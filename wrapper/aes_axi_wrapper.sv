// ============================================================================
//  aes_axi_wrapper.sv
//
//  Standardized-protocol shell around the fixed aes_top AES-128 core:
//    - AXI4-Lite slave : key load, control, and status/observability regs
//    - AXI4-Stream slave (S_AXIS)  : plaintext/ciphertext data IN
//    - AXI4-Stream master (M_AXIS) : ciphertext/plaintext data OUT
//
//  This is the module intended to go through the backend flow for tapeout,
//  wrapping the (now key-sync-fixed) aes_top core untouched underneath.
//
//  CLOCKING / RESET
//  -----------------
//  Single clock domain: ACLK drives both the AXI shell and the core
//  (aes_top's `clk`). This is a deliberate simplification to avoid CDC
//  logic in a block whose primary job, for this pass, is fixing a
//  functional correctness bug ahead of tapeout - not introducing new
//  clock-domain-crossing surface area. If the SoC integration needs the
//  core on a different clock than the AXI fabric, add a standard
//  AXI-CDC/register-slice IP between this wrapper and the fabric; do not
//  bolt ad hoc CDC onto this module.
//
//  ARESETn is the standard AXI active-low asynchronous reset input;
//  rst_sync.sv converts it to the synchronous active-high `reset` the
//  core (and this wrapper's own registers) expect internally.
//
//  AXI4-LITE REGISTER MAP  (32-bit registers, word-aligned, 4-byte stride)
//  -------------------------------------------------------------------------
//  0x00  KEY_IN0        W    key_in[31:0]    (stage word 0 of next key)
//  0x04  KEY_IN1        W    key_in[63:32]
//  0x08  KEY_IN2        W    key_in[95:64]
//  0x0C  KEY_IN3        W    key_in[127:96]
//  0x10  KEY_CTRL       W    bit0 = PUSH: write 1 to push the currently
//                             staged KEY_IN0..3 into the core's key FIFO
//                             (one-cycle pulse, self-clearing - write-only,
//                             reads as 0)
//  0x14  KEY_STATUS     R    bit0  key_push_ready   (0 => last push may
//                                                     have been dropped -
//                                                     FIFO was full)
//                             bit1  key_system_busy
//                             bit2  key_available
//                             bit3  active_key_bank
//                             [5:4] bank_valid[1:0]
//                             [7:6] bank_free[1:0]
//                             [9:8] bank_busy_total[1:0]
//                             bit10 key_ctx_error (STICKY - a data-plane
//                                   transaction was refused for a
//                                   key-generation mismatch since this bit
//                                   was last cleared; see KEY_CTRL bit1)
//  0x18  KEY_GEN_HANDLE  R    [15:0] = generation handle assigned to the
//                             MOST RECENTLY ACCEPTED key push. Software
//                             must capture this immediately after a push
//                             and present it again on S_AXIS TUSER
//                             (key_gen field) for any transaction meant
//                             to use that key.
//  0x1C  BANK_GEN        R    [15:0]  = bank_gen_flat for bank 0
//                             [31:16] = bank_gen_flat for bank 1
//                             (debug/status readback of what generation
//                             each bank currently holds)
//  0x20  KEY_CTX_ERR_CNT R/W1C
//                             Saturating count of key-context mismatches
//                             (transactions refused by aes_top's
//                             key_ctx_error). Write ANY value to clear
//                             both this counter and KEY_STATUS bit10.
//  0x24  IP_VERSION      R    constant 32'h41455331 ("AES1") - sanity/ID
//                             read for driver bring-up.
//
//  All unmapped word offsets in the 0x000-0x3FF AXI4-Lite window read 0
//  and ignore writes (decoded, not aliased, to avoid silent mis-hits).
//
//  AXI4-STREAM DATA CHANNELS
//  --------------------------
//  S_AXIS (slave, data IN):
//    S_AXIS_TDATA [127:0]  plaintext (op_mode=0) or ciphertext (op_mode=1)
//    S_AXIS_TUSER [17:0]   sideband, valid for the whole beat:
//                             [0]     op_mode      (0=encrypt,1=decrypt)
//                             [1]     current_bank (which key bank)
//                             [17:2]  key_gen       (generation handle -
//                                     THE key-sync fix's whole point:
//                                     get this from KEY_GEN_HANDLE after
//                                     the push that populated the bank
//                                     you're naming, not by guessing)
//    S_AXIS_TVALID/TREADY  standard handshake
//    S_AXIS_TLAST          expected tied high by the master (this core
//                           has no notion of a multi-beat packet - every
//                           beat is one independent 128-bit block)
//
//  M_AXIS (master, data OUT):
//    M_AXIS_TDATA [127:0]  result block
//    M_AXIS_TUSER [0]      op_mode this result was produced under
//                           (0=came from the encrypt engine, 1=decrypt)
//    M_AXIS_TVALID/TREADY  standard handshake
//    M_AXIS_TLAST          tied high (see above)
//
//  A transaction refused by the key-context gate inside aes_top (mismatched
//  key_gen) simply never asserts S_AXIS_TREADY for that beat - from the
//  AXI master's point of view this looks like ordinary backpressure. Poll
//  KEY_STATUS bit10 / KEY_CTX_ERR_CNT to distinguish "core is busy" from
//  "you named a stale key context" during bring-up/debug.
// ============================================================================
/*
`timescale 1ns/1ps

module aes_axi_wrapper
    import aes_pkg::*;
#(
    parameter int C_S_AXI_ADDR_WIDTH = 8   // 0x00-0xFF is ample for 10 regs
)(
    // ------------------------------------------------------------------
    // Clock / Reset
    // ------------------------------------------------------------------
    input  logic                          ACLK,
    input  logic                          ARESETn,

    // ------------------------------------------------------------------
    // AXI4-Lite slave : control / status / key load
    // ------------------------------------------------------------------
    input  logic [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  logic                          S_AXI_AWVALID,
    output logic                          S_AXI_AWREADY,

    input  logic [31:0]                   S_AXI_WDATA,
    input  logic [3:0]                    S_AXI_WSTRB,
    input  logic                          S_AXI_WVALID,
    output logic                          S_AXI_WREADY,

    output logic [1:0]                    S_AXI_BRESP,
    output logic                          S_AXI_BVALID,
    input  logic                          S_AXI_BREADY,

    input  logic [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  logic                          S_AXI_ARVALID,
    output logic                          S_AXI_ARREADY,

    output logic [31:0]                   S_AXI_RDATA,
    output logic [1:0]                    S_AXI_RRESP,
    output logic                          S_AXI_RVALID,
    input  logic                          S_AXI_RREADY,

    // ------------------------------------------------------------------
    // AXI4-Stream slave : data in
    // ------------------------------------------------------------------
    input  logic [127:0]                  S_AXIS_TDATA,
    input  logic [17:0]                   S_AXIS_TUSER,
    input  logic                          S_AXIS_TVALID,
    output logic                          S_AXIS_TREADY,
    input  logic                          S_AXIS_TLAST,

    // ------------------------------------------------------------------
    // AXI4-Stream master : data out
    // ------------------------------------------------------------------
    output logic [127:0]                  M_AXIS_TDATA,
    output logic [0:0]                    M_AXIS_TUSER,
    output logic                          M_AXIS_TVALID,
    input  logic                          M_AXIS_TREADY,
    output logic                          M_AXIS_TLAST
);

    // ========================================================================
    // Reset synchronization
    // ========================================================================
    logic reset;
    rst_sync u_rst_sync (
        .clk          (ACLK),
        .async_rst_n  (ARESETn),
        .sync_rst     (reset)
    );

    // ========================================================================
    // Core signals
    // ========================================================================
    logic        key_push;
    aes_block_t  key_in;
    logic        key_push_ready;
    key_gen_t    key_gen_out;

    logic        op_mode;
    logic        current_bank;
    key_gen_t    key_gen;
    logic        in_valid, in_ready;
    aes_block_t  data_in;
    aes_block_t  data_out;
    logic        out_valid, out_ready;

    logic [1:0]  bank_valid, bank_free, bank_busy_total;
    logic        key_system_busy, key_available, active_key_bank;
    logic [NUM_BANKS*KEY_GEN_W-1:0] bank_gen_flat;
    logic        key_ctx_error;

    // Output-side direction tag: latched alongside the transaction that
    // was accepted, shifted out in lockstep with the pipeline so M_AXIS
    // TUSER correctly reflects which engine produced each result even
    // while a different-direction transaction is later in flight
    // upstream. PIPE_DEPTH-deep shift register, indexed the same way the
    // core's own internal bank[] tracking is (see aes_top.sv).
    logic op_mode_pipe [0:PIPE_DEPTH-1];
    integer pd;
    always_ff @(posedge ACLK) begin
        if (reset) begin
            for (pd = 0; pd < PIPE_DEPTH; pd = pd + 1)
                op_mode_pipe[pd] <= 1'b0;
        end else begin
            if (in_valid && in_ready)
                op_mode_pipe[0] <= op_mode;
            else
                op_mode_pipe[0] <= op_mode_pipe[0];
            for (pd = 1; pd < PIPE_DEPTH; pd = pd + 1)
                op_mode_pipe[pd] <= op_mode_pipe[pd-1];
        end
    end
    // NOTE: this shift register is a convenience tag for M_AXIS TUSER only
    // - it does NOT gate correctness (aes_top's own internal bank[]/
    // op_mode arbitration already guarantees data_out/out_valid come from
    // exactly one unambiguous source at a time, see aes_top.sv's
    // single-active-engine-arbitration note). Because the core enforces
    // "only one direction in flight at a time" (new opposite-direction
    // transactions stall until the other engine fully drains), the value
    // that actually reaches M_AXIS_TUSER at any out_valid cycle is simply
    // whichever direction is currently active - op_mode_pipe tracks that
    // correctly without needing to be indexed by the core's internal
    // per-slot bank/direction state.
    assign M_AXIS_TUSER[0] = op_mode_pipe[PIPE_DEPTH-1];

    // ========================================================================
    // Core instance
    // ========================================================================
    aes_top u_aes_top (
        .clk             (ACLK),
        .reset           (reset),
        .key_push        (key_push),
        .key_in          (key_in),
        .key_push_ready  (key_push_ready),
        .key_gen_out     (key_gen_out),
        .op_mode         (op_mode),
        .current_bank    (current_bank),
        .key_gen         (key_gen),
        .in_valid        (in_valid),
        .in_ready        (in_ready),
        .data_in         (data_in),
        .data_out        (data_out),
        .out_valid       (out_valid),
        .out_ready       (out_ready),
        .bank_valid      (bank_valid),
        .bank_free       (bank_free),
        .key_system_busy (key_system_busy),
        .key_available   (key_available),
        .active_key_bank (active_key_bank),
        .bank_busy_total (bank_busy_total),
        .bank_gen_flat   (bank_gen_flat),
        .key_ctx_error   (key_ctx_error)
    );

    // ========================================================================
    // AXI4-Stream <-> core data channel (pure passthrough, no buffering -
    // AXI4-Stream valid/ready is a strict subset of the core's own
    // valid/ready handshake semantics, so this is a direct wire-through)
    // ========================================================================
    assign data_in       = S_AXIS_TDATA;
    assign op_mode        = S_AXIS_TUSER[0];
    assign current_bank   = S_AXIS_TUSER[1];
    assign key_gen         = key_gen_t'(S_AXIS_TUSER[17:2]);
    assign in_valid       = S_AXIS_TVALID;
    assign S_AXIS_TREADY  = in_ready;

    assign M_AXIS_TDATA   = data_out;
    assign M_AXIS_TVALID  = out_valid;
    assign out_ready       = M_AXIS_TREADY;
    assign M_AXIS_TLAST   = 1'b1;   // every beat is its own 128-bit block

    // ========================================================================
    // AXI4-Lite slave : write channel
    // ------------------------------------------------------------------
    // Standard single-cycle-acceptance AXI4-Lite slave: AWREADY/WREADY are
    // asserted (and the register write committed) in the SAME cycle that
    // AWVALID and WVALID are BOTH observed high together - the common,
    // fully protocol-compliant simplification used by most AXI4-Lite
    // peripherals (e.g. Xilinx's AXI4-Lite slave template), since
    // AXI4-Lite makes no guarantee of independent AW/W channel progress
    // beyond ordering. This avoids any multi-edge handshake-detection
    // register (an earlier draft of this slave used a 2-stage
    // aw_done_q/w_done_q scheme that required the master to hold
    // AWVALID/WVALID one cycle longer than the AXI4-Lite spec requires -
    // caught during wrapper bring-up simulation and replaced with this
    // simpler, correct pattern before this file was finalized).
    // ========================================================================
    localparam logic [1:0] AXI_OK = 2'b00;

    logic                          bvalid_q;
    logic                          aw_w_accept;

    assign aw_w_accept   = S_AXI_AWVALID && S_AXI_WVALID && !bvalid_q;
    assign S_AXI_AWREADY = aw_w_accept;
    assign S_AXI_WREADY  = aw_w_accept;

    logic do_write;
    assign do_write = aw_w_accept;

    always_ff @(posedge ACLK) begin
        if (reset)
            bvalid_q <= 1'b0;
        else if (do_write)
            bvalid_q <= 1'b1;
        else if (S_AXI_BVALID && S_AXI_BREADY)
            bvalid_q <= 1'b0;
    end
    assign S_AXI_BVALID = bvalid_q;
    assign S_AXI_BRESP  = AXI_OK;

    // ---- Register writes ----
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_KEY_IN0    = 8'h00;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_KEY_IN1    = 8'h04;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_KEY_IN2    = 8'h08;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_KEY_IN3    = 8'h0C;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_KEY_CTRL   = 8'h10;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_KEY_STATUS = 8'h14;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_KEY_GEN    = 8'h18;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_BANK_GEN   = 8'h1C;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_ERR_CNT    = 8'h20;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_VERSION    = 8'h24;

    logic [127:0] key_stage_q;
    logic         key_push_pulse;
    logic [15:0]  key_ctx_err_cnt_q;
    logic         key_ctx_error_sticky_q;
    key_gen_t     key_gen_handle_q;

    // FIX (wrapper key-sync bookkeeping): key_gen_out is a LIVE wire off
    // the core's own push_gen_counter (see key_system_top.sv) - it only
    // holds the handle assigned to a given push during that push's own
    // one-cycle pulse; the instant the pulse ends, key_gen_out keeps
    // tracking the counter's current (possibly already-incremented-by-a-
    // later-push) value. A register READ several cycles later would
    // therefore show the WRONG (already-advanced) handle if wired
    // straight through - exactly the same one-cycle-timing class of bug
    // already caught and fixed in the core itself (see keymem_dual.sv /
    // key_system_top.sv comments). Latch it into a stable register here,
    // gated on the exact push-accepted cycle, and expose THAT via
    // KEY_GEN_HANDLE instead of the live wire.
    always_ff @(posedge ACLK) begin
        if (reset)
            key_gen_handle_q <= '0;
        else if (key_push && key_push_ready)
            key_gen_handle_q <= key_gen_out;
    end

    // Register writes commit using THIS cycle's address/data directly when
    // do_write fires (not awaddr_q, which would be one cycle stale on the
    // very cycle of acceptance since it's registered from the same event).
    logic [C_S_AXI_ADDR_WIDTH-1:0] write_addr;
    assign write_addr = S_AXI_AWADDR;

    always_ff @(posedge ACLK) begin
        if (reset) begin
            key_stage_q             <= '0;
            key_push_pulse           <= 1'b0;
            key_ctx_err_cnt_q        <= '0;
            key_ctx_error_sticky_q   <= 1'b0;
        end else begin
            key_push_pulse <= 1'b0;   // self-clearing, default deassert

            if (do_write) begin
                unique case (write_addr)
                    ADDR_KEY_IN0: key_stage_q[31:0]    <= wstrobe(key_stage_q[31:0],   S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_KEY_IN1: key_stage_q[63:32]   <= wstrobe(key_stage_q[63:32],  S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_KEY_IN2: key_stage_q[95:64]   <= wstrobe(key_stage_q[95:64],  S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_KEY_IN3: key_stage_q[127:96]  <= wstrobe(key_stage_q[127:96], S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_KEY_CTRL: key_push_pulse       <= S_AXI_WDATA[0];
                    ADDR_ERR_CNT: begin
                        key_ctx_err_cnt_q      <= '0;   // any write clears
                        key_ctx_error_sticky_q <= 1'b0;
                    end
                    default: ; // unmapped: ignored
                endcase
            end

            // Sticky error tracking (independent of the AXI write FSM)
            if (key_ctx_error) begin
                key_ctx_error_sticky_q <= 1'b1;
                if (key_ctx_err_cnt_q != 16'hFFFF)
                    key_ctx_err_cnt_q <= key_ctx_err_cnt_q + 16'h1;
            end
        end
    end

    // Byte-strobed register write helper
    function automatic logic [31:0] wstrobe(
        input logic [31:0] cur,
        input logic [31:0] wdata,
        input logic [3:0]  strb
    );
        logic [31:0] result;
        result = cur;
        if (strb[0]) result[7:0]   = wdata[7:0];
        if (strb[1]) result[15:8]  = wdata[15:8];
        if (strb[2]) result[23:16] = wdata[23:16];
        if (strb[3]) result[31:24] = wdata[31:24];
        return result;
    endfunction

    assign key_in   = key_stage_q;
    assign key_push  = key_push_pulse;

    // ---- Reads ----
    // ========================================================================
    // AXI4-Lite slave : read channel
    // ------------------------------------------------------------------
    // Same principle as the write channel above: ARREADY is purely
    // combinational (gated only by "not currently holding an unconsumed
    // read result"), so any same-cycle logic that reads it (rvalid_q's
    // own acceptance condition, right below) sees the true, current
    // value - no delayed/registered-READY detection stage, and no need
    // for the master to hold ARVALID beyond the single accepting cycle.
    // ========================================================================
    logic rvalid_q;
    logic ar_accept;

    assign ar_accept     = S_AXI_ARVALID && !rvalid_q;
    assign S_AXI_ARREADY = !rvalid_q;

    logic [C_S_AXI_ADDR_WIDTH-1:0] araddr_q;

    always_ff @(posedge ACLK) begin
        if (reset)
            araddr_q <= '0;
        else if (ar_accept)
            araddr_q <= S_AXI_ARADDR;
    end

    always_ff @(posedge ACLK) begin
        if (reset)
            rvalid_q <= 1'b0;
        else if (ar_accept)
            rvalid_q <= 1'b1;
        else if (S_AXI_RVALID && S_AXI_RREADY)
            rvalid_q <= 1'b0;
    end
    assign S_AXI_RVALID = rvalid_q;
    assign S_AXI_RRESP  = AXI_OK;

    logic [31:0] key_status_word;
    assign key_status_word = {
        21'b0,
        key_ctx_error_sticky_q,      // [10]
        bank_busy_total,              // [9:8]
        bank_free,                    // [7:6]
        bank_valid,                   // [5:4]
        active_key_bank,              // [3]
        key_available,                // [2]
        key_system_busy,              // [1]
        key_push_ready                // [0]
    };

    always_comb begin
        unique case (araddr_q)
            ADDR_KEY_STATUS: S_AXI_RDATA = key_status_word;
            ADDR_KEY_GEN:    S_AXI_RDATA = {16'b0, key_gen_handle_q};
            ADDR_BANK_GEN:   S_AXI_RDATA = {bank_gen_flat[2*KEY_GEN_W-1:KEY_GEN_W],
                                             bank_gen_flat[KEY_GEN_W-1:0]};
            ADDR_ERR_CNT:    S_AXI_RDATA = {16'b0, key_ctx_err_cnt_q};
            ADDR_VERSION:    S_AXI_RDATA = 32'h41455331; // "AES1"
            default:         S_AXI_RDATA = 32'h0;
        endcase
    end

endmodule
*/

// ============================================================================
//  aes_axi_wrapper.sv
//
//  Standardized-protocol shell around the fixed aes_top AES-128 core:
//    - AXI4-Lite slave : key load, control, and status/observability regs
//    - AXI4-Stream slave (S_AXIS)  : plaintext/ciphertext data IN
//    - AXI4-Stream master (M_AXIS) : ciphertext/plaintext data OUT
//
//  This is the module intended to go through the backend flow for tapeout,
//  wrapping the (now key-sync-fixed) aes_top core untouched underneath.
//
//  CLOCKING / RESET
//  -----------------
//  Single clock domain: ACLK drives both the AXI shell and the core
//  (aes_top's `clk`). This is a deliberate simplification to avoid CDC
//  logic in a block whose primary job, for this pass, is fixing a
//  functional correctness bug ahead of tapeout - not introducing new
//  clock-domain-crossing surface area. If the SoC integration needs the
//  core on a different clock than the AXI fabric, add a standard
//  AXI-CDC/register-slice IP between this wrapper and the fabric; do not
//  bolt ad hoc CDC onto this module.
//
//  ARESETn is the standard AXI active-low asynchronous reset input;
//  rst_sync.sv converts it to the synchronous active-high `reset` the
//  core (and this wrapper's own registers) expect internally.
//
//  AXI4-LITE REGISTER MAP  (32-bit registers, word-aligned, 4-byte stride)
//  -------------------------------------------------------------------------
//  0x00  KEY_IN0        W    key_in[31:0]    (stage word 0 of next key)
//  0x04  KEY_IN1        W    key_in[63:32]
//  0x08  KEY_IN2        W    key_in[95:64]
//  0x0C  KEY_IN3        W    key_in[127:96]
//  0x10  KEY_CTRL       W    bit0 = PUSH: write 1 to push the currently
//                             staged KEY_IN0..3 into the core's key FIFO
//                             (one-cycle pulse, self-clearing - write-only,
//                             reads as 0)
//  0x14  KEY_STATUS     R    (registered snapshot, <=1 ACLK cycle stale -
//                             see FIX (timing) comment at status_snapshot_q
//                             below)
//                             bit0  key_push_ready   (0 => last push may
//                                                     have been dropped -
//                                                     FIFO was full)
//                             bit1  key_system_busy
//                             bit2  key_available
//                             bit3  active_key_bank
//                             [5:4] bank_valid[1:0]
//                             [7:6] bank_free[1:0]
//                             [9:8] bank_busy_total[1:0]
//                             bit10 key_ctx_error (STICKY - a data-plane
//                                   transaction was refused for a
//                                   key-generation mismatch since this bit
//                                   was last cleared; see KEY_CTRL bit1)
//  0x18  KEY_GEN_HANDLE  R    [15:0] = generation handle assigned to the
//                             MOST RECENTLY ACCEPTED key push. Software
//                             must capture this immediately after a push
//                             and present it again on S_AXIS TUSER
//                             (key_gen field) for any transaction meant
//                             to use that key.
//  0x1C  BANK_GEN        R    [15:0]  = bank_gen_flat for bank 0
//                             [31:16] = bank_gen_flat for bank 1
//                             (debug/status readback of what generation
//                             each bank currently holds)
//  0x20  KEY_CTX_ERR_CNT R/W1C
//                             Saturating count of key-context mismatches
//                             (transactions refused by aes_top's
//                             key_ctx_error). Write ANY value to clear
//                             both this counter and KEY_STATUS bit10.
//  0x24  IP_VERSION      R    constant 32'h41455331 ("AES1") - sanity/ID
//                             read for driver bring-up.
//
//  All unmapped word offsets in the 0x000-0x3FF AXI4-Lite window read 0
//  and ignore writes (decoded, not aliased, to avoid silent mis-hits).
//
//  AXI4-STREAM DATA CHANNELS
//  --------------------------
//  S_AXIS (slave, data IN):
//    S_AXIS_TDATA [127:0]  plaintext (op_mode=0) or ciphertext (op_mode=1)
//    S_AXIS_TUSER [17:0]   sideband, valid for the whole beat:
//                             [0]     op_mode      (0=encrypt,1=decrypt)
//                             [1]     current_bank (which key bank)
//                             [17:2]  key_gen       (generation handle -
//                                     THE key-sync fix's whole point:
//                                     get this from KEY_GEN_HANDLE after
//                                     the push that populated the bank
//                                     you're naming, not by guessing)
//    S_AXIS_TVALID/TREADY  standard handshake
//    S_AXIS_TLAST          expected tied high by the master (this core
//                           has no notion of a multi-beat packet - every
//                           beat is one independent 128-bit block)
//
//  M_AXIS (master, data OUT):
//    M_AXIS_TDATA [127:0]  result block
//    M_AXIS_TUSER [0]      op_mode this result was produced under
//                           (0=came from the encrypt engine, 1=decrypt)
//    M_AXIS_TVALID/TREADY  standard handshake
//    M_AXIS_TLAST          tied high (see above)
//
//  A transaction refused by the key-context gate inside aes_top (mismatched
//  key_gen) simply never asserts S_AXIS_TREADY for that beat - from the
//  AXI master's point of view this looks like ordinary backpressure. Poll
//  KEY_STATUS bit10 / KEY_CTX_ERR_CNT to distinguish "core is busy" from
//  "you named a stale key context" during bring-up/debug.
// ============================================================================

`timescale 1ns/1ps

module aes_axi_wrapper
    import aes_pkg::*;
#(
    parameter int C_S_AXI_ADDR_WIDTH = 8   // 0x00-0xFF is ample for 10 regs
)(
    // ------------------------------------------------------------------
    // Clock / Reset
    // ------------------------------------------------------------------
    input  logic                          ACLK,
    input  logic                          ARESETn,

    // ------------------------------------------------------------------
    // AXI4-Lite slave : control / status / key load
    // ------------------------------------------------------------------
    input  logic [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  logic                          S_AXI_AWVALID,
    output logic                          S_AXI_AWREADY,

    input  logic [31:0]                   S_AXI_WDATA,
    input  logic [3:0]                    S_AXI_WSTRB,
    input  logic                          S_AXI_WVALID,
    output logic                          S_AXI_WREADY,

    output logic [1:0]                    S_AXI_BRESP,
    output logic                          S_AXI_BVALID,
    input  logic                          S_AXI_BREADY,

    input  logic [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  logic                          S_AXI_ARVALID,
    output logic                          S_AXI_ARREADY,

    output logic [31:0]                   S_AXI_RDATA,
    output logic [1:0]                    S_AXI_RRESP,
    output logic                          S_AXI_RVALID,
    input  logic                          S_AXI_RREADY,

    // ------------------------------------------------------------------
    // AXI4-Stream slave : data in
    // ------------------------------------------------------------------
    input  logic [127:0]                  S_AXIS_TDATA,
    input  logic [17:0]                   S_AXIS_TUSER,
    input  logic                          S_AXIS_TVALID,
    output logic                          S_AXIS_TREADY,
    input  logic                          S_AXIS_TLAST,

    // ------------------------------------------------------------------
    // AXI4-Stream master : data out
    // ------------------------------------------------------------------
    output logic [127:0]                  M_AXIS_TDATA,
    output logic [0:0]                    M_AXIS_TUSER,
    output logic                          M_AXIS_TVALID,
    input  logic                          M_AXIS_TREADY,
    output logic                          M_AXIS_TLAST
);

    // ========================================================================
    // Reset synchronization
    // ========================================================================
    logic reset;
    rst_sync u_rst_sync (
        .clk          (ACLK),
        .async_rst_n  (ARESETn),
        .sync_rst     (reset)
    );

    // ========================================================================
    // Core signals
    // ========================================================================
    logic        key_push;
    aes_block_t  key_in;
    logic        key_push_ready;
    key_gen_t    key_gen_out;

    logic        op_mode;
    logic        current_bank;
    key_gen_t    key_gen;
    logic        in_valid, in_ready;
    aes_block_t  data_in;
    aes_block_t  data_out;
    logic        out_valid, out_ready;

    logic [1:0]  bank_valid, bank_free, bank_busy_total;
    logic        key_system_busy, key_available, active_key_bank;
    logic [NUM_BANKS*KEY_GEN_W-1:0] bank_gen_flat;
    logic        key_ctx_error;

    // Output-side direction tag: latched alongside the transaction that
    // was accepted, shifted out in lockstep with the pipeline so M_AXIS
    // TUSER correctly reflects which engine produced each result even
    // while a different-direction transaction is later in flight
    // upstream. PIPE_DEPTH-deep shift register, indexed the same way the
    // core's own internal bank[] tracking is (see aes_top.sv).
    logic op_mode_pipe [0:PIPE_DEPTH-1];
    integer pd;
    always_ff @(posedge ACLK) begin
        if (reset) begin
            for (pd = 0; pd < PIPE_DEPTH; pd = pd + 1)
                op_mode_pipe[pd] <= 1'b0;
        end else begin
            if (in_valid && in_ready)
                op_mode_pipe[0] <= op_mode;
            else
                op_mode_pipe[0] <= op_mode_pipe[0];
            for (pd = 1; pd < PIPE_DEPTH; pd = pd + 1)
                op_mode_pipe[pd] <= op_mode_pipe[pd-1];
        end
    end
    // NOTE: this shift register is a convenience tag for M_AXIS TUSER only
    // - it does NOT gate correctness (aes_top's own internal bank[]/
    // op_mode arbitration already guarantees data_out/out_valid come from
    // exactly one unambiguous source at a time, see aes_top.sv's
    // single-active-engine-arbitration note). Because the core enforces
    // "only one direction in flight at a time" (new opposite-direction
    // transactions stall until the other engine fully drains), the value
    // that actually reaches M_AXIS_TUSER at any out_valid cycle is simply
    // whichever direction is currently active - op_mode_pipe tracks that
    // correctly without needing to be indexed by the core's internal
    // per-slot bank/direction state.
    assign M_AXIS_TUSER[0] = op_mode_pipe[PIPE_DEPTH-1];

    // ========================================================================
    // Core instance
    // ========================================================================
    aes_top u_aes_top (
        .clk             (ACLK),
        .reset           (reset),
        .key_push        (key_push),
        .key_in          (key_in),
        .key_push_ready  (key_push_ready),
        .key_gen_out     (key_gen_out),
        .op_mode         (op_mode),
        .current_bank    (current_bank),
        .key_gen         (key_gen),
        .in_valid        (in_valid),
        .in_ready        (in_ready),
        .data_in         (data_in),
        .data_out        (data_out),
        .out_valid       (out_valid),
        .out_ready       (out_ready),
        .bank_valid      (bank_valid),
        .bank_free       (bank_free),
        .key_system_busy (key_system_busy),
        .key_available   (key_available),
        .active_key_bank (active_key_bank),
        .bank_busy_total (bank_busy_total),
        .bank_gen_flat   (bank_gen_flat),
        .key_ctx_error   (key_ctx_error)
    );

    // ========================================================================
    // AXI4-Stream <-> core data channel
    // ------------------------------------------------------------------
    // FIX (timing): S_AXIS_TREADY used to be a direct, unregistered
    // passthrough of in_ready, which is combinational on live pipeline
    // state several logic levels deep inside aes_top (see aes_top.sv /
    // AES_Encrypt.sv `stall`). That put a deep combinational cone
    // directly on a top-level output pin and was the #2 worst-slack
    // family in synthesis (see diagnostic report, Section 6).
    //
    // Replaced with a standard 1-entry "skid buffer": S_AXIS_TREADY is
    // now purely `!skid_valid_q`, a single register's output through an
    // inverter - no dependency on in_ready at all. When the core isn't
    // ready for a beat the AXI master has already been granted (TREADY
    // was high, TVALID was high, but in_ready was low that same cycle),
    // that one beat is latched into skid_tdata_q/skid_tuser_q and
    // presented to the core ahead of any newer beat until the core
    // accepts it. This is lossless and duplication-free: at most one
    // beat is ever in flight between "accepted on the AXI side" and
    // "accepted into the core", and TREADY correctly drops the instant
    // that one slot is occupied so the master holds its next beat
    // stable per the AXI4-Stream spec.
    // ========================================================================
    // ------------------------------------------------------------------
    // IMPORTANT correctness note: a transaction can be "not ready" for
    // two functionally different reasons, and they must NOT be treated
    // the same way by the buffer:
    //   (a) TRANSIENT capacity reasons (the other engine's pipeline is
    //       still draining - enc_gate/dec_gate - or this engine's own
    //       last stage hasn't moved yet - stall). These are guaranteed
    //       to clear eventually and are safe to buffer across.
    //   (b) PERMANENT admissibility reasons (current_bank names a bank
    //       that isn't valid, or key_gen doesn't match bank_gen[that
    //       bank] - a stale/wrong key context). These can persist
    //       forever (e.g. a software bug), and the design's documented
    //       contract is that such a beat must simply never be accepted
    //       (TREADY stays low, looks like ordinary backpressure, the
    //       master holds and can retry with a corrected beat - see the
    //       module header and aes_top.sv's key_ctx_error comments).
    //       If the skid buffer latched a type-(b) beat the same way as
    //       a type-(a) beat, it would swallow it off the AXI interface
    //       (TREADY momentarily high) and then hold it forever (since
    //       it can never become admissible), permanently deadlocking
    //       S_AXIS - strictly worse than the original behaviour.
    //
    // So TREADY/buffering here re-checks admissibility (key_ctx_ok &&
    // bank_valid[current_bank]) directly off the same registered
    // sources aes_top itself uses (bank_gen_flat, bank_valid - both
    // already-registered keymem_dual outputs, shallow logic, not part
    // of the flagged critical-path cone), and only ever buffers a beat
    // that has already passed that check. An inadmissible beat is
    // refused combinationally every cycle, exactly as before.
    // ------------------------------------------------------------------
    logic        live_current_bank;
    key_gen_t    live_key_gen;
    assign live_current_bank = S_AXIS_TUSER[1];
    assign live_key_gen      = key_gen_t'(S_AXIS_TUSER[17:2]);

    logic live_request_admissible;
    assign live_request_admissible =
        bank_valid[live_current_bank] &&
        (live_key_gen == bank_gen_flat[live_current_bank*KEY_GEN_W +: KEY_GEN_W]);

    logic [127:0] skid_tdata_q;
    logic [17:0]  skid_tuser_q;
    logic         skid_valid_q;

    // Data actually presented to the core: the buffered (older) beat
    // takes priority whenever one is held, otherwise today's live
    // S_AXIS data flows straight through (zero added latency in the
    // common, not-backpressured case). Note: an admitted-but-not-yet-
    // buffered live beat (skid_valid_q=0) still flows straight into
    // in_valid/data_in exactly as before, including while inadmissible
    // (TVALID high, bad context) - so aes_top's own key_ctx_error
    // sticky/counter logic keeps firing every such cycle, unchanged
    // from the original behaviour.
    logic [127:0] core_tdata_mux;
    logic [17:0]  core_tuser_mux;
    assign core_tdata_mux = skid_valid_q ? skid_tdata_q : S_AXIS_TDATA;
    assign core_tuser_mux = skid_valid_q ? skid_tuser_q : S_AXIS_TUSER;

    assign data_in       = core_tdata_mux;
    assign op_mode        = core_tuser_mux[0];
    assign current_bank   = core_tuser_mux[1];
    assign key_gen         = key_gen_t'(core_tuser_mux[17:2]);
    assign in_valid       = skid_valid_q || S_AXIS_TVALID;

    // TREADY: never asserted while the buffer is occupied, and never
    // asserted for a currently-inadmissible beat (so such a beat is
    // never latched into the buffer in the first place - see note
    // above). Both terms are shallow/registered-source logic, not the
    // deep bank_busy-derived cone that caused the original violation.
    assign S_AXIS_TREADY  = !skid_valid_q && live_request_admissible;

    always_ff @(posedge ACLK) begin
        if (reset) begin
            skid_valid_q <= 1'b0;
        end else if (!skid_valid_q) begin
            // Buffer empty: if the master is presenting an ADMISSIBLE
            // beat this cycle that the core can't take right now for
            // transient capacity reasons, latch it - the AXI transfer
            // is still considered complete this cycle (TREADY was
            // high), so nothing is lost.
            if (S_AXIS_TVALID && live_request_admissible && !in_ready) begin
                skid_valid_q <= 1'b1;
                skid_tdata_q <= S_AXIS_TDATA;
                skid_tuser_q <= S_AXIS_TUSER;
            end
        end else begin
            // Buffer holds a beat: release it the instant the core
            // accepts it (in_ready here reflects the core's readiness
            // for the buffered beat, since core_tdata_mux/core_tuser_mux
            // are already selecting it while skid_valid_q is set).
            if (in_ready) begin
                skid_valid_q <= 1'b0;
            end
        end
    end

    assign M_AXIS_TDATA   = data_out;
    assign M_AXIS_TVALID  = out_valid;
    assign out_ready       = M_AXIS_TREADY;
    assign M_AXIS_TLAST   = 1'b1;   // every beat is its own 128-bit block

    // ========================================================================
    // AXI4-Lite slave : write channel
    // ------------------------------------------------------------------
    // Standard single-cycle-acceptance AXI4-Lite slave: AWREADY/WREADY are
    // asserted (and the register write committed) in the SAME cycle that
    // AWVALID and WVALID are BOTH observed high together - the common,
    // fully protocol-compliant simplification used by most AXI4-Lite
    // peripherals (e.g. Xilinx's AXI4-Lite slave template), since
    // AXI4-Lite makes no guarantee of independent AW/W channel progress
    // beyond ordering. This avoids any multi-edge handshake-detection
    // register (an earlier draft of this slave used a 2-stage
    // aw_done_q/w_done_q scheme that required the master to hold
    // AWVALID/WVALID one cycle longer than the AXI4-Lite spec requires -
    // caught during wrapper bring-up simulation and replaced with this
    // simpler, correct pattern before this file was finalized).
    // ========================================================================
    localparam logic [1:0] AXI_OK = 2'b00;

    logic                          bvalid_q;
    logic                          aw_w_accept;

    assign aw_w_accept   = S_AXI_AWVALID && S_AXI_WVALID && !bvalid_q;
    assign S_AXI_AWREADY = aw_w_accept;
    assign S_AXI_WREADY  = aw_w_accept;

    logic do_write;
    assign do_write = aw_w_accept;

    always_ff @(posedge ACLK) begin
        if (reset)
            bvalid_q <= 1'b0;
        else if (do_write)
            bvalid_q <= 1'b1;
        else if (S_AXI_BVALID && S_AXI_BREADY)
            bvalid_q <= 1'b0;
    end
    assign S_AXI_BVALID = bvalid_q;
    assign S_AXI_BRESP  = AXI_OK;

    // ---- Register writes ----
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_KEY_IN0    = 8'h00;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_KEY_IN1    = 8'h04;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_KEY_IN2    = 8'h08;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_KEY_IN3    = 8'h0C;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_KEY_CTRL   = 8'h10;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_KEY_STATUS = 8'h14;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_KEY_GEN    = 8'h18;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_BANK_GEN   = 8'h1C;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_ERR_CNT    = 8'h20;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_VERSION    = 8'h24;

    logic [127:0] key_stage_q;
    logic         key_push_pulse;
    logic [15:0]  key_ctx_err_cnt_q;
    logic         key_ctx_error_sticky_q;
    key_gen_t     key_gen_handle_q;

    // FIX (wrapper key-sync bookkeeping): key_gen_out is a LIVE wire off
    // the core's own push_gen_counter (see key_system_top.sv) - it only
    // holds the handle assigned to a given push during that push's own
    // one-cycle pulse; the instant the pulse ends, key_gen_out keeps
    // tracking the counter's current (possibly already-incremented-by-a-
    // later-push) value. A register READ several cycles later would
    // therefore show the WRONG (already-advanced) handle if wired
    // straight through - exactly the same one-cycle-timing class of bug
    // already caught and fixed in the core itself (see keymem_dual.sv /
    // key_system_top.sv comments). Latch it into a stable register here,
    // gated on the exact push-accepted cycle, and expose THAT via
    // KEY_GEN_HANDLE instead of the live wire.
    always_ff @(posedge ACLK) begin
        if (reset)
            key_gen_handle_q <= '0;
        else if (key_push && key_push_ready)
            key_gen_handle_q <= key_gen_out;
    end

    // Register writes commit using THIS cycle's address/data directly when
    // do_write fires (not awaddr_q, which would be one cycle stale on the
    // very cycle of acceptance since it's registered from the same event).
    logic [C_S_AXI_ADDR_WIDTH-1:0] write_addr;
    assign write_addr = S_AXI_AWADDR;

    always_ff @(posedge ACLK) begin
        if (reset) begin
            key_stage_q             <= '0;
            key_push_pulse           <= 1'b0;
            key_ctx_err_cnt_q        <= '0;
            key_ctx_error_sticky_q   <= 1'b0;
        end else begin
            key_push_pulse <= 1'b0;   // self-clearing, default deassert

            if (do_write) begin
                unique case (write_addr)
                    ADDR_KEY_IN0: key_stage_q[31:0]    <= wstrobe(key_stage_q[31:0],   S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_KEY_IN1: key_stage_q[63:32]   <= wstrobe(key_stage_q[63:32],  S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_KEY_IN2: key_stage_q[95:64]   <= wstrobe(key_stage_q[95:64],  S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_KEY_IN3: key_stage_q[127:96]  <= wstrobe(key_stage_q[127:96], S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_KEY_CTRL: key_push_pulse       <= S_AXI_WDATA[0];
                    ADDR_ERR_CNT: begin
                        key_ctx_err_cnt_q      <= '0;   // any write clears
                        key_ctx_error_sticky_q <= 1'b0;
                    end
                    default: ; // unmapped: ignored
                endcase
            end

            // Sticky error tracking (independent of the AXI write FSM)
            if (key_ctx_error) begin
                key_ctx_error_sticky_q <= 1'b1;
                if (key_ctx_err_cnt_q != 16'hFFFF)
                    key_ctx_err_cnt_q <= key_ctx_err_cnt_q + 16'h1;
            end
        end
    end

    // Byte-strobed register write helper
    function automatic logic [31:0] wstrobe(
        input logic [31:0] cur,
        input logic [31:0] wdata,
        input logic [3:0]  strb
    );
        logic [31:0] result;
        result = cur;
        if (strb[0]) result[7:0]   = wdata[7:0];
        if (strb[1]) result[15:8]  = wdata[15:8];
        if (strb[2]) result[23:16] = wdata[23:16];
        if (strb[3]) result[31:24] = wdata[31:24];
        return result;
    endfunction

    assign key_in   = key_stage_q;
    assign key_push  = key_push_pulse;

    // ---- Reads ----
    // ========================================================================
    // AXI4-Lite slave : read channel
    // ------------------------------------------------------------------
    // Same principle as the write channel above: ARREADY is purely
    // combinational (gated only by "not currently holding an unconsumed
    // read result"), so any same-cycle logic that reads it (rvalid_q's
    // own acceptance condition, right below) sees the true, current
    // value - no delayed/registered-READY detection stage, and no need
    // for the master to hold ARVALID beyond the single accepting cycle.
    // ========================================================================
    logic rvalid_q;
    logic ar_accept;

    assign ar_accept     = S_AXI_ARVALID && !rvalid_q;
    assign S_AXI_ARREADY = !rvalid_q;

    logic [C_S_AXI_ADDR_WIDTH-1:0] araddr_q;

    always_ff @(posedge ACLK) begin
        if (reset)
            araddr_q <= '0;
        else if (ar_accept)
            araddr_q <= S_AXI_ARADDR;
    end

    always_ff @(posedge ACLK) begin
        if (reset)
            rvalid_q <= 1'b0;
        else if (ar_accept)
            rvalid_q <= 1'b1;
        else if (S_AXI_RVALID && S_AXI_RREADY)
            rvalid_q <= 1'b0;
    end
    assign S_AXI_RVALID = rvalid_q;
    assign S_AXI_RRESP  = AXI_OK;

    logic [31:0] key_status_word;
    assign key_status_word = {
        21'b0,
        key_ctx_error_sticky_q,      // [10]
        bank_busy_total,              // [9:8]
        bank_free,                    // [7:6]
        bank_valid,                   // [5:4]
        active_key_bank,              // [3]
        key_available,                // [2]
        key_system_busy,              // [1]
        key_push_ready                // [0]
    };

    // FIX (timing): key_status_word above is combinational on live
    // pipeline state several logic levels deep inside aes_top
    // (bank_busy_total/bank_free/key_system_busy all trace back to the
    // encrypt/decrypt pipelines' final-stage valid registers - see
    // AES_Encrypt.sv's bank_busy block). Reading it straight into the
    // S_AXI_RDATA mux put that whole cone directly on a top-level
    // output pin and was the #1 worst-slack family in synthesis (19 of
    // 20 worst paths - see diagnostic report, Section 5).
    //
    // Capture it into a register every cycle (unconditionally - this
    // is a free-running status snapshot, not gated on anything) and
    // have the read mux select the SNAPSHOT instead of the live word.
    // AXI4-Lite places no requirement on how "live" a status register's
    // value is as of the read; this adds at most one clock's staleness
    // (10 ns at 100 MHz) to KEY_STATUS reads, which is immaterial for a
    // control/debug register polled by software, and it does not touch
    // the read-channel handshake (ar_accept/rvalid_q) at all.
    logic [31:0] status_snapshot_q;
    always_ff @(posedge ACLK) begin
        if (reset)
            status_snapshot_q <= 32'h0;
        else
            status_snapshot_q <= key_status_word;
    end

    always_comb begin
        unique case (araddr_q)
            ADDR_KEY_STATUS: S_AXI_RDATA = status_snapshot_q;
            ADDR_KEY_GEN:    S_AXI_RDATA = {16'b0, key_gen_handle_q};
            ADDR_BANK_GEN:   S_AXI_RDATA = {bank_gen_flat[2*KEY_GEN_W-1:KEY_GEN_W],
                                             bank_gen_flat[KEY_GEN_W-1:0]};
            ADDR_ERR_CNT:    S_AXI_RDATA = {16'b0, key_ctx_err_cnt_q};
            ADDR_VERSION:    S_AXI_RDATA = 32'h41455331; // "AES1"
            default:         S_AXI_RDATA = 32'h0;
        endcase
    end

endmodule

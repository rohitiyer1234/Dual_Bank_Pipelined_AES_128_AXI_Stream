
`timescale 1ns/1ps
// ============================================================================
//  key_system_top.sv  (FIXED)
// ============================================================================
//
//  BUGS FIXED
//  ----------
//
//  BUG-KST1 [CRITICAL]: expand_enable not connected to AES_Key_Expansion_128.
//    The original instantiation omitted .expand_enable().  The module port
//    was left undriven → synthesis resolves it to 0 (or X in simulation),
//    so the expansion FSM inside AES_Key_Expansion_128 never advanced past
//    the start cycle.  No round keys beyond K0 were ever written.
//    FIX: Wire expand_enable = 1'b1.  The expansion engine should always be
//    allowed to run once started.  The controller already gates start via
//    exp_start.  Gating expand_enable is not needed and was harmful.
//
//  BUG-KST2: active_bank logic always picks bank0 if bank_valid[0] is set,
//    even if bank1 was loaded more recently.  Under normal dual-bank
//    rotation (bank0 loaded, then bank1 loaded), the pipeline always uses
//    bank0, never transitioning to the newer key in bank1.
//    FIX: Track the bank most recently signaled as valid.  When exp_done
//    fires, record write_bank as the new active_bank.
//
//  BUG-KST3: bank_release can assert both bits simultaneously when both
//    banks are valid, busy==0, and a new key is pending.  This clears both
//    banks in keymem_dual, leaving no valid key for in-flight pipeline data
//    even briefly.  Only one bank needs to be released at a time; priority
//    encoder prevents double-release.
//    FIX: Release bank0 first if both conditions are met; only release
//    bank1 if bank0 is not being released this cycle.
//
// ============================================================================

import aes_pkg::*;

module key_system_top(

    input  logic        clk,
    input  logic        reset,

    // =========================================================================
    // KEY INPUT
    // =========================================================================

    input  logic        push,
    input  aes_block_t  key_in,

    // =========================================================================
    // PIPELINE FEEDBACK
    // =========================================================================

    input  logic [1:0]  bank_busy,

    // =========================================================================
    // OUTPUTS
    // =========================================================================

    output rk_store_t   round_keys,

    output logic [1:0]  bank_valid,
    output logic [1:0]  bank_free,

    output logic        key_system_busy,

    output logic        key_available,

    output logic        active_bank,

    // =========================================================================
    // FIX (key-sync): key-context generation handle interface
    // =========================================================================
    // key_push_ready: combinational, = !fifo_full. A push issued while
    //   this is low is dropped by key_fifo (as before), but the caller
    //   now has a way to know that happened instead of the key silently
    //   vanishing.
    // key_gen_out: the handle assigned to the key accepted THIS cycle
    //   (valid when push && key_push_ready). Software stores this and
    //   later presents it back on the data channel as key_gen; the core
    //   will only accept a transaction whose key_gen matches the
    //   generation currently resident in the bank it names.
    // bank_gen: per-bank handle of whichever key that bank currently
    //   holds - readable at any time as a status/debug field.
    // =========================================================================
    output logic        key_push_ready,
    output key_gen_t    key_gen_out,
    output logic [NUM_BANKS*KEY_GEN_W-1:0] bank_gen_flat
);

    // =========================================================================
    // FIFO SIGNALS
    // =========================================================================

    logic fifo_empty;
    logic fifo_full;
    logic fifo_pop;
    aes_block_t fifo_key;
    key_gen_t   fifo_gen;

    // =========================================================================
    // FIX (key-sync): push-side generation counter
    // =========================================================================
    // Monotonic counter, one increment per key accepted into the FIFO.
    // The value assigned to THIS push is the counter's current value
    // (pre-increment) - echoed out combinationally as key_gen_out so the
    // caller gets its handle back in the same cycle it pushes, with no
    // possibility of racing a later push's handle.
    // =========================================================================
    key_gen_t push_gen_counter;
    logic     fifo_accept;

    assign key_push_ready = !fifo_full;
    assign fifo_accept    = push && key_push_ready;
    assign key_gen_out    = push_gen_counter;

    always_ff @(posedge clk) begin
        if (reset)
            push_gen_counter <= '0;
        else if (fifo_accept)
            push_gen_counter <= push_gen_counter + 1'b1;
    end

    // =========================================================================
    // CONTROLLER SIGNALS
    // =========================================================================

    logic     exp_start;
    logic     write_bank;
    logic     exp_done;
    key_gen_t write_gen;

    // FIX (key-sync) - TIMING NOTE: write_gen must NOT be captured at the
    // same edge as start_condition/write_bank. key_fifo's data_out is a
    // registered (non-lookahead) output that only reflects the popped
    // entry starting the cycle AFTER the pop occurs - AES_Key_Expansion_128
    // already accounts for this by consuming key_in gated on `exp_start`
    // (itself already one edge delayed from start_condition), not on
    // start_condition directly (see the timing note in
    // AES_Key_Expansion.sv). write_gen must follow the exact same
    // delayed-by-one-edge timing as key_in/fifo_key, or it latches the
    // PREVIOUS pop's (or reset-time) value instead of the current key's -
    // exactly the bug this comment replaces (caught by tb_key_sync_fix.sv
    // failing on the second key load: bank_gen for the second bank stayed
    // at its reset value of 0 instead of the freshly-pushed key's actual
    // handle).
    always_ff @(posedge clk) begin
        if (reset)
            write_gen <= '0;
        else if (exp_start)
            write_gen <= fifo_gen;
    end

    // =========================================================================
    // EXPANSION SIGNALS
    // =========================================================================

    logic        w_en;
    logic [3:0]  waddr;
    aes_block_t  wkey;

    // =========================================================================
    // BANK RELEASE
    // =========================================================================

    logic [1:0] bank_release;

    // =========================================================================
    // FIFO
    // =========================================================================

    // FIX (key-sync): FIFO now carries {gen_handle, key} as one atomic
    // entry (WIDTH = 128 + KEY_GEN_W) so the handle can never desync
    // from the key it was assigned to, even under back-to-back pushes.
    logic [aes_pkg::KEY_GEN_W+127:0] fifo_din, fifo_dout;
    assign fifo_din       = {push_gen_counter, key_in};
    assign {fifo_gen, fifo_key} = fifo_dout;

    key_fifo #(
        .WIDTH (aes_pkg::KEY_GEN_W + 128),
        .DEPTH (aes_pkg::KEY_FIFO_DEPTH)
    ) fifo_inst(
        .clk(clk),
        .reset(reset),
        .push(push),
        .data_in(fifo_din),
        .pop(fifo_pop),
        .data_out(fifo_dout),
        .empty(fifo_empty),
        .full(fifo_full)
    );

    // =========================================================================
    // CONTROLLER
    // =========================================================================

    key_controller ctrl_inst(
        .clk(clk),
        .reset(reset),
        .key_valid(!fifo_empty),
        .key_ready(fifo_pop),
        .bank_free(bank_free),
        .exp_done(exp_done),
        .exp_start(exp_start),
        .write_bank(write_bank)
    );

    // =========================================================================
    // KEY EXPANSION
    // FIX-KST1: expand_enable tied to 1'b1 - expansion always runs once
    //           started.  Gating it was preventing key derivation.
    // =========================================================================

    AES_Key_Expansion_128 expand_inst(
        .clk(clk),
        .reset(reset),
        .exp_start(exp_start),
        .expand_enable(1'b1),       // FIX-KST1: was left unconnected → 0/X
        .key_in(fifo_key),
        .w_en(w_en),
        .waddr(waddr),
        .wkey(wkey),
        .done(exp_done)
    );

    // =========================================================================
    // BANK RELEASE CONTROL
    // FIX-KST3: priority encoder - never release both banks simultaneously
    //
    // POLICY:
    //   Release a bank ONLY IF:
    //   1. New key is pending in FIFO
    //   2. No free bank exists
    //   3. Bank is currently idle (not busy in pipeline)
    //   4. Bank is currently valid
    //   Priority: bank0 before bank1
    // =========================================================================

    always_ff @(posedge clk) begin

        if (reset)
            bank_release <= 2'b00;
        else begin

            bank_release <= 2'b00;

            if (
                !fifo_empty           &&
                (bank_free == 2'b00)  &&
                bank_valid[0]         &&
                !bank_busy[0]
            ) begin
                // FIX-KST3: only release bank0
                bank_release[0] <= 1'b1;
            end

            else if (
                !fifo_empty           &&
                (bank_free == 2'b00)  &&
                bank_valid[1]         &&
                !bank_busy[1]
            ) begin
                // FIX-KST3: only release bank1 if bank0 not being released
                bank_release[1] <= 1'b1;
            end

        end

    end

    // =========================================================================
    // KEY MEMORY
    // =========================================================================

    keymem_dual keymem_inst(
        .clk(clk),
        .reset(reset),
        .w_en(w_en),
        .waddr(waddr),
        .wkey(wkey),
        .write_bank(write_bank),
        .write_gen(write_gen),
        .bank_release(bank_release),
        .bank_busy(bank_busy),
        .round_keys(round_keys),
        .bank_valid(bank_valid),
        .bank_free(bank_free),
        .bank_gen_flat(bank_gen_flat)
    );

    // =========================================================================
    // ACTIVE BANK TRACKING
    // FIX-KST2: track the most recently loaded bank (by watching exp_done)
    //           rather than always preferring bank0.
    // =========================================================================

    always_ff @(posedge clk) begin

        if (reset)
            active_bank <= 1'b0;
        else begin
            // When expansion completes, the written bank becomes active
            if (exp_done)
                active_bank <= write_bank;
        end

    end

    // =========================================================================
    // KEY AVAILABLE
    // =========================================================================

    always_comb begin
        key_available = 1'b0;
        if (bank_valid[0]) key_available = 1'b1;
        if (bank_valid[1]) key_available = 1'b1;
    end

    // =========================================================================
    // KEY SYSTEM BUSY
    // =========================================================================

    always_comb begin
        key_system_busy = 1'b0;
        if (!fifo_empty)          key_system_busy = 1'b1;
        if (bank_busy != 2'b00)   key_system_busy = 1'b1;
    end

endmodule
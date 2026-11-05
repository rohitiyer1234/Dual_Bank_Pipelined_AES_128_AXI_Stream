// ============================================================================
//  aes_top.sv
//
//  Top-level AES-128 hardware-accelerator core.
//  Encases: key_system_top (dual-bank key expansion) + AES_Encrypt +
//           AES_Decrypt, behind one plaintext/ciphertext data channel and
//           one key-load channel.
//
//  This is deliberately built as a plain valid/ready core so it drops
//  cleanly behind future AXI4-Stream (data in/out) and AXI4-Lite
//  (control/status) shells:
//    - in_valid/in_ready/data_in/op_mode/current_bank  <- AXI4-Stream slave
//      (TDATA = data_in, TUSER = {current_bank, op_mode} is a natural fit)
//    - out_valid/out_ready/data_out                    -> AXI4-Stream master
//    - key_push/key_in                                 <- AXI4-Lite write
//      (key material would be staged through an AXI4-Lite write FIFO)
//    - bank_valid/bank_free/key_system_busy/key_available/active_key_bank
//                                                       -> AXI4-Lite status
//
//  SINGLE-ACTIVE-ENGINE ARBITRATION
//  ---------------------------------
//  AES_Encrypt and AES_Decrypt are two independent pipelines, each with
//  its own in-flight-item tracking (bank_busy) and its own out_valid.
//  If both were allowed in flight at once, their two out_valid streams
//  would have to be merged onto one data_out/out_valid bus with no way
//  to guarantee ordering or avoid same-cycle collisions.
//
//  Rather than build a reorder buffer, this wrapper enforces a simple,
//  provably-safe policy: a new transaction of one mode (encrypt/decrypt)
//  is only accepted while the OTHER engine is fully drained (its
//  bank_busy == 0, i.e. it holds no in-flight items and therefore can
//  never produce another out_valid pulse). This guarantees the two
//  engines' out_valid signals are mutually exclusive at every cycle, so
//  data_out/out_valid can be a simple OR-mux with no arbitration logic
//  and no ordering hazard. The cost is a stall when switching direction
//  while the previous direction's pipeline is still draining (up to
//  PIPE_DEPTH cycles) - acceptable for a control-plane-driven
//  accelerator where direction switches are infrequent relative to
//  streamed block counts.
//
//  KEY MATERIAL IS NOT EXPOSED ON TOP-LEVEL PORTS
//  ------------------------------------------------
//  round_keys / wkey never appear on the aes_top boundary. Only status
//  (which banks are valid/free/busy) is exposed, matching normal
//  accelerator practice of not routing key material to observable pins.
//  A testbench that needs to check key correctness reads the internal
//  round_keys bus via hierarchical reference (dut.round_keys), as done
//  in tb_aes_top.sv.
// ============================================================================

`timescale 1ns/1ps

module aes_top
    import aes_pkg::*;
(
    input  logic        clk,
    input  logic        reset,

    // =========================================================================
    // KEY LOAD CHANNEL  (future: staged from AXI4-Lite)
    // =========================================================================
    input  logic        key_push,
    input  aes_block_t  key_in,

    // FIX (key-sync): handle returned for the key accepted THIS cycle
    // (valid when key_push && key_push_ready). Software must hold onto
    // this and echo it back as key_gen on the data channel below.
    output logic         key_push_ready,
    output key_gen_t      key_gen_out,

    // =========================================================================
    // DATA CHANNEL  (future: AXI4-Stream slave/master)
    // =========================================================================
    input  logic         op_mode,       // 0 = encrypt (data_in = plaintext)
                                         // 1 = decrypt (data_in = ciphertext)
    input  logic         current_bank,  // which key bank this transaction uses

    // FIX (key-sync): the generation handle the caller believes bank
    // `current_bank` still holds. This is the actual fix for the
    // key/data desynchronization gap: previously current_bank was a
    // bare 1-bit index supplied by an external master with no hardware
    // guarantee that the bank still contains the key the master
    // intended (the bank could since have been released and reloaded
    // with a different key - a real race if the master queues data
    // faster than it re-checks status, or has a software bug). A
    // transaction is now only accepted if key_gen matches
    // bank_gen[current_bank] at that instant; on a mismatch the core
    // simply withholds in_ready (identical in shape to the existing
    // bank_valid[current_bank] gate) rather than silently encrypting
    // or decrypting under the wrong key. key_ctx_error pulses for
    // exactly one cycle whenever a transaction is refused for this
    // reason, so the mismatch is observable (e.g. wired to an
    // interrupt/status bit in the AXI4-Lite shell) instead of merely
    // showing up as unexplained backpressure.
    input  key_gen_t     key_gen,

    input  logic         in_valid,
    output logic         in_ready,
    input  aes_block_t   data_in,

    output aes_block_t   data_out,
    output logic         out_valid,
    input  logic         out_ready,

    // =========================================================================
    // STATUS  (future: AXI4-Lite read-only registers)
    // =========================================================================
    output logic [1:0]  bank_valid,
    output logic [1:0]  bank_free,
    output logic         key_system_busy,
    output logic         key_available,
    output logic         active_key_bank,

    // Aggregate busy across BOTH pipelines, per bank - useful top-level
    // "is bank N safe to reuse/reload" status independent of direction.
    output logic [1:0]  bank_busy_total,

    // FIX (key-sync): per-bank generation handle (debug/status - lets a
    // control-plane read back "what key context is bank N holding"
    // without racing a data-plane push), plus the one-cycle mismatch
    // strobe described above.
    output logic [NUM_BANKS*KEY_GEN_W-1:0] bank_gen_flat,
    output logic         key_ctx_error
);

    // ========================================================================
    // KEY SYSTEM
    // ========================================================================
    rk_store_t   round_keys;
    logic [1:0]  bank_busy_agg;

    key_system_top ksys_inst (
        .clk             (clk),
        .reset           (reset),
        .push            (key_push),
        .key_in          (key_in),
        .bank_busy       (bank_busy_agg),
        .round_keys      (round_keys),
        .bank_valid      (bank_valid),
        .bank_free       (bank_free),
        .key_system_busy (key_system_busy),
        .key_available   (key_available),
        .active_bank     (active_key_bank),
        .key_push_ready  (key_push_ready),
        .key_gen_out     (key_gen_out),
        .bank_gen_flat   (bank_gen_flat)
    );

    // ========================================================================
    // FIX (key-sync): key-context acceptance gate
    // ------------------------------------------------------------------
    // A transaction is only well-formed if the generation it names
    // (key_gen) still matches what that bank currently holds
    // (bank_gen[current_bank]). This is evaluated combinationally from
    // already-registered state (bank_gen), same timing class as the
    // existing bank_valid[current_bank] check it sits beside.
    // ========================================================================
    logic key_ctx_ok;
    assign key_ctx_ok    = (key_gen == bank_gen_flat[current_bank*KEY_GEN_W +: KEY_GEN_W]);
    assign key_ctx_error = in_valid && bank_valid[current_bank] && !key_ctx_ok;

    // ========================================================================
    // SINGLE-ACTIVE-ENGINE ARBITRATION
    // ========================================================================
    logic [1:0] enc_bank_busy, dec_bank_busy;

    assign bank_busy_agg    = enc_bank_busy | dec_bank_busy;
    assign bank_busy_total  = enc_bank_busy | dec_bank_busy;

    // A mode may accept a new transaction only while the OTHER engine has
    // nothing in flight - guarantees the two out_valid streams below are
    // mutually exclusive at every cycle (see header comment).
    logic enc_gate, dec_gate;
    assign enc_gate = (dec_bank_busy == 2'b00);
    assign dec_gate = (enc_bank_busy == 2'b00);

    logic enc_in_valid, dec_in_valid;
    logic enc_in_ready, dec_in_ready;

    // FIX (key-sync): key_ctx_ok gates acceptance exactly like bank_valid
    // does inside AES_Encrypt/AES_Decrypt (accept = in_valid &&
    // bank_valid[current_bank] && !stall) - a mismatched generation
    // simply never reaches enc_in_valid/dec_in_valid, so it can never be
    // accepted into the pipeline under the wrong key.
    assign enc_in_valid = in_valid && !op_mode && enc_gate && key_ctx_ok;
    assign dec_in_valid = in_valid &&  op_mode && dec_gate && key_ctx_ok;

    always_comb begin
        if (!op_mode)
            in_ready = enc_gate && key_ctx_ok && enc_in_ready;
        else
            in_ready = dec_gate && key_ctx_ok && dec_in_ready;
    end

    // ========================================================================
    // ENCRYPT PIPELINE
    // ========================================================================
    aes_block_t enc_ciphertext;
    logic       enc_out_valid;
    logic       enc_out_ready;
    logic [1:0] enc_bank_valid_in;

    // Encrypt/decrypt must only ever see a bank as "valid" once the key
    // system also reports it valid - straight pass-through, kept as a
    // separate wire for readability at the integration boundary.
    assign enc_bank_valid_in = bank_valid;

    AES_Encrypt enc_inst (
        .clk          (clk),
        .reset        (reset),
        .in_valid     (enc_in_valid),
        .in_ready     (enc_in_ready),
        .plaintext    (data_in),
        .current_bank (current_bank),
        .round_keys   (round_keys),
        .bank_busy    (enc_bank_busy),
        .bank_valid   (enc_bank_valid_in),
        .ciphertext   (enc_ciphertext),
        .out_valid    (enc_out_valid),
        .out_ready    (enc_out_ready)
    );

    // ========================================================================
    // DECRYPT PIPELINE
    // ========================================================================
    aes_block_t dec_plaintext;
    logic       dec_out_valid;
    logic       dec_out_ready;
    logic [1:0] dec_bank_valid_in;

    assign dec_bank_valid_in = bank_valid;

    AES_Decrypt dec_inst (
        .clk          (clk),
        .reset        (reset),
        .in_valid     (dec_in_valid),
        .in_ready     (dec_in_ready),
        .ciphertext   (data_in),
        .current_bank (current_bank),
        .round_keys   (round_keys),
        .bank_busy    (dec_bank_busy),
        .bank_valid   (dec_bank_valid_in),
        .plaintext    (dec_plaintext),
        .out_valid    (dec_out_valid),
        .out_ready    (dec_out_ready)
    );

    // ========================================================================
    // OUTPUT MUX
    // Safe OR-mux: enc_out_valid and dec_out_valid are guaranteed mutually
    // exclusive by the arbitration policy above (see header).
    // ========================================================================
    assign enc_out_ready = out_ready;
    assign dec_out_ready = out_ready;

    assign out_valid = enc_out_valid | dec_out_valid;
    assign data_out   = enc_out_valid ? enc_ciphertext : dec_plaintext;

    // ------------------------------------------------------------------------
    // Design-time assertion: the mutual-exclusion guarantee this wrapper
    // relies on must never be violated. If it ever fires, the arbitration
    // gating above has a hole and the output mux is no longer safe.
    // ------------------------------------------------------------------------
    // synthesis translate_off
    always_ff @(posedge clk) begin
        if (!reset) begin
            if (enc_out_valid && dec_out_valid)
                $error("[aes_top] ASSERTION FAILED: enc_out_valid and dec_out_valid both high at t=%0t - output mux is unsafe", $time);
        end
    end
    // synthesis translate_on

endmodule : aes_top

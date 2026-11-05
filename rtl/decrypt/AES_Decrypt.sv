// ============================================================================
// AES_Decrypt.sv
//
// Pipelined AES-128 straightforward (non-equivalent) inverse cipher.
// Mirrors AES_Encrypt.sv exactly: same PIPE_DEPTH (NUM_ROUNDS+1), same
// stall/accept/handshake logic, same dual-bank round_keys/bank_valid/
// bank_busy interface to keymem_dual. Only the per-stage transform and
// the round-key indexing order differ (keys are consumed K10 -> K0).
//
// Per-stage transform (straightforward inverse cipher, FIPS-197 5.3):
//   Stage 0            : ciphertext ^ K[NUM_ROUNDS]                 (ARK K10)
//   Stage r (1..N-1)   : InvShiftRows -> InvSubBytes -> ARK(K[N-r]) -> InvMixColumns
//   Stage N (final)    : InvShiftRows -> InvSubBytes -> ARK(K[0])   (no InvMixColumns)
//
// This is the exact structural mirror of AES_Encrypt's
//   Stage r (1..N-1): SubBytes -> ShiftRows -> MixColumns -> ARK(K[r])
//   Stage N (final)  : SubBytes -> ShiftRows -> ARK(K[N])
// with the operation order reversed and round keys walked backwards,
// which is what turns the encrypt pipeline into its algorithmic inverse.
// ============================================================================

module AES_Decrypt
    import aes_pkg::*;
#(
    parameter int NUM_ROUNDS = aes_pkg::NUM_ROUNDS,
    parameter int PIPE_DEPTH = aes_pkg::PIPE_DEPTH
)(
    input  logic       clk,
    input  logic       reset,

    input  logic       in_valid,
    output logic       in_ready,
    input  aes_block_t ciphertext,

    input  logic       current_bank,

    input  rk_store_t  round_keys,
    output logic [1:0] bank_busy,
    input  logic [1:0] bank_valid,

    output aes_block_t plaintext,
    output logic       out_valid,
    input  logic       out_ready


);
    aes_block_t state [0:PIPE_DEPTH-1];
    logic       valid [0:PIPE_DEPTH-1];
    logic       bank  [0:PIPE_DEPTH-1];
    logic       stall;
    logic       accept;

    assign stall    = valid[PIPE_DEPTH-1] && !out_ready ;
    assign accept = in_valid  && bank_valid[current_bank]  && !stall;

    assign in_ready = !stall && bank_valid[current_bank];

    always_comb begin
        bank_busy = 2'b00;
        for (int i = 0; i < PIPE_DEPTH; i++)
            if (valid[i])
                bank_busy[bank[i]] = 1'b1;
    end

    // Stage 0 - AddRoundKey(K[NUM_ROUNDS])  (first inverse-cipher step: undo final ARK)
   always_ff @(posedge clk) begin

    if(reset) begin
        valid[0] <= 1'b0;
        state[0] <= '0;
        bank[0]  <= '0;
    end
    else if(!stall) begin

        valid[0] <= accept;

        if(accept) begin
            bank[0]  <= current_bank;
            state[0] <= ciphertext ^
                         round_keys[current_bank][NUM_ROUNDS];
        end
    end
end

    // Stages 1..NUM_ROUNDS-1 - InvSR -> InvSB -> ARK(K[NUM_ROUNDS-r]) -> InvMC
    generate
        for (genvar r = 1; r < NUM_ROUNDS; r++) begin : DEC_STAGE
            aes_block_t isr, isb, mc;
            InvShiftRows  u_isr (.inp(state[r-1]), .out(isr));
            InvSubBytes   u_isb (.inp(isr),        .res(isb));
            InvMixColumns u_imc (.inp(isb ^ round_keys[bank[r-1]][NUM_ROUNDS-r]), .res(mc));

            always_ff @(posedge clk) begin
                if (reset) begin
                    valid[r] <= '0;
                    state[r] <= '0;
                    bank[r]  <= '0;
                end else if (!stall) begin
                    valid[r] <= valid[r-1];
                    bank[r]  <= bank[r-1];
                    state[r] <= mc;
                end
            end
        end
    endgenerate

    // Stage NUM_ROUNDS (final) - InvSR -> InvSB -> ARK(K[0]), no InvMixColumns
    aes_block_t isr_final, isb_final;
    InvShiftRows u_isr_final (.inp(state[NUM_ROUNDS-1]), .out(isr_final));
    InvSubBytes  u_isb_final (.inp(isr_final),           .res(isb_final));

    always_ff @(posedge clk) begin
        if (reset) begin
            valid[NUM_ROUNDS] <= '0;
            state[NUM_ROUNDS] <= '0;
            bank[NUM_ROUNDS]  <= '0;
        end else if (!stall) begin
            valid[NUM_ROUNDS] <= valid[NUM_ROUNDS-1];
            bank[NUM_ROUNDS]  <= bank[NUM_ROUNDS-1];
            state[NUM_ROUNDS] <= isb_final ^ round_keys[bank[NUM_ROUNDS-1]][0];
        end
    end

    assign plaintext = state[NUM_ROUNDS];
    assign out_valid = valid[NUM_ROUNDS];

endmodule : AES_Decrypt
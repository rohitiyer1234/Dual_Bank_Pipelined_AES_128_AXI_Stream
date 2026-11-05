module AES_Encrypt
    import aes_pkg::*;
#(
    parameter int NUM_ROUNDS = aes_pkg::NUM_ROUNDS,
    parameter int PIPE_DEPTH = aes_pkg::PIPE_DEPTH
)(
    input  logic       clk,
    input  logic       reset,
    
    input  logic       in_valid,
    output logic       in_ready,
    input  aes_block_t plaintext,
    
    input  logic       current_bank,
    
    input  rk_store_t  round_keys,
    output logic [1:0] bank_busy,
    input logic  [1:0] bank_valid,
    
    output aes_block_t ciphertext,
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
 
    // Stage 0 - AddRoundKey(K0)
   always_ff @(posedge clk) begin

    if(reset) begin
        valid[0] <= 1'b0;
        state[0] <= '0;
        bank[0]  <= '0;
    end
    else if(!stall) begin

        valid[0] <= accept;

        if(accept) begin
            //$display( "[ACCEPT] t=%0t bank=%0d pt=%032h",  $time,  current_bank,  plaintext);
            bank[0]  <= current_bank;
            state[0] <= plaintext ^
                         round_keys[current_bank][0];
        end
    end
end
 
    // Stages 1..NUM_ROUNDS-1 - SB → SR → MC → ARK
    generate
        for (genvar r = 1; r < NUM_ROUNDS; r++) begin : ENC_STAGE
            aes_block_t sb, sr, mc;
            SubBytes  u_sb (.inp(state[r-1]), .res(sb));
            ShiftRows u_sr (.inp(sb),         .out(sr));
            MixColumns u_mc(.inp(sr),         .res(mc));
 
            always_ff @(posedge clk) begin
                if (reset) begin
                    valid[r] <= '0;
                    state[r] <= '0;
                    bank[r]  <= '0;
                end else if (!stall) begin
                    valid[r] <= valid[r-1];
                    bank[r]  <= bank[r-1];
                    state[r] <= mc ^ round_keys[bank[r-1]][r];
                end
            end
        end
    endgenerate
 
    // Stage NUM_ROUNDS (final) - SB → SR → ARK(K10), no MixColumns
    aes_block_t sb_final, sr_final;
    SubBytes  u_sb_final (.inp(state[NUM_ROUNDS-1]), .res(sb_final));
    ShiftRows u_sr_final (.inp(sb_final),            .out(sr_final));
 
    always_ff @(posedge clk) begin
        if (reset) begin
            valid[NUM_ROUNDS] <= '0;
            state[NUM_ROUNDS] <= '0;
            bank[NUM_ROUNDS]  <= '0;
        end else if (!stall) begin
            valid[NUM_ROUNDS] <= valid[NUM_ROUNDS-1];
            bank[NUM_ROUNDS]  <= bank[NUM_ROUNDS-1];
            state[NUM_ROUNDS] <= sr_final ^ round_keys[bank[NUM_ROUNDS-1]][NUM_ROUNDS];
        end
    end
 
    assign ciphertext = state[NUM_ROUNDS];
    assign out_valid  = valid[NUM_ROUNDS];
 
endmodule : AES_Encrypt
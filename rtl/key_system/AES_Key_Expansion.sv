// ============================================================================
//  AES_Key_Expansion_128.sv
//
//  STATUS: This module was referenced by key_system_top.sv (instance
//  expand_inst) but was NOT present in the supplied design files. It is
//  the actual Rijndael key-schedule engine and is therefore the core of
//  "the complete key expansion unit" - without it the dual-bank
//  architecture has no key source and cannot function at all.
//  Implemented from scratch here per FIPS-197 Sec. 5.2, matching the
//  port list key_system_top.sv already assumes:
//
//      .clk, .reset, .exp_start, .expand_enable, .key_in,
//      .w_en, .waddr, .wkey, .done
//
//  ALGORITHM
//  ---------
//  Round key 0 = the raw 128-bit input key (W0..W3).
//  For r = 1..10:
//      temp   = W[4r-1]
//      temp   = SubWord(RotWord(temp)) ^ (Rcon[r] << 24)
//      W[4r]  = W[4r-4] ^ temp
//      W[4r+1]= W[4r]   ^ W[4r-3]
//      W[4r+2]= W[4r+1] ^ W[4r-2]
//      W[4r+3]= W[4r+2] ^ W[4r-1]
//
//  One 128-bit round key is produced and written per clock cycle:
//  cycle 0 (exp_start) writes round key 0 directly from key_in; the
//  following 10 cycles (gated by expand_enable) each derive and write
//  one further round key. `done` pulses for exactly one cycle, aligned
//  with the w_en/waddr/wkey for round key 10 (the final write) - the
//  same cycle key_controller expects to see exp_done to close out the
//  active expansion.
//
//  INTERFACE CONTRACT / TIMING NOTE
//  ---------------------------------
//  key_controller registers exp_start and write_bank from the SAME
//  cycle's start_condition, and key_fifo registers data_out from the
//  same cycle's pop pulse. Because both use identical registered
//  timing, fifo_key (routed to key_in here) is already valid on the
//  same clock edge exp_start is asserted - so key_in is safe to latch
//  directly on the exp_start cycle without an extra sync stage.
//
//  A new expansion must not be started (exp_start) while a previous one
//  is still active; key_controller already enforces this via its
//  `active` flag, so no re-entrancy guard is duplicated here.
// ============================================================================

`timescale 1ns/1ps

module AES_Key_Expansion_128
    import aes_pkg::*;
(
    input  logic        clk,
    input  logic        reset,

    input  logic        exp_start,      // 1-cycle pulse: begin expansion, key_in valid
    input  logic        expand_enable,  // gates the round-by-round advance

    input  aes_block_t  key_in,

    output logic        w_en,
    output logic [3:0]  waddr,
    output aes_block_t  wkey,

    output logic        done
);

    // ========================================================================
    // Standard forward AES S-box (FIPS-197 Fig. 7), 256 entries.
    // Implemented as a case-statement function (synthesizes to a ROM/LUT) -
    // more portable across tools than an unpacked-array localparam.
    // ========================================================================
    function automatic aes_byte_t sbox_lookup(input aes_byte_t a);
        case (a)
            8'h00:sbox_lookup=8'h63; 8'h01:sbox_lookup=8'h7c; 8'h02:sbox_lookup=8'h77; 8'h03:sbox_lookup=8'h7b;
            8'h04:sbox_lookup=8'hf2; 8'h05:sbox_lookup=8'h6b; 8'h06:sbox_lookup=8'h6f; 8'h07:sbox_lookup=8'hc5;
            8'h08:sbox_lookup=8'h30; 8'h09:sbox_lookup=8'h01; 8'h0a:sbox_lookup=8'h67; 8'h0b:sbox_lookup=8'h2b;
            8'h0c:sbox_lookup=8'hfe; 8'h0d:sbox_lookup=8'hd7; 8'h0e:sbox_lookup=8'hab; 8'h0f:sbox_lookup=8'h76;
            8'h10:sbox_lookup=8'hca; 8'h11:sbox_lookup=8'h82; 8'h12:sbox_lookup=8'hc9; 8'h13:sbox_lookup=8'h7d;
            8'h14:sbox_lookup=8'hfa; 8'h15:sbox_lookup=8'h59; 8'h16:sbox_lookup=8'h47; 8'h17:sbox_lookup=8'hf0;
            8'h18:sbox_lookup=8'had; 8'h19:sbox_lookup=8'hd4; 8'h1a:sbox_lookup=8'ha2; 8'h1b:sbox_lookup=8'haf;
            8'h1c:sbox_lookup=8'h9c; 8'h1d:sbox_lookup=8'ha4; 8'h1e:sbox_lookup=8'h72; 8'h1f:sbox_lookup=8'hc0;
            8'h20:sbox_lookup=8'hb7; 8'h21:sbox_lookup=8'hfd; 8'h22:sbox_lookup=8'h93; 8'h23:sbox_lookup=8'h26;
            8'h24:sbox_lookup=8'h36; 8'h25:sbox_lookup=8'h3f; 8'h26:sbox_lookup=8'hf7; 8'h27:sbox_lookup=8'hcc;
            8'h28:sbox_lookup=8'h34; 8'h29:sbox_lookup=8'ha5; 8'h2a:sbox_lookup=8'he5; 8'h2b:sbox_lookup=8'hf1;
            8'h2c:sbox_lookup=8'h71; 8'h2d:sbox_lookup=8'hd8; 8'h2e:sbox_lookup=8'h31; 8'h2f:sbox_lookup=8'h15;
            8'h30:sbox_lookup=8'h04; 8'h31:sbox_lookup=8'hc7; 8'h32:sbox_lookup=8'h23; 8'h33:sbox_lookup=8'hc3;
            8'h34:sbox_lookup=8'h18; 8'h35:sbox_lookup=8'h96; 8'h36:sbox_lookup=8'h05; 8'h37:sbox_lookup=8'h9a;
            8'h38:sbox_lookup=8'h07; 8'h39:sbox_lookup=8'h12; 8'h3a:sbox_lookup=8'h80; 8'h3b:sbox_lookup=8'he2;
            8'h3c:sbox_lookup=8'heb; 8'h3d:sbox_lookup=8'h27; 8'h3e:sbox_lookup=8'hb2; 8'h3f:sbox_lookup=8'h75;
            8'h40:sbox_lookup=8'h09; 8'h41:sbox_lookup=8'h83; 8'h42:sbox_lookup=8'h2c; 8'h43:sbox_lookup=8'h1a;
            8'h44:sbox_lookup=8'h1b; 8'h45:sbox_lookup=8'h6e; 8'h46:sbox_lookup=8'h5a; 8'h47:sbox_lookup=8'ha0;
            8'h48:sbox_lookup=8'h52; 8'h49:sbox_lookup=8'h3b; 8'h4a:sbox_lookup=8'hd6; 8'h4b:sbox_lookup=8'hb3;
            8'h4c:sbox_lookup=8'h29; 8'h4d:sbox_lookup=8'he3; 8'h4e:sbox_lookup=8'h2f; 8'h4f:sbox_lookup=8'h84;
            8'h50:sbox_lookup=8'h53; 8'h51:sbox_lookup=8'hd1; 8'h52:sbox_lookup=8'h00; 8'h53:sbox_lookup=8'hed;
            8'h54:sbox_lookup=8'h20; 8'h55:sbox_lookup=8'hfc; 8'h56:sbox_lookup=8'hb1; 8'h57:sbox_lookup=8'h5b;
            8'h58:sbox_lookup=8'h6a; 8'h59:sbox_lookup=8'hcb; 8'h5a:sbox_lookup=8'hbe; 8'h5b:sbox_lookup=8'h39;
            8'h5c:sbox_lookup=8'h4a; 8'h5d:sbox_lookup=8'h4c; 8'h5e:sbox_lookup=8'h58; 8'h5f:sbox_lookup=8'hcf;
            8'h60:sbox_lookup=8'hd0; 8'h61:sbox_lookup=8'hef; 8'h62:sbox_lookup=8'haa; 8'h63:sbox_lookup=8'hfb;
            8'h64:sbox_lookup=8'h43; 8'h65:sbox_lookup=8'h4d; 8'h66:sbox_lookup=8'h33; 8'h67:sbox_lookup=8'h85;
            8'h68:sbox_lookup=8'h45; 8'h69:sbox_lookup=8'hf9; 8'h6a:sbox_lookup=8'h02; 8'h6b:sbox_lookup=8'h7f;
            8'h6c:sbox_lookup=8'h50; 8'h6d:sbox_lookup=8'h3c; 8'h6e:sbox_lookup=8'h9f; 8'h6f:sbox_lookup=8'ha8;
            8'h70:sbox_lookup=8'h51; 8'h71:sbox_lookup=8'ha3; 8'h72:sbox_lookup=8'h40; 8'h73:sbox_lookup=8'h8f;
            8'h74:sbox_lookup=8'h92; 8'h75:sbox_lookup=8'h9d; 8'h76:sbox_lookup=8'h38; 8'h77:sbox_lookup=8'hf5;
            8'h78:sbox_lookup=8'hbc; 8'h79:sbox_lookup=8'hb6; 8'h7a:sbox_lookup=8'hda; 8'h7b:sbox_lookup=8'h21;
            8'h7c:sbox_lookup=8'h10; 8'h7d:sbox_lookup=8'hff; 8'h7e:sbox_lookup=8'hf3; 8'h7f:sbox_lookup=8'hd2;
            8'h80:sbox_lookup=8'hcd; 8'h81:sbox_lookup=8'h0c; 8'h82:sbox_lookup=8'h13; 8'h83:sbox_lookup=8'hec;
            8'h84:sbox_lookup=8'h5f; 8'h85:sbox_lookup=8'h97; 8'h86:sbox_lookup=8'h44; 8'h87:sbox_lookup=8'h17;
            8'h88:sbox_lookup=8'hc4; 8'h89:sbox_lookup=8'ha7; 8'h8a:sbox_lookup=8'h7e; 8'h8b:sbox_lookup=8'h3d;
            8'h8c:sbox_lookup=8'h64; 8'h8d:sbox_lookup=8'h5d; 8'h8e:sbox_lookup=8'h19; 8'h8f:sbox_lookup=8'h73;
            8'h90:sbox_lookup=8'h60; 8'h91:sbox_lookup=8'h81; 8'h92:sbox_lookup=8'h4f; 8'h93:sbox_lookup=8'hdc;
            8'h94:sbox_lookup=8'h22; 8'h95:sbox_lookup=8'h2a; 8'h96:sbox_lookup=8'h90; 8'h97:sbox_lookup=8'h88;
            8'h98:sbox_lookup=8'h46; 8'h99:sbox_lookup=8'hee; 8'h9a:sbox_lookup=8'hb8; 8'h9b:sbox_lookup=8'h14;
            8'h9c:sbox_lookup=8'hde; 8'h9d:sbox_lookup=8'h5e; 8'h9e:sbox_lookup=8'h0b; 8'h9f:sbox_lookup=8'hdb;
            8'ha0:sbox_lookup=8'he0; 8'ha1:sbox_lookup=8'h32; 8'ha2:sbox_lookup=8'h3a; 8'ha3:sbox_lookup=8'h0a;
            8'ha4:sbox_lookup=8'h49; 8'ha5:sbox_lookup=8'h06; 8'ha6:sbox_lookup=8'h24; 8'ha7:sbox_lookup=8'h5c;
            8'ha8:sbox_lookup=8'hc2; 8'ha9:sbox_lookup=8'hd3; 8'haa:sbox_lookup=8'hac; 8'hab:sbox_lookup=8'h62;
            8'hac:sbox_lookup=8'h91; 8'had:sbox_lookup=8'h95; 8'hae:sbox_lookup=8'he4; 8'haf:sbox_lookup=8'h79;
            8'hb0:sbox_lookup=8'he7; 8'hb1:sbox_lookup=8'hc8; 8'hb2:sbox_lookup=8'h37; 8'hb3:sbox_lookup=8'h6d;
            8'hb4:sbox_lookup=8'h8d; 8'hb5:sbox_lookup=8'hd5; 8'hb6:sbox_lookup=8'h4e; 8'hb7:sbox_lookup=8'ha9;
            8'hb8:sbox_lookup=8'h6c; 8'hb9:sbox_lookup=8'h56; 8'hba:sbox_lookup=8'hf4; 8'hbb:sbox_lookup=8'hea;
            8'hbc:sbox_lookup=8'h65; 8'hbd:sbox_lookup=8'h7a; 8'hbe:sbox_lookup=8'hae; 8'hbf:sbox_lookup=8'h08;
            8'hc0:sbox_lookup=8'hba; 8'hc1:sbox_lookup=8'h78; 8'hc2:sbox_lookup=8'h25; 8'hc3:sbox_lookup=8'h2e;
            8'hc4:sbox_lookup=8'h1c; 8'hc5:sbox_lookup=8'ha6; 8'hc6:sbox_lookup=8'hb4; 8'hc7:sbox_lookup=8'hc6;
            8'hc8:sbox_lookup=8'he8; 8'hc9:sbox_lookup=8'hdd; 8'hca:sbox_lookup=8'h74; 8'hcb:sbox_lookup=8'h1f;
            8'hcc:sbox_lookup=8'h4b; 8'hcd:sbox_lookup=8'hbd; 8'hce:sbox_lookup=8'h8b; 8'hcf:sbox_lookup=8'h8a;
            8'hd0:sbox_lookup=8'h70; 8'hd1:sbox_lookup=8'h3e; 8'hd2:sbox_lookup=8'hb5; 8'hd3:sbox_lookup=8'h66;
            8'hd4:sbox_lookup=8'h48; 8'hd5:sbox_lookup=8'h03; 8'hd6:sbox_lookup=8'hf6; 8'hd7:sbox_lookup=8'h0e;
            8'hd8:sbox_lookup=8'h61; 8'hd9:sbox_lookup=8'h35; 8'hda:sbox_lookup=8'h57; 8'hdb:sbox_lookup=8'hb9;
            8'hdc:sbox_lookup=8'h86; 8'hdd:sbox_lookup=8'hc1; 8'hde:sbox_lookup=8'h1d; 8'hdf:sbox_lookup=8'h9e;
            8'he0:sbox_lookup=8'he1; 8'he1:sbox_lookup=8'hf8; 8'he2:sbox_lookup=8'h98; 8'he3:sbox_lookup=8'h11;
            8'he4:sbox_lookup=8'h69; 8'he5:sbox_lookup=8'hd9; 8'he6:sbox_lookup=8'h8e; 8'he7:sbox_lookup=8'h94;
            8'he8:sbox_lookup=8'h9b; 8'he9:sbox_lookup=8'h1e; 8'hea:sbox_lookup=8'h87; 8'heb:sbox_lookup=8'he9;
            8'hec:sbox_lookup=8'hce; 8'hed:sbox_lookup=8'h55; 8'hee:sbox_lookup=8'h28; 8'hef:sbox_lookup=8'hdf;
            8'hf0:sbox_lookup=8'h8c; 8'hf1:sbox_lookup=8'ha1; 8'hf2:sbox_lookup=8'h89; 8'hf3:sbox_lookup=8'h0d;
            8'hf4:sbox_lookup=8'hbf; 8'hf5:sbox_lookup=8'he6; 8'hf6:sbox_lookup=8'h42; 8'hf7:sbox_lookup=8'h68;
            8'hf8:sbox_lookup=8'h41; 8'hf9:sbox_lookup=8'h99; 8'hfa:sbox_lookup=8'h2d; 8'hfb:sbox_lookup=8'h0f;
            8'hfc:sbox_lookup=8'hb0; 8'hfd:sbox_lookup=8'h54; 8'hfe:sbox_lookup=8'hbb; 8'hff:sbox_lookup=8'h16;
            default: sbox_lookup = 8'h00;
        endcase
    endfunction

    function automatic aes_byte_t rcon_byte(input logic [3:0] r);
        case (r)
            4'd1  : rcon_byte = 8'h01;
            4'd2  : rcon_byte = 8'h02;
            4'd3  : rcon_byte = 8'h04;
            4'd4  : rcon_byte = 8'h08;
            4'd5  : rcon_byte = 8'h10;
            4'd6  : rcon_byte = 8'h20;
            4'd7  : rcon_byte = 8'h40;
            4'd8  : rcon_byte = 8'h80;
            4'd9  : rcon_byte = 8'h1b;
            4'd10 : rcon_byte = 8'h36;
            default: rcon_byte = 8'h00;
        endcase
    endfunction

    // ========================================================================
    // State
    // ========================================================================
    logic        active;
    logic [3:0]  rnd;        // round key currently being PRODUCED (1..NUM_ROUNDS)
    aes_block_t  cur_key;    // most recently produced round key (round rnd-1)

    // ========================================================================
    // Combinational next-round-key derivation (FIPS-197 5.2)
    // ========================================================================
    aes_word_t w0, w1, w2, w3;
    assign w0 = cur_key[127:96];
    assign w1 = cur_key[95:64];
    assign w2 = cur_key[63:32];
    assign w3 = cur_key[31:0];

    aes_word_t rotw, subw, temp;
    assign rotw = {w3[23:0], w3[31:24]};                       // RotWord
    assign subw = {sbox_lookup(rotw[31:24]), sbox_lookup(rotw[23:16]),
                    sbox_lookup(rotw[15:8]),  sbox_lookup(rotw[7:0])}; // SubWord
    assign temp = subw ^ {rcon_byte(rnd), 24'h000000};

    aes_word_t w4, w5, w6, w7;
    assign w4 = w0 ^ temp;
    assign w5 = w4 ^ w1;
    assign w6 = w5 ^ w2;
    assign w7 = w6 ^ w3;

    aes_block_t next_key_comb;
    assign next_key_comb = {w4, w5, w6, w7};

    // ========================================================================
    // Sequencer
    // ========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            active  <= 1'b0;
            rnd     <= 4'd0;
            cur_key <= '0;
            w_en    <= 1'b0;
            waddr   <= 4'd0;
            wkey    <= '0;
            done    <= 1'b0;
        end
        else begin
            // Defaults: single-cycle pulses
            w_en <= 1'b0;
            done <= 1'b0;

            if (!active) begin
                if (exp_start) begin
                    // Round key 0 is the raw key itself - written immediately.
                    active  <= 1'b1;
                    rnd     <= 4'd1;
                    cur_key <= key_in;
                    w_en    <= 1'b1;
                    waddr   <= 4'd0;
                    wkey    <= key_in;
                end
            end
            else if (expand_enable) begin
                // Produce and write round key `rnd` from cur_key (round rnd-1)
                w_en    <= 1'b1;
                waddr   <= rnd;
                wkey    <= next_key_comb;
                cur_key <= next_key_comb;

                if (rnd == 4'(aes_pkg::NUM_ROUNDS)) begin
                    // Round key 10 just committed - expansion complete
                    active <= 1'b0;
                    done   <= 1'b1;
                    rnd    <= 4'd0;
                end
                else begin
                    rnd <= rnd + 4'd1;
                end
            end
        end
    end

endmodule : AES_Key_Expansion_128

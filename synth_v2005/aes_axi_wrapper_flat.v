module key_fifo (
	clk,
	reset,
	push,
	data_in,
	pop,
	data_out,
	empty,
	full
);
	parameter signed [31:0] WIDTH = 128;
	parameter signed [31:0] DEPTH = 4;
	input wire clk;
	input wire reset;
	input wire push;
	input wire [WIDTH - 1:0] data_in;
	input wire pop;
	output reg [WIDTH - 1:0] data_out;
	output wire empty;
	output wire full;
	localparam signed [31:0] PTR_W = $clog2(DEPTH) + 1;
	reg [WIDTH - 1:0] mem [0:DEPTH - 1];
	reg [PTR_W - 1:0] wr_ptr;
	reg [PTR_W - 1:0] rd_ptr;
	reg [PTR_W - 1:0] count;
	assign empty = count == {PTR_W {1'sb0}};
	function automatic signed [PTR_W - 1:0] sv2v_cast_E310E_signed;
		input reg signed [PTR_W - 1:0] inp;
		sv2v_cast_E310E_signed = inp;
	endfunction
	assign full = count == sv2v_cast_E310E_signed(DEPTH);
	always @(posedge clk)
		if (reset) begin
			wr_ptr <= 1'sb0;
			rd_ptr <= 1'sb0;
			count <= 1'sb0;
			data_out <= 1'sb0;
		end
		else
			case ({push && !full, pop && !empty})
				2'b10: begin
					mem[wr_ptr[PTR_W - 2:0]] <= data_in;
					wr_ptr <= wr_ptr + 1'b1;
					count <= count + 1'b1;
				end
				2'b01: begin
					data_out <= mem[rd_ptr[PTR_W - 2:0]];
					rd_ptr <= rd_ptr + 1'b1;
					count <= count - 1'b1;
				end
				2'b11: begin
					mem[wr_ptr[PTR_W - 2:0]] <= data_in;
					data_out <= mem[rd_ptr[PTR_W - 2:0]];
					wr_ptr <= wr_ptr + 1'b1;
					rd_ptr <= rd_ptr + 1'b1;
				end
				default:
					;
			endcase
endmodule
module key_controller (
	clk,
	reset,
	key_valid,
	key_ready,
	bank_free,
	exp_done,
	exp_start,
	write_bank
);
	reg _sv2v_0;
	input wire clk;
	input wire reset;
	input wire key_valid;
	output reg key_ready;
	input wire [1:0] bank_free;
	input wire exp_done;
	output reg exp_start;
	output reg write_bank;
	reg active;
	reg selected_bank;
	wire start_condition;
	always @(*) begin
		if (_sv2v_0)
			;
		if (bank_free[0])
			selected_bank = 1'b0;
		else if (bank_free[1])
			selected_bank = 1'b1;
		else
			selected_bank = 1'b0;
	end
	assign start_condition = (key_valid && !active) && (bank_free != 2'b00);
	always @(*) begin
		if (_sv2v_0)
			;
		key_ready = start_condition;
	end
	always @(posedge clk)
		if (reset) begin
			active <= 1'b0;
			exp_start <= 1'b0;
			write_bank <= 1'b0;
		end
		else begin
			exp_start <= 1'b0;
			if (exp_done)
				active <= 1'b0;
			if (start_condition) begin
				active <= 1'b1;
				write_bank <= selected_bank;
				exp_start <= 1'b1;
			end
		end
	initial _sv2v_0 = 0;
endmodule
module AES_Key_Expansion_128 (
	clk,
	reset,
	exp_start,
	expand_enable,
	key_in,
	w_en,
	waddr,
	wkey,
	done
);
	input wire clk;
	input wire reset;
	input wire exp_start;
	input wire expand_enable;
	input wire [127:0] key_in;
	output reg w_en;
	output reg [3:0] waddr;
	output reg [127:0] wkey;
	output reg done;
	function automatic [7:0] sbox_lookup;
		input reg [7:0] a;
		case (a)
			8'h00: sbox_lookup = 8'h63;
			8'h01: sbox_lookup = 8'h7c;
			8'h02: sbox_lookup = 8'h77;
			8'h03: sbox_lookup = 8'h7b;
			8'h04: sbox_lookup = 8'hf2;
			8'h05: sbox_lookup = 8'h6b;
			8'h06: sbox_lookup = 8'h6f;
			8'h07: sbox_lookup = 8'hc5;
			8'h08: sbox_lookup = 8'h30;
			8'h09: sbox_lookup = 8'h01;
			8'h0a: sbox_lookup = 8'h67;
			8'h0b: sbox_lookup = 8'h2b;
			8'h0c: sbox_lookup = 8'hfe;
			8'h0d: sbox_lookup = 8'hd7;
			8'h0e: sbox_lookup = 8'hab;
			8'h0f: sbox_lookup = 8'h76;
			8'h10: sbox_lookup = 8'hca;
			8'h11: sbox_lookup = 8'h82;
			8'h12: sbox_lookup = 8'hc9;
			8'h13: sbox_lookup = 8'h7d;
			8'h14: sbox_lookup = 8'hfa;
			8'h15: sbox_lookup = 8'h59;
			8'h16: sbox_lookup = 8'h47;
			8'h17: sbox_lookup = 8'hf0;
			8'h18: sbox_lookup = 8'had;
			8'h19: sbox_lookup = 8'hd4;
			8'h1a: sbox_lookup = 8'ha2;
			8'h1b: sbox_lookup = 8'haf;
			8'h1c: sbox_lookup = 8'h9c;
			8'h1d: sbox_lookup = 8'ha4;
			8'h1e: sbox_lookup = 8'h72;
			8'h1f: sbox_lookup = 8'hc0;
			8'h20: sbox_lookup = 8'hb7;
			8'h21: sbox_lookup = 8'hfd;
			8'h22: sbox_lookup = 8'h93;
			8'h23: sbox_lookup = 8'h26;
			8'h24: sbox_lookup = 8'h36;
			8'h25: sbox_lookup = 8'h3f;
			8'h26: sbox_lookup = 8'hf7;
			8'h27: sbox_lookup = 8'hcc;
			8'h28: sbox_lookup = 8'h34;
			8'h29: sbox_lookup = 8'ha5;
			8'h2a: sbox_lookup = 8'he5;
			8'h2b: sbox_lookup = 8'hf1;
			8'h2c: sbox_lookup = 8'h71;
			8'h2d: sbox_lookup = 8'hd8;
			8'h2e: sbox_lookup = 8'h31;
			8'h2f: sbox_lookup = 8'h15;
			8'h30: sbox_lookup = 8'h04;
			8'h31: sbox_lookup = 8'hc7;
			8'h32: sbox_lookup = 8'h23;
			8'h33: sbox_lookup = 8'hc3;
			8'h34: sbox_lookup = 8'h18;
			8'h35: sbox_lookup = 8'h96;
			8'h36: sbox_lookup = 8'h05;
			8'h37: sbox_lookup = 8'h9a;
			8'h38: sbox_lookup = 8'h07;
			8'h39: sbox_lookup = 8'h12;
			8'h3a: sbox_lookup = 8'h80;
			8'h3b: sbox_lookup = 8'he2;
			8'h3c: sbox_lookup = 8'heb;
			8'h3d: sbox_lookup = 8'h27;
			8'h3e: sbox_lookup = 8'hb2;
			8'h3f: sbox_lookup = 8'h75;
			8'h40: sbox_lookup = 8'h09;
			8'h41: sbox_lookup = 8'h83;
			8'h42: sbox_lookup = 8'h2c;
			8'h43: sbox_lookup = 8'h1a;
			8'h44: sbox_lookup = 8'h1b;
			8'h45: sbox_lookup = 8'h6e;
			8'h46: sbox_lookup = 8'h5a;
			8'h47: sbox_lookup = 8'ha0;
			8'h48: sbox_lookup = 8'h52;
			8'h49: sbox_lookup = 8'h3b;
			8'h4a: sbox_lookup = 8'hd6;
			8'h4b: sbox_lookup = 8'hb3;
			8'h4c: sbox_lookup = 8'h29;
			8'h4d: sbox_lookup = 8'he3;
			8'h4e: sbox_lookup = 8'h2f;
			8'h4f: sbox_lookup = 8'h84;
			8'h50: sbox_lookup = 8'h53;
			8'h51: sbox_lookup = 8'hd1;
			8'h52: sbox_lookup = 8'h00;
			8'h53: sbox_lookup = 8'hed;
			8'h54: sbox_lookup = 8'h20;
			8'h55: sbox_lookup = 8'hfc;
			8'h56: sbox_lookup = 8'hb1;
			8'h57: sbox_lookup = 8'h5b;
			8'h58: sbox_lookup = 8'h6a;
			8'h59: sbox_lookup = 8'hcb;
			8'h5a: sbox_lookup = 8'hbe;
			8'h5b: sbox_lookup = 8'h39;
			8'h5c: sbox_lookup = 8'h4a;
			8'h5d: sbox_lookup = 8'h4c;
			8'h5e: sbox_lookup = 8'h58;
			8'h5f: sbox_lookup = 8'hcf;
			8'h60: sbox_lookup = 8'hd0;
			8'h61: sbox_lookup = 8'hef;
			8'h62: sbox_lookup = 8'haa;
			8'h63: sbox_lookup = 8'hfb;
			8'h64: sbox_lookup = 8'h43;
			8'h65: sbox_lookup = 8'h4d;
			8'h66: sbox_lookup = 8'h33;
			8'h67: sbox_lookup = 8'h85;
			8'h68: sbox_lookup = 8'h45;
			8'h69: sbox_lookup = 8'hf9;
			8'h6a: sbox_lookup = 8'h02;
			8'h6b: sbox_lookup = 8'h7f;
			8'h6c: sbox_lookup = 8'h50;
			8'h6d: sbox_lookup = 8'h3c;
			8'h6e: sbox_lookup = 8'h9f;
			8'h6f: sbox_lookup = 8'ha8;
			8'h70: sbox_lookup = 8'h51;
			8'h71: sbox_lookup = 8'ha3;
			8'h72: sbox_lookup = 8'h40;
			8'h73: sbox_lookup = 8'h8f;
			8'h74: sbox_lookup = 8'h92;
			8'h75: sbox_lookup = 8'h9d;
			8'h76: sbox_lookup = 8'h38;
			8'h77: sbox_lookup = 8'hf5;
			8'h78: sbox_lookup = 8'hbc;
			8'h79: sbox_lookup = 8'hb6;
			8'h7a: sbox_lookup = 8'hda;
			8'h7b: sbox_lookup = 8'h21;
			8'h7c: sbox_lookup = 8'h10;
			8'h7d: sbox_lookup = 8'hff;
			8'h7e: sbox_lookup = 8'hf3;
			8'h7f: sbox_lookup = 8'hd2;
			8'h80: sbox_lookup = 8'hcd;
			8'h81: sbox_lookup = 8'h0c;
			8'h82: sbox_lookup = 8'h13;
			8'h83: sbox_lookup = 8'hec;
			8'h84: sbox_lookup = 8'h5f;
			8'h85: sbox_lookup = 8'h97;
			8'h86: sbox_lookup = 8'h44;
			8'h87: sbox_lookup = 8'h17;
			8'h88: sbox_lookup = 8'hc4;
			8'h89: sbox_lookup = 8'ha7;
			8'h8a: sbox_lookup = 8'h7e;
			8'h8b: sbox_lookup = 8'h3d;
			8'h8c: sbox_lookup = 8'h64;
			8'h8d: sbox_lookup = 8'h5d;
			8'h8e: sbox_lookup = 8'h19;
			8'h8f: sbox_lookup = 8'h73;
			8'h90: sbox_lookup = 8'h60;
			8'h91: sbox_lookup = 8'h81;
			8'h92: sbox_lookup = 8'h4f;
			8'h93: sbox_lookup = 8'hdc;
			8'h94: sbox_lookup = 8'h22;
			8'h95: sbox_lookup = 8'h2a;
			8'h96: sbox_lookup = 8'h90;
			8'h97: sbox_lookup = 8'h88;
			8'h98: sbox_lookup = 8'h46;
			8'h99: sbox_lookup = 8'hee;
			8'h9a: sbox_lookup = 8'hb8;
			8'h9b: sbox_lookup = 8'h14;
			8'h9c: sbox_lookup = 8'hde;
			8'h9d: sbox_lookup = 8'h5e;
			8'h9e: sbox_lookup = 8'h0b;
			8'h9f: sbox_lookup = 8'hdb;
			8'ha0: sbox_lookup = 8'he0;
			8'ha1: sbox_lookup = 8'h32;
			8'ha2: sbox_lookup = 8'h3a;
			8'ha3: sbox_lookup = 8'h0a;
			8'ha4: sbox_lookup = 8'h49;
			8'ha5: sbox_lookup = 8'h06;
			8'ha6: sbox_lookup = 8'h24;
			8'ha7: sbox_lookup = 8'h5c;
			8'ha8: sbox_lookup = 8'hc2;
			8'ha9: sbox_lookup = 8'hd3;
			8'haa: sbox_lookup = 8'hac;
			8'hab: sbox_lookup = 8'h62;
			8'hac: sbox_lookup = 8'h91;
			8'had: sbox_lookup = 8'h95;
			8'hae: sbox_lookup = 8'he4;
			8'haf: sbox_lookup = 8'h79;
			8'hb0: sbox_lookup = 8'he7;
			8'hb1: sbox_lookup = 8'hc8;
			8'hb2: sbox_lookup = 8'h37;
			8'hb3: sbox_lookup = 8'h6d;
			8'hb4: sbox_lookup = 8'h8d;
			8'hb5: sbox_lookup = 8'hd5;
			8'hb6: sbox_lookup = 8'h4e;
			8'hb7: sbox_lookup = 8'ha9;
			8'hb8: sbox_lookup = 8'h6c;
			8'hb9: sbox_lookup = 8'h56;
			8'hba: sbox_lookup = 8'hf4;
			8'hbb: sbox_lookup = 8'hea;
			8'hbc: sbox_lookup = 8'h65;
			8'hbd: sbox_lookup = 8'h7a;
			8'hbe: sbox_lookup = 8'hae;
			8'hbf: sbox_lookup = 8'h08;
			8'hc0: sbox_lookup = 8'hba;
			8'hc1: sbox_lookup = 8'h78;
			8'hc2: sbox_lookup = 8'h25;
			8'hc3: sbox_lookup = 8'h2e;
			8'hc4: sbox_lookup = 8'h1c;
			8'hc5: sbox_lookup = 8'ha6;
			8'hc6: sbox_lookup = 8'hb4;
			8'hc7: sbox_lookup = 8'hc6;
			8'hc8: sbox_lookup = 8'he8;
			8'hc9: sbox_lookup = 8'hdd;
			8'hca: sbox_lookup = 8'h74;
			8'hcb: sbox_lookup = 8'h1f;
			8'hcc: sbox_lookup = 8'h4b;
			8'hcd: sbox_lookup = 8'hbd;
			8'hce: sbox_lookup = 8'h8b;
			8'hcf: sbox_lookup = 8'h8a;
			8'hd0: sbox_lookup = 8'h70;
			8'hd1: sbox_lookup = 8'h3e;
			8'hd2: sbox_lookup = 8'hb5;
			8'hd3: sbox_lookup = 8'h66;
			8'hd4: sbox_lookup = 8'h48;
			8'hd5: sbox_lookup = 8'h03;
			8'hd6: sbox_lookup = 8'hf6;
			8'hd7: sbox_lookup = 8'h0e;
			8'hd8: sbox_lookup = 8'h61;
			8'hd9: sbox_lookup = 8'h35;
			8'hda: sbox_lookup = 8'h57;
			8'hdb: sbox_lookup = 8'hb9;
			8'hdc: sbox_lookup = 8'h86;
			8'hdd: sbox_lookup = 8'hc1;
			8'hde: sbox_lookup = 8'h1d;
			8'hdf: sbox_lookup = 8'h9e;
			8'he0: sbox_lookup = 8'he1;
			8'he1: sbox_lookup = 8'hf8;
			8'he2: sbox_lookup = 8'h98;
			8'he3: sbox_lookup = 8'h11;
			8'he4: sbox_lookup = 8'h69;
			8'he5: sbox_lookup = 8'hd9;
			8'he6: sbox_lookup = 8'h8e;
			8'he7: sbox_lookup = 8'h94;
			8'he8: sbox_lookup = 8'h9b;
			8'he9: sbox_lookup = 8'h1e;
			8'hea: sbox_lookup = 8'h87;
			8'heb: sbox_lookup = 8'he9;
			8'hec: sbox_lookup = 8'hce;
			8'hed: sbox_lookup = 8'h55;
			8'hee: sbox_lookup = 8'h28;
			8'hef: sbox_lookup = 8'hdf;
			8'hf0: sbox_lookup = 8'h8c;
			8'hf1: sbox_lookup = 8'ha1;
			8'hf2: sbox_lookup = 8'h89;
			8'hf3: sbox_lookup = 8'h0d;
			8'hf4: sbox_lookup = 8'hbf;
			8'hf5: sbox_lookup = 8'he6;
			8'hf6: sbox_lookup = 8'h42;
			8'hf7: sbox_lookup = 8'h68;
			8'hf8: sbox_lookup = 8'h41;
			8'hf9: sbox_lookup = 8'h99;
			8'hfa: sbox_lookup = 8'h2d;
			8'hfb: sbox_lookup = 8'h0f;
			8'hfc: sbox_lookup = 8'hb0;
			8'hfd: sbox_lookup = 8'h54;
			8'hfe: sbox_lookup = 8'hbb;
			8'hff: sbox_lookup = 8'h16;
			default: sbox_lookup = 8'h00;
		endcase
	endfunction
	function automatic [7:0] rcon_byte;
		input reg [3:0] r;
		case (r)
			4'd1: rcon_byte = 8'h01;
			4'd2: rcon_byte = 8'h02;
			4'd3: rcon_byte = 8'h04;
			4'd4: rcon_byte = 8'h08;
			4'd5: rcon_byte = 8'h10;
			4'd6: rcon_byte = 8'h20;
			4'd7: rcon_byte = 8'h40;
			4'd8: rcon_byte = 8'h80;
			4'd9: rcon_byte = 8'h1b;
			4'd10: rcon_byte = 8'h36;
			default: rcon_byte = 8'h00;
		endcase
	endfunction
	reg active;
	reg [3:0] rnd;
	reg [127:0] cur_key;
	wire [31:0] w0;
	wire [31:0] w1;
	wire [31:0] w2;
	wire [31:0] w3;
	assign w0 = cur_key[127:96];
	assign w1 = cur_key[95:64];
	assign w2 = cur_key[63:32];
	assign w3 = cur_key[31:0];
	wire [31:0] rotw;
	wire [31:0] subw;
	wire [31:0] temp;
	assign rotw = {w3[23:0], w3[31:24]};
	assign subw = {sbox_lookup(rotw[31:24]), sbox_lookup(rotw[23:16]), sbox_lookup(rotw[15:8]), sbox_lookup(rotw[7:0])};
	assign temp = subw ^ {rcon_byte(rnd), 24'h000000};
	wire [31:0] w4;
	wire [31:0] w5;
	wire [31:0] w6;
	wire [31:0] w7;
	assign w4 = w0 ^ temp;
	assign w5 = w4 ^ w1;
	assign w6 = w5 ^ w2;
	assign w7 = w6 ^ w3;
	wire [127:0] next_key_comb;
	assign next_key_comb = {w4, w5, w6, w7};
	localparam signed [31:0] aes_pkg_NUM_ROUNDS = 10;
	function automatic signed [3:0] sv2v_cast_4_signed;
		input reg signed [3:0] inp;
		sv2v_cast_4_signed = inp;
	endfunction
	always @(posedge clk)
		if (reset) begin
			active <= 1'b0;
			rnd <= 4'd0;
			cur_key <= 1'sb0;
			w_en <= 1'b0;
			waddr <= 4'd0;
			wkey <= 1'sb0;
			done <= 1'b0;
		end
		else begin
			w_en <= 1'b0;
			done <= 1'b0;
			if (!active) begin
				if (exp_start) begin
					active <= 1'b1;
					rnd <= 4'd1;
					cur_key <= key_in;
					w_en <= 1'b1;
					waddr <= 4'd0;
					wkey <= key_in;
				end
			end
			else if (expand_enable) begin
				w_en <= 1'b1;
				waddr <= rnd;
				wkey <= next_key_comb;
				cur_key <= next_key_comb;
				if (rnd == sv2v_cast_4_signed(aes_pkg_NUM_ROUNDS)) begin
					active <= 1'b0;
					done <= 1'b1;
					rnd <= 4'd0;
				end
				else
					rnd <= rnd + 4'd1;
			end
		end
endmodule
module keymem_dual (
	clk,
	reset,
	w_en,
	waddr,
	wkey,
	write_bank,
	write_gen,
	bank_release,
	bank_busy,
	round_keys,
	bank_valid,
	bank_free,
	bank_gen_flat
);
	reg _sv2v_0;
	input wire clk;
	input wire reset;
	input wire w_en;
	input wire [3:0] waddr;
	input wire [127:0] wkey;
	input wire write_bank;
	localparam signed [31:0] aes_pkg_KEY_GEN_W = 16;
	input wire [15:0] write_gen;
	input wire [1:0] bank_release;
	input wire [1:0] bank_busy;
	localparam signed [31:0] aes_pkg_NUM_BANKS = 2;
	localparam signed [31:0] aes_pkg_NUM_ROUNDS = 10;
	output reg [2815:0] round_keys;
	output reg [1:0] bank_valid;
	output reg [1:0] bank_free;
	output wire [(aes_pkg_NUM_BANKS * aes_pkg_KEY_GEN_W) - 1:0] bank_gen_flat;
	reg [aes_pkg_NUM_ROUNDS:0] valid [0:1];
	reg [15:0] bank_gen_reg [0:1];
	genvar _gv_gb_1;
	generate
		for (_gv_gb_1 = 0; _gv_gb_1 < aes_pkg_NUM_BANKS; _gv_gb_1 = _gv_gb_1 + 1) begin : GEN_FLATTEN
			localparam gb = _gv_gb_1;
			assign bank_gen_flat[((gb + 1) * aes_pkg_KEY_GEN_W) - 1-:aes_pkg_KEY_GEN_W] = bank_gen_reg[gb];
		end
	endgenerate
	always @(*) begin
		if (_sv2v_0)
			;
		bank_free[0] = !bank_busy[0] && !bank_valid[0];
		bank_free[1] = !bank_busy[1] && !bank_valid[1];
	end
	always @(posedge clk)
		if (reset) begin
			valid[0] <= 1'sb0;
			valid[1] <= 1'sb0;
			bank_valid <= 2'b00;
			begin : sv2v_autoblock_1
				reg signed [31:0] b;
				for (b = 0; b < 2; b = b + 1)
					begin
						begin : sv2v_autoblock_2
							reg signed [31:0] r;
							for (r = 0; r <= aes_pkg_NUM_ROUNDS; r = r + 1)
								round_keys[(((1 - b) * 11) + (aes_pkg_NUM_ROUNDS - r)) * 128+:128] <= 1'sb0;
						end
						bank_gen_reg[b] <= 1'sb0;
					end
			end
		end
		else begin
			if (bank_release[0]) begin
				valid[0] <= 1'sb0;
				bank_valid[0] <= 1'b0;
			end
			if (bank_release[1]) begin
				valid[1] <= 1'sb0;
				bank_valid[1] <= 1'b0;
			end
			if (w_en && bank_free[write_bank]) begin
				round_keys[(((1 - write_bank) * 11) + (aes_pkg_NUM_ROUNDS - waddr)) * 128+:128] <= wkey;
				valid[write_bank][waddr] <= 1'b1;
				if (waddr == 4'd0)
					bank_gen_reg[write_bank] <= write_gen;
			end
			bank_valid[0] <= &valid[0];
			bank_valid[1] <= &valid[1];
		end
	initial _sv2v_0 = 0;
endmodule
module key_system_top (
	clk,
	reset,
	push,
	key_in,
	bank_busy,
	round_keys,
	bank_valid,
	bank_free,
	key_system_busy,
	key_available,
	active_bank,
	key_push_ready,
	key_gen_out,
	bank_gen_flat
);
	reg _sv2v_0;
	input wire clk;
	input wire reset;
	input wire push;
	input wire [127:0] key_in;
	input wire [1:0] bank_busy;
	localparam signed [31:0] aes_pkg_NUM_BANKS = 2;
	localparam signed [31:0] aes_pkg_NUM_ROUNDS = 10;
	output wire [2815:0] round_keys;
	output wire [1:0] bank_valid;
	output wire [1:0] bank_free;
	output reg key_system_busy;
	output reg key_available;
	output reg active_bank;
	output wire key_push_ready;
	localparam signed [31:0] aes_pkg_KEY_GEN_W = 16;
	output wire [15:0] key_gen_out;
	output wire [(aes_pkg_NUM_BANKS * aes_pkg_KEY_GEN_W) - 1:0] bank_gen_flat;
	wire fifo_empty;
	wire fifo_full;
	wire fifo_pop;
	wire [127:0] fifo_key;
	wire [15:0] fifo_gen;
	reg [15:0] push_gen_counter;
	wire fifo_accept;
	assign key_push_ready = !fifo_full;
	assign fifo_accept = push && key_push_ready;
	assign key_gen_out = push_gen_counter;
	always @(posedge clk)
		if (reset)
			push_gen_counter <= 1'sb0;
		else if (fifo_accept)
			push_gen_counter <= push_gen_counter + 1'b1;
	wire exp_start;
	wire write_bank;
	wire exp_done;
	reg [15:0] write_gen;
	always @(posedge clk)
		if (reset)
			write_gen <= 1'sb0;
		else if (exp_start)
			write_gen <= fifo_gen;
	wire w_en;
	wire [3:0] waddr;
	wire [127:0] wkey;
	reg [1:0] bank_release;
	wire [143:0] fifo_din;
	wire [143:0] fifo_dout;
	assign fifo_din = {push_gen_counter, key_in};
	assign {fifo_gen, fifo_key} = fifo_dout;
	localparam signed [31:0] aes_pkg_KEY_FIFO_DEPTH = 4;
	key_fifo #(
		.WIDTH(144),
		.DEPTH(aes_pkg_KEY_FIFO_DEPTH)
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
	AES_Key_Expansion_128 expand_inst(
		.clk(clk),
		.reset(reset),
		.exp_start(exp_start),
		.expand_enable(1'b1),
		.key_in(fifo_key),
		.w_en(w_en),
		.waddr(waddr),
		.wkey(wkey),
		.done(exp_done)
	);
	always @(posedge clk)
		if (reset)
			bank_release <= 2'b00;
		else begin
			bank_release <= 2'b00;
			if (((!fifo_empty && (bank_free == 2'b00)) && bank_valid[0]) && !bank_busy[0])
				bank_release[0] <= 1'b1;
			else if (((!fifo_empty && (bank_free == 2'b00)) && bank_valid[1]) && !bank_busy[1])
				bank_release[1] <= 1'b1;
		end
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
	always @(posedge clk)
		if (reset)
			active_bank <= 1'b0;
		else if (exp_done)
			active_bank <= write_bank;
	always @(*) begin
		if (_sv2v_0)
			;
		key_available = 1'b0;
		if (bank_valid[0])
			key_available = 1'b1;
		if (bank_valid[1])
			key_available = 1'b1;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		key_system_busy = 1'b0;
		if (!fifo_empty)
			key_system_busy = 1'b1;
		if (bank_busy != 2'b00)
			key_system_busy = 1'b1;
	end
	initial _sv2v_0 = 0;
endmodule
module SubBytes (
	inp,
	res
);
	input [127:0] inp;
	output wire [127:0] res;
	genvar _gv_i_1;
	function automatic [7:0] sbox;
		input [7:0] in;
		case (in)
			8'h00: sbox = 8'h63;
			8'h01: sbox = 8'h7c;
			8'h02: sbox = 8'h77;
			8'h03: sbox = 8'h7b;
			8'h04: sbox = 8'hf2;
			8'h05: sbox = 8'h6b;
			8'h06: sbox = 8'h6f;
			8'h07: sbox = 8'hc5;
			8'h08: sbox = 8'h30;
			8'h09: sbox = 8'h01;
			8'h0a: sbox = 8'h67;
			8'h0b: sbox = 8'h2b;
			8'h0c: sbox = 8'hfe;
			8'h0d: sbox = 8'hd7;
			8'h0e: sbox = 8'hab;
			8'h0f: sbox = 8'h76;
			8'h10: sbox = 8'hca;
			8'h11: sbox = 8'h82;
			8'h12: sbox = 8'hc9;
			8'h13: sbox = 8'h7d;
			8'h14: sbox = 8'hfa;
			8'h15: sbox = 8'h59;
			8'h16: sbox = 8'h47;
			8'h17: sbox = 8'hf0;
			8'h18: sbox = 8'had;
			8'h19: sbox = 8'hd4;
			8'h1a: sbox = 8'ha2;
			8'h1b: sbox = 8'haf;
			8'h1c: sbox = 8'h9c;
			8'h1d: sbox = 8'ha4;
			8'h1e: sbox = 8'h72;
			8'h1f: sbox = 8'hc0;
			8'h20: sbox = 8'hb7;
			8'h21: sbox = 8'hfd;
			8'h22: sbox = 8'h93;
			8'h23: sbox = 8'h26;
			8'h24: sbox = 8'h36;
			8'h25: sbox = 8'h3f;
			8'h26: sbox = 8'hf7;
			8'h27: sbox = 8'hcc;
			8'h28: sbox = 8'h34;
			8'h29: sbox = 8'ha5;
			8'h2a: sbox = 8'he5;
			8'h2b: sbox = 8'hf1;
			8'h2c: sbox = 8'h71;
			8'h2d: sbox = 8'hd8;
			8'h2e: sbox = 8'h31;
			8'h2f: sbox = 8'h15;
			8'h30: sbox = 8'h04;
			8'h31: sbox = 8'hc7;
			8'h32: sbox = 8'h23;
			8'h33: sbox = 8'hc3;
			8'h34: sbox = 8'h18;
			8'h35: sbox = 8'h96;
			8'h36: sbox = 8'h05;
			8'h37: sbox = 8'h9a;
			8'h38: sbox = 8'h07;
			8'h39: sbox = 8'h12;
			8'h3a: sbox = 8'h80;
			8'h3b: sbox = 8'he2;
			8'h3c: sbox = 8'heb;
			8'h3d: sbox = 8'h27;
			8'h3e: sbox = 8'hb2;
			8'h3f: sbox = 8'h75;
			8'h40: sbox = 8'h09;
			8'h41: sbox = 8'h83;
			8'h42: sbox = 8'h2c;
			8'h43: sbox = 8'h1a;
			8'h44: sbox = 8'h1b;
			8'h45: sbox = 8'h6e;
			8'h46: sbox = 8'h5a;
			8'h47: sbox = 8'ha0;
			8'h48: sbox = 8'h52;
			8'h49: sbox = 8'h3b;
			8'h4a: sbox = 8'hd6;
			8'h4b: sbox = 8'hb3;
			8'h4c: sbox = 8'h29;
			8'h4d: sbox = 8'he3;
			8'h4e: sbox = 8'h2f;
			8'h4f: sbox = 8'h84;
			8'h50: sbox = 8'h53;
			8'h51: sbox = 8'hd1;
			8'h52: sbox = 8'h00;
			8'h53: sbox = 8'hed;
			8'h54: sbox = 8'h20;
			8'h55: sbox = 8'hfc;
			8'h56: sbox = 8'hb1;
			8'h57: sbox = 8'h5b;
			8'h58: sbox = 8'h6a;
			8'h59: sbox = 8'hcb;
			8'h5a: sbox = 8'hbe;
			8'h5b: sbox = 8'h39;
			8'h5c: sbox = 8'h4a;
			8'h5d: sbox = 8'h4c;
			8'h5e: sbox = 8'h58;
			8'h5f: sbox = 8'hcf;
			8'h60: sbox = 8'hd0;
			8'h61: sbox = 8'hef;
			8'h62: sbox = 8'haa;
			8'h63: sbox = 8'hfb;
			8'h64: sbox = 8'h43;
			8'h65: sbox = 8'h4d;
			8'h66: sbox = 8'h33;
			8'h67: sbox = 8'h85;
			8'h68: sbox = 8'h45;
			8'h69: sbox = 8'hf9;
			8'h6a: sbox = 8'h02;
			8'h6b: sbox = 8'h7f;
			8'h6c: sbox = 8'h50;
			8'h6d: sbox = 8'h3c;
			8'h6e: sbox = 8'h9f;
			8'h6f: sbox = 8'ha8;
			8'h70: sbox = 8'h51;
			8'h71: sbox = 8'ha3;
			8'h72: sbox = 8'h40;
			8'h73: sbox = 8'h8f;
			8'h74: sbox = 8'h92;
			8'h75: sbox = 8'h9d;
			8'h76: sbox = 8'h38;
			8'h77: sbox = 8'hf5;
			8'h78: sbox = 8'hbc;
			8'h79: sbox = 8'hb6;
			8'h7a: sbox = 8'hda;
			8'h7b: sbox = 8'h21;
			8'h7c: sbox = 8'h10;
			8'h7d: sbox = 8'hff;
			8'h7e: sbox = 8'hf3;
			8'h7f: sbox = 8'hd2;
			8'h80: sbox = 8'hcd;
			8'h81: sbox = 8'h0c;
			8'h82: sbox = 8'h13;
			8'h83: sbox = 8'hec;
			8'h84: sbox = 8'h5f;
			8'h85: sbox = 8'h97;
			8'h86: sbox = 8'h44;
			8'h87: sbox = 8'h17;
			8'h88: sbox = 8'hc4;
			8'h89: sbox = 8'ha7;
			8'h8a: sbox = 8'h7e;
			8'h8b: sbox = 8'h3d;
			8'h8c: sbox = 8'h64;
			8'h8d: sbox = 8'h5d;
			8'h8e: sbox = 8'h19;
			8'h8f: sbox = 8'h73;
			8'h90: sbox = 8'h60;
			8'h91: sbox = 8'h81;
			8'h92: sbox = 8'h4f;
			8'h93: sbox = 8'hdc;
			8'h94: sbox = 8'h22;
			8'h95: sbox = 8'h2a;
			8'h96: sbox = 8'h90;
			8'h97: sbox = 8'h88;
			8'h98: sbox = 8'h46;
			8'h99: sbox = 8'hee;
			8'h9a: sbox = 8'hb8;
			8'h9b: sbox = 8'h14;
			8'h9c: sbox = 8'hde;
			8'h9d: sbox = 8'h5e;
			8'h9e: sbox = 8'h0b;
			8'h9f: sbox = 8'hdb;
			8'ha0: sbox = 8'he0;
			8'ha1: sbox = 8'h32;
			8'ha2: sbox = 8'h3a;
			8'ha3: sbox = 8'h0a;
			8'ha4: sbox = 8'h49;
			8'ha5: sbox = 8'h06;
			8'ha6: sbox = 8'h24;
			8'ha7: sbox = 8'h5c;
			8'ha8: sbox = 8'hc2;
			8'ha9: sbox = 8'hd3;
			8'haa: sbox = 8'hac;
			8'hab: sbox = 8'h62;
			8'hac: sbox = 8'h91;
			8'had: sbox = 8'h95;
			8'hae: sbox = 8'he4;
			8'haf: sbox = 8'h79;
			8'hb0: sbox = 8'he7;
			8'hb1: sbox = 8'hc8;
			8'hb2: sbox = 8'h37;
			8'hb3: sbox = 8'h6d;
			8'hb4: sbox = 8'h8d;
			8'hb5: sbox = 8'hd5;
			8'hb6: sbox = 8'h4e;
			8'hb7: sbox = 8'ha9;
			8'hb8: sbox = 8'h6c;
			8'hb9: sbox = 8'h56;
			8'hba: sbox = 8'hf4;
			8'hbb: sbox = 8'hea;
			8'hbc: sbox = 8'h65;
			8'hbd: sbox = 8'h7a;
			8'hbe: sbox = 8'hae;
			8'hbf: sbox = 8'h08;
			8'hc0: sbox = 8'hba;
			8'hc1: sbox = 8'h78;
			8'hc2: sbox = 8'h25;
			8'hc3: sbox = 8'h2e;
			8'hc4: sbox = 8'h1c;
			8'hc5: sbox = 8'ha6;
			8'hc6: sbox = 8'hb4;
			8'hc7: sbox = 8'hc6;
			8'hc8: sbox = 8'he8;
			8'hc9: sbox = 8'hdd;
			8'hca: sbox = 8'h74;
			8'hcb: sbox = 8'h1f;
			8'hcc: sbox = 8'h4b;
			8'hcd: sbox = 8'hbd;
			8'hce: sbox = 8'h8b;
			8'hcf: sbox = 8'h8a;
			8'hd0: sbox = 8'h70;
			8'hd1: sbox = 8'h3e;
			8'hd2: sbox = 8'hb5;
			8'hd3: sbox = 8'h66;
			8'hd4: sbox = 8'h48;
			8'hd5: sbox = 8'h03;
			8'hd6: sbox = 8'hf6;
			8'hd7: sbox = 8'h0e;
			8'hd8: sbox = 8'h61;
			8'hd9: sbox = 8'h35;
			8'hda: sbox = 8'h57;
			8'hdb: sbox = 8'hb9;
			8'hdc: sbox = 8'h86;
			8'hdd: sbox = 8'hc1;
			8'hde: sbox = 8'h1d;
			8'hdf: sbox = 8'h9e;
			8'he0: sbox = 8'he1;
			8'he1: sbox = 8'hf8;
			8'he2: sbox = 8'h98;
			8'he3: sbox = 8'h11;
			8'he4: sbox = 8'h69;
			8'he5: sbox = 8'hd9;
			8'he6: sbox = 8'h8e;
			8'he7: sbox = 8'h94;
			8'he8: sbox = 8'h9b;
			8'he9: sbox = 8'h1e;
			8'hea: sbox = 8'h87;
			8'heb: sbox = 8'he9;
			8'hec: sbox = 8'hce;
			8'hed: sbox = 8'h55;
			8'hee: sbox = 8'h28;
			8'hef: sbox = 8'hdf;
			8'hf0: sbox = 8'h8c;
			8'hf1: sbox = 8'ha1;
			8'hf2: sbox = 8'h89;
			8'hf3: sbox = 8'h0d;
			8'hf4: sbox = 8'hbf;
			8'hf5: sbox = 8'he6;
			8'hf6: sbox = 8'h42;
			8'hf7: sbox = 8'h68;
			8'hf8: sbox = 8'h41;
			8'hf9: sbox = 8'h99;
			8'hfa: sbox = 8'h2d;
			8'hfb: sbox = 8'h0f;
			8'hfc: sbox = 8'hb0;
			8'hfd: sbox = 8'h54;
			8'hfe: sbox = 8'hbb;
			8'hff: sbox = 8'h16;
			default: sbox = 8'h00;
		endcase
	endfunction
	generate
		for (_gv_i_1 = 0; _gv_i_1 < 16; _gv_i_1 = _gv_i_1 + 1) begin : SB
			localparam i = _gv_i_1;
			assign res[127 - (8 * i)-:8] = sbox(inp[127 - (8 * i)-:8]);
		end
	endgenerate
endmodule
module ShiftRows (
	inp,
	out
);
	input [127:0] inp;
	output wire [127:0] out;
	wire [7:0] b [15:0];
	assign {b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]} = inp;
	assign out = {b[0], b[5], b[10], b[15], b[4], b[9], b[14], b[3], b[8], b[13], b[2], b[7], b[12], b[1], b[6], b[11]};
endmodule
module MixColumns (
	inp,
	res
);
	input [127:0] inp;
	output wire [127:0] res;
	genvar _gv_i_2;
	function automatic [7:0] mix2;
		input [7:0] x;
		mix2 = (x << 1) ^ (x[7] ? 8'h1b : 8'h00);
	endfunction
	function automatic [7:0] mix3;
		input [7:0] x;
		mix3 = mix2(x) ^ x;
	endfunction
	generate
		for (_gv_i_2 = 0; _gv_i_2 < 4; _gv_i_2 = _gv_i_2 + 1) begin : genblk1
			localparam i = _gv_i_2;
			wire [7:0] s0;
			wire [7:0] s1;
			wire [7:0] s2;
			wire [7:0] s3;
			assign s0 = inp[127 - (32 * i):120 - (32 * i)];
			assign s1 = inp[119 - (32 * i):112 - (32 * i)];
			assign s2 = inp[111 - (32 * i):104 - (32 * i)];
			assign s3 = inp[103 - (32 * i):96 - (32 * i)];
			assign res[127 - (32 * i):120 - (32 * i)] = ((mix2(s0) ^ mix3(s1)) ^ s2) ^ s3;
			assign res[119 - (32 * i):112 - (32 * i)] = ((s0 ^ mix2(s1)) ^ mix3(s2)) ^ s3;
			assign res[111 - (32 * i):104 - (32 * i)] = ((s0 ^ s1) ^ mix2(s2)) ^ mix3(s3);
			assign res[103 - (32 * i):96 - (32 * i)] = ((mix3(s0) ^ s1) ^ s2) ^ mix2(s3);
		end
	endgenerate
endmodule
module AES_Encrypt (
	clk,
	reset,
	in_valid,
	in_ready,
	plaintext,
	current_bank,
	round_keys,
	bank_busy,
	bank_valid,
	ciphertext,
	out_valid,
	out_ready
);
	reg _sv2v_0;
	localparam signed [31:0] aes_pkg_NUM_ROUNDS = 10;
	parameter signed [31:0] NUM_ROUNDS = aes_pkg_NUM_ROUNDS;
	localparam signed [31:0] aes_pkg_PIPE_DEPTH = 11;
	parameter signed [31:0] PIPE_DEPTH = aes_pkg_PIPE_DEPTH;
	input wire clk;
	input wire reset;
	input wire in_valid;
	output wire in_ready;
	input wire [127:0] plaintext;
	input wire current_bank;
	localparam signed [31:0] aes_pkg_NUM_BANKS = 2;
	input wire [2815:0] round_keys;
	output reg [1:0] bank_busy;
	input wire [1:0] bank_valid;
	output wire [127:0] ciphertext;
	output wire out_valid;
	input wire out_ready;
	reg [127:0] state [0:PIPE_DEPTH - 1];
	reg valid [0:PIPE_DEPTH - 1];
	reg bank [0:PIPE_DEPTH - 1];
	wire stall;
	wire accept;
	assign stall = valid[PIPE_DEPTH - 1] && !out_ready;
	assign accept = (in_valid && bank_valid[current_bank]) && !stall;
	assign in_ready = !stall && bank_valid[current_bank];
	always @(*) begin
		if (_sv2v_0)
			;
		bank_busy = 2'b00;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < PIPE_DEPTH; i = i + 1)
				if (valid[i])
					bank_busy[bank[i]] = 1'b1;
		end
	end
	always @(posedge clk)
		if (reset) begin
			valid[0] <= 1'b0;
			state[0] <= 1'sb0;
			bank[0] <= 1'sb0;
		end
		else if (!stall) begin
			valid[0] <= accept;
			if (accept) begin
				bank[0] <= current_bank;
				state[0] <= plaintext ^ round_keys[(((1 - current_bank) * 11) + aes_pkg_NUM_ROUNDS) * 128+:128];
			end
		end
	genvar _gv_r_1;
	generate
		for (_gv_r_1 = 1; _gv_r_1 < NUM_ROUNDS; _gv_r_1 = _gv_r_1 + 1) begin : ENC_STAGE
			localparam r = _gv_r_1;
			wire [127:0] sb;
			wire [127:0] sr;
			wire [127:0] mc;
			SubBytes u_sb(
				.inp(state[r - 1]),
				.res(sb)
			);
			ShiftRows u_sr(
				.inp(sb),
				.out(sr)
			);
			MixColumns u_mc(
				.inp(sr),
				.res(mc)
			);
			always @(posedge clk)
				if (reset) begin
					valid[r] <= 1'sb0;
					state[r] <= 1'sb0;
					bank[r] <= 1'sb0;
				end
				else if (!stall) begin
					valid[r] <= valid[r - 1];
					bank[r] <= bank[r - 1];
					state[r] <= mc ^ round_keys[(((1 - bank[r - 1]) * 11) + (aes_pkg_NUM_ROUNDS - r)) * 128+:128];
				end
		end
	endgenerate
	wire [127:0] sb_final;
	wire [127:0] sr_final;
	SubBytes u_sb_final(
		.inp(state[NUM_ROUNDS - 1]),
		.res(sb_final)
	);
	ShiftRows u_sr_final(
		.inp(sb_final),
		.out(sr_final)
	);
	always @(posedge clk)
		if (reset) begin
			valid[NUM_ROUNDS] <= 1'sb0;
			state[NUM_ROUNDS] <= 1'sb0;
			bank[NUM_ROUNDS] <= 1'sb0;
		end
		else if (!stall) begin
			valid[NUM_ROUNDS] <= valid[NUM_ROUNDS - 1];
			bank[NUM_ROUNDS] <= bank[NUM_ROUNDS - 1];
			state[NUM_ROUNDS] <= sr_final ^ round_keys[(((1 - bank[NUM_ROUNDS - 1]) * 11) + (aes_pkg_NUM_ROUNDS - NUM_ROUNDS)) * 128+:128];
		end
	assign ciphertext = state[NUM_ROUNDS];
	assign out_valid = valid[NUM_ROUNDS];
	initial _sv2v_0 = 0;
endmodule
module InvSubBytes (
	inp,
	res
);
	input [127:0] inp;
	output wire [127:0] res;
	genvar _gv_i_3;
	function automatic [7:0] inv_sbox;
		input [7:0] in;
		case (in)
			8'h00: inv_sbox = 8'h52;
			8'h01: inv_sbox = 8'h09;
			8'h02: inv_sbox = 8'h6a;
			8'h03: inv_sbox = 8'hd5;
			8'h04: inv_sbox = 8'h30;
			8'h05: inv_sbox = 8'h36;
			8'h06: inv_sbox = 8'ha5;
			8'h07: inv_sbox = 8'h38;
			8'h08: inv_sbox = 8'hbf;
			8'h09: inv_sbox = 8'h40;
			8'h0a: inv_sbox = 8'ha3;
			8'h0b: inv_sbox = 8'h9e;
			8'h0c: inv_sbox = 8'h81;
			8'h0d: inv_sbox = 8'hf3;
			8'h0e: inv_sbox = 8'hd7;
			8'h0f: inv_sbox = 8'hfb;
			8'h10: inv_sbox = 8'h7c;
			8'h11: inv_sbox = 8'he3;
			8'h12: inv_sbox = 8'h39;
			8'h13: inv_sbox = 8'h82;
			8'h14: inv_sbox = 8'h9b;
			8'h15: inv_sbox = 8'h2f;
			8'h16: inv_sbox = 8'hff;
			8'h17: inv_sbox = 8'h87;
			8'h18: inv_sbox = 8'h34;
			8'h19: inv_sbox = 8'h8e;
			8'h1a: inv_sbox = 8'h43;
			8'h1b: inv_sbox = 8'h44;
			8'h1c: inv_sbox = 8'hc4;
			8'h1d: inv_sbox = 8'hde;
			8'h1e: inv_sbox = 8'he9;
			8'h1f: inv_sbox = 8'hcb;
			8'h20: inv_sbox = 8'h54;
			8'h21: inv_sbox = 8'h7b;
			8'h22: inv_sbox = 8'h94;
			8'h23: inv_sbox = 8'h32;
			8'h24: inv_sbox = 8'ha6;
			8'h25: inv_sbox = 8'hc2;
			8'h26: inv_sbox = 8'h23;
			8'h27: inv_sbox = 8'h3d;
			8'h28: inv_sbox = 8'hee;
			8'h29: inv_sbox = 8'h4c;
			8'h2a: inv_sbox = 8'h95;
			8'h2b: inv_sbox = 8'h0b;
			8'h2c: inv_sbox = 8'h42;
			8'h2d: inv_sbox = 8'hfa;
			8'h2e: inv_sbox = 8'hc3;
			8'h2f: inv_sbox = 8'h4e;
			8'h30: inv_sbox = 8'h08;
			8'h31: inv_sbox = 8'h2e;
			8'h32: inv_sbox = 8'ha1;
			8'h33: inv_sbox = 8'h66;
			8'h34: inv_sbox = 8'h28;
			8'h35: inv_sbox = 8'hd9;
			8'h36: inv_sbox = 8'h24;
			8'h37: inv_sbox = 8'hb2;
			8'h38: inv_sbox = 8'h76;
			8'h39: inv_sbox = 8'h5b;
			8'h3a: inv_sbox = 8'ha2;
			8'h3b: inv_sbox = 8'h49;
			8'h3c: inv_sbox = 8'h6d;
			8'h3d: inv_sbox = 8'h8b;
			8'h3e: inv_sbox = 8'hd1;
			8'h3f: inv_sbox = 8'h25;
			8'h40: inv_sbox = 8'h72;
			8'h41: inv_sbox = 8'hf8;
			8'h42: inv_sbox = 8'hf6;
			8'h43: inv_sbox = 8'h64;
			8'h44: inv_sbox = 8'h86;
			8'h45: inv_sbox = 8'h68;
			8'h46: inv_sbox = 8'h98;
			8'h47: inv_sbox = 8'h16;
			8'h48: inv_sbox = 8'hd4;
			8'h49: inv_sbox = 8'ha4;
			8'h4a: inv_sbox = 8'h5c;
			8'h4b: inv_sbox = 8'hcc;
			8'h4c: inv_sbox = 8'h5d;
			8'h4d: inv_sbox = 8'h65;
			8'h4e: inv_sbox = 8'hb6;
			8'h4f: inv_sbox = 8'h92;
			8'h50: inv_sbox = 8'h6c;
			8'h51: inv_sbox = 8'h70;
			8'h52: inv_sbox = 8'h48;
			8'h53: inv_sbox = 8'h50;
			8'h54: inv_sbox = 8'hfd;
			8'h55: inv_sbox = 8'hed;
			8'h56: inv_sbox = 8'hb9;
			8'h57: inv_sbox = 8'hda;
			8'h58: inv_sbox = 8'h5e;
			8'h59: inv_sbox = 8'h15;
			8'h5a: inv_sbox = 8'h46;
			8'h5b: inv_sbox = 8'h57;
			8'h5c: inv_sbox = 8'ha7;
			8'h5d: inv_sbox = 8'h8d;
			8'h5e: inv_sbox = 8'h9d;
			8'h5f: inv_sbox = 8'h84;
			8'h60: inv_sbox = 8'h90;
			8'h61: inv_sbox = 8'hd8;
			8'h62: inv_sbox = 8'hab;
			8'h63: inv_sbox = 8'h00;
			8'h64: inv_sbox = 8'h8c;
			8'h65: inv_sbox = 8'hbc;
			8'h66: inv_sbox = 8'hd3;
			8'h67: inv_sbox = 8'h0a;
			8'h68: inv_sbox = 8'hf7;
			8'h69: inv_sbox = 8'he4;
			8'h6a: inv_sbox = 8'h58;
			8'h6b: inv_sbox = 8'h05;
			8'h6c: inv_sbox = 8'hb8;
			8'h6d: inv_sbox = 8'hb3;
			8'h6e: inv_sbox = 8'h45;
			8'h6f: inv_sbox = 8'h06;
			8'h70: inv_sbox = 8'hd0;
			8'h71: inv_sbox = 8'h2c;
			8'h72: inv_sbox = 8'h1e;
			8'h73: inv_sbox = 8'h8f;
			8'h74: inv_sbox = 8'hca;
			8'h75: inv_sbox = 8'h3f;
			8'h76: inv_sbox = 8'h0f;
			8'h77: inv_sbox = 8'h02;
			8'h78: inv_sbox = 8'hc1;
			8'h79: inv_sbox = 8'haf;
			8'h7a: inv_sbox = 8'hbd;
			8'h7b: inv_sbox = 8'h03;
			8'h7c: inv_sbox = 8'h01;
			8'h7d: inv_sbox = 8'h13;
			8'h7e: inv_sbox = 8'h8a;
			8'h7f: inv_sbox = 8'h6b;
			8'h80: inv_sbox = 8'h3a;
			8'h81: inv_sbox = 8'h91;
			8'h82: inv_sbox = 8'h11;
			8'h83: inv_sbox = 8'h41;
			8'h84: inv_sbox = 8'h4f;
			8'h85: inv_sbox = 8'h67;
			8'h86: inv_sbox = 8'hdc;
			8'h87: inv_sbox = 8'hea;
			8'h88: inv_sbox = 8'h97;
			8'h89: inv_sbox = 8'hf2;
			8'h8a: inv_sbox = 8'hcf;
			8'h8b: inv_sbox = 8'hce;
			8'h8c: inv_sbox = 8'hf0;
			8'h8d: inv_sbox = 8'hb4;
			8'h8e: inv_sbox = 8'he6;
			8'h8f: inv_sbox = 8'h73;
			8'h90: inv_sbox = 8'h96;
			8'h91: inv_sbox = 8'hac;
			8'h92: inv_sbox = 8'h74;
			8'h93: inv_sbox = 8'h22;
			8'h94: inv_sbox = 8'he7;
			8'h95: inv_sbox = 8'had;
			8'h96: inv_sbox = 8'h35;
			8'h97: inv_sbox = 8'h85;
			8'h98: inv_sbox = 8'he2;
			8'h99: inv_sbox = 8'hf9;
			8'h9a: inv_sbox = 8'h37;
			8'h9b: inv_sbox = 8'he8;
			8'h9c: inv_sbox = 8'h1c;
			8'h9d: inv_sbox = 8'h75;
			8'h9e: inv_sbox = 8'hdf;
			8'h9f: inv_sbox = 8'h6e;
			8'ha0: inv_sbox = 8'h47;
			8'ha1: inv_sbox = 8'hf1;
			8'ha2: inv_sbox = 8'h1a;
			8'ha3: inv_sbox = 8'h71;
			8'ha4: inv_sbox = 8'h1d;
			8'ha5: inv_sbox = 8'h29;
			8'ha6: inv_sbox = 8'hc5;
			8'ha7: inv_sbox = 8'h89;
			8'ha8: inv_sbox = 8'h6f;
			8'ha9: inv_sbox = 8'hb7;
			8'haa: inv_sbox = 8'h62;
			8'hab: inv_sbox = 8'h0e;
			8'hac: inv_sbox = 8'haa;
			8'had: inv_sbox = 8'h18;
			8'hae: inv_sbox = 8'hbe;
			8'haf: inv_sbox = 8'h1b;
			8'hb0: inv_sbox = 8'hfc;
			8'hb1: inv_sbox = 8'h56;
			8'hb2: inv_sbox = 8'h3e;
			8'hb3: inv_sbox = 8'h4b;
			8'hb4: inv_sbox = 8'hc6;
			8'hb5: inv_sbox = 8'hd2;
			8'hb6: inv_sbox = 8'h79;
			8'hb7: inv_sbox = 8'h20;
			8'hb8: inv_sbox = 8'h9a;
			8'hb9: inv_sbox = 8'hdb;
			8'hba: inv_sbox = 8'hc0;
			8'hbb: inv_sbox = 8'hfe;
			8'hbc: inv_sbox = 8'h78;
			8'hbd: inv_sbox = 8'hcd;
			8'hbe: inv_sbox = 8'h5a;
			8'hbf: inv_sbox = 8'hf4;
			8'hc0: inv_sbox = 8'h1f;
			8'hc1: inv_sbox = 8'hdd;
			8'hc2: inv_sbox = 8'ha8;
			8'hc3: inv_sbox = 8'h33;
			8'hc4: inv_sbox = 8'h88;
			8'hc5: inv_sbox = 8'h07;
			8'hc6: inv_sbox = 8'hc7;
			8'hc7: inv_sbox = 8'h31;
			8'hc8: inv_sbox = 8'hb1;
			8'hc9: inv_sbox = 8'h12;
			8'hca: inv_sbox = 8'h10;
			8'hcb: inv_sbox = 8'h59;
			8'hcc: inv_sbox = 8'h27;
			8'hcd: inv_sbox = 8'h80;
			8'hce: inv_sbox = 8'hec;
			8'hcf: inv_sbox = 8'h5f;
			8'hd0: inv_sbox = 8'h60;
			8'hd1: inv_sbox = 8'h51;
			8'hd2: inv_sbox = 8'h7f;
			8'hd3: inv_sbox = 8'ha9;
			8'hd4: inv_sbox = 8'h19;
			8'hd5: inv_sbox = 8'hb5;
			8'hd6: inv_sbox = 8'h4a;
			8'hd7: inv_sbox = 8'h0d;
			8'hd8: inv_sbox = 8'h2d;
			8'hd9: inv_sbox = 8'he5;
			8'hda: inv_sbox = 8'h7a;
			8'hdb: inv_sbox = 8'h9f;
			8'hdc: inv_sbox = 8'h93;
			8'hdd: inv_sbox = 8'hc9;
			8'hde: inv_sbox = 8'h9c;
			8'hdf: inv_sbox = 8'hef;
			8'he0: inv_sbox = 8'ha0;
			8'he1: inv_sbox = 8'he0;
			8'he2: inv_sbox = 8'h3b;
			8'he3: inv_sbox = 8'h4d;
			8'he4: inv_sbox = 8'hae;
			8'he5: inv_sbox = 8'h2a;
			8'he6: inv_sbox = 8'hf5;
			8'he7: inv_sbox = 8'hb0;
			8'he8: inv_sbox = 8'hc8;
			8'he9: inv_sbox = 8'heb;
			8'hea: inv_sbox = 8'hbb;
			8'heb: inv_sbox = 8'h3c;
			8'hec: inv_sbox = 8'h83;
			8'hed: inv_sbox = 8'h53;
			8'hee: inv_sbox = 8'h99;
			8'hef: inv_sbox = 8'h61;
			8'hf0: inv_sbox = 8'h17;
			8'hf1: inv_sbox = 8'h2b;
			8'hf2: inv_sbox = 8'h04;
			8'hf3: inv_sbox = 8'h7e;
			8'hf4: inv_sbox = 8'hba;
			8'hf5: inv_sbox = 8'h77;
			8'hf6: inv_sbox = 8'hd6;
			8'hf7: inv_sbox = 8'h26;
			8'hf8: inv_sbox = 8'he1;
			8'hf9: inv_sbox = 8'h69;
			8'hfa: inv_sbox = 8'h14;
			8'hfb: inv_sbox = 8'h63;
			8'hfc: inv_sbox = 8'h55;
			8'hfd: inv_sbox = 8'h21;
			8'hfe: inv_sbox = 8'h0c;
			8'hff: inv_sbox = 8'h7d;
			default: inv_sbox = 8'h00;
		endcase
	endfunction
	generate
		for (_gv_i_3 = 0; _gv_i_3 < 16; _gv_i_3 = _gv_i_3 + 1) begin : ISB
			localparam i = _gv_i_3;
			assign res[127 - (8 * i)-:8] = inv_sbox(inp[127 - (8 * i)-:8]);
		end
	endgenerate
endmodule
module InvShiftRows (
	inp,
	out
);
	input [127:0] inp;
	output wire [127:0] out;
	wire [7:0] b [15:0];
	assign {b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]} = inp;
	assign out = {b[0], b[13], b[10], b[7], b[4], b[1], b[14], b[11], b[8], b[5], b[2], b[15], b[12], b[9], b[6], b[3]};
endmodule
module InvMixColumns (
	inp,
	res
);
	input [127:0] inp;
	output wire [127:0] res;
	genvar _gv_i_4;
	function automatic [7:0] mix2;
		input [7:0] x;
		mix2 = (x << 1) ^ (x[7] ? 8'h1b : 8'h00);
	endfunction
	function automatic [7:0] mix4;
		input [7:0] x;
		mix4 = mix2(mix2(x));
	endfunction
	function automatic [7:0] mix8;
		input [7:0] x;
		mix8 = mix2(mix4(x));
	endfunction
	function automatic [7:0] mul11;
		input [7:0] x;
		mul11 = (mix8(x) ^ mix2(x)) ^ x;
	endfunction
	function automatic [7:0] mul13;
		input [7:0] x;
		mul13 = (mix8(x) ^ mix4(x)) ^ x;
	endfunction
	function automatic [7:0] mul14;
		input [7:0] x;
		mul14 = (mix8(x) ^ mix4(x)) ^ mix2(x);
	endfunction
	function automatic [7:0] mul9;
		input [7:0] x;
		mul9 = mix8(x) ^ x;
	endfunction
	generate
		for (_gv_i_4 = 0; _gv_i_4 < 4; _gv_i_4 = _gv_i_4 + 1) begin : genblk1
			localparam i = _gv_i_4;
			wire [7:0] s0;
			wire [7:0] s1;
			wire [7:0] s2;
			wire [7:0] s3;
			assign s0 = inp[127 - (32 * i):120 - (32 * i)];
			assign s1 = inp[119 - (32 * i):112 - (32 * i)];
			assign s2 = inp[111 - (32 * i):104 - (32 * i)];
			assign s3 = inp[103 - (32 * i):96 - (32 * i)];
			assign res[127 - (32 * i):120 - (32 * i)] = ((mul14(s0) ^ mul11(s1)) ^ mul13(s2)) ^ mul9(s3);
			assign res[119 - (32 * i):112 - (32 * i)] = ((mul9(s0) ^ mul14(s1)) ^ mul11(s2)) ^ mul13(s3);
			assign res[111 - (32 * i):104 - (32 * i)] = ((mul13(s0) ^ mul9(s1)) ^ mul14(s2)) ^ mul11(s3);
			assign res[103 - (32 * i):96 - (32 * i)] = ((mul11(s0) ^ mul13(s1)) ^ mul9(s2)) ^ mul14(s3);
		end
	endgenerate
endmodule
module AES_Decrypt (
	clk,
	reset,
	in_valid,
	in_ready,
	ciphertext,
	current_bank,
	round_keys,
	bank_busy,
	bank_valid,
	plaintext,
	out_valid,
	out_ready
);
	reg _sv2v_0;
	localparam signed [31:0] aes_pkg_NUM_ROUNDS = 10;
	parameter signed [31:0] NUM_ROUNDS = aes_pkg_NUM_ROUNDS;
	localparam signed [31:0] aes_pkg_PIPE_DEPTH = 11;
	parameter signed [31:0] PIPE_DEPTH = aes_pkg_PIPE_DEPTH;
	input wire clk;
	input wire reset;
	input wire in_valid;
	output wire in_ready;
	input wire [127:0] ciphertext;
	input wire current_bank;
	localparam signed [31:0] aes_pkg_NUM_BANKS = 2;
	input wire [2815:0] round_keys;
	output reg [1:0] bank_busy;
	input wire [1:0] bank_valid;
	output wire [127:0] plaintext;
	output wire out_valid;
	input wire out_ready;
	reg [127:0] state [0:PIPE_DEPTH - 1];
	reg valid [0:PIPE_DEPTH - 1];
	reg bank [0:PIPE_DEPTH - 1];
	wire stall;
	wire accept;
	assign stall = valid[PIPE_DEPTH - 1] && !out_ready;
	assign accept = (in_valid && bank_valid[current_bank]) && !stall;
	assign in_ready = !stall && bank_valid[current_bank];
	always @(*) begin
		if (_sv2v_0)
			;
		bank_busy = 2'b00;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < PIPE_DEPTH; i = i + 1)
				if (valid[i])
					bank_busy[bank[i]] = 1'b1;
		end
	end
	always @(posedge clk)
		if (reset) begin
			valid[0] <= 1'b0;
			state[0] <= 1'sb0;
			bank[0] <= 1'sb0;
		end
		else if (!stall) begin
			valid[0] <= accept;
			if (accept) begin
				bank[0] <= current_bank;
				state[0] <= ciphertext ^ round_keys[(((1 - current_bank) * 11) + (aes_pkg_NUM_ROUNDS - NUM_ROUNDS)) * 128+:128];
			end
		end
	genvar _gv_r_2;
	generate
		for (_gv_r_2 = 1; _gv_r_2 < NUM_ROUNDS; _gv_r_2 = _gv_r_2 + 1) begin : DEC_STAGE
			localparam r = _gv_r_2;
			wire [127:0] isr;
			wire [127:0] isb;
			wire [127:0] mc;
			InvShiftRows u_isr(
				.inp(state[r - 1]),
				.out(isr)
			);
			InvSubBytes u_isb(
				.inp(isr),
				.res(isb)
			);
			InvMixColumns u_imc(
				.inp(isb ^ round_keys[(((1 - bank[r - 1]) * 11) + (aes_pkg_NUM_ROUNDS - (NUM_ROUNDS - r))) * 128+:128]),
				.res(mc)
			);
			always @(posedge clk)
				if (reset) begin
					valid[r] <= 1'sb0;
					state[r] <= 1'sb0;
					bank[r] <= 1'sb0;
				end
				else if (!stall) begin
					valid[r] <= valid[r - 1];
					bank[r] <= bank[r - 1];
					state[r] <= mc;
				end
		end
	endgenerate
	wire [127:0] isr_final;
	wire [127:0] isb_final;
	InvShiftRows u_isr_final(
		.inp(state[NUM_ROUNDS - 1]),
		.out(isr_final)
	);
	InvSubBytes u_isb_final(
		.inp(isr_final),
		.res(isb_final)
	);
	always @(posedge clk)
		if (reset) begin
			valid[NUM_ROUNDS] <= 1'sb0;
			state[NUM_ROUNDS] <= 1'sb0;
			bank[NUM_ROUNDS] <= 1'sb0;
		end
		else if (!stall) begin
			valid[NUM_ROUNDS] <= valid[NUM_ROUNDS - 1];
			bank[NUM_ROUNDS] <= bank[NUM_ROUNDS - 1];
			state[NUM_ROUNDS] <= isb_final ^ round_keys[(((1 - bank[NUM_ROUNDS - 1]) * 11) + aes_pkg_NUM_ROUNDS) * 128+:128];
		end
	assign plaintext = state[NUM_ROUNDS];
	assign out_valid = valid[NUM_ROUNDS];
	initial _sv2v_0 = 0;
endmodule
module aes_top (
	clk,
	reset,
	key_push,
	key_in,
	key_push_ready,
	key_gen_out,
	op_mode,
	current_bank,
	key_gen,
	in_valid,
	in_ready,
	data_in,
	data_out,
	out_valid,
	out_ready,
	bank_valid,
	bank_free,
	key_system_busy,
	key_available,
	active_key_bank,
	bank_busy_total,
	bank_gen_flat,
	key_ctx_error
);
	reg _sv2v_0;
	input wire clk;
	input wire reset;
	input wire key_push;
	input wire [127:0] key_in;
	output wire key_push_ready;
	localparam signed [31:0] aes_pkg_KEY_GEN_W = 16;
	output wire [15:0] key_gen_out;
	input wire op_mode;
	input wire current_bank;
	input wire [15:0] key_gen;
	input wire in_valid;
	output reg in_ready;
	input wire [127:0] data_in;
	output wire [127:0] data_out;
	output wire out_valid;
	input wire out_ready;
	output wire [1:0] bank_valid;
	output wire [1:0] bank_free;
	output wire key_system_busy;
	output wire key_available;
	output wire active_key_bank;
	output wire [1:0] bank_busy_total;
	localparam signed [31:0] aes_pkg_NUM_BANKS = 2;
	output wire [(aes_pkg_NUM_BANKS * aes_pkg_KEY_GEN_W) - 1:0] bank_gen_flat;
	output wire key_ctx_error;
	localparam signed [31:0] aes_pkg_NUM_ROUNDS = 10;
	wire [2815:0] round_keys;
	wire [1:0] bank_busy_agg;
	key_system_top ksys_inst(
		.clk(clk),
		.reset(reset),
		.push(key_push),
		.key_in(key_in),
		.bank_busy(bank_busy_agg),
		.round_keys(round_keys),
		.bank_valid(bank_valid),
		.bank_free(bank_free),
		.key_system_busy(key_system_busy),
		.key_available(key_available),
		.active_bank(active_key_bank),
		.key_push_ready(key_push_ready),
		.key_gen_out(key_gen_out),
		.bank_gen_flat(bank_gen_flat)
	);
	wire key_ctx_ok;
	assign key_ctx_ok = key_gen == bank_gen_flat[current_bank * aes_pkg_KEY_GEN_W+:aes_pkg_KEY_GEN_W];
	assign key_ctx_error = (in_valid && bank_valid[current_bank]) && !key_ctx_ok;
	wire [1:0] enc_bank_busy;
	wire [1:0] dec_bank_busy;
	assign bank_busy_agg = enc_bank_busy | dec_bank_busy;
	assign bank_busy_total = enc_bank_busy | dec_bank_busy;
	wire enc_gate;
	wire dec_gate;
	assign enc_gate = dec_bank_busy == 2'b00;
	assign dec_gate = enc_bank_busy == 2'b00;
	wire enc_in_valid;
	wire dec_in_valid;
	wire enc_in_ready;
	wire dec_in_ready;
	assign enc_in_valid = ((in_valid && !op_mode) && enc_gate) && key_ctx_ok;
	assign dec_in_valid = ((in_valid && op_mode) && dec_gate) && key_ctx_ok;
	always @(*) begin
		if (_sv2v_0)
			;
		if (!op_mode)
			in_ready = (enc_gate && key_ctx_ok) && enc_in_ready;
		else
			in_ready = (dec_gate && key_ctx_ok) && dec_in_ready;
	end
	wire [127:0] enc_ciphertext;
	wire enc_out_valid;
	wire enc_out_ready;
	wire [1:0] enc_bank_valid_in;
	assign enc_bank_valid_in = bank_valid;
	AES_Encrypt enc_inst(
		.clk(clk),
		.reset(reset),
		.in_valid(enc_in_valid),
		.in_ready(enc_in_ready),
		.plaintext(data_in),
		.current_bank(current_bank),
		.round_keys(round_keys),
		.bank_busy(enc_bank_busy),
		.bank_valid(enc_bank_valid_in),
		.ciphertext(enc_ciphertext),
		.out_valid(enc_out_valid),
		.out_ready(enc_out_ready)
	);
	wire [127:0] dec_plaintext;
	wire dec_out_valid;
	wire dec_out_ready;
	wire [1:0] dec_bank_valid_in;
	assign dec_bank_valid_in = bank_valid;
	AES_Decrypt dec_inst(
		.clk(clk),
		.reset(reset),
		.in_valid(dec_in_valid),
		.in_ready(dec_in_ready),
		.ciphertext(data_in),
		.current_bank(current_bank),
		.round_keys(round_keys),
		.bank_busy(dec_bank_busy),
		.bank_valid(dec_bank_valid_in),
		.plaintext(dec_plaintext),
		.out_valid(dec_out_valid),
		.out_ready(dec_out_ready)
	);
	assign enc_out_ready = out_ready;
	assign dec_out_ready = out_ready;
	assign out_valid = enc_out_valid | dec_out_valid;
	assign data_out = (enc_out_valid ? enc_ciphertext : dec_plaintext);
	always @(posedge clk)
		if (!reset) begin
			if (enc_out_valid && dec_out_valid)
				$display("Error [%0t] rtl/aes_top.sv:268:17 - aes_top.<unnamed_block>.<unnamed_block>.<unnamed_block>\n msg: ", $time, "[aes_top] ASSERTION FAILED: enc_out_valid and dec_out_valid both high at t=%0t - output mux is unsafe", $time);
		end
	initial _sv2v_0 = 0;
endmodule
module rst_sync (
	clk,
	async_rst_n,
	sync_rst
);
	input wire clk;
	input wire async_rst_n;
	output wire sync_rst;
	(* ASYNC_REG = "TRUE" *) reg ff1;
	(* ASYNC_REG = "TRUE" *) reg ff2;
	always @(posedge clk or negedge async_rst_n)
		if (!async_rst_n) begin
			ff1 <= 1'b1;
			ff2 <= 1'b1;
		end
		else begin
			ff1 <= 1'b0;
			ff2 <= ff1;
		end
	assign sync_rst = ff2;
endmodule
module aes_axi_wrapper (
	ACLK,
	ARESETn,
	S_AXI_AWADDR,
	S_AXI_AWVALID,
	S_AXI_AWREADY,
	S_AXI_WDATA,
	S_AXI_WSTRB,
	S_AXI_WVALID,
	S_AXI_WREADY,
	S_AXI_BRESP,
	S_AXI_BVALID,
	S_AXI_BREADY,
	S_AXI_ARADDR,
	S_AXI_ARVALID,
	S_AXI_ARREADY,
	S_AXI_RDATA,
	S_AXI_RRESP,
	S_AXI_RVALID,
	S_AXI_RREADY,
	S_AXIS_TDATA,
	S_AXIS_TUSER,
	S_AXIS_TVALID,
	S_AXIS_TREADY,
	S_AXIS_TLAST,
	M_AXIS_TDATA,
	M_AXIS_TUSER,
	M_AXIS_TVALID,
	M_AXIS_TREADY,
	M_AXIS_TLAST
);
	reg _sv2v_0;
	parameter signed [31:0] C_S_AXI_ADDR_WIDTH = 8;
	input wire ACLK;
	input wire ARESETn;
	input wire [C_S_AXI_ADDR_WIDTH - 1:0] S_AXI_AWADDR;
	input wire S_AXI_AWVALID;
	output wire S_AXI_AWREADY;
	input wire [31:0] S_AXI_WDATA;
	input wire [3:0] S_AXI_WSTRB;
	input wire S_AXI_WVALID;
	output wire S_AXI_WREADY;
	output wire [1:0] S_AXI_BRESP;
	output wire S_AXI_BVALID;
	input wire S_AXI_BREADY;
	input wire [C_S_AXI_ADDR_WIDTH - 1:0] S_AXI_ARADDR;
	input wire S_AXI_ARVALID;
	output wire S_AXI_ARREADY;
	output reg [31:0] S_AXI_RDATA;
	output wire [1:0] S_AXI_RRESP;
	output wire S_AXI_RVALID;
	input wire S_AXI_RREADY;
	input wire [127:0] S_AXIS_TDATA;
	input wire [17:0] S_AXIS_TUSER;
	input wire S_AXIS_TVALID;
	output wire S_AXIS_TREADY;
	input wire S_AXIS_TLAST;
	output wire [127:0] M_AXIS_TDATA;
	output wire [0:0] M_AXIS_TUSER;
	output wire M_AXIS_TVALID;
	input wire M_AXIS_TREADY;
	output wire M_AXIS_TLAST;
	wire reset;
	rst_sync u_rst_sync(
		.clk(ACLK),
		.async_rst_n(ARESETn),
		.sync_rst(reset)
	);
	wire key_push;
	wire [127:0] key_in;
	wire key_push_ready;
	localparam signed [31:0] aes_pkg_KEY_GEN_W = 16;
	wire [15:0] key_gen_out;
	wire op_mode;
	wire current_bank;
	wire [15:0] key_gen;
	wire in_valid;
	wire in_ready;
	wire [127:0] data_in;
	wire [127:0] data_out;
	wire out_valid;
	wire out_ready;
	wire [1:0] bank_valid;
	wire [1:0] bank_free;
	wire [1:0] bank_busy_total;
	wire key_system_busy;
	wire key_available;
	wire active_key_bank;
	localparam signed [31:0] aes_pkg_NUM_BANKS = 2;
	wire [(aes_pkg_NUM_BANKS * aes_pkg_KEY_GEN_W) - 1:0] bank_gen_flat;
	wire key_ctx_error;
	localparam signed [31:0] aes_pkg_NUM_ROUNDS = 10;
	localparam signed [31:0] aes_pkg_PIPE_DEPTH = 11;
	reg op_mode_pipe [0:10];
	integer pd;
	always @(posedge ACLK)
		if (reset)
			for (pd = 0; pd < aes_pkg_PIPE_DEPTH; pd = pd + 1)
				op_mode_pipe[pd] <= 1'b0;
		else begin
			if (in_valid && in_ready)
				op_mode_pipe[0] <= op_mode;
			else
				op_mode_pipe[0] <= op_mode_pipe[0];
			for (pd = 1; pd < aes_pkg_PIPE_DEPTH; pd = pd + 1)
				op_mode_pipe[pd] <= op_mode_pipe[pd - 1];
		end
	assign M_AXIS_TUSER[0] = op_mode_pipe[10];
	aes_top u_aes_top(
		.clk(ACLK),
		.reset(reset),
		.key_push(key_push),
		.key_in(key_in),
		.key_push_ready(key_push_ready),
		.key_gen_out(key_gen_out),
		.op_mode(op_mode),
		.current_bank(current_bank),
		.key_gen(key_gen),
		.in_valid(in_valid),
		.in_ready(in_ready),
		.data_in(data_in),
		.data_out(data_out),
		.out_valid(out_valid),
		.out_ready(out_ready),
		.bank_valid(bank_valid),
		.bank_free(bank_free),
		.key_system_busy(key_system_busy),
		.key_available(key_available),
		.active_key_bank(active_key_bank),
		.bank_busy_total(bank_busy_total),
		.bank_gen_flat(bank_gen_flat),
		.key_ctx_error(key_ctx_error)
	);
	assign data_in = S_AXIS_TDATA;
	assign op_mode = S_AXIS_TUSER[0];
	assign current_bank = S_AXIS_TUSER[1];
	function automatic [15:0] sv2v_cast_B5163;
		input reg [15:0] inp;
		sv2v_cast_B5163 = inp;
	endfunction
	assign key_gen = sv2v_cast_B5163(S_AXIS_TUSER[17:2]);
	assign in_valid = S_AXIS_TVALID;
	assign S_AXIS_TREADY = in_ready;
	assign M_AXIS_TDATA = data_out;
	assign M_AXIS_TVALID = out_valid;
	assign out_ready = M_AXIS_TREADY;
	assign M_AXIS_TLAST = 1'b1;
	localparam [1:0] AXI_OK = 2'b00;
	reg bvalid_q;
	wire aw_w_accept;
	assign aw_w_accept = (S_AXI_AWVALID && S_AXI_WVALID) && !bvalid_q;
	assign S_AXI_AWREADY = aw_w_accept;
	assign S_AXI_WREADY = aw_w_accept;
	wire do_write;
	assign do_write = aw_w_accept;
	always @(posedge ACLK)
		if (reset)
			bvalid_q <= 1'b0;
		else if (do_write)
			bvalid_q <= 1'b1;
		else if (S_AXI_BVALID && S_AXI_BREADY)
			bvalid_q <= 1'b0;
	assign S_AXI_BVALID = bvalid_q;
	assign S_AXI_BRESP = AXI_OK;
	localparam [C_S_AXI_ADDR_WIDTH - 1:0] ADDR_KEY_IN0 = 8'h00;
	localparam [C_S_AXI_ADDR_WIDTH - 1:0] ADDR_KEY_IN1 = 8'h04;
	localparam [C_S_AXI_ADDR_WIDTH - 1:0] ADDR_KEY_IN2 = 8'h08;
	localparam [C_S_AXI_ADDR_WIDTH - 1:0] ADDR_KEY_IN3 = 8'h0c;
	localparam [C_S_AXI_ADDR_WIDTH - 1:0] ADDR_KEY_CTRL = 8'h10;
	localparam [C_S_AXI_ADDR_WIDTH - 1:0] ADDR_KEY_STATUS = 8'h14;
	localparam [C_S_AXI_ADDR_WIDTH - 1:0] ADDR_KEY_GEN = 8'h18;
	localparam [C_S_AXI_ADDR_WIDTH - 1:0] ADDR_BANK_GEN = 8'h1c;
	localparam [C_S_AXI_ADDR_WIDTH - 1:0] ADDR_ERR_CNT = 8'h20;
	localparam [C_S_AXI_ADDR_WIDTH - 1:0] ADDR_VERSION = 8'h24;
	reg [127:0] key_stage_q;
	reg key_push_pulse;
	reg [15:0] key_ctx_err_cnt_q;
	reg key_ctx_error_sticky_q;
	reg [15:0] key_gen_handle_q;
	always @(posedge ACLK)
		if (reset)
			key_gen_handle_q <= 1'sb0;
		else if (key_push && key_push_ready)
			key_gen_handle_q <= key_gen_out;
	wire [C_S_AXI_ADDR_WIDTH - 1:0] write_addr;
	assign write_addr = S_AXI_AWADDR;
	function automatic [31:0] wstrobe;
		input reg [31:0] cur;
		input reg [31:0] wdata;
		input reg [3:0] strb;
		reg [31:0] result;
		begin
			result = cur;
			if (strb[0])
				result[7:0] = wdata[7:0];
			if (strb[1])
				result[15:8] = wdata[15:8];
			if (strb[2])
				result[23:16] = wdata[23:16];
			if (strb[3])
				result[31:24] = wdata[31:24];
			wstrobe = result;
		end
	endfunction
	always @(posedge ACLK)
		if (reset) begin
			key_stage_q <= 1'sb0;
			key_push_pulse <= 1'b0;
			key_ctx_err_cnt_q <= 1'sb0;
			key_ctx_error_sticky_q <= 1'b0;
		end
		else begin
			key_push_pulse <= 1'b0;
			if (do_write)
				(* full_case, parallel_case *)
				case (write_addr)
					ADDR_KEY_IN0: key_stage_q[31:0] <= wstrobe(key_stage_q[31:0], S_AXI_WDATA, S_AXI_WSTRB);
					ADDR_KEY_IN1: key_stage_q[63:32] <= wstrobe(key_stage_q[63:32], S_AXI_WDATA, S_AXI_WSTRB);
					ADDR_KEY_IN2: key_stage_q[95:64] <= wstrobe(key_stage_q[95:64], S_AXI_WDATA, S_AXI_WSTRB);
					ADDR_KEY_IN3: key_stage_q[127:96] <= wstrobe(key_stage_q[127:96], S_AXI_WDATA, S_AXI_WSTRB);
					ADDR_KEY_CTRL: key_push_pulse <= S_AXI_WDATA[0];
					ADDR_ERR_CNT: begin
						key_ctx_err_cnt_q <= 1'sb0;
						key_ctx_error_sticky_q <= 1'b0;
					end
					default:
						;
				endcase
			if (key_ctx_error) begin
				key_ctx_error_sticky_q <= 1'b1;
				if (key_ctx_err_cnt_q != 16'hffff)
					key_ctx_err_cnt_q <= key_ctx_err_cnt_q + 16'h0001;
			end
		end
	assign key_in = key_stage_q;
	assign key_push = key_push_pulse;
	reg rvalid_q;
	wire ar_accept;
	assign ar_accept = S_AXI_ARVALID && !rvalid_q;
	assign S_AXI_ARREADY = !rvalid_q;
	reg [C_S_AXI_ADDR_WIDTH - 1:0] araddr_q;
	always @(posedge ACLK)
		if (reset)
			araddr_q <= 1'sb0;
		else if (ar_accept)
			araddr_q <= S_AXI_ARADDR;
	always @(posedge ACLK)
		if (reset)
			rvalid_q <= 1'b0;
		else if (ar_accept)
			rvalid_q <= 1'b1;
		else if (S_AXI_RVALID && S_AXI_RREADY)
			rvalid_q <= 1'b0;
	assign S_AXI_RVALID = rvalid_q;
	assign S_AXI_RRESP = AXI_OK;
	wire [31:0] key_status_word;
	assign key_status_word = {21'b000000000000000000000, key_ctx_error_sticky_q, bank_busy_total, bank_free, bank_valid, active_key_bank, key_available, key_system_busy, key_push_ready};
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (araddr_q)
			ADDR_KEY_STATUS: S_AXI_RDATA = key_status_word;
			ADDR_KEY_GEN: S_AXI_RDATA = {16'b0000000000000000, key_gen_handle_q};
			ADDR_BANK_GEN: S_AXI_RDATA = {bank_gen_flat[31:aes_pkg_KEY_GEN_W], bank_gen_flat[15:0]};
			ADDR_ERR_CNT: S_AXI_RDATA = {16'b0000000000000000, key_ctx_err_cnt_q};
			ADDR_VERSION: S_AXI_RDATA = 32'h41455331;
			default: S_AXI_RDATA = 32'h00000000;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
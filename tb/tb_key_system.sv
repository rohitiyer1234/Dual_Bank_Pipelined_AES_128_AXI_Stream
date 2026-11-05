`timescale 1ns/1ps
//=============================================================================
// tb_key_system.sv
//
// Regular (non-layered) directed + scoreboarded testbench for
// key_system_top: key_fifo -> key_controller -> AES_Key_Expansion_128 ->
// keymem_dual.
//
// Style mirrors tb_encrypt_test.sv (negedge-only stimulus, posedge-only
// sampling, explicit pass/fail scoreboard per test) so it's consistent
// with the rest of the suite.
//
// A software reference key-schedule (ref_expand_key, independently coded
// from FIPS-197, not copy-pasted from the RTL) is used to check every
// round key written into either bank.
//
// SIMULATOR NOTE (Icarus Verilog specific - not an RTL issue)
// --------------------------------------------------------------
// Icarus Verilog does not correctly propagate values through OUTPUT
// ports typed as an unpacked array via a typedef (rk_store_t here)
// once more than one level of hierarchy is crossed - confirmed with an
// isolated 2-line repro independent of this design (a trivial
// output-port array written in one module reads back as 'x' from its
// grandparent, while the same array read as an INPUT port propagates
// correctly). This is a known category of gap in Icarus's SystemVerilog
// support, not a violation of the LRM - Vivado XSIM, Questa and VCS all
// propagate this correctly. Because key_system_top.round_keys is itself
// fed from keymem_dual's output port, its value does not reach this
// testbench's top-level `round_keys` port connection under Icarus. All
// checks below therefore read the underlying storage directly via the
// hierarchical path `dut.keymem_inst.round_keys` - this is only needed
// to get a runnable regression under Icarus; on Vivado/Questa the
// port-level `round_keys` signal works identically and either form may
// be used.
//=============================================================================

module tb_key_system;

import aes_pkg::*;

//=============================================================================
// DUT INTERFACE
//=============================================================================

logic        clk;
logic        reset;

logic        push;
aes_block_t  key_in;

logic [1:0]  bank_busy;

rk_store_t   round_keys;
logic [1:0]  bank_valid;
logic [1:0]  bank_free;
logic        key_system_busy;
logic        key_available;
logic        active_bank;

//=============================================================================
// DUT
//=============================================================================

key_system_top dut (
    .clk             (clk),
    .reset           (reset),
    .push            (push),
    .key_in          (key_in),
    .bank_busy       (bank_busy),
    .round_keys      (round_keys),
    .bank_valid      (bank_valid),
    .bank_free       (bank_free),
    .key_system_busy (key_system_busy),
    .key_available   (key_available),
    .active_bank     (active_bank)
);

//=============================================================================
// CLOCK - 100 MHz, negedge at 5 ns, posedge at 10 ns (matches tb_encrypt)
//=============================================================================

initial clk = 0;
always #5 clk = ~clk;

//=============================================================================
// SOFTWARE REFERENCE KEY SCHEDULE (independent of RTL, FIPS-197 5.2)
//=============================================================================

function automatic aes_byte_t ref_sbox(input aes_byte_t a);
    // Same 256-entry AES forward S-box, written independently here so the
    // scoreboard is not merely re-checking the RTL's own copy against
    // itself.
    case (a)
        8'h00:ref_sbox=8'h63; 8'h01:ref_sbox=8'h7c; 8'h02:ref_sbox=8'h77; 8'h03:ref_sbox=8'h7b;
        8'h04:ref_sbox=8'hf2; 8'h05:ref_sbox=8'h6b; 8'h06:ref_sbox=8'h6f; 8'h07:ref_sbox=8'hc5;
        8'h08:ref_sbox=8'h30; 8'h09:ref_sbox=8'h01; 8'h0a:ref_sbox=8'h67; 8'h0b:ref_sbox=8'h2b;
        8'h0c:ref_sbox=8'hfe; 8'h0d:ref_sbox=8'hd7; 8'h0e:ref_sbox=8'hab; 8'h0f:ref_sbox=8'h76;
        8'h10:ref_sbox=8'hca; 8'h11:ref_sbox=8'h82; 8'h12:ref_sbox=8'hc9; 8'h13:ref_sbox=8'h7d;
        8'h14:ref_sbox=8'hfa; 8'h15:ref_sbox=8'h59; 8'h16:ref_sbox=8'h47; 8'h17:ref_sbox=8'hf0;
        8'h18:ref_sbox=8'had; 8'h19:ref_sbox=8'hd4; 8'h1a:ref_sbox=8'ha2; 8'h1b:ref_sbox=8'haf;
        8'h1c:ref_sbox=8'h9c; 8'h1d:ref_sbox=8'ha4; 8'h1e:ref_sbox=8'h72; 8'h1f:ref_sbox=8'hc0;
        8'h20:ref_sbox=8'hb7; 8'h21:ref_sbox=8'hfd; 8'h22:ref_sbox=8'h93; 8'h23:ref_sbox=8'h26;
        8'h24:ref_sbox=8'h36; 8'h25:ref_sbox=8'h3f; 8'h26:ref_sbox=8'hf7; 8'h27:ref_sbox=8'hcc;
        8'h28:ref_sbox=8'h34; 8'h29:ref_sbox=8'ha5; 8'h2a:ref_sbox=8'he5; 8'h2b:ref_sbox=8'hf1;
        8'h2c:ref_sbox=8'h71; 8'h2d:ref_sbox=8'hd8; 8'h2e:ref_sbox=8'h31; 8'h2f:ref_sbox=8'h15;
        8'h30:ref_sbox=8'h04; 8'h31:ref_sbox=8'hc7; 8'h32:ref_sbox=8'h23; 8'h33:ref_sbox=8'hc3;
        8'h34:ref_sbox=8'h18; 8'h35:ref_sbox=8'h96; 8'h36:ref_sbox=8'h05; 8'h37:ref_sbox=8'h9a;
        8'h38:ref_sbox=8'h07; 8'h39:ref_sbox=8'h12; 8'h3a:ref_sbox=8'h80; 8'h3b:ref_sbox=8'he2;
        8'h3c:ref_sbox=8'heb; 8'h3d:ref_sbox=8'h27; 8'h3e:ref_sbox=8'hb2; 8'h3f:ref_sbox=8'h75;
        8'h40:ref_sbox=8'h09; 8'h41:ref_sbox=8'h83; 8'h42:ref_sbox=8'h2c; 8'h43:ref_sbox=8'h1a;
        8'h44:ref_sbox=8'h1b; 8'h45:ref_sbox=8'h6e; 8'h46:ref_sbox=8'h5a; 8'h47:ref_sbox=8'ha0;
        8'h48:ref_sbox=8'h52; 8'h49:ref_sbox=8'h3b; 8'h4a:ref_sbox=8'hd6; 8'h4b:ref_sbox=8'hb3;
        8'h4c:ref_sbox=8'h29; 8'h4d:ref_sbox=8'he3; 8'h4e:ref_sbox=8'h2f; 8'h4f:ref_sbox=8'h84;
        8'h50:ref_sbox=8'h53; 8'h51:ref_sbox=8'hd1; 8'h52:ref_sbox=8'h00; 8'h53:ref_sbox=8'hed;
        8'h54:ref_sbox=8'h20; 8'h55:ref_sbox=8'hfc; 8'h56:ref_sbox=8'hb1; 8'h57:ref_sbox=8'h5b;
        8'h58:ref_sbox=8'h6a; 8'h59:ref_sbox=8'hcb; 8'h5a:ref_sbox=8'hbe; 8'h5b:ref_sbox=8'h39;
        8'h5c:ref_sbox=8'h4a; 8'h5d:ref_sbox=8'h4c; 8'h5e:ref_sbox=8'h58; 8'h5f:ref_sbox=8'hcf;
        8'h60:ref_sbox=8'hd0; 8'h61:ref_sbox=8'hef; 8'h62:ref_sbox=8'haa; 8'h63:ref_sbox=8'hfb;
        8'h64:ref_sbox=8'h43; 8'h65:ref_sbox=8'h4d; 8'h66:ref_sbox=8'h33; 8'h67:ref_sbox=8'h85;
        8'h68:ref_sbox=8'h45; 8'h69:ref_sbox=8'hf9; 8'h6a:ref_sbox=8'h02; 8'h6b:ref_sbox=8'h7f;
        8'h6c:ref_sbox=8'h50; 8'h6d:ref_sbox=8'h3c; 8'h6e:ref_sbox=8'h9f; 8'h6f:ref_sbox=8'ha8;
        8'h70:ref_sbox=8'h51; 8'h71:ref_sbox=8'ha3; 8'h72:ref_sbox=8'h40; 8'h73:ref_sbox=8'h8f;
        8'h74:ref_sbox=8'h92; 8'h75:ref_sbox=8'h9d; 8'h76:ref_sbox=8'h38; 8'h77:ref_sbox=8'hf5;
        8'h78:ref_sbox=8'hbc; 8'h79:ref_sbox=8'hb6; 8'h7a:ref_sbox=8'hda; 8'h7b:ref_sbox=8'h21;
        8'h7c:ref_sbox=8'h10; 8'h7d:ref_sbox=8'hff; 8'h7e:ref_sbox=8'hf3; 8'h7f:ref_sbox=8'hd2;
        8'h80:ref_sbox=8'hcd; 8'h81:ref_sbox=8'h0c; 8'h82:ref_sbox=8'h13; 8'h83:ref_sbox=8'hec;
        8'h84:ref_sbox=8'h5f; 8'h85:ref_sbox=8'h97; 8'h86:ref_sbox=8'h44; 8'h87:ref_sbox=8'h17;
        8'h88:ref_sbox=8'hc4; 8'h89:ref_sbox=8'ha7; 8'h8a:ref_sbox=8'h7e; 8'h8b:ref_sbox=8'h3d;
        8'h8c:ref_sbox=8'h64; 8'h8d:ref_sbox=8'h5d; 8'h8e:ref_sbox=8'h19; 8'h8f:ref_sbox=8'h73;
        8'h90:ref_sbox=8'h60; 8'h91:ref_sbox=8'h81; 8'h92:ref_sbox=8'h4f; 8'h93:ref_sbox=8'hdc;
        8'h94:ref_sbox=8'h22; 8'h95:ref_sbox=8'h2a; 8'h96:ref_sbox=8'h90; 8'h97:ref_sbox=8'h88;
        8'h98:ref_sbox=8'h46; 8'h99:ref_sbox=8'hee; 8'h9a:ref_sbox=8'hb8; 8'h9b:ref_sbox=8'h14;
        8'h9c:ref_sbox=8'hde; 8'h9d:ref_sbox=8'h5e; 8'h9e:ref_sbox=8'h0b; 8'h9f:ref_sbox=8'hdb;
        8'ha0:ref_sbox=8'he0; 8'ha1:ref_sbox=8'h32; 8'ha2:ref_sbox=8'h3a; 8'ha3:ref_sbox=8'h0a;
        8'ha4:ref_sbox=8'h49; 8'ha5:ref_sbox=8'h06; 8'ha6:ref_sbox=8'h24; 8'ha7:ref_sbox=8'h5c;
        8'ha8:ref_sbox=8'hc2; 8'ha9:ref_sbox=8'hd3; 8'haa:ref_sbox=8'hac; 8'hab:ref_sbox=8'h62;
        8'hac:ref_sbox=8'h91; 8'had:ref_sbox=8'h95; 8'hae:ref_sbox=8'he4; 8'haf:ref_sbox=8'h79;
        8'hb0:ref_sbox=8'he7; 8'hb1:ref_sbox=8'hc8; 8'hb2:ref_sbox=8'h37; 8'hb3:ref_sbox=8'h6d;
        8'hb4:ref_sbox=8'h8d; 8'hb5:ref_sbox=8'hd5; 8'hb6:ref_sbox=8'h4e; 8'hb7:ref_sbox=8'ha9;
        8'hb8:ref_sbox=8'h6c; 8'hb9:ref_sbox=8'h56; 8'hba:ref_sbox=8'hf4; 8'hbb:ref_sbox=8'hea;
        8'hbc:ref_sbox=8'h65; 8'hbd:ref_sbox=8'h7a; 8'hbe:ref_sbox=8'hae; 8'hbf:ref_sbox=8'h08;
        8'hc0:ref_sbox=8'hba; 8'hc1:ref_sbox=8'h78; 8'hc2:ref_sbox=8'h25; 8'hc3:ref_sbox=8'h2e;
        8'hc4:ref_sbox=8'h1c; 8'hc5:ref_sbox=8'ha6; 8'hc6:ref_sbox=8'hb4; 8'hc7:ref_sbox=8'hc6;
        8'hc8:ref_sbox=8'he8; 8'hc9:ref_sbox=8'hdd; 8'hca:ref_sbox=8'h74; 8'hcb:ref_sbox=8'h1f;
        8'hcc:ref_sbox=8'h4b; 8'hcd:ref_sbox=8'hbd; 8'hce:ref_sbox=8'h8b; 8'hcf:ref_sbox=8'h8a;
        8'hd0:ref_sbox=8'h70; 8'hd1:ref_sbox=8'h3e; 8'hd2:ref_sbox=8'hb5; 8'hd3:ref_sbox=8'h66;
        8'hd4:ref_sbox=8'h48; 8'hd5:ref_sbox=8'h03; 8'hd6:ref_sbox=8'hf6; 8'hd7:ref_sbox=8'h0e;
        8'hd8:ref_sbox=8'h61; 8'hd9:ref_sbox=8'h35; 8'hda:ref_sbox=8'h57; 8'hdb:ref_sbox=8'hb9;
        8'hdc:ref_sbox=8'h86; 8'hdd:ref_sbox=8'hc1; 8'hde:ref_sbox=8'h1d; 8'hdf:ref_sbox=8'h9e;
        8'he0:ref_sbox=8'he1; 8'he1:ref_sbox=8'hf8; 8'he2:ref_sbox=8'h98; 8'he3:ref_sbox=8'h11;
        8'he4:ref_sbox=8'h69; 8'he5:ref_sbox=8'hd9; 8'he6:ref_sbox=8'h8e; 8'he7:ref_sbox=8'h94;
        8'he8:ref_sbox=8'h9b; 8'he9:ref_sbox=8'h1e; 8'hea:ref_sbox=8'h87; 8'heb:ref_sbox=8'he9;
        8'hec:ref_sbox=8'hce; 8'hed:ref_sbox=8'h55; 8'hee:ref_sbox=8'h28; 8'hef:ref_sbox=8'hdf;
        8'hf0:ref_sbox=8'h8c; 8'hf1:ref_sbox=8'ha1; 8'hf2:ref_sbox=8'h89; 8'hf3:ref_sbox=8'h0d;
        8'hf4:ref_sbox=8'hbf; 8'hf5:ref_sbox=8'he6; 8'hf6:ref_sbox=8'h42; 8'hf7:ref_sbox=8'h68;
        8'hf8:ref_sbox=8'h41; 8'hf9:ref_sbox=8'h99; 8'hfa:ref_sbox=8'h2d; 8'hfb:ref_sbox=8'h0f;
        8'hfc:ref_sbox=8'hb0; 8'hfd:ref_sbox=8'h54; 8'hfe:ref_sbox=8'hbb; 8'hff:ref_sbox=8'h16;
        default: ref_sbox = 8'h00;
    endcase
endfunction

function automatic aes_byte_t ref_rcon(input int r);
    case (r)
        1:ref_rcon=8'h01; 2:ref_rcon=8'h02; 3:ref_rcon=8'h04; 4:ref_rcon=8'h08; 5:ref_rcon=8'h10;
        6:ref_rcon=8'h20; 7:ref_rcon=8'h40; 8:ref_rcon=8'h80; 9:ref_rcon=8'h1b; 10:ref_rcon=8'h36;
        default: ref_rcon = 8'h00;
    endcase
endfunction

// Populates the module-level ref_key_out[] array as a side effect (Icarus
// Verilog has weak support for unpacked-array function/task ports, so a
// global scratch array is used instead of returning/passing rk_bank_t).
aes_block_t ref_key_out [0:10];

task automatic ref_expand_key(input aes_block_t key);
    aes_word_t w[0:43];
    w[0] = key[127:96]; w[1] = key[95:64]; w[2] = key[63:32]; w[3] = key[31:0];
    for (int i = 4; i < 44; i++) begin
        aes_word_t temp = w[i-1];
        if (i % 4 == 0) begin
            aes_word_t rotw = {temp[23:0], temp[31:24]};
            temp = {ref_sbox(rotw[31:24]), ref_sbox(rotw[23:16]),
                    ref_sbox(rotw[15:8]),  ref_sbox(rotw[7:0])} ^ {ref_rcon(i/4), 24'h0};
        end
        w[i] = w[i-4] ^ temp;
    end
    for (int r = 0; r <= 10; r++)
        ref_key_out[r] = {w[4*r], w[4*r+1], w[4*r+2], w[4*r+3]};
endtask

//=============================================================================
// SCOREBOARD HELPERS
//=============================================================================

int pass_count = 0;
int fail_count = 0;

task automatic check_bank(input logic bank, input aes_block_t key, input string tag);
    int errs = 0;
    ref_expand_key(key);
    for (int r = 0; r <= aes_pkg::NUM_ROUNDS; r++) begin
        // NOTE: reads dut.keymem_inst.round_keys (hierarchical) rather
        // than the port-level `round_keys` signal above. This is an
        // Icarus Verilog workaround, not an RTL requirement - see the
        // "SIMULATOR NOTE" block near the top of this file for why.
        if (dut.keymem_inst.round_keys[bank][r] !== ref_key_out[r]) begin
            $display("[%s] MISMATCH bank=%0d round=%0d got=%032h exp=%032h",
                      tag, bank, r, dut.keymem_inst.round_keys[bank][r], ref_key_out[r]);
            errs++;
        end
    end
    if (errs == 0) begin
        pass_count++;
        $display("[%s] PASS  bank=%0d key=%032h - all 11 round keys correct", tag, bank, key);
    end else begin
        fail_count++;
    end
endtask

task automatic push_key(input aes_block_t key);
    @(negedge clk);
    key_in = key;
    push   = 1'b1;
    @(negedge clk);
    push   = 1'b0;
endtask

task automatic wait_cycles(input int n);
    repeat (n) @(posedge clk);
endtask

// Waits (with timeout) for a bank to report valid.
task automatic wait_bank_valid(input logic bank, input int timeout = 200);
    int cnt = 0;
    while (!bank_valid[bank] && cnt < timeout) begin
        @(posedge clk);
        cnt++;
    end
    if (!bank_valid[bank]) begin
        $display("[TIMEOUT] bank %0d never went valid", bank);
        fail_count++;
    end
endtask

task automatic print_result(input string name, input int p, input int f);
    $display("+------------------------------------------+");
    $display("|  %-40s  |", name);
    $display("|  PASS=%-5d  FAIL=%-5d                  |", p, f);
    if (f == 0) $display("|  *** PASSED ***                          |");
    else        $display("|  *** FAILED ***                          |");
    $display("+------------------------------------------+\n");
endtask

//=============================================================================
// TEST 1 - FIPS-197 KAT keys into bank0 then bank1, sequential
//=============================================================================
task automatic test1_fips_kat();
    int p0, f0;
    $display("\n====================================");
    $display("TEST 1 : FIPS-197 KAT (dual bank fill)");
    $display("====================================");
    p0 = pass_count; f0 = fail_count;

    bank_busy = 2'b00;

    push_key(128'h2b7e151628aed2a6abf7158809cf4f3c);
    wait_bank_valid(1'b0);
    check_bank(1'b0, 128'h2b7e151628aed2a6abf7158809cf4f3c, "T1");

    push_key(128'h000102030405060708090a0b0c0d0e0f);
    wait_bank_valid(1'b1);
    check_bank(1'b1, 128'h000102030405060708090a0b0c0d0e0f, "T1");

    print_result("TEST 1: FIPS-197 KAT DUAL BANK", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// TEST 2 - Bank reuse: both banks full+idle, push a 3rd key.
// Policy (key_system_top FIX-KST3): release bank0 first.
//=============================================================================
task automatic test2_bank_reuse();
    int p0, f0;
    aes_block_t k3 = 128'hdeadbeefcafebabe0123456789abcdef;
    $display("\n====================================");
    $display("TEST 2 : BANK REUSE / ROTATION");
    $display("====================================");
    p0 = pass_count; f0 = fail_count;

    if (!bank_valid[0] || !bank_valid[1]) begin
        $display("[T2] precondition failed: both banks should be valid from TEST1");
        fail_count++;
    end

    bank_busy = 2'b00; // both idle -> bank0 released and reused first
    push_key(k3);
    begin
        int cnt = 0;
        while (dut.keymem_inst.round_keys[0][0] !== k3 && cnt < 60) begin
            @(posedge clk);
            cnt++;
        end
    end
    wait_bank_valid(1'b0);
    check_bank(1'b0, k3, "T2");

    if (!bank_valid[1]) begin
        $display("[T2] FAIL: bank1 should remain valid (untouched) while bank0 was reused");
        fail_count++;
    end else begin
        pass_count++;
    end

    print_result("TEST 2: BANK REUSE / ROTATION", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// TEST 3 - Busy blocking: mark both banks busy, push a key, confirm no
// release/overwrite happens until a bank frees up.
//=============================================================================
task automatic test3_busy_blocking();
    int p0, f0;
    aes_block_t k4 = 128'h00112233445566778899aabbccddeeff;
    aes_block_t saved0, saved1;
    $display("\n====================================");
    $display("TEST 3 : BUSY BLOCKS RELEASE/REUSE");
    $display("====================================");
    p0 = pass_count; f0 = fail_count;

    saved0 = dut.keymem_inst.round_keys[0][0];
    saved1 = dut.keymem_inst.round_keys[1][0];

    bank_busy = 2'b11; // both banks busy - neither may be released
    push_key(k4);
    wait_cycles(20);

    if (dut.keymem_inst.round_keys[0][0] !== saved0 || dut.keymem_inst.round_keys[1][0] !== saved1) begin
        $display("[T3] FAIL: a busy bank's key was overwritten");
        fail_count++;
    end else begin
        pass_count++;
        $display("[T3] PASS: both busy banks preserved their keys");
    end

    if (!key_system_busy) begin
        $display("[T3] FAIL: key_system_busy should be 1 (key pending in FIFO)");
        fail_count++;
    end else begin
        pass_count++;
    end

    // Free bank1 (bank_busy[1]=0), keep bank0 busy (bank_busy[0]=1) -
    // expect the pending key to land in bank1.
    bank_busy = 2'b01;
    begin
        int cnt = 0;
        while (dut.keymem_inst.round_keys[1][0] !== k4 && cnt < 60) begin
            @(posedge clk);
            cnt++;
        end
    end
    wait_bank_valid(1'b1);
    check_bank(1'b1, k4, "T3");

    bank_busy = 2'b00;
    print_result("TEST 3: BUSY BLOCKS RELEASE/REUSE", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// TEST 4 - Random regression, continuous refill of bank0 (never busy)
//=============================================================================
task automatic test4_random(input int num_keys = 40);
    int p0, f0;
    $display("\n====================================");
    $display("TEST 4 : RANDOM REGRESSION (%0d keys)", num_keys);
    $display("====================================");
    p0 = pass_count; f0 = fail_count;
    bank_busy = 2'b00;
    wait_cycles(20); // let TEST3's tail settle before starting

    for (int i = 0; i < num_keys; i++) begin
        aes_block_t k = {$urandom, $urandom, $urandom, $urandom};
        int cnt = 0;
        logic found;
        push_key(k);
        found = 1'b0;
        // Poll (bounded) instead of a fixed delay - robust to bank
        // release/rotation latency instead of guessing a cycle count.
        while (!found && cnt < 60) begin
            @(posedge clk);
            cnt++;
            if (dut.keymem_inst.round_keys[0][0] === k && bank_valid[0]) found = 1'b1;
            else if (dut.keymem_inst.round_keys[1][0] === k && bank_valid[1]) found = 1'b1;
        end
        if (found) begin
            if (dut.keymem_inst.round_keys[0][0] === k && bank_valid[0])
                check_bank(1'b0, k, "T4");
            else
                check_bank(1'b1, k, "T4");
        end else begin
            $display("[T4] FAIL: key %032h not found valid in either bank after push", k);
            fail_count++;
        end
    end

    print_result("TEST 4: RANDOM REGRESSION", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// TEST 5 - FIFO backpressure: push more than DEPTH keys back-to-back with
// no draining (both banks held busy so nothing is consumed), confirm
// key_system_busy stays asserted and no corruption/hang occurs, then
// release and confirm the system drains cleanly.
//=============================================================================
task automatic test5_fifo_backpressure();
    int p0, f0;
    aes_block_t k;
    $display("\n====================================");
    $display("TEST 5 : FIFO BACKPRESSURE");
    $display("====================================");
    p0 = pass_count; f0 = fail_count;

    // Drain to a known idle state first.
    bank_busy = 2'b00;
    wait_cycles(30);

    bank_busy = 2'b11; // block all consumption
    k = 128'hffeeddccbbaa99887766554433221100;
    // key_fifo depth is aes_pkg::KEY_FIFO_DEPTH (4) - push exactly that many
    // plus one extra, which must be silently dropped (push && !full only).
    for (int i = 0; i < aes_pkg::KEY_FIFO_DEPTH + 1; i++)
        push_key(k ^ (128'(i) << 8));

    wait_cycles(10);
    if (!key_system_busy) begin
        $display("[T5] FAIL: key_system_busy should be asserted with FIFO full/blocked");
        fail_count++;
    end else pass_count++;

    // Release everything, let the system drain.
    bank_busy = 2'b00;
    wait_cycles(200);

    if (key_system_busy) begin
        $display("[T5] FAIL: key_system_busy should clear once FIFO drains");
        fail_count++;
    end else pass_count++;

    print_result("TEST 5: FIFO BACKPRESSURE", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// MAIN
//=============================================================================
initial begin
    push      = 0;
    key_in    = '0;
    bank_busy = 2'b00;
    reset     = 1;
    repeat (5) @(posedge clk);
    @(negedge clk);
    reset = 0;

    test1_fips_kat();
    test2_bank_reuse();
    test3_busy_blocking();
    test4_random(40);
    test5_fifo_backpressure();

    $display("\n====================================================");
    $display(" KEY SYSTEM TB SUMMARY: PASS=%0d  FAIL=%0d", pass_count, fail_count);
    $display("====================================================\n");

    if (fail_count == 0) $display("*** ALL KEY SYSTEM TESTS PASSED ***");
    else                 $display("*** KEY SYSTEM TESTS FAILED ***");

    $finish;
end

// Global timeout watchdog
initial begin
    #500000;
    $display("[WATCHDOG] Global timeout - simulation stuck");
    $finish;
end

endmodule : tb_key_system

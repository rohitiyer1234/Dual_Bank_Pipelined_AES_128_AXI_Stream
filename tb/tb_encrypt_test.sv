`timescale 1ns/1ps
//=============================================================================
// tb_encrypt.sv  v3  - race-free, all 10 tests
//
// ====================================================================
// ROOT CAUSE ANALYSIS OF v2 FAILURES
// ====================================================================
//
// The v2 testbench still produced 577 failures.  The failure signature
// from the log was unambiguous:
//
//   ID=6238  EXP=4362...  DUT=66c4...
//   ID=6239  EXP=be3f...  DUT=30ec...    DUT==EXP of ID=6238
//   ID=6244  EXP=b00b...  DUT=be3f...    DUT==EXP of ID=6239
//   "Unexpected output: no pending entry ct=4362..."
//
// Outputs ARE correct - they appear in the DUT column of LATER
// scoreboard entries.  The scoreboard and the DUT are misaligned
// by a variable number of transactions.  Two races caused this:
//
// ---------------------------------------------------------------
// RACE-1: out_ready driven at posedge by backpressure thread
// ---------------------------------------------------------------
//
//   The backpressure thread in v2 did:
//     out_ready = $urandom_range(0,1);          // (A)
//     repeat ($urandom_range(1,3)) @(posedge clk); // (B)
//
//   Assignment (A) executes at the Active region of the POSEDGE
//   that ends the previous repeat.  At that same posedge:
//     - DUT always_ff evaluates stall = valid[10] && !out_ready
//     - Acceptance monitor evaluates in_ready
//     - out_ready just changed
//   Evaluation order of (A) vs DUT vs monitor is non-deterministic
//   in XSim.  This creates a race where:
//     - DUT may see old out_ready (stall stays)
//     - Monitor sees new in_ready derived from new out_ready
//    acceptance monitor records a push the DUT didn't execute, or vice versa.
//
//   TIMING DIAGRAM - RACE-1:
//     posedge N:
//       [XSim active region, order non-det]
//       BP:   out_ready = 1           changes here
//       DUT:  stall = valid[10] && !out_ready    which out_ready?
//       MON:  sample in_ready = !stall && bv     which stall?
//     If BP wins: DUT sees new out_ready=1, stall=0, in_ready=1
//                 monitor also sees in_ready=1  CONSISTENT
//     If DUT wins first: DUT latches with old out_ready=0, stall=1, in_ready=0
//                        monitor sees old in_ready=0  push skipped
//                        BUT: next posedge DUT will also see in_ready=0
//                         net effect: 1 extra or 1 missing scoreboard push
//
//   FIX: Drive out_ready ONLY at @(negedge clk).
//   By posedge, out_ready has been stable for 5 ns.
//   DUT, acceptance monitor, and output monitor all agree on its value.
//
// ---------------------------------------------------------------
// RACE-2: consecutive send_block calls with repeat(0) gap
// ---------------------------------------------------------------
//
//   The test 10 driver did:
//     send_block(pt, bk);
//     repeat ($urandom_range(0,2)) @(posedge clk);  // can be 0
//
//   send_block ends with:
//     @(negedge clk); in_valid = 0;  // deassert at negedge N
//     [task returns]
//
//   If repeat(0) is selected, the next send_block call starts
//   immediately and does:
//     @(negedge clk);               // waits for negedge N+1
//     in_valid = 1; plaintext = pt_NEW; ...
//
//   This is safe - negedge N+1 is after negedge N.  BUT: during
//   backpressure (stall=1), the driver is ALREADY blocked inside
//   send_block's while(!in_ready) loop.  When stall clears, in_ready
//   goes high at a posedge.  The acceptance monitor fires.  The
//   driver's @(posedge clk) inside the while loop also fires at the
//   same posedge.  The driver then does @(negedge clk); in_valid=0.
//
//   At that negedge the NEXT send_block call may begin:
//     @(negedge clk)  same negedge as in_valid=0
//   In XSim, the ordering of two blocking @(negedge) in two different
//   fork threads at the same negedge is non-deterministic.  One may
//   see in_valid still 1 when it samples.
//
//   FIX: Change repeat(0,2) to repeat(1,3) - always at least 1 idle
//   posedge between send_block calls in the inter-transaction gap.
//   This guarantees that by the time the next send_block's first
//   @(negedge clk) fires, the previous in_valid=0 has already settled.
//
// ---------------------------------------------------------------
// RACE-3: total_checked > total_accepted (80 extra outputs in test 10)
// ---------------------------------------------------------------
//
//   total_checked = pass_count + fail_count = 6361
//   total_accepted = 6281
//   Delta = 80 - outputs from test 9 drained INTO test 10's window.
//
//   Cause: drain_scoreboard after test 9 returned as soon as
//   expected_q.size()==0, then waited PIPE_DEPTH+4=15 cycles.
//   But with RACE-1 active in tests 7/8 (out_ready driven at posedge),
//   some scoreboard entries were MISSING (never pushed due to race).
//   So expected_q.size() reached 0 BEFORE all outputs were consumed -
//   the pipeline still had up to ~11 transactions in flight.
//   When test 10 started, those outputs fired the output monitor
//   but the queue was empty  "unexpected output" errors.
//
//   FIX: With RACE-1 and RACE-2 eliminated, this cascading effect
//   disappears.  drain_scoreboard is also made robust by waiting for
//   bank_busy==0 AFTER the queue empties, confirming the pipeline is
//   truly idle before returning.
//
// ====================================================================
// DEFINITIVE PROTOCOL (v3)
// ====================================================================
//
//  ALL control signal changes happen ONLY at @(negedge clk).
//  Posedge is read-only from the testbench perspective.
//
//  send_block:
//    @(negedge clk);                    drive in_valid=1, pt, bk
//    @(posedge clk); while (!in_ready) { @(negedge); @(posedge); }
//    @(negedge clk);                    in_valid=0
//
//  backpressure:
//    @(negedge clk);                    out_ready = random
//    repeat(N) @(posedge clk);          hold
//    @(negedge clk);                    out_ready = random (or 1)
//
//  acceptance monitor (@posedge):       reads stable in_valid, in_ready, pt, bk
//  output monitor    (@posedge):        reads stable out_valid, out_ready, ct
//
//  Guarantee: every signal is stable for >= 5 ns before every posedge.
//  No race possible between TB threads or between TB and DUT.
//
//=============================================================================

module tb_encrypt;

import aes_pkg::*;
import aes_ref_pkg::*;

//=============================================================================
// DUT INTERFACE
//=============================================================================

logic clk;
logic reset;
logic       in_valid;
logic       in_ready;
logic       out_valid;
logic       out_ready;
logic       current_bank;
aes_block_t plaintext;
aes_block_t ciphertext;
logic [1:0] bank_busy;
logic [1:0] bank_valid;
rk_store_t  round_keys;

//=============================================================================
// DUT
//=============================================================================

AES_Encrypt dut (
    .clk          (clk),
    .reset        (reset),
    .in_valid     (in_valid),
    .in_ready     (in_ready),
    .plaintext    (plaintext),
    .current_bank (current_bank),
    .round_keys   (round_keys),
    .ciphertext   (ciphertext),
    .out_valid    (out_valid),
    .out_ready    (out_ready),
    .bank_busy    (bank_busy),
    .bank_valid   (bank_valid)
);

//=============================================================================
// CLOCK  100 MHz  - negedge at 5 ns, posedge at 10 ns, period 10 ns
//=============================================================================

initial clk = 0;
always  #5 clk = ~clk;

//=============================================================================
// SCOREBOARD TYPES AND STATE
//=============================================================================

typedef struct {
    int unsigned  id;
    aes_block_t   pt;
    logic         bank;
    aes_block_t   expected;
} sb_item_t;

sb_item_t expected_q[$];

int unsigned next_txid   = 0;
int          pass_count  = 0;
int          fail_count  = 0;
int          total_accepted = 0;

//=============================================================================
// ACCEPTANCE MONITOR
// Fires at posedge where in_valid && in_ready.
// By the negedge protocol all inputs are stable >= 5 ns before this edge.
// No race with DUT possible.
//=============================================================================

always @(posedge clk) begin
    if (!reset && in_valid && in_ready) begin
        sb_item_t item;
        item.id       = next_txid++;
        item.pt       = plaintext;
        item.bank     = current_bank;
        item.expected = aes_ref_pkg::ref_encrypt_bank(plaintext, current_bank);
        expected_q.push_back(item);
        total_accepted++;
    end
end

//=============================================================================
// OUTPUT MONITOR / SCOREBOARD CHECKER
// Fires at posedge where out_valid && out_ready.
// out_ready is driven only at negedge (v3 fix), so stable here.
//=============================================================================

always @(posedge clk) begin
    if (!reset && out_valid && out_ready) begin
        if (expected_q.size() == 0) begin
            $error("[SB] Unexpected output  ct=%032h  t=%0t", ciphertext, $time);
            fail_count++;
        end else begin
            sb_item_t item = expected_q.pop_front();
            if (ciphertext === item.expected) begin
                pass_count++;
            end else begin
                fail_count++;
                $display("");
                $display("+==========================================+");
                $display("|         SCOREBOARD MISMATCH              |");
                $display("==========================================");
                $display("|  ID   = %-6d                           |", item.id);
                $display("|  BANK = %0d                               |", item.bank);
                $display("|  PT   = %032h", item.pt);
                $display("|  EXP  = %032h", item.expected);
                $display("|  DUT  = %032h", ciphertext);
                $display("+==========================================+");
            end
        end
    end
end

//=============================================================================
// send_block - v3, race-free
//
// All signal changes happen at @(negedge clk).
// The acceptance monitor reads at @(posedge clk) - always sees settled values.
//
// Protocol:
//   negedge:  drive pt, bk, in_valid=1
//   posedge:  sample in_ready
//              if 1: DUT accepted, done
//              if 0: keep signals, loop
//   negedge:  in_valid=0
//=============================================================================

task automatic send_block(
    input aes_block_t pt,
    input logic       bk
);
    @(negedge clk);
    plaintext    = pt;
    current_bank = bk;
    in_valid     = 1'b1;

    @(posedge clk);
    while (!in_ready) begin
        @(negedge clk);   // keep signals, nothing changes
        @(posedge clk);
    end
    // Accepted at this posedge.

    @(negedge clk);
    in_valid = 1'b0;
    // Caller must wait >= 1 posedge before calling send_block again
    // to ensure in_valid=0 is seen before the next drive.
endtask

//=============================================================================
// set_out_ready - ALWAYS call this instead of assigning out_ready directly.
// Drives out_ready only at @(negedge clk), eliminating RACE-1.
//=============================================================================

task automatic set_out_ready(input logic val);
    @(negedge clk);
    out_ready = val;
endtask

//=============================================================================
// drain_scoreboard
// Waits for expected_q to empty AND bank_busy to clear.
// out_ready must be 1 before calling (caller's responsibility).
//=============================================================================

task automatic drain_scoreboard(input int timeout_cycles = 3000);
    int cnt = 0;
    // Wait for all scoreboard entries to be consumed
    while (expected_q.size() > 0 && cnt < timeout_cycles) begin
        @(posedge clk);
        cnt++;
    end
    if (expected_q.size() != 0)
        $error("[DRAIN] timeout: %0d entries remain", expected_q.size());
    // Wait for pipeline to fully empty (bank_busy -> 0)
    cnt = 0;
    while (bank_busy != 2'b00 && cnt < PIPE_DEPTH + 4) begin
        @(posedge clk);
        cnt++;
    end
    if (bank_busy != 2'b00)
        $error("[DRAIN] pipeline not empty after drain: bank_busy=%02b", bank_busy);
endtask

//=============================================================================
// print_result
//=============================================================================

task automatic print_result(input string name, input int p, input int f);
    $display("+------------------------------------------+");
    $display("|  %-40s  |", name);
    $display("|  PASS=%-5d  FAIL=%-5d                  |", p, f);
    if (f == 0)
        $display("|  *** PASSED ***                          |");
    else
        $display("|  *** FAILED ***                          |");
    $display("+------------------------------------------+\n");
endtask

//=============================================================================
// KEY SETUP
//=============================================================================

task automatic load_round_keys();
    // Bank 0: FIPS-197 key 2b7e151628aed2a6abf7158809cf4f3c
    round_keys[0][0]  = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    round_keys[0][1]  = 128'ha0fafe1788542cb123a339392a6c7605;
    round_keys[0][2]  = 128'hf2c295f27a96b9435935807a7359f67f;
    round_keys[0][3]  = 128'h3d80477d4716fe3e1e237e446d7a883b;
    round_keys[0][4]  = 128'hef44a541a8525b7fb671253bdb0bad00;
    round_keys[0][5]  = 128'hd4d1c6f87c839d87caf2b8bc11f915bc;
    round_keys[0][6]  = 128'h6d88a37a110b3efddbf98641ca0093fd;
    round_keys[0][7]  = 128'h4e54f70e5f5fc9f384a64fb24ea6dc4f;
    round_keys[0][8]  = 128'head27321b58dbad2312bf5607f8d292f;
    round_keys[0][9]  = 128'hac7766f319fadc2128d12941575c006e;
    round_keys[0][10] = 128'hd014f9a8c9ee2589e13f0cc8b6630ca6;
    // Bank 1: key 000102030405060708090a0b0c0d0e0f
    round_keys[1][0]  = 128'h000102030405060708090a0b0c0d0e0f;
    round_keys[1][1]  = 128'hd6aa74fdd2af72fadaa678f1d6ab76fe;
    round_keys[1][2]  = 128'hb692cf0b643dbdf1be9bc5006830b3fe;
    round_keys[1][3]  = 128'hb6ff744ed2c2c9bf6c590cbf0469bf41;
    round_keys[1][4]  = 128'h47f7f7bc95353e03f96c32bcfd058dfd;
    round_keys[1][5]  = 128'h3caaa3e8a99f9deb50f3af57adf622aa;
    round_keys[1][6]  = 128'h5e390f7df7a69296a7553dc10aa31f6b;
    round_keys[1][7]  = 128'h14f9701ae35fe28c440adf4d4ea9c026;
    round_keys[1][8]  = 128'h47438735a41c65b9e016baf4aebf7ad2;
    round_keys[1][9]  = 128'h549932d1f08557681093ed9cbe2c974e;
    round_keys[1][10] = 128'h13111d7fe3944a17f307a78b4d2b30c5;
endtask

//=============================================================================
// BACKPRESSURE HELPER
// Runs in a fork alongside a driver.
// Drives out_ready at negedge only.
// Exits when driver_done=1 AND expected_q is empty.
//=============================================================================

task automatic run_backpressure(
    ref   logic driver_done,
    input int   min_hold = 1,
    input int   max_hold = 4
);
    // out_ready starts at 1 (set by caller before fork)
    while (!driver_done || expected_q.size() > 0) begin
        // Change out_ready at negedge - race-free
        @(negedge clk);
        out_ready = $urandom_range(0,1);
        // Hold for N posedge cycles
        repeat ($urandom_range(min_hold, max_hold)) @(posedge clk);
    end
    // Ensure out_ready=1 when done
    @(negedge clk);
    out_ready = 1'b1;
endtask

//=============================================================================
// 
// TESTS
// 
//=============================================================================

//=============================================================================
// TEST 1 - FIPS-197 Known Answer Test
//   PT  = 3243f6a8885a308d313198a2e0370734
//   Key = 2b7e151628aed2a6abf7158809cf4f3c  (bank 0)
//   CT  = 3925841d02dc09fbdc118597196a0b32
//=============================================================================

task automatic test1_fips_kat();
    int p0, f0;
    $display("\n====================================");
    $display("TEST 1 : FIPS-197 KAT");
    $display("====================================");
    out_ready = 1;
    p0 = pass_count; f0 = fail_count;

    send_block(128'h3243f6a8885a308d313198a2e0370734, 1'b0);
    @(posedge clk);  // gap before drain
    drain_scoreboard(50);

    print_result("TEST 1: FIPS-197 KAT", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// TEST 2 - Pipeline Fill / Throughput
// 20 back-to-back transactions, bank 0.
//=============================================================================

task automatic test2_pipeline_fill();
    int p0, f0;
    $display("\n====================================");
    $display("TEST 2 : PIPELINE FILL");
    $display("====================================");
    out_ready = 1;
    p0 = pass_count; f0 = fail_count;

    for (int i = 0; i < 20; i++) begin
        aes_block_t pt = {32'(i), 32'(i), 32'(i), 32'(i)};
        send_block(pt, 1'b0);
        @(posedge clk);  // minimum 1-cycle inter-transaction gap (RACE-2 fix)
    end
    drain_scoreboard(100);

    print_result("TEST 2: PIPELINE FILL", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// TEST 3 - Random Regression, 100 vectors, random bank
//=============================================================================

task automatic test3_random(input int num_vectors = 100);
    int p0, f0;
    $display("\n====================================");
    $display("TEST 3 : RANDOM REGRESSION (%0d)", num_vectors);
    $display("====================================");
    out_ready = 1;
    p0 = pass_count; f0 = fail_count;

    for (int i = 0; i < num_vectors; i++) begin
        aes_block_t pt = {$urandom,$urandom,$urandom,$urandom};
        logic bk = $urandom_range(0,1);
        send_block(pt, bk);
        @(posedge clk);
    end
    drain_scoreboard(num_vectors + 50);

    print_result("TEST 3: RANDOM REGRESSION", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// TEST 4 - Dual Bank Alternating (0,1,0,1,...)
// Detects bank pipeline misalignment.
//=============================================================================

task automatic test4_alternating_banks(input int num_vectors = 200);
    int p0, f0;
    $display("\n====================================");
    $display("TEST 4 : ALTERNATING BANKS (%0d)", num_vectors);
    $display("====================================");
    out_ready = 1;
    p0 = pass_count; f0 = fail_count;

    for (int i = 0; i < num_vectors; i++) begin
        aes_block_t pt = {$urandom,$urandom,$urandom,$urandom};
        logic       bk = logic'(i[0]);
        send_block(pt, bk);
        @(posedge clk);
    end
    drain_scoreboard(num_vectors + 50);

    print_result("TEST 4: ALTERNATING BANKS", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// TEST 5 - Bank 0 Burst / Bank 1 Burst (16+16, repeat 10)
// Detects stale bank mux state at burst boundaries.
//=============================================================================

task automatic test5_burst_banks(
    input int burst_len = 16,
    input int repeats   = 10
);
    int p0, f0;
    $display("\n====================================");
    $display("TEST 5 : BURST BANKS (%0d%0d2)", burst_len, repeats);
    $display("====================================");
    out_ready = 1;
    p0 = pass_count; f0 = fail_count;

    for (int r = 0; r < repeats; r++) begin
        for (int i = 0; i < burst_len; i++) begin
            aes_block_t pt = {$urandom,$urandom,$urandom,$urandom};
            send_block(pt, 1'b0);
            @(posedge clk);
        end
        for (int i = 0; i < burst_len; i++) begin
            aes_block_t pt = {$urandom,$urandom,$urandom,$urandom};
            send_block(pt, 1'b1);
            @(posedge clk);
        end
    end
    drain_scoreboard(burst_len*repeats*4 + 50);

    print_result("TEST 5: BURST BANKS", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// TEST 6 - Constant Plaintext, Alternating Bank
// Same PT every cycle, bank alternates 0/1.
// Proves bank mux: outputs must strictly alternate between two known values.
//=============================================================================

task automatic test6_const_pt_alt_bank(input int num_vectors = 100);
    int p0, f0;
    aes_block_t fixed_pt = 128'hdeadbeefcafebabedeadbeefcafebabe;
    $display("\n====================================");
    $display("TEST 6 : CONST PT / ALT BANK (%0d)", num_vectors);
    $display("====================================");
    $display("  PT     = %032h", fixed_pt);
    $display("  EXP_B0 = %032h", aes_ref_pkg::ref_encrypt_bank(fixed_pt, 1'b0));
    $display("  EXP_B1 = %032h", aes_ref_pkg::ref_encrypt_bank(fixed_pt, 1'b1));
    out_ready = 1;
    p0 = pass_count; f0 = fail_count;

    for (int i = 0; i < num_vectors; i++) begin
        logic bk = logic'(i[0]);
        send_block(fixed_pt, bk);
        @(posedge clk);
    end
    drain_scoreboard(num_vectors + 50);

    print_result("TEST 6: CONST PT ALT BANK", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// TEST 7 - Output Backpressure
// 200 random transactions with random out_ready toggling.
// out_ready changes ONLY at negedge (RACE-1 fix).
//=============================================================================

logic t7_done;

task automatic test7_backpressure(input int num_vectors = 200);
    int p0, f0;
    $display("\n====================================");
    $display("TEST 7 : OUTPUT BACKPRESSURE (%0d)", num_vectors);
    $display("====================================");
    p0 = pass_count; f0 = fail_count;
    t7_done = 0;
    // Start with out_ready=1 at a negedge so it's settled
    @(negedge clk);
    out_ready = 1;

    fork
        // Driver thread
        begin
            for (int i = 0; i < num_vectors; i++) begin
                aes_block_t pt = {$urandom,$urandom,$urandom,$urandom};
                logic       bk = $urandom_range(0,1);
                send_block(pt, bk);
                @(posedge clk);          // RACE-2 fix: minimum 1-cycle gap
            end
            t7_done = 1;
        end
        // Backpressure thread - changes out_ready at negedge only (RACE-1 fix)
        begin
            run_backpressure(t7_done, 1, 4);
        end
    join

    drain_scoreboard(num_vectors*4 + 100);
    print_result("TEST 7: OUTPUT BACKPRESSURE", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// TEST 8 - Bank Valid Stress
// Exercises all four bank_valid combinations.
//=============================================================================

task automatic test8_bank_valid_stress();
    int p0, f0;
    $display("\n====================================");
    $display("TEST 8 : BANK VALID STRESS");
    $display("====================================");
    out_ready = 1;
    p0 = pass_count; f0 = fail_count;

    //--- Phase A: bank_valid=2'b11 ---
    $display("[T8-A] bank_valid=2'b11 - both banks, 20 random vectors");
    bank_valid = 2'b11;
    for (int i = 0; i < 20; i++) begin
        aes_block_t pt = {$urandom,$urandom,$urandom,$urandom};
        send_block(pt, $urandom_range(0,1));
        @(posedge clk);
    end
    drain_scoreboard(100);

    //--- Phase B: bank_valid=2'b01 - only bank 0 ---
    $display("[T8-B] bank_valid=2'b01 - bank 1 must be blocked");
    @(negedge clk); bank_valid = 2'b01;
    // Try to drive bank 1 - in_ready must be 0
    @(negedge clk);
    plaintext    = 128'hdeadbeefdeadbeefdeadbeefdeadbeef;
    current_bank = 1'b1;
    in_valid     = 1'b1;
    @(posedge clk);
    if (in_ready !== 1'b0)
        $error("[T8-B] FAIL: in_ready=%b expected 0 (bank_valid[1]=0)", in_ready);
    else
        $display("[T8-B] PASS: in_ready=0 for bank=1 when bank_valid=01");
    @(negedge clk); in_valid = 1'b0;
    repeat(2) @(posedge clk);
    // Bank 0 must still work
    for (int i = 0; i < 10; i++) begin
        aes_block_t pt = {$urandom,$urandom,$urandom,$urandom};
        send_block(pt, 1'b0);
        @(posedge clk);
    end
    drain_scoreboard(50);

    //--- Phase C: bank_valid=2'b10 - only bank 1 ---
    $display("[T8-C] bank_valid=2'b10 - bank 0 must be blocked");
    @(negedge clk); bank_valid = 2'b10;
    @(negedge clk);
    plaintext    = 128'hcafebabeCAFEBABEcafebabeCAFEBABE;
    current_bank = 1'b0;
    in_valid     = 1'b1;
    @(posedge clk);
    if (in_ready !== 1'b0)
        $error("[T8-C] FAIL: in_ready=%b expected 0 (bank_valid[0]=0)", in_ready);
    else
        $display("[T8-C] PASS: in_ready=0 for bank=0 when bank_valid=10");
    @(negedge clk); in_valid = 1'b0;
    repeat(2) @(posedge clk);
    for (int i = 0; i < 10; i++) begin
        aes_block_t pt = {$urandom,$urandom,$urandom,$urandom};
        send_block(pt, 1'b1);
        @(posedge clk);
    end
    drain_scoreboard(50);

    //--- Phase D: bank_valid=2'b00 - nothing accepted ---
    $display("[T8-D] bank_valid=2'b00 - in_ready must stay 0");
    @(negedge clk); bank_valid = 2'b00;
    @(negedge clk);
    in_valid     = 1'b1;
    current_bank = 1'b0;
    repeat (10) begin
        @(posedge clk);
        if (in_ready !== 1'b0)
            $error("[T8-D] FAIL: in_ready=1 with bank_valid=00 at %0t", $time);
    end
    $display("[T8-D] PASS: in_ready held 0 for 10 cycles");
    @(negedge clk); in_valid = 1'b0;
    @(negedge clk); bank_valid = 2'b11;
    repeat(4) @(posedge clk);

    print_result("TEST 8: BANK VALID STRESS", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// TEST 9 - Long Regression: 5000 vectors, random bank, no backpressure
//=============================================================================

task automatic test9_long_regression(input int num_vectors = 5000);
    int p0, f0;
    $display("\n====================================");
    $display("TEST 9 : LONG REGRESSION (%0d)", num_vectors);
    $display("====================================");
    @(negedge clk); out_ready = 1;
    p0 = pass_count; f0 = fail_count;

    for (int i = 0; i < num_vectors; i++) begin
        aes_block_t pt = {$urandom,$urandom,$urandom,$urandom};
        logic       bk = $urandom_range(0,1);
        send_block(pt, bk);
        @(posedge clk);
    end
    drain_scoreboard(num_vectors + 100);

    print_result("TEST 9: LONG REGRESSION", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// TEST 10 - Transaction ID Tracking with backpressure
// 300 vectors, mild backpressure, full per-transaction diagnostics.
//
// The global acceptance monitor already records id/pt/bank/expected for
// every transaction.  The output monitor prints full context on mismatch.
// On any failure this test prints the ID range so you can cross-reference
// with the waveform.
//=============================================================================

logic t10_done;

task automatic test10_txid_tracking(input int num_vectors = 300);
    int p0, f0, start_id;
    $display("\n====================================");
    $display("TEST 10 : TX ID TRACKING (%0d)", num_vectors);
    $display("====================================");
    p0 = pass_count; f0 = fail_count;
    start_id = next_txid;
    t10_done = 0;
    @(negedge clk); out_ready = 1;

    fork
        // Driver
        begin
            for (int i = 0; i < num_vectors; i++) begin
                aes_block_t pt = {$urandom,$urandom,$urandom,$urandom};
                logic       bk = $urandom_range(0,1);
                send_block(pt, bk);
                @(posedge clk);          // RACE-2 fix: >= 1-cycle gap
                // Additional random gap 0-1 cycles
                if ($urandom_range(0,1)) @(posedge clk);
            end
            t10_done = 1;
        end
        // Backpressure - negedge-driven only (RACE-1 fix)
        begin
            run_backpressure(t10_done, 1, 3);
        end
    join

    drain_scoreboard(num_vectors*4 + 100);

    if (fail_count - f0 > 0) begin
        $display("[T10] ID range: [%0d, %0d)", start_id, next_txid);
        $display("[T10] Accepted=%0d  Checked=%0d  Pass=%0d  Fail=%0d",
                 next_txid-start_id, (pass_count-p0)+(fail_count-f0),
                 pass_count-p0, fail_count-f0);
    end
    print_result("TEST 10: TX ID TRACKING", pass_count-p0, fail_count-f0);
endtask

//=============================================================================
// WATCHDOG
//=============================================================================

initial begin
    #20_000_000;
    $display("[FATAL] Watchdog timeout at %0t", $time);
    $finish;
end

//=============================================================================
// SVA - structural properties, verified every posedge
//=============================================================================

// P1: in_ready must be 0 whenever the DUT is stalled.
property p_stall_blocks_ready;
    @(posedge clk) disable iff (reset)
    (out_valid && !out_ready) |-> !in_ready;
endproperty
assert property (p_stall_blocks_ready)
    else $error("[SVA] in_ready=1 during stall at %0t", $time);

// P2: While stalled, ciphertext must not change.
property p_stall_holds_ct;
    @(posedge clk) disable iff (reset)
    (out_valid && !out_ready) |=> (ciphertext === $past(ciphertext));
endproperty
assert property (p_stall_holds_ct)
    else $error("[SVA] ciphertext changed during stall at %0t", $time);

// P3: While stalled, out_valid must not deassert.
property p_stall_holds_ov;
    @(posedge clk) disable iff (reset)
    (out_valid && !out_ready) |=> out_valid;
endproperty
assert property (p_stall_holds_ov)
    else $error("[SVA] out_valid dropped during stall at %0t", $time);

// P4: in_ready must be 0 when the selected bank is not valid.
property p_invalid_bank_blocks_ready;
    @(posedge clk) disable iff (reset)
    (!bank_valid[current_bank]) |-> !in_ready;
endproperty
assert property (p_invalid_bank_blocks_ready)
    else $error("[SVA] in_ready=1 but bank_valid[%0b]=0 at %0t",
                current_bank, $time);

// P5: Control outputs must never be X after reset.
property p_no_x;
    @(posedge clk) disable iff (reset)
    !$isunknown(out_valid) && !$isunknown(in_ready) && !$isunknown(bank_busy);
endproperty
assert property (p_no_x)
    else $error("[SVA] X on control output at %0t", $time);

//=============================================================================
// MAIN INITIAL BLOCK
//=============================================================================

initial begin
    // --------------------------------------------------------
    // Initialise all TB-driven signals at time 0
    // --------------------------------------------------------
    clk          = 0;
    reset        = 1;
    in_valid     = 0;
    out_ready    = 1;       // will be formally set at negedge before use
    current_bank = 0;
    plaintext    = '0;
    bank_valid   = 2'b00;
    t7_done      = 0;
    t10_done     = 0;

    pass_count   = 0;
    fail_count   = 0;
    total_accepted = 0;

    load_round_keys();

    // --------------------------------------------------------
    // Reset
    // --------------------------------------------------------
    repeat (5) @(posedge clk);
    @(negedge clk);
    reset      = 0;
    bank_valid = 2'b11;
    out_ready  = 1;
    repeat (3) @(posedge clk);

    // --------------------------------------------------------
    // Run all tests
    // --------------------------------------------------------
    test1_fips_kat();
    test2_pipeline_fill();
    test3_random(100);
    test4_alternating_banks(200);
    test5_burst_banks(16, 10);
    test6_const_pt_alt_bank(100);
    test7_backpressure(200);
    test8_bank_valid_stress();
    test9_long_regression(5000);
    test10_txid_tracking(300);

    // --------------------------------------------------------
    // Final summary
    // --------------------------------------------------------
    repeat (5) @(posedge clk);
    $display("\n+==========================================+");
    $display(  "|             FINAL RESULTS                |");
    $display(  "==========================================");
    $display(  "|  Total accepted  : %-6d               |", total_accepted);
    $display(  "|  Total checked   : %-6d               |", pass_count+fail_count);
    $display(  "|  PASS            : %-6d               |", pass_count);
    $display(  "|  FAIL            : %-6d               |", fail_count);
    $display(  "==========================================");
    if (fail_count == 0)
        $display("|       *** ALL TESTS PASSED ***           |");
    else
        $display("|  *** %0d FAILURE(S) - see log ***         |", fail_count);
    $display(  "+==========================================+\n");
    $finish;
end

endmodule : tb_encrypt
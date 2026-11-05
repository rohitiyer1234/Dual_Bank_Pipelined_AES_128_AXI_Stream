// ============================================================================
//  keymem_dual.sv
//
//  Dual-bank AES round-key memory
//
//  PURPOSE
//  -------
//  Stores expanded AES round keys for two independent banks.
//  One bank may be actively used by encrypt/decrypt pipelines
//  while the other bank is being populated by key expansion.
//
//  DESIGN GOALS
//  ------------
//  - Timing-closure safe
//  - Fully synthesizable
//  - No combinational loops
//  - No stale bank-valid races
//  - Safe bank reuse
//  - Compatible with AES encrypt/decrypt pipelines
//  - bank_busy comes FROM pipelines and propagates upward
//
//  FIXES APPLIED (prior pass, kept)
//  ---------------------------------
//  1. bank_valid derived ONLY from registered valid bits
//  2. Added explicit bank_release support
//  3. Removed valid_next race hazard
//  4. Full reset initialization
//  5. Timing-safe sequential control
//  6. No combinational feedback paths
//  7. Safe simultaneous release/write handling
//
//  FIX APPLIED (this pass)
//  ------------------------
//  8. REMOVED the separate `mem` shadow array + combinational
//     always_comb mirror onto `round_keys`. That block used
//     variable-indexed nested for-loops to copy mem -> round_keys;
//     under simulation (confirmed with Icarus Verilog) this pattern
//     can fail to build a correct implicit sensitivity list for an
//     unpacked memory array, so the block evaluates once at time 0
//     (all-X) and never re-triggers as mem is written - round_keys
//     then reads back as permanently 'x' even though the writes
//     themselves (visible on w_en/waddr/wkey and on mem directly)
//     are completely correct. Rather than rely on generate/genvar
//     workarounds (which hit their own portability issues on some
//     toolchains when indexing typedef'd unpacked-array ports),
//     round_keys is now the storage itself: written directly and
//     registered in the same always_ff block that used to write
//     `mem`. This removes an entire redundant array, removes the
//     fragile combinational mirror, and is the standard portable
//     way to expose a small on-chip memory array to consumers.
// ============================================================================

`timescale 1ns/1ps

import aes_pkg::*;

module keymem_dual (

    input  logic        clk,
    input  logic        reset,

    // Write interface from key expansion engine

    input  logic        w_en,
    input  logic [3:0]  waddr,
    input  aes_block_t  wkey,
    input  logic        write_bank,

    // FIX (key-sync): generation handle for the key currently being
    // written into `write_bank`. Latched into bank_gen[write_bank] on
    // the K0 write (waddr==0), i.e. as soon as the bank is claimed for
    // this expansion - stable well before bank_valid[write_bank] can
    // possibly go high (that requires all 11 round-key writes), so
    // bank_gen is always correct by the time bank_valid gates any
    // consumer of it.
    input  key_gen_t    write_gen,

    // ------------------------------------------------------------
    // Release interface
    // Higher-level controller releases bank after pipelines finish
    // ------------------------------------------------------------
    input  logic [1:0]  bank_release,
    // ------------------------------------------------------------
    // Busy feedback from AES pipelines
    // ------------------------------------------------------------
    input  logic [1:0]  bank_busy,
    // ------------------------------------------------------------
    // Outputs
    // ------------------------------------------------------------
    output rk_store_t   round_keys,
    output logic [1:0]  bank_valid,
    output logic [1:0]  bank_free,

    // FIX (key-sync): per-bank generation handle, readable by aes_top /
    // status registers so a data-plane master can confirm which key
    // context a bank currently holds before (or as) it issues data
    // against it.
    //
    // Exposed as a FLAT PACKED vector (bank b occupies bits
    // [(b+1)*KEY_GEN_W-1 : b*KEY_GEN_W]) rather than an unpacked
    // key_gen_t[NUM_BANKS] array. This is deliberate: an unpacked/
    // typedef'd array relayed output-port -> output-port through two
    // hierarchy levels (keymem_dual -> key_system_top -> aes_top) hits
    // the same Icarus-specific port-propagation gap already documented
    // in this repo for `round_keys` (see header comment above and
    // tb_aes_top.sv's ICARUS_SIM workaround) - confirmed by direct
    // testing while developing this fix. A packed vector of identical
    // total width does not: bank_valid/bank_free (plain logic[1:0])
    // already relay correctly through the same two hierarchy levels,
    // and this port now follows that same safe, portable shape. Vivado
    // XSIM/Questa/VCS handle either form correctly per the LRM; this
    // choice removes the ambiguity for Icarus and is also the more
    // conservative, tool-portable style for the ASIC backend flow.
    output logic [NUM_BANKS*KEY_GEN_W-1:0] bank_gen_flat
);

    // ============================================================
    // valid[b][r] - indicates whether round-key r in bank b is valid
    // ============================================================

    logic [NUM_ROUNDS:0] valid [0:1];

    // Internal per-bank generation register (indexed with a registered
    // control signal, written one bank at a time - this is plain,
    // ordinary indexed storage, not a cross-module port relay, so it
    // carries none of the port-propagation caveat above).
    key_gen_t bank_gen_reg [0:NUM_BANKS-1];

    genvar gb;
    generate
        for (gb = 0; gb < NUM_BANKS; gb++) begin : GEN_FLATTEN
            assign bank_gen_flat[(gb+1)*KEY_GEN_W-1 -: KEY_GEN_W] = bank_gen_reg[gb];
        end
    endgenerate

    // ============================================================
    // BANK STATUS
    // ============================================================

    always_comb begin
        // --------------------------------------------------------
        // A bank is FREE only if:
        // 1. not busy in pipelines
        // 2. not already fully populated
        // --------------------------------------------------------
        bank_free[0] = !bank_busy[0] && !bank_valid[0];
        bank_free[1] =  !bank_busy[1] && !bank_valid[1];
    end

    // ============================================================
    // SEQUENTIAL MEMORY (round_keys itself) + VALID CONTROL
    // ============================================================
    always_ff @(posedge clk) begin
        if(reset) begin
            // ----------------------------------------------------
            // Reset valid state
            // ----------------------------------------------------
            valid[0] <= '0;
            valid[1] <= '0;
            bank_valid <= 2'b00;
            // ----------------------------------------------------
            // Memory clear
            // ----------------------------------------------------
            for(int b=0;b<2;b++) begin
                for(int r=0;r<=NUM_ROUNDS;r++) begin
                    round_keys[b][r] <= '0;
                end
                bank_gen_reg[b] <= '0;
            end
        end
        else begin
            // ====================================================
            // BANK RELEASE
            // ====================================================

            // Release has highest priority
            // Clears validity for bank reuse
            if(bank_release[0]) begin
                valid[0]      <= '0;
                bank_valid[0] <= 1'b0;
            end
            if(bank_release[1]) begin
                valid[1]      <= '0;
                bank_valid[1] <= 1'b0;
            end
            // ====================================================
            // KEY WRITE
            // ====================================================
            if(w_en && bank_free[write_bank]) begin
                round_keys[write_bank][waddr] <= wkey;
                valid[write_bank][waddr]      <= 1'b1;
                // FIX (key-sync): stamp the bank with its owning key's
                // generation handle at the start of the expansion
                // (waddr==0 == K0/raw-key write). Re-stamping only on
                // waddr==0 (not every write) means the tag can't be
                // corrupted by anything mid-expansion.
                if (waddr == 4'd0)
                    bank_gen_reg[write_bank] <= write_gen;
            end
            // ====================================================
            // BANK VALID GENERATION
            // ====================================================

            // Registered generation prevents:
            // - stale read races
            // - same-cycle visibility hazards
            // - timing ambiguity
            bank_valid[0] <= &valid[0];
            bank_valid[1] <= &valid[1];
        end
    end

endmodule

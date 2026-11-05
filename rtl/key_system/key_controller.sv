// ============================================================================
//  key_controller.sv
//
//  Key Expansion Sequencer / Arbiter
//
//  PURPOSE
//  -------
//  Controls movement of AES keys from FIFO -> expansion engine -> keymem.
//
//  FUNCTION
//  --------
//  1. Wait for a key in FIFO
//  2. Select a free bank
//  3. Pulse exp_start for one cycle
//  4. Hold active until expansion completes
//  5. Prevent overlapping expansions
//
//  DESIGN GOALS
//  ------------
//  - Timing-closure safe
//  - No combinational loops
//  - No FIFO underflow hazards
//  - No bank arbitration races
//  - Clean one-cycle start pulse
//  - Fully synthesizable
//
//  FIXES APPLIED
//  -------------
//  1. key_ready now gated with key_valid
//  2. Simultaneous exp_done/new-request handled cleanly
//  3. Stable bank selection
//  4. Removed redundant bank_valid dependency
//  5. Timing-safe registered control
// ============================================================================

`timescale 1ns/1ps

import aes_pkg::*;

module key_controller (

    input  logic        clk,
    input  logic        reset,
    // ------------------------------------------------------------
    // FIFO Interface
    // ------------------------------------------------------------
    input  logic        key_valid,     // FIFO !empty
    output logic        key_ready,     // FIFO pop pulse
    // ------------------------------------------------------------
    // Bank Status
    // ------------------------------------------------------------
    input  logic [1:0]  bank_free,
    // ------------------------------------------------------------
    // Expansion Engine Status
    //------------------------------------------------------------
    input  logic        exp_done,
    // ------------------------------------------------------------
    // Control Outputs
    // ------------------------------------------------------------
    output logic        exp_start,
    output logic        write_bank
);
    // ============================================================
    // INTERNAL STATE
    // ============================================================
    logic active;
    logic selected_bank;
    logic start_condition;
    // ============================================================
    // FREE BANK SELECTION
    // Priority:
    //   bank0 > bank1
    // ============================================================
    always_comb begin
        if(bank_free[0])
            selected_bank = 1'b0;
        else if(bank_free[1])
            selected_bank = 1'b1;
        else
            selected_bank = 1'b0;
    end
    // ============================================================
    // START CONDITION
    // ============================================================
    assign start_condition =key_valid && !active &&  (bank_free != 2'b00);     

    // ============================================================
    // FIFO POP CONTROL
    // ============================================================

    // Pop ONLY when:
    // - key exists
    // - controller accepts it
    // - expansion launching now

    always_comb begin
        key_ready = start_condition;
    end

    // ============================================================
    // MAIN CONTROL FSM
    // ============================================================
    always_ff @(posedge clk) begin
        if(reset) begin
            active     <= 1'b0;
            exp_start  <= 1'b0;
            write_bank <= 1'b0;
        end
        else begin
            exp_start <= 1'b0;
            // ----------------------------------------------------
            // Expansion completion
            // ----------------------------------------------------
            if(exp_done)
                active <= 1'b0;
            // ----------------------------------------------------
            // Launch new expansion
            // ----------------------------------------------------
            if(start_condition) begin
                active     <= 1'b1;
                write_bank <= selected_bank;
                exp_start  <= 1'b1;
            end
        end
    end
endmodule
// ============================================================================
//  rst_sync.sv
//
//  Standard 2-flop async-assert / sync-deassert reset synchronizer.
//
//  WHY THIS EXISTS
//  ----------------
//  The aes_top core (and everything under rtl/) uses a plain synchronous
//  active-high `reset` throughout - correct and preferred for the core's
//  own internal logic (fully synthesizable, no async set/reset cells
//  needed inside the datapath, clean STA). But the actual reset source
//  entering an ASIC top level (a POR cell, an external pin, a reset
//  controller) is normally asynchronous and must be:
//    1. Asserted immediately (async), so the chip resets even if the
//       clock is dead/stopped/not yet stable.
//    2. De-asserted synchronously to `clk`, so every flop in the design
//       that samples `reset` releases on the same clock edge - removing
//       reset-removal recovery/removal timing hazards that a plain
//       asynchronous release would create.
//  This module sits between the pad-level async reset and the
//  synchronous `reset` input the AES core (and this wrapper) expect.
//
//  USAGE
//  -----
//  Instantiate once per clock domain at the top of the chip/wrapper:
//    rst_sync u_rst_sync (.clk(ACLK), .async_rst_n(POR_n), .sync_rst(reset));
//  `sync_rst` is active-HIGH, matching the core's `reset` convention.
// ============================================================================
`timescale 1ns/1ps

module rst_sync (
    input  logic clk,
    input  logic async_rst_n,   // active-low async reset in (e.g. POR, pin)
    output logic sync_rst       // active-high sync reset out (-> core `reset`)
);

    (* ASYNC_REG = "TRUE" *) logic ff1, ff2;

    always_ff @(posedge clk or negedge async_rst_n) begin
        if (!async_rst_n) begin
            ff1 <= 1'b1;
            ff2 <= 1'b1;
        end else begin
            ff1 <= 1'b0;
            ff2 <= ff1;
        end
    end

    assign sync_rst = ff2;

endmodule

## ============================================================================
##  aes_axi_wrapper_standalone_pynq_z2.xdc
##
##  PURPOSE: interim, STANDALONE-TOP-LEVEL re-verification only.
##  Use this to re-run the exact synth diagnostic sequence from the
##  report (Section 15, steps 1-2) and confirm the WNS/TNS recovery from
##  Fix A / Fix B *before* building the real Zynq block-design IP
##  integration. This XDC intentionally still exposes every AXI signal
##  as a (fictitious) top-level pin -> IOB overuse (380 vs 125) WILL
##  still be reported here. That is expected and not a problem: pin
##  count is a non-issue once aes_axi_wrapper is instantiated inside the
##  Zynq block design (see vivado/README_IP_INTEGRATION.md / the Tcl
##  scripts in this folder) - this file only exists to re-check TIMING
##  in isolation, with the same clock/IO-delay budget as the original
##  diagnostic run, so the before/after comparison is apples-to-apples.
##
##  Do NOT use this file for the final bitstream. Use
##  build_block_design.tcl's generated constraints (board-preset XDC +
##  this file's clock/reset lines only) for that.
## ============================================================================

# ------------------------------------------------------------------------
# 1. Clock: 100 MHz, matching the original diagnostic run exactly
# ------------------------------------------------------------------------
create_clock -period 10.000 -name ACLK -waveform {0.000 5.000} [get_ports ACLK]

set_clock_uncertainty -setup 0.200 [get_clocks ACLK]

# ------------------------------------------------------------------------
# 2. Reset: asynchronous input to rst_sync's first flop - correctly
#    excluded from synchronous timing analysis. Do NOT add any other
#    false paths; every other path in this design is ordinary
#    single-cycle synchronous AXI/data/control logic.
# ------------------------------------------------------------------------
set_false_path -from [get_ports ARESETn]

# ------------------------------------------------------------------------
# 3. I/O delay budget - unchanged from the original run so the WNS
#    comparison is meaningful. These numbers are NOT a real interconnect
#    timing budget; once aes_axi_wrapper is inside the Zynq block
#    design, these ports don't exist as physical I/O at all and this
#    section is dropped entirely.
# ------------------------------------------------------------------------
set_input_delay  -clock ACLK -max 4.000 [get_ports -regexp {S_AXI.*|S_AXIS_.*}]
set_input_delay  -clock ACLK -min 0.000 [get_ports -regexp {S_AXI.*|S_AXIS_.*}]
set_output_delay -clock ACLK -max 4.000 [get_ports -regexp {S_AXI_[ABRW].*|S_AXIS_TREADY|M_AXIS_.*}]
set_output_delay -clock ACLK -min 0.000 [get_ports -regexp {S_AXI_[ABRW].*|S_AXIS_TREADY|M_AXIS_.*}]

# ARESETn and ACLK themselves are excluded from the regexp-based I/O
# delay application above (they aren't data ports); no action needed.

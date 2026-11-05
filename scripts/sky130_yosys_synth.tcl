## ============================================================================
##  sky130_yosys_synth.tcl
##
##  Standalone Yosys synthesis script for aes_axi_wrapper, targeting
##  sky130_fd_sc_hd. Produces a gate-level netlist ready for
##  OpenROAD place & route (or hand off to OpenLane - see
##  openlane_config.json alongside this script for the full-flow
##  equivalent).
##
##  PREREQUISITE: this design is written in SystemVerilog. Yosys 0.33's
##  native SV parsing does not accept this codebase's package-import
##  style directly (confirmed while developing this flow - see
##  docs/FIX_AND_BACKEND_README.md (verification results) and docs/how_to_run.md). Run sv2v FIRST to flatten to plain
##  Verilog-2005, exactly as done here:
##
##    sv2v -w synth_v2005/aes_axi_wrapper_flat.v $(grep -v '^#' scripts/filelist.f | grep -v '^$')
##
##  (sv2v: https://github.com/zachjs/sv2v - a well-established,
##  widely-used open-source SV-to-Verilog-2005 converter; this is a
##  standard step in open-source SKY130/OpenLane flows for
##  SystemVerilog sources, not a workaround specific to this design.)
##
##  USAGE
##  -----
##    export PDK_ROOT=/path/to/pdk            # e.g. from volare/open_pdks
##    export SKY130_LIB=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
##    yosys -c scripts/sky130_yosys_synth.tcl
##
##  Verified (this pass): sv2v conversion + Yosys generic elaboration
##  (read_verilog/hierarchy/proc/opt_clean/check/stat) completed cleanly
##  with zero errors, zero latches, zero combinational loops - see
##  docs/FIX_AND_BACKEND_README.md (verification results) and docs/how_to_run.md for the exact log. The `synth -flatten`
##  and ABC gate-mapping steps below were NOT run against real sky130hd
##  liberty in this environment (no PDK available here) and still need a
##  real run in the target tapeout environment before sign-off.
## ============================================================================

set DESIGN_TOP   "aes_axi_wrapper"
set RTL_FLAT     "synth_v2005/aes_axi_wrapper_flat.v"
set OUT_NETLIST  "synth_out/${DESIGN_TOP}.synth.v"
set OUT_JSON     "synth_out/${DESIGN_TOP}.synth.json"

if {![info exists ::env(SKY130_LIB)]} {
    puts "ERROR: set \$SKY130_LIB to the sky130_fd_sc_hd liberty file before running this script."
    puts "  e.g. export SKY130_LIB=\$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
    exit 1
}

file mkdir synth_out

yosys read_verilog $RTL_FLAT
yosys hierarchy -check -top $DESIGN_TOP

# Generic elaboration / sanity pass first (this is the pass already
# verified clean during development of this fix - see log referenced
# above). Catching latch/comb-loop issues HERE, before gate mapping, is
# far cheaper to debug than after ABC has obscured the structure.
yosys proc
yosys opt_clean
yosys check -noinit

# Performance-oriented synthesis strategy: this design's own timing
# budget (see constraints/aes_axi_wrapper.sdc) asks for performance over
# area, so bias `synth` and ABC accordingly (favor speed-optimized
# mapping over area-optimized mapping; flatten hierarchy so ABC can
# optimize across module boundaries rather than being blocked by them).
yosys synth -top $DESIGN_TOP -flatten

yosys dfflibmap -liberty $::env(SKY130_LIB)
yosys abc -liberty $::env(SKY130_LIB) -D [expr {int([lindex $argv 0 ] eq "" ? 4000 : [lindex $argv 0])}]
# -D <ps> above is ABC's target clock period constraint in picoseconds;
# pass it as an optional script argument, defaulting to 4000ps (4.0 ns,
# matching CLK_PERIOD_NS in constraints/aes_axi_wrapper.sdc) - keep the
# two numbers in sync if one changes.

yosys clean
yosys opt_clean

# sky130hd standard cells use these tie-cell names; substitute if the
# specific PDK variant/version in use differs.
yosys hilomap -hicell sky130_fd_sc_hd__conb_1 HI -locell sky130_fd_sc_hd__conb_1 LO

yosys stat -liberty $::env(SKY130_LIB)

yosys write_verilog -noattr $OUT_NETLIST
yosys write_json $OUT_JSON

puts "Synthesis complete: $OUT_NETLIST"
puts "Next: OpenROAD floorplan/place/CTS/route, then STA sign-off against"
puts "      constraints/aes_axi_wrapper.sdc using the SAME liberty corner(s)"
puts "      used here (run at least tt/ff/ss corners before tapeout, not"
puts "      just the one used for this synthesis pass)."

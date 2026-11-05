## ============================================================================
##  aes_axi_wrapper.sdc
##  SDC constraints for the aes_axi_wrapper top level, targeting the
##  SkyWater SKY130 (sky130_fd_sc_hd) standard-cell library.
##
##  Intent: performance-optimized, area may be relaxed. This means:
##    - A single, moderately-aggressive clock period target (below), meant
##      to be driven down further once initial STA/PnR results come back -
##      NOT a number derived from a real timing sign-off run on this
##      design (that requires the actual sky130hd .lib/.lef, which are
##      not available in this environment). Treat CLK_PERIOD_NS as the
##      starting point for the standard synthesize -> STA -> tighten loop.
##    - Generous clock uncertainty / IO margins (safe default assumptions,
##      not measured PLL jitter or board-level numbers) - tighten once
##      real PLL/IO-timing numbers for the target package are known.
##    - No area-driven multicycle relaxation anywhere: every path in this
##      design (AXI-Lite regs, AXI-Stream passthrough, the AES pipeline
##      itself) is constrained as ordinary single-cycle. There is nothing
##      in this design that legitimately needs area-saving multicycle
##      treatment, and inventing one would only put function at risk for
##      a benefit the design doesn't need (area is not the constraint
##      here).
##
##  USAGE
##  -----
##  Source this after `read_liberty`/`read_lef` and before/at
##  synthesis or STA invocation:
##    source scripts/sky130_yosys_synth.tcl   (which itself sources this file)
##  or, for a standalone OpenSTA/OpenROAD run:
##    read_sdc constraints/aes_axi_wrapper.sdc
## ============================================================================

# ------------------------------------------------------------------------
# 1. Clock definition
# ------------------------------------------------------------------------
# Starting target: 250 MHz (4.0 ns period). This is a reasonable opening
# bid for a single-round-per-pipeline-stage AES datapath (SubBytes/
# ShiftRows/MixColumns combinational per stage, registered between rounds)
# on sky130hd's typical-corner characteristics, NOT a verified number for
# THIS netlist - re-run STA after synthesis and walk this down (or up) to
# match what the actual critical path (almost certainly inside SubBytes'
# S-box LUT logic, or the AXI-Lite byte-strobed register-write mux) will
# support. Change this one line to retarget the whole constraint set.
set CLK_PERIOD_NS   4.0
set CLK_NAME        core_clk
set CLK_PORT        ACLK

create_clock -name $CLK_NAME -period $CLK_PERIOD_NS [get_ports $CLK_PORT]

# Uncertainty: setup margin covering clock-tree skew + jitter before a
# real CTS is run. 5% of period is a common, conservative pre-CTS
# starting allowance; revisit once actual CTS/skew numbers exist.
set_clock_uncertainty -setup [expr {$CLK_PERIOD_NS * 0.05}] [get_clocks $CLK_NAME]
set_clock_uncertainty -hold  0.10                            [get_clocks $CLK_NAME]

# Clock transition (slew) target at the clock pins - typical starting
# value for sky130hd designs pre-CTS.
set_clock_transition 0.15 [get_clocks $CLK_NAME]

# Clock is generated on-chip (or brought in) as an ideal clock for this
# constraint set; if a PLL/clock-gen macro is integrated upstream of
# ACLK, replace this create_clock with the appropriate
# create_generated_clock referencing that macro's output instead.

# ------------------------------------------------------------------------
# 2. Reset - asynchronous assert, synchronous release
# ------------------------------------------------------------------------
# ARESETn drives ONLY the async set/reset pin of rst_sync's two flops
# (see wrapper/rst_sync.sv) - it is not combinational data feeding any
# synchronous path, so it is not a valid startpoint for setup/hold
# analysis. STA tools handle the async pin's own recovery/removal timing
# automatically from the liberty async-pin timing arcs; this false_path
# only prevents ARESETn from being (incorrectly) treated as a normal
# clocked data input elsewhere.
set_false_path -from [get_ports ARESETn]

# ------------------------------------------------------------------------
# 3. I/O delay budgets
# ------------------------------------------------------------------------
# All I/O (AXI4-Lite + AXI4-Stream) is synchronous to ACLK, single clock
# domain (see aes_axi_wrapper.sv header - no CDC in this block by
# design). 40% of the period is a standard starting split between this
# block and whatever sits on the other side of the pad/interconnect;
# tighten once the actual fabric/interconnect timing model is known.
set IO_DELAY_NS [expr {$CLK_PERIOD_NS * 0.4}]

set ALL_INPUTS  [remove_from_collection [all_inputs] [get_ports [list $CLK_PORT ARESETn]]]
set ALL_OUTPUTS [all_outputs]

set_input_delay  -clock $CLK_NAME $IO_DELAY_NS $ALL_INPUTS
set_output_delay -clock $CLK_NAME $IO_DELAY_NS $ALL_OUTPUTS

# ------------------------------------------------------------------------
# 4. Driving cell / load assumptions for standalone (block-level) STA
# ------------------------------------------------------------------------
# Placeholder sky130_fd_sc_hd cells - substitute the integrator's actual
# pad/interconnect driver and the real downstream load once this block is
# dropped into a full chip/SoC timing view. These exist so block-level
# STA has *some* realistic edge condition rather than defaulting to a
# zero-impedance/zero-load ideal, which would understate real delay.
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin X $ALL_INPUTS
set_load [expr {4 * 0.0027}] $ALL_OUTPUTS
# (0.0027 pF ~ 1x sky130_fd_sc_hd__inv_1 input pin cap; 4x models a
#  modest fanout/interconnect load - adjust to the real downstream load.)

# ------------------------------------------------------------------------
# 5. Design rule / electrical constraints (performance-favoring: favor
#    buffering/upsizing over accepting slow, high-fanout nets)
# ------------------------------------------------------------------------
set_max_fanout     16   [current_design]
set_max_transition  0.75 [current_design]
# max_transition above is intentionally loose at the design level - the
# clock network itself is separately bounded tighter by
# set_clock_transition (0.15 ns) above; this line governs ordinary data
# nets, where sky130hd timing tends to stay well-behaved even up to
# ~0.75 ns transitions for the cell drive strengths in this library.

# ------------------------------------------------------------------------
# 6. Explicit non-goals (why no multicycle/exception paths are declared)
# ------------------------------------------------------------------------
# - Key expansion (AES_Key_Expansion) runs one round per cycle through
#   ordinary registers; each round's SubWord/RotWord/XOR is a single-
#   cycle combinational path like everything else here - no multicycle
#   relaxation applies or is used.
# - The AXI4-Lite write-accept path (aw_w_accept, see aes_axi_wrapper.sv)
#   is combinational-same-cycle by design; it's still just an ordinary
#   single-cycle path from the AXI master's registered outputs to this
#   block's registers, not a special timing case.
# - bank_gen_flat / key_gen comparison (the key-sync fix's accept gate,
#   aes_top.sv) is likewise ordinary combinational logic feeding a
#   registered accept decision - no exception needed.
## ============================================================================

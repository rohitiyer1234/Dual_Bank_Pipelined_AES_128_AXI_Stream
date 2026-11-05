# ============================================================================
#  filelist.f
#  Compile-order file list for the fixed AES-128 core + AXI wrapper.
#  Package/typedef files MUST come first (aes_pkg.sv), then leaf modules
#  before the modules that instantiate them, matching the elaboration
#  order already verified under Icarus during development of this fix
#  (see docs/FIX_AND_BACKEND_README.md (verification results) and docs/how_to_run.md).
#
#  Usage:
#    yosys -c scripts/sky130_yosys_synth.tcl                  (reads this list)
#    verilator --lint-only -f filelist.f -DVERILATOR     (lint pass)
#    vlog -sv -f filelist.f                              (Questa/ModelSim)
#
#  NOTE: sv2v does NOT support a -f/filelist flag (confirmed against
#  sv2v v0.0.13) - pass files as plain positional arguments instead:
#    sv2v -w synth_v2005/aes_axi_wrapper_flat.v $(grep -v '^#' scripts/filelist.f | grep -v '^$')
#
#  Paths are relative to the package root.
# ============================================================================

rtl/aes_pkg.sv

rtl/key_system/key_fifo.sv
rtl/key_system/key_controller.sv
rtl/key_system/AES_Key_Expansion.sv
rtl/key_system/keymem_dual.sv
rtl/key_system/key_system_top.sv

rtl/encrypt/SubBytes.sv
rtl/encrypt/ShiftRows.sv
rtl/encrypt/MixColumns.sv
rtl/encrypt/AES_Encrypt.sv

rtl/decrypt/InvSubBytes.sv
rtl/decrypt/InvShiftRows.sv
rtl/decrypt/InvMixColumns.sv
rtl/decrypt/AES_Decrypt.sv

rtl/aes_top.sv

wrapper/rst_sync.sv
wrapper/aes_axi_wrapper.sv

# NOTE: rtl/aes_ref_pkg.sv (the encrypt/decrypt reference model used by
# the project's own extensive KAT testbenches) is intentionally NOT
# listed here - it is simulation/verification-only golden-model code,
# never part of the synthesizable design, and must not be handed to the
# synthesis tool. Likewise tb_key_sync_fix.sv / wrapper/tb_aes_axi_wrapper.sv
# (this fix's own smoke tests) and the project's existing tb/ directory
# are simulation-only and excluded from this list on purpose.

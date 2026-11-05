# How to run the verification

## Key-sync fix smoke test (core-level)

```
iverilog -g2012 -o tb_sync.vvp \
  rtl/aes_pkg.sv \
  rtl/key_system/key_fifo.sv \
  rtl/key_system/key_controller.sv \
  rtl/key_system/AES_Key_Expansion.sv \
  rtl/key_system/keymem_dual.sv \
  rtl/key_system/key_system_top.sv \
  rtl/encrypt/SubBytes.sv rtl/encrypt/ShiftRows.sv rtl/encrypt/MixColumns.sv rtl/encrypt/AES_Encrypt.sv \
  rtl/decrypt/InvSubBytes.sv rtl/decrypt/InvShiftRows.sv rtl/decrypt/InvMixColumns.sv rtl/decrypt/AES_Decrypt.sv \
  rtl/aes_top.sv \
  rtl/tb_key_sync_fix.sv \
  -s tb_key_sync_fix
vvp tb_sync.vvp
```
Expect: `TB_KEY_SYNC_FIX RESULTS: PASS=9 FAIL=0`.

## AXI wrapper smoke test

```
iverilog -g2012 -o tb_wrap.vvp \
  rtl/aes_pkg.sv \
  rtl/key_system/key_fifo.sv \
  rtl/key_system/key_controller.sv \
  rtl/key_system/AES_Key_Expansion.sv \
  rtl/key_system/keymem_dual.sv \
  rtl/key_system/key_system_top.sv \
  rtl/encrypt/SubBytes.sv rtl/encrypt/ShiftRows.sv rtl/encrypt/MixColumns.sv rtl/encrypt/AES_Encrypt.sv \
  rtl/decrypt/InvSubBytes.sv rtl/decrypt/InvShiftRows.sv rtl/decrypt/InvMixColumns.sv rtl/decrypt/AES_Decrypt.sv \
  rtl/aes_top.sv \
  wrapper/rst_sync.sv \
  wrapper/aes_axi_wrapper.sv \
  wrapper/tb_aes_axi_wrapper.sv \
  -s tb_aes_axi_wrapper
vvp tb_wrap.vvp
```
Expect: `TB_AES_AXI_WRAPPER RESULTS: PASS=6 FAIL=0`.

## Re-generate the Verilog-2005 netlist (for Yosys/OpenLane)

```
sv2v -w synth_v2005/aes_axi_wrapper_flat.v $(grep -v '^#' scripts/filelist.f | grep -v '^$')
yosys -p "
  read_verilog synth_v2005/aes_axi_wrapper_flat.v
  hierarchy -check -top aes_axi_wrapper
  proc; opt_clean; check -noinit; stat
"
```
Expect: no errors, no latches, no combinational loops.

## Re-run the project's own existing regressions

The original `tb/` directory (KAT vectors, `tb_key_system.sv`,
`tb_aes_top.sv`, etc.) was not modified or re-copied into this delivery.
Point it at the fixed `rtl/` in this package and re-run — `key_fifo.sv`'s
instantiation changed shape (now `WIDTH`-parameterized rather than
`aes_pkg`-typed; `key_system_top.sv` now widens it internally), so any
testbench that instantiates `key_fifo` directly (rather than through
`key_system_top`) will need its port list updated to match. Testbenches
that only exercise `aes_top`/`key_system_top` from the outside should work
unmodified, modulo the new `key_gen`/`key_gen_out`/`bank_gen_flat`/
`key_ctx_error`/`key_push_ready` ports on `aes_top` and `key_system_top`
(new ports only — nothing existing was removed or renamed except
`bank_gen`, which didn't exist before this fix).

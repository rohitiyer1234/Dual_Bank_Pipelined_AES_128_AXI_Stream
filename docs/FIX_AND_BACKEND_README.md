# Dual-Bank Pipelined AES-128 — Key-Sync Fix, AXI Wrapper, SKY130 Backend Kit

Starting point: `rohitiyer1234/Dual_Bank_Pipelined_AES_128_Hardware_Accelerator`
(cloned and reviewed in full — every RTL file under `rtl/`, including the
key-management subsystem, was read before making any change).

## 1. The bug: key/data desynchronization

`aes_top`'s data channel took `current_bank` — a bare 1-bit index — from
whatever external master issues transactions, with **no hardware check that
the bank still held the key the master intended**. `keymem_dual` tracked
per-bank *validity* but never a key *identity/generation*. Concretely:

- A master could push a new key into a bank while an earlier transaction
  meant for that bank's *previous* key was still queued upstream (not yet
  issued into the core). Once issued, it would silently encrypt/decrypt
  under the **wrong key** — `bank_valid[current_bank]` would still read 1,
  so nothing in the core would object.
- Software had no way to confirm, at accept time, "is this still the key I
  think it is" — only "is *a* key present."
- A secondary issue in the same area: pushing a key into a full key FIFO
  silently dropped it with **zero indication anywhere** in the design.

## 2. The fix

A 16-bit generation handle (`key_gen_t`, `aes_pkg.sv`) is assigned to every
accepted key push, monotonically, and echoed back immediately
(`key_gen_out`). Each bank is stamped with the handle of the key it holds
(`bank_gen_flat`, a packed status vector). A data transaction must now
present the handle it expects (`key_gen`) alongside `current_bank`; `aes_top`
only accepts the transaction if `key_gen == bank_gen_flat[current_bank]`,
otherwise it withholds `in_ready` (ordinary AXI-style backpressure from the
caller's point of view) and pulses a new `key_ctx_error` status signal.

This is the same pattern used in production crypto accelerators (key
handle/context-ID matching before processing) — reject on mismatch rather
than trusting the caller's bookkeeping.

**Files touched:** `aes_pkg.sv`, `key_fifo.sv`, `keymem_dual.sv`,
`key_system_top.sv`, `aes_top.sv`.
**Files NOT touched (confirmed byte-for-byte identical to upstream):**
`key_controller.sv`, `AES_Key_Expansion.sv`, `AES_Encrypt.sv`,
`AES_Decrypt.sv`, `SubBytes/ShiftRows/MixColumns.sv`,
`InvSubBytes/InvShiftRows/InvMixColumns.sv`. The fix lives entirely in the
key-management side; the already-verified cipher/transform pipelines were
never modified, on the reasoning that a transaction's bank tag — once
accepted — already guarantees (via existing, verified `bank_busy` logic)
that the key can't change under it mid-flight. The fix only needed to close
the *acceptance-time* gap, not touch in-flight correctness.

A secondary fix: `key_push_ready` (`= !fifo_full`) is now exposed, so a
push against a full FIFO is observable instead of silently dropped.

### A note on port shape (`bank_gen_flat`)

`bank_gen` is exposed as a **flat packed vector**
(`logic [NUM_BANKS*KEY_GEN_W-1:0]`), not an unpacked `key_gen_t[NUM_BANKS]`
array, despite that being the more "natural" SV type. This was deliberate,
found during verification: an unpacked/typedef'd array relayed
output-port→output-port through two hierarchy levels
(`keymem_dual → key_system_top → aes_top`) hits a real simulator
propagation gap under Icarus — the exact same class of issue this repo
already documents for `round_keys`. `bank_valid`/`bank_free` (plain packed
`logic[1:0]`) already relay correctly through the same depth, so the flat
vector both sidesteps that gap and is arguably the more portable,
synthesis-friendly choice anyway.

## 3. Verification

Two purpose-built, self-checking testbenches (not a replacement for the
project's own existing KAT regressions — those weren't touched and should
still be re-run):

- **`rtl/tb_key_sync_fix.sv`** — exercises the fix directly at the `aes_top`
  boundary: push key → correct-context accept → wrong-context reject (+
  `key_ctx_error` strobe) → reload the bank with a second key → confirm the
  *old* handle is now rejected on that bank while the *new* handle is
  accepted (the actual race the fix closes).
  **Result: 9/9 PASS.**
  (A 10th, informational-only check — full ciphertext content against the
  FIPS-197 KAT — is skipped under Icarus due to the pre-existing
  `round_keys` propagation gap noted above; it is **not** part of the
  fix and doesn't affect its correctness. AES correctness itself is
  already exhaustively covered by this project's own 6,281-vector
  regressions, untouched by this change.)

- **`wrapper/tb_aes_axi_wrapper.sv`** — end-to-end through the AXI shell:
  stage a key via AXI4-Lite writes, pulse push, read back the handle,
  issue one AXI4-Stream transaction with the correct handle (accepted,
  produces a result), then one with a wrong handle (refused,
  `KEY_STATUS.key_ctx_error` sticky bit set).
  **Result: 6/6 PASS.**

Both testbenches surfaced and required fixing real bugs during
development (documented inline at the point of the fix in each file, not
just here): a one-cycle-early generation-tag latch in the original attempt
at the core fix, and a non-compliant multi-cycle-hold AXI-Lite testbench
master that caused (correct, per-protocol) duplicate-write acceptance
against the wrapper's combinational-acceptance slave logic. Both are fixed;
neither was papered over.

Run either: see `docs/how_to_run.md`.

## 4. AXI wrapper (`wrapper/aes_axi_wrapper.sv`)

AXI4-Lite slave for key load/control/status + AXI4-Stream slave/master for
data, wrapping the fixed `aes_top` untouched underneath. Full register map
and stream sideband (`TUSER`) layout are documented in the file header.
Single clock domain (`ACLK` drives the core too) — deliberate, to avoid
adding CDC surface area in a change whose job is fixing a correctness bug,
not introducing new clock-domain risk. `wrapper/rst_sync.sv` provides the
standard async-assert/sync-deassert reset synchronizer between `ARESETn`
and the core's synchronous `reset`.

## 5. Backend flow (SKY130)

- `constraints/aes_axi_wrapper.sdc` — performance-first constraints (4.0 ns
  / 250 MHz starting target — explicitly flagged as a starting point, not
  a signed-off number; see file header), generous IO/uncertainty margins,
  loose fanout/transition limits (favor buffering over area). No
  multicycle exceptions anywhere — nothing in this design legitimately
  needs one.
- `scripts/filelist.f` — compile-order file list.
- `scripts/sky130_yosys_synth.tcl` — Yosys synthesis script targeting
  `sky130_fd_sc_hd`.
- `scripts/openlane_config.json` — full RTL-to-GDS OpenLane flow config
  (relaxed `PL_TARGET_DENSITY`/`FP_CORE_UTIL`, delay-optimized synthesis
  strategy, core power ring — all consistent with "optimize for
  performance, relax on area").
- `synth_v2005/aes_axi_wrapper_flat.v` — the design pre-converted to plain
  Verilog-2005 via `sv2v` (open-source, standard step for SystemVerilog in
  SKY130/OpenLane flows — Yosys 0.33's native SV parser doesn't accept
  this codebase's package-import style directly). **Already generated and
  verified in this pass** — see next section.

### What was actually verified in this environment vs. left for you

No SKY130 PDK/liberty files are available in this sandbox, so I could not
run a real gate-level synthesis, STA, or place-and-route pass. What **was**
verified here:
- `sv2v` conversion of the entire design (fix + wrapper) to Verilog-2005:
  clean, zero errors.
- Yosys generic elaboration of the converted netlist
  (`read_verilog → hierarchy → proc → opt_clean → check → stat`): **zero
  errors, zero latches, zero combinational loops**, ~9,500 cells at the
  RTL-primitive level. The only warnings are Yosys flattening small
  pipeline shift-register arrays (`bank[]`, `state[]`, `valid[]`,
  `op_mode_pipe[]`) into individual flops — expected, benign.

Still needed before tapeout, in your environment: real `synth`/`abc`
mapping against `sky130_fd_sc_hd` liberty, OpenROAD floorplan/place/CTS/
route, STA sign-off at **multiple corners** (not just typical — the SDC
and OpenLane config both flag this), DRC/LVS, and re-running the project's
own existing KAT regressions against the now-fixed key-management RTL.

## 6. Other shortcomings noted, and what was (not) done about them

- **Bank-0 arbitration priority** (`key_controller.sv`): when both banks
  are free, key expansion always lands in bank 0 first. This is already
  documented in the repo as a deliberate design trade-off, not a bug —
  left untouched.
- **No CDC** between the AXI fabric and the core: avoided entirely by
  running both on one clock domain in this wrapper (see §4). If your SoC
  integration needs the core on a different clock, add a standard AXI
  register-slice/CDC IP between this wrapper and the fabric — don't bolt
  ad hoc CDC onto the core or this wrapper.
- **DFT/scan**: not added. This pass focused on functional correctness
  ahead of tapeout; scan-chain insertion is normally a synthesis-flow
  concern (`INSERT_SCAN` style options in most backend tools) layered on
  top of a functionally-clean netlist like this one, not something to
  hand-roll into the RTL.

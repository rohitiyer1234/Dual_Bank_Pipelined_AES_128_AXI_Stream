# Running `aes_axi_wrapper` Through OpenLane2: A Step-by-Step Learning Guide

This is a hands-on guide to taking the fixed AES-128 core + AXI wrapper
(from the previous deliverable) all the way through OpenLane2's RTL-to-GDS
flow on the SkyWater 130nm PDK — install, first run, reading the results,
and then the part that actually matters for a good chip: the PPA
(Power/Performance/Area) tuning loop, with concrete knobs for *this*
design and scripts to automate the search.

It assumes you already have the `delivery/` package from the previous step
(the fixed `rtl/`, `wrapper/`, `constraints/aes_axi_wrapper.sdc`,
`scripts/filelist.f`, and `synth_v2005/aes_axi_wrapper_flat.v`).

> **A naming note before you start.** As of this writing, OpenLane
> (the original, `OpenLane 1`) is in **maintenance mode** — critical
> bugfixes only, not recommended for new designs. **OpenLane 2**, what
> this guide covers, is under active development at
> `github.com/efabless/openlane2`, and its own documentation now points
> to a community-driven successor called **LibreLane**
> (`github.com/librelane/librelane`), described as backwards-compatible
> with OpenLane 2's configuration format. Everything in this guide will
> work with OpenLane 2 as installed below; if you find OpenLane 2 itself
> has been archived or redirected by the time you read this, the same
> `config.json`, SDC, and commands should carry over to LibreLane with at
> most the install step changing — check
> `https://github.com/efabless/openlane2` first, it will tell you plainly
> if that's happened.

---

## Table of Contents

1. [Prerequisites & mental model](#1-prerequisites--mental-model)
2. [Installing OpenLane2](#2-installing-openlane2)
3. [Preparing the design directory](#3-preparing-the-design-directory)
4. [Writing `config.json`](#4-writing-configjson)
5. [First run: the smoke test, then the real thing](#5-first-run-the-smoke-test-then-the-real-thing)
6. [Reading the results](#6-reading-the-results)
7. [The PPA tuning loop, stage by stage](#7-the-ppa-tuning-loop-stage-by-stage)
   - 7.1 [Synthesis](#71-synthesis-stage)
   - 7.2 [Floorplan](#72-floorplan-stage)
   - 7.3 [Placement](#73-placement-stage)
   - 7.4 [Clock Tree Synthesis (CTS)](#74-clock-tree-synthesis-cts)
   - 7.5 [Global & Detailed Routing](#75-global--detailed-routing)
   - 7.6 [Power (the "P" in PPA)](#76-power-the-p-in-ppa)
8. [Automating the search: Python and TCL scripts](#8-automating-the-search-python-and-tcl-scripts)
9. [Signoff checklist](#9-signoff-checklist)
10. [Design-specific notes for this AES core](#10-design-specific-notes-for-this-aes-core)
11. [Quick command reference](#11-quick-command-reference)

---

## 1. Prerequisites & mental model

OpenLane2 takes your RTL (or, as in our case, a pre-synthesizable netlist
you've already converted from SystemVerilog) through the full ASIC
implementation flow:

```
RTL → Synthesis → Floorplan → Placement → CTS → Global Route
    → Detailed Route → Signoff (DRC/LVS/STA/Antenna) → GDSII
```

Each stage is a **Step**. A sequence of Steps is a **Flow** — the default,
`Classic`, is what we'll use. Each Step reads a `state_in.json` (the
design's current layout + metrics), does its job, and writes
`state_out.json`. This means:

- Every intermediate result (DEF, netlist, ODB, metrics) is inspectable —
  nothing is a black box.
- You can **resume from, or re-run starting at, any step** by feeding it a
  saved state — this is what makes the PPA tuning loop in §7 practical:
  you don't have to re-run synthesis every time you tweak a placement
  variable.

Minimum machine spec: quad-core CPU, 2.0GHz+, 8GiB RAM (16GiB and a recent
6+ core CPU recommended — CTS and detailed routing are the slow steps).

**Knowledge assumed:** basic digital design, JSON, and enough RTL
familiarity to read the SDC/config decisions we made in the previous
deliverable. If any OpenLane term below is unfamiliar, the project's own
[Glossary](https://openlane2.readthedocs.io/en/latest/glossary.html) is
worth a bookmark.

---

## 2. Installing OpenLane2

Two supported install paths: **Nix** (recommended — reproducible, no
Docker VM overhead, smaller update deltas) and **Docker** (works
everywhere, add `--dockerized` after `openlane` in every CLI command
below if you go this route). A pip-only install exists but is explicitly
called out by the project as unsupported/at-your-own-risk — skip it.

### 2.1 Nix install (Ubuntu/Linux — what this guide uses)

```bash
# 1. curl is required to install Nix
sudo apt-get install -y curl

# 2. Install Nix with OpenLane's binary cache pre-configured
#    (this avoids rebuilding every EDA tool from source - ~5 minutes)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install --no-confirm --extra-conf "
    extra-substituters = https://openlane.cachix.org
    extra-trusted-public-keys = openlane.cachix.org-1:qqdwh+QMNGmZAuyeQJTH9ErW57OWSvdtuwfBKdS254E=
"

# Close and reopen your terminal after this step.
```

If you already had Nix installed before reading this, you need to add the
cache manually instead — see the
[Nix-based Installation](https://openlane2.readthedocs.io/en/latest/getting_started/common/nix_installation/installation_linux.html)
docs for the `cachix use openlane` steps.

```bash
# 3. Clone OpenLane2
git clone https://github.com/efabless/openlane2/ ~/openlane2

# 4. Enter the OpenLane environment (first time: ~10 min, pulls ~3GiB)
nix-shell --pure ~/openlane2/shell.nix
# Your prompt should now read: [nix-shell:~/openlane2]$

# 5. Smoke-test - this also auto-downloads the sky130 PDK
[nix-shell:~/openlane2]$ openlane --log-level ERROR --condensed --show-progress-bar --smoke-test
```

**Everything from here on assumes you're inside that `nix-shell`.** If a
command isn't found, you probably closed the shell — re-run step 4.

### 2.2 Docker install (alternative)

Follow
[Docker-based Installation](https://openlane2.readthedocs.io/en/latest/getting_started/common/docker_installation/index.html)
for your OS. The short version: install Docker, then every `openlane`
command in this guide becomes `openlane --dockerized ...`. You'll still
need to provision the PDK yourself (see the docs page above) since there's
no `nix-shell` auto-download step.

### 2.3 Verifying the install

```bash
[nix-shell:~/openlane2]$ openlane --version
```

---

## 3. Preparing the design directory

> **If you're reading this inside the consolidated project repo** (the one
> with `rtl/`, `wrapper/`, `constraints/`, `scripts/`, `synth_v2005/`, and
> this `docs/` folder all as siblings), **you can skip straight to §5** —
> a ready-to-run `config.json` already sits at the repo root, pointing at
> `synth_v2005/aes_axi_wrapper_flat.v` and `constraints/aes_axi_wrapper.sdc`
> via paths relative to itself. Just `cd` into the repo root and run
> `openlane config.json`. The rest of §3–§4 below describes the general,
> from-scratch process (useful if you're setting this up in a fresh
> directory, or want to understand *why* the shipped `config.json` looks
> the way it does) — the shipped file already reflects every choice
> explained here.

Create a working directory and drop in the artifacts from the previous
deliverable:

```bash
mkdir -p ~/my_designs/aes_axi_wrapper
cd ~/my_designs/aes_axi_wrapper

# Copy the pre-flattened Verilog-2005 netlist (sv2v output) - see the
# previous delivery's docs/README.md §5 for why this exists: OpenLane2's
# bundled Yosys doesn't parse this codebase's SV package-import style
# directly.
cp /path/to/delivery/synth_v2005/aes_axi_wrapper_flat.v .

# Copy our own SDC (used for the pre/mid-PnR constraint set)
mkdir -p src
cp /path/to/delivery/constraints/aes_axi_wrapper.sdc src/
```

> **Alternative: let OpenLane2 run sv2v/Yosys itself.** If you'd rather
> hand OpenLane2 the original `.sv` files and let its own Verilog
> frontend (which does have some SystemVerilog support) attempt the
> parse, list them via `VERILOG_FILES` in `config.json` (§4) in the
> compile order from `scripts/filelist.f`, minus `aes_ref_pkg.sv` and the
> testbenches. If that hits the same package-import parsing issue we hit
> with plain Yosys during development (see the previous deliverable's
> `docs/README.md`), fall back to the pre-flattened netlist above — it's
> the same design, already verified to elaborate cleanly.

---

## 4. Writing `config.json`

This is the single file that drives the whole flow. Below is a complete,
working configuration for our design — a cleaned-up, OpenLane2-native
version of the `scripts/openlane_config.json` sketch from the previous
deliverable (that one mixed in some OpenLane-1-flavored key names; this
one uses confirmed OpenLane2 `Classic`-flow variable names throughout).

**`config.json`:**
```json
{
  "PDK": "sky130A",
  "DESIGN_NAME": "aes_axi_wrapper",
  "VERILOG_FILES": "dir::aes_axi_wrapper_flat.v",

  "CLOCK_PORT": "ACLK",
  "CLOCK_PERIOD": 4.0,

  "PNR_SDC_FILE": "dir::src/aes_axi_wrapper.sdc",
  "SIGNOFF_SDC_FILE": "dir::src/aes_axi_wrapper.sdc",

  "FP_SIZING": "relative",
  "FP_CORE_UTIL": 35,
  "PL_TARGET_DENSITY": 0.40,

  "SYNTH_STRATEGY": "DELAY 3",
  "SYNTH_BUFFERING": 1,
  "SYNTH_SIZING": 1,

  "RUN_POST_CTS_RESIZER_TIMING": 1,
  "RUN_POST_GRT_RESIZER_TIMING": 1,

  "FP_PDN_CORE_RING": 1
}
```

A few notes on choices here, since "why" matters more than "what" for a
learning guide:

- **`CLOCK_PERIOD: 4.0`** (250MHz) is the same starting target from our
  SDC — explicitly a *starting point*, not a signed-off number. §7 is
  about how you actually arrive at a real number for this design.
- **`PNR_SDC_FILE` vs `SIGNOFF_SDC_FILE`** are deliberately the same file
  here. OpenLane2 lets you point these at *different* files — a common
  trick is to slightly over-constrain PnR (tighter period) so the
  optimizer works harder, then sign off timing against the real,
  slightly relaxed target. Once you've picked a real target frequency in
  §7, this is worth trying.
- **`FP_CORE_UTIL: 35` / `PL_TARGET_DENSITY: 0.40`** — low utilization,
  consistent with "optimize for performance, relax on area": more
  routing headroom means placement and CTS have more freedom to keep
  timing-critical nets short instead of being forced into a dense,
  congested floorplan.
- **`SYNTH_STRATEGY: "DELAY 3"`** — biases Yosys/ABC's technology mapping
  toward delay optimization over area, the other half of that same
  intent.
- **`FP_PDN_CORE_RING: 1`** — see §7.6; a reasonable, cheap-given-relaxed-area
  choice for a crypto block with bursty per-cycle switching activity.

Minimum required variables for *any* design, per the docs, are
`DESIGN_NAME`, `VERILOG_FILES`, `CLOCK_PERIOD`, `CLOCK_PORT` — everything
else above is us actively steering PPA, not boilerplate.

---

## 5. First run: the smoke test, then the real thing

You already ran `--smoke-test` once during install (§2.1) — that exercises
the toolchain against a tiny bundled design, not ours. Now run our design:

```bash
[nix-shell:~/openlane2]$ openlane ~/my_designs/aes_axi_wrapper/config.json
```

This will take anywhere from a few minutes (small/lenient constraints) to
much longer (tight timing, dense placement, big designs) — for a
single-clock AES-128 pipeline like this, expect low tens of minutes on a
reasonable machine for a first pass.

Useful flags while iterating:

```bash
# Quieter output, single progress bar instead of a full log stream
openlane --log-level ERROR --condensed --show-progress-bar config.json

# Give the run a name you'll recognize later (instead of a timestamp)
openlane --run-tag baseline_4ns_util35 config.json
```

Each invocation creates a new run directory:
`runs/<RUN_TAG_or_timestamp>/`. **Nothing is overwritten** — this is
deliberate and is what makes the sweep methodology in §8 safe: every
experiment gets its own directory you can compare against the others.

---

## 6. Reading the results

### 6.1 Run directory anatomy

```
runs/baseline_4ns_util35/
├── 01-verilator-lint/
├── 02-checker-linttimingconstructs/
├── 04-yosys-jsonheader/
├── 05-yosys-synthesis/
├── 09-openroad-staprepnr/          <- first real timing signal
├── 10-openroad-floorplan/
├── 15-openroad-globalplacementskipio/
├── ...-openroad-detailedplacement/
├── ...-openroad-cts/
├── ...-openroad-globalrouting/
├── ...-openroad-detailedrouting/
├── ...-magic-drc/
├── ...-klayout-drc/
├── ...-netgen-lvs/
├── ...-openroad-stapostpnr/         <- signoff timing (most accurate)
├── final/
│   ├── gds/                        <- what you'd tape out
│   ├── def/  lef/  odb/  spef/  sdf/  nl/  pnl/  lib/
│   ├── metrics.json                <- THE file for PPA tracking
│   └── metrics.csv
├── resolved.json                   <- every config variable, fully resolved
├── error.log  warning.log  info.log
```

Every step directory has the same shape: `config.json` (what it saw),
`*.log`, `state_in.json` / `state_out.json` (layout + metrics before/after),
and step-specific outputs. This uniformity is what makes writing
automation against the flow tractable — see §8.

### 6.2 Viewing the layout

```bash
# Final GDS in KLayout
openlane --last-run --flow openinklayout config.json

# Or the OpenROAD GUI (better for inspecting placement/routing/timing interactively)
openlane --last-run --flow openinopenroad config.json

# View an INTERMEDIATE state (e.g. right after floorplanning)
openlane --last-run --flow openinklayout config.json \
  --with-initial-state runs/baseline_4ns_util35/10-openroad-floorplan/state_out.json
```

### 6.3 Timing reports — where PPA lives

The step `OpenROAD.STAPostPNR` (final signoff STA, using real extracted
parasitics — the most trustworthy numbers in the whole flow) writes one
subdirectory per **IPVT corner** (Interconnect/Process/Voltage/Temperature
— the worst-case operating-condition combinations a real chip must survive,
*not* just the corner your synthesis ran against):

```
<N>-openroad-stapostpnr/
├── nom_tt_025C_1v80/
│   ├── max.rpt          <- setup-check paths, worst first
│   ├── min.rpt           <- hold-check paths, worst first
│   ├── wns.max.rpt       <- Worst Negative Slack (setup) - THE headline number
│   ├── wns.min.rpt       <- Worst Negative Slack (hold)
│   ├── tns.max.rpt        <- Total Negative Slack (setup) - how BAD, not just worst-case
│   ├── skew.max.rpt       <- clock skew (setup)
│   ├── violator_list.rpt  <- every failing endpoint
│   ├── checks.rpt         <- max cap / max slew / max fanout / SDC sanity
│   ├── power.rpt
│   └── ...
├── nom_ss_100C_1v60/     <- slow-slow, hot, low voltage: worst for SETUP
├── nom_ff_n40C_1v95/     <- fast-fast, cold, high voltage: worst for HOLD
└── summary.rpt           <- one table, every corner, at a glance
```

**`summary.rpt` is your first stop after every run** — it's a single
table across every corner with Setup/Hold Worst Slack, TNS, and violation
counts. A design is only "closed" when **every corner** shows
`Setup Violations: 0` and `Hold Violations: 0` — not just the typical
corner. This matters a lot in practice: the slow-slow-hot-low-voltage
corner (`ss_100C_1v60`-ish) is usually your worst setup case, and
fast-fast-cold-high-voltage is usually your worst hold case — they pull
in opposite directions, which is exactly why hold fixing and setup
fixing are separate knobs in §7.

A single timing path report (from `max.rpt`) reads like this — get
comfortable with this shape, you'll read hundreds of them:

```
Startpoint: x[9] (input port clocked by clk)
Endpoint: _618_ (rising edge-triggered flip-flop clocked by clk)
Path Group: clk
Delay    Time    Description
---------------------------------------------------------
0.00     0.00    clock clk (rise edge)
0.20     0.20    input external delay
0.08     0.28    _537_/Y (sky130_fd_sc_hd__nand2_1)
0.06     0.34    _541_/Y (sky130_fd_sc_hd__o21ai_1)
0.34     data arrival time
...
0.39     slack (MET)
```

Positive slack = met. Negative = violation. The cell names in the delay
column (`sky130_fd_sc_hd__nand2_1`, etc.) tell you exactly which gates on
the critical path are worth attacking first (§7 covers how).

### 6.4 `final/metrics.json` — the PPA scoreboard

This is the file to script against (§8). It's a flat JSON of every metric
the flow tracked: final area, cell count, worst slack per corner, power
(if `RUN_IRDROP_REPORT`/power reporting is enabled), DRC/LVS violation
counts, and more. `final/metrics.csv` is the same data, spreadsheet-ready.

---

## 7. The PPA tuning loop, stage by stage

The mental model: **run → read `summary.rpt` and `metrics.json` → identify
which stage is limiting you → adjust that stage's variables → re-run from
that stage (not from scratch) → repeat.**

Below, for each stage: what it controls, the variables that move PPA, and
concrete guidance for *this* design.

### 7.1 Synthesis stage

**Controls:** technology mapping — how RTL becomes gates. This is where
most of your Power and a good chunk of your achievable Performance ceiling
gets set; PnR can only work with the netlist synthesis hands it.

| Variable | Effect |
|---|---|
| `SYNTH_STRATEGY` | `"AREA 0"`through `"DELAY 4"` — ABC mapping bias. We used `"DELAY 3"`. |
| `SYNTH_BUFFERING` / `SYNTH_SIZING` | Allow ABC to insert buffers / upsize cells during synthesis itself, ahead of PnR-stage resizing. |
| `SYNTH_NO_FLAT` | Keep hierarchy through synthesis (debug-friendly) vs. flatten (usually better QoR — we flatten). |

**For this design specifically:** the critical path is almost certainly
either (a) inside `SubBytes`' S-box logic (a LUT-shaped 8-to-8 Boolean
function — inherently the widest combinational fan-in in the whole
pipeline) or (b) the AXI-Lite write-accept combinational path
(`aw_w_accept` → the byte-strobed register-write mux in
`aes_axi_wrapper.sv`). **Check `09-openroad-staprepnr/nom_tt_025C_1v80/max.rpt`
first** — this runs right after synthesis with an *ideal* clock (no skew
yet), so it isolates pure logic-depth problems from clock-tree problems.
If your worst path here is inside `SubBytes`, that's expected and mostly
a synthesis-strategy problem (try `DELAY 4`, or consider whether the
S-box should be pipelined into two half-round stages — a genuine RTL
change, out of scope for a "just retarget the constraints" pass, but the
honest answer if `DELAY 4` isn't enough). If it's the AXI-Lite path,
that's a much smaller, cheaper-to-fix combinational mux and should yield
readily to synthesis/placement tuning alone.

### 7.2 Floorplan stage

**Controls:** the die/core area and where the core sits inside it —
everything downstream (placement, routing) inherits this.

| Variable | Effect |
|---|---|
| `FP_SIZING` | `"relative"` (util-percentage driven, what we used) vs `"absolute"` (exact `DIE_AREA`) |
| `FP_CORE_UTIL` | Target utilization %. **Lower = more routing/placement headroom = usually better timing, worse area.** |
| `FP_ASPECT_RATIO` | Die shape — matters for pin-heavy designs (our AXI4-Lite + two AXI4-Stream interfaces are pin-heavy for a block this size) |
| `FP_PDN_CORE_RING` etc. | Power ring around the core, see §7.6 |

**For this design:** we started at `FP_CORE_UTIL: 35`. If, after a full
run, `metrics.json` shows comfortable positive slack everywhere with
margin to spare, that's your signal to **raise** utilization (try 45, then
55) and re-run — you're paying area for timing margin you don't need. If
you're still violating setup after the placement/CTS/routing resizer
passes (§7.3–7.5) have done what they can, **lower** it further (try 25)
before reaching for a slower clock period — more space is often cheaper
than you'd expect for a design this size.

### 7.3 Placement stage

**Controls:** where each cell physically sits. This is where the biggest
performance/area trade-off decisions actually get made, via two
sub-phases: global placement (density target) and the post-placement
resizer (timing-driven buffering/sizing).

| Variable | Effect |
|---|---|
| `PL_TARGET_DENSITY` | Local placement density target (distinct from, but related to, `FP_CORE_UTIL`) |
| `PL_RESIZER_TIMING_OPTIMIZATIONS` | Enable timing-driven resizing after placement |
| `PL_RESIZER_SETUP_SLACK_MARGIN` | Don't stop at 0 slack — target *this much* positive margin (guards against the small pessimism PnR→signoff timing shifts introduce) |
| `PL_RESIZER_HOLD_SLACK_MARGIN` | Same, for hold |
| `PL_RESIZER_SETUP_MAX_BUFFER_PCT` / `PL_RESIZER_HOLD_MAX_BUFFER_PCT` | Caps how much cell-area growth the resizer is allowed to spend fixing violations — the direct area/performance dial |
| `PL_RESIZER_ALLOW_SETUP_VIOS` | If you don't have a hard frequency requirement (we don't — 250MHz was a starting guess, not a spec), let the resizer sacrifice setup margin to prioritize fixing hold violations instead |

**This is the single most important stage for this design's stated
goal ("optimize for performance, relax on area").** Concretely:

```json
"PL_RESIZER_TIMING_OPTIMIZATIONS": 1,
"PL_RESIZER_SETUP_SLACK_MARGIN": 0.15,
"PL_RESIZER_HOLD_SLACK_MARGIN": 0.10,
"PL_RESIZER_SETUP_MAX_BUFFER_PCT": 40,
"PL_RESIZER_HOLD_MAX_BUFFER_PCT": 40
```

The `MAX_BUFFER_PCT` values above (40%) are deliberately generous —
default OpenLane2 values are more conservative (area-preserving); since
we've already said area can be relaxed, give the resizer more room to
spend cells fixing timing before it gives up.

### 7.4 Clock Tree Synthesis (CTS)

**Controls:** how the clock physically reaches every flip-flop — this is
almost entirely about **hold** violations (setup is dominated by logic
depth from §7.1–7.3; hold is dominated by clock skew from CTS).

| Variable | Effect |
|---|---|
| `CTS_CLK_BUFFERS` | Which buffer *sizes* CTS may use for the clock tree. **The docs specifically call out limiting this list as helping balance skew** — fewer size choices per level of the tree tends to produce a more uniform (lower-skew) tree. |
| `RUN_POST_CTS_RESIZER_TIMING` | Whether to run another timing-driven fix-up pass right after CTS (once *real* skew exists, not the ideal clock from §7.1) — leave this on. |
| `CTS_TARGET_SKEW` | Explicit skew target in ps |

**Workflow specific to this design:** run once with `RUN_POST_CTS_RESIZER_TIMING: 1`
and defaults, then look at `skew.max.rpt`/`skew.min.rpt` in the mid-PnR
STA step. If skew is uneven (check whether it correlates with die
location — e.g. worse near the AXI-Lite register block vs. the AES
pipeline, which would suggest a floorplan/placement issue feeding CTS
rather than a CTS issue itself), narrow `CTS_CLK_BUFFERS` to 2–3 sizes and
re-run just from the CTS step (see the "resume from a step" technique in
§8.2).

### 7.5 Global & Detailed Routing

**Controls:** actual wire geometry — this is where parasitic
capacitance/resistance becomes real (vs. the estimated values STA used
before this point), so it's also where **`STAPostPNR`'s numbers can
meaningfully diverge from what mid-PnR STA predicted**.

| Variable | Effect |
|---|---|
| `RUN_POST_GRT_RESIZER_TIMING` | Another timing-driven fix-up pass after global routing, using real global-route parasitics — the docs flag this as experimental/can crash; if it does, disable it and rely on the post-CTS pass + signoff-stage manual fixes instead |
| `GRT_RESIZER_SETUP_SLACK_MARGIN` / `GRT_RESIZER_HOLD_SLACK_MARGIN` / `*_MAX_BUFFER_PCT` | Same shape of knobs as §7.3, one stage later |
| `DIODE_INSERTION_STRATEGY` | Antenna-violation avoidance strategy — affects routing congestion, marginally affects area, essentially never affects timing directly |

**Check `checks.rpt` (§6.3) for max-capacitance and max-transition
violations after this stage** — per the official timing-closure guide,
these are "OK if you don't have setup/hold violations" but are early
warning signs of high-fanout or over-long nets that *will* eventually
cost you timing margin as you push the clock period down further. Our
SDC's `set_max_fanout 16` / `set_max_transition 0.75` are meant to keep
routing honest about this rather than silently accepting a slow, poorly-
buffered net.

### 7.6 Power (the "P" in PPA)

We haven't optimized for power at all in this pass — deliberately, since
"optimize for performance, relax on area" was the stated priority, and
low-power techniques (multi-Vt cell swapping, clock gating, power gating)
generally trade against both. If/when power becomes a target:

- `FP_PDN_CORE_RING: 1` (already set) trades area for **supply
  robustness** — worth keeping regardless, since a crypto pipeline's
  every-cycle, wide simultaneous-switching activity (the AES round
  function touches essentially the whole 128-bit state every clock) is a
  worse-than-typical di/dt profile for IR drop.
- Enable `RUN_IRDROP_REPORT: 1` (already in our config) and read the
  resulting IR-drop report under the relevant PDN/signoff step — this
  tells you if the ring/strap density above is actually adequate for
  this design's real switching activity, not just a rule of thumb.
- For real power reduction, the first lever (before anything more
  invasive) is almost always **clock-gating the idle engine** — right
  now, both the encrypt and decrypt pipelines' registers toggle every
  cycle a transaction of *either* direction is in flight in the other
  one, since `aes_top`'s own internal arbitration (see the previous
  deliverable) doesn't currently gate the *inactive* direction's clock.
  That's an RTL-level change, out of scope here, but worth flagging as
  the highest-leverage next step if power ever becomes a hard target.

---

## 8. Automating the search: Python and TCL scripts

Manually editing `config.json` and re-running for every experiment doesn't
scale once you're sweeping multiple variables. OpenLane2 is a Python
library first, CLI tool second — use the Python API directly.

### 8.1 Python: sweep clock period × placement density, rank by PPA

```python
#!/usr/bin/env python3
"""
sweep_ppa.py — sweep CLOCK_PERIOD and PL_TARGET_DENSITY for
aes_axi_wrapper, run each point through the Classic flow, and rank the
results by (in priority order): timing closure achieved, then area, then
worst negative slack margin remaining.

Run from inside `nix-shell` in the OpenLane2 repo root, or anywhere with
the `openlane` package importable.
"""
import csv
import itertools
import json
from pathlib import Path

from openlane.flows import Flow

Classic = Flow.factory.get("Classic")

DESIGN_DIR = Path("~/my_designs/aes_axi_wrapper").expanduser()
BASE_CONFIG = json.loads((DESIGN_DIR / "config.json").read_text())

# --- sweep space -----------------------------------------------------
CLOCK_PERIODS_NS = [4.5, 4.0, 3.5, 3.0]     # slower -> faster
CORE_DENSITIES   = [0.30, 0.40, 0.50]        # sparser -> denser
# -----------------------------------------------------------------------

results = []

for period, density in itertools.product(CLOCK_PERIODS_NS, CORE_DENSITIES):
    tag = f"sweep_p{period}_d{int(density*100)}"
    cfg = dict(BASE_CONFIG)
    cfg["CLOCK_PERIOD"] = period
    cfg["PL_TARGET_DENSITY"] = density

    print(f"\n=== Running {tag} ===")
    flow = Classic(cfg, design_dir=str(DESIGN_DIR))
    try:
        flow.start(tag=tag)
    except Exception as e:
        # A run that fails to close timing/DRC is still a DATA POINT -
        # don't let one bad config kill the whole sweep.
        print(f"  -> flow raised: {e}")

    metrics_path = DESIGN_DIR / "runs" / tag / "final" / "metrics.json"
    if not metrics_path.exists():
        print(f"  -> no metrics.json (run likely failed before signoff)")
        continue

    m = json.loads(metrics_path.read_text())
    # Keys below match OpenLane2's metrics.json naming as of this guide -
    # if a KeyError shows up, `python3 -c "import json,sys; print(list(json.load(open(sys.argv[1])).keys()))" <path>`
    # against one real metrics.json first and adjust these keys.
    row = {
        "tag": tag,
        "period_ns": period,
        "density": density,
        "wns_setup": m.get("timing__setup__ws", None),
        "wns_hold": m.get("timing__hold__ws", None),
        "die_area_um2": m.get("design__die__area", None),
        "cell_count": m.get("design__instance__count", None),
        "drc_violations": m.get("magic__drc_error__count", None),
        "lvs_errors": m.get("netgen__lvs_error__count", None),
    }
    results.append(row)
    print(f"  -> {row}")

# --- rank: timing-clean first, then smallest area, then most setup margin
def is_clean(r):
    return (
        (r["wns_setup"] or -1) >= 0
        and (r["wns_hold"] or -1) >= 0
        and (r["drc_violations"] or 1) == 0
        and (r["lvs_errors"] or 1) == 0
    )

results.sort(key=lambda r: (not is_clean(r), r["die_area_um2"] or 1e18, -(r["wns_setup"] or -1e9)))

out_csv = DESIGN_DIR / "sweep_results.csv"
with open(out_csv, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(results[0].keys()))
    w.writeheader()
    w.writerows(results)

print(f"\nRanked results written to {out_csv}")
print("Best clean point:", next((r for r in results if is_clean(r)), "NONE CLOSED - relax constraints or widen the sweep"))
```

**Notes on this script:**
- `flow.start(tag=tag)` is the same mechanism as `--run-tag` on the CLI —
  every sweep point gets its own `runs/<tag>/` directory, nothing
  overwrites anything.
- The exact `metrics.json` key names (`timing__setup__ws`, etc.) follow
  OpenLane2's dotted/dunder metric-naming convention as documented in the
  `openlane.common.metrics` API reference; **run one real flow first and
  inspect an actual `metrics.json` to confirm the exact keys** before
  trusting the sweep's ranking — metric names have changed across
  OpenLane2 versions before and may again.
- This is a *grid* search (16 runs for the space above) — for a design
  this size that's a reasonable afternoon, not a farm job. If you scale
  the sweep space up, look at OpenLane2's own support for running Steps
  standalone (`openlane.steps` API) so you're not re-running synthesis
  15 times for what's really only a placement/CTS-stage experiment (see
  §8.2 for the resume-from-a-step alternative, which is cheaper still).

### 8.2 Resuming from a specific step (cheap iteration, no sweep needed)

For the common case — "I only want to retry placement/CTS with a new
variable, synthesis hasn't changed" — don't re-run the whole flow:

```bash
openlane --last-run \
  --from OpenROAD.GlobalPlacement \
  config.json
```

`--from <Step ID>` resumes using that run's saved `state_out.json` from
the step *before* the one named, and re-runs everything from there
forward with whatever you changed in `config.json`. Pair this with
`openlane --flow ... --with-initial-state ...` (§6.2) to visually confirm
you're starting from the state you think you are before trusting a long
run to it.

### 8.3 TCL: quick WNS/TNS extraction across every corner, for a script or CI gate

Useful as a pass/fail gate in a Makefile or CI job, without needing
Python/`metrics.json` parsing:

```tcl
# extract_wns.tcl - run with: openroad -no_init -exit extract_wns.tcl
# (or invoke as an OpenLane custom step - see "Writing Custom Steps" in
#  the OpenLane2 docs if you want this wired into the flow itself rather
#  than run standalone)

set run_dir   [lindex $argv 0]
set sta_step  [glob -directory $run_dir "*-openroad-stapostpnr"]
set corners   [glob -directory $sta_step -type d "*"]

set worst_setup 1000.0
set worst_hold  1000.0

foreach corner_dir $corners {
    set wns_setup_file [file join $corner_dir "wns.max.rpt"]
    set wns_hold_file  [file join $corner_dir "wns.min.rpt"]
    if {[file exists $wns_setup_file]} {
        set f [open $wns_setup_file r]
        set content [read $f]
        close $f
        # wns.max.rpt's payload line is: "<corner_name>: <value>"
        if {[regexp {: +(-?[0-9.]+)} $content -> val]} {
            if {$val < $worst_setup} { set worst_setup $val }
        }
    }
    if {[file exists $wns_hold_file]} {
        set f [open $wns_hold_file r]
        set content [read $f]
        close $f
        if {[regexp {: +(-?[0-9.]+)} $content -> val]} {
            if {$val < $worst_hold} { set worst_hold $val }
        }
    }
}

puts "WORST SETUP SLACK ACROSS ALL CORNERS: $worst_setup"
puts "WORST HOLD SLACK ACROSS ALL CORNERS:  $worst_hold"

if {$worst_setup < 0 || $worst_hold < 0} {
    puts "TIMING NOT CLOSED"
    exit 1
} else {
    puts "TIMING CLOSED (all corners)"
    exit 0
}
```

```bash
openroad -no_init -exit extract_wns.tcl -- runs/baseline_4ns_util35
echo "exit code: $?"
```

### 8.4 Plotting the sweep (optional, if you want the visual)

```python
#!/usr/bin/env python3
"""plot_sweep.py - quick visualization of sweep_results.csv from §8.1"""
import csv
import matplotlib.pyplot as plt

rows = list(csv.DictReader(open("sweep_results.csv")))
periods = sorted(set(float(r["period_ns"]) for r in rows))
densities = sorted(set(float(r["density"]) for r in rows))

fig, ax = plt.subplots(figsize=(8, 6))
for d in densities:
    xs = [float(r["period_ns"]) for r in rows if float(r["density"]) == d]
    ys = [float(r["wns_setup"]) if r["wns_setup"] not in (None, "None") else float("nan")
          for r in rows if float(r["density"]) == d]
    pairs = sorted(zip(xs, ys))
    xs, ys = zip(*pairs)
    ax.plot(xs, ys, marker="o", label=f"density={d}")

ax.axhline(0, color="red", linestyle="--", label="closure threshold")
ax.set_xlabel("Clock period (ns)")
ax.set_ylabel("Worst setup slack (ns)")
ax.set_title("aes_axi_wrapper: setup slack vs. clock period, by placement density")
ax.legend()
ax.invert_xaxis()  # faster clocks (smaller period) to the right
plt.tight_layout()
plt.savefig("sweep_setup_slack.png", dpi=150)
print("Wrote sweep_setup_slack.png")
```

---

## 9. Signoff checklist

Before you'd call this "ready to tape out," every one of these needs to
be clean — **at every IPVT corner**, not just typical:

- [ ] **STA (`OpenROAD.STAPostPNR`)**: `summary.rpt` shows 0 setup
      violations and 0 hold violations at every corner (§6.3).
- [ ] **DRC**: both `Magic.DRC` and `KLayout.DRC` report zero violations
      (they have different blind spots — both must pass, one isn't a
      substitute for the other).
- [ ] **LVS (`Netgen.LVS`)**: `netgen-lvs.log` ends with
      `Circuits match uniquely.`
- [ ] **Antenna check (`OpenROAD.CheckAntennas`)**: zero violations after
      the repair step.
- [ ] **`checks.rpt`** (per corner): confirm zero *unconstrained paths* —
      an unconstrained path isn't a slack violation, it's a path STA
      silently didn't check at all, usually because an SDC clock/false-path
      declaration is missing. This is exactly the kind of thing our
      SDC's explicit `set_false_path -from [get_ports ARESETn]` (see the
      previous deliverable) is meant to prevent from becoming a *silent*
      gap.
- [ ] **Re-run the project's own KAT regressions** (the 6,281-vector
      encrypt/decrypt suites from the original repo) against the
      post-synthesis gate-level netlist (`final/nl/aes_axi_wrapper.nl.v`),
      not just the RTL — this is what actually confirms synthesis didn't
      change functional behavior. See §7 of the timing-closure guide's
      SDF-annotated gate-level simulation section if you want
      timing-accurate GL simulation (Icarus doesn't support SDF
      annotation; the docs point to `CVC` as the open-source option that
      does).

---

## 10. Design-specific notes for this AES core

- **Single clock domain.** OpenLane2's `Classic` flow assumes one clock
  domain unless you tell it otherwise — this matches our wrapper's own
  design decision (ACLK drives the core too, see the previous
  deliverable's `docs/README.md` §4). If you later integrate this into an
  SoC where the core runs on a different clock than the AXI fabric, that
  integration needs its own CDC-aware constraints on top of everything
  here — don't assume this guide's single-clock config still applies
  once a register slice/CDC bridge is added upstream.
- **The key-sync fix's accept-time comparison
  (`key_gen == bank_gen_flat[current_bank]`, in `aes_top.sv`) is ordinary
  combinational logic feeding a registered accept decision** — it needs
  no special SDC treatment, and you should expect it to show up as a
  perfectly normal reg-to-reg path in the STA reports, not as an
  unconstrained or exception path. If it *does* show up as unconstrained,
  that's a real problem worth chasing down, not something to false-path
  away.
- **Pin count.** AXI4-Lite (address/data/resp × read+write) + two
  AXI4-Stream interfaces is a lot of top-level pins for a block this
  size — if floorplanning struggles to place them without congestion,
  revisit `FP_ASPECT_RATIO` and consider a custom `FP_PIN_ORDER_CFG` (see
  the pin-placement example in OpenLane2's Newcomers guide) to group
  related signals (all of `S_AXI_*` on one edge, `S_AXIS_*`/`M_AXIS_*` on
  another) rather than leaving pin placement to the default algorithm.

---

## 11. Quick command reference

```bash
# Enter the environment
nix-shell --pure ~/openlane2/shell.nix

# Run the flow
openlane ~/my_designs/aes_axi_wrapper/config.json

# Run with a memorable tag, quieter output
openlane --run-tag my_experiment --log-level ERROR --condensed --show-progress-bar config.json

# View final layout
openlane --last-run --flow openinklayout config.json
openlane --last-run --flow openinopenroad config.json

# View an intermediate state
openlane --last-run --flow openinklayout config.json --with-initial-state <path/to/state_out.json>

# Resume from a specific step (cheap iteration)
openlane --last-run --from OpenROAD.GlobalPlacement config.json

# Smoke test (sanity-check the install itself)
openlane --smoke-test

# Docker users: prefix every invocation above with --dockerized, e.g.
openlane --dockerized ~/my_designs/aes_axi_wrapper/config.json
```

**Where to look after every run, in order:**
1. `runs/<tag>/final/metrics.json` — the scoreboard
2. `runs/<tag>/<N>-openroad-stapostpnr/summary.rpt` — timing, every corner
3. Whichever per-stage `*.rpt` the summary points you toward (§6.3)
4. `runs/<tag>/error.log` / `warning.log` if the run didn't complete

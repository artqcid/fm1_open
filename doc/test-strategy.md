---
title: Test Strategy
description: What can actually be verified in FM1 Open today — no unit-test harness, no CI; the web build is the smoke check.
status: active
stale_after: 2027-04-19
---

# Test Strategy

## Honest baseline (as of 2026-10-19)

- **No unit-test harness** exists in this repository: no `test/` tree, no
  ctest/gtest/unity, no CI configuration, no coverage tooling.
- **No CI.** Verification is whatever the developer (or agent) runs locally.
- The engine is **binary-only**, so most of its behaviour cannot be tested
  from source — only exercised through the public header contract.

Therefore the strategy below is deliberately modest: it says what *is*
verifiable, and does not pretend there is more.

## Level 1 — Build gates (always available, mandatory)

Run these after every code-touching task:

~~~powershell
.\build.bat --web
Test-Path .\build\preview\index.html     # must be True
~~~

The **web build is the smoke test**: it compiles `web/` + `web/synth/` +
`web/engine/` C sources to WASM, so syntax, type, header and linkage breakage
in the shared engine sources shows up here without any hardware or cross
toolchain.

`tools\Build-Web.ps1` also enforces consistency checks that double as
regression gates: firmware/web release version agreement, `build_id` format,
no unexpanded `/*FM1_...*/` placeholders, `THIRD_PARTY.md` header check.

## Level 2 — Firmware build gates (needs toolchain + `FM1_SOURCE_URL`)

~~~powershell
$env:FM1_SOURCE_URL      = 'https://github.com/m-vave/fm1_open'
$env:FM1_PI32_TOOLCHAIN  = 'C:\JL\pi32-2.5.2\C$\JL\pi32'   # hash-pinned 2.5.2 (BUG-002)
# both are also set as persistent user-level environment variables
.\build.bat --package
Test-Path .\build\dx7\generated\FM1_OFFICIAL_OPEN.fwsc   # must be True
~~~

`sdk\Build.ps1` performs a long list of **invariants** that act as a static
test suite (see `doc/build-workflow.md`): audio callback and panel tables in
internal SRAM, fixed identity sizes, no stubbed Bluetooth discovery, link-map
audits, heap/ACL pool minimums, startup matching the ROM entry.

**Status in this workspace: green** (2026-10-19) — `FM1_SOURCE_URL` and the
hash-pinned `FM1_PI32_TOOLCHAIN` (JieLi 2.5.2, BUG-002) are configured, so
`.\build.bat --package` produces `build/dx7/generated/FM1_OFFICIAL_OPEN.fwsc`
plus the complete workbench. See [`./build-workflow.md`](./build-workflow.md).

## Level 3 — On-device acceptance protocol (manual, scripted)

Not automated — run on real hardware after any change that can be heard, felt
or persisted. Tick every box; **any fail becomes a `BUG-<n>` entry in
[`./bugs.md`](./bugs.md) (ledger rules: full record only there).** Record the
observed values in the notes column instead of "looks fine".

Run `.\build.bat --package` and flash/install first; note the build id.

| # | Check | Pass | Notes |
| --- | --- | --- | --- |
| 1 | Power-on → splash → home screen; no boot loop | ☐ | |
| 2 | Load the factory demo project; 8 tracks audible, pattern plays at the set tempo | ☐ | |
| 3 | Every track source type produces sound (DX7, 303, 808, PSG, PLUCK, SAMPLE, …) — switch source per track and play a note | ☐ | |
| 4 | Sequencer + arpeggiator: start/stop, step edit, lock/alt tuning audible | ☐ | |
| 5 | Save project, power-cycle, reload — project identical (steps, sources, levels) | ☐ | |
| 6 | Sample bank: write a bank, rebind, play back, verify CRC/status (`groove_samples_status`) | ☐ | |
| 7 | USB audio out **and** Bluetooth audio out independently; both mixed if simultaneous; no clipping/DC | ☐ | |
| 8 | MIDI in → notes sound; MIDI out echoes; USB MIDI + BLE MIDI each work | ☐ | |
| 9 | BLE role switch (Peripheral ↔ Central), scan list, connect/disconnect, forget bonds — async codes as documented | ☐ | |
| 10 | Tuning API: capture/apply tables for all 8 tracks, save, power-cycle, re-apply | ☐ | |
| 11 | Firmware update round-trip with the web workbench (`build/official-web/…`) | ☐ | |
| 12 | Timing health: `fm1_audio_stats.overruns == 0` and `fm1_engine_stats.underruns == 0` after ≥ 5 min of playback under load | ☐ | |
| 13 | Display/UI: every page reachable (OVERVIEW, STEPS, FM_EDIT, MIX, EFFECTS, PROJECT), no stuck screens | ☐ | |

Product safety (always, both for testers and for shipped docs): **back up
projects and samples, and keep the device powered during saves and firmware
updates.**

## Level 4 — Boundary/packaging checks (cheap, automated)

- `pwsh doc/lint.ps1` — wiki consistency (orphans, duplicates, stale claims,
  contradictions). Exit 0 = clean, 1 = warnings, 2 = errors.
- `git status --short` — no stray artifacts in the repo root or under
  `app/`, `web/`, `sdk/` (AGENTS.md scratch-compilation rule).
- `git diff --stat main...main-feature` — the change set contains only what
  the task intended.

## Possible future work (not started)

- `FM1_HOST_TEST` in `sdk/include/fm1.h` already compiles `FM1_AUDIO_CODE` /
  `FM1_AUDIO_DATA` away — a plausible entry point for host-side checks of APP
  logic. Explore only with an explicit task (see `doc/checklist.md`).
- A WASM harness driving `sdk/Simulator.js` (`sim_*` exports) for sequencer /
  tuning behaviour without hardware.

Record decisions about this in `doc/checklist.md` and `doc/log.md`.

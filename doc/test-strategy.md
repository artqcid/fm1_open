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
$env:FM1_SOURCE_URL      = '...'
$env:FM1_PI32_TOOLCHAIN  = 'C:\JL\pi32'
.\build.bat --package
Test-Path .\build\dx7\generated\FM1_OFFICIAL_OPEN.fwsc   # must be True
~~~

`sdk\Build.ps1` performs a long list of **invariants** that act as a static
test suite (see `doc/build-workflow.md`): audio callback and panel tables in
internal SRAM, fixed identity sizes, no stubbed Bluetooth discovery, link-map
audits, heap/ACL pool minimums, startup matching the ROM entry.

**Status in this workspace:** pending — `FM1_SOURCE_URL` and
`FM1_PI32_TOOLCHAIN` are not configured. Never report this level as green.

## Level 3 — Runtime evidence on hardware

Not automated; performed manually on the device:

- Timing health: read `struct fm1_audio_stats` (`blocks`, `short_intervals`,
  `overruns`, `peak_ticks`) and `struct fm1_engine_stats` (`submitted`,
  `completed`, `underruns`, `midi_dropped`) — nonzero `overruns`/`underruns`
  means the render budget regressed.
- Regression probes: USB/BT mixing audible and non-clipping, recording
  captures what is played, MIDI in/out and BLE role changes behave per the
  documented async codes.
- Persistence: save a project and a sample bank, power-cycle, reload;
  Flash-adjacent changes must prove the upgrade path still works
  (`tuning_upgrade`).
- Product safety warnings stay in the docs: back up projects and samples,
  keep the device powered during saves and firmware updates.

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

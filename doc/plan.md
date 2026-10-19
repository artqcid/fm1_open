---
title: Implementation Plan (Roadmap)
description: Tier-1 roadmap — decisions, risks and the ordered task groups (A–F) derived from the 2026-10-19 project review. Status lives in doc/checklist.md.
status: active
stale_after: 2027-04-19
---

# Implementation Plan — Roadmap

Tier-1 planning tier (borrowed from `artqcid/wogd-ddsp-trainer`, see
[./reference-wogd-ddsp-trainer.md](./reference-wogd-ddsp-trainer.md)). **This
page holds decisions, risks and grouping only.** The live status of every task
is in [./checklist.md](./checklist.md) — task IDs (`T-nn`) are permanent there.

Origin: the 2026-10-19 project review (efficiency, dev environment, build
process, agent rules, docs, code) produced the task list below. The review
itself is not duplicated here; this page turns it into an executable,
dependency-ordered plan.

## How to work this plan

1. Tasks are worked in **group order A → F** unless a dependency says
   otherwise (see [Dependencies](#dependencies)).
2. Every task follows the normal workflow in `AGENTS.md`: todo-first, plan
   approval, one small subagent task per step, primary agent builds and
   verifies.
3. Doku-only edits under `doc/` may be done by the primary agent directly
   (AGENTS.md exception); code edits are delegated to subagents.
4. On completion: update the `T-nn` row in [./checklist.md](./checklist.md),
   append to [./log.md](./log.md), run `pwsh doc/lint.ps1`.
5. **Branch target:** all tasks are implemented on `main-feature` except
   **T-28 and T-31**, which are **upstream-bound**: base them on `main`, merge
   them into local `main`, and submit a PR to `m-vave/fm1_open`; propagate to
   `main-feature` afterwards. Never mix other work into `main`.
6. **Effective order of the open tasks:** bookkeeping (T-15/T-21) → T-31 →
   T-32 → T-40 → T-23 → T-29 → T-30 → T-24 (hardware) → T-28 (last; needs
   ARCHITECT/BUILD and Group E).

## Group A — Quick wins (≤ 30 min each, low risk)

| ID | Task | Scope | DoD |
| --- | --- | --- | --- |
| T-26 | Fix stale prose: `doc/test-strategy.md` Level-2 still says "pending" though both build gates are green since 2026-10-19 | doc | Status text matches `doc/build-workflow.md`; no contradiction |
| T-05 | Resolve the NotebookLM notebook ID for **WOGD-FM1 Firmware** via the `nbml-list` skill; write it into `AGENTS.md` (currently `TBD`) | tooling | Real UUID in `AGENTS.md` |
| T-06 | First Knowledge-Sync: push a `doc/log.md` digest into the WOGD-FM1 Firmware notebook | tooling | Digest note visible in notebook |
| T-25 | Remove the stale machine-wide `LIB` entry (deleted VS 18 preview path) from the user environment | env | `build.ps1` `LIB` workaround no longer required (kept anyway) |
| T-33 | `app/audio_output.c` line 37: document *why* the Bluetooth gain uses `output_gain * 2` while USB uses `>> 7` (16-bit vs Q23 scaling) | code | Comment explains the scaling asymmetry |

## Group B — Tooling & dev environment (< 2 h each)

| ID | Task | Scope | DoD |
| --- | --- | --- | --- |
| T-34 | Add a committed `.env.example` listing `FM1_SOURCE_URL`, `FM1_PI32_TOOLCHAIN`, `FM1_WASI_SDK`; reference it in `README.md` | tooling | New file + README pointer; `.env` stays gitignored |
| T-38 | Set `FM1_WASI_SDK` in `.vscode/build.ps1` so the 518 MiB web-SDK download happens once and lives outside the gitignored `build/` tree (closes T-13) | tooling | Web build re-uses an external WASI SDK 27 |
| T-35 | Add a `problemMatcher` to the FM1 VS Code tasks so JieLi-clang diagnostics appear in the Problems panel | tooling | Compiler errors arrive as VS Code problems |
| T-36 | Execute T-21: synchronise the `README.md` task table with `.vscode/tasks.json` (currently 3 tasks) instead of keeping it only as a rule | doc/tooling | README task table matches `tasks.json` |
| T-37 | Trim the `AGENTS.md` "Quick facts" block to the minimum and delegate detail to `doc/index.md` (removes duplicated drift surface) | agents | Quick facts no longer duplicate the wiki |
| T-27 | Add `tools/check-repo.ps1` — an automated Level-4 hygiene check (stray compiler artifacts under root/`app`/`web`/`sdk`, `build/` is gitignored, `.gitattributes` present) wired as a VS Code task | tooling | One command reproduces the manual Level-4 checks |

## Group C — RAG / code index (new, medium)

| ID | Task | Scope | DoD |
| --- | --- | --- | --- |
| T-39 | Build `tools/generate-code-index.ps1` + generated `doc/code_index.md` | tooling | Index regenerates from the APP/web sources; linked from `doc/index.md` |

**Decision — yes, a code index is worth building (2026-10-19 review).**

- **What:** a PowerShell script that extracts function signatures, named
  constants (`enum`/`#define`), struct layouts and file-level purpose comments
  from `app/*.c`, `app/board/*.c`, `app/instrument.h` and `web/engine/*.c` into
  a single generated Markdown file `doc/code_index.md`.
- **Why:** the price of navigation is dominated by a few large files —
  `app/screen.c` (≈ 2 900 lines), `web/engine/sound.c` (≈ 82 KB),
  `app/project.c` (744 lines). Grep-ing a generated symbol index is far cheaper
  in context than reading those files, and it is the single biggest lever for
  faster agent work on this repo.
- **What it is NOT:** it never replaces reading the real file — it is a *finder*.
  The **binary engine** (`sdk/lib/libfm1_engine.a`) has no source and is
  therefore **out of scope**: the index only describes open APP/web symbols.
- **Tooling choice:** PowerShell only — **no Python, no git hook** (unlike the
  sibling). The sibling's Python `sync-wiki.py` + post-commit hook was
  explicitly rejected for this repo (`reference-wogd-ddsp-trainer.md` §Not
  applicable) because there is no Python runtime here. Regeneration is manual
  (`pwsh tools/generate-code-index.ps1`) or part of the Post-Task Sync when
  APP/web sources changed.
- **Marker:** mark `doc/code_index.md` as generated in its frontmatter and in
  `doc/index.md` so nobody hand-edits it and `doc/lint.ps1` expectations stay
  clear.

## Group D — Code quality (1–3 h each, low/medium)

| ID | Task | Scope | DoD |
| --- | --- | --- | --- |
| T-31 | Replace the bare-metal register addresses in `app/board/audio.c` (`0x51030`, `0x10014`) with named constants in `app/board/fm1_audio.h` — **upstream-bound (`main`), PR: pending** | code | No magic I/O addresses without a symbolic name |
| T-32 | Rename the file-local `crc32()` in `app/samples.c` to `samples_crc32()` (namespace hygiene; the public symbol is `groove_crc32`) | code | No unprefixed file-local symbols |
| T-40 | Decide BUG-001's fate: open a minimal upstream PR (make `build.bat` prefer `pwsh` with a `powershell.exe` fallback) **or** mark it `wont-fix` with a reason — **done 2026-10-20: fixed locally on `main-feature`** | decision | `doc/bugs.md` BUG-001 status reflects the decision |

## Group E — Automated testing (large, 4–8 h each)

No unit-test harness exists today (see [./test-strategy.md](./test-strategy.md)).
These two tasks create the *first* real automated coverage that does not need
hardware.

| ID | Task | Scope | DoD |
| --- | --- | --- | --- |
| T-29 | Activate a host-side C harness via the existing `FM1_HOST_TEST` switch (builds `FM1_AUDIO_CODE`/`FM1_AUDIO_DATA` as no-ops) and cover pure APP logic | testing | Host build + checks for `project.c`/`samples.c` run green from the scratch dir |
| T-30 | Build a lightweight Node.js WASM harness driving the `sim_*` exports of `sdk/Simulator.js` | testing | Script asserts boundary rejects + sequencer/tuning behaviour against the WASM build |

**T-29 detail.** `FM1_HOST_TEST` already exists in `sdk/include/fm1.h`; it
compiles the audio section attributes away. A host compiler (MSVC `cl` or
clang-cl) builds `app/project.c` + `app/samples.c` against `fm1_flash_*` /
engine stubs. First checks: CRC-32 known vectors, project header magic +
`checksum()` round-trip, legacy→V13 upgrade path, tuning capture/apply
validation (`-128` rejection, all-or-nothing). **No new test framework** — a
plain `main()` returning non-zero on failure is enough. All artifacts go to
`%TEMP%\opencode` (AGENTS.md scratch rule).

**T-30 detail.** `build/preview` already contains the WASM build; `sdk/
Simulator.js` exports `sim_*`. A single Node script (no npm dependencies) loads
the build and asserts: wrong-length MIDI/patch/sample inputs are rejected
(the documented boundary checks), `sim_*` init succeeds, and a sequencer/tuning
edit is observable through the read-back exports. This is the only
**behaviour**-level automated check available without hardware; syntax-only
coverage is what `build.bat --web` already gives.

## Group F — Large refactor (≥ 1 day)

| ID | Task | Scope | DoD |
| --- | --- | --- | --- |
| T-28 | Split `app/screen.c` (≈ 2 900 lines, 19 pages) into per-page units behind a shared header — **upstream-bound (`main`), PR: pending** | code/arch | Both builds green; page count unchanged; no behaviour change |

**T-28 detail (architectural — confirm with ARCHITECT/BUILD before starting).**

- New `app/screen_common.h` owns the shared state (`track`, `page`, `cursor`,
  `op`, the paint API, colour constants, the `font`/`algorithm` tables, the
  glyph primitives `text`/`number`/`line`/`fill`).
- New units: `screen_overview.c`, `screen_steps.c`,
  `screen_fm.c` (FM_EDIT + FM_ENV + FM_LFO + FM_QUICK),
  `screen_mix.c`, `screen_effects.c`, `screen_project.c`, `screen_ble.c`,
  `screen_edit.c` (STEP_EDIT + RHYTHM + ACTIONS + ARP_EDIT),
  `screen_browser.c` (PRESET_BROWSER).
- `screen.c` shrinks to a dispatcher: `draw_page_body()` routes to per-page draw
  functions; the shared `groove_screen_control()` input state machine stays.
- **Must not change behaviour.** Verification: `.\build.bat --web` and
  `.\build.bat --package` both green; on-device Level-3 protocol (T-24) after
  the split.
- **Branch:** upstream-bound — base on `main` and submit a PR to
  `m-vave/fm1_open`; do not develop it on `main-feature`.
- **Sequencing:** do this **after** T-39 (the code index makes the split safe
  to delegate to subagents) and **after** Group E, so the new harness covers
  the moved logic.

## Dependencies

- T-06 (Knowledge-Sync) **needs** T-05 (notebook ID).
- T-28 (screen split) **needs** T-39 (code index) and should follow Group E.
- T-38 closes T-13; T-36 executes T-21.
- Everything else is independent and can be parallelised as separate sessions.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| `screen.c` split introduces a subtle behaviour change | UI/audio regression | Both builds green + Level-3 on-device protocol (T-24) after the split; split by page, commit per page |
| Host harness (T-29) diverges from device behaviour | False confidence | Keep it to *pure* logic (CRC, layout, validation), never DSP/timing; document the boundary in `test-strategy.md` |
| WASM harness (T-30) coupled to a generated build path | Brittle test | Assert only documented boundary contracts (`sim_*`), not internals |
| Code index goes stale | Misleading nav | Marked *generated*; regenerate in Post-Task Sync on source change |
| Upstream PR (T-40) rejected / ignored | Workaround kept | `wont-fix` fallback with the reason recorded in BUG-001 |

## Explicitly out of scope

- A Python/RAG pipeline or post-commit hook (no Python runtime; rejected in the
  sibling study).
- CI (no CI runtime; the build gates are the tests — see `test-strategy.md`).
- Changes to the binary engine (`sdk/lib/libfm1_engine.a`) — not modifiable.
- `clean-*` task variants, installer pipeline, format-on-save (rejected in the
  sibling study).

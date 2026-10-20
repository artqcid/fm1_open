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
   tasks explicitly tagged **upstream-bound** (currently **T-31**; T-28 was
   upstream-bound but was rejected). *Upstream-bound is a per-task tag, not a
   fixed list*: any small fix or change that should become a PR to
   `m-vave/fm1_open` is tagged so, based on `main`, merged into local `main`,
   and submitted from an `origin` topic branch (`feature/upstream-<name>`);
   propagate to `main-feature` afterwards. Never mix other work into `main`.
   Full procedure: [./branch-workflow.md](./branch-workflow.md).
6. **Effective order of the open tasks:** bookkeeping (T-15/T-21) → T-31 →
   T-32 → T-40 → T-23 → T-29 → T-30 (done) → T-24 (hardware). T-28 was
   rejected (flash budget); T-41 is an optional, size-neutral refactoring.

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
| T-31 | Replace the bare-metal register addresses in `app/board/audio.c` (`0x51030`, `0x10014`) with named constants in `app/board/fm1_audio.h` — **upstream-bound (`main`), PR #7 open (2026-10-20)** | code | No magic I/O addresses without a symbolic name |
| T-32 | Rename the file-local `crc32()` in `app/samples.c` to `samples_crc32()` (namespace hygiene; the public symbol is `groove_crc32`) — **done 2026-10-20** | code | No unprefixed file-local symbols |
| T-40 | Decide BUG-001's fate: open a minimal upstream PR (make `build.bat` prefer `pwsh` with a `powershell.exe` fallback) **or** mark it `wont-fix` with a reason — **done 2026-10-20: fixed locally on `main-feature`** | decision | `doc/bugs.md` BUG-001 status reflects the decision |

## Group E — Automated testing (large, 4–8 h each)

No unit-test harness exists today (see [./test-strategy.md](./test-strategy.md)).
These two tasks create the *first* real automated coverage that does not need
hardware.

| ID | Task | Scope | DoD |
| --- | --- | --- | --- |
| T-29 | Activate a host-side C harness via the existing `FM1_HOST_TEST` switch (builds `FM1_AUDIO_CODE`/`FM1_AUDIO_DATA` as no-ops) and cover pure APP logic — **done 2026-10-20** (`tests/host/run.ps1`) | testing | Host build + checks for `project.c`/`samples.c` run green from the scratch dir |
| T-30 | Build a lightweight Node.js WASM harness driving the `sim_*` exports of `sdk/Simulator.js` - **done 2026-10-20** (`tests/wasm/fm1_wasm_test.mjs`) | testing | Script asserts boundary rejects + sequencer/tuning behaviour against the WASM build |

**T-29 detail.** `FM1_HOST_TEST` already exists in `sdk/include/fm1.h`; it
compiles the audio section attributes away. A host compiler (MSVC `cl` or
clang-cl) builds `app/project.c` + `app/samples.c` against `fm1_flash_*` /
engine stubs. First checks: CRC-32 known vectors, project header magic +
`checksum()` round-trip, legacy→V13 upgrade path, tuning capture/apply
validation (`-128` rejection, all-or-nothing). **No new test framework** — a
plain `main()` returning non-zero on failure is enough. All artifacts go to
`%TEMP%\opencode` (AGENTS.md scratch rule).

**T-30 detail.** `build.bat --web` emits `build/web/simulator.wasm`; `sdk/
Simulator.js` exposes `FM1SimulatorCore` and returns before the browser UI
boots when `document` is undefined. A single Node script (no npm dependencies)
loads the build and asserts: wrong-length MIDI/patch/sample inputs are rejected
(the documented boundary checks), `sim_*` init succeeds, and a sequencer/tuning
edit is observable through the read-back exports. Run
`node tests/wasm/fm1_wasm_test.mjs` after `.\build.bat --web`. This is the only
**behaviour**-level automated check available without hardware; syntax-only
coverage is what `build.bat --web` already gives.

## Group F — Large refactor (≥ 1 day)

| ID | Task | Scope | DoD |
| --- | --- | --- | --- |
| T-28 | ~~Split `app/screen.c` (≈ 2 900 lines, 19 pages) into per-page translation units behind a shared header~~ — **REJECTED 2026-10-20** (flash budget) | code/arch | — (closed; record in [`doc/screen-split-plan.md`](./screen-split-plan.md)) |
| T-41 | *Optional:* byte-neutral refactoring of `app/screen.c` into `#include` fragments (see below) | code/arch | App image stays at the pre-change byte count; both builds + both harnesses green; no behaviour change |

### T-28 — rejected

The three-layer split into 11 translation units with `extern` shared state was
implemented up to step 6 and measured: the app image grew from 453 736 B to
457 544 B against a hard limit of 453 921 B (185 B headroom). The overhead is
caused by losing internal linkage (static globals can no longer be merged into
one base-register block, single-use functions are no longer inlined, every
cross-symbol access is a 6-byte absolute address), **not** by the file
separation — a monolith with merely `static` stripped yields the same size. The
build-time argument does not apply (`Build.ps1` always rebuilds everything,
≈ 7 s) and the navigation argument is covered by `doc/code_index.md`. Evidence
and table: [`doc/screen-split-plan.md`](./screen-split-plan.md#outcome-2026-10-20).
The `feature/upstream-screen-split` branch was deleted.

### Option: byte-neutral screen refactoring (T-41)

**Status: optional, not scheduled.** Only worth doing if the readability of
`app/screen.c` (2 994 lines) becomes a concrete maintenance cost. It is the only
refactoring shape that is compatible with the flash budget, and it is
generalisable to other large files (`web/engine/sound.c`, `app/project.c`).

**Principle — one translation unit, many files.** The code is moved verbatim
into `#include`d fragments; the compiler sees (almost) the same translation unit
as before.

- Fragments live next to the main file with the extension **`.inc`**
  (`app/screen_gfx.inc`, `app/screen_seq.inc`, …). `Build.ps1` only compiles
  `.c`/`.S`, so fragments never become their own object; `Build-Web.ps1`
  already tracks `.inc` as a build input; the build identity hashes every file
  under `app/`.
- `app/screen.c` stays the only translation unit and `#include`s the fragments
  in dependency order. It keeps the shared state definitions.
- **Every file-scope symbol stays `static`** (functions and variables). No new
  `extern` declarations, no `screen_internal.h`/`screen_page.h`, no renames, no
  prefix table, no new public API, no new header contracts.
- **`sdk/Build.ps1`, `sdk/manifest.json` and all compiler flags stay
  untouched** (the hash pin and the `app/screen.c` flag matches keep working
  because the unit name does not change).
- Moves are verbatim: no logic edits, no reformatting, no macro replacement for
  functions (e.g. keep `clamp()` a function).
- Measured proof of concept (2026-10-20, scratch copy): moving a 214-line block
  into a `.inc` fragment gave exactly 453 736 B, identical to the baseline.

**Cut order (cheapest/safest first; stop whenever the gain is enough):**

1. Browser-simulator adapter (`groove_screen_web_*`, `web_targets[]`,
   ≈ lines 2702–2915, wrapped in `#ifdef FM1_HOST_TEST` — move the whole
   `#ifdef … #endif` block).
2. Pixel layer (`font[]`, `punctuation[]`, paint state, fill/text/line/number/
   decimal/knob helpers).
3. Page draw groups in file order: overview + LED matrix, sequencer, FM/DX7 +
   tone, mix, effects, BLE, project/preset/name/boot, edit overlays.
4. Input state machine (`apply_controls`, ≈ 720 lines) — last, highest risk.
   Fragment order must respect `static` forward-declaration needs; add
   forward declarations at the top of `screen.c` if the include order demands
   it.

**Gate for every step (mandatory, one commit per fragment):**

1. `pwsh sdk\Build.ps1 -FirmwareOnly` (via `.\build.bat`): the printed
   `FM1: <n> bytes app image` **must equal the pre-change number**; tolerance
   ±16 B only if explained (e.g. different ordering of inlining), otherwise
   revert the step. Never accept a step that eats headroom
   ([flash budget](./build-workflow.md#flash-budget)).
2. `.\build.bat --web` green; `node tests\wasm\fm1_wasm_test.mjs` and
   `pwsh tests\host\run.ps1` green.
3. `tools/generate-code-index.ps1`: extend its source globs to also read
   `app/*.inc` (otherwise the index loses the moved symbols), regenerate
   `doc/code_index.md`, `pwsh doc/lint.ps1` clean.
4. After the last fragment: Level-3 on-device protocol (T-24) once.

**Expected benefit / non-goals.** Benefit: smaller files, a page can be found
and edited without scrolling through unrelated code, per-fragment git history.
Non-goals: separate translation units, reusable `screen_gfx` library for custom
firmware, encapsulation of the shared UI state, faster builds. Those would need
internal linkage to be dropped, which the flash budget does not allow.

**Branch:** `main-feature` / `feature/screen-fragments` (not upstream-bound by
default). It may be tagged upstream-bound later if a PR is wanted; then it must
be cut from `main` per the branch workflow.

## Dependencies

- T-06 (Knowledge-Sync) **needs** T-05 (notebook ID).
- T-41 (optional fragment refactoring) **needs** T-39 (code index, glob must be
  extended to `.inc`) and Group E (T-29/T-30 harnesses). T-28 is rejected.
- T-38 closes T-13; T-36 executes T-21.
- Everything else is independent and can be parallelised as separate sessions.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| App image exceeds the flash limit (453 921 B, 185 B headroom on V14) | `--package` fails; blocks every `app/` change | Check `app_image_bytes` on every firmware task; byte-exact gate for T-41; see [flash budget](./build-workflow.md#flash-budget) |
| `screen.c` fragment refactoring (T-41) introduces a subtle behaviour change | UI regression | Verbatim moves only, one fragment per commit, byte-exact size gate, both harnesses + Level-3 on-device protocol (T-24) after the last fragment |
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

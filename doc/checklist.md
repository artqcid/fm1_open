---
title: FM1 Open Checklist
description: Open tasks with short descriptions. Newest state of the workspace backlog.
updated: 2026-10-20
---

# FM1 Open — Checklist

Short descriptions only. Keep entries small; expand into a `doc/*.md` page or a
git issue when a task grows. Newest first inside each section.

Grouping, rationale, dependencies and risks for the tasks below live in the
**Tier-1 roadmap** [`./plan.md`](./plan.md); this file is the live status only.
The `plan.md` groups A–F and the sections below reference the same `T-nn` IDs.

Legend: `[ ]` open · `[~]` in progress / `[x]` done.
**Task IDs (`T-nn`) are permanent** — assign the next free number in
`next-free:` below, never reuse or renumber an ID. A deferred item is marked
`**Moved to …**` instead of being silently deleted (convention borrowed from
`artqcid/wogd-ddsp-trainer`, see
[./reference-wogd-ddsp-trainer.md](./reference-wogd-ddsp-trainer.md)).

**Branch targets:** all tasks are implemented on `main-feature` (or a
`feature/*` branch cut from it) **except tasks tagged upstream-bound**
(currently **T-31**). Upstream-bound is a per-task tag: base such a task on
`main`, merge it into local `main`, and submit it as a PR to
`m-vave/fm1_open` from an `origin` topic branch; propagate to `main-feature`
afterwards (see [./branch-workflow.md](./branch-workflow.md)). New small
fixes/changes intended for upstream get their own `T-nn` with this tag. PR
status is `PR: pending` until upstream accepts or rejects the PR.

next-free: **T-42**

## Documentation & workspace

- [x] **T-01** `AGENTS.md` with workflow, subagent rules, Definition of Done.
- [x] **T-02** `doc/` wiki: index, log, checklist, lint, coding-standards,
      build-workflow, architecture, licensing, branch-workflow, test-strategy.
- [x] **T-03** `.editorconfig` + `.vscode/` tasks.
- [x] **T-04** `fm1_open.code-workspace`, project-level `opencode.json`
      (`notebooklm_devblogs` MCP).
- [x] **T-05** Resolve the NotebookLM notebook ID for **WOGD-FM1 Firmware** via
      the `nbml-list` skill once the MCP server is running; write it into
      `AGENTS.md`. **Done 2026-10-19** — ID `a85eb2ec-cfaa-4f10-bb74-a1732bfae75c`.
      The 400 was a corrupted `auth.json` (`csrf_token` == `session_id`); the
      reauth script's CSRF extraction was fixed. *(plan.md A)*
- [x] **T-06** First Knowledge-Sync run: push a `doc/log.md` digest to the
      notebook. **Done 2026-10-19** — digest source
      `a541f9df-d04d-4de5-94ac-bce34a8e2df7` in WOGD-FM1 Firmware. *(plan.md A)*
- [x] **T-07** First `pwsh doc/lint.ps1` run: **OK, 9 pages, exit 0** (2026-10-19).
- [x] **T-26** Fix stale prose: `doc/test-strategy.md` Level-2 still says
      "pending" though both build gates are green since 2026-10-19. **Done
      2026-10-19** — status now green. *(plan.md A)*
- [x] **T-36** Execute T-21 for real: synchronise the documented task table
      with `.vscode/tasks.json`. **Done 2026-10-19** — README has no task
      table, so the canonical table in `doc/build-workflow.md` was updated
      instead (adds `fm1:check-repo`). *(plan.md B, executes T-21)*
- [x] **T-37** Trim the `AGENTS.md` "Quick facts" block to the minimum and
      delegate detail to `doc/index.md`. **Done 2026-10-19.** *(plan.md B)*
- [x] **T-19** **Consider when the backlog grows:** add a `doc/plan.md`
      roadmap tier. **Done 2026-10-19** — `doc/plan.md` created (Tier-1;
      groups A–F, decisions, risks). *(plan.md preamble)*
- [x] **T-23** Work through the `## Action items` table in `doc/licensing.md`
      (7 rows, all `open` except PR #2) and update statuses as each is verified.
      **Done 2026-10-20** — all seven `verified` against V14 (`4d26685`);
      `cfg_tool.bin` is byte-identical to the official AC79 SDK file.

## Build & environment

- [x] **T-08** Set `FM1_SOURCE_URL` — `https://github.com/m-vave/fm1_open`
      (user-level env var, baked into the VS Code tasks), 2026-10-19.
- [x] **T-09** Set `FM1_PI32_TOOLCHAIN` — hash-pinned **JieLi 2.5.2** extracted
      to `C:\JL\pi32-2.5.2\C$\JL\pi32` (see BUG-002), 2026-10-19.
- [x] **T-10** `.\build.bat --web` green → `build/preview/index.html` (883 KB),
      2026-10-19.
- [x] **T-11** `.\build.bat --package` green → `FM1_OFFICIAL_OPEN.fwsc`,
      2026-10-19.
- [x] **T-12** `sdk/manifest.json` → `external_toolchain` **22/22** hashes match
      the in-use 2.5.2 toolchain (BUG-002), 2026-10-19.
- [x] **T-13** Optional: set `FM1_WASI_SDK` to an extracted WASI SDK 27 to avoid
      the 518 MiB first-time download. **Done 2026-10-19 via T-38** — SDK
      moved to `C:\wasi-sdk-27` and exported as a User env var.
      *(executed by T-38)*
- [x] **T-14** Confirm toolchain availability and record it in
      `doc/build-workflow.md` — done 2026-10-19 (22/22 manifest hashes).
- [x] **T-25** Optional machine cleanup: the system-wide `LIB` environment
      variable still lists a deleted Visual Studio 18 preview path
      (`…\MSVC\14.50.35717\lib\x64`). **Done 2026-10-19** — the Machine value
      now points at MSVC 14.51 + Windows SDK (UAC-elevated); the User-level
      override is superseded. *(plan.md A)*
- [x] **T-34** Add a committed `.env.example` (FM1_SOURCE_URL,
      FM1_PI32_TOOLCHAIN, FM1_WASI_SDK) and reference it from `README.md`;
      `.env` stays gitignored. **Done 2026-10-19** (`.gitignore` exception
      `!.env.example`). *(plan.md B)*
- [x] **T-35** Add a `problemMatcher` to the FM1 VS Code tasks so JieLi-clang
      diagnostics show in the Problems panel. **Done 2026-10-19** (`$gcc` on
      both build tasks). *(plan.md B)*
- [x] **T-38** Set `FM1_WASI_SDK` in `.vscode/build.ps1` (closes T-13).
      **Done 2026-10-19** — points at `C:\wasi-sdk-27`. *(plan.md B)*
- [x] **T-27** Add `tools/check-repo.ps1` — automated Level-4 hygiene check
      (stray artifacts, `build/` gitignored, `.gitattributes` present) + a
      VS Code task. **Done 2026-10-19** — green, wired as `fm1:check-repo`.
      *(plan.md B)*

## Engineering (code quality, candidates)

- [x] **T-31** Replace the bare-metal register addresses in `app/board/audio.c`
      (`0x51030`, `0x10014`) with named constants in `app/board/fm1_audio.h`.
      **Done 2026-10-20** — upstream-bound, merged to local `main` and
      `main-feature`; PR [#7](https://github.com/m-vave/fm1_open/pull/7)
      open. *(plan.md D)*
- [x] **T-32** Rename the file-local `crc32()` in `app/samples.c` to
      `samples_crc32()` (namespace hygiene). **Done 2026-10-20** — web +
      firmware builds green. *(plan.md D)*
- [x] **T-33** Document in `app/audio_output.c` why the Bluetooth gain uses
      `output_gain * 2` while USB uses `>> 7` (16-bit vs Q23 scaling).
      **Done 2026-10-19.** *(plan.md D)*
- [x] **T-39** Build `tools/generate-code-index.ps1` + generated
      `doc/code_index.md` (RAG-style symbol index for `app/` + `web/engine/`).
      **Done 2026-10-19** — 16 files / 375 symbols; linked from `index.md`.
      *(plan.md C — enabler for T-28/T-41)*
- [x] **T-40** Decide BUG-001: open a minimal upstream PR (`build.bat` prefers
      `pwsh` with a `powershell.exe` fallback) **or** mark it `wont-fix` with a
      reason. **Done 2026-10-20** — fixed locally on `main-feature` (no upstream
      PR per branch policy); BUG-001 is now `fixed`. *(plan.md D)*
- [x] **T-28** ~~Split `app/screen.c` into a three-layer multi-TU
      architecture.~~ **Rejected 2026-10-20** — the split grows the app image
      to 457 544 B against a hard limit of 453 921 B (baseline 453 736 B); the
      overhead comes from losing `static` linkage. Work discarded, branch
      `feature/upstream-screen-split` deleted. Evidence:
      [`doc/screen-split-plan.md`](./screen-split-plan.md#outcome-2026-10-20).
      Surviving alternative: **T-41**. *(plan.md F)*
- [ ] **T-41** *Optional:* byte-neutral refactoring of `app/screen.c` into
      `app/screen_*.inc` fragments included by the single `screen.c`
      translation unit (all symbols stay `static`, no `Build.ps1`/manifest
      change, app image must stay byte-identical). Plan, cut order and gate:
      [`doc/plan.md`](./plan.md#option-byte-neutral-screen-refactoring-t-41).
      Not scheduled; branch `main-feature`. *(plan.md F)*
- [x] **T-15** Decide whether a host-side check harness is wanted. **Decided
      2026-10-19: yes** → implemented as T-29 (host C harness via
      `FM1_HOST_TEST`). Closed 2026-10-20 as superseded by T-29.
- [ ] **T-16** Gleanings: file findings from any debugging session back into
      `doc/`. *(ongoing)*

## Testing

- [x] **T-29** Activate a host-side C harness via the existing `FM1_HOST_TEST`
      switch and cover pure APP logic (`project.c` CRC/magic/upgrade,
      `samples.c` header CRC, tuning capture/apply validation). No new
      framework; artifacts to `%TEMP%\opencode`. **Done 2026-10-20** —
      `pwsh tests\host\run.ps1` green. *(plan.md E)*
- [x] **T-30** Build a lightweight Node.js WASM harness driving the `sim_*`
      exports of `sdk/Simulator.js` (boundary rejects + sequencer/tuning
      behaviour). **Done 2026-10-20** - `node tests\wasm\fm1_wasm_test.mjs`
      green against `build/web/simulator.wasm`. *(plan.md E)*
- [ ] **T-24** Run the Level-3 on-device protocol (`doc/test-strategy.md`) once
      T-11 produced a flashable image; file every fail as `BUG-<n>` in
      `doc/bugs.md`. Also re-run after T-41 (if done). *(plan.md F verification)*

## From the reference study (wogd-ddsp-trainer)

Full analysis: [./reference-wogd-ddsp-trainer.md](./reference-wogd-ddsp-trainer.md).

- [x] **T-17** **Adopt:** scripted manual hardware test protocol as the
      Level-3 section of `doc/test-strategy.md` (13 checks) — 2026-10-19.
- [x] **T-18** **Adopt:** canonical `doc/bugs.md` ledger — 2026-10-19.
- [x] **T-20** **Adopt:** `## Action items` block for flagged components in
      `doc/licensing.md` — 2026-10-19.
- [x] **T-22** Reference page `doc/reference-wogd-ddsp-trainer.md` written and
      linked — 2026-10-19.
- [x] **T-21** **Rule to keep:** any change to `.vscode/tasks.json` updates the
      task table in `README.md` in the same commit. Closed 2026-10-20 —
      executed by T-36 and kept as a standing rule.
- Explicitly **not** adopted: generated `code_wiki.md`/RAG index **from Python +
      post-commit hook** (a PowerShell code index *is* pursued as T-39),
      pytest/vitest/CI tasks, installer pipeline, `clean-*` tasks,
      format-on-save.

## Done (archive)

- [x] 2026-10-19 — **Project review** (efficiency, dev env, build, agent rules,
      docs, code) → this `plan.md` roadmap + tasks T-26…T-40 filed
      (`next-free: T-41`).
- [x] 2026-10-19 — reference study of `artqcid/wogd-ddsp-trainer`
      (task **T-22**; 2 explore subagents → `doc/reference-wogd-ddsp-trainer.md`).
- [x] 2026-10-19 — created `main-feature` from `main` at `b178ac4` (V13);
      wiki sync committed (`5c1534f`, `983f743`) and pushed to
      `origin/main-feature`.
- [x] 2026-10-17 — FM1 V13 upstream release (`b178ac4`).

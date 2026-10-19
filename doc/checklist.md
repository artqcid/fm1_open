---
title: FM1 Open Checklist
description: Open tasks with short descriptions. Newest state of the workspace backlog.
updated: 2026-10-19
---

# FM1 Open — Checklist

Short descriptions only. Keep entries small; expand into a `doc/*.md` page or a
git issue when a task grows. Newest first inside each section.

Legend: `[ ]` open · `[~]` in progress / `[x]` done.
**Task IDs (`T-nn`) are permanent** — assign the next free number in
`next-free:` below, never reuse or renumber an ID. A deferred item is marked
`**Moved to …**` instead of being silently deleted (convention borrowed from
`artqcid/wogd-ddsp-trainer`, see
[./reference-wogd-ddsp-trainer.md](./reference-wogd-ddsp-trainer.md)).

next-free: **T-26**

## Documentation & workspace

- [x] **T-01** `AGENTS.md` with workflow, subagent rules, Definition of Done.
- [x] **T-02** `doc/` wiki: index, log, checklist, lint, coding-standards,
      build-workflow, architecture, licensing, branch-workflow, test-strategy.
- [x] **T-03** `.editorconfig` + `.vscode/` tasks.
- [x] **T-04** `fm1_open.code-workspace`, project-level `opencode.json`
      (`notebooklm_devblogs` MCP).
- [ ] **T-05** Resolve the NotebookLM notebook ID for **WOGD-FM1 Firmware** via
      the `nbml-list` skill once the MCP server is running; write it into
      `AGENTS.md` (currently `TBD`).
- [ ] **T-06** First Knowledge-Sync run: push `doc/log.md` digest to the notebook.
- [x] **T-07** First `pwsh doc/lint.ps1` run: **OK, 9 pages, exit 0** (2026-10-19).

## Build & environment (blocked until configured)

- [x] **T-08** Set `FM1_SOURCE_URL` (HTTPS URL of the matching source archive) —
      **done 2026-10-19:** `https://github.com/m-vave/fm1_open` (accepted by the
      web build; baked into both VS Code build tasks **and** persisted as a
      user-level environment variable — `$env:` alone is session-only).
- [x] **T-09** Set `FM1_PI32_TOOLCHAIN` to a folder containing `bin/clang.exe`.
      **Done 2026-10-19 (revised):** the hash-pinned **JieLi toolchain 2.5.2**
      is extracted (no installer run) to `C:\JL\pi32-2.5.2\C$\JL\pi32` —
      see BUG-002 for the full recipe. Persisted as a user-level environment
      variable; the superseded `C:\JL` 2.5.3 install (which never matched
      the SDK pin) has been deleted.
- [x] **T-10** Run `.\build.bat --web` → confirm `build/preview/index.html`.
      **Green 2026-10-19** (883 KB; WASI SDK 27 downloaded once into
      `build/tools`). Needed the BUG-001 `PSModulePath` workaround.
- [x] **T-11** Run `.\build.bat --package` → confirm
      `build/dx7/generated/FM1_OFFICIAL_OPEN.fwsc`.
      **Green 2026-10-19:** 440 028-byte app image, package fits 1 MiB;
      `FM1_OFFICIAL_OPEN.fwsc` + `build/official-web/FM1-Official-Open-Source.html`
      produced (after the BUG-002 fix and a session-level stale-`LIB` cleanup).
- [x] **T-12** Verify `sdk/manifest.json` → `external_toolchain` hashes match the
      toolchain actually in use. **Done 2026-10-19: 22/22 entries match** the
      extracted 2.5.2 toolchain (initially found 4/5 mismatches → BUG-002).
- [ ] **T-13** Optional: set `FM1_WASI_SDK` to an extracted WASI SDK 27 to avoid
      the 518 MiB first-time download — the SDK now lives in `build/tools`
      (re-downloaded after a `build/` wipe); exporting the variable keeps it
      outside the gitignored `build/` tree.

## Engineering (candidates, not yet planned)

- [x] **T-14** Confirm toolchain availability and record it in
      `doc/build-workflow.md` — the pinned 2.5.2 toolchain is extracted and
      verified (22/22 manifest hashes) at `C:\JL\pi32-2.5.2\C$\JL\pi32`;
      recipe and status recorded in the build workflow.
- [ ] **T-25** Optional machine cleanup: the **system-wide** `LIB` environment
      variable still lists a deleted Visual Studio 18 preview path
      (`…\MSVC\14.50.35717\lib\x64`). Builds now clear `LIB` session-side,
      but removing the stale entry from the machine environment avoids the
      warning forever (user decision — changes the system, not the repo).
- [ ] **T-15** Decide whether a host-side check harness is wanted
      (`FM1_HOST_TEST` already exists in `sdk/include/fm1.h`).
- [ ] **T-16** Gleanings: file findings from any debugging session back into `doc/`.
- [ ] **T-24** Run the Level-3 on-device protocol
      (`doc/test-strategy.md`) once **T-11** produced a flashable image; file
      every fail as `BUG-<n>` in `doc/bugs.md`.
- [ ] **T-23** Work through the `## Action items` table in `doc/licensing.md`
      (7 rows, all `open` except PR #2) and update statuses as each is verified.

## From the reference study (wogd-ddsp-trainer)

Full analysis: [./reference-wogd-ddsp-trainer.md](./reference-wogd-ddsp-trainer.md).

- [x] **T-17** **Adopt:** scripted manual hardware test protocol as the
      Level-3 section of `doc/test-strategy.md` (13 checks, pass/fail boxes) —
      2026-10-19.
- [x] **T-18** **Adopt:** canonical `doc/bugs.md` ledger — `BUG-<n>` IDs and
      full records only there, ID-only cross-references elsewhere, periodic
      re-verification written back into the same entry — 2026-10-19.
- [ ] **T-19** **Consider when the backlog grows:** add a `doc/plan.md`
      roadmap tier (meta plan / decisions / risks).
      _Task-ID prefixes and `**Moved to …**` markers are already adopted (T-nn)._
- [x] **T-20** **Adopt:** `## Action items` block for flagged components in
      `doc/licensing.md` — 2026-10-19.
- [ ] **T-21** **Rule to keep:** any change to `.vscode/tasks.json` updates the
      task table in `README.md` in the same commit (sibling drifts — 6 vs 10).
      Kept as a rule rather than an upstream-README edit to avoid widening the
      upstream diff.
- [x] **T-22** Reference page `doc/reference-wogd-ddsp-trainer.md` written and
      linked (2026-10-19).
- Explicitly **not** adopted: generated `code_wiki.md`/RAG index + post-commit
  hook, pytest/vitest/CI tasks, installer pipeline, `clean-*` tasks,
  format-on-save.

## Done (archive)

- [x] 2026-10-19 — reference study of `artqcid/wogd-ddsp-trainer`
      (task **T-22**; 2 explore subagents → `doc/reference-wogd-ddsp-trainer.md`).
- [x] 2026-10-19 — created `main-feature` from `main` at `b178ac4` (V13);
      wiki sync committed (`5c1534f`, `983f743`) and pushed to
      `origin/main-feature`.
- [x] 2026-10-17 — FM1 V13 upstream release (`b178ac4`).

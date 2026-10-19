---
title: FM1 Open Checklist
description: Open tasks with short descriptions. Newest state of the workspace backlog.
updated: 2026-10-19
---

# FM1 Open — Checklist

Short descriptions only. Keep entries small; expand into a `doc/*.md` page or a
git issue when a task grows. Newest first inside each section.

Legend: `[ ]` open · `[~]` in progress / partially done · `[x]` done.

## Documentation & workspace

- [x] `AGENTS.md` with workflow, subagent rules, Definition of Done.
- [x] `doc/` wiki: index, log, checklist, lint, coding-standards,
      build-workflow, architecture, licensing, branch-workflow, test-strategy.
- [x] `.editorconfig` + `.vscode/` tasks.
- [x] `fm1_open.code-workspace`, project-level `opencode.json`
      (`notebooklm_devblogs` MCP).
- [ ] Resolve the NotebookLM notebook ID for **WOGD-FM1 Firmware** via the
      `nbml-list` skill once the MCP server is running; write it into
      `AGENTS.md` (currently `TBD`).
- [ ] First Knowledge-Sync run: push `doc/log.md` digest to the notebook.
- [x] First `pwsh doc/lint.ps1` run: **OK, 9 pages, exit 0** (2026-10-19).

## Build & environment (blocked until configured)

- [ ] Set `FM1_SOURCE_URL` (HTTPS URL of the matching source archive) —
      all builds stop without it. **Confirmed 2026-10-19:** `.\build.bat --web`
      exits 1 with exactly this message.
- [ ] Set `FM1_PI32_TOOLCHAIN` to a folder containing `bin/clang.exe`
      (README suggests `C:\JL\pi32` — verify it exists).
- [ ] Run `.\build.bat --web` → confirm `build/preview/index.html`.
- [ ] Run `.\build.bat --package` → confirm
      `build/dx7/generated/FM1_OFFICIAL_OPEN.fwsc`.
- [ ] Verify `sdk/manifest.json` → `external_toolchain` hashes match the
      toolchain actually in use.
- [ ] Optional: set `FM1_WASI_SDK` to an extracted WASI SDK 27 to avoid the
      518 MiB first-time download.

## Engineering (candidates, not yet planned)

- [ ] Confirm toolchain availability and record it in `doc/build-workflow.md`.
- [ ] Decide whether a host-side check harness is wanted
      (`FM1_HOST_TEST` already exists in `sdk/include/fm1.h`).
- [ ] Gleanings: file findings from any debugging session back into `doc/`.

## Done (archive)

- [x] 2026-10-19 — created `main-feature` from `main` at `b178ac4` (V13).
- [x] 2026-10-17 — FM1 V13 upstream release (`b178ac4`).

# FM1 Open — Changelog (docs & workspace)

Append-only, **newest first**. Every completed task adds an entry here and keeps
[./index.md](./index.md) in sync (AGENTS.md → Post-Task Sync).
Format: `## YYYY-MM-DD — <short title>` then bullet lines starting with `-`.

---

## 2026-10-19 — Wiki sync committed and pushed

- Wiki sync committed to `main-feature` as `5c1534f`
  ("docs: add agent workflow wiki, coding standards and workspace config",
  16 files, 1483 insertions).
- Pushed to `origin` (`artqcid/fm1_open`) branch `main-feature`.
  `main` / `origin/main` remain untouched upstream mirrors of
  `m-vave/fm1_open`.
- `opencode.json` was included in the commit (contains local tool/profile
  paths only — no secrets).

## 2026-10-19 — Initial FM1 Open V13 wiki sync

- Added `AGENTS.md`: language rule (agent-facing docs in English), todo-first
  workflow gated by explicit plan approval, subagent rules (one small task per
  prompt, subagents never build/test, GitHub MCP read-only allowed,
  `notebooklm_devblogs` primary-only), Definition of Done, wiki-lint and
  knowledge-sync rules, ad-hoc scratch-compilation rule, quick facts.
- Added `doc/index.md` — LLM-Wiki catalog (load-first navigation entry point).
- Added `doc/log.md` — this file.
- Added `doc/checklist.md` — open tasks with short descriptions.
- Added `doc/lint.ps1` — wiki lint (orphan pages, duplicate index entries,
  stale claims, contradictions); exit codes 0/1/2.
- Added `doc/coding-standards.md` — Clean Code Developer 45 rules / 6 degrees,
  adapted for C + fixed-point DSP + FM1 IRQ constraints.
- Added `doc/build-workflow.md` — build modes, env vars, toolchain, outputs,
  verification commands.
- Added `doc/architecture.md` — APP vs binary engine, audio IRQ path, Web/WASM
  path, memory sections, version identity.
- Added `doc/licensing.md` — license map (APP GPLv3+exception, proprietary
  engine grant, Apache-2.0 boot resources, third-party table).
- Added `doc/branch-workflow.md` — `main`/`origin` pristine, `main-feature`
  integration branch, `feature/*` rules.
- Added `doc/test-strategy.md` — honest verification strategy (no unit-test
  harness; web build is the smoke check).
- Added `.editorconfig` — indentation, line endings, trailing whitespace.
- Added `.vscode/tasks.json` and `.vscode/launch.json` — FM1 build/lint tasks.
- Workspace state: `main-feature` created from `main` at `b178ac4`
  (V13). `main` / `origin/main` untouched. Untracked at time of entry:
  `AGENTS.md`, `opencode.json`, `fm1_open.code-workspace`, `doc/`, `.vscode/`,
  `.editorconfig`.
- Verification results:
  - `pwsh doc/lint.ps1` → **OK, no issues**, 9 pages scanned, exit 0.
  - `.\build.bat --web` → **stopped early**, exit 1:
    `Set FM1_SOURCE_URL or -SourceUrl to the HTTPS URL of the matching source
    archive.` (expected — env var not configured).
  - `git status --short` → only the intended new files; no stray compiler
    artifacts under the repo root, `app/`, `web/` or `sdk/`; no `build/` dir.
- **Pending:** firmware build `.\build.bat --package` not run — `FM1_SOURCE_URL`
  and `FM1_PI32_TOOLCHAIN` are not set in this environment. Web build is
  equally pending on `FM1_SOURCE_URL`.

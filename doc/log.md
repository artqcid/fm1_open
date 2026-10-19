# FM1 Open — Changelog (docs & workspace)

Append-only, **newest first**. Every completed task adds an entry here and keeps
[./index.md](./index.md) in sync (AGENTS.md → Post-Task Sync).
Format: `## YYYY-MM-DD — <short title>` then bullet lines starting with `-`.

---

## 2026-10-19 — C:\JL cleanup: superseded 2.5.3 install removed

- `C:\JL\ver.txt` identified the old install as toolchain **2.5.3**; its
  `pi32/` (159 MB), `commtools/` (26 MB), `mc/` (98 MB) and the installer
  extras in the root (`LicenseViewer.exe`, `RequestLicense.exe`,
  `UpdateDector.exe`, `ver.txt`, EULA `.rtf`, `unins000.*`) were deleted —
  ~283 MB freed. No PATH or repo references pointed at them, and the
  extracted 2.5.2 tree has complete copies of `commtools`/`mc`.
- `C:\JL` now contains **only** the pinned, verified `pi32-2.5.2`
  (clang.exe spot-check still `0ae79bfb…`). Session scratch (wrong-version
  installer, innoextract, failed `zlb` reverse-engineering outputs) removed
  from `%TEMP%\opencode`.
- **Persistent user env set** (was session-only `$env:` before):
  `FM1_SOURCE_URL=https://github.com/m-vave/fm1_open` and
  `FM1_PI32_TOOLCHAIN=C:\JL\pi32-2.5.2\C$\JL\pi32` — Machine/User registry,
  PS profiles, cmd AutoRun and `.env` files had been checked and were empty
  of any FM1/JL/pi32 entries; no stale old-path variable existed to delete.

## 2026-10-19 — BUG-002 fixed: both Definition-of-DoD builds green

- **Toolchain provenance solved.** No CI/Docker config exists in
  `m-vave/fm1_open` (no `.github/`), but `earlynerd/HLK-LD2450_FW` →
  `firmware/toolchain.lock.json` pins the identical `clang.exe` hash and
  names the source: **JieLi Windows toolchain 2.5.2**, installer
  `https://jl-update.oss-cn-shenzhen.aliyuncs.com/2.5.2.exe`
  (SHA-256 `1ec78e33…`, Authenticode Valid — ZhuHai JieLi Technology).
- Extracted **without executing the installer** with innoextract 1.9 into
  `C:\JL\pi32-2.5.2` → toolchain at `C:\JL\pi32-2.5.2\C$\JL\pi32`.
  Verified **22/22** entries of `sdk/manifest.json` → `external_toolchain`.
  **BUG-002 moved to `## Fixed`**; manifest pin untouched; the old
  `C:\JL\pi32` install left as-is.
- Second environment pitfall found and worked around: the **machine-wide**
  `LIB` variable lists a deleted Visual Studio 18 preview path, which broke
  `Add-Type` (Package.cs) with a warning-as-error. Builds now clear `LIB`
  session-side; the machine cleanup itself is new task **T-25**.
- **`.\build.bat --package` green:** app image 440 028 bytes, package fits
  1 MiB, `build/dx7/generated/FM1_OFFICIAL_OPEN.fwsc` +
  `build/official-web/FM1-Official-Open-Source.html` produced. **T-11 done.**
- `.vscode/tasks.json`, `.vscode/launch.json` and `fm1_open.code-workspace`
  updated (toolchain path, `PSModulePath` + `LIB` workarounds,
  `fm1.sourceUrl` filled in); recipe documented in `doc/build-workflow.md`.

## 2026-10-19 — Builds run for the first time: web green, firmware blocked (BUG-002)

- `FM1_SOURCE_URL` set to `https://github.com/m-vave/fm1_open` (T-08) and
  baked into both VS Code build tasks together with the **BUG-001**
  `PSModulePath` workaround.
- **BUG-001** filed: `build.bat` fails under PowerShell 7 with
  `CommandNotFoundException: Get-FileHash` (5.1 inherits `pwsh`'s
  `PSModulePath`, then fails to auto-load the PS7 copy of
  `Microsoft.PowerShell.Utility`). Workaround in `.vscode/tasks.json`;
  upstream `build.bat` untouched. Details in `doc/bugs.md`.
- **Web build green:** `.\build.bat --web` → `build/preview/index.html`
  (883 KB). WASI SDK 27 downloaded once into `build/tools` (T-10 done).
- **BUG-002** filed: the toolchain at `C:\JL\pi32` fails the
  `sdk/manifest.json` hash pin (only `llvm-nm.exe` matches) →
  `build.bat --package` stops at the integrity check. The manifest pin is
  **not** relaxed; the pinned clang 4.0.1 r3 must be installed. T-11 stays
  open, T-12 closed with the mismatch as its result.

## 2026-10-19 — VS Code build tasks + toolchain path verified

- Rewrote `.vscode/tasks.json`: default build task
  `FM-1: Build Firmware Package (.fwsc)` (sets
  `FM1_PI32_TOOLCHAIN=C:\JL\pi32`, runs `build.bat --package`),
  `FM-1: Build Web Preview` (`build.bat --web`, group `test`), and the kept
  `fm1:lint` task. The previous generic `fm1:*` build tasks were replaced.
- Toolchain path **verified**: `C:\JL\pi32\bin\clang.exe` exists (25.8 MB).
  Recorded in `doc/build-workflow.md`; checklist **T-09** and **T-14** closed.
- **Still blocking both build tasks:** `FM1_SOURCE_URL` is not set and is
  deliberately not baked into the tasks (no placeholder URLs). Everything else
  for a firmware build is now in place.

## 2026-10-19 — Reference-study adoptions implemented

- Added `doc/bugs.md` — canonical bug ledger (`BUG-<n>` IDs and full records
  only there, ID-only cross-references elsewhere, append-only `history`,
  periodic re-verification written back into the same entry). `next_id: 1`.
- `doc/test-strategy.md` Level 3 is now a **scripted 13-point on-device
  acceptance protocol** with pass/fail boxes and a notes column; fails become
  `BUG-<n>` entries.
- `doc/licensing.md` gained `## Action items` — 7 flagged components
  (Newlib-derived `libc.a`, micro-ecc routines in the binary engine, JieLi
  SDK material, `cfg_tool.bin` identity, boot/OTA Apache-2.0 duties, DSP
  upstream pins, PR #2) with status column; 6 `open`, 1 `verified`.
- `doc/checklist.md` restructured with **permanent `T-nn` task IDs**,
  a `next-free:` counter (T-25) and the `**Moved to …**` deferral convention;
  new tasks T-23 (work the licensing action items) and T-24 (run the Level-3
  protocol after the first flashable build).
- `doc/index.md` links `doc/bugs.md`; `AGENTS.md` quick facts gained the bug
  ledger and task-ID notes, and Post-Task Sync now requires filing found/fixed
  bugs into the ledger.
- **Not** adopted (as decided in the reference study): `doc/plan.md` roadmap
  tier (deferred to T-19), generated RAG/symbol index + post-commit hook,
  pytest/vitest/CI, installer pipeline, `clean-*` tasks, format-on-save, and
  no upstream-`README.md` edits (rule kept as T-21 instead).
- Verification: `pwsh doc/lint.ps1` → OK, 11 pages, exit 0; no stray artifacts;
  nothing committed yet.

## 2026-10-19 — Reference study: artqcid/wogd-ddsp-trainer

- Added `doc/reference-wogd-ddsp-trainer.md` — verified comparison against the
  sibling repo (read-only GitHub MCP recon, `main` as of 2026-10-19; `doc/`
  listing cross-checked: 21 entries, sizes match reported values).
- Findings: **adopt** (1) scripted manual hardware test protocol into
  `doc/test-strategy.md`, (2) canonical `doc/bugs.md` ledger with `BUG-<n>`
  single-source-of-truth and ID-only cross-references; **consider later**
  `plan.md` roadmap tier, checklist task-ID prefixes, licensing action-items
  list; **not applicable** generated `code_wiki.md`/RAG index + post-commit
  hook, pytest/vitest/CI, installer pipeline, clean-* tasks, format-on-save.
- Negative example recorded: sibling README documents 6 VS Code tasks while
  `tasks.json` has 10 — README/task table must be updated in the same commit.
- Linked from `doc/index.md` (new "References" section); adoption items added
  to `doc/checklist.md`.

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

# FM1 Open — Changelog (docs & workspace)

Append-only, **newest first**. Every completed task adds an entry here and keeps
[./index.md](./index.md) in sync (AGENTS.md → Post-Task Sync).
Format: `## YYYY-MM-DD — <short title>` then bullet lines starting with `-`.

---

## 2026-10-20 — Knowledge-tooling plan (group G), OpenCode V2 config, subagent models

- Studied `artqcid/wogd-ddsp-trainer` and `artqcid/wogd-vst-netsdrstation`
  (GitHub MCP read): RAG-MCP server (FastMCP, SQLite FTS5 trigram + bm25, four
  tools, stable chunk IDs, `.ragignore`), generated code wiki, post-commit sync,
  local skills, per-agent RAG permissions, NotebookLM as third store.
- New **plan.md group G** (T-42…T-48) + checklist section; `next-free` is T-49.
  Decisions: keep the PowerShell `code_index.md` next to the RAG; vendor sources
  indexed but scope-tagged; CI optional (T-47). Reference study decision 7
  ("no Python RAG") marked superseded in `reference-wogd-ddsp-trainer.md`.
- **OpenCode V2 (v2.0.32):** V1 config is normalised silently
  (`opencode debug config`: no warnings). Project `opencode.json` converted to the
  native V2 shape (`mcp.servers`); `notebooklm_devblogs` reconnects. V2 notes
  recorded in plan.md (Code Mode → `codemode: false` for `fm1_rag`, `explore`
  denies MCP tools by default, `external_directory` allowed by default,
  `instructions` for the global no-auto-commit rule, token in plain text).
- **Subagent models reset (global config, outside the repo):** `general` and
  `explore` back to `openrouter/upstage/solar-pro4` in
  `~/.config/opencode/opencode.json` and `agent/{general,explore}.md`
  (`opencode/deepseek-v4.1-flash-free` and `reasoningEffort: low` removed);
  verified with `opencode debug agents`. Backups: `%TEMP%\opencode\cfg_backup_20261020`.
- NotebookLM authentication is **expired** (`notebook_get` → "Authentication
  expired"). *Correction (same day):* no separate action — re-auth stays an
  on-demand rule via the `nbml-reauth` skill (agent-run) when T-46 needs it.
- *Correction (same day):* the GitHub-token rotation/`{env:…}` advice is
  optional hygiene, not a requirement; the token was echoed once into a
  session tool output (config dump without redaction), which is why it was
  raised.

## 2026-10-20 — T-28 rejected (flash budget); T-41 byte-neutral option

- Analysed the partial T-28 work (`feature/upstream-screen-split`, steps 1–6).
  Scratch builds (`Build.ps1 -FirmwareOnly`, never touching the repo): baseline
  V14 = 453 736 B app image; partial split 457 544 B (458 088 B with the
  unchanged flags); hard limit 453 921 B (derived from `sdk/Package.cs`) →
  only 185 B headroom.
- Root cause: loss of internal linkage (`static` 137 → 44), not the file
  split. Controls: monolith with only `static` stripped = 457 544 B (same);
  unity build of the split files = 457 512 B; baseline with a 214-line
  `#include`d `.inc` fragment and `static` kept = 453 736 B (identical).
- Also found: build-time argument void (`Build.ps1` rebuilds all objects, ≈ 7 s),
  `sdk/Build.ps1` is hash-pinned in `sdk/manifest.json`, `clamp()` macro risk.
- **Decision (user): discard the split completely.** Working-tree changes
  reverted, new `screen_*.c` removed, local branch deleted (last commit
  `29325bf`, reflog only). `main` was never touched.
- `doc/screen-split-plan.md` → `status: deprecated` + Outcome section (kept as
  a record). T-28 closed as rejected in `checklist.md`.
- New optional task **T-41** (own ID): byte-neutral refactoring via `.inc`
  fragments in one translation unit — plan, cut order, byte-exact size gate in
  `plan.md` ("Option: byte-neutral screen refactoring"). Not scheduled.
- New "Flash budget" section in `doc/build-workflow.md` (limit formula, V14
  status 453 736 B); stale V13 figure 440 028 B corrected.
- `branch-workflow.md` / `plan.md` / `checklist.md`: "upstream-bound" is now a
  per-task tag (currently T-31 only) so future small fixes can be prepared for
  PRs to `m-vave/fm1_open` with their own `T-nn`; `next-free` is T-42.

## 2026-10-20 — T-28 screen-split plan (superseded by the entry above)

- Analysed `app/screen.c` (2,994 lines): paint layer, 10 page groups,
  input state machine, web adapter.
- Designed a three-layer architecture: `screen_gfx.h` (reusable pixel kit
  — custom firmware entry point), `screen_page.h` (mid-layer page contract),
  `screen_internal.h` (internal shared state).
- Split into 11 new translation units; `screen.c` slims to ~300 lines.
- Defined function rename table (`paint_fill` → `screen_fill`, etc.) and
  `sdk/Build.ps1` flag pattern update.
- Documented 12 ordered implementation steps (each independently verifiable
  with `.\build.bat --web`) and PR description template.
- Phase-2 follow-up items recorded (per-page input handlers, parameter passing).
- New file: `doc/screen-split-plan.md`; checklist/plan/index updated.

## 2026-10-20 — T-30 WASM behaviour harness

- Added `tests/wasm/fm1_wasm_test.mjs`: no npm dependencies; evaluates
  `sdk/Simulator.js` without a DOM and drives `FM1SimulatorCore` against
  `build/web/simulator.wasm`.
- Checks init exports, boundary rejects (MIDI >1024, project/patch/sample/
  library lengths), a sequencer step round-trip, and tuning import/export
  (`-127`, `-128` rejection, CRC).
- `node tests/wasm/fm1_wasm_test.mjs` green; `.\build.bat --web` rebuilds the
  WASM input.

## 2026-10-20 — T-29 host persistence harness

- Added `tests/host/fm1_host_test.c` + `tests/host/run.ps1`: builds
  `app/project.c`/`app/samples.c` with `FM1_HOST_TEST` against a RAM-backed
  Flash and the engine control stubs.
- Checks CRC-32 vector, project save/load + checksum rejection, legacy v3→v4
  upgrade, tuning `-128`/all-or-nothing, sample header CRC + write order.
- `pwsh tests/host/run.ps1` green; artifacts stay in `%TEMP%\opencode`.

## 2026-10-20 — T-23 licensing action items verified

- Verified all seven `doc/licensing.md` action items against V14 (`4d26685`):
  `libc.a` manifest hash + Newlib symbols (`__dtoa`, `__gethex`, `__hexnan`,
  `__mprec_bigtens`), micro-ecc `uECC_*` in the current engine, AC79 pin
  `5fa84a9`, `cfg_tool.bin` byte-identical to the official
  `cpu/wl82/tools/cfg_tool.bin` (SHA-256 `276579…`), boot/update hashes +
  Apache-2.0 notices, DSP pins unchanged (`FM1_SYNTH_API 4U→5U`), PR #2.
- Statuses updated to `verified`; lint OK.

## 2026-10-20 — T-32 `samples_crc32` rename

- Renamed the file-local `crc32()` helper in `app/samples.c` to
  `samples_crc32()` (definition + two call sites); `groove_crc32` untouched.
- `.\build.bat --web` and `.\build.bat --package` green; lint OK.

## 2026-10-20 — T-31 upstream PR #7

- Implemented T-31: `FM1_AUDIO_PORT_ROUTE` / `FM1_AUDIO_CLOCK_SEL` in
  `app/board/fm1_audio.h`, used in `app/board/audio.c`; no behaviour change.
- Verified on the upstream branch via `pwsh -File tools/Build-Web.ps1` and
  `sdk/Build.ps1 -Package` (V14, both green).
- Fast-forwarded local `main` to `24beff7`, pushed `main` + branch to
  `origin`, opened **PR #7** against `m-vave/fm1_open:main`.
- Merged `main` into `main-feature` (`ebd80ca`) so the change is present in
  the integration branch.

## 2026-10-20 — V14 upstream merge + BUG-001/T-40 fixed

- Merged upstream **V14** (`4d26685`, tag `V14`) into `main-feature`;
  resolved the `README.md` build-section conflict (kept the `.env.example`
  pointer plus the new `-LocalPreview` hint). Both builds green on V14.
- **T-40 done:** BUG-001 fixed locally on `main-feature` — `build.bat` now
  prefers `pwsh`, with a `powershell.exe` fallback that resets `PSModulePath`.
  No upstream PR (branch policy: only T-28/T-31 go to `main`).
- Verified: `.\build.bat --web` → `build/preview/index.html`;
  `.\build.bat --package` → firmware image + workbench.

## 2026-10-20 — Upstream-bound main policy + effective task order

- **T-28** (split `app/screen.c`) and **T-31** (audio register constants) are
  **upstream-bound**: topic branch from `main` → ff-merge into local `main` →
  PR to `m-vave/fm1_open` → merge `main` into `main-feature`. All other tasks
  stay on `main-feature` / `feature/*`.
- `main` is no longer a pristine mirror: it is upstream **plus** the two
  upstream-bound commits. Upstream sync uses `git merge upstream/main`; the
  PR lifecycle (open / merge / squash / reject) is documented in
  `branch-workflow.md`.
- Closed bookkeeping **T-15** (superseded by T-29) and **T-21** (standing rule,
  executed by T-36).
- Recorded the effective execution order in `plan.md`: T-15/T-21 → T-31 →
  T-32 → T-40 → T-23 → T-29 → T-30 → T-24 → T-28.
- Updated `checklist.md`, `plan.md`, `branch-workflow.md`, `log.md`.

## 2026-10-19 — NotebookLM unblocked (T-05/T-06) + Machine LIB fixed (T-25)

- **T-25 (done):** the elevated Machine `LIB` now points at the installed
  MSVC 14.51 + Windows SDK paths (replacing the deleted VS 18 MSVC 14.50
  entry) via a UAC-elevated `SetEnvironmentVariable`; the earlier User-level
  override is superseded.
- **T-05/T-06 (done):** `notebooklm-mcp-server` dependencies were upgraded;
  the persistent 400 on `notebook_list` was a corrupted `auth.json`
  (`csrf_token` == `session_id`) produced by the reauth script's CSRF
  fallback. Fixed `reauth_nblm.py` to read `SNlM0e` from the raw page HTML.
  Notebook ID `a85eb2ec-cfaa-4f10-bb74-a1732bfae75c` recorded in `AGENTS.md`;
  the first Knowledge-Sync digest was pushed (source `a541f9df-…`).
- Verification: `notebook_list` → 30 notebooks; digest present in the
  notebook; `csrf != sid` after re-heal.

## 2026-10-19 — Implementation Groups A–C (T-25…T-39)

- **Docs:** `test-strategy.md` Level-2 status corrected to green (T-26);
  `AGENTS.md` Quick facts trimmed to a pointer-only block (T-37);
  `doc/build-workflow.md` task table now documents `fm1:check-repo` and the
  external WASI SDK (T-36; README has no task table, so the canonical table
  here was updated instead).
- **Tooling:** added `tools/generate-code-index.ps1` → `doc/code_index.md`
  (16 files / 375 symbols, linked from `index.md`; T-39) and
  `tools/check-repo.ps1` (Level-4 hygiene, wired as `fm1:check-repo`; T-27).
- **Environment:** `FM1_WASI_SDK=C:\wasi-sdk-27` (SDK moved out of the
  gitignored `build/tools`; T-38 closes T-13); `.env.example` committed with
  a `.gitignore` exception and referenced from `README.md` (T-34);
  `problemMatcher: ["$gcc"]` on both build tasks (T-35).
- **T-25 (partial):** User-level `LIB` override points at MSVC 14.51 +
  Windows SDK; the stale Machine entry needs an elevated one-liner (the
  interactive shell is not admin).
- **T-05/T-06 blocked:** NotebookLM re-auth succeeds, but `notebook_list`
  returns HTTP 400 (stale frontend build label in the MCP package); needs an
  MCP-server update outside this repo.
- Verification: `pwsh doc/lint.ps1` → **OK, 13 pages, exit 0**;
  `pwsh tools/check-repo.ps1` → **all checks passed**;
  `.\build.bat --web` (clean env) → **green**, `build/preview/index.html`
  883 170 bytes, re-used `C:\wasi-sdk-27` (no re-download).

## 2026-10-19 — Implementation plan: project review → roadmap (`plan.md`)

- Project review (efficiency, dev environment, build process, agent rules,
  docs, code) turned into a Tier-1 roadmap [`./plan.md`](./plan.md) with the
  ordered task groups **A–F**, dependencies and risks. Closes **T-19**
  (roadmap tier) — the backlog is now past the size where a single
  `checklist.md` is enough.
- **New tasks filed** (`next-free: T-41`): T-26 (fix stale Level-2 prose in
  `test-strategy.md`), T-27 (`tools/check-repo.ps1` Level-4 hygiene check),
  T-28 (split `app/screen.c`, ≈ 2 900 lines), T-29 (host C harness via
  `FM1_HOST_TEST`), T-30 (Node WASM `sim_*` harness), T-31 (register symbols in
  `audio.c`), T-32 (rename `crc32`→`samples_crc32`), T-33 (BT-gain comment),
  T-34 (`.env.example`), T-35 (VS Code `problemMatcher`), T-36 (execute T-21),
  T-37 (trim `AGENTS.md` quick facts), T-38 (close T-13 via `build.ps1`),
  T-39 (code index), T-40 (BUG-001 decision).
- **RAG decision (yes):** build a PowerShell-generated `doc/code_index.md`
  (T-39) as a symbol *finder* for `app/` + `web/engine/`. No Python, no
  post-commit hook — regeneration is manual / Post-Task-Sync. The binary engine
  and `THIRD_PARTY.md` stay out of scope. Enabler for the T-28 split.
- Task bookkeeping: T-15 decided (→ T-29), T-21 executed by T-36, T-13
  executed by T-38; `checklist.md` restructured (new **Testing** section) and
  `index.md` links `plan.md`.
- Verification: `pwsh doc/lint.ps1` → **OK, 12 pages, exit 0**; `git status`
  shows only the intended `doc/` changes, no stray build artifacts.

## 2026-10-19 — VS Code build tasks fixed (BUG-001 recurrence)

- The integrated terminal task failed: VS Code passes an inline `-Command`
  setup string through two PowerShell parsers, the inner quotes are stripped
  and `$env:PSModulePath= C:\Program Files\…` splits into bogus commands.
- Switching to an `options.env` block failed **again** with `Get-FileHash`,
  which exposed the real mechanism: **PowerShell 7 re-appends its
  `$PSHOME\Modules` to `PSModulePath` at startup**, so any value inherited
  from the parent shell is overwritten before `build.bat` runs. The reset
  must happen inside the running `pwsh` process.
- Fix: new **`.vscode/build.ps1`** wrapper (`-Mode package|web`) sets
  `PSModulePath`, `LIB`, `FM1_SOURCE_URL`, `FM1_PI32_TOOLCHAIN` after pwsh
  has started and then calls `build.bat`; both build tasks invoke it with
  `-File` (no nested quoting). **Verified: `-Mode package` and `-Mode web`
  both exit 0.**
- Docs updated: `doc/bugs.md` BUG-001 (refined root cause + history),
  `doc/build-workflow.md` (pitfall section, task table, `LIB` note).

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
- `doc/test-strategy.md` Level-2 snippet updated to the pinned 2.5.2 path
  (was still `C:\JL\pi32`). Remaining old-path mentions are intentional
  history (`doc/bugs.md` BUG-002, `doc/log.md`) or upstream files
  (`README.md`, `README.zh-CN.md`) that stay pristine.

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

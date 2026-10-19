# AGENTS.md

## Language Rule

All agent rules, instructions, and agent-facing documentation in this workspace
**must be written in English**. This applies to AGENTS.md, skill files
(`.opencode/skills/**/SKILL.md`), agent system prompts, and any other
agent-facing configuration.

Human-facing docs under `doc/` are also English; user conversation may be in
German.

## Mandatory Workflow (single source of truth for ALL agents)

This section is the **single source of truth** for every workflow rule in this
workspace. It applies to all workspace agents: `ARCHITECT`,
`ARCHITECT_Openrouter`, `BUILD`, `BUILD_Openrouter`, `DEV`, `DEV_OpenRouter`,
`DEV_JUNIOR_Openrouter`. The global agents `build` and `plan` are NOT
workspace-specific and must never receive workspace-specific prompts or settings.

### Navigation & Knowledge First (MANDATORY — always start here)

Before every task (read/edit/build):

1. **`doc/index.md` — always load first.** The LLM-Wiki catalog links to every
   concept file. Navigate from here to find what you need (build workflow,
   architecture, licensing, branch rules, checklist, etc.).
2. If the index points to a concept file, read or query it directly.
3. For source-level questions read files with `offset`/`limit` — never whole
   files. `THIRD_PARTY.md` (142 KB) must only be grepped or read in slices.
4. Primary references in order: `doc/index.md` → `README.md` →
   `doc/build-workflow.md` → `doc/architecture.md`.

### Todo-first workflow + Autopilot (gated by explicit plan approval)

- **No permission prompts.** All tools are allowed (edit, bash, read, glob,
  grep, list, task, todowrite, question, webfetch, websearch, skill,
  external_directory).
- **Work outside the workspace is always allowed** without asking.
- **Todo-first workflow (mandatory):** before starting ANY work on a task:
  1. Break the task into concrete, ordered steps.
  2. Create a todo list via `todowrite` with each step marked `pending`.
  3. Present the plan to the user in the response.
  4. **STOP. Wait for explicit user confirmation** ("go", "ok", "ja", "yes",
     "do it", or similar) before executing the first step. No confirmation →
     no execution. Never infer approval from an imperative like "continue",
     "weiter" — a bare imperative ("weiter in der umsetzung") is NOT approval
     of a plan; if a plan is presented, the agent still waits for confirmation.
  5. Update todo status to `in_progress` / `completed` as work proceeds.
- **Autopilot applies ONLY AFTER the todo list is confirmed.** Once the user
  has explicitly approved the plan, execution is autonomous: never ask for
  permission again — proceed until the task is complete. Before that approval,
  autopilot is NOT in effect.

### Branch discipline (MANDATORY)

- `main` and `origin/main` track upstream (`m-vave/fm1_open`) and stay
  pristine. **Never** commit workspace work to `main`.
- All work happens on `main-feature` (the integration branch) and on
  `feature/*` branches cut from `main-feature`.
- Full rules: `doc/branch-workflow.md`.

### Subagent rules

**Autonomy (important):** The todo-first / wait-for-approval workflow applies
ONLY to the primary agent. Subagents do **NOT** wait for approval — the
primary's delegation prompt IS their "go". A subagent executes its single task
autonomously from start to finish and then returns its report. The primary
agent is responsible for waiting for the user's plan approval BEFORE spawning
subagents; once approved, spawning subagents needs no further permission.

**Delegation:**
- Escalate architectural questions upward: DEV → BUILD → ARCHITECT.
- Delegate small, focused implementation/search tasks to subagents
  (`general`, `explore`); subagents never build/test (see below).

**Task size & context limits (MANDATORY — subagents have small context windows):**
- Give each subagent ONE small, single-step task only (e.g. fix one bug, change
  one file, one focused concern). Never bundle multiple bugs, multiple files, or
  multi-step plans into a single subagent prompt.
- Break large work into a CHAIN of small subagent tasks, not one big task.
- After each subagent returns, the primary agent REVIEWS the result and verifies
  it (reads the diff / runs the relevant check) BEFORE delegating the next step.
- A subagent prompt must contain: the single concrete goal, the exact file(s),
  the specific inputs/constraints, and the required return report. Keep it short
  — assume the subagent can only hold one file's worth of context.

**Build & test ownership:**
- **Subagents must NEVER build or run tests.** This is always the job of the
  primary agent.
- When a subagent has finished implementing, the **primary agent** takes over
  building and/or running the checks.
- If build or check errors occur, the fix is delegated **back to a subagent**.
- Give subagents small, focused tasks; the primary agent always verifies the
  result (code review + build).

**MCP access:**
- **Subagents have access to GitHub MCP read-only tools** (`github_search_code`,
  `github_get_file_contents`, `github_list_commits`, `github_search_repositories`,
  etc.) for analyzing code on GitHub — especially useful for
  `m-vave/fm1_open` upstream history. Write tools (create PR, push, branch,
  issue) remain primary-only.
- **`notebooklm_devblogs` remains primary-only** — subagents must not access
  this server.
- Subagents do NOT run `git commit`, `git push`, or any git mutation.

### Definition of Done

A task is complete only when ALL of the following hold:

1. **Process proof (mandatory, non-negotiable):** the primary agent's final
   report MUST contain (a) the plan-approval quote or paraphrase from the user
   (the explicit "go"/"ok"/"ja"/"yes" message), and (b) for every implemented
   step, the `task_id` of the subagent that did the work. If implementation was
   done by the primary instead of a delegated subagent, the task is **not** done
   — redo it via delegation. The only exceptions to mandatory delegation are:
   documentation edits under `doc/`, config edits under `.opencode/`, `.vscode/`,
   `~/.config/opencode/`, and root config files (`opencode.json`,
   `AGENTS.md`, `.editorconfig`, `*.code-workspace`).
2. **Web build compiles:** `.\build.bat --web` completes and
   `build/preview/index.html` exists. This is the always-available smoke check
   (needs only Windows x64 + PowerShell + curl + tar).
3. **Firmware build compiles** (when the task touches `app/`, `sdk/`, or
   firmware-visible behaviour): `.\build.bat --package` completes and
   `build/dx7/generated/FM1_OFFICIAL_OPEN.fwsc` exists. Requires
   `FM1_SOURCE_URL` and `FM1_PI32_TOOLCHAIN` — see `doc/build-workflow.md`.
   If the toolchain is unavailable, state explicitly that this step is pending.
4. **No stray build artifacts** in the repo root or under `app/`, `web/`,
   `sdk/` (see "Ad-hoc / scratch compilation" below).
5. `pwsh doc/lint.ps1` ran without new issues.
6. `doc/log.md` appended with a changelog entry (newest first) and
   `doc/index.md` updated if a file was added, removed or renamed.

**Post-Task Sync (after each completed task):**
- Run `pwsh doc/lint.ps1` to check orphan pages, stale claims, duplicate
  entries and contradictions.
- Append to `doc/log.md`.
- If the task found or fixed a bug: record it in `doc/bugs.md` following the
  ledger rules (full record and `BUG-<n>` ID only there; reference the ID
  everywhere else).
- If a build was not run (missing toolchain/`FM1_SOURCE_URL`): explicitly
  report that the build step is pending.

## Project Overview

`fm1_open` (FM1 Open V13) is the open APP source + binary SDK for the
**M-VAVE FM-1** hardware groovebox: 8 tracks, 8 sample slots, 16 FX demos.
Language: C (C99-style, fixed-point DSP) targeting the **JieLi PI32v2** SoC
with a clang 4.0.1 r3 cross toolchain. A second build path compiles the same
engine to WebAssembly for a browser workbench.

- APP sources (GPLv3 + SDK linking exception): `app/`, `web/`
- Third-party DSP: `third_party/synth/`
- Binary engine + bootloader + tools: `sdk/`
- Hardware drivers: `app/board/`
- Docs: `README.md`, `LICENSE.md`, `THIRD_PARTY.md`, `doc/`

Full detail: `doc/architecture.md`.

## Role & Delegation Model

Primary agents form a responsibility hierarchy:

- **ARCHITECT / ARCHITECT_Openrouter** — decides and validates architectural
  questions (e.g. changes to the engine boundary, block sizes, memory layout).
- **BUILD / BUILD_Openrouter** — senior dev; considers every change
  project-wide (APP + web + packaging must stay in sync).
- **DEV / DEV_OpenRouter** — implements the assigned task, stays scoped.
- **DEV_JUNIOR_Openrouter** — small, well-defined, self-contained tasks.

## Project Main Notebook (NotebookLM devblogs)

The main notebook for this project is **WOGD-FM1 Firmware**.

- **Notebook name:** `WOGD-FM1 Firmware`
- **Notebook ID:** `a85eb2ec-cfaa-4f10-bb74-a1732bfae75c`
- **MCP Server:** `notebooklm_devblogs`
- **Config source:** `opencode.json` in this workspace root

All NotebookLM work for this project (notes, research, reports, sources)
runs through this notebook.

## Wiki Lint Workflow (runs on every Post-Task Sync)

The lint script `pwsh doc/lint.ps1` runs automatically as part of every
Post-Task Sync. It can also be run manually at any time. It checks:

1. **Orphan pages**: every file in `doc/` (excluding `archive/`) should be
   listed in `doc/index.md`. Find unlisted files with:
   `Get-ChildItem doc/*.md, doc/archive/*.md` and cross-check against
   `index.md`.
2. **Duplicate index entries**: grep `index.md` for duplicate links
   (same `./file.md` appearing more than once).
3. **Stale claims**: for each file with `stale_after:` in frontmatter,
   check if `today >= stale_after`. If stale, add a `! STALE` warning to the
   entry in `index.md` and flag for human review.
4. **Contradictions**: identify claims about the SAME feature that differ
   across files (e.g. "firmware build ✅" vs "❌"). When found, determine the
   actual truth from the code and update the outdated file.
5. **Cross-reference health**: files marked `status: deprecated` should have a
   redirect note or be moved to `archive/`.
6. **Gleanings**: after any significant analysis or debugging session, file the
   findings back into the wiki (new concept file or update to an existing one)
   — Karpathy's "good answers go back into the wiki".

## Knowledge-Sync (Docs <-> NotebookLM)

All project knowledge is kept in sync across two stores with clear roles:

1. **Docs (`doc/`)** — OKF-Wiki (primary storage). `doc/index.md` (catalog),
   `doc/log.md` (changelog), individual concept files with YAML frontmatter.
   This is the **compiled knowledge artifact** — agents navigate here first.
2. **NotebookLM (`notebooklm_devblogs`, WOGD-FM1 Firmware notebook)** —
   Consuming / disseminating layer for long-form reports, briefings and
   external reference. NOT a duplicate of the wiki. Update via
   `notebook_add_text` with a weekly `log.md` digest, or push specific
   analysis/findings as they are completed.

**Deterministic Sync Workflow:**
- After every completed task: update `doc/log.md` + `doc/index.md`.
- Weekly (or on explicit `sync-notebooklm`): push the week's `log.md` entries
  as an aggregated note to the WOGD-FM1 Firmware notebook.
- If drift is detected between stores, resolve by treating `doc/` as the
  authoritative source and updating NotebookLM from it.

## Ad-hoc / scratch compilation (no artifacts in the repo root)

Ad-hoc/scratch compile checks (single-file type-checks, throwaway "probe"
programs) are allowed during debugging, but must NEVER leave compiler
artifacts (`*.obj`, `*.o`, `*.exe`, `*.pdb`, `*.ilk`, `*.wasm`, `*.elf`,
`*.map`, `*.d`) in the workspace root or under `app/`, `web/`, `sdk/`.

- Always direct compiler output to a scratch directory, e.g. the pre-approved
  temp dir `C:\Users\marku\AppData\Local\Temp\opencode`.
- Run the compiler with the scratch dir as the working directory (or use the
  `workdir` parameter) so the CWD is never the repo root.
- Prefer the real builds (`.\build.bat --web`, `.\build.bat`) over ad-hoc
  compile-only checks — the build scripts enforce layout and symbol rules.
- Delete scratch sources and outputs when done.
- `build/` is gitignored; never force-add it.

Background: cross clang writes `.o` into the CWD when no output path is given.
Running such a command from the repo root dumps artifacts there, which would
pollute the upstream diff and can break `sdk/manifest.json` integrity checks.

## Quick facts

- Entry: `build.bat` → `sdk\Build.ps1`; web: `tools\Build-Web.ps1`.
- Modes: `build.bat` (firmware), `--web` (preview), `--package`
  (firmware + complete workbench).
- Environment: see `.env.example`; `FM1_SOURCE_URL` is mandatory for every
  build, `FM1_PI32_TOOLCHAIN` for firmware. Details: `doc/build-workflow.md`.
- Outputs: `build/preview/index.html`,
  `build/dx7/generated/FM1_OFFICIAL_OPEN.fwsc`,
  `build/official-web/FM1-Official-Open-Source.html`.
- Engine is **binary-only** (`sdk/lib/libfm1_engine.a`); audio path: DMA IRQ →
  `fm1_audio_irq()` → `fm1_engine_render()` → `fm1_output_mix()`.
- Version identity: `app/version.h`.
- Navigation: `doc/index.md`; tasks `doc/checklist.md`; bugs `doc/bugs.md`
  (`BUG-<n>`); changelog `doc/log.md`.
- Remotes: `upstream` = `m-vave/fm1_open`; `origin` = `artqcid/fm1_open`.

## Global rules

- `~/.config/opencode/rules/no-auto-commit.md`: no git commits/pushes/PRs
  without explicit user request.

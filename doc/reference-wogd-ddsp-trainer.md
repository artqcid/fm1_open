---
title: Reference — artqcid/wogd-ddsp-trainer
description: What the sibling project teaches us. Verified comparison, adoption matrix (adopt / consider / not applicable) with reasons.
status: active
stale_after: 2027-04-19
---

# Reference: `artqcid/wogd-ddsp-trainer`

Sibling project of the same owner: a **web UI for training DDSP speech-synthesis
models** (Python/PyTorch + FastAPI + Celery/Redis + Vue 3/Vite/Pinia),
Apache-2.0, status M1–M17 implemented, checks green (`ruff`, `pytest`,
`vitest`).

**Why it is comparable:** same wiki DNA — its `AGENTS.md` uses the same
navigation-first workflow, todo-gated autopilot, subagent safety rules
(one-file / abort→stop / primary diff check), TOON delegation gate,
plan-approval + task_id Definition of Done, and a `doc/` wiki with
`index.md` / `log.md` / `checklist.md` / `lint.ps1`. Our FM1 wiki was modelled
on that shape; this page records what *else* it does and what is worth taking.

**Verification:** findings below were read from `main` on 2026-10-19 via the
GitHub MCP read tools and cross-checked against the `doc/` directory listing
(21 entries). Nothing was copied — conventions only; the sibling's code is
Apache-2.0, ours is GPLv3 + linking exception, so borrowing text verbatim is
avoided deliberately.

## What the sibling has that we do not

| Sibling artifact | Size | Purpose |
| --- | --- | --- |
| `doc/bugs.md` | 177 KB | canonical bug ledger, `BUG-<id>` single source of truth |
| `doc/plan.md` | 14 KB | roadmap M1–M20, decisions, risks (meta plan) |
| `doc/implementation/mN-*.md` | ~21 files | per-milestone granular step plans |
| `doc/handbook.md` | 28 KB | German end-user manual |
| `doc/manual-test-protokoll.md` | 20 KB | scripted acceptance tests, simple → complex |
| `doc/oss-dependencies.md` | 3.5 KB | per-layer SPDX table + flagged action items |
| `doc/ui-requirements.md`, `parameter-handling.md`, `ddsp-concepts.md`, `related-work.md`, `experimental-*.md` | 6–35 KB | domain/concept pages |
| `doc/code_wiki.md` | 873 KB | **auto-generated, MCP-only** symbol index (never `read()`) |
| `doc/workspace-workflow.md` | 5.5 KB | setup/run workflow (≈ our `build-workflow.md`) |
| `scripts/sync-wiki.py` + `.githooks/post-commit` | — | auto re-index after every commit |
| `scripts/build-installer.ps1` + `start/stop-app.ps1` | — | portable Windows package, run lifecycle |

## Conventions verified in its `lint.ps1`

Exit-code contract **0 = clean, 1 = warnings, 2 = errors** — identical to ours.
Its four checks: orphan pages, duplicate index entries, stale `stale_after`,
and `status: deprecated` not living under `archive/`. Frontmatter keys in use:
`type`, `title`, `description`, `status` (`draft`/`active`/`deprecated`),
`stale_after`, `tags`, `generated.{by,at}`.

**Delta vs. ours:** we already run orphan / duplicate / stale /
contradiction checks; their deprecated→`archive/` rule is a **stricter error**
where ours is a warning, and they carry `type:` + `tags:` frontmatter we do not
use. Nothing essential is missing on our side.

## Adoption matrix

### ✅ Adopt — concrete gap in `fm1_open`

1. **Scripted manual hardware test protocol.**
   Their `manual-test-protokoll.md` turns "test on the device" into an ordered,
   repeatable acceptance list. Our `doc/test-strategy.md` Level 3 currently
   says *"not automated; performed manually"* with no script — that is the
   weakest part of our strategy (and Level 1 is blocked until
   `FM1_SOURCE_URL` exists).
   → **Deliverable:** add a `Level 3 script` section to `doc/test-strategy.md`
   (boot, play demo project, all 8 track sources, save/load project, sample
   bank write, USB/BT audio, MIDI in/out, BLE role switch, firmware update)
   with pass/fail boxes.

2. **Canonical bug ledger `doc/bugs.md`.**
   Rules worth copying verbatim in *spirit*: a bug is described **in full only
   in that file**; IDs are assigned only there; every other page references
   `BUG-<n>` only; and open bugs get a **periodic re-verification pass** whose
   corrections are written back into the same entry (append-only `history`).
   Rationale for firmware: bugs here span DSP, drivers, Flash layout and web
   build, and would otherwise be re-described inconsistently across `log.md`,
   `checklist.md` and ad-hoc notes — exactly the drift the sibling prevents.
   → **Deliverable:** new `doc/bugs.md` (template + `## Open` / `## Fixed` /
   `## Wont-fix`), linked from `doc/index.md`, referenced by `AGENTS.md`.

### 🟡 Consider — useful, but only when the project grows to need it

3. **Three-tier planning model** (`plan.md` roadmap ↔ `checklist.md` status ↔
   `implementation/*.md` granular steps). Ours has tier 2 only. Adopt tier 1
   (`doc/plan.md`) **when** a real multi-release roadmap appears; tier 3 only
   for milestone-sized work. Today's backlog fits in `checklist.md` — creating
   three files now would be the speculative structure the sibling itself only
   earned over 17 milestones.

4. **Checklist task-ID prefix + visible deferral marker.**
   Rows like `- [ ] **M14.3** …` and `- [ ] **Moved to M7** …` make status
   machine-mappable and scope cuts *visible* instead of silent. Cheap to adopt
   as `- [ ] **T-01** …` in `doc/checklist.md` once entries grow past ~15.

5. **`oss-dependencies.md`-style action items inside `doc/licensing.md`.**
   Their table has an `OSI?` column plus an explicit `## Action items` list for
   *flagged* components (e.g. a GPLv3-only fallback flagged for
   compatibility review). We have the table but no flagged-action list; the
   FM1 equivalent would hold: Newlib-derived `libc.a` terms, the identified
   micro-ecc routines, JieLi upstream terms — each with a status.
   → small addition to `doc/licensing.md`.

6. **README ↔ tasks.json drift lesson (negative example).**
   Its README documents 6 VS Code tasks while `tasks.json` has 10 — silent
   drift. Take the *rule*, not the bug: whenever `.vscode/tasks.json` changes,
   update the README/task table in the same commit.

### ❌ Not applicable — do not import

7. **`code_wiki.md` + `scripts/sync-wiki.py` + post-commit hook.** An
   873 KB auto-generated symbol index, queryable only via MCP, refreshed by a
   Python script from a git hook. We have no RAG index and no Python runtime in
   this repo; our sources are C plus a binary engine (so a generated symbol
   index would mostly describe symbols we cannot open). Requires a separate
   decision + tooling — out of scope until someone asks for it.
8. **`pytest` / `vitest` / e2e tasks, CI.** No test runtime and no CI here; a
   green task label would be misleading scaffolding (see
   `doc/test-strategy.md` baseline). The build gates *are* our tests.
9. **Installer / start-app / stop-app pipeline.** `fm1_open` produces a
   `.fwsc` image and static HTML, distributed by the vendor workbench — there
   is no app process to start or package.
10. **`clean-*` task variants.** `sdk\Build.ps1` already invalidates stale
    outputs itself ("Invalidate stale successful output before validating build
    inputs"), so a manual clean task would duplicate a safety mechanism.
11. **`formatOnSave` / extension recommendations.** We have `.editorconfig`
    and no formatter for C in this repo; enabling format-on-save would fight
    the untouched vendor bytes protected by `.gitattributes`.

## Summary for `fm1_open`

Two real wins (scripted hardware test protocol, canonical bug ledger), three
"later if it grows" items (plan.md tier, checklist task IDs, licensing action
items), one negative example (README/task drift), and five explicit
non-adoptions. Everything else in the sibling is either the workflow we already
share or Python/ML tooling that has no counterpart in a C firmware repo.

Findings go back into the wiki (Karpathy rule) — this page *is* that loop;
adoption work items live in `doc/checklist.md`.

## Update 2026-10-20 — decision 7 superseded; second sibling

**Decision 7 above ("`code_wiki.md` + sync script + hook: not applicable") no
longer holds.** Its premise was "no Python runtime in this repo". Python 3.14,
`uv` and `fastmcp` are installed on the dev machine, SQLite FTS5 with the trigram
tokenizer works, and the NotebookLM MCP is itself a Python tool. The adoption is
now planned as **group G (T-42…T-48)** in [./plan.md](./plan.md); decisions 8–11
stay valid except that a minimal CI is reconsidered as optional (T-47).

**Second sibling: `artqcid/wogd-vst-netsdrstation`** (native VST3 plugin, C++/CMake
+ Vue WebView). Read 2026-10-20 via the GitHub MCP read tools. It shares the
RAG-MCP design (`netsdr_mcp_server.py`, FastMCP, SQLite FTS5, the same four tools,
`.ragignore`, MCP-first rules in `AGENTS.md`, an `opencode.json` with the RAG
server) as a single 57 KB file adapted from an older project, whereas the trainer
refactored it into the modular `mcp_rag/` package. Additionally it uses
NotebookLM as a third knowledge store (notebook ID + source count in
`AGENTS.md`, "Docs ↔ RAG/Wiki MCP ↔ NotebookLM" sync rule), a GitHub Actions
matrix with CTest and coverage, and `clang-tidy`. What we take and what we skip
(workspace prompt duplicating `AGENTS.md`, `clang-tidy` on a JieLi clang fork,
installer) is listed in plan.md group G.

Trainer-specific additions worth noting: `.opencode/skills/` (`knowledge-first`,
`post-task-sync`, `definition-of-done`) keep `AGENTS.md` short, per-subagent RAG
permissions and `compaction` live in `opencode.json`, and the RAG tools support an
opt-in TOON output format for token-sparing results.

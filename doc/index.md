---
title: FM1 Open LLM-Wiki Index
description: Catalog of all concept pages. Load this file first, then navigate to the linked page.
updated: 2026-10-19
---

# FM1 Open — LLM-Wiki Index

**Navigation rule (AGENTS.md):** load this file first for every task. Follow the
links below to the concept page you need. Do not read source files blindly;
do not read `THIRD_PARTY.md` (142 KB) whole — grep it or read slices.

Project: **FM1 Open V13** — open APP source + binary SDK for the M-VAVE FM-1
groovebox (8 tracks, 8 sample slots, 16 FX demos), C / fixed-point DSP on the
JieLi PI32v2 SoC.

## Primary references (read in this order)

1. `doc/index.md` (this file)
2. `../README.md` — upstream-facing quick start
3. `doc/build-workflow.md` — how to build
4. `doc/architecture.md` — how the pieces fit

## Workflow & rules

| Page | What it answers |
| --- | --- |
| [./log.md](./log.md) | What changed, when. Append-only, newest first. |
| [./checklist.md](./checklist.md) | What is open right now (short task descriptions). |
| [./branch-workflow.md](./branch-workflow.md) | Where may I commit? `main` vs `main-feature` vs `feature/*`. |
| [./coding-standards.md](./coding-standards.md) | Which coding rules apply (Clean Code Developer, C/FM1 adaptations)? |
| [./test-strategy.md](./test-strategy.md) | What can actually be verified, and how? |
| [./lint.ps1](./lint.ps1) | Script that checks this wiki (orphans, duplicates, stale claims, contradictions). |
| [./bugs.md](./bugs.md) | **Canonical bug ledger** — full records only here, everything else references `BUG-<n>`. |

## Engineering

| Page | What it answers |
| --- | --- |
| [./build-workflow.md](./build-workflow.md) | Build modes, env vars, toolchain, outputs, verification. |
| [./architecture.md](./architecture.md) | APP vs binary engine, audio path, Web/WASM path, memory sections. |
| [./licensing.md](./licensing.md) | Which license applies to which file? Index into `LICENSE.md` / `THIRD_PARTY.md`. |

## References

| Page | What it answers |
| --- | --- |
| [./reference-wogd-ddsp-trainer.md](./reference-wogd-ddsp-trainer.md) | What does the sibling project `artqcid/wogd-ddsp-trainer` teach us — adopt / consider / not applicable matrix. |

## Reference (upstream, not part of this wiki)

- `../README.md` / `../README.zh-CN.md` — upstream build & licensing summary.
- `../LICENSE.md` — FM1 APP license: GPLv3 + SDK linking exception.
- `../THIRD_PARTY.md` — full third-party notices (142 KB; **grep only**).
- `../AGENTS.md` — agent rules: workflow, subagents, definition of done.

## Conventions for pages

- Frontmatter keys: `title`, `description`, `status`, `stale_after`.
- `stale_after: YYYY-MM-DD` → `doc/lint.ps1` flags the entry as `! STALE`
  once today's date is past it; then re-verify the claims against the code.
- `status: deprecated` → add a redirect note or move the file to `doc/archive/`.
- Every file added, removed or renamed under `doc/` must be reflected here
  in the same change, otherwise `doc/lint.ps1` reports an orphan.
- Findings from analysis/debug sessions go back into these pages
  ("good answers go back into the wiki").

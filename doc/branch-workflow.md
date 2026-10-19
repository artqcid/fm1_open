---
title: Branch Workflow
description: main stays pristine, main-feature is the integration branch, feature/* branches cut from and merge back into main-feature.
status: active
stale_after: 2027-04-19
---

# Branch Workflow

## Branch roles

| Branch | Role | May be committed to? |
| --- | --- | --- |
| `main` | tracks upstream `m-vave/fm1_open` — pristine mirror | **never** |
| `origin/main` | remote mirror of upstream | **never** (fast-forward from upstream only) |
| `upstream` = `m-vave/fm1_open` | source of truth for releases | never (read/pull only) |
| `origin` = `artqcid/fm1_open` | our remote | only via `main-feature` / `feature/*` pushes on explicit request |
| `main-feature` | **integration branch** for all workspace work | yes |
| `feature/*` | short-lived topic branches cut from `main-feature` | yes |

Current state (2026-10-19): `main-feature` exists locally at `b178ac4`
("Update FM1 Open to V13"), same commit as `main` / `origin/main`. Nothing of
ours has been committed yet.

## Rules

1. **`main` stays pristine.** No workspace commits, no local edits that get
   committed. Sync `main` only from upstream:
   `git pull upstream main` (then `git push origin main` if explicitly asked).
2. **Work starts from `main-feature`:**
   `git checkout main-feature`
3. **Topic branches are cut from `main-feature`, merged back into
   `main-feature` only:**

   ~~~powershell
   git checkout main-feature
   git checkout -b feature/<short-name>
   # ... work, commit ...
   git checkout main-feature
   git merge feature/<short-name>
   git branch -d feature/<short-name>
   ~~~

4. **Never merge a `feature/*` branch into `main`** and never open a PR
   against upstream without an explicit user request.
5. **`main-feature` is pushed only on explicit user request.** Same for any
   push, commit, tag or PR — global rule `no-auto-commit.md` applies.
6. Upstream sync into `main-feature` happens by merging `main` (which tracks
   upstream) into `main-feature`, so our history stays on top of upstream's.

## Naming

- `feature/<lower-case-kebab>` — one concern per branch
  (e.g. `feature/doc-wiki`, `feature/tuning-editor`).
- Branch name in commit subjects should make the scope obvious.

## Commit hygiene

- Stage only intended files: `git status` / `git diff` before every commit.
- Never stage: `build/`, scratch artifacts (`*.o`, `*.obj`, `*.exe`, `*.wasm`,
  `*.elf`, `*.map`), editor/OS droppings, secrets.
- Preserve `.gitattributes` behaviour (vendor/header/SDK bytes stay exact).
- Message style: short imperative subject, body explains *why* when non-obvious.

## Day-to-day sequence

~~~powershell
git fetch upstream
git checkout main
git merge --ff-only upstream/main        # main = upstream
git checkout main-feature
git merge main                            # bring upstream into our work
# ... work on feature/* ...
git merge feature/<name>                  # back into main-feature
pwsh doc/lint.ps1                         # wiki still consistent?
# push only when the user asks
~~~

## Why this shape

`fm1_open` is a downstream of a third-party release repo: we periodically
absorb upstream version drops (V12 → V13 happened as a single upstream commit)
while carrying our own docs, tooling and patches. Keeping `main` byte-identical
to upstream makes those drops conflict-free reviewable and keeps
`sdk/manifest.json` integrity checks meaningful.

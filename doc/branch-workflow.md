---
title: Branch Workflow
description: main mirrors upstream plus the upstream-bound commits (T-31/T-28); main-feature is the integration branch; feature/* branches cut from main-feature.
status: active
stale_after: 2027-04-19
---

# Branch Workflow

## Branch roles

| Branch | Role | May be committed to? |
| --- | --- | --- |
| `main` | upstream mirror **plus** the upstream-bound commits (T-31/T-28) | only via the upstream-bound topic branch (ff merge) |
| `origin/main` | our remote; mirrors local `main` | via `main` pushes on explicit request |
| `upstream` = `m-vave/fm1_open` | source of truth for releases | never (read/pull only) |
| `origin` = `artqcid/fm1_open` | our remote | via `main`, `main-feature` and `feature/*` pushes on explicit request |
| `main-feature` | **integration branch** for all workspace work | yes |
| `feature/*` | short-lived topic branches cut from `main-feature` | yes |

Current state (2026-10-20): `main` = `4d26685` (upstream V14) + T-31
(`24beff7`); PR #7 is open. `main-feature` carries the integration work on
top; T-28 is still pending.

## Rules

1. **`main` is the upstream mirror plus the two upstream-bound commits.**
   No other workspace work is committed there. Sync the upstream part with
   `git fetch upstream && git merge upstream/main` (not `--ff-only` once our
   commits sit on top); push `origin/main` only when explicitly asked.
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
   against upstream without an explicit user request. The standing request
   covers only the upstream-bound tasks **T-28** and **T-31** (see below).
5. **`main-feature` is pushed only on explicit user request.** Same for any
   push, commit, tag or PR — global rule `no-auto-commit.md` applies.
6. Upstream sync into `main-feature` happens by merging `main` (upstream plus
   the upstream-bound commits) into `main-feature`, so our history stays on top
   of upstream's.
7. **Upstream-bound tasks** (**T-28**, **T-31**) branch from `main`, never
   from `main-feature` — see below.

## Upstream-bound tasks (exception)

**T-28** (split `app/screen.c`) and **T-31** (named audio register constants)
are intended for upstream `m-vave/fm1_open` and must not be developed on
`main-feature`:

1. `git fetch upstream && git checkout main && git merge --ff-only
   upstream/main` (only while `main` has no own commits; otherwise
   `git merge upstream/main`).
2. `git checkout -b feature/upstream-<name>` (cut from `main`).
3. Implement + verify (both builds, lint).
4. Commit on the topic branch, then `git checkout main && git merge --ff-only
   feature/upstream-<name>` so **local `main` also carries the change**.
5. Push `main` and the topic branch to `origin` on explicit request.
6. Open a PR from `origin/feature/upstream-<name>` to `m-vave/fm1_open:main`
   (never from `main`, so later `main` commits do not alter the PR).
7. Propagate: `git checkout main-feature && git merge main` (so the change is
   also in the integration branch), then build + lint + push.

All other tasks stay on `main-feature` / `feature/*` cut from it.

### PR lifecycle (acceptance unknown)

| State | Local `main` | Command |
| --- | --- | --- |
| PR open / not accepted | upstream + our commits; keep merging upstream | `git checkout main && git merge upstream/main` |
| Merged as merge commit (SHAs kept) | fast-forward to upstream | `git fetch upstream && git merge --ff-only upstream/main` |
| Squash/rebase merge (new SHAs) | drop patch-equivalent commits | `git rebase upstream/main` (or `git reset --hard upstream/main` after `git diff upstream/main main` is empty) |
| Rejected / changes requested | keep local commits; rework on a new topic branch | `git checkout -b feature/upstream-<name>-v2 main` |

After every state change: `git checkout main-feature && git merge main` (or
`git merge upstream/main`).

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
git merge upstream/main                   # upstream + our upstream-bound commits
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
while carrying our own docs, tooling and patches. Keeping `main` limited to the
upstream mirror plus the two upstream-bound commits keeps the PR diffs minimal
and makes version drops reviewable; `sdk/manifest.json` integrity checks stay
meaningful because no SDK/vendor bytes are touched.

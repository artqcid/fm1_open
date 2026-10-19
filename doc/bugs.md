---
title: Bug Ledger (canonical)
description: Single source of truth for every bug. Full record lives ONLY here; every other page references BUG-<n>.
type: bug-ledger
status: active
stale_after: 2027-04-19
next_id: 3
---

# FM1 Open — Bug Ledger

Borrowed from `artqcid/wogd-ddsp-trainer` (see
[./reference-wogd-ddsp-trainer.md](./reference-wogd-ddsp-trainer.md)).

## Rules (non-negotiable)

1. **A bug is described in full only in this file.** `BUG-<n>` IDs are assigned
   only here — by incrementing `next_id` in the frontmatter in the same edit
   that creates the entry.
2. **Every other document references bugs by `BUG-<n>` only** — `doc/log.md`,
   `doc/checklist.md`, commit messages, subagent prompts, issues. Never
   duplicate a full bug record anywhere else.
3. **Entries are append-only.** Corrections and fixes go into the entry's
   `history:` field (newest first) — never rewrite past facts.
4. **Periodic re-verification:** open bugs are re-checked against the actual
   code on a schedule (or before a release); corrections are written back into
   the same entry, and the fact that the re-check happened is noted.
5. Bug work follows the escalation chain (DEV → BUILD → ARCHITECT) and the
   normal workflow in `AGENTS.md`; the *record* lives here, not in the chat.

## Template (copy for a new bug)

~~~markdown
## BUG-<n> - <one-line title>

- `status:` open | fixed | wont-fix
- `found:` YYYY-MM-DD
- `area:` app | web | sdk-build | doc | hardware | tooling
- `severity:` blocker | major | minor
- `affects:` <files / module / build mode>
- `description:` what is wrong, observed vs. expected
- `reproduction:` exact steps / command / device state
- `resolution:` root cause + what changed (fill when fixed)
- `history:` (append-only, newest first)
  - YYYY-MM-DD discovered …
~~~

## Open

## BUG-001 - `build.bat` fails under PowerShell 7: `Get-FileHash` not found

- `status:` open
- `found:` 2026-10-19
- `area:` tooling
- `severity:` major
- `affects:` `build.bat --web`, `build.bat --package` when the caller is
  PowerShell 7 (`pwsh`) — e.g. this agent's shell, VS Code integrated terminal
- `description:` `tools/Build-Web.ps1` (and any script using `Get-FileHash`)
  dies immediately with `CommandNotFoundException: Get-FileHash` when
  `build.bat` spawns `powershell.exe` (5.1). Expected: the build completes.
- `reproduction:` From a `pwsh` 7.6 shell: `$env:FM1_SOURCE_URL='…';
  .\build.bat --web` → fails. The same command succeeds when `powershell.exe`
  is launched directly from `pwsh`, and fails when launched via
  `cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File …"`.
- `resolution:` Root cause: `pwsh` exports its own `PSModulePath`
  (including `c:\program files\powershell\7\Modules`). A `cmd`-launched
  `powershell.exe` (5.1) inherits it, so `Get-Module -ListAvailable` resolves
  `Microsoft.PowerShell.Utility` to the **PowerShell 7** copy, which 5.1
  cannot load — auto-load fails and `Get-FileHash` disappears. Directly
  `pwsh`-spawned `powershell.exe` sanitizes `PSModulePath` to the
  Windows-PowerShell paths, which is why only the batch path breaks.
  Workaround in place: both build tasks in `.vscode/tasks.json` reset
  `PSModulePath` to
  `C:\Program Files\WindowsPowerShell\Modules;C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules`
  before calling `build.bat`; documented in `doc/build-workflow.md`.
- `history:` (append-only, newest first)
  - 2026-10-19 discovered while running `build.bat --web` from the agent
    shell; isolated via `-File` vs `-Command` and `pwsh` vs `cmd` A/B tests;
    workaround applied in `.vscode/tasks.json` (upstream `build.bat` /
    `tools/Build-Web.ps1` untouched — upstream diff kept minimal).

## Fixed

## BUG-002 - Installed toolchain `C:\JL\pi32` does not match `sdk/manifest.json`

- `status:` fixed
- `found:` 2026-10-19
- `fixed:` 2026-10-19
- `area:` tooling
- `severity:` blocker
- `affects:` firmware builds (`build.bat`, `build.bat --package`)
- `description:` `sdk/Build.ps1` verifies every file in
  `sdk/manifest.json` → `external_toolchain` by SHA-256. The install at
  `C:\JL\pi32` reports itself as `clang version 4.0.1` / `i686-pc-windows-msvc`,
  but only `bin/llvm-nm.exe` matches the pin. Mismatches:
  `bin/clang.exe` (local `d4bc97cf…` vs pinned `0ae79bfb…`),
  `bin/llvm-ar.exe` (`fc5b72c4…` vs `0b436f8d…`),
  `bin/LLVMgold.dll` (`205f648a…` vs `5af1a984…`),
  `bin/pi32v2-ld.exe` (`88de8942…` vs `c06dede1…`).
  Build stops with `External toolchain does not match the SDK: bin/clang.exe`.
- `reproduction:` `$env:FM1_PI32_TOOLCHAIN='C:\JL\pi32';
  .\build.bat --package`
- `resolution:` Root cause: the machine had a **newer packaging** of the same
  compiler family (2.5.3-era tree with extra `libc/`, `q32s-*/` dirs) instead
  of the exact build the SDK pins. The pin's provenance was found via
  `earlynerd/HLK-LD2450_FW` → `firmware/toolchain.lock.json`, which records
  the identical `clang.exe` hash and names the source: **JieLi Windows
  toolchain 2.5.2**, installer
  `https://jl-update.oss-cn-shenzhen.aliyuncs.com/2.5.2.exe`
  (SHA-256 `1ec78e33…`, Authenticode Valid — ZhuHai JieLi Technology Co.,Ltd),
  extracted **without executing it** using innoextract 1.9
  (`https://constexpr.org/innoextract/files/innoextract-1.9-windows.zip`,
  SHA-256 `6989342c…`) into `C:\JL\pi32-2.5.2`. Verified: **22/22** entries
  of `sdk/manifest.json` → `external_toolchain` match byte-for-byte.
  `FM1_PI32_TOOLCHAIN=C:\JL\pi32-2.5.2\C$\JL\pi32`; `--package` then builds
  `build/dx7/generated/FM1_OFFICIAL_OPEN.fwsc` green. The manifest pin was
  **not** modified. The pre-existing `C:\JL\pi32` is left untouched.
- `history:` (append-only, newest first)
  - 2026-10-19 **fixed.** Recipe recorded in `doc/build-workflow.md`;
    VS Code tasks, `launch.json` and `fm1_open.code-workspace` point at the
    extracted 2.5.2 toolchain.
  - 2026-10-19 discovered on the first `--package` run after
    `FM1_SOURCE_URL` became available; all five `bin/*` files hashed and
    compared against `sdk/manifest.json` lines 78-83.

## Wont-fix

_(none yet — a `wont-fix` entry must state the reason)_

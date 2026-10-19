---
title: Build Workflow
description: Build modes, required environment variables, toolchain, outputs and verification for FM1 Open.
status: active
stale_after: 2027-04-19
---

# Build Workflow

Entry point: `build.bat` → `sdk\Build.ps1` (firmware) and
`tools\Build-Web.ps1` (browser). `build.bat --help` prints the modes.

## Requirements

| Requirement | Needed for | Notes |
| --- | --- | --- |
| Windows x64 | all | README states this explicitly. |
| PowerShell | all | Scripts run with `-NoProfile -ExecutionPolicy Bypass`. |
| `curl.exe`, `tar.exe` | all | Both ship with Windows 10+; used for downloads/extraction. |
| `FM1_SOURCE_URL` | **all** | HTTPS URL of this build's source archive. **Set in this workspace (2026-10-19): `https://github.com/m-vave/fm1_open`** — accepted by the web build. |
| `FM1_PI32_TOOLCHAIN` | firmware | Folder must contain `bin/clang.exe`. **This workspace (2026-10-19): `C:\JL\pi32-2.5.2\C$\JL\pi32`** — the hash-pinned JieLi toolchain **2.5.2**, extracted with innoextract (no installer run), verified **22/22** against `sdk/manifest.json` (see BUG-002 for the recipe). |
| `FM1_WASI_SDK` | web (optional) | Reuses an extracted WASI SDK 27; otherwise the first web build downloads 518 MiB into `build/tools`. |

`FM1_SOURCE_URL` must be an HTTPS source URL **without credentials**
(`tools/Build-Web.ps1` rejects anything else). The URL is also embedded in the
generated workbench HTML as `/*FM1_SOURCE_URL*/`.

Set them per session:

~~~powershell
$env:FM1_SOURCE_URL  = 'https://github.com/m-vave/fm1_open'   # this workspace, set 2026-10-19
$env:FM1_PI32_TOOLCHAIN = 'C:\JL\pi32-2.5.2\C$\JL\pi32'  # hash-pinned 2.5.2 (BUG-002 recipe)
# optional:
$env:FM1_WASI_SDK   = 'C:\wasi-sdk-27'
~~~

> **Note (2026-10-19):** both `FM1_SOURCE_URL` and `FM1_PI32_TOOLCHAIN` are
> additionally set as **persistent user-level environment variables** with the
> values above — a bare `.\build.bat --package` works in a fresh shell without
> re-exporting them. Session exports (`$env:…`) do **not** persist; open
> terminals started before the change may still hold the old value
> `C:\JL\pi32` (deleted) — re-export or restart them.

### PowerShell 7 pitfall (BUG-001)

**Fixed 2026-10-20:** `build.bat` now prefers `pwsh`. Only when `pwsh` is
missing does it fall back to `powershell.exe` (5.1), and that branch resets
`PSModulePath` to the two Windows-PowerShell folders before launching, so
`Get-FileHash` always auto-loads. A bare `.\build.bat --web` / `--package`
from a `pwsh` shell works without a manual reset. Full record: BUG-001.

### Stale `LIB` pitfall (packaging step)

`sdk/Build.ps1` compiles `sdk/Package.cs` with `Add-Type`. A system-wide `LIB`
environment variable that still lists an **uninstalled Visual Studio**
version makes the C# compiler fail with `Ungültiger Suchpath … in
'LIB-Umgebungsvariable'` (warning treated as error). Clear it for the
session:

~~~powershell
$env:LIB = ''
~~~

`.vscode/build.ps1` (used by the VS Code firmware task) clears it
automatically, as does the `fm1:build package` launch config. The underlying
machine-environment entry is tracked as T-25.

## Build modes

| Command | Script | Output |
| --- | --- | --- |
| `.\build.bat --web` | `tools\Build-Web.ps1` | `build/preview/index.html` — browser preview (built from included C sources). |
| `.\build.bat` | `sdk\Build.ps1` | Firmware build. |
| `.\build.bat --package` | `sdk\Build.ps1 -Package` | `build/dx7/generated/FM1_OFFICIAL_OPEN.fwsc` — firmware **and** complete workbench. |
| `.\build.bat --package` + web | both | also `build/official-web/FM1-Official-Open-Source.html` (complete workbench HTML). |

Only `--web` works without the JieLi toolchain: it needs just Windows x64,
PowerShell, `curl`, `tar` and `FM1_SOURCE_URL`. That is why it is the
always-available smoke check in the Definition of Done.

## What the build actually verifies (fail-fast checks)

`sdk/Build.ps1` is not only a compiler driver — it enforces invariants and
throws when they break. Highlights:

- ELF symbol/layout checks: audio callback must live in internal SRAM
  (`0x01c00000`–`0x01c80000`), panel scan code and wiring table likewise.
- Fixed sizes: `fm1_build_id` = 32 bytes, `fm1_update_identity` = 27 bytes.
- Runtime registration tables, LVGL runtime, Bluetooth discovery symbols,
  USB MIDI runtime present; no stubbed substitutes.
- Link map audits: no unsupported link inputs/members, `libfm1_runtime.a`
  must **not** be linked, runtime heap ≥ 49152 bytes, Classic ACL pools
  1024/4096 bytes.
- Firmware startup must match the fixed ROM entry and the first packaged
  instruction.

`tools/Build-Web.ps1` additionally checks: firmware/web release versions agree
(`app/version.h` `FM1_RELEASE_VERSION` vs the firmware package metadata),
`build_id` is 64 hex chars, no unexpanded `/*FM1_...*/` placeholders in the
HTML, and `THIRD_PARTY.md` starts with `# Third-party notices`.

**Consequence:** a green build is meaningful evidence — a red one names the
invariant that broke. Do not bypass these checks.

## Version identity

- `app/version.h`: `FM1_RELEASE_VERSION` = `"V13"`,
  `FM1_UPDATE_PRODUCT` = `"FM-1_8000013"`.
- The web build fails if `FM1_RELEASE_VERSION` is missing or if firmware and
  web release versions differ.

## Toolchain integrity

- `sdk/manifest.json` → `external_toolchain` holds expected toolchain hashes
  and names `FM1_PI32_TOOLCHAIN` as the environment variable supplying the
  path.
- Verify after any toolchain change: the hashes in `manifest.json` must match
  the toolchain actually in use.
- **Checked & fixed 2026-10-19:** the machine's `C:\JL\pi32` did **not**
  match (BUG-002). The pinned toolchain is **JieLi Windows toolchain 2.5.2**:
  1. Download `https://jl-update.oss-cn-shenzhen.aliyuncs.com/2.5.2.exe`
     (SHA-256 `1ec78e3315a5987d4e82ecd002536c84240e5c832b1875beff7ce55450124ee5`,
     Authenticode Valid — ZhuHai JieLi Technology Co.,Ltd).
  2. Download `innoextract-1.9-windows.zip`
     (`https://constexpr.org/innoextract/files/innoextract-1.9-windows.zip`,
     SHA-256 `6989342c9b026a00a72a38f23b62a8e6a22cc5de69805cf47d68ac2fec993065`).
  3. Extract **without executing the installer**:
     `innoextract -d C:\JL\pi32-2.5.2 jl-2.5.2.exe`
     → toolchain lands in `C:\JL\pi32-2.5.2\C$\JL\pi32`.
  4. Verify: **22/22** entries of `sdk/manifest.json` → `external_toolchain`
     match.
  Provenance of the recipe: `earlynerd/HLK-LD2450_FW` →
  `firmware/toolchain.lock.json` (identical `clang.exe` pin).
- Do not relax the manifest pin to work around a mismatch — the hash contract
  is the SDK integrity guarantee.

## Verification checklist (run after every build-touching task)

~~~powershell
# 1. smoke check (always available)
.\build.bat --web
Test-Path .\build\preview\index.html          # must be True

# 2. firmware (needs FM1_SOURCE_URL + FM1_PI32_TOOLCHAIN)
.\build.bat --package
Test-Path .\build\dx7\generated\FM1_OFFICIAL_OPEN.fwsc   # must be True

# 3. no stray artifacts anywhere in the repo
git status --short                            # nothing but intended changes
~~~

Outputs to expect:

- `build/preview/index.html` — preview.
- `build/dx7/generated/FM1_OFFICIAL_OPEN.fwsc` — firmware image.
- `build/official-web/FM1-Official-Open-Source.html` — complete workbench.

`build/` is gitignored — never force-add it.

## VS Code tasks (`.vscode/tasks.json`)

| Task | Effect |
| --- | --- |
| `FM-1: Build Firmware Package (.fwsc)` (default, Ctrl+Shift+B) | runs `pwsh -File .vscode/build.ps1 -Mode package` → resets `PSModulePath` *inside* pwsh (BUG-001), clears `LIB` (stale-VS pitfall), sets `FM1_SOURCE_URL` + `FM1_PI32_TOOLCHAIN=C:\JL\pi32-2.5.2\C$\JL\pi32`, then `build.bat --package` |
| `FM-1: Build Web Preview` | `… -Mode web` → same resets, sets `FM1_SOURCE_URL`, reuses `FM1_WASI_SDK=C:\wasi-sdk-27` when present, then `build.bat --web` |
| `fm1:lint` | runs `pwsh doc/lint.ps1` (required by the Post-Task Sync) |
| `fm1:check-repo` | runs `pwsh tools/check-repo.ps1` (Level-4 repo hygiene; see T-27) |

The environment setup lives in **`.vscode/build.ps1`**, not in the task's
command line: a task `-Command` string would be re-parsed by two PowerShell
layers (quote loss), and an `options.env` block is defeated by the `pwsh`
startup module-path re-append — see the BUG-001 section above.

## Current workspace status (2026-10-19)

- `FM1_SOURCE_URL`: **set** — `https://github.com/m-vave/fm1_open`.
- Web build: **green** — `build/preview/index.html` (883 KB).
- `FM1_PI32_TOOLCHAIN`: **pinned 2.5.2 extracted and verified (22/22)** at
  `C:\JL\pi32-2.5.2\C$\JL\pi32` (BUG-002 fixed).
- Firmware package: **green** — `build/dx7/generated/FM1_OFFICIAL_OPEN.fwsc`
  plus `build/official-web/FM1-Official-Open-Source.html`; app image
  440 028 bytes, package fits 1 MiB (image 458 752 + VM 45 056 +
  user 536 576).
- Both Definition-of-DoD build gates now pass on this machine.
- `FM1_WASI_SDK`: **set** — `C:\wasi-sdk-27` (moved out of `build/tools`;
  T-38). Web builds re-use it instead of re-downloading.
- `LIB`: User-level override points at the installed MSVC 14.51 + Windows SDK
  paths; the stale Machine entry still needs an elevated cleanup (T-25).
- Repo hygiene: `pwsh tools/check-repo.ps1` → **green** (T-27).
- **Cleanup 2026-10-19:** the superseded **2.5.3** installation that occupied
  `C:\JL` (`pi32/`, `commtools/`, `mc/`, `LicenseViewer.exe`,
  `RequestLicense.exe`, `UpdateDector.exe`, `ver.txt`, EULA `.rtf`,
  `unins000.*` — confirmed by `ver.txt` = `2.5.3`) was deleted;
  `C:\JL` now holds only `pi32-2.5.2`. The extracted 2.5.2 tree contains its
  own complete copies of `commtools`/`mc`, so nothing was lost. Re-creation
  recipe: see "Toolchain integrity" above.

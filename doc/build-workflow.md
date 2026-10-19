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
| `FM1_SOURCE_URL` | **all** | HTTPS URL of this build's source archive. Web/package builds **stop without it**. |
| `FM1_PI32_TOOLCHAIN` | firmware | Folder must contain `bin/clang.exe` (JieLi PI32v2 clang 4.0.1 r3). README example: `C:\JL\pi32`. |
| `FM1_WASI_SDK` | web (optional) | Reuses an extracted WASI SDK 27; otherwise the first web build downloads 518 MiB into `build/tools`. |

`FM1_SOURCE_URL` must be an HTTPS source URL **without credentials**
(`tools/Build-Web.ps1` rejects anything else). The URL is also embedded in the
generated workbench HTML as `/*FM1_SOURCE_URL*/`.

Set them per session:

~~~powershell
$env:FM1_SOURCE_URL  = 'https://<host>/<path>/source-archive.tar.gz'
$env:FM1_PI32_TOOLCHAIN = 'C:\JL\pi32'   # folder containing bin\clang.exe
# optional:
$env:FM1_WASI_SDK   = 'C:\wasi-sdk-27'
~~~

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

## Current workspace status

- `FM1_SOURCE_URL`: **not set** in this environment → all builds stop early.
- `FM1_PI32_TOOLCHAIN`: **not verified** (README example path `C:\JL\pi32`
  untested here).
- Therefore: firmware build step is **pending**, not green.
  See `doc/checklist.md` → "Build & environment".

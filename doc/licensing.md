---
title: Licensing Map
description: Which license applies to which part of FM1 Open. Index into LICENSE.md and THIRD_PARTY.md.
status: active
stale_after: 2027-04-19
---

# Licensing Map

This page is an **index**, not a replacement. The authoritative texts are
[`LICENSE.md`](../LICENSE.md) (APP) and
[`THIRD_PARTY.md`](../THIRD_PARTY.md) (SDK terms, third-party notices,
contributions). `THIRD_PARTY.md` is 142 KB — **grep it or read it in slices**,
never whole.

## The four layers

| Layer | What | License | Source provided? |
| --- | --- | --- | --- |
| 1. APP / open web engine | `app/`, `web/`, `third_party/synth/`, tools scripts | **GPLv3 with the FM1 SDK linking exception** (`LICENSE.md`) | yes |
| 2. Proprietary engine | `sdk/lib/libfm1_engine.a` (M-VAVE-owned components) | **M-VAVE non-exclusive, royalty-free permission**, **FM1-device-only** | no (binary) |
| 3. Boot/update resources | `sdk/tools/pack/uboot.boot`, `ota.bin`, `cfg_tool.bin`, `boot-config.bin`, `sdk/firmware/FM-1_015.fwsc` | **Apache-2.0** | binary |
| 4. Third-party components | see table below | MIT / Apache-2.0 / BSD-2-Clause / legacy MIT-NCSA / upstream JieLi terms | per component |

Key points from `THIRD_PARTY.md`:

- The **linking exception** lets the GPLv3 APP link against the proprietary SDK
  without the SDK becoming GPL. Files carrying their own license notice keep
  their terms.
- The FM1-only condition applies **only** to the proprietary engine grant; the
  APP, third-party components and separately licensed resources keep their own
  terms.
- Redistributions must retain applicable copyright/license notices and include
  `THIRD_PARTY.md`.
- Complete packages must meet each component's corresponding-source
  obligations where they apply.
- Boot/recovery resources under Apache-2.0 require marking modifications and
  retaining NOTICE/attribution material (section 4).

## Third-party components (summary table)

Source: table at the top of `THIRD_PARTY.md` — grep it for the exact upstream
commit pins before citing.

| Component | Upstream | License |
| --- | --- | --- |
| 303 | Open303 (Robin Schmidt) | MIT |
| 808 / Pluck | DaisySP (Plaits drum/String models) | MIT |
| SVF | stmlib (Emilie Gillet) | MIT |
| FM model | MSFA (Google) / Dexed msfa | Apache-2.0 |
| PSG | emu2149 (Mitsutaka Okazaki) | MIT |
| SEA codec | sea-codec (Dani Biró) | MIT |
| Packager | jl-misctools (Andrey Grigoryev) | MIT |
| Native C runtime | `sdk/lib/libc.a`, Newlib-derived | Newlib notices (see `THIRD_PARTY.md`) |
| Native compiler runtime | `sdk/lib/libcompiler_rt.a` | legacy MIT / Univ. of Illinois-NCSA |
| micro-ecc | identified routines in `libfm1_engine.a` | BSD-2-Clause |
| FreeRTOS | JieLi SDK material | MIT |
| JieLi AC79 SDK material | upstream terms retained | Apache-2.0 where covered |
| Configuration resource | `sdk/tools/pack/cfg_tool.bin` | Apache-2.0 (official JieLi SDK) |
| Tuning contributions | PR #2 by Vikram Rojo (2026-10-17) | original file licenses retained; FM1 integration changes by M-VAVE |

Copyright for company-authored FM1 modifications, FX, arrangements and
synthesized demo samples: © 2026 珠海笙科智能科技有限公司 (M-VAVE).

## Action items (flagged components)

Pattern borrowed from `artqcid/wogd-ddsp-trainer`'s `oss-dependencies.md`:
every component that needs a human decision carries an explicit status instead
of a vague "check licenses" note. Status values: `open` · `in progress` ·
`verified` · `n/a`. Update the row **in the same change** that resolves it and
note it in [`./log.md`](./log.md).

| Component | Why flagged | Status | Next step |
| --- | --- | --- | --- |
| `sdk/lib/libc.a` (Newlib-derived routines) | Notices live deep inside `THIRD_PARTY.md` § Native C runtime; scope of the derivation for V13 not independently confirmed | `open` | Cross-check the identified routine list against the V13 binary; confirm which Newlib license text applies to our distribution |
| micro-ecc routines inside `sdk/lib/libfm1_engine.a` | Identified inside a *binary* library — identification must be re-done whenever the engine binary changes | `open` | Re-verify the identification against the current `libfm1_engine.a`; confirm BSD-2-Clause notice coverage |
| JieLi AC79 SDK material (`sdk/include/*`, tooling) | "Retains its upstream terms" — Apache-2.0 where covered, upstream copyright notice otherwise | `open` | Confirm the pinned upstream commit is still the one we distribute against |
| `sdk/tools/pack/cfg_tool.bin` | Claimed byte-identical to the official JieLi Apache-2.0 SDK distribution | `open` | Re-verify identity (hash) after any SDK refresh |
| Boot/update resources + recovery image (`uboot.boot`, `ota.bin`, `boot-config.bin`, `FM-1_015.fwsc`) | Apache-2.0 imposes attribution/NOTICE duties on redistribution | `open` | Confirm the distributed package carries the Apache-2.0 text and marks modified files as required |
| Third-party DSP pins (Open303, DaisySP, stmlib, MSFA/Dexed, emu2149, SEA, jl-misctools) | Upstream commits are pinned in `THIRD_PARTY.md`; pins drift silently when sources are updated | `open` | Re-pin check after any `third_party/synth/` change |
| Contributions (PR #2, Vikram Rojo) | Original file licenses retained; integration changes by M-VAVE 2026-10-17 | `verified` | None — recorded in `THIRD_PARTY.md` |

## What this means for agents

- **Never relicense or strip headers** on third-party or vendor files.
- Preserve `.gitattributes` semantics — vendor/header bytes and SDK sources
  must keep their exact content (integrity checks depend on it).
- Adding a new dependency: record it in `THIRD_PARTY.md` (upstream commit pin,
  license) **and** in this page's table in the same change.
- Distribution statements (e.g. the About dialog in `sdk/Update.html.in`) are
  generated from these notices — keep wording consistent.
- When unsure whether a file is APP, SDK or third-party: check its SPDX line
  (`/* SPDX-License-Identifier: ... */`) first.

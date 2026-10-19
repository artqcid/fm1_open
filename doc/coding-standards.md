---
title: Coding Standards (Clean Code Developer, FM1 edition)
description: 45 rules in 6 degrees, adapted from the Clean Code Developer ruleset for C, fixed-point DSP and the FM1 firmware/web build.
status: active
stale_after: 2027-04-19
---

# Coding Standards — Clean Code Developer (FM1 edition)

Adapted from the Clean Code Developer ruleset (6 degrees, 45 rules) for this
project: C99-style code, fixed-point DSP on the JieLi PI32v2, a binary engine
we cannot change, plus the browser/WASM build of the same engine.

**Legend for the FM1 notes:**
- 🔒 = hard rule for interrupt/DSP code (a violation breaks audio or the Flash
  transaction window).
- 🌐 = applies to `web/` and the WASM build as well as `app/`.

## Degree 1 — Red: the code must be readable (5 rules)

1. Every line we write is readable. Code that cannot be read is not written.
2. **FM1:** Every identifier says what it is: `rendered`, `block_ticks`,
   `mute_depth` — not `tmp2`. Struct fields carry units where ambiguous
   (`*_ticks`, `*_bytes`, `*_frames`).
3. Comments explain *why*, never *what*. A comment that restates the code is
   deleted; a comment that captures a Flash/IRQ constraint stays
   (see `app/board/audio.c`: "No libc calls in the DMA commit window").
4. **FM1 🔒** Section/attribute macros are part of the contract: audio-path code
   carries `FM1_AUDIO_CODE`, audio-path data `FM1_AUDIO_DATA`,
   engine-side DSP code `FM1_DSP_CODE`. Adding a function to the audio path
   without the attribute silently risks Flash-programming corruption.
5. The code is formatted consistently with the file you are editing
   (`.editorconfig` is authoritative: 4 spaces, LF, no trailing whitespace).

## Degree 2 — Orange: keep it simple (6 rules)

6. **KISS** — the simplest thing that works wins. No clever bit tricks unless
   the DSP needs them, and then with a comment.
7. **DRY** — no duplicated logic. Shared helpers live in one place; a third
   copy of an algorithm is a bug waiting to diverge.
8. **YAGNI** — no parameter, flag or code path "for later". FM1 has a fixed
   feature set (8 tracks, 8 slots, 16 FX demos).
9. **Rule of three** — duplicate code is tolerated twice; on the third
   occurrence extract a function (or a macro for fixed-point helpers).
10. **Boy Scout Rule** — leave every file cleaner than you found it: delete
    dead code, tighten an obvious `int`/`unsigned`, fix the comment you had to
    decode.
11. **🟢 Non-goal:** no premature optimization outside the render path. The
    audio IRQ budget is measured (see `struct fm1_audio_stats`), not guessed.

## Degree 3 — Yellow: structure & naming (7 rules)

12. A function does one thing and is named for it. `fm1_output_mix`,
    `groove_samples_write`, `transfer_begin` are the model.
13. Keep functions short enough to read on one screen; extract blocks, not
    lines.
14. **FM1:** no hidden global coupling. State that outlives a call is `static`
    and declared next to its users, or passed explicitly.
15. `static` by default; only what `sdk/include/*.h` declares is public.
16. Magic numbers become named constants (`FM1_BLOCK_FRAMES`,
    `PROJECT_MAGIC`, `TUNING_VERSION`).
17. 🌐 Boundary values are checked at the edges (`if (frames !=
    FM1_BLOCK_FRAMES) return -1;`), not deep inside loops.
18. **FM1:** error returns are consistent: `0` ok, negative = specific failure,
    `-2`/`-3` = busy/retry. Never invent a new convention in one function.

## Degree 4 — Green: verify (8 rules)

19. Verification is part of done — see `doc/test-strategy.md`. There is no unit
    harness here, so the real gate is: `.\build.bat --web` compiles.
20. **FM1 🔒** Never leave compiler artifacts in the repo root (AGENTS.md
    "Ad-hoc / scratch compilation" — scratch dir only).
21. **FM1 🔒** No heap allocation on the audio path or inside any
    `FM1_AUDIO_CODE` function. No `malloc`, no libc calls in the DMA commit
    window.
22. **FM1 🔒** No blocking, no retries-with-sleep, no Flash writes from
    interrupt context. Long/async operations return "busy" and the caller
    retries (`fm1_midi_send`, `fm1_ble_*` contract).
23. 🌐 Web and firmware stay in sync: a change that alters behaviour must build
    in **both** paths, because `web/` compiles the same engine sources to WASM.
24. Fix build/check errors in the smallest possible change; never silence a
    warning by deleting the check that produced it.
25. Review your own diff before handing it over: does every hunk belong to the
    task?
26. When a bug is found, record the root cause (RCA) in `doc/log.md` or the
    relevant `doc/*.md` page — "good answers go back into the wiki".

## Degree 5 — Blue: design (9 rules)

27. **SRP** — one reason to change: `app/board/audio.c` (IRQ/DMA),
    `app/audio_output.c` (mixing), `app/project.c` (Flash persistence),
    `app/screen.c` (UI) stay separated.
28. **OCP / LSP / ISP / DIP** as applicable; headers expose the smallest
    surface the callers need.
29. **Engine boundary:** the APP talks to the binary engine only through
    `sdk/include/` (`fm1_engine_render`, `fm1_engine_control.h`,
    `fm1_audio.h`). We never reach past that boundary into
    `sdk/lib/libfm1_engine.a` internals.
30. Weak hooks are the extension mechanism (`groove_tuning_capture`,
    `groove_tuning_apply`, `groove_project_apply_edit`) — use them instead of
    editing core files when an optional feature is being added.
31. Prefer the existing pattern over a new abstraction; introduce an
    abstraction only for the third concrete case.
32. **R.I.P.** — remove Repetition, Inconsistency and Pomposity (no
    framework-speak in local names, no speculative layers).
33. Fix the root cause, not the symptom. If a symptom fix is unavoidable,
    comment it and add a `doc/checklist.md` entry.
34. 🌐 Data crossing the WASM boundary (MIDI messages, sample banks, patches)
    is validated at the boundary — `web/engine/Simulator.c` and
    `sdk/Simulator.js` already reject wrong lengths; keep that property.
35. **Flash layout is an API.** `project.c` sector formats, magic values and
    CRCs are persisted data; changing them requires an upgrade path
    (`tuning_upgrade`) and a compatibility note.

## Degree 6 — Violet: professionalism & process (10 rules)

36. Read `doc/index.md` first; navigate the wiki instead of grepping blind.
37. Plan first (todo list), get explicit approval, then execute — AGENTS.md.
38. Do exactly the task you were given; escalate architecture questions
    DEV → BUILD → ARCHITECT instead of improvising.
39. Commit hygiene: only intended files, never `build/`, never scratch
    artifacts, never `.env`/secrets; the message matches the repo style.
40. **FM1 🔒** Never commit to `main`. Work lands on `main-feature` or on a
    `feature/*` branch (see `doc/branch-workflow.md`).
41. **FM1 🔒** Preserve `.gitattributes` semantics: vendor/header bytes and SDK
    sources keep their exact content — integrity checks depend on them.
42. Keep documentation truthful: every completed task appends to `doc/log.md`;
    every added/removed `doc/*.md` updates `doc/index.md`; run
    `pwsh doc/lint.ps1` after the task.
43. Say what is *not* done. A pending firmware build is reported as pending,
    never implied as green.
44. Respect the license map: APP = GPLv3 + SDK linking exception, engine =
    proprietary FM1-only grant, boot resources = Apache-2.0
    (see `doc/licensing.md`). Do not relicense third-party files.
45. Backups and power: docs must keep the user warning about backing up
    projects/samples and keeping the device powered during saves and updates —
    this is a product safety rule, not a style preference.

---

## Quick self-check before handing a task over

- [ ] Does it build? `.\build.bat --web` → `build/preview/index.html`.
- [ ] Firmware build run or explicitly reported as pending?
- [ ] Audio-path change carries `FM1_AUDIO_CODE` / `FM1_DSP_CODE`?
- [ ] No new globals, no heap on the render path, no blocking in IRQ?
- [ ] `doc/log.md` appended, `doc/index.md` updated, `pwsh doc/lint.ps1` run?
- [ ] Nothing staged from `main`?

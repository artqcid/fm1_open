---
title: Architecture
description: APP vs binary engine, the real-time audio path, the Web/WASM path, memory sections and version identity.
status: active
stale_after: 2027-04-19
---

# Architecture

`fm1_open` = open APP source (GPLv3 + SDK linking exception) + **binary-only**
DSP engine (proprietary, FM1-only permission) for the **M-VAVE FM-1**
groovebox: 8 tracks, 8 sample slots, 16 FX demos, 240×240 display.

Target: **JieLi PI32v2** SoC, clang 4.0.1 r3 cross toolchain, C99-style code,
fixed-point DSP. A second build path compiles the same engine sources to
WebAssembly for a browser workbench.

## 1. Two halves of the codebase

| Half | Location | License | Role |
| --- | --- | --- | --- |
| APP (open) | `app/`, `web/`, `third_party/synth/` | GPLv3 + SDK linking exception | UI, panel/LCD, Flash persistence, USB/BT mixing, MIDI routing, sequencing glue, tuning API |
| SDK (binary) | `sdk/lib/libfm1_engine.a`, bootloader, tools, `sdk/include/` | proprietary M-VAVE grant (FM1-only) + Apache-2.0 boot resources | instrument rendering, audio I/O, device/BT stack, packaging |
| Board drivers | `app/board/` | GPLv3 + exception | audio IRQ, GPIO, panel scan, LCD, input |

The engine is **not modifiable**: there is no engine source. Everything we can
change lives in the APP. The contract is `sdk/include/*.h`.

## 2. The engine boundary (what we may call)

From `sdk/include/fm1_engine_control.h`:

- `fm1_engine_render(int32_t *output, unsigned frames)` — **I2S/DMA interrupt
  only**, once per block, never concurrently or recursively. Fills
  `FM1_BLOCK_FRAMES` stereo frames with signed **Q23** output. Returns `0`, or
  `-1` for an invalid pointer/count without writing output. Master gain, USB/BT
  mixing and recording are the **APP's** job.
- `fm1_engine_pause()` / `fm1_engine_resume()` — nestable, brief, **control
  task only**; edit transactions.
- `fm1_engine_stop()` — stop playback during an edit transaction.
- `fm1_engine_output_level()` — `FM1_AUDIO_CODE`, reads global output level.
- `fm1_engine_stats_read(struct fm1_engine_stats *)` — `submitted`,
  `completed`, `underruns`, `midi_dropped`.

Other boundary headers: `fm1.h` (MIDI/BLE/SysEx/screen/Flash constants),
`fm1_audio.h` + `fm1_audio_io.h` (DMA half buffers), `fm1_block.h`,
`fm1_device.h`, `fm1_gpio.h`, `fm1_sea.h`.

## 3. Real-time audio path (firmware)

Constants (`sdk/include/fm1_block.h`): `FM1_SAMPLE_RATE 44100`,
`FM1_BLOCK_FRAMES 128`, `FM1_CHANNELS 2` → `FM1_BLOCK_WORDS 256`.

~~~
DMA IRQ
  └─ fm1_audio_irq()            app/board/audio.c   (FM1_AUDIO_CODE, interrupt)
       ├─ interval/overrun gate  → statistics (short_intervals, overruns)
       ├─ fm1_engine_render(rendered, FM1_BLOCK_FRAMES)   ← binary engine
       ├─ fm1_output_mix(rendered)                        ← app/audio_output.c
       └─ copy into transmit[2][FM1_BLOCK_WORDS] (DMA half, 32-byte aligned)
~~~

Notable constraints visible in the code:

- **No libc calls in the DMA commit window** (including during Flash writes) —
  the copy is a hand-written loop plus a `csync` barrier.
- Timing is measured against `FM1_AUDIO_TIMER_COUNT`; blocks outside ±1/8 of
  the nominal interval count as `short_intervals` / `overruns`.
- `fm1_audio_suspend()` / `mute_depth` gates rendering during mute.
- `fm1_output_mix()` (`FM1_AUDIO_CODE`) mixes USB PCM and Bluetooth PCM into
  the engine output with a limiter (`limit(int64_t)`), and handles USB
  recording.
- Sections: `FM1_AUDIO_CODE` → `.volatile_ram_code`,
  `FM1_AUDIO_DATA` → `.volatile_ram.fm1` — **audio code and every callee must
  be safe during Flash programming**. Large zero-initialized working buffers
  stay in ordinary internal BSS.
- Diagnostics: `struct fm1_audio_stats` (`blocks`, `short_intervals`,
  `overruns`, `peak_ticks`) read from the control task.

## 4. APP modules

| Module | Responsibility |
| --- | --- |
| `app/board/audio.c` | DMA IRQ, block timing, render/mix orchestration |
| `app/board/panel.c`, `device.c`, `lcd.inc` | panel scan, device/IRQ helpers, LCD |
| `app/audio_output.c` | USB/Bluetooth mixing, recording, output limiter |
| `app/screen.c` | UI pages (OVERVIEW, STEPS, FM_EDIT, MIX, EFFECTS, …) |
| `app/project.c` | Flash project/settings/tuning persistence, CRCs, upgrade paths |
| `app/samples.c` | sample bank staging, CRC32, bind/unbind |
| `app/transfer.c` | SysEx transfer protocol (`fm1_app_sysex`) |
| `app/presets.c` | factory projects/scenes, FM program tables |
| `app/instrument.h` | **per-track tuning API** and project/instrument structs |
| `app/synth/*.h` | voice/parameter declarations for the DSP side |
| `app/version.h` | `FM1_RELEASE_VERSION` = `"V13"`, `FM1_UPDATE_PRODUCT` = `"FM-1_8000013"` |

### Per-track tuning API (`app/instrument.h`)

- `GROOVE_TRACKS = 8`, `GROOVE_TUNING_KEYS = 12`,
  `struct groove_tuning { int8_t main[12], alt[12]; }` (24 bytes, asserted).
- `groove_tuning_set/get(track, …)` — `0` ok, `<0` invalid.
- `groove_tuning_capture/apply(t[GROOVE_TRACKS])` — all-or-nothing apply;
  these are **weak** symbols (`app/tuning_hook.h`), so an optional override
  can be linked in without touching core files.
- Persisted per project slot in Flash with magic/CRC
  (`TUNING_MAGIC`, `TUNING_VERSION = 2`), plus a journal for safe commits.
- Source selection: `groove_source_type(track)` /
  `groove_source_set(track, type)` with `enum groove_source`
  (DX7, 303, 808, PSG, PLUCK, SAMPLE, …).
- Clocks: `GROOVE_CLOCK_INTERNAL` / `GROOVE_CLOCK_MIDI`;
  project layout `GROOVE_PROJECT_SLOTS = 16`, `GROOVE_PROJECT_BYTES = 4064`;
  sample bank `GROOVE_SAMPLE_OFFSET = 69632`, `GROOVE_SAMPLE_BYTES = 466944`.

## 5. Web / WASM path

Same engine sources, different platform shim:

- `web/engine/` — `Simulator.c` (WASM entry points `sim_*`),
  `sequencer.c`, `effects.c`, `edit.c`, `sound.c`, `tuning.c`.
- `web/synth/` — third-party DSP compiled for the browser: DX7 core
  (`dx7*.c`), ADSR, mixer, PSG, sample drum, SEA codec, demo bank.
- Runtime/UI: `sdk/Simulator.js` (workbench page/preview host),
  `sdk/Samples.js` (sample library, SEA5 encoding in a worker),
  `sdk/WebUpdate.js` (browser firmware update over WebMIDI), `sdk/Update.html.in`.
- Boundary validation: WASM-facing calls validate message/length (patch 156,
  timbre 223, sample bank 512…462848, project ≤ 4280, etc.). Wrong lengths
  throw before reaching the engine.
- Built by `tools\Build-Web.ps1`; it cross-checks the firmware package's
  `release_version` / `build_id` against `app/version.h`.

**Rule:** any behavioural change must build on **both** paths — the web build
is the always-available regression net.

## 6. Memory / section rules

- `.volatile_ram_code`, `.volatile_ram.fm1` — audio-path code/data that stays
  valid while Flash is being programmed.
- Audio callbacks must sit in internal SRAM `0x01c00000`–`0x01c80000`;
  panel scan code and wiring table likewise — enforced by `sdk/Build.ps1`.
- Runtime heap must be ≥ 49152 bytes; Classic ACL pools 1024/4096 — enforced.
- No heap on the render path (see `doc/coding-standards.md`).

## 7. Threading model (as observed)

- **DMA/I2S interrupt** — render + mix + commit (`fm1_audio_irq`).
- **Control task** — MIDI/BLE/SysEx, UI, edit transactions
  (`fm1_engine_pause/resume` around edits); never in ISR.
- **Bluetooth task** — BT audio/MIDI configuration and role changes;
  `fm1_ble_*` commands are asynchronous: `0` queued, `-1` invalid, `-2` busy.

## 8. Known open points (see `doc/checklist.md`)

- Toolchain path and `FM1_SOURCE_URL` unverified in this workspace.
- `FM1_HOST_TEST` exists in `sdk/include/fm1.h` (builds `FM1_AUDIO_CODE`/
  `FM1_AUDIO_DATA` as no-ops) — a possible seed for host-side checks, not yet
  wired up.

---
title: "T-28 — screen.c split: design & implementation plan"
status: active
stale_after: 2027-04-01
---

# T-28 — `app/screen.c` split: design & implementation plan

> **Branch:** `feature/screen-split` (cut from `main`, upstream-bound PR)  
> **Prerequisite:** T-39 done (code index at `doc/code_index.md`).  
> **Verification:** `.\build.bat --web` + `.\build.bat --package` green; no
> behaviour change; WASM harness (`node tests/wasm/fm1_wasm_test.mjs`) passes.

---

## 1  Motivation & open-source goals

`app/screen.c` is **2,994 lines** in a single translation unit.  It holds four
logically distinct responsibilities:

| Responsibility | Lines (approx) |
|---|---|
| GFX primitives — pixel fills, text, font tables, DMA band state | 1–520 |
| Per-page draw functions — one per UI page | 522–1,377 |
| Render/paint loop — frame capture, dispatcher, DMA flush | 1,378–1,773 |
| Input state machine — `apply_controls`, navigation helpers | 1,774–2,753 |
| Web simulator interface — `groove_screen_web_*` | 2,754–2,993 |

This creates **three problems** for an open-source hardware project:

1. **Continuous development** — a bug in the BLE page requires reading/editing
   around 2,500 unrelated lines to find the relevant 80-line block.
2. **Custom firmware** — developers who want to build a completely different UI
   (e.g. a single-track sampler, a minimal MIDI controller, a game) cannot
   selectively reuse the drawing primitives without also taking on the full FM1
   page system.
3. **Build** — a single-character change anywhere in the file triggers a
   full 2,994-line recompilation.

The goal is to produce a **layered split** that addresses all three:

- GFX primitives become a **reusable drawing kit** (custom firmware entry
  point) declared in `screen_gfx.h`.
- The page contract is formally documented in `screen_page.h` — a header with
  no companion `.c` that describes exactly what every page module must provide.
- Each page group lives in its own `.c` file, independently changeable.
- The input state machine is isolated in `screen_control.c`.
- The web simulator adapter is isolated in `screen_web.c`.

---

## 2  Layer architecture

```
 ┌──────────────────────────────────────────────────────────┐
 │  app/screen_overview.c   app/screen_fm.c   …             │  ← concrete pages
 │  app/screen_control.c (input)  app/screen_web.c          │
 │        ↑ implements contracts declared by ↓              │
 │                   app/screen_page.h                      │  ← mid-layer contract
 ├──────────────────────────────────────────────────────────┤
 │  app/screen.c  (slimmed: dispatch + public API)          │  ← FM1 framework
 │  shared state, frame capture, render loop, paint_flush   │
 │        ↑ uses ↓                                          │
 │                   app/screen_internal.h                  │  ← internal state
 ├──────────────────────────────────────────────────────────┤
 │  app/screen_gfx.c  (pixel layer)                         │  ← reusable drawing kit
 │        ↑ declared by ↓                                   │
 │                   app/screen_gfx.h          ← PUBLIC     │
 ├──────────────────────────────────────────────────────────┤
 │  SDK:  fm1_screen_submit / fm1_controls_read / fm1_led_* │  ← hardware binary
 └──────────────────────────────────────────────────────────┘
```

### Layer 0 — SDK hardware (binary)
`fm1_screen_*`, `fm1_controls_*`, `fm1_led_*`, `groove_*`.  Unchanged.

### Layer 1 — GFX primitives (`screen_gfx.h` / `screen_gfx.c`)
**Stable, reusable, hardware-adjacent.**  Owns the DMA pixel buffer,
the 5×7 font, and all stateless draw operations.  Has no knowledge of
pages, tracks or the engine.  A developer writing custom firmware **only
needs this layer** to put pixels on the 240×240 display.

`screen_gfx.h` is the **one header** a custom firmware project includes to
get the full drawing toolkit without any FM1 page machinery.

### Layer 2 — FM1 screen framework (`screen.c` slimmed + `screen_internal.h`)
Navigation state machine entry, frame capture (`draw()`), page dispatcher
(`draw_page_body()`), `paint_flush()`, and all `groove_screen_*` public API
functions.  Declares shared state as `extern` in `screen_internal.h` so that
page files can read it without coupling to each other.

### Mid-layer contract (`screen_page.h`)
A **documentation header** — no `.c`.  Declares the prototype of every
per-page draw function and the prototype of every per-page helper needed by
the framework.  Reading this single file answers "which files implement which
pages?" and "what is the calling convention?".  For custom firmware: replace
any subset of page `.c` files and keep everything else.

### Layer 3 — Concrete page modules (`screen_*.c`)
Each page group is one `.c` file.  It includes `screen_internal.h` (shared
state) and `screen_gfx.h` (draw API).  It provides the draw functions
declared in `screen_page.h`.  It has no knowledge of other pages.

---

## 3  File inventory

### New headers

| File | Role | Includes |
|---|---|---|
| `app/screen_gfx.h` | **Public** draw API, color macros | `<stdint.h>`, `fm1.h` |
| `app/screen_internal.h` | Internal shared state (`extern` vars, page enum, `draw_cache`, frame vars) | `screen_gfx.h`, `instrument.h`, `fm_patch.h`, `fm1_engine_control.h` |
| `app/screen_page.h` | Page contract: all per-page draw function prototypes | `screen_internal.h` |

### Modified source

| File | After split | Lines (est.) |
|---|---|---|
| `app/screen.c` | Orchestrator: color enum, state defs, `draw()`, `draw_page_body()`, `draw_page()`, `paint_flush()`, `groove_screen_init()`, `groove_screen_control()`, `groove_screen_tap/preset/open/mmc/snapshot()` | ~300 |

### New sources

| File | Origin (screen.c lines) | Content | Lines (est.) |
|---|---|---|---|
| `app/screen_gfx.c` | 7–75, 35–41, 42–520 (partial) | `font[]`, `punctuation[]`, paint state, `screen_fill()`, `screen_text()`, `screen_line()`, `screen_rect()`, `screen_number()`, `screen_decimal()`, `screen_note_name()`, `screen_signature()`, `web_knobs[]`, `screen_knob()` | ~220 |
| `app/screen_overview.c` | 153–154, 522–601, 1205–1265 | `colors[]`, `white_keys[]`, `screen_overview_draw()`, `screen_leds()` | ~180 |
| `app/screen_seq.c` | 188–201, 602–695 | `seq_pages[]`, `step_first()`, `step_knob()`, `step_adjust()`, `sequence_length_adjust()`, `screen_seq_draw()` | ~165 |
| `app/screen_fm.c` | 157–172, 323–335, 696–803, 804–946, 2918–2993 | `fm_pages[]`, `fm_parameter()`, `parameter_page()`, `screen_fm_draw()`, `tone_part/slot/parameter/label()`, `track_lfo_draw()`, `screen_tone_draw()`, `algorithms[]`, `algorithm_draw()` | ~410 |
| `app/screen_mix.c` | 948–972 | `screen_mix_draw()` | ~30 |
| `app/screen_effects.c` | 1159–1204 | `screen_effects_draw()` | ~50 |
| `app/screen_project.c` | 156, 233–261, 1064–1157, 1361–1376 | `edit_keys[]`, `edit_character()`, `project_refresh()`, `preset_refresh()`, `screen_project_draw()`, `screen_preset_draw()`, `screen_name_draw()`, `screen_boot_draw()` | ~250 |
| `app/screen_ble.c` | 973–1063 | `radio_line()`, `screen_ble_draw()` | ~95 |
| `app/screen_edit.c` | 174–177, 1267–1360 | `actions[]`, `ACTION_COUNT`, `screen_edit_draw()` | ~115 |
| `app/screen_control.c` | 280–352, 1712–1773, 1835–2583 | `clamp()`, `move_step()`, `navigation_mode()`, `encoder_active()`, `read_encoders()`, `fm_encoder_delta()`, `open_subpage()`, `post()`, `release_keys[_except]()`, `preset_load()`, `toggle_step()`, `select_track()`, `apply_controls()` | ~820 |
| `app/screen_web.c` | 2754–2916 | `web_targets[]`, `web_target/alias()`, all `groove_screen_web_*()`, `groove_screen_snapshot()` | ~200 |

**Total after split: ~2,835 lines across 11 sources + 3 headers** (vs. 2,994 in one file).

---

## 4  Header design

### 4a  `screen_gfx.h` (public — custom firmware entry point)

```c
/* SPDX-License-Identifier: GPL-3.0-only WITH GPL-3.0-linking-exception */
/*
 * screen_gfx.h — FM1 pixel drawing kit.
 *
 * REUSE CONTRACT: This header and its companion screen_gfx.c are designed
 * to be portable.  They depend only on <stdint.h>, <string.h>, and the
 * fm1_screen_* hardware API from fm1.h.  Custom firmware that wants to use
 * the display without the FM1 page system needs only these two files.
 *
 * All functions write into the internal DMA pixel buffer; the buffer is
 * flushed to hardware via paint_flush() in screen.c.
 */
#pragma once
#include <stdint.h>

/* Paint state (defined in screen_gfx.c; read by paint_flush in screen.c). */
extern uint16_t screen_paint_pixels[];
extern uint8_t  screen_paint_left[], screen_paint_right[];
extern unsigned screen_paint_rendering, screen_paint_top,
                screen_paint_next, screen_paint_x, screen_paint_end;
extern uint32_t screen_paint_priority;

/* Pixel fill — the primitive that all other draw calls reduce to. */
void screen_fill(unsigned x, unsigned y, unsigned w, unsigned h, uint16_t color);

/* 5×7 proportional text (scale 1 = 6×8 px per glyph). */
void screen_text(unsigned x, unsigned y, const char *s,
                 unsigned scale, uint16_t fg, uint16_t bg);

/* Geometric primitives. */
void screen_line(int x0, int y0, int x1, int y1, uint16_t color);
void screen_rect(unsigned x, unsigned y, unsigned w, unsigned h, uint16_t color);

/* Formatted number — decimal(out, value, digits) writes into a char[12]. */
void screen_decimal(char out[12], int value, unsigned digits);
void screen_number(unsigned x, unsigned y, int value, unsigned digits,
                   unsigned scale, uint16_t fg, uint16_t bg);
void screen_note_name(unsigned note, char out[12]);

/* 32-bit Bernstein hash — used for dirty-cache comparisons (no crypto). */
uint32_t screen_signature(uint32_t seed, const void *bytes, unsigned n);

/* Four-column encoder knob strip.  Writes label/value into web_knobs[]
 * (used by the browser simulator) and paints into the bottom 32 px. */
void screen_knob(unsigned col, const char *label,
                 const char *value, uint16_t color);

/* web_knobs[col][0] = label, [1] = value (written by screen_knob). */
extern char screen_web_knobs[4][2][16];
```

### 4b  `screen_internal.h` (internal — not for custom firmware)

Contains:
- Color constants (`BACK`, `PANEL`, `TEXT`, `ACCENT`, `DIM`, `GREEN`, `AMBER`)
- Page enum (`OVERVIEW … ARP_EDIT`, `STARTUP`)
- Button enum (`OCT_DOWN … REC`)
- `struct draw_cache` definition
- `extern` declarations for ALL shared state variables:
  - Navigation state: `track`, `cursor`, `page`, `drum`, `op`, `fm_group`, `writing`,
    `octave`, `glo_down/used`, `music_page`, `subpage_return`, `seq_page`, `arp_page`,
    `effects_page`, `advanced_edit`, `step_follow`
  - Key/encoder: `previous_buttons`, `previous_keys`, `blocked_keys`, `key_note[]`,
    `key_track[]`, `operator_page[][]`, `operator_selected[]`, `lfo_page[]`,
    `tone_pages[][]`, `drum_parts[]`, `encoder_direction[]`, `encoder_speed[]`
  - BLE: `ble_device`, `ble_view`, `ble_action`, `ble_result`, `ble_forget`,
    `ble_stage`, `ble_seconds`, `ble_stage_since`, `ble_was_linked`
  - Project/preset: `project_result`, `project_slot`, `project_factory`,
    `name_cursor`, `preset_slot`, `preset_bank`, `preset_loaded`,
    `preset_current_slot/bank`, `preset_project_revision`, `project_stored[]`,
    `project_stored_result`, `project_drawn_revision`, `project_reload`,
    `project_operation`, `project_return`
  - Edit/rec: `edit_down`, `edit_long`, `edit_ms`, `seq_down`, `seq_ms`,
    `arp_down`, `arp_long`, `arp_ms`, `rec_down`, `rec_used`, `rec_ms`,
    `rec_before_press`, `retry_reset`
  - Misc: `source_preview`, `source_result`, `action`, `action_confirm`,
    `tone_clip_ready`, `tone_clip`, `boot_active`, `boot_phase`, `boot_started`,
    `notice`, `notice_until`, `master_notice[]`, `transport_seen`,
    `selected_note`, `octave`, `frame_ms`, `glo_ms`, `project_keys`
  - Frame snapshot: `frame_views[]`, `frame_patch[]`, `frame_controls`,
    `frame_ble`, `frame_radio`, `frame_radio_flags`, `frame_radio_role`,
    `frame_devices[]`, `frame_step_notes[]`, `frame_effects[]`, `frame_time`
  - Cache: `saved_cache`, `band_cache`, `*cache`, `led_cache`, `button_led_cache`
  - MIDI activity: `midi_seen[]`, `midi_until[]`, `midi_active[]`
  - Health: `health_output`, `health_at`, `health_underruns`, `health_dropped`,
    `health_adapted`, `health_dma`

### 4c  `screen_page.h` (mid-layer contract)

```c
/* SPDX-License-Identifier: GPL-3.0-only WITH GPL-3.0-linking-exception */
/*
 * screen_page.h — Page module contract.
 *
 * Every page module (screen_overview.c, screen_fm.c, …) provides:
 *
 *   1. A draw function:  screen_FOO_draw(void)
 *      Called from draw_page_body() in screen.c on every render tick.
 *      MUST read only from frame_* snapshot variables (see screen_internal.h),
 *      never call engine API directly.
 *      MUST write pixels only via screen_gfx.h primitives.
 *
 *   2. For complex pages, per-page helpers called from apply_controls()
 *      in screen_control.c.  These ARE allowed to call engine API.
 *
 * To add a new page to a custom firmware:
 *   - Add a new constant to the page enum in screen_internal.h.
 *   - Create a screen_NEWPAGE.c implementing screen_NEWPAGE_draw().
 *   - Add the call in draw_page_body() in screen.c.
 *   - Add input handling in apply_controls() in screen_control.c.
 *   - Declare the draw function prototype here.
 */
#pragma once
#include "screen_internal.h"

/* --- draw functions (called from draw_page_body in screen.c) ----------- */
void screen_overview_draw(void);       /* OVERVIEW page                    */
void screen_seq_draw(void);            /* STEPS page                       */
void screen_fm_draw(void);             /* FM_EDIT / FM_ENV / FM_LFO pages  */
void screen_tone_draw(void);           /* TONE_EDIT / FM_ENV (non-DX7)     */
void screen_lfo_draw(void);            /* FM_LFO (non-DX7 track)           */
void screen_mix_draw(void);            /* MIX page                         */
void screen_effects_draw(void);        /* EFFECTS page                     */
void screen_project_draw(void);        /* PROJECT page                     */
void screen_preset_draw(void);         /* PRESET_BROWSER page              */
void screen_name_draw(void);           /* NAME page                        */
void screen_boot_draw(void);           /* STARTUP splash                   */
void screen_ble_draw(void);            /* BLE page                         */
void screen_edit_draw(unsigned visible); /* STEP_EDIT / RHYTHM / ACTIONS / ARP_EDIT */

/* --- framework helpers (called from screen.c and screen_control.c) ----- */
void   screen_leds(const struct groove_view *v, unsigned visible); /* LED matrix */
void   screen_draw_header(const struct groove_view *v);            /* track header bar */
unsigned screen_step_first(const struct groove_view *v);
void   sequence_length_adjust(int delta);  /* also called from screen_web.c */

/* --- control helpers (called from screen_control.c) -------------------- */
int  screen_preset_load(unsigned start, uint32_t now);
void screen_toggle_step(unsigned step);
int  screen_release_keys(void);
int  screen_release_keys_except(uint32_t keep);
void screen_select_track(int delta);
void screen_open_subpage(unsigned target);
int  screen_post(uint8_t cmd, uint8_t a, uint8_t b, unsigned bytes);
```

---

## 5  Build system changes (`sdk/Build.ps1`)

Three existing patterns reference `app/screen.c` by exact name.  After the
split, **all** `app/screen*.c` files (including the slimmed `screen.c` and all
new `screen_*.c`) share the same compiler options.

```powershell
# BEFORE (three separate blocks in Build.ps1):

if ($source -in @('app/screen.c','app/transfer.c','app/midi_router.c')) {
    $options += '-fno-lto'
}
if ($source -in @('app/project.c','app/transfer.c','app/samples.c','app/screen.c',
        'app/presets.c','app/midi_router.c','app/fm_factory.c','app/fm_library.c')) {
    $options += '-Oz'
}
if ($source -eq 'app/screen.c') { $options += '-fno-inline-functions' }

# AFTER:

if ($source -in @('app/transfer.c','app/midi_router.c') -or
        $source -match '^app/screen') {
    $options += '-fno-lto'     # keep user-entry symbols visible to linker
}
if ($source -in @('app/project.c','app/transfer.c','app/samples.c',
        'app/presets.c','app/midi_router.c','app/fm_factory.c','app/fm_library.c') -or
        $source -match '^app/screen') {
    $options += '-Oz'          # code-size optimisation for non-DSP modules
}
# -fno-inline-functions: only on the two largest remaining translation units.
# Smaller page files benefit from within-TU inlining; do not suppress it.
if ($source -match '^app/screen(\.c|_control\.c)$') {
    $options += '-fno-inline-functions'
}
```

`tools/Build-Web.ps1`: no change — it globs `app/**` recursively and has no
per-source flag overrides for screen.c.

---

## 6  Renaming convention

All functions that move from `static` scope to translation-unit boundary get
a module prefix:

| Original (static) | New (extern, in header) | Module |
|---|---|---|
| `paint_fill(x,y,w,h,c)` | `screen_fill(...)` | screen_gfx |
| `text(x,y,s,sc,fg,bg)` | `screen_text(...)` | screen_gfx |
| `line(x0,y0,x1,y1,c)` | `screen_line(...)` | screen_gfx |
| `frame(x,y,w,h,c)` | `screen_rect(...)` | screen_gfx |
| `number(x,y,v,d,sc,fg,bg)` | `screen_number(...)` | screen_gfx |
| `decimal(out,v,d)` | `screen_decimal(...)` | screen_gfx |
| `note_name(n,out)` | `screen_note_name(...)` | screen_gfx |
| `signature(seed,b,n)` | `screen_signature(...)` | screen_gfx |
| `knob(col,lbl,val,c)` | `screen_knob(...)` | screen_gfx |
| `web_knobs[4][2][16]` | `screen_web_knobs[4][2][16]` | screen_gfx |
| `header(v)` | `screen_draw_header(v)` | screen.c |
| `leds(v,vis)` | `screen_leds(v,vis)` | screen_overview.c |
| `step_first(v)` | `screen_step_first(v)` | screen_seq.c |
| `overview(views)` | `screen_overview_draw()` | screen_overview.c |
| `steps(v)` | `screen_seq_draw()` | screen_seq.c |
| `fm_draw(patch,ctrl)` | `screen_fm_draw()` | screen_fm.c |
| `tone_draw(patch)` | `screen_tone_draw()` | screen_fm.c |
| `track_lfo_draw()` | `screen_lfo_draw()` | screen_fm.c |
| `mix_draw(views)` | `screen_mix_draw()` | screen_mix.c |
| `effects_draw()` | `screen_effects_draw()` | screen_effects.c |
| `project_draw()` | `screen_project_draw()` | screen_project.c |
| `preset_draw()` | `screen_preset_draw()` | screen_project.c |
| `name_draw()` | `screen_name_draw()` | screen_project.c |
| `boot_draw()` | `screen_boot_draw()` | screen_project.c |
| `draw_ble(ble)` | `screen_ble_draw()` | screen_ble.c |
| `edit_page_draw(vis)` | `screen_edit_draw(vis)` | screen_edit.c |
| `release_keys()` | `screen_release_keys()` | screen_control.c |
| `release_keys_except(k)` | `screen_release_keys_except(k)` | screen_control.c |
| `select_track(d)` | `screen_select_track(d)` | screen_control.c |
| `toggle_step(s)` | `screen_toggle_step(s)` | screen_control.c |
| `preset_load(s,t)` | `screen_preset_load(s,t)` | screen_control.c |
| `open_subpage(t)` | `screen_open_subpage(t)` | screen_control.c |
| `post(c,a,b,n)` | `screen_post(c,a,b,n)` | screen_control.c |

Functions that stay `static` (not called across TU boundaries): `paint_mark`,
`clamp`, `step_knob`, `step_adjust`, `fm_parameter`, `fm_encoder_delta`,
`parameter_page`, `algorithm_draw`, `tone_part`, `tone_slot`, `tone_parameter`,
`tone_label`, `radio_line`, `project_refresh`, `preset_refresh`,
`edit_character`, `move_step`, `navigation_mode`, `encoder_active`,
`read_encoders`, `web_target`, `web_alias`.

---

## 7  Exact implementation steps

Each step must leave `.\build.bat --web` green before the next step starts.
One git commit per step on `feature/screen-split`.

### Step 0 — Branch setup
```powershell
git checkout main
git pull upstream main          # must be at V14 (4d26685) or later
git checkout -b feature/screen-split
```

### Step 1 — Create `app/screen_gfx.h` and `app/screen_internal.h` and `app/screen_page.h`
Three new headers only; no `.c` changes yet.
- `screen_gfx.h`: as designed in §4a.
- `screen_internal.h`: includes from §4b; include guards; `#include "screen_gfx.h"`;
  forward-declare `struct groove_view`, `struct groove_preset`, etc. before
  the extern block, or include `instrument.h` + `fm_patch.h` + `fm1_engine_control.h`.
- `screen_page.h`: as designed in §4c.
- In `screen.c`: add `#include "screen_page.h"` at the top (after existing includes).
  All existing `static` declarations continue to compile unchanged.

**Verify:** `.\build.bat --web` green.  
**Commit:** `screen: add layered headers (screen_gfx.h, screen_internal.h, screen_page.h)`

### Step 2 — Extract `app/screen_gfx.c`
Move from `screen.c`:
- Lines 7–14: color enum → becomes named constants in `screen_gfx.c` (still available
  via `screen_internal.h` which re-declares them for page modules).
- Lines 17–75: `font[]`, `punctuation[]` (remain `static`, not in any header).
- Lines 35–41: paint state vars (renamed per §6, definitions in `screen_gfx.c`,
  `extern` declarations already in `screen_gfx.h`).
- Lines 42–75: `paint_mark()` (remains `static`, only called by `screen_fill`).
- Lines 51–75: `screen_fill()` (renamed from `paint_fill`).
- Lines 77–148: `screen_text()`.
- Lines 354–371: `screen_decimal()`.
- Lines 373–378: `screen_number()`.
- Lines 380–390: `screen_note_name()`.
- Lines 392–397: `screen_signature()`.
- Lines 399–404: `screen_rect()`.
- Lines 406–439: `screen_line()`.
- Lines 439: `web_knobs[]` definition.
- Lines 441–462: `screen_knob()`.

`screen.c` retains `screen_draw_header()` (needs frame state) — see step 8.
`header()` is NOT moved in this step; it is renamed inline.

**Verify:** `.\build.bat --web` green.  
**Commit:** `screen: extract pixel drawing layer into screen_gfx.c`

### Step 3 — Extract `app/screen_overview.c`
Move from `screen.c`:
- Lines 153–154: `colors[]`, `white_keys[]` (static, private to this module).
- Lines 173: `source_names[]` — used in `draw_page_body` knob labels AND in
  `apply_controls`.  Keep definition here; declare `extern const char *const
  source_names[]` in `screen_internal.h`.
- Lines 522–601: `screen_overview_draw()` (rename from `overview`).
- Lines 1205–1265: `screen_leds()` (rename from `leds`).

**Verify:** `.\build.bat --web` green.  
**Commit:** `screen: extract overview page and LED matrix into screen_overview.c`

### Step 4 — Extract `app/screen_seq.c`
Move from `screen.c`:
- Lines 188–201: `seq_pages[]`, `step_first()` → `screen_step_first()`.
- Lines 602–615: `step_knob()` (static).
- Lines 617–629: `step_adjust()` (static).
- Lines 631–637: `sequence_length_adjust()` (extern — also called from
  `screen_web.c`; declare in `screen_page.h`).
- Lines 639–695: `screen_seq_draw()`.

**Verify:** `.\build.bat --web` green.  
**Commit:** `screen: extract sequencer page into screen_seq.c`

### Step 5 — Extract `app/screen_fm.c`
Move from `screen.c`:
- Lines 157–172: `fm_pages[]` (static).
- Lines 323–335: `fm_encoder_delta()`, `parameter_page()` (static; called from
  `apply_controls` → declare `parameter_page` extern in `screen_internal.h`
  since `screen.c`'s `groove_screen_open` also calls it; make `fm_encoder_delta`
  static private).
- Lines 696–703: `fm_parameter()` (static).
- Lines 703 (forward decl) + 2952–end: `algorithm_draw()` + `algorithms[]`
  (both static, move together).
- Lines 704–803: `screen_fm_draw()`.
- Lines 804–809: `tone_part()`, `tone_slot()` (static).
- Lines 811–857: `tone_parameter()`, `track_lfo_draw()` → `screen_lfo_draw()`.
- Lines 859–870: `tone_label()` (static).
- Lines 872–946: `screen_tone_draw()`.
- Lines 829–857: `track_lfo_draw()` → `screen_lfo_draw()`.
- Lines 2918–2993: `algorithms[]`, `algorithm_draw()` (static, move here from end of file).

Note: `fm_encoder_delta()` is called from `apply_controls()` in the control
step (step 10).  Declare it `extern` in `screen_internal.h` or make it a small
helper duplicated in `screen_control.c`.  Preferred: declare `extern` in
`screen_internal.h` with its definition in `screen_fm.c`.

**Verify:** `.\build.bat --web` green.  
**Commit:** `screen: extract FM/DX7 and tone pages into screen_fm.c`

### Step 6 — Extract `app/screen_mix.c`, `app/screen_effects.c`, `app/screen_ble.c`
Three small modules in one step:
- `screen_mix.c`: lines 948–972 → `screen_mix_draw()`.
- `screen_effects.c`: lines 1159–1204 → `screen_effects_draw()`.
  `effects_page` state variable: defined in `screen.c` (part of shared state),
  declared extern in `screen_internal.h`.
- `screen_ble.c`: lines 973–980 `radio_line()` (static) + 981–1063 → `screen_ble_draw()`.

**Verify:** `.\build.bat --web` green.  
**Commit:** `screen: extract mix, effects, and BLE pages`

### Step 7 — Extract `app/screen_project.c`
Move from `screen.c`:
- Lines 156: `edit_keys[]` (static).
- Lines 233–243: `project_refresh()` (static).
- Lines 244–249: `preset_refresh()` (static; also called from `screen_control.c`
  via `groove_screen_open` path → declare extern in `screen_internal.h` or
  `screen_page.h`).
- Lines 250–261: `edit_character()` (static).
- Lines 1064–1115: `screen_project_draw()`.
- Lines 1116–1134: `screen_preset_draw()`.
- Lines 1136–1157: `screen_name_draw()`.
- Lines 1361–1376: `screen_boot_draw()`.
  `boot_active`, `boot_phase`, `boot_started`: defined in `screen.c` (shared),
  extern in `screen_internal.h`.

**Verify:** `.\build.bat --web` green.  
**Commit:** `screen: extract project, preset, name and boot pages`

### Step 8 — Extract `app/screen_edit.c` + rename `header()`
- `screen_edit.c`: lines 174–177 `actions[]`, `ACTION_COUNT`, lines 1267–1360
  → `screen_edit_draw(unsigned visible)`.
- In `screen.c`: rename `header()` → `screen_draw_header()`, declare in
  `screen_page.h`.  Update all callers in `draw_page_body` (now in screen.c)
  and in page files that call it (fm_draw, steps, overview — already moved).

**Verify:** `.\build.bat --web` green.  
**Commit:** `screen: extract edit overlay pages; rename header() → screen_draw_header()`

### Step 9 — Extract `app/screen_control.c`
Highest-risk step.  Move from `screen.c`:
- Lines 280–282: `clamp()` (static).
- Lines 284–290: `move_step()` (static).
- Lines 292–295: `navigation_mode()` (static).
- Lines 297–302: `encoder_active()` (static).
- Lines 304–318: `read_encoders()` (static).
- Lines 337–343: `screen_open_subpage()`.
- Lines 345–352: `screen_post()`.
- Lines 1712–1723: `screen_release_keys_except()`, `screen_release_keys()`.
- Lines 1726–1760: `screen_preset_load()`.
- Lines 1762–1772: `screen_toggle_step()`.
- Lines 1835–1853: `screen_select_track()`.
- Lines 1860–2583: `apply_controls()` (723 lines, stays intact — no logic change).

`apply_controls` calls into page modules (e.g. `screen_preset_load`,
`sequence_length_adjust`, `screen_open_subpage`).  All cross-module calls are
covered by prototypes in `screen_page.h` / `screen_internal.h`.

**Verify:** `.\build.bat --web` green.  
**Commit:** `screen: extract input state machine into screen_control.c`

### Step 10 — Extract `app/screen_web.c`
Move from `screen.c`:
- Lines 2754–2758: `struct web_target`, `web_targets[]`, `web_target_count`.
- Lines 2782–2795: `web_target()`, `web_alias()` (static).
- Lines 2757–2780: `groove_screen_web_context()`, `groove_screen_web_mask()`.
- Lines 2800–2916: `groove_screen_web_targets()`, `groove_screen_web_target_count()`,
  `groove_screen_web_adjust()`, `groove_screen_web_knobs()`,
  `groove_screen_web_first()`, `groove_screen_web_step()`.
- Lines 2904–2916: `groove_screen_snapshot()`.

`groove_screen_web_adjust()` calls `sequence_length_adjust()` (declared in
`screen_page.h`) and `screen_release_keys()` (declared in `screen_page.h`).

**Verify:** `.\build.bat --web` green.  
**Commit:** `screen: extract web simulator interface into screen_web.c`

### Step 11 — Slim `screen.c` + update `sdk/Build.ps1`
`screen.c` now contains only:
- Includes: `screen_page.h`, `instrument.h`, etc.
- Color constant definitions (also used via `screen_internal.h`).
- All shared state **definitions** (the `static` → plain `extern`-visible variables).
- `screen_draw_header()`.
- `draw_page_body()` dispatcher (~250 lines).
- `draw_page()`, `draw()` (frame capture ~100 lines).
- `paint_flush()` (~50 lines, calls `screen_paint_*` from screen_gfx.h).
- `groove_screen_init()`, `groove_screen_control()`, `groove_screen_tap()`,
  `groove_screen_preset()`, `groove_screen_preset_position()`,
  `groove_screen_open()`, `groove_screen_mmc()`.

Target: **~300 lines**.

Update `sdk/Build.ps1` as specified in §5.

**Verify:** `.\build.bat --web` green, `.\build.bat --package` green (if toolchain available).  
**Commit:** `screen: slim orchestrator; update Build.ps1 compiler flags for screen split`

### Step 12 — Final verification
```powershell
.\build.bat --web                                # must produce build/preview/index.html
.\build.bat --package                            # if toolchain available
node tests/wasm/fm1_wasm_test.mjs                # WASM checks passed
pwsh tests/host/run.ps1                          # host checks passed
pwsh doc/lint.ps1                                # OK - no issues
git diff --stat main feature/screen-split        # review scope
```
Check that `build/preview` behaviour is identical: load in browser, navigate
every page, verify LEDs and knob labels match the pre-split build.

**Commit:** `screen: add split verification note to doc/screen-split-plan.md`

---

## 8  Commit plan summary

| # | Commit message | Risk |
|---|---|---|
| 1 | `screen: add layered headers` | Low |
| 2 | `screen: extract pixel drawing layer into screen_gfx.c` | Low |
| 3 | `screen: extract overview page and LED matrix` | Low |
| 4 | `screen: extract sequencer page` | Low |
| 5 | `screen: extract FM/DX7 and tone pages` | Medium |
| 6 | `screen: extract mix, effects, and BLE pages` | Low |
| 7 | `screen: extract project, preset, name and boot pages` | Low |
| 8 | `screen: extract edit overlay pages; rename header()` | Low |
| 9 | `screen: extract input state machine` | **High** |
| 10 | `screen: extract web simulator interface` | Low |
| 11 | `screen: slim orchestrator; update Build.ps1 flags` | Medium |
| 12 | `screen: final verification` | — |

Step 9 is highest risk because `apply_controls` is 723 lines and references
every page's state.  If a build failure occurs, bisect by commit: steps 1–8
are independently verifiable.

---

## 9  PR description template (for `m-vave/fm1_open`)

```
screen: split 2,994-line monolith into focused translation units

Motivation
----------
app/screen.c grew to ~3,000 lines holding four distinct responsibilities:
pixel drawing, per-page UI, input handling, and the web simulator adapter.
This makes contributor navigation hard and prevents custom firmware developers
from reusing the drawing layer without also taking the full FM1 page system.

Architecture
------------
Three logical layers, two header contracts:

  screen_gfx.h/.c       — Reusable pixel drawing kit (fill, text, line, knob).
                           Custom firmware needs only this layer to draw on the
                           240×240 display.
  screen_internal.h     — Internal shared state (page enum, extern vars).
  screen_page.h         — Mid-layer contract: all per-page draw function
                           prototypes; documents what each page module provides.
  screen_control.c      — Input state machine (apply_controls, ~720 lines).
  screen_web.c          — Browser simulator adapter.
  screen_overview.c     — OVERVIEW page + LED matrix.
  screen_seq.c          — STEPS + sequencer helpers.
  screen_fm.c           — FM_EDIT / FM_ENV / FM_LFO / TONE_EDIT pages.
  screen_mix.c          — MIX page.
  screen_effects.c      — EFFECTS page.
  screen_project.c      — PROJECT / PRESET_BROWSER / NAME / boot pages.
  screen_ble.c          — BLE page.
  screen_edit.c         — STEP_EDIT / RHYTHM / ACTIONS / ARP_EDIT pages.
  screen.c              — Slimmed orchestrator (~300 lines).

No behaviour change.  Both builds verified green before and after.
WASM harness (tests/wasm/fm1_wasm_test.mjs) passes unchanged.

Build
-----
sdk/Build.ps1: replaced three exact app/screen.c flag matches with a
pattern match on ^app/screen, dropping -fno-inline-functions from the
smaller page files while keeping it for screen.c and screen_control.c.
tools/Build-Web.ps1: no change (already globs app/ recursively).
```

---

## 10  Phase 2 — future follow-up (not in this PR)

This PR moves code mechanically.  The following improvements are deliberately
deferred to keep the PR reviewable:

1. **Per-page input handlers** — refactor `apply_controls()` into
   `screen_XXX_input(const struct fm1_controls *, uint32_t)` per page module.
   This makes the page contract in `screen_page.h` complete: each page owns
   its own draw + input.  Requires deep testing on hardware (T-24).

2. **Parameter passing instead of extern globals** — introduce a
   `struct screen_state *` passed to draw functions instead of reading
   extern variables directly.  Better encapsulation, easier unit testing.

3. **screen_gfx host test** — extend `tests/host/` to test pixel primitives
   (fill, text output) on a RAM canvas without hardware.

---

## 11  Contributor quick-reference

After the split, the answer to "where do I find X?" is:

| Task | File |
|---|---|
| Add/change a draw primitive (fill, text, font) | `screen_gfx.c` |
| Change the FM/DX7 page appearance | `screen_fm.c` |
| Change sequencer page appearance | `screen_seq.c` |
| Change BLE page appearance | `screen_ble.c` |
| Fix a button/encoder input bug | `screen_control.c` |
| Add a new page | `screen_page.h` + new `screen_NEWPAGE.c` + dispatcher in `screen.c` |
| Change LED matrix feedback | `screen_overview.c` |
| Change web simulator targets | `screen_web.c` |
| Change render loop / paint scheduling | `screen.c` |
| Understand the page interface contract | `screen_page.h` |
| Build custom firmware using just the draw kit | `screen_gfx.h` + `screen_gfx.c` |

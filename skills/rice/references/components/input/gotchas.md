# input — gotchas

## `follow_mouse = 1` is focus-follows-mouse — NOT `2`

The single most common misread of the Hyprland input docs. Verified against the upstream
source (`src/config/values/ConfigValues.cpp`, the option map for `input:follow_mouse`):

| Value | Map name | Behavior |
|---|---|---|
| `0` | `disabled` | **Click to focus.** Cursor movement does not change focus at all. |
| `1` | `follow` | **Focus follows mouse** — moving the pointer over a window focuses it. The Hyprland default. This is what users mean when they ask for "sloppy focus" / "focus follows mouse." |
| `2` | `detached` | **Detached / loose** — the cursor can scroll and click the window it hovers, **but keyboard focus only changes on click**. Hovering does NOT refocus. This is the *opposite* of what most users mean. (See `#7677`: "Cursor focus will be detached from keyboard focus. Clicking on a window will move keyboard focus to that window.") |
| `3` | `separate` | Full-separate variant of `2` (rare). |

Source: option declared at `input:follow_mouse` with
`OptionMap{{"disabled", 0}, {"follow", 1}, {"detached", 2}, {"separate", 3}}`, default `1`.

When the user says "focus should change as I move the mouse over a window," record
`follow_mouse = 1`. Do not record `2` unless the user explicitly describes the detached
behavior (e.g. "I want to scroll the inactive window without giving it keyboard focus").

The interview question (2d in `interview.md`) presents these in plain English to avoid the
trap; record the integer that matches the prose the user picked, not whatever number "sounds
higher / more focused."

### Related: `mouse_refocus`, `float_switch_override_focus`

Both default to on. `mouse_refocus = false` is the well-known knob for "only refocus when the
mouse crosses a window boundary" (paired with `follow_mouse = 1`). `float_switch_override_focus`
controls whether crossing tiled↔floating refocuses; set to `0` to suppress that case (the
discussion in #7677 recommends this when `follow_mouse = 2` and floating dialogs are stealing
focus).

## Gestures: two cliffs (0.45+ adds keyword, 0.51+ removes legacy swipe keys)

There are **two** version cliffs in the gesture story, not one. Branch on `hypr_version` from
`answers.json` (top-level, seeded by `scripts/detect-version.sh` — see
`_shared/version-matrix.md`):

- **`≥ 0.45`** → the `gesture = FINGERS, DIRECTION, ACTION [, ARG]` keyword exists and is the
  preferred form. The `gestures {}` block also still exists; both forms parse simultaneously
  on 0.45–0.50.
- **`≥ 0.51`** → "Gesture Rework." The legacy `gestures:workspace_swipe`,
  `gestures:workspace_swipe_fingers`, and `gestures:workspace_swipe_min_fingers` are **removed**
  — leaving them in the config is a hard parse error (see omarchy#1594/1595, HyDE#1306). The
  other `gestures:workspace_swipe_*` tuning keys (`_distance`, `_invert`, `_cancel_ratio`,
  `_min_speed_to_force`, `_create_new`, `_direction_lock`, `_forever`, `_use_r`,
  `_touch`, `_touch_invert`) still exist as tuning for the swipe gesture you register with
  `gesture = N, horizontal, workspace`.
- **`< 0.45`** → no `gesture =` keyword; the only path is the legacy
  `gestures { workspace_swipe = true; workspace_swipe_fingers = 3; … }` block.

Rice rule (matches `template.md`):

| `hypr_version` | Emit | Tuning |
|---|---|---|
| `≥ 0.51` | `gesture = …` lines only | optional `gestures { workspace_swipe_distance = … }` for tuning; **do NOT** emit `workspace_swipe`, `workspace_swipe_fingers`, `workspace_swipe_min_fingers` |
| `0.45 – 0.50` | `gesture = …` lines preferred | legacy `gestures { workspace_swipe = true; workspace_swipe_fingers = N }` still parses |
| `< 0.45` | `gestures {}` block only | `workspace_swipe = true; workspace_swipe_fingers = 3` |

The validator (`hyprland-config-validator`) flags a `gesture =` line emitted against
`hypr_version < 0.45` as a parse-time error, and flags `gestures:workspace_swipe(_fingers|_min_fingers)`
against `≥ 0.51`.

### Verified `gesture =` syntax (from `src/config/legacy/ConfigManager.cpp:handleGesture`)

```
gesture = FINGERS, DIRECTION [, mod:MODS] [, scale:F], ACTION [, ARG…]
```

- **FINGERS**: integer `2..9` (`<= 1` or `>= 10` rejected).
- **DIRECTION** (via `TrackpadGestures::dirForString`, case-insensitive):
  `swipe`, `left`/`l`, `right`/`r`, `up`/`u`/`top`/`t`, `down`/`d`/`bottom`/`b`,
  `horizontal`/`horiz`, `vertical`/`vert`, `pinch`, `pinchin`/`zoomin`,
  `pinchout`/`zoomout`. (No `swipein`/`swipeout`.)
- Optional `mod:<MODMASK>` and `scale:<FLOAT 0.1..10>` after DIRECTION.
- **ACTION** is one of: `dispatcher <name> [args]`, `workspace`, `resize`, `move`,
  `special [name]`, `close`, `float [arg]`, `fullscreen [arg]`, `cursorZoom <a> <b>`,
  `scrollMove`, `unset`. Anything else is "Invalid gesture: <name>".

Note `float` and `fullscreen` and `special` take an **optional argument** (not the
`float, tile` two-word form some blog posts use). The `float` arg toggles modes; pass nothing
for the default.

## Omit the `touchpad {}` sub-block entirely on desktops

The `touchpad {}` block inside `input {}` is harmless on a system with no touchpad — Hyprland
ignores it — but it's noise in `input.conf` and confuses users hand-editing later. If the user
picked "No touchpad / desktop" in 2f, omit the entire `touchpad {}` sub-block from
`input.conf`. The template uses the `has_touchpad` boolean (see `template.md`); set it to
`false` and the section drops.

Same for the gesture section: empty `input.touchpad_gestures` → no `gesture =` lines, no
`gestures {}` block.

## Touchpad detection vs gestures gating — detection ≠ filter

`scripts/detect-version.sh` (and the broader detection step) sets `IS_LAPTOP=1` / `IS_LAPTOP=0`
based on chassis. **This seeds default ordering only.** From `_interview-protocol.md`:

> Detection is for defaults, not filters. … `HAVE_<tool>=1`/`MISSING_<tool>=1` flags from
> detection are used only to annotate the install batch; they do not reorder, hide, or
> default-bias the options.

For input specifically:

- 2f (touchpad) is **always asked**. `IS_LAPTOP=1` lists "Natural scroll + tap-to-click on"
  first; `IS_LAPTOP=0` lists "No touchpad / desktop" first. Either way the user confirms.
- 2g (gestures) is gated on the **answer to 2f**, not on `IS_LAPTOP`. If the user (on a desktop)
  says they actually have a touchpad, 2g is still asked.
- If the user (on a laptop) says "no touchpad" in 2f, 2g is skipped and
  `input.touchpad_gestures` is recorded as `[]`.

## `kb_options` is comma-joined, not space-joined

Hyprland passes `kb_options` to xkb verbatim; xkb expects comma-separated tokens. The template
emits `kb_options = caps:swapescape,grp:win_space_toggle` — not space-separated. Empty array →
`kb_options =` (blank value, line still present; Hyprland accepts this).

## `repeat_rate` / `repeat_delay` defaults — only emit non-defaults

Hyprland's compiled-in defaults are `repeat_rate = 25` and `repeat_delay = 600`. When the user
picks the "Default" option in 2c, **omit both lines** from `input.conf` — don't write
`repeat_rate = 25` redundantly. Keeps the file readable and means future Hyprland default
changes flow through. The template's `non_default_repeat_*` booleans handle this.

## Mouse `sensitivity = 0` is a no-op — omit the line

Same logic: `sensitivity = 0.0` is the libinput default. The template's
`non_default_sensitivity` boolean drops the line when `mouse_sensitivity == 0.0`.

Source: `input:sensitivity` is `Float`, default `0`, "clamped to the range -1.0 to 1.0".

## `accel_profile` valid values are `adaptive`, `flat`, `custom` (default unset)

Source: `input:accel_profile` is a `String` with validator `strChoice({"adaptive", "flat", "custom"})`
and default `STRVAL_EMPTY` (i.e. "use libinput's per-device default"). Not "adaptive by default" —
the empty string lets libinput choose. Only emit the line when the user picked `flat` (or
`custom`, which the interview does not expose).

## `touchpad` block — verified option names (0.55.x source)

`input:touchpad:` keys, all confirmed in `src/config/values/ConfigValues.cpp`:

| Key | Type | Default | Notes |
|---|---|---|---|
| `disable_while_typing` | bool | `true` | |
| `natural_scroll` | bool | `false` | |
| `scroll_factor` | float | `1` | range 0..2; **separate** from the input-level `scroll_factor` (which is for external mice). |
| `middle_button_emulation` | bool | `false` | |
| `tap_button_map` | string | empty | `lrm` or `lmr` only. |
| `clickfinger_behavior` | bool | `false` | 1/2/3 finger click → LMB/RMB/MMB. **Default false** — the rice template currently forces `true`; only emit when the user opted in. |
| `tap-to-click` | bool | `true` | Hyphenated literal — keep the dash. |
| `drag_lock` | **int 0..2** | `0` | NOT a bool. `0=off`, `1=timeout`, `2=sticky` (per libinput). |
| `tap-and-drag` | bool | `true` | |
| `flip_x`, `flip_y` | bool | `false` | invert touchpad axis |
| `drag_3fg` | int | `0` (`disable`) | `0`/`1`(`3_finger`)/`2`(`4_finger`) |

## Per-device input config — `device {}` special category

For per-keyboard/touchpad overrides, Hyprland accepts a top-level `device {}` special block
keyed by `name`. Verified keys (from `src/config/legacy/ConfigManager.cpp:512+`):
`sensitivity`, `accel_profile`, `rotation`, `kb_file`, `kb_layout`, `kb_variant`, `kb_options`,
`kb_rules`, `kb_model`, `repeat_rate`, `repeat_delay`, `natural_scroll`, `tap_button_map`,
`numlock_by_default`, `resolve_binds_by_sym`, `disable_while_typing`, `clickfinger_behavior`,
`middle_button_emulation`, `tap-to-click`, `tap-and-drag`, `drag_lock`, `left_handed`,
`scroll_method`, `scroll_button`, `scroll_button_lock`, `scroll_points`, `scroll_factor`,
`transform`, `output`, `enabled`, `keybinds`, `tags` (0.55+), and tablet-only keys
(`region_*`, `relative_input`, `active_area_*`, `flip_x/y`, `drag_3fg`).

Example:

```ini
device {
    name = epic-mouse-v1
    sensitivity = -0.5
    accel_profile = flat
}
```

Find the device name with `hyprctl devices`. Rice doesn't enumerate devices in the interview
(out of scope), but the validator should not reject `device {}` blocks the user added by hand.

## 0.55+ device tags for device-specific binds

0.55 added a `tags` field on the `device {}` block — e.g.
`device { name = my-keeb; tags = +my-tag }` — that lets a `bind` target a specific device by tag
prefix. Useful for laptop-keyboard-only Fn keys vs external keyboard layouts. Mentioned here
so the validator does not strip unknown `tags` lines from user configs. The interview does not
ask about this.

## Theming angles (narrow but real)

Input is a structural component — most of `input.conf` has no theming surface. The few angles
the corpus actually exercises:

### Multi-layout `kb_layout` ↔ waybar `hyprland/language` cross-surface coherence

When 2a yields a multi-layout (`us, es`), popular rices surface the active layout in the bar via
the `hyprland/language` module so the user can SEE which layout is live. JaKooLit ships the
canonical wiring in `config/waybar/Modules` (the file is base64 in the GitHub API; decoded):

```json
"hyprland/language": {
    "format": "Lang: {}",
    "format-en": "US",
    "format-tr": "Korea",
    "keyboard-name": "at-translated-set-2-keyboard",
    "on-click": "hyprctl switchxkblayout $SET_KB next"
}
```

The `on-click` dispatcher `switchxkblayout $SET_KB next` requires the **keyboard name** to be
discovered at runtime (`hyprctl devices`) — the rice can't hard-code it. Rule of thumb for the
component-writer agent:

- If `input.kb_layout` contains a comma (multi-layout), the waybar component SHOULD add
  `hyprland/language` to the bar's right cluster, and the writer agent should leave the
  `keyboard-name` field unset (waybar then matches the first keyboard).
- If `input.kb_options` includes `grp:win_space_toggle` or `grp:alt_shift_toggle`, the
  language indicator is the visual feedback for the toggle — without it, the user cycles
  layouts blind.

Cross-component: **flag this to the `waybar` agent.** The current waybar template does not
react to `input.kb_layout` being multi.

### Touchpad `natural_scroll` ↔ widget scroll-direction coherence

Bar widgets in JaKooLit, ML4W, end-4, and HyDE wire `on-scroll-up` / `on-scroll-down` to
volume / brightness / workspace dispatchers (e.g. `Volume.sh --inc`, `hyprctl dispatch
workspace +1`). Those handlers are written assuming OS-level "natural scroll" semantics — if
the user enables `touchpad:natural_scroll = true` on a laptop the OSDs FEEL right (scroll up
→ volume up, content follows finger). If the user enables `natural_scroll` only on the
touchpad but NOT on an external mouse (the Hyprland default), the same bar widget will scroll
"backwards" via the mouse. There is no fix in input — flag in the interview that this
asymmetry is a known UX artefact of the libinput/Hyprland separation between `input.touchpad`
and `input` for mouse scroll. No corpus rice exposes a knob for it.

### `binds:scroll_event_delay = 0` for snappy bar-widget scroll

end-4's `dots/.config/hypr/hyprland/general.lua` and ML4W's `conf/window.lua` both set
`binds { scroll_event_delay = 0 }` (Hyprland default is `300` ms). This is the difference
between waybar's pulseaudio widget feeling instant on a trackpad scroll vs lagging by a third
of a second. Out of scope for this component (lives under `keybinds` / look-feel territory),
but a popular UX-coherence move worth flagging if the user has a "snappy" archetype.

### `off_window_axis_events` and inactive-window scroll

end-4 ships `off_window_axis_events = 2` ("fake" — synthesize a scroll on the inactive
window without changing focus). This pairs with `follow_mouse = 2` (detached) for the
"scroll inactive windows" UX. ML4W defaults to `1` ("out-of-bounds"). The corpus default for
this knob is **not consistent** — leave it unset (Hyprland default `1`) and surface it only if
the user explicitly asks for detached/loose focus in 2d.

### Popular rices ship `numlock_by_default = true`

HyDE, JaKooLit, end-4, dusky, and Matt-FTW all ship `numlock_by_default = true`. The
Hyprland compiled-in default is `false`. The current interview (2e) lists this as an
opt-in — that's correct for a *strict no-defaulting* interview, but the prose should mention
that the community convention is on. No template change.

### `focus_on_close` is theming-adjacent for floating archetypes

caelestia's `hypr/hyprland/input.conf` ships `focus_on_close = 1` (focus the window under the
cursor when one closes). For floating-overlay rices where dialogs and pickers float over a
tiled background, this prevents the focus from jumping to a "random" tiled neighbour when a
notification dismisses or a picker closes. Not currently in the interview — out of scope, but
documented here for the validator/writer not to strip it.

### Out of scope: cursor theme, hyprcursor, sync_gsettings_theme

The Hyprland `cursor {}` block (`sync_gsettings_theme`, `enable_hyprcursor`,
`no_hardware_cursors`, `inactive_timeout`, `zoom_factor`) is **NOT** owned by this component —
it lives under `components/look-feel/` (which already covers `cursor:no_hardware_cursors` as
the nouveau/NVIDIA workaround). The cursor theme + size env vars
(`XCURSOR_THEME`/`XCURSOR_SIZE`/`HYPRCURSOR_THEME`/`HYPRCURSOR_SIZE`) live under
`components/env/`. If you find yourself wanting to put a cursor knob in `input.conf`, route
it to one of those two instead.

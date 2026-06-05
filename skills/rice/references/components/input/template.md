# input — template

Renders to `~/.config/hypr/input.conf`, sourced from `hyprland.conf` by the `keybinds`
component (which owns the top-level file). Three version branches:

- **0.51+** — `gesture =` keyword only; the legacy `gestures:workspace_swipe`,
  `workspace_swipe_fingers`, `workspace_swipe_min_fingers` are **removed** and emitting them
  is a parse error.
- **0.45 – 0.50** — `gesture =` keyword preferred; legacy `gestures { workspace_swipe = … }`
  block still parses.
- **`< 0.45`** — only the `gestures {}` block exists.

Branch on `hypr_version` from `answers.json` (top-level, seeded by detection — see
`_shared/version-matrix.md` and `gotchas.md` → "Gestures: two cliffs").

## `input.conf` — 0.45+ target

```ini
input {
    kb_layout = {{kb_layout}}
    kb_variant =
    kb_options = {{kb_options_joined}}
    follow_mouse = {{follow_mouse}}     # 0=disabled, 1=follow (default, hover focuses), 2=detached (keyboard focus stays until click), 3=separate
    {{#if non_default_sensitivity}}sensitivity = {{mouse_sensitivity}}{{/if}}       # libinput accel, -1.0 .. 1.0 (0 = default; line omitted at 0)
    {{#if non_default_repeat_rate}}repeat_rate = {{key_repeat.rate}}{{/if}}         # default 25 (repeats/sec); only emit if non-default
    {{#if non_default_repeat_delay}}repeat_delay = {{key_repeat.delay}}{{/if}}      # default 600 (ms); only emit if non-default
    {{#if accel_flat}}accel_profile = flat{{/if}}                                   # valid: adaptive | flat | custom; default unset (libinput chooses)
    {{#if numlock}}numlock_by_default = true{{/if}}

    {{#if has_touchpad}}touchpad {
        natural_scroll = {{touchpad_natural_scroll}}                                # default false
        disable_while_typing = true                                                 # default true; kept explicit for clarity
        tap-to-click = {{touchpad_tap}}                                             # default true; literal name uses a hyphen
        {{#if clickfinger}}clickfinger_behavior = true{{/if}}                       # default false; only emit if the user opted in (1/2/3-finger click → LMB/RMB/MMB)
    }{{/if}}
}

{{#if gestures_nonempty}}
# Gestures — 0.45+ keyword API (one keyword per gesture).
# Syntax: gesture = FINGERS, DIRECTION [, mod:MODS] [, scale:F], ACTION [, ARG]
# FINGERS: 2..9 inclusive.
# DIRECTION: horizontal | vertical | up | down | left | right | pinch | pinchin | pinchout (case-insensitive; aliases l/r/u/d/t/b/horiz/vert/zoomin/zoomout/swipe).
# ACTION: workspace | move | special[, name] | close | float[, arg] | fullscreen[, arg] | resize | dispatcher, <name> [args] | cursorZoom <a> <b> | scrollMove | unset.
{{#if gesture_workspace_swipe}}gesture = 3, horizontal, workspace{{/if}}      # 3-finger swipe ⇄ change workspace
{{#if gesture_window_move}}gesture = 4, horizontal, move{{/if}}               # 4-finger drag moves the window
{{#if gesture_fullscreen_3up}}gesture = 3, up, fullscreen{{/if}}              # 3-finger up → fullscreen
{{#if gesture_float_pinch}}gesture = 3, pinchin, float{{/if}}                 # 3-finger pinch → toggle float
{{#if gesture_special_4up}}gesture = 4, up, special{{/if}}                    # 4-finger up → default special workspace
{{/if}}
```

### Substitution notes

- `{{kb_options_joined}}` = `input.kb_options.join(",")`; empty array → blank (`kb_options =`).
- `non_default_sensitivity` = `mouse_sensitivity != 0.0`.
- `non_default_repeat_rate` = `key_repeat.rate != 25`; same shape for `_delay` against `600`.
- `has_touchpad` = the user did not pick "No touchpad / desktop" in 2f. When false, the entire
  `touchpad {}` sub-block is omitted.
- `clickfinger` = the user picked the clickfinger variant in 2f. Defaults to false because the
  Hyprland default for `input:touchpad:clickfinger_behavior` is `false`.
- The five `gesture_*` booleans map 1:1 to the short-names in `schema.md` →
  `input.touchpad_gestures` (note: `gesture_float_pinch`, **not** `gesture_float_tile_pinch`).

## `input.conf` — pre-0.45 fallback

On a target older than 0.45 the `gesture =` keyword form is unrecognized. Replace the bottom
gesture section with a `gestures {}` block:

```ini
gestures {
    workspace_swipe = {{has_workspace_swipe}}
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 300
    workspace_swipe_invert = true
    workspace_swipe_min_speed_to_force = 30
    workspace_swipe_cancel_ratio = 0.5
}
```

- `has_workspace_swipe` = `input.touchpad_gestures` contains `workspace-swipe` (the only
  pre-0.45 gesture rice supports).
- The other four gestures (`window-move`, `fullscreen-3up`, `float-pinch`, `special-4up`)
  have **no equivalent** in the pre-0.45 block API — emit a single comment instead:

  ```ini
  # Note: the other selected gestures (4-horizontal move, 3-up fullscreen, pinch float,
  # 4-up special) require Hyprland 0.45+; upgrade to enable them.
  ```

### 0.51+ note — DO NOT emit the removed swipe keys

On `hypr_version >= 0.51` the keys `gestures:workspace_swipe`,
`gestures:workspace_swipe_fingers`, and `gestures:workspace_swipe_min_fingers` are removed and
emitting any of them is a hard parse error (omarchy#1594, HyDE#1306). The other
`gestures:workspace_swipe_*` tuning keys (`_distance`, `_invert`, `_min_speed_to_force`,
`_cancel_ratio`, `_create_new`, `_direction_lock`, `_forever`, `_use_r`, `_touch`,
`_touch_invert`) still exist and tune the swipe gesture you register with
`gesture = N, horizontal, workspace`.

If the user wants non-default swipe tuning on 0.51+:

```ini
gesture = 3, horizontal, workspace
gestures {
    workspace_swipe_distance = 300
    workspace_swipe_invert = true
    # NOTE: do NOT add workspace_swipe / workspace_swipe_fingers / workspace_swipe_min_fingers on 0.51+.
}
```

See `_shared/version-matrix.md` → "0.45+ cliff" / "0.51+ cliff" for the branch criteria.

## What does NOT belong here

- The `source = ~/.config/hypr/input.conf` line — that's `components/keybinds/template.md`
  (which owns `hyprland.conf`).
- Workspace-swipe **tuning** beyond what `gestures {}` exposes (per-monitor distance, etc.) —
  out of scope for the interview; users can hand-edit later.
- Per-device input rules (`device { name = …; sensitivity = … }`) — also out of scope; the
  interview doesn't enumerate devices.

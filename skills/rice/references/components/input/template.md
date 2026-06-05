# input — template

Renders to `~/.config/hypr/input.conf`, sourced from `hyprland.conf` by the `keybinds`
component (which owns the top-level file). Two version branches: 0.45+ uses the
`gesture =` keyword API; older targets use the `gestures {}` block. The branch is decided by
`hypr_version` from `answers.json` (top-level, seeded by detection — see
`_shared/version-matrix.md`).

## `input.conf` — 0.45+ target

```ini
input {
    kb_layout = {{kb_layout}}
    kb_variant =
    kb_options = {{kb_options_joined}}
    follow_mouse = {{follow_mouse}}     # 1=focus-follows-mouse (hover focuses; Hyprland default), 0=click-to-focus, 2=detached/loose, 3=full-loose
    {{#if non_default_sensitivity}}sensitivity = {{mouse_sensitivity}}{{/if}}       # libinput accel, -1.0 .. 1.0 (0 = default; line omitted at 0)
    {{#if non_default_repeat_rate}}repeat_rate = {{key_repeat.rate}}{{/if}}         # default 25; only emit if non-default
    {{#if non_default_repeat_delay}}repeat_delay = {{key_repeat.delay}}{{/if}}      # default 600; only emit if non-default
    {{#if accel_flat}}accel_profile = flat{{/if}}
    {{#if numlock}}numlock_by_default = true{{/if}}

    {{#if has_touchpad}}touchpad {
        natural_scroll = {{touchpad_natural_scroll}}
        disable_while_typing = true
        tap-to-click = {{touchpad_tap}}
        clickfinger_behavior = true
    }{{/if}}
}

{{#if gestures_nonempty}}
# Gestures — 0.45+ keyword API (one keyword per gesture).
{{#if gesture_workspace_swipe}}gesture = 3, horizontal, workspace{{/if}}      # 3-finger swipe ⇄ change workspace
{{#if gesture_window_move}}gesture = 4, horizontal, move{{/if}}               # 4-finger drag moves the window
{{#if gesture_fullscreen_3up}}gesture = 3, up, fullscreen{{/if}}              # 3-finger up → fullscreen
{{#if gesture_float_tile_pinch}}gesture = 3, pinchin, float, tile{{/if}}      # 3-finger pinch toggles float/tile (HyDE preset)
{{#if gesture_special_4up}}gesture = 4, up, special{{/if}}                    # 4-finger up → special/scratchpad
{{/if}}
```

### Substitution notes

- `{{kb_options_joined}}` = `input.kb_options.join(",")`; empty array → blank (`kb_options =`).
- `non_default_sensitivity` = `mouse_sensitivity != 0.0`.
- `non_default_repeat_rate` = `key_repeat.rate != 25`; same shape for `_delay` against `600`.
- `has_touchpad` = the user did not pick "No touchpad / desktop" in 2f. When false, the entire
  `touchpad {}` sub-block is omitted.
- The five `gesture_*` booleans map 1:1 to the short-names in `schema.md` →
  `input.touchpad_gestures`.

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
- The other four gestures (`window-move`, `fullscreen-3up`, `float-tile-pinch`, `special-4up`)
  have **no equivalent** in the pre-0.45 block API — emit a single comment instead:

  ```ini
  # Note: the other selected gestures (4-horizontal move, 3-up fullscreen, pinch float/tile,
  # 4-up special) require Hyprland 0.45+; upgrade to enable them.
  ```

See `_shared/version-matrix.md` → "0.45+ cliff" for the branch criterion.

## What does NOT belong here

- The `source = ~/.config/hypr/input.conf` line — that's `components/keybinds/template.md`
  (which owns `hyprland.conf`).
- Workspace-swipe **tuning** beyond what `gestures {}` exposes (per-monitor distance, etc.) —
  out of scope for the interview; users can hand-edit later.
- Per-device input rules (`device { name = …; sensitivity = … }`) — also out of scope; the
  interview doesn't enumerate devices.

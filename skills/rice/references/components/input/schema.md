# input — answers.json slice

Keys this component owns under the top-level `input` key.

```json
{
  "input": {
    "kb_layout": "us",
    "kb_options": ["caps:swapescape"],
    "key_repeat": { "rate": 25, "delay": 600 },
    "follow_mouse": 1,
    "mouse_sensitivity": 0.0,
    "touchpad_gestures": ["workspace-swipe"]
  }
}
```

## Types

- `input.kb_layout` — string. xkb layout name(s). Single (`"us"`) or comma-separated multi
  (`"us, es"`). Always populated.
- `input.kb_options` — array of strings. Each element is a literal `kb_options` token (e.g.
  `caps:swapescape`, `compose:caps`, `grp:win_space_toggle`). The Hyprland default is empty
  (`STRVAL_EMPTY`). Empty array means no options emitted (the template writes `kb_options =`
  blank — `input.conf` still parses). Tokens are validated against the xkeyboard-config
  options list (`man xkeyboard-config`, [OPTIONS]).
- `input.key_repeat` — object `{ rate: int, delay: int }`. `rate` is keys/sec (Hyprland default
  25). `delay` is ms before repeat starts (Hyprland default 600). Both keys required when the
  object is present. The writer **only emits non-default** values to `input.conf` — if both
  match the defaults, neither line is written.
- `input.follow_mouse` — integer `0 | 1 | 2 | 3`. Hyprland default is `1`. Always populated.
  - `0` — click-to-focus.
  - `1` — focus-follows-mouse (hover refocuses).
  - `2` — detached / loose (cursor can interact, **keyboard focus only on click**).
  - `3` — full-loose variant.
- `input.mouse_sensitivity` — float in `[-1.0, 1.0]`, default `0.0`. Maps to libinput accel
  bias. Only emitted to `input.conf` when non-zero.
- `input.touchpad_gestures` — array of strings, gesture short-names. Recognized values
  (verified against `src/config/legacy/ConfigManager.cpp:handleGesture` action list and
  `TrackpadGestures::dirForString`):
  - `workspace-swipe` → `gesture = 3, horizontal, workspace`
  - `window-move` → `gesture = 4, horizontal, move`
  - `fullscreen-3up` → `gesture = 3, up, fullscreen`
  - `float-pinch` → `gesture = 3, pinchin, float` (the `float` action takes an optional arg, **not** a second positional like `tile`; the old `float, tile` form is invalid)
  - `special-4up` → `gesture = 4, up, special` (the `special` action accepts an optional special-workspace name)

  Empty array means "no gestures emitted" — also the value to record when 2f said "no
  touchpad / desktop". The template also omits the `touchpad {}` sub-block in that case.

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (`input`) | Renders `input.conf` from `template.md` — emits the `input {}` block, optional `touchpad {}` sub-block, and either `gesture =` lines (0.45+) or a `gestures {}` block (pre-0.45). Reads every `input.*` key. |
| `hyprland-component-writer` (`keybinds`) | Adds `source = ~/.config/hypr/input.conf` to `hyprland.conf`. Does not read any `input.*` key directly. |
| `hyprland-config-validator` | Cross-checks `kb_options` tokens against `setxkbmap -query` allow-list; validates `follow_mouse` range; flags `touchpad_gestures` keyword form against `hypr_version` (see `_shared/version-matrix.md`). |
| `hyprland-package-installer` | Does **not** read these keys. Input is built into Hyprland (see `packages.md`). |

## Validation

- `kb_layout` required, non-empty string.
- `kb_options` is an array (possibly empty); each element a non-empty string.
- `key_repeat.rate` ∈ `[1, 100]`; `key_repeat.delay` ∈ `[100, 2000]` (ms). Outside-range values
  are clamped with a warning, not rejected.
- `follow_mouse` ∈ `{0, 1, 2, 3}`. **Hard error** otherwise — most user-typed values land
  outside this set and we don't want to silently coerce.
- `mouse_sensitivity` ∈ `[-1.0, 1.0]`. Clamped with a warning if out-of-range.
- `touchpad_gestures` is an array; each element must be one of the recognized short-names
  listed above. Unknown short-names are dropped with a warning.

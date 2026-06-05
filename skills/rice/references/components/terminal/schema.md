# terminal — answers.json slice

Keys this component owns under the top-level `terminal` key.

```json
{
  "terminal": {
    "emulator":  "kitty | alacritty | foot | wezterm | ghostty",
    "opacity":   1.0,
    "padding":   8,
    "font_size": 11,
    "cursor":    { "shape": "block | beam | underline", "blink": false },
    "extras":    ["ligatures", "scrollback-10k", "bell-off", "no-confirm-close", "swallow"],
    "swallow":   false
  }
}
```

## Types

| Key | Type | Notes |
|---|---|---|
| `terminal.emulator` | string (enum) | `kitty` \| `alacritty` \| `foot` \| `wezterm` \| `ghostty`. Drives `$terminal` in `hyprland.conf` and which template/package is selected. Always populated. |
| `terminal.opacity` | float `0.0`–`1.0` | Background opacity. `1.0` = opaque. Below ~`0.8` becomes unreadable over busy wallpapers (see `gotchas.md` / `styling.md`). |
| `terminal.padding` | int (px) | Window padding, same value on x and y. The template fans it out per emulator (`window_padding_width`, `[window].padding = {x,y}`, `pad=NxN`, `window_padding`, `window-padding-x/y`). |
| `terminal.font_size` | int (pt) | Just the **size**; the family comes from `fonts.mono` (group 13). The colors file never includes the size — only the emulator's main config does. |
| `terminal.cursor.shape` | string (enum) | `block` \| `beam` \| `underline`. The writer maps this per emulator (each has its own spelling):<br>• kitty `cursor_shape` — `block` / `beam` / `underline` (lowercase)<br>• alacritty `[cursor.style] shape` — `"Block"` / `"Beam"` / `"Underline"` (capitalized strings)<br>• foot `[cursor] style` — `block` / `beam` / `underline` (lowercase; foot also has `hollow`, rice doesn't use it)<br>• wezterm `default_cursor_style` — combined with blink: `SteadyBlock`/`BlinkingBlock`, `SteadyBar`/`BlinkingBar`, `SteadyUnderline`/`BlinkingUnderline` (rice `beam` → `Bar`)<br>• ghostty `cursor-style` — `block` / `bar` / `underline` (rice `beam` → `bar`) |
| `terminal.cursor.blink` | bool | `true` enables blink (kitty `cursor_blink_interval 0.5`, alacritty `[cursor.style] blinking = "On"`, foot `[cursor] blink=yes`, wezterm `default_cursor_style = 'Blinking…'`, ghostty `cursor-style-blink = true`); `false` leaves the cursor steady (kitty `cursor_blink_interval 0`, alacritty `"Off"`, etc.). |
| `terminal.extras` | array<string> | Subset of `ligatures` \| `scrollback-10k` \| `bell-off` \| `no-confirm-close` \| `swallow`. Order-insensitive. Missing → empty array. |
| `terminal.swallow` | bool | Convenience mirror of `"swallow" ∈ extras`. The `look-feel` writer reads this directly. |

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (`terminal`) | Renders the emulator's main config from `template.md`; values fill `font_size`, `padding`, `opacity`, `cursor.*`, `extras`. |
| `hyprland-component-writer` (`hyprland`) | Writes `$terminal = <emulator>` in the variables block of `hyprland.conf`. |
| `hyprland-component-writer` (`keybinds`) | Reads `terminal.emulator` only to confirm `$terminal` is set; the bind itself uses the variable. |
| `hyprland-component-writer` (`look-feel`) | Reads `terminal.swallow`; if true, emits `misc:enable_swallow = true` + `swallow_regex = ^(<class>)$` into `looknfeel.conf`. Maps emulator → window class (see `gotchas.md`). |
| theming engine | Renders the colors file (`~/.config/<emulator>/colors.<ext>`) from `palette.conf`. Uses the variable-name contract in `_shared/colors-contract.md`. |
| `hyprland-package-installer` | Reads `terminal.emulator` against `packages.md`, adds the package to the install batch. |

## Validation

- `emulator` is required and must be in the enum.
- `opacity` must be a float `0.0`–`1.0`. The validator warns if `< 0.7` (text legibility).
- `padding` must be a non-negative int. The validator warns if `> 40` (likely a typo).
- `font_size` must be a positive int. The validator warns if `< 8` or `> 24`.
- `extras` items must come from the documented set; unknown strings are dropped with a warning.
- `swallow` and `("swallow" ∈ extras)` must agree; the writer normalizes by treating `swallow ==
  true` as authoritative.

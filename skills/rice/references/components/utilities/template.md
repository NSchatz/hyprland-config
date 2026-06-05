# utilities — template

This component doesn't render a `.conf` from a palette. Its outputs are two things:

1. **Script files** copied verbatim from `${CLAUDE_PLUGIN_ROOT}/skills/rice/assets/scripts/` into
   `~/.config/hypr/scripts/<name>.sh`, with mode `0755`. No `{{var}}` substitution — these are
   plain shell scripts.
2. **Bind lines** appended to `~/.config/hypr/binds.conf` (owned by the `keybinds` component, but
   the lines below are *this* component's contribution).

For each value in `utilities.selected`, walk the row below and emit the script copy (when there
is one) and the bind line.

## Script + bind map

| Value | Script (copy from `assets/scripts/`) | Runtime deps (auto-detected) | Bind line(s) emitted into `binds.conf` |
|---|---|---|---|
| `screenshot` | `screenshot.sh` | one of `grimblast`/`hyprshot`/(`grim`+`slurp`+`jq`); `wl-clipboard`; `satty` OR `swappy` for the `edit` arg | `bind = , Print, exec, ~/.config/hypr/scripts/screenshot.sh region` <br> `bind = $mainMod, Print, exec, ~/.config/hypr/scripts/screenshot.sh region edit` <br> `bind = ALT, Print, exec, ~/.config/hypr/scripts/screenshot.sh window` |
| `screen-record` | `screenrecord.sh` | one of `wl-screenrec` (HW, preferred) / `wf-recorder` (SW fallback); `slurp` for region | `bind = $mainMod SHIFT, Print, exec, ~/.config/hypr/scripts/screenrecord.sh region` |
| `ocr` | `ocr.sh` | `tesseract` + `tesseract-data-eng` (+ per-language packs); `grim`; `slurp`; `wl-clipboard` | `bind = $mainMod, O, exec, ~/.config/hypr/scripts/ocr.sh` |
| `color-picker` | `colorpicker.sh` | `hyprpicker`; `wl-clipboard` (for `-a` autocopy) | `bind = $mainMod SHIFT, P, exec, ~/.config/hypr/scripts/colorpicker.sh` |
| `power-menu` (rofi flavor) | `powermenu.sh` | `rofi` (≥ 2.0); `hyprlock`; systemd | `bind = $mainMod, Escape, exec, ~/.config/hypr/scripts/powermenu.sh` |
| `power-menu` (wlogout flavor) | *(no script — direct bind)* | `wlogout` | `bind = $mainMod SHIFT, M, exec, wlogout` |

Pick the wlogout flavor when the user selected `wlogout` upstream (companion-daemons or look-feel);
otherwise default to `powermenu.sh`.

## Bind-only tools (no script copy)

| Value | Bind line | Notes |
|---|---|---|
| `clipboard` | `bind = $mainMod SHIFT, V, exec, cliphist list \| $dmenu -i -p "Clipboard" \| cliphist decode \| wl-copy` | Use `$dmenu`, **not** `$menu`. `$mainMod, V` is usually toggle-float, so clipboard goes on `SHIFT+V`. The two `cliphist store` watchers must be in `autostart`. |
| `emoji` | `bind = $mainMod, period, exec, bemoji -t` | `bemoji` is self-contained — picks up whichever menu (`rofi`/`wofi`/`fuzzel`) is installed. `-t` types the choice; drop it to copy only. |
| `calculator` | `bind = $mainMod, C, exec, rofi -show calc -modi calc -no-show-match -no-sort \| wl-copy` | Needs `rofi-calc`. If the launcher is fuzzel/walker, route to its math plugin instead. |
| `night-light` | `bind = $mainMod SHIFT, N, exec, pkill hyprsunset \|\| hyprsunset -t 4000` | 4000 K warm; drop to 3500 K for stronger filtering. The `accessibility` component binds the same toggle. |
| `wifi-applet` | *(no bind — applet runs from autostart)* | `nm-applet --indicator` goes in `../autostart/template.md`. Needs a system tray on the bar (waybar `tray` module). |
| `bluetooth-applet` | *(no bind — applet runs from autostart)* | `blueman-applet` goes in `../autostart/template.md`. Same tray requirement. |

## Wi-Fi / Bluetooth — the keyboard-driven alternative

When the user explicitly wants keyboard-driven Wi-Fi instead of the tray, **do not** hand-author
an nmcli/bluetoothctl rofi parser — they break on SSIDs/device names with spaces and colons. Point
the user at the maintained external scripts:

- `rofi-network-manager` — single shell script the user drops in `~/.config/hypr/scripts/`.
- `rofi-bluetooth` — same.

Then emit:

```ini
bind = $mainMod, W, exec, ~/.config/hypr/scripts/rofi-network-manager.sh
```

This is opt-in only — surface it in the gotcha, not as a default option in the interview.

## Scripts ship verbatim — what does NOT belong here

- No palette substitution. These scripts are plain functional code; if a user wants a themed pop-up,
  that's the launcher's `theme.rasi` (themed by `launcher` component), not this script.
- No per-host variable injection. Paths are `~/.config/hypr/scripts/<name>.sh` literally.
- The autostart entries the scripts depend on (`cliphist` watchers, `nm-applet --indicator`,
  `blueman-applet`) — those belong in `../autostart/template.md`, not here.
- The actual bind table in `binds.conf` is assembled by the `keybinds` component; this file just
  documents the lines this component contributes.

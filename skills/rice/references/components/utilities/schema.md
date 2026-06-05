# utilities — answers.json slice

Keys this component owns under the top-level `utilities` key.

```json
{
  "utilities": {
    "selected": ["screenshot","clipboard","color-picker","power-menu","screen-record","ocr","emoji","calculator","wifi-applet","bluetooth-applet","night-light"],
    "osd_route": "in-shell"
  }
}
```

## Types

- `utilities.selected` — **string array**. May be empty (`[]`). The closed set of recognized
  values is below; the validator rejects any string not in this set.
- `utilities.osd_route` — **string enum**. Where volume/brightness/capslock OSDs appear visually.
  One of: `in-shell` | `swayosd` | `notification` | `none`. Defaults reordered per detected
  widget shell (see `interview.md` 18b).
    - `in-shell`: bind calls a shell IPC method (Quickshell rices). No extra daemon.
    - `swayosd`: install `swayosd-server`; writer emits a matugen template + autostart line.
    - `notification`: routes through the notification daemon — `notify-send -a OSD` + an
      `[app-name=OSD]` palette block in `notifications/template.md`.
    - `none`: bind scripts run silently; no visual feedback.
  Multiple downstream components read this — see "Who reads these keys" below.

### Recognized values

| Value | Surface |
|---|---|
| `screenshot` | Copies `screenshot.sh`; binds `Print` / `SUPER+Print` / `ALT+Print`. |
| `clipboard` | No script — emits the `cliphist list \| $dmenu \| cliphist decode \| wl-copy` bind on `SUPER+SHIFT+V`. Requires the `cliphist-text` and `cliphist-image` watchers in autostart. |
| `color-picker` | Copies `colorpicker.sh`; binds `SUPER+SHIFT+P`. |
| `power-menu` | Copies `powermenu.sh` (rofi-driven) **or** binds `wlogout` directly on `SUPER+SHIFT+M` if the user picked `wlogout` upstream. |
| `screen-record` | Copies `screenrecord.sh`; binds `SUPER+SHIFT+Print`. |
| `ocr` | Copies `ocr.sh`; binds `SUPER+O`. |
| `emoji` | No script — binds `bemoji -t` on `SUPER+period`. |
| `calculator` | No script — binds `rofi -show calc -modi calc -no-show-match -no-sort \| wl-copy` on `SUPER+C`. |
| `wifi-applet` | No script — adds `nm-applet --indicator` to autostart. (For the keyboard-driven rofi flow, see `gotchas.md`.) |
| `bluetooth-applet` | No script — adds `blueman-applet` to autostart. |
| `night-light` | No script — binds `pkill hyprsunset \|\| hyprsunset -t 4000` on `SUPER+SHIFT+N`. |

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (`utilities`) | Walks `.selected`; for each value, copies the matching script (if any) into `~/.config/hypr/scripts/` and `chmod +x`. Renders the swayosd matugen template iff `.osd_route == "swayosd"`. |
| `hyprland-component-writer` (`keybinds`) | Walks `.selected` for bind appends; reads `.osd_route` for the volume/brightness/capslock bind targets (each route maps to a different dispatch). |
| `hyprland-component-writer` (`autostart`) | Walks `.selected` for cliphist/nm-applet/blueman-applet appends. Adds `swayosd-server` exec-once iff `.osd_route == "swayosd"`. |
| `hyprland-component-writer` (`notifications`) | Reads `.osd_route`; iff `notification`, emits the `[app-name=OSD]` palette block in the daemon's template (mako/dunst/swaync). |
| `hyprland-component-writer` (`laptop`) | Reads `.osd_route` to pick the brightness/volume dispatch shape — `qs ipc call …` (in-shell), `swayosd-client …` (swayosd), `notify-send -a OSD …` (notification), `brightnessctl … >/dev/null` (none). |
| `hyprland-package-installer` | Walks `.selected` for per-tool deps. Adds `swayosd` iff `.osd_route == "swayosd"`. |

## Validation

- `utilities.selected` is required (emit `[]` when the user deselects everything).
- Every string must be in the recognized set above; the validator errors on unknown values rather
  than silently dropping them — a typo means a missing script or bind downstream.
- Duplicates are deduplicated by the writer (harmless but flagged).
- Order is **not** significant — the writer always emits scripts/binds in the canonical order
  above for diff stability.

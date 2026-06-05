# utilities — answers.json slice

Keys this component owns under the top-level `utilities` key.

```json
{
  "utilities": {
    "selected": ["screenshot","clipboard","color-picker","power-menu","screen-record","ocr","emoji","calculator","wifi-applet","bluetooth-applet","night-light"]
  }
}
```

## Types

- `utilities.selected` — **string array**. May be empty (`[]`). The closed set of recognized
  values is below; the validator rejects any string not in this set.

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
| `hyprland-component-writer` (`utilities`) | Walks the array; for each value, copies the matching script (if any) into `~/.config/hypr/scripts/` and `chmod +x`. |
| `hyprland-component-writer` (`keybinds`) | Walks the array; for each value, appends the matching bind line to `binds.conf`. |
| `hyprland-component-writer` (`autostart`) | Walks the array; appends `cliphist` watchers when `clipboard` is present, `nm-applet --indicator` when `wifi-applet` is present, `blueman-applet` when `bluetooth-applet` is present. |
| `hyprland-package-installer` | Walks the array; for each value, looks up `packages.md` and appends the dep set to the install batch. |

## Validation

- `utilities.selected` is required (emit `[]` when the user deselects everything).
- Every string must be in the recognized set above; the validator errors on unknown values rather
  than silently dropping them — a typo means a missing script or bind downstream.
- Duplicates are deduplicated by the writer (harmless but flagged).
- Order is **not** significant — the writer always emits scripts/binds in the canonical order
  above for diff stability.

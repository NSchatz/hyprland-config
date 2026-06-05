# utilities — packages

Each value in `utilities.selected` maps to a dependency set. The installer agent walks this map,
deduplicates (many tools share `grim`, `slurp`, `wl-clipboard`, `jq`), and appends to the global
`PKGS` list. Shared deps with other components — e.g. `rofi` (also pulled by `launcher`),
`hyprlock` (also pulled by `lock-screen`) — are deduplicated globally.

## Per-value dependency map

| Selected value | Required packages | Optional / preferred | Repo / AUR | Notes |
|---|---|---|---|---|
| `screenshot` | `grim` `slurp` `jq` `wl-clipboard` | `hyprshot` (extra), `grimblast` (AUR: `grimblast-git`), `satty` (extra), `swappy` (extra) | repo + AUR | Auto-detect at runtime — install the wrapper(s) and annotator(s) the user picked; bare `grim`+`slurp` is the fallback. As of 2025-08, `hyprshot` and `satty` moved from AUR to `extra`. |
| `screen-record` | `slurp` | `wl-screenrec` (AUR), `wf-recorder` (extra) | repo + AUR | `wl-screenrec` is HW-encoded (VAAPI) — preferred on AMD/Intel; `wf-recorder` is the software fallback. Both is harmless (auto-detect). |
| `ocr` | `tesseract` `tesseract-data-eng` `grim` `slurp` `wl-clipboard` | `tesseract-data-<lang>` per extra language | repo (extra) | English is the floor; add per-language data packs as the user requests. |
| `color-picker` | `hyprpicker` `wl-clipboard` | | repo (extra) | |
| `power-menu` (rofi flavor) | `rofi` `hyprlock` | | repo (extra) | Repo `rofi` ≥ 2.0 (released 2025-09-01) ships native Wayland — the old AUR `rofi-wayland` is obsolete. systemd is base; no separate package. |
| `power-menu` (wlogout flavor) | `wlogout` (AUR) `hyprlock` | | AUR | Upstream: `ArtsyMacaw/wlogout`. When the user picked `wlogout` upstream, swap to this row. |
| `clipboard` | `cliphist` `wl-clipboard` | | repo (extra) | The two watcher processes go in `autostart` (group 15), not here. |
| `emoji` | `bemoji` (AUR) | | AUR | Upstream: `marty-oehme/bemoji`. Auto-detects the first available picker in `$PATH` from: `bemenu`/`wofi`/`rofi`/`dmenu`/`wmenu`/`ilia`/`fuzzel`. Override with `BEMOJI_PICKER_CMD`. |
| `calculator` | `rofi` `rofi-calc` `wl-clipboard` | | repo + AUR | `rofi-calc` is AUR. Or route to the launcher's built-in math plugin (fuzzel/walker/anyrun) — then no extra package. |
| `wifi-applet` | `network-manager-applet` `networkmanager` | `nm-connection-editor` (editor UI) | repo (extra) | Needs system tray on the bar. |
| `bluetooth-applet` | `blueman` `bluez-utils` | | repo (extra) | Needs system tray on the bar. |
| `night-light` | `hyprsunset` | | repo (extra) | Same package the `accessibility` component pulls. |

## Other utility-adjacent packages

These are not driven by `utilities.selected` directly but live in the same neighborhood — the
writer/installer pull them when the right upstream components are selected:

| Package | Pulled by | Notes |
|---|---|---|
| `brightnessctl` | `keybinds` (XF86 keys) | `extra`. Brightness `bindel` lines (`brightnessctl set 5%+` / `5%-`). |
| `playerctl` | `keybinds` (XF86 keys) | `extra`. Media keys (`play-pause` / `next` / `previous`). |
| `swayosd` | `look-feel` / `keybinds` | `extra` (since 2024 — was AUR). Daemon `swayosd-server` + client `swayosd-client --output-volume raise/lower/mute-toggle`, `--brightness raise/lower`. |
| `pavucontrol` | `waybar` (audio on-click) | `extra`. PulseAudio/PipeWire mixer launched from the bar. |

## Assembly rule

```bash
# Walk utilities.selected; for each value, append its package set to PKGS.
for util in $(jq -r '.utilities.selected[]?' "$staging/answers.json"); do
  case "$util" in
    screenshot)
      pkgs+=(grim slurp jq wl-clipboard)
      # User-preferred wrapper(s) — pulled from the install-batch addenda the interview recorded:
      pkgs+=(hyprshot satty)
      ;;
    screen-record)      pkgs+=(slurp wl-screenrec) ;;
    ocr)                pkgs+=(tesseract tesseract-data-eng grim slurp wl-clipboard) ;;
    color-picker)       pkgs+=(hyprpicker wl-clipboard) ;;
    power-menu)
      if jq -e '.companion_configs.wlogout // false' "$staging/answers.json" >/dev/null; then
        pkgs+=(wlogout hyprlock)
      else
        pkgs+=(rofi hyprlock)
      fi
      ;;
    clipboard)          pkgs+=(cliphist wl-clipboard) ;;
    emoji)              pkgs+=(bemoji) ;;
    calculator)         pkgs+=(rofi rofi-calc wl-clipboard) ;;
    wifi-applet)        pkgs+=(network-manager-applet networkmanager) ;;
    bluetooth-applet)   pkgs+=(blueman bluez-utils) ;;
    night-light)        pkgs+=(hyprsunset) ;;
  esac
done
```

The installer dedups globally (`sort -u`), so repeating `wl-clipboard` / `grim` / `slurp` / `jq`
across rows is fine — the final batch lists each package once.

The repo/AUR column is informational — `install.sh` auto-routes each name at runtime via
`pacman -Si`, so a package that drifts between repos (e.g. `cliphist` was AUR, now repo) doesn't
break the install.

## Cross-references

- The wrapper/annotator preference (hyprshot vs grimblast, satty vs swappy, wl-screenrec vs
  wf-recorder) → `gotchas.md`
- Autostart entries the picks here require (cliphist watchers, nm-applet, blueman-applet) →
  `../autostart/packages.md` and `../autostart/template.md`
- Tray module on the bar (required by wifi/bluetooth applets) → `../waybar/template.md`
- `hyprsunset` is also referenced from `../accessibility/packages.md` — same package, deduped.

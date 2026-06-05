# utilities — packages

Each value in `utilities.selected` maps to a dependency set. The installer agent walks this map,
deduplicates (many tools share `grim`, `slurp`, `wl-clipboard`, `jq`), and appends to the global
`PKGS` list. Shared deps with other components — e.g. `rofi` (also pulled by `launcher`),
`hyprlock` (also pulled by `lock-screen`) — are deduplicated globally.

## Per-value dependency map

| Selected value | Required packages | Optional / preferred | Repo / AUR | Notes |
|---|---|---|---|---|
| `screenshot` | `grim` `slurp` `jq` `wl-clipboard` | `hyprshot` (AUR), `grimblast`, `satty` (AUR), `swappy` | repo + AUR | Auto-detect at runtime — install the wrapper(s) and annotator(s) the user picked; bare `grim`+`slurp` is the fallback. |
| `screen-record` | `slurp` | `wl-screenrec` (AUR — preferred on AMD/Intel), `wf-recorder` | repo + AUR | Pick one of `wl-screenrec`/`wf-recorder`; both is harmless (auto-detect). |
| `ocr` | `tesseract` `tesseract-data-eng` `grim` `slurp` `wl-clipboard` | `tesseract-data-<lang>` per extra language | repo | English is the floor; add per-language data packs as the user requests. |
| `color-picker` | `hyprpicker` `wl-clipboard` | | repo | |
| `power-menu` (rofi flavor) | `rofi` `hyprlock` | | repo | systemd is base; no separate package. |
| `power-menu` (wlogout flavor) | `wlogout` (AUR) `hyprlock` | | AUR | When the user picked `wlogout` upstream, swap to this row. |
| `clipboard` | `cliphist` `wl-clipboard` | | repo | The two watcher processes go in `autostart` (group 15), not here. |
| `emoji` | `bemoji` (AUR) | | AUR | Uses whichever menu is installed (`rofi`/`wofi`/`fuzzel`). |
| `calculator` | `rofi` `rofi-calc` `wl-clipboard` | | repo | Or route to the launcher's built-in math plugin (fuzzel/walker/anyrun) — then no extra package. |
| `wifi-applet` | `network-manager-applet` `networkmanager` | `nm-connection-editor` (editor UI) | repo | Needs system tray on the bar. |
| `bluetooth-applet` | `blueman` `bluez-utils` | | repo | Needs system tray on the bar. |
| `night-light` | `hyprsunset` | | repo | Same package the `accessibility` component pulls. |

## Other utility-adjacent packages

These are not driven by `utilities.selected` directly but live in the same neighborhood — the
writer/installer pull them when the right upstream components are selected:

| Package | Pulled by | Notes |
|---|---|---|
| `brightnessctl` | `keybinds` (XF86 keys) | Brightness `bindel` lines. |
| `playerctl` | `keybinds` (XF86 keys) | Media keys. |
| `swayosd` (AUR) | `look-feel` / `keybinds` | Volume/brightness OSD overlay. |
| `pavucontrol` | `waybar` (audio on-click) | Audio mixer launched from the bar. |

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

# Utilities & menus

The small tools and pop-up menus that every popular Hyprland rice ships — screenshots, screen
recording, OCR, a color picker, clipboard/emoji pickers, and rofi/wofi menus for power, Wi-Fi and
Bluetooth. These are what make a config feel *finished*; the corpus (JaKooLit, HyDE, Omarchy,
gh0stzk) treats them as first-class features, but a generator easily skips them. **Group 18** of the
interview decides which to wire up.

The functional scripts ship as **plugin template files** in this skill's `assets/scripts/`. They are
plain functional scripts (not palette-themed — they need no colors file), so install is a copy +
`chmod`, not a render. The matching keybinds are emitted into the user's `binds.conf` (group 3).

## Installing a chosen script

For each utility the user picks, copy its script into their Hypr config and make it executable, then
add the bind. Use the timestamped backup first (the rice safe-apply flow already does this for
`~/.config/hypr`):

```sh
mkdir -p ~/.config/hypr/scripts
cp <skill>/assets/scripts/<name>.sh ~/.config/hypr/scripts/
chmod +x ~/.config/hypr/scripts/<name>.sh
```

Then add the bind to `binds.conf` (see each tool below). Bias which tools are *offered* and which are
**(on)** by default to what `detect-version.sh` reports installed (`HAVE_grim`, `HAVE_satty`,
`HAVE_tesseract`, `HAVE_bemoji`, `HAVE_wf_recorder`, `HAVE_hyprpicker`, `HAVE_cliphist`, `HAVE_rofi`,
…). Name the package for anything missing — **never install it**.

## Shipped scripts

| Script | Purpose | Deps (name the missing ones) | Suggested bind |
|---|---|---|---|
| `screenshot.sh [region\|window\|output] [edit]` | Capture → clipboard **and** `~/Pictures/Screenshots`; `edit` opens satty/swappy first | `grimblast`/`hyprshot`/`grim`+`slurp`, `wl-clipboard`, `jq` (window+grim), `satty`/`swappy` (edit) | `bind = , Print, exec, ~/.config/hypr/scripts/screenshot.sh region` · `bind = $mainMod, Print, exec, …/screenshot.sh region edit` · `bind = ALT, Print, exec, …/screenshot.sh window` |
| `screenrecord.sh [region\|output] [audio]` | Toggle recording → `~/Videos/Recordings`; re-run stops it | `wf-recorder`, `slurp` | `bind = $mainMod SHIFT, Print, exec, ~/.config/hypr/scripts/screenrecord.sh region` |
| `ocr.sh [lang]` | Select region → OCR text → clipboard | `grim`, `slurp`, `tesseract` (+ `tesseract-data-<lang>`), `wl-clipboard` | `bind = $mainMod, O, exec, ~/.config/hypr/scripts/ocr.sh` |
| `colorpicker.sh` | Eyedropper a pixel → hex to clipboard | `hyprpicker`, `wl-clipboard` | `bind = $mainMod SHIFT, P, exec, ~/.config/hypr/scripts/colorpicker.sh` |
| `powermenu.sh` | Rofi lock/logout/suspend/reboot/shutdown | `rofi`, `hyprlock`, systemd | `bind = $mainMod, Escape, exec, ~/.config/hypr/scripts/powermenu.sh` |

`screenshot.sh` and `screenrecord.sh` auto-detect the best installed capture tool, so they work
whether the user has grimblast, hyprshot, or bare grim+slurp.

## Tools that are a bind, not a script

- **Clipboard history** — needs the `cliphist` store watchers running (group 15 autostart) and a
  one-line picker bind; no script file:
  `bind = $mainMod, V, exec, cliphist list | $menu | cliphist decode | wl-copy`
- **Emoji picker** — `bemoji` is self-contained (it types/copies the choice); just bind it. It uses
  whatever menu is installed (`rofi`/`wofi`/`fuzzel`):
  `bind = $mainMod, period, exec, bemoji -t` (`-t` types, drop it to copy only). Package: `bemoji`.
- **Calculator** — rofi has a built-in calc mode; no script:
  `bind = $mainMod, C, exec, rofi -show calc -modi calc -no-show-match -no-sort | wl-copy`
  (needs `rofi-calc`). Or route to the chosen launcher's math plugin.
- **Logout grid** — if the user chose `wlogout` (group 15), bind it directly instead of `powermenu.sh`:
  `bind = $mainMod SHIFT, M, exec, wlogout`.

## Wi-Fi / Bluetooth menus — recipe, not a shipped script

Homegrown nmcli/bluetoothctl rofi parsers are notoriously fragile (SSIDs/device names with spaces and
colons break naive `awk`), so this plugin does **not** ship them. Two honest options to offer:

1. **The robust default — the tray applets** (already offered in group 15 autostart): `nm-applet
   --indicator` (NetworkManager) and `blueman-applet` (Bluetooth). These need a system tray on the bar
   (waybar `tray` module). This is what most "it just works" setups use.
2. **A rofi menu** for users who want keyboard-driven control — point them at a maintained external
   project rather than a brittle inline script: `rofi-network-manager` (Wi-Fi) and `rofi-bluetooth`
   (Bluetooth), both single-script installs the user drops in `~/.config/hypr/scripts/` and binds. Name
   the dependency (`networkmanager`/`bluez-utils`) and let the user install the menu script; document
   the bind:
   `bind = $mainMod, W, exec, ~/.config/hypr/scripts/rofi-network-manager.sh`

Offer (1) by default; mention (2) for the keyboard-centric.

## Night light / blue-light filter

`hyprsunset` is the first-party tool (group 15 lists it as an autostart, off by default). To make it a
*toggle* rather than always-on, bind a small wrapper or use its IPC:
`bind = $mainMod SHIFT, N, exec, pkill hyprsunset || hyprsunset -t 4000` (4000 K warm; drop to 3500 K
for stronger filtering). Document it here so the accessibility group (Tier 2) and this group share one
mechanism.

## Group 18 question (how to ask)

One `AskUserQuestion`, **multi-select**, options ordered by how often each appears in the corpus, with
the items whose tools are installed pre-checked **(on)**:

> **Which utilities & menus should I set up?** (generates the script + keybind for each)
> - Screenshot (region/window/full + annotate) **(on)**
> - Clipboard history picker **(on)**
> - Color picker **(on if hyprpicker)**
> - Power menu **(on)**
> - Screen recording
> - OCR (screen → text)
> - Emoji picker
> - Calculator
> - Wi-Fi menu / applet
> - Bluetooth menu / applet
> - Night-light toggle

Map each checked item to its row above: copy the script (or just add the bind), wire the keybind into
`binds.conf`, and make sure its autostart prerequisite (cliphist watchers, nm-applet) is also enabled
in group 15. Validate `binds.conf` with `hyprctl reload` + `configerrors` after writing (the rice
safe-apply flow). For anything whose tool is missing, add the bind but note the package to install.

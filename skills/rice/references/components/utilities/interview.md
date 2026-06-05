# utilities — interview

Two `AskUserQuestion` calls (a multi-select + a single-select). This is group 18 of the
interview walk.

The asking discipline rule (see `_interview-protocol.md`): *every* sub-question gets asked, even
when the defaults are obvious. The pre-checks just put the commonly-rice'd items first so the user
can confirm with one press — they don't authorize skipping the call.

## Sub-questions

**18a. Which utilities & menus should I set up?** *(multi-select; generates the script and/or bind
for each)*

Options ordered by corpus frequency. Items marked **(on)** are pre-checked.

| Option | Value | Pre-checked | Notes |
|---|---|---|---|
| Screenshot (region/window/full + annotate) | `screenshot` | **on** | Most-shipped utility across the corpus. |
| Clipboard history picker | `clipboard` | **on** | Needs `cliphist` watchers in `autostart`. |
| Color picker | `color-picker` | **on** | `hyprpicker` + `wl-copy`. |
| Power menu | `power-menu` | **on** | rofi/wofi/bemenu prompt OR `wlogout`. |
| Screen recording | `screen-record` | off | `wl-screenrec` (HW-encoded) or `wf-recorder`. |
| OCR (screen → text) | `ocr` | off | `tesseract` + per-language data. |
| Emoji picker | `emoji` | off | `bemoji` self-contained. |
| Calculator | `calculator` | off | `rofi -show calc` (needs `rofi-calc`). |
| Wi-Fi menu / applet | `wifi-applet` | off | Tray applet by default (`nm-applet --indicator`). |
| Bluetooth menu / applet | `bluetooth-applet` | off | Tray applet by default (`blueman-applet`). |
| Night-light toggle | `night-light` | off | `hyprsunset` toggle bind. |

Tool defaults the writer should prefer at install-batch time (see `gotchas.md`): **satty** over
swappy for annotation, **wl-screenrec** over wf-recorder on AMD/Intel, **grimblast** or `hyprshot`
for the capture wrapper. The shipped scripts auto-detect (screenshot.sh: grimblast → hyprshot →
grim+slurp; screenrecord.sh: wl-screenrec → wf-recorder), so listing several tools in the install
batch is harmless — the script picks the first one present.

## Record path

After the user answers, record the multi-select as a JSON array:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh" "$staging/answers.json" \
  utilities.selected --json '["screenshot","clipboard","color-picker","power-menu"]'
```

If the user deselects everything (rare but valid — they don't want any of the small tools):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh" "$staging/answers.json" \
  utilities.selected --json '[]'
```

Downstream code branches on array membership, not on key presence — always emit the key.

**18b. OSD routing.** Where do volume / brightness / capslock change events appear visually?

Background: `gotchas.md` § "OSD-route coherence" documents the four strategies the corpus
uses and why getting it wrong is the **single most common cross-surface coherence miss** in
the top-19 rices (Matt-FTW ships `swayosd-client` binds but no swayosd matugen template — the
OSD falls back to stock GTK colors and clashes with the rest of the rice).

| Option | Value | Pre-checked rule | Notes |
|---|---|---|---|
| Inside your shell (Quickshell renders the OSD) | `in-shell` | **on** when `widgets.shell` is `quickshell-based`. | Bind calls a shell IPC method (`qs ipc call brightness increment` — end-4 pattern). Shell auto-themes via matugen output. **Most coherent for Quickshell rices** (end-4 / caelestia / DMS / noctalia). |
| Dedicated `swayosd-server` daemon | `swayosd` | **on** when no widget shell is selected. | Matt-FTW pattern (without the coherence miss). Installs `swayosd`; the writer ships a matugen template for it so the OSD inherits the rice palette. |
| Route through your notification daemon (`[app-name=OSD]` block) | `notification` | off | dusky / HyDE / JaKooLit pattern — `notify-send -h int:value:N -u low -a OSD` + a per-app palette override in the notification daemon's matugen template. Reuses the notification surface; no new daemon. |
| None — bind runs silently | `none` | off | binnewbs partial pattern. Volume/brightness keys still WORK; you just don't see a toast. |

After the user answers, record the single-select string:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh" "$staging/answers.json" \
  utilities.osd_route "in-shell"
```

## Cross-references

- Recognized values (the closed set) → `schema.md`
- Per-tool deps and bind lines → `template.md`
- Why Wi-Fi/Bluetooth default to tray applets and not rofi parsers → `gotchas.md`
- Packages walked by the installer → `packages.md`
- Cliphist watchers and tray applets (autostart prereqs) → `../autostart/template.md`
- The actual bind lines in `binds.conf` → `../keybinds/template.md`

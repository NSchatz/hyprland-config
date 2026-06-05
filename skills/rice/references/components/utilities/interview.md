# utilities — interview

One `AskUserQuestion` call, **multi-select**. This is group 18 of the interview walk.

The asking discipline rule (see `_interview-protocol.md`): *every* sub-question gets asked, even
when the defaults are obvious. The pre-checks just put the commonly-rice'd items first so the user
can confirm with one press — they don't authorize skipping the call.

## Sub-question

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

## Cross-references

- Recognized values (the closed set) → `schema.md`
- Per-tool deps and bind lines → `template.md`
- Why Wi-Fi/Bluetooth default to tray applets and not rofi parsers → `gotchas.md`
- Packages walked by the installer → `packages.md`
- Cliphist watchers and tray applets (autostart prereqs) → `../autostart/template.md`
- The actual bind lines in `binds.conf` → `../keybinds/template.md`

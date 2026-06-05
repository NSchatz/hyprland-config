# utilities — gotchas

## Wi-Fi / Bluetooth: prefer the tray applets, NOT homegrown rofi parsers

The temptation is to write a `nmcli dev wifi list | rofi -dmenu` one-liner. **Don't.** SSIDs and
Bluetooth device names contain spaces, colons, parentheses, and UTF-8 — naive `awk '{print $2}'`
parsers break on all of them, and `nmcli`'s tabular output changes between releases. The robust
default is the **tray applets**:

- `nm-applet --indicator` (NetworkManager — package `network-manager-applet`)
- `blueman-applet` (Bluetooth — packages `blueman` + `bluez-utils`)

Both run from `autostart` and need a system-tray module on the bar (waybar `tray`, ags/quickshell
equivalents). This is what "it just works" rices ship.

If the user explicitly wants keyboard-driven control, point them at the maintained external
projects — `rofi-network-manager` and `rofi-bluetooth` — rather than rolling a fragile parser.
See `template.md` for the bind. **Never inline a `nmcli | awk | rofi` script** in the generated
config.

## 2025-2026 tool defaults the install batch should prefer

The corpus has shifted in the last year; pick the modern tool when adding to the install batch:

| Surface | Older default | 2025-2026 default | Why |
|---|---|---|---|
| Screenshot annotation | `swappy` | **`satty`** | Active maintenance, better UI, pen pressure. |
| Screen recording | `wf-recorder` | **`wl-screenrec`** (on AMD/Intel) | HW-encoded via VAAPI — drastically lower CPU, smaller files. |
| Capture wrapper | bare `grim`+`slurp` | **`grimblast`** or `hyprshot` | Window-capture honors Hyprland geometry; output dir, edit-arg handling. |

`hyprshot` and `satty` moved from AUR to `extra` in 2025-08; `swayosd` moved to `extra` earlier.
`wl-screenrec`, `wlogout`, `bemoji`, and `grimblast` remain AUR-only.

The shipped `screenshot.sh` auto-detects in the order **grimblast → hyprshot → bare `grim`+`slurp`**;
`screenrecord.sh` prefers **wl-screenrec → wf-recorder**. Listing multiple capture/recording tools
in the install batch is harmless — the script picks the first present, and a user who later
uninstalls one still gets a working script via the fallback chain.

## Scripts auto-detect — listing multiple tools is fine

A direct consequence of the above: the writer agent should **not** worry about "the user picked
satty, do I also need swappy?" — only install what the user selected. If the user later wants to
switch from satty to swappy, just install swappy; the script's auto-detect picks it up. No
re-generation needed.

## Cliphist watchers belong in `autostart`, not here

The clipboard *picker* (`cliphist list | $dmenu | cliphist decode | wl-copy`) is a bind this
component emits. The clipboard *watchers* — two `wl-paste --watch cliphist store` processes (one
for text, one for images) — must run from `autostart.conf` or the picker shows an empty history.
These live in `../autostart/template.md`. The writer agent must emit **both** when the user
selects `clipboard` in `utilities.selected`; missing the watchers is a silent failure (picker
opens, picks nothing).

## OCR language packs

`tesseract` itself contains no language data. The shipped `ocr.sh` calls
`tesseract -l <lang>` and fails silently (or returns garbage) when the requested data pack isn't
installed. The install batch must include at least `tesseract-data-eng`; if the user works in
other languages, add `tesseract-data-<lang>` per language (German `deu`, French `fra`, etc.).
There's no interview sub-question for this — flag it in the post-install README so the user knows
how to add languages later.

## `$dmenu` vs `$menu` — bind syntax for the bind-only tools

The clipboard, emoji, and calculator binds **must** use `$dmenu` (e.g. `rofi -dmenu`,
`wofi --dmenu`, `fuzzel --dmenu`), **not** `$menu`. `$menu` is the launcher invocation with
`-show drun` already baked in; piping into it conflicts with the existing mode flag and the picker
silently fails to open. This is documented in `_shared/dispatchers.md` under "Variable
conventions" — the variable split exists for exactly this reason.

## `SUPER+V` is taken — use `SUPER+SHIFT+V` for clipboard

The corpus default for `SUPER+V` is `togglefloating` (set by the `keybinds` component). Putting
the clipboard picker on `SUPER+V` would shadow it. Always emit clipboard on `SUPER+SHIFT+V`.

## `wlogout` vs `powermenu.sh` — pick one

If the user already selected `wlogout` in `companion-daemons` or `look-feel`, **do not also** copy
`powermenu.sh` — they're two power-menu UIs competing for the same bind. The writer picks the
wlogout-direct bind (`bind = $mainMod SHIFT, M, exec, wlogout`) and skips the script copy.
Otherwise, the rofi-driven `powermenu.sh` on `$mainMod, Escape` is the default. Document the
chosen flavor in the post-install summary so the user isn't surprised by the missing/extra script.

## Night-light is dual-owned with `accessibility`

The `night-light` value here and the `accessibility` component's night-light entry bind the same
`hyprsunset` toggle on `$mainMod SHIFT, N`. The writer must **not** emit the bind twice (Hyprland
warns on duplicate binds and keeps the last one) — first-wins, and the writer should track which
component already emitted it. Same `hyprsunset` package in the install batch (dedup via
`--needed`).

## Version note — `hyprsunset` and `hyprshot` track Hyprland

Both are part of the Hyprland project and follow the same release cadence. They are stable across
the version cliffs documented in `_shared/version-matrix.md`; no branching needed here.

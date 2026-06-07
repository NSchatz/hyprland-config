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
| Screen recording | (`wl-screenrec` was here briefly in 2025) | **`wf-recorder`** | Repo C package, no ffmpeg-next pin. See "Screen recorder default" below — `wl-screenrec` is opt-in only. |
| Capture wrapper | bare `grim`+`slurp` | **`grimblast`** or `hyprshot` | Window-capture honors Hyprland geometry; output dir, edit-arg handling. |

`hyprshot` and `satty` moved from AUR to `extra` in 2025-08; `swayosd` moved to `extra` earlier.
`wl-screenrec`, `wlogout`, `bemoji`, and `grimblast` remain AUR-only.

The shipped `screenshot.sh` auto-detects in the order **grimblast → hyprshot → bare `grim`+`slurp`**;
`screenrecord.sh` prefers **`wf-recorder` → `wl-screenrec`**. Listing multiple capture/recording
tools in the install batch is harmless — the script picks the first present, and a user who later
uninstalls one still gets a working script via the fallback chain.

## Screen recorder default — wf-recorder (repo), not wl-screenrec (AUR Rust)

Defect #7. **Default to `wf-recorder`**, not `wl-screenrec`:

- `wf-recorder` is in `extra`, written in C, no ffmpeg-next pin — it just keeps working as
  `ffmpeg` moves.
- `wl-screenrec` is an AUR Rust build that pins `ffmpeg-next 8.0.0`, whose hand-written
  exhaustive matches don't cover ffmpeg-8 enum variants. The build fails with `E0004`s; with
  batch-mode AUR installs, that one failure aborts the entire batch and the user loses every
  AUR package that hadn't been built yet. The installer agent now installs AUR packages
  individually (see `agents/hyprland-package-installer.md` step 3) so one broken build can't
  poison the rest, but `wl-screenrec` should still be opt-in only.

When the user explicitly opts in to `wl-screenrec` (Intel/AMD VAAPI HW-encoded MP4 — real
benefit for long recordings on a laptop), include **both** `wf-recorder` and `wl-screenrec` in
the install batch. `screenrecord.sh` prefers `wf-recorder` so a `wl-screenrec` build failure
doesn't leave the user without a recorder.

Broader rule: **prefer repo packages over AUR Rust builds when a functional equivalent exists**.
The same logic applies to `eww` (Rust, AUR — but unique), `swww` (Rust, archived — fork is
`awww`), `matugen` (Rust, AUR — but unique), `paru` itself: when there's a repo C/C++ tool that
does the job, pick that one.

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

## wlogout: layer-shell namespace is `logout_dialog` (for the blur layerrule)

When wlogout is compiled with `gtk-layer-shell` (the standard Arch package config), it sets the
layer-shell namespace to **`logout_dialog`** (`ArtsyMacaw/wlogout:main.c` →
`gtk_layer_set_namespace(win, "logout_dialog")`). To get a translucent backdrop *with* a blurred
background of the desktop behind it (the corpus default), the `window-rules` component must emit:

```ini
layerrule = blur, logout_dialog
layerrule = ignorezero, logout_dialog
```

The translucency in `style.css` (`alpha(@bg, 0.85)`) alone gives you a frosted-glass *color*; the
`layerrule` is what actually blurs the pixels of whatever is under wlogout. Without it the
desktop just shows through, tinted. This is the same pattern `window-rules` already does for
launcher/notification daemons — extend it to `logout_dialog`. Flag for `window-rules` agent.

If wlogout was compiled without layer-shell support (rare — only some BSDs / minimal builds), it
falls back to xdg-shell and the layerrule has no effect; CSS `alpha()` is then the only knob.
Probe with `wlogout --help` — the `--protocol` flag is only present when layer-shell support is
compiled in.

## wlogout: prefer `hyprctl dispatch exit 0` over `loginctl terminate-user`

The upstream wlogout default `layout` file's logout button runs `loginctl terminate-user $USER`,
which ends **every session for that user** — including TTY logins and SSH connections. On a
single-seat desktop this is usually fine, but if the user is debugging Hyprland from a TTY or
has an SSH session open from another machine, the upstream default kills those too. The corpus
majority (`hyprctl dispatch exit 0`) exits Hyprland cleanly and leaves other sessions intact —
that's the default our recipe ships. See `template.md` "wlogout — layout".

## wlogout `layout` is JSON-lines, NOT a JSON array

`man 5 wlogout` specifies the layout as a sequence of bare `{ … }` objects separated by
whitespace — no surrounding `[ … ]`, no commas between objects. Writers tempted to JSON-encode
the whole list with `jq -n '[…]'` will produce a file the parser rejects with a cryptic
"missing key" error on line 1. The shipped recipe's blocks are literal — emit them with a
heredoc, not a JSON encoder.

## swayosd is NOT in any top-corpus rice as of 2026-06

Searched the top 19 active rices: none ship a `swayosd/` directory at HEAD. HyDE explicitly
*auto-detects* swayosd at runtime in `Configs/.local/share/bin/volumecontrol.sh` ("Check if
SwayOSD is installed" — falls back to `notify-send` when absent), but does not ship a config.
The corpus default for volume/brightness OSDs is still **bar-rendered indicators** (waybar
`pulseaudio`/`backlight` modules, Quickshell's `OSD.qml`) plus `notify-send`-driven toast
fallback. If the user wants swayosd, they install it standalone — there is no themed config to
copy. This is why `swayosd` is in `packages.md` (so the brightness keybind can use
`swayosd-client`) but NOT in `interview.md` as a selectable utility.

## wlogout.tmpl coherence rule

The four `@define-color` lines in `wlogout.tmpl` (`bg fg accent surface`) are exactly the set
`_shared/colors-contract.md` declares for wlogout, **and** they are exactly what `template.md`'s
`style.css` consumes (`@bg`, `@fg`, `@accent`, `@surface`). If you add a new var to either, add
it to both. v0.13 fixed a class of bug where `.tmpl` exports drifted from `template.md` usage —
guard against that here by walking the four names whenever you touch either file.

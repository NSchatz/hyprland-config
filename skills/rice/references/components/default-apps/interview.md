# default-apps — interview

Two sub-questions, one `AskUserQuestion` call (≤ 4 sub-qs cap respected).

The launched apps wired to `$browser` / `$fileManager` variables. (The terminal and launcher get
their own dedicated components — here we just confirm the non-themed picks.)

## Sub-questions

**4a. Browser** → default `firefox`; common: `chromium`, `brave` (AUR `brave-bin`),
`qutebrowser`.
- Firefox: Wayland is the **default since 121.0 (Dec 2023)**; `env` still emits
  `MOZ_ENABLE_WAYLAND,1` as a documentation marker but it is a no-op on any current Firefox
  (see `gotchas.md`).
- Chromium / Brave / Electron apps: pick up Wayland via `ELECTRON_OZONE_PLATFORM_HINT,auto`
  (set by `env`), no per-app flag needed.
- Qutebrowser: QtWebEngine; works on Wayland via `QT_QPA_PLATFORM=wayland;xcb` (set by `env`).

**4b. File manager** → default `nautilus`; common: `thunar`, `dolphin`, `nemo`, `pcmanfm`, or a
TUI (`yazi`, `ranger`) launched in `$terminal`. Heads-up: Dolphin pulls ~33 KDE/Qt6 deps —
heavy on non-KDE hosts (see `packages.md`).

## Record paths

After the user answers, record with `record-answer.sh`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" default_apps.browser firefox
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" default_apps.files thunar
```

If the user picks a TUI (`yazi` / `ranger`) or skips the file manager, record `null`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" default_apps.files --json null
```

A TUI cannot be wired through `$fileManager` directly — `bind = $mainMod, E, exec, $fileManager`
runs the binary with no terminal and yazi/ranger exit immediately. The TUI bind belongs in
`keybinds` as `bind = $mainMod, E, exec, $terminal -e <tui>`; this component records `null` so
the standard `$fileManager` bind is suppressed. See `gotchas.md` → "TUI file managers".

## Cross-references

- Schema → `schema.md`
- The actual `$browser`/`$fileManager` lines that land in `hyprland.conf` → `template.md`
- Firefox-on-Wayland env → `../env/template.md`
- Packages → `packages.md`

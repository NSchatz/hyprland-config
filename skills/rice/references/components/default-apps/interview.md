# default-apps — interview

Two sub-questions, one `AskUserQuestion` call (≤ 4 sub-qs cap respected).

The launched apps wired to `$browser` / `$fileManager` variables. (The terminal and launcher get
their own dedicated components — here we just confirm the non-themed picks.)

## Sub-questions

**4a. Browser** → default `firefox`; common: `chromium`, `brave`, `qutebrowser`.
(Firefox path → set `MOZ_ENABLE_WAYLAND,1` in `env`.)

**4b. File manager** → default `nautilus`; common: `thunar`, `dolphin`, `nemo`, `pcmanfm`, or a
TUI (`yazi`, `ranger`) launched in `$terminal`.

## Record paths

After the user answers, record with `record-answer.sh`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" default_apps.browser firefox
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" default_apps.files thunar
```

If the user skips the file manager (TUI-in-terminal preference), record `null`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" default_apps.files --json null
```

## Cross-references

- Schema → `schema.md`
- The actual `$browser`/`$fileManager` lines that land in `hyprland.conf` → `template.md`
- Firefox-on-Wayland env → `../env/template.md`
- Packages → `packages.md`

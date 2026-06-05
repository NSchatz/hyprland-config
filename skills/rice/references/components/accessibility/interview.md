# accessibility — interview

Group 22. **One** `AskUserQuestion` call, one multi-select sub-question, **nothing pre-checked**.

Off by default — surface it once (high value for those who need it, cheap to skip for those who
don't). Every option is genuinely optional; the user may check zero, one, or all four.

## Sub-question

**22a. Accessibility helpers?** (multi-select, all off by default)

| Option | What it does |
|---|---|
| `magnifier` | Bind `SUPER+=` / `SUPER+-` to Hyprland's built-in `cursor:zoom_factor` (no external tool). Keysyms are `equal` / `minus` (X11/XKB names). |
| `large-cursor` | Bump `XCURSOR_SIZE` **and** `HYPRCURSOR_SIZE` to 32 (or 48), call `hyprctl setcursor` (hyprcursor only since 0.37) and `gsettings set org.gnome.desktop.interface cursor-size`, plus `gtk-cursor-theme-size` in `settings.ini`. |
| `night-light` | Autostart the `hyprsunset` daemon and bind keys to its IPC: `hyprctl hyprsunset temperature 4000` (on) / `hyprctl hyprsunset identity` (off). Requires hyprsunset >= 0.45 (Hyprland 0.45+). |
| `larger-ui` | Low-vision preset: bump monitor `scale` + `gsettings set org.gnome.desktop.interface text-scaling-factor 1.25` (the documented gsettings key). |

Use `multiSelect: true`. **Nothing pre-checked.** Hint text on the question should note that the
larger-UI option may trigger the fractional-scaling gotcha (see `../monitors/gotchas.md`).

## Record path

After the user answers, record with `record-answer.sh` using the `--json` form (it's an array):

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" \
  "$staging/answers.json" accessibility --json '["magnifier","large-cursor"]'
```

If the user checks zero items, record an empty array (do **not** omit the key):

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" \
  "$staging/answers.json" accessibility --json '[]'
```

Downstream writers branch on `(.accessibility // []) | length == 0`, so the key must exist.

## Strict-asking note

Per `../../_interview-protocol.md`: this gate is **always asked**, even if no `$ARGUMENTS` hint
mentions accessibility and no existing config has it. Detection (e.g. did a previous install set
`HYPRCURSOR_SIZE`?) doesn't decide the gate — the user does. Skipping this call is a defect.

## Cross-references

- Schema → `schema.md`
- Per-helper output routing → `template.md`
- Fractional-scale + cursor-format gotchas → `gotchas.md`
- Packages → `packages.md`
- Night-light overlap with utilities → `../utilities/interview.md`

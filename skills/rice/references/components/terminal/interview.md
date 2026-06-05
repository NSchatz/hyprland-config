# terminal — interview

Six sub-questions, split across **two `AskUserQuestion` calls** to respect the ≤ 4 sub-q cap. Every
sub-question is asked — none are silently defaulted, including the extras. The terminal is the
surface the user stares at most, so the interview goes deep here.

The emulator pick also sets `$terminal` in `hyprland.conf` (read by `keybinds`) and triggers a
themed colors file rendered from the rice palette (`_shared/colors-contract.md`).

## Sub-questions

### First call (4 sub-questions)

**5a. Emulator** → `kitty` **(default)**; common: `alacritty`, `foot`, `wezterm`, `ghostty`. If
`detect-theme-tools.sh` reports an installed emulator, list it first — but every option is still
offered. The pick is recorded; the `packages.md` map adds it to the install batch regardless.

**5b. Background opacity** — Opaque `1.0` **(default)** · Slightly translucent `0.95` · Frosted
`0.85` (pair with Hyprland blur on the terminal layer for a glass look) · Custom (record literal
float).

**5c. Window padding** — Comfortable `~8px` **(default)** · Tight `2–4px` · Roomy `12–16px`. One
of the biggest "looks designed vs. default" knobs (see `styling.md`).

**5d. Cursor shape & blink** — Block, no blink **(default)** · Beam · Underline · Block + blink.

### Second call (2 sub-questions)

**5e. Font size** — `11` **(default)** · `10` · `12` · `13`. The **family** is the monospace
Nerd Font from group 13; this question only sets the size. The colors file does **not** include
the size — emulator `kitty.conf` / `alacritty.toml` / etc. own that.

**5f. Extras** (`multiSelect`, all off by default) — font ligatures · larger scrollback (10k+
lines) · audible bell off · confirm-on-close off · **window swallowing** (the terminal hides
itself while a GUI app it launched is open).

If `window swallowing` is selected, the **look-feel** component must emit `misc:enable_swallow =
true` and `swallow_regex = ^(<terminal-class>)$` into `looknfeel.conf`. The `<terminal-class>` is
derived from `terminal.emulator` (kitty → `kitty`, alacritty → `Alacritty`, foot → `foot`, wezterm
→ `org.wezfurlong.wezterm`, ghostty → `com.mitchellh.ghostty`). See `gotchas.md`.

## Record paths

After each `AskUserQuestion`, persist with `record-answer.sh`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" terminal.emulator kitty
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" terminal.opacity   --json 1.0
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" terminal.padding   --json 8
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" terminal.cursor    --json '{"shape":"block","blink":false}'

bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" terminal.font_size --json 11
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" terminal.extras    --json '["scrollback-10k","swallow"]'
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" terminal.swallow   --json true
```

`terminal.swallow` is a convenience boolean mirroring the presence of `"swallow"` in `extras` —
the look-feel writer reads `terminal.swallow` directly without re-parsing the extras array.

## Cross-references

- Schema → `schema.md`
- Per-emulator recipes → `template.md`
- Design library (palette/fonts/padding/opacity) → `styling.md`
- Colors-file variable names → `../../_shared/colors-contract.md`
- Packages → `packages.md`
- The `bind = $mainMod, Return, exec, $terminal` line → `../keybinds/template.md`
- `misc:enable_swallow` + `swallow_regex` lines → `../look-feel/template.md`

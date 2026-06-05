# keybinds — interview

Six sub-questions, split across **two** `AskUserQuestion` calls (the tool's cap is 4 sub-questions
per call — see `_interview-protocol.md`). Suggested split:

- **Call 1** — 3a mod key, 3b keybind flavor, 3c vim HJKL, 3d resize submap.
- **Call 2** — 3e cheat-sheet, 3f theme switcher.

Every sub-question is asked. `(default)` reorders the option list so the matching pick lands
first; it does not authorize skipping the question.

## Sub-questions

**3a. Mod key** → `SUPER` **(default)** · `ALT`. Records as the value of the `$mainMod` variable.
Tutorials, the shipped default config, and muscle memory all assume `SUPER`; only flip to `ALT` if
the user explicitly asks (Mac-style layouts, conflicts with a VM/RDP grabber, etc.).

**3b. Keybind flavor**
- **Official default** **(default)** — `SUPER+Q` terminal, `C` close, `R` menu, `E` files, `V`
  float, `M` exit. Matches the shipped `~/.config/hypr/hyprland.conf` and every tutorial.
- **i3/sway-style** — `SUPER+Return` terminal, `Q` close, `D` menu, `F` fullscreen.
- **Minimal** — just the essentials (terminal, close, menu, exit, workspaces 1–10, focus, move).

Recorded as `keybinds.flavor` (string). Downstream the template branches on this for the apps +
window-management block.

**3c. Add vim HJKL focus?** → `No` **(default)** · `Yes`. When yes, HJKL bind to `movefocus
l/r/u/d` **in addition to** the arrow-key binds. Shifts `togglesplit` off `J` (now focus-down) to
`T`. Recorded as `keybinds.vim` (bool).

**3d. Resize submap?** → `Yes` **(default)** · `No`. When yes, `SUPER+R` enters a `submap =
resize` block (arrows/HJKL resize, `Esc` exits via `submap = reset`). Near-universal nicety;
template lines come straight from `template.md`. Recorded as `keybinds.resize_submap` (bool).

**3e. Keybind cheat-sheet?** → `Yes, bind SUPER+/` **(default)** · `No`. When yes, drops
`assets/scripts/keybind-cheatsheet.sh` at `~/.config/hypr/scripts/keybind-cheatsheet.sh` and binds
`SUPER+/` to run it. The script reads live binds via `hyprctl binds -j | jq …` (so it stays in
sync with the actual config) and pipes them through `$dmenu`. **Needs** `jq` + a launcher
(rofi/wofi/fuzzel). The launcher dependency is satisfied by whatever the user picked in component
8 — confirm that pick exists before emitting this bind. Recorded into `keybinds.extras` as the
string `"cheatsheet"`.

**3f. Theme-switcher keybind?** →
- `Yes, SUPER+SHIFT+T opens a theme menu` **(default)** — drops `assets/scripts/theme-switch.sh`,
  binds `SUPER+SHIFT+T` to it. The script lists every saved rice profile via `rice themes` and
  feeds them through `$dmenu`; the user picks one and the engine swaps the palette in-place.
- `Menu + a SUPER+CTRL+T dark/light toggle` — both binds. The toggle binds `rice theme-toggle
  <light> <dark>` between two named profiles (default the chosen scheme's dark variant + a light
  one, e.g. `catppuccin-mocha` / `catppuccin-latte`). The toggle needs no launcher; the menu
  does.
- `No`.

Recorded into `keybinds.extras` as `"theme-switch"` (menu only) or `"theme-switch"` +
`"theme-toggle"` (both). When `theme-toggle` is selected, also record `keybinds.theme_dark` and
`keybinds.theme_light` (the two named profile slugs).

## Record paths

After each `AskUserQuestion` call, persist with `record-answer.sh`:

```bash
# Call 1 (3a–3d)
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" keybinds.mod SUPER
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" keybinds.flavor official-default
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" keybinds.vim --json false
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" keybinds.resize_submap --json true

# Call 2 (3e–3f) — extras is an array; pass full list each time
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" keybinds.extras \
  --json '["cheatsheet","theme-switch"]'
# Toggle path also records the two profile slugs:
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" keybinds.theme_dark  catppuccin-mocha
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" keybinds.theme_light catppuccin-latte
```

If the user picks "No" to 3e or 3f, drop the matching slug from `keybinds.extras` (omit, don't
record an empty placeholder).

## Cross-references

- Schema → `schema.md`
- Templates (`hyprland.conf` index + `binds.conf` bind table) → `template.md`
- Dispatchers (catalog, plugin-gating rule, bind-flag variants) → `../../_shared/dispatchers.md`
- Variables fed by sibling components → `../default-apps/`, `../terminal/`, `../launcher/`
- Util-script and ecosystem binds gated by sibling picks → `../utilities/`,
  `../lock-screen/`, `../accessibility/`, `../laptop/`
- Packages → `packages.md`

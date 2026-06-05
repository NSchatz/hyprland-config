# launcher — interview

Five sub-questions across 1–2 `AskUserQuestion` calls (the cap is 4 per call, so 8a–8d in the
first call and 8e in a follow-up). Every sub-question gets asked — see `_interview-protocol.md`,
strict no-defaulting.

The launcher is a dedicated group (separate from `default-apps`) because it gets a themed
config, not just a `$variable`. Pick the tool, the mode, the layout, whether to show icons, and
matching behavior.

## Sub-questions

**8a. Launcher tool** → `wofi` **(default)**, `rofi`, `fuzzel`, `tofi`, `walker`, `vicinae`,
`anyrun`. Notes the user sees:
- `wofi` — GTK-based, fast, simple CSS theming. The defaultable, palette-coherent pick.
- `rofi` — most themeable (RASI language). Use `rofi-wayland` (AUR) for native layer-shell.
- `fuzzel` — INI config, Wayland-native, minimal. Colors merged into `[colors]`.
- `tofi` — INI, text-only, fast. No app icons by design.
- `walker` — Wayland-native, runs as a service for instant startup. Ships own config/style format.
- `vicinae` — Qt, the 2025 Raycast-for-Linux. Runs Raycast extensions, bundles
  clipboard/calc/emoji/window-switch. Engine themes only what it exposes.
- `anyrun` — krunner-style, plugin-extensible. Ships own config (`.ron`) and CSS style.

**8b. Mode** → `drun` (app launcher) **(default)**, `run-drun` (run + drun combined), plus an
opt-in window-switcher bind (records separately, off by default).

**8c. Layout & size** → `centered` (~600px, single column) **(default)**, `compact-top` (slim
list anchored top), `fullscreen-grid` (whole screen, icon grid), `multi-column` (icon grid in a
centered card).

**8d. Show icons?** → `true` (app icons, requires icon theme) **(default)**, `false` (text only,
faster, no icon theme needed). tofi forces `false` regardless.

Second call:

**8e. Matching & behavior** *(multi-select)* — `fuzzy` (fuzzy matching) **(on by default)**,
`type-to-search`, `hide-scrollbar`, `close-on-focus-loss` **(on by default)**.

## Record paths

After each `AskUserQuestion` call, persist each pick to `<staging>/answers.json` via
`record-answer.sh`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" launcher.tool wofi
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" launcher.mode drun
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" launcher.layout centered
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" launcher.icons --json true
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" launcher.behavior --json '["fuzzy","close-on-focus-loss"]'
```

For the optional window-switcher bind (a separate `keybinds.extras` entry, not a launcher key):

```bash
# only when the user opted in during 8b — recorded by the keybinds component, not here:
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" keybinds.extras --json '["window-switcher"]'
```

## Cross-references

- Schema → `schema.md`
- Per-tool config + style recipes → `template.md`
- Styling-technique catalog (selection idioms, blur, sizing) → `styling.md`
- The `$menu`/`$dmenu` lines in `hyprland.conf` → `../keybinds/template.md`
- The launcher `layerrule` blur block → `../window-rules/template.md`
- Packages → `packages.md`

# hyprpanel - widgets

Everything this plugin knows about authoring **hyprpanel** for the `widgets` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template
- Validation
- Gotchas
- Reload

---

## Template


HyprPanel owns its colors via a **GUI** (Dashboard → gear icon) and a JSON `theme.*` block — the
rice skill does **not** register a manifest line for it. Theming path:

- Install `hyprpanel` (AUR — see `packages.md`).
- Add `exec-once = hyprpanel` to `hyprland.conf` (autostart component).
- For Material-You-on-wallpaper: install `matugen`, point it at the wallpaper, enable
  `Theming > Matugen Settings` in the HyprPanel GUI. The rice skill writes a matugen config
  pointing at the current wallpaper; on every theme switch the wallpaper changes and HyprPanel
  re-themes.
- For a static palette: import a `.json` theme via `Theming > General Settings > Import/Export` —
  one-time, no rice-engine integration.

Same model for the other Material-You-native shells (end-4, caelestia) and for any turnkey shell:
let matugen own colors while palette.conf still owns every other app. **Keep one palette source per
run** so they stay consistent — see `gotchas.md`.

---

## Validation


HyprPanel reads `~/.config/hyprpanel/config.json` (and `~/.config/hyprpanel/modules.json` in newer
builds). Validation is JSON-shape only — the rice skill doesn't re-render this file:

```bash
jq empty "$HOME/.config/hyprpanel/config.json" >"$staging/hyprpanel-validate.log" 2>&1 || {
  echo "ERROR: hyprpanel config.json is not valid JSON" >&2
  exit 1
}
```

If the user picked `widgets.look == material-you`, also validate the matugen config:

```bash
matugen --version >/dev/null 2>&1 || {
  echo "ERROR: matugen not installed; required for widgets.look == material-you" >&2
  exit 1
}
```

---

## Gotchas


HyprPanel ships a **GUI theming dialog** + `.json` theme import; end-4 / caelestia / Noctalia /
DankMaterialShell ship their own Material 3 → Colors singleton pipelines. They don't read a rice
template. Trying to register one means two palette sources fighting — one from the engine
(`palette.conf`-driven), one from the shell's own (matugen / `.json` / wallpaper-extracted).

**Fix:** when `widgets.system` is `hyprpanel` / `turnkey` (or when `widgets.look == material-you`
for any shell), the engine **does not** register a widget manifest line. Instead it:

1. Adds `matugen` to the install batch (see `packages.md`).
2. Writes `~/.config/matugen/config.toml` pointing at the active wallpaper.
3. On every `rice apply` (theme switch), re-runs matugen against the new wallpaper so the shell
   re-themes itself.
4. Keeps `palette.conf` driving every other component — terminal, waybar (if still running),
   launcher, hyprlock, GTK — so the desktop stays coherent.

**Warn the user:** the shell's bar / notifications / launcher use *its* palette, which may
visibly differ from waybar / kitty / rofi if both are running. The cohesion point is the
wallpaper — pick one matugen-driven wallpaper and the shell's palette stays aligned to the
engine's named-scheme picks within rounding error.

---

## Reload


HyprPanel doesn't have a CLI reload — theming changes go through the GUI ("Dashboard → gear icon
→ Theming") or matugen. The rice skill's `rice apply` for a HyprPanel desktop:

1. **Writes matugen config** at `~/.config/matugen/config.toml` pointing at the active wallpaper.
2. **Runs matugen**: `matugen image "$wallpaper"`.
3. matugen writes color files (the location is configured per `matugen-themes/hyprpanel`); the
   user enables "Matugen Settings" in HyprPanel's dialog once at setup, and HyprPanel re-themes
   on the next matugen run.
4. If HyprPanel is running and its file-monitor doesn't catch the change (the GUI normally does),
   `pkill -SIGUSR1 hyprpanel` is the documented refresh — but version-dependent. The rice skill
   logs the matugen run and lets HyprPanel's normal refresh path handle it.

Guard:

```bash
if command -v matugen >/dev/null; then
  matugen image "$wallpaper" >/dev/null 2>&1 || true
fi
```

(The validator already ensured `matugen` is installed for this path — see `packages.md`.)


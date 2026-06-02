---
name: Theme Hyprland Desktop
description: This skill should be used when the user runs "/hyprland-config:theme-config" or asks to theme, recolor, restyle, or set the fonts of their Hyprland desktop — e.g. "theme my desktop", "apply Catppuccin/Gruvbox/Nord/Tokyo Night to everything", "change my color scheme", "make my colors match my wallpaper", "set up matugen/wallust", "theme my waybar/kitty/gtk", "change my accent color", or "change/choose my font". Resolves one palette (named scheme, wallpaper-generated, or manual hex), presents font choices (UI + monospace/Nerd), and applies them consistently across Hyprland, hyprlock, waybar, notifications, launcher, terminal, and GTK/Qt/cursor/icons/fonts — backing up and reloading each app.
argument-hint: "[scheme or request, e.g. 'catppuccin mocha' or 'match my wallpaper']"
allowed-tools: AskUserQuestion, Bash, Read, Write, Edit, Glob, Grep
version: 0.1.0
---

# Theme Hyprland Desktop

Apply one coherent color palette across the whole Hyprland desktop. The model is **one normalized
palette → render per-app color files → reload each app** (see
`references/theming.md`). Treat `$ARGUMENTS` as the requested scheme or source.

Read `references/theming.md` (architecture, per-surface mechanics, reload commands),
`references/palettes.md` (named schemes), and `references/templates.md` (per-app color templates)
before applying. Use only currently-correct syntax — for Hyprland color files defer to the
**hyprland-reference** skill.

## Workflow

### 1. Detect tooling & current appearance

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/detect-theme-tools.sh"
```

It prints `HAVE_*`/`MISSING_*` for generators (matugen/wallust/pywal), terminals, bars, notifiers,
and theming tools, plus `CURRENT_*` gsettings (current GTK/icon/cursor/font). Use it to (a) know
which surfaces exist to theme, and (b) read the starting state.

### 2. Choose the palette source (always ask)

Ask the user (don't assume a default scheme):

- **Named scheme** → pick from `palettes.md` (Catppuccin Mocha/Latte, Gruvbox, Nord, Tokyo Night,
  Rosé Pine). Resolve straight to the palette contract.
- **Wallpaper-generated** → needs `matugen` or `wallust`. If neither is installed (per step 1),
  **offer a named scheme or manual instead** and tell the user the package to install — do not
  install it. If available, run it on the wallpaper, obtain the palette (matugen
  `matugen image <img> --json hex`; wallust writes a colors file), and map to the contract.
- **Manual** → ask for at least `bg`, `fg`, `accent`; derive the rest, or ask for the full 16.

Resolve everything to the **palette contract** (`theming.md`) as bare `RRGGBB` before rendering.

### 3. Choose surfaces (default: all installed)

Confirm which to theme; default to every surface whose app is installed/running:
Hyprland + hyprlock, waybar, mako/dunst, wofi/rofi, kitty/terminal, GTK (3+4), Qt, cursor/icons/
fonts. Skip surfaces whose app isn't present (note them).

### 3b. Present font choices (always ask)

Fonts are a presented choice — don't pick silently. Read `references/fonts.md`. Using the
`HAVE_NERD_FONT` / `FONT_MONO=` / `FONT_SANS=` / `CURRENT_*FONT*` lines from step 1, present the
user with options for:

- a **UI / sans font** (GTK text), and
- a **monospace / Nerd font** (terminal, bar, fetch, prompt) — default to an **installed Nerd
  Font** (e.g. `JetBrainsMono Nerd Font`) so glyphs render.

Offer the installed families first; if `MISSING_NERD_FONT`, offer the catalog from `fonts.md` and
note the package to install (don't install it). Apply the chosen fonts across `gsettings`
(`font-name`, `monospace-font-name`), GTK `settings.ini`, kitty `font_family`, and waybar
`font-family` per `fonts.md`/`templates.md`.

### 4. Back up everything first

Back up every file about to change in one timestamped set:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" \
  ~/.config/hypr ~/.config/waybar ~/.config/mako ~/.config/kitty \
  ~/.config/gtk-3.0 ~/.config/gtk-4.0 ~/.config/wofi ~/.config/rofi
```

(Pass only the paths actually being changed.) Record the `BACKUP ... -> ...` lines to relay.

### 5. Render color files & wire includes

For each chosen surface, write the **separate colors file** from `templates.md` and ensure the
app `include`/`@import`/`source`es it (Hyprland `colors.conf` via `source=`; waybar `colors.css`
via `@import`; kitty `colors.conf` via `include`; etc.). Use `Edit` to add the include line if
missing; use `Write` for the colors file. Never inline colors directly into the app's main config
if a separate colors file is cleaner — it makes re-theming a one-file rewrite.

For GTK/Qt/cursor/icons, write `gtk.css`/`settings.ini` and apply live settings with `gsettings`
and (cursor) `hyprctl setcursor` per `templates.md`.

### 6. Apply + reload + verify

Reload every affected running app:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/apply-theme.sh" --cursor '<Cursor>' 24
```

It reloads Hyprland, waybar, mako/dunst, kitty (only if running) and applies the cursor. Then
confirm the Hyprland color file still parses:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/generate-config/scripts/verify-config.sh"
```

`VERIFY=ok` → the compositor accepted the new colors. `VERIFY=errors` → restore the Hyprland files
from the backup, reload, and report. (Color files rarely break parsing, but test anyway.)

### 7. Report

Summarize: source + scheme, surfaces themed, files written, backup paths, and the reload/verify
results. Note any surface skipped (app not installed) and any package the user would install for
more (e.g. a matching GTK theme, or `matugen`/`wallust` for generated palettes).

## Rice engine (preferred: reproducible, re-applyable)

For a real rice, drive the **engine** instead of writing each file ad hoc — it makes the theme
reproducible and re-applyable with one command, and version-controllable. Read
`references/engine.md`. Flow:

1. Scaffold/refresh the engine: `bash "${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/rice-init.sh"`
   (creates `~/.config/hypr-rice/` with `palette.conf`, `templates/`, `templates.list`, the
   `render-templates.sh` engine, and the `rice` CLI). Idempotent.
2. Resolve the chosen palette and **write it to `~/.config/hypr-rice/palette.conf`** (the source of
   truth — `KEY=hex`, plus `scheme`/`wallpaper`/`font_ui`/`font_mono`). For wallpaper-generated,
   produce the palette with matugen/wallust first (see `engine.md`).
3. Ensure each app reads its colors file (one-time wiring: `source=`/`@import`/`include`).
4. Apply: `bash ~/.config/hypr-rice/rice apply` (renders every template + reloads running apps).
   Then `verify-config.sh` for the Hyprland part.

Re-theming later is just: rewrite `palette.conf` → `rice apply`. Adding an app is: drop a
`<name>.tmpl` in `templates/` + a manifest line. The `apply-theme.sh` path and per-app
`templates.md` remain valid for one-off, non-engine theming.

## Safety rules

- Back up every file before writing (step 4); keep the `BACKUP` paths for rollback.
- Reload apps rather than forcing a logout; only reload what's running.
- Don't install packages — suggest them.
- After Hyprland color changes, always run `verify-config.sh`; never leave it in `VERIFY=errors`.

## Resources

- **`references/theming.md`** — architecture, palette contract, per-surface mechanics, reloads.
- **`references/palettes.md`** — named schemes mapped to the contract + matching GTK/cursor/icons.
- **`references/fonts.md`** — font roles, the catalog to present, detection, and how to apply a
  UI font + monospace/Nerd font across surfaces.
- **`references/engine.md`** — the rice engine: `palette.conf` source of truth, the render
  manifest, the `rice` CLI, matugen/wallust integration, adding apps, and reproducibility.
- **`scripts/rice-init.sh`** — scaffold/refresh the engine into `~/.config/hypr-rice/`.
- **`scripts/render-templates.sh`** — the render engine (also installed for the `rice` CLI).
- **`templates/*.tmpl`** — the color templates the engine renders.
- **`references/templates.md`** — per-app color templates.
- **`scripts/detect-theme-tools.sh`** — tooling + current-appearance probe.
- **`scripts/apply-theme.sh`** — reload running apps (+ live cursor).
- **`${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh`** — timestamped backup of arbitrary paths.
- **`${CLAUDE_PLUGIN_ROOT}/skills/generate-config/scripts/verify-config.sh`** — Hyprland parse test.

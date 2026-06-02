---
name: wallpaper
description: This skill should be used when the user runs "/hyprland-config:wallpaper" or asks to set, change, or cycle their wallpaper, or to theme their desktop from the wallpaper — e.g. "set my wallpaper to X", "change wallpaper and match my colors", "make my theme match my wallpaper", "cycle wallpapers", "random wallpaper", or "set up wallpaper-based theming". Sets the wallpaper (swww/hyprpaper/swaybg), optionally extracts a palette from it (matugen/wallust/pywal) and re-themes the whole desktop via the rice engine, and can set up wallpaper cycling.
argument-hint: "[image path or request, e.g. '~/Pictures/wall.png and theme from it']"
allowed-tools: AskUserQuestion, Bash, Read, Write, Edit, Glob, Grep
version: 0.1.0
---

# Wallpaper & Dynamic Theming

Set the wallpaper and (optionally) drive **wallpaper-based theming**: extract a palette from the
image and re-theme every app through the rice engine. This is the canonical rice front door —
"change wallpaper, the whole desktop follows." Treat `$ARGUMENTS` as the image path / request.

Read `references/wallpaper.md` (backends, dynamic theming, cycling) and the rice engine reference
`${CLAUDE_PLUGIN_ROOT}/skills/theme-config/references/engine.md`.

## Workflow

### 1. Detect backend & generator

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/detect-theme-tools.sh"
```

Note the wallpaper backend (`HAVE_swww`/`HAVE_hyprpaper`) and palette generator
(`HAVE_matugen`/`HAVE_wallust`/`HAVE_pywal`). If none of the generators is installed, you can still
set the wallpaper; for *dynamic theming* offer a named/manual palette instead and note the package
(`matugen` recommended). Never install anything.

### 2. Ensure the rice engine exists

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/rice-init.sh"
```

Idempotent — scaffolds/refreshes `~/.config/hypr-rice/` (incl. the wallpaper helpers + `rice` CLI).

### 3. Set the wallpaper (+ optionally theme)

Resolve the image path (ask if not given; common dir `~/Pictures/wallpapers`). Then:

- **Wallpaper only:** `bash ~/.config/hypr-rice/rice wallpaper '<image>' --no-theme`
- **Wallpaper + dynamic theme** (the rice flow): `bash ~/.config/hypr-rice/rice wallpaper '<image>'`
  — sets the wallpaper, regenerates `palette.conf` from it (matugen/wallust/pywal), renders every
  template, and reloads each app.

Back up first if overwriting an existing wallpaper config:
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" ~/.config/hypr/hyprpaper.conf ~/.config/hypr-rice/palette.conf`.

### 4. Verify

After theming, confirm Hyprland still parses:
`bash "${CLAUDE_PLUGIN_ROOT}/skills/generate-config/scripts/verify-config.sh"`. If
`VERIFY=errors`, restore `palette.conf`/`colors.conf` from the backup and re-apply.

### 5. Cycling (optional)

For rotating wallpapers, use `rice random [dir]` (random pick + re-theme). To automate without
Claude, set up a **systemd user timer** or a Hyprland `exec-once` loop — see `wallpaper.md`. Tell
the user the cadence and how to stop it.

### 6. Report

Summarize: wallpaper set (+ backend), whether the palette was regenerated (and how), apps reloaded,
backup paths, and any package to install for dynamic theming.

## Notes

- Material You (matugen) → ANSI `color0..15` mapping is approximate; wallust/pywal give a true
  16-color scheme. State this when relevant.
- The wallpaper path is recorded in `palette.conf` (`wallpaper=…`), so the rice state captures it
  and profiles/version-control reproduce it.

## Safety rules

- Back up `hyprpaper.conf`/`palette.conf` before overwriting.
- Don't install packages — suggest them.
- After theming, run `verify-config.sh`; never leave Hyprland in `VERIFY=errors`.

## Resources

- **`references/wallpaper.md`** — backends, dynamic theming, cycling automation.
- **`${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/set-wallpaper.sh`** — set wallpaper (any backend).
- **`${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/palette-from-wallpaper.sh`** — extract palette.
- **`${CLAUDE_PLUGIN_ROOT}/skills/theme-config/references/engine.md`** — the rice engine + `rice` CLI.

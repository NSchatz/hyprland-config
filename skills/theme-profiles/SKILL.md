---
name: theme-profiles
description: This skill should be used when the user runs "/hyprland-config:theme-profiles" or asks to save, switch, list, or manage named desktop theme profiles ("rices") — e.g. "save my current theme as X", "switch to nord/gruvbox/tokyo-night", "list my themes", "load my <name> rice", "go back to my saved theme", or "pin my accent color so re-theming doesn't change it". Manages saved theme profiles and the user-override layer on top of the rice engine.
argument-hint: "[action, e.g. 'save as midnight' or 'switch to nord']"
allowed-tools: AskUserQuestion, Bash, Read, Write, Edit, Glob, Grep
version: 0.1.0
---

# Theme Profiles

Save, list, and switch named "rices" (complete theme snapshots) and manage the **user-override
layer** — personal color pins that survive every theme/wallpaper change. Built on the rice engine
(`${CLAUDE_PLUGIN_ROOT}/skills/theme-config/references/engine.md`). Treat `$ARGUMENTS` as the action.

A **profile** is a snapshot of `palette.conf` (palette + scheme + wallpaper + fonts), stored at
`~/.config/hypr-rice/profiles/<name>.conf`. Five presets ship out of the box: `catppuccin-mocha`,
`gruvbox`, `nord`, `tokyo-night`, `rose-pine`.

## Workflow

### 1. Ensure the engine exists

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/rice-init.sh"
```

Idempotent — also installs the preset profiles (without clobbering customized ones).

### 2. Do the requested action (via the `rice` CLI)

- **List:** `bash ~/.config/hypr-rice/rice themes`
- **Switch/apply:** `bash ~/.config/hypr-rice/rice theme <name>` — loads that profile's palette
  (and its recorded wallpaper, if any), renders every template, and reloads apps.
- **Save current as a profile:** `bash ~/.config/hypr-rice/rice save <name>` — snapshots the
  current `palette.conf`.
- **Apply current without switching:** `bash ~/.config/hypr-rice/rice apply`.

Back up `palette.conf` before a switch if the current state isn't already saved:
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" ~/.config/hypr-rice/palette.conf`.

### 3. User-override layer (pins that survive re-theming)

To keep a personal tweak (e.g. always use a specific accent) regardless of which profile or
wallpaper is active, write `KEY=hex` lines into `~/.config/hypr-rice/palette.user.conf`. The render
engine overlays it **after** the profile/generated palette, so the cascade is
`generated/profile → user`. Edit it with the `Write`/`Edit` tools, then `rice apply`. Example:

```
# ~/.config/hypr-rice/palette.user.conf — always win
accent=cba6f7
font_mono=JetBrainsMono Nerd Font 12
```

### 4. Verify & report

After a switch/apply, run `verify-config.sh` (Hyprland parse). Report: profile applied, wallpaper
(if any), apps reloaded, and any active overrides. If `VERIFY=errors`, restore from backup.

## Notes

- Switching a profile does **not** clear `palette.user.conf` — overrides are intentionally
  persistent. To drop an override, remove its line and `rice apply`.
- Profiles version-control well: committing `~/.config/hypr-rice/` (see the dotfiles skill)
  captures every saved rice and the current state in git history — a profile per branch/tag also
  works.

## Safety rules

- Back up `palette.conf` before switching if the current state isn't saved.
- After applying, run `verify-config.sh`; never leave Hyprland in `VERIFY=errors`.

## Resources

- **`${CLAUDE_PLUGIN_ROOT}/skills/theme-config/references/engine.md`** — engine, palette, cascade.
- **`${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/rice-init.sh`** — scaffold + install presets.
- **`${CLAUDE_PLUGIN_ROOT}/skills/generate-config/scripts/verify-config.sh`** — Hyprland parse test.

---
name: hyprland-reference
description: This skill should be used when the user asks about Hyprland configuration syntax, "hyprland.conf", how to configure monitors, input, decoration, animations, keybinds/keybindings, dispatchers, submaps, window rules, layer rules, workspace rules, gestures, or environment variables in Hyprland, what a Hyprland config option or hyprctl keyword does, whether a Hyprland option is deprecated or renamed, to review/audit an existing hyprland.conf for outdated syntax, or about the Hyprland ecosystem and companion packages (hyprlock, hypridle, hyprpaper, hyprpicker, hyprsunset, hyprpolkitagent, waybar, status bars, launchers like wofi/rofi/fuzzel, notification daemons, clipboard managers, screenshot tools, portals/screen sharing) and how to wire them in. Provides authoritative reference material for the Hyprland (Wayland compositor) config language and ecosystem.
version: 0.1.0
---

# Hyprland Config Reference

Authoritative reference for the Hyprland configuration language: file format, every major
config section, keybinding/dispatcher syntax, window rules, and a catalog of options that have
been renamed or removed across versions. Use this to answer "how do I configure X in Hyprland"
questions and to write or audit `hyprland.conf` files that use correct, current syntax.

## Hyprland config in 60 seconds

- Default config path: `~/.config/hypr/hyprland.conf`.
- The config is a live document — Hyprland reloads it automatically on save (unless
  `misc:disable_autoreload` is set).
- Two equivalent ways to set options:
  - **Nested block:** `general { gaps_in = 5 }`
  - **Flat keyword:** `general:gaps_in = 5`
- **Variables:** define with `$name = value`, reference as `$name`. Example: `$mod = SUPER`.
- **Include other files:** `source = ~/.config/hypr/monitors.conf`. Sourcing is how modular
  configs are assembled (one main file that sources topic files).
- **Comments:** `#` to end of line.
- **Colors:** `rgba(rrggbbaa)`, `rgb(rrggbb)`, or `0xAARRGGBB`. Gradients list multiple colors
  plus an optional angle: `col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg`.

## How to use this skill

1. Identify which area the question concerns (monitor, input, decoration, binds, rules, env).
2. Read the matching reference file below — do **not** answer Hyprland syntax questions from
   memory alone, since option names shift between releases.
3. When writing or editing a config, cross-check every non-trivial option against
   `references/deprecations.md` so old tutorials' syntax is not reproduced.
4. State the Hyprland version assumption when syntax is version-sensitive. Detect the installed
   version with `hyprctl version` when a real system is available.

## Reference files

Consult these as needed — each is loaded only when relevant:

- **`references/config-syntax.md`** — file format, variables, sourcing, keyword vs block form,
  color/gradient syntax, dynamic variables, and config-reload behavior.
- **`references/sections.md`** — every major section (`monitor`, `input`, `general`,
  `decoration`, `animations`, `dwindle`, `master`, `gestures`, `group`, `misc`, `cursor`,
  `binds`, `xwayland`) with their commonly used options and value types.
- **`references/keybindings.md`** — `bind` and its variants (`bindm`, `binde`, `bindl`,
  `bindr`, `bindel`, …), modifier syntax, submaps, and the dispatcher catalog.
- **`references/window-rules.md`** — `windowrule` / `windowrulev2`, `layerrule`,
  `workspace` rules, matcher fields (class, title, initialClass, …), and common recipes.
- **`references/deprecations.md`** — options that were renamed or removed and their modern
  replacements (shadow/blur subcategories, `master:new_status`, cursor category, the
  `windowrule`/`windowrulev2` merge, and more). Check this before trusting any older example.
- **`references/testing.md`** — how to read a config (resolving `source=`) and how to actually
  test it on a live Hyprland (`hyprctl reload` + `hyprctl configerrors`, `hyprctl keyword` for a
  single option), plus the safe apply→test→rollback pattern. Use whenever changing a live config.
- **`references/ecosystem.md`** — the official Hypr ecosystem tools (`hyprlock`, `hypridle`,
  `hyprpaper`, `hyprpicker`, `hyprsunset`, `hyprpolkitagent`, `hyprshot`, portals) plus the
  community packages commonly paired with Hyprland (status bars, launchers, notification
  daemons, clipboard, screenshots, OSD, theming), with launch commands and the `hyprlock` /
  `hypridle` / `hyprpaper` config formats. Use when wiring companion apps into a config.

## Common pitfalls

- Shadow and blur options moved into `decoration:shadow { }` and `decoration:blur { }`
  subcategories — `drop_shadow`/`shadow_range` at the top of `decoration` are deprecated.
- `master:new_is_master` was replaced by `master:new_status` / `master:new_on_top`.
- Several cursor options moved from `general`/`input` into a dedicated `cursor { }` category.
- `windowrulev2` syntax was merged into `windowrule`; both still parse but prefer the unified
  form on current versions. See `references/deprecations.md`.
- `monitor` lines are positional: `name, resolution@hz, position, scale` — order matters.

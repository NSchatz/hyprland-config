# palette.conf schema (canonical)

The rice engine's source of truth lives at `~/.config/hypr-rice/palette.conf`. Every key listed
below is **required**; templates fail to render if any is missing. Hex values are **without** the
leading `#`.

## Color keys

```
bg              # window background, base surface
fg              # primary text
surface         # raised surface (cards, drawers, inactive borders)
muted           # secondary text, dimmed UI
cursor          # cursor color (used by GTK + hyprcursor as a tint)

accent          # primary accent — focus rings, active workspace, signal
accent2         # secondary accent — gradient endpoint for col.active_border, hover

# Semantic / signal colors
red             # error, urgent, battery-critical
green           # success, online, charging
yellow          # warning, low-priority signal
blue            # info, network
magenta         # decorative second-tier signal
cyan            # decorative third-tier signal

# ANSI 16-color palette (terminals, prompts; matches xterm 16)
color0  color1  color2  color3  color4  color5  color6  color7
color8  color9  color10 color11 color12 color13 color14 color15
```

## Metadata keys

```
scheme          # "catppuccin-mocha" | "manual" | "wallpaper" | "tokyo-night" | …
wallpaper       # absolute path to the current wallpaper (or empty)
font_ui         # "Inter 11"  (family + size — size is meaningful for hyprlock)
font_mono       # "JetBrainsMono Nerd Font 11"
```

## Sizing rules

- `font_ui` / `font_mono` are written **with** the trailing size; consumers strip it when only the
  family is wanted (e.g. waybar `font-family`, kitty `font_family`, QML `font.family`).
- Hyprland color values wrap as `rgb({{accent}})` (Hyprland doesn't take a hash); CSS wraps as
  `#{{accent}}`; kitty wraps as `#{{color1}}`.
- `accent2` must **always be populated** — even on the manual path where only `bg`/`fg`/`accent`
  were collected (default it to `accent` or a derived neighbour). The `looknfeel.conf` border
  template references it, so a missing value errors the reload.

## Sources

- **Named scheme** → look up the hex in `theming/palettes.md`.
- **Wallpaper-generated** → run `scripts/palette-from-wallpaper.sh <image>` (matugen or wallust);
  map matugen's `primary→accent`, `secondary→accent2`, `surface→bg`, `on_surface→fg`,
  neutrals→`muted`/`surface`, and the source/extended colors → `color0..15`.
- **Manual hex** → write the user's values directly; derive `accent2` and the `color*` set from
  the chosen `accent` if not collected.

## Render flow

`rice apply` → `render-templates.sh`:
1. Loads `palette.conf` into variables (KEY=hex).
2. For each manifest line (`name <TAB> template <TAB> output <TAB> reload-cmd`): substitutes
   `{{key}}` in the template → writes the output file.
3. Runs the app's reload hook (guarded — a no-op if the app isn't running).

The render-manifest line shape is documented in `theming/engine.md`.

## Cross-references

- Per-app variable names every component's colors file exports → `colors-contract.md`
- Named scheme catalog → `theming/palettes.md`
- Font handling → `theming/fonts.md`
- Engine architecture (manifest, override cascade, CLI) → `theming/engine.md`

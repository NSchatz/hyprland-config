# Theme Interview — palette & fonts (shared)

The **single source of truth** for the styling questions about *color* and *fonts*. Both
`theme-config` (re-theming an existing desktop) and `generate-config` (theming a brand-new config)
read this file so the two never drift. Ask these with `AskUserQuestion`; resolve every answer into
the rice engine's **`palette.conf`** (`~/.config/hypr-rice/palette.conf` — see `engine.md`), which
is what actually renders the colors into each app.

Always run `detect-theme-tools.sh` first so the options reflect what's installed (generators,
fonts, terminals/bars present). Present installed choices first; for anything missing, still offer
it but name the package to install — never install.

---

## T1. Palette source (always ask — don't assume a scheme)

- **Named scheme (default)** → one of the schemes in `palettes.md` (Catppuccin Mocha/Latte,
  Gruvbox, Nord, Tokyo Night, Rosé Pine). Resolves straight to the palette contract.
- **Match my wallpaper** → needs `matugen` or `wallust`. If neither is installed, say so and fall
  back to a named scheme or manual (don't install). If available, generate the palette from the
  wallpaper (`palette-from-wallpaper.sh`) and map it onto the contract.
- **Manual hex** → ask for at least `bg`, `fg`, `accent`; derive the rest, or collect all 16.

When the source is "named scheme", ask the **scheme** as a second question (the list from
`palettes.md`). When it's "wallpaper", confirm the wallpaper path. When it's "manual", collect the
hex values.

## T2. Accent (let the user override)

Each named scheme lists a sensible default `accent` (and `accent2`). Offer to keep it or override
with another hue from the scheme (e.g. Catppuccin mauve → blue/green/peach), or a custom hex. The
accent drives borders, focus rings, and bar highlights, so it's the highest-leverage single choice.

## T3. Light vs. dark (only when ambiguous)

Most schemes are dark; some have a light variant (Catppuccin Latte). If the user picked a scheme
with both, confirm. For light, set GTK `color-scheme = prefer-light` (see `palettes.md`).

## T4. UI / sans font (always present — don't pick silently)

The GTK app/text font. Read `fonts.md`. Using `FONT_SANS=` / `CURRENT_*FONT*` from detection,
present installed families first (Inter, Cantarell, Noto Sans, Adwaita Sans). Default to an
installed UI font; offer the catalog (naming the package) if the user wants one not present.
Record as `font_ui = <Family> <size>` (e.g. `Inter 11`).

## T5. Monospace / Nerd font (always present)

The terminal, bar, fetch, and prompt font. **Default to an installed Nerd Font** (e.g.
`JetBrainsMono Nerd Font`) so glyph icons render instead of tofu boxes (▯). Using `HAVE_NERD_FONT`
/ `FONT_MONO=`, offer installed Nerd Fonts first; if `MISSING_NERD_FONT`, offer the catalog from
`fonts.md` and name the package — warn that glyph-heavy bars/prompts show boxes until one is
installed. Record as `font_mono = <Family> <size>`.

---

## Mapping answers → `palette.conf`

Write the resolved values into `~/.config/hypr-rice/palette.conf` (the rice state / source of
truth). Keys (hex without `#`):

```
scheme=<name-or-"manual"-or-"wallpaper">
wallpaper=<path or empty>
bg fg surface muted cursor accent accent2 red green yellow blue magenta cyan
color0 … color15
font_ui=<Family size>
font_mono=<Family size>
```

**Always populate `accent2`**, including on the manual-hex path where the user only gave
`bg`/`fg`/`accent` — default it to `accent` or a derived neighbouring hue. Templates such as the
Hyprland border (`col.active_border = $accent $accent2 45deg`) reference it, so a missing value
errors the reload.

Then `rice apply` renders every wired app's colors file and reloads it. For the full contract and
render flow see `engine.md`; for the per-scheme hex see `palettes.md`; for fonts see `fonts.md`.

## Surfaces (caller-specific — NOT part of this shared bank)

*Which* apps get themed differs by caller, so each skill asks that itself:

- **theme-config** confirms the surface set (default: every installed app) — see its SKILL step 3.
- **generate-config** owns only the Hyprland files it writes; it wires `colors.conf` and lets the
  rice engine theme the rest as those configs come to exist (desktop-shell, later `rice apply`).

# The Rice Engine

A self-contained theming engine the plugin scaffolds into `~/.config/hypr-rice/`. One palette is
the source of truth; templates render it into every app's config; one command re-applies and
reloads. It keeps working **without** the plugin (the `rice` CLI), so it can be version-controlled
and automated. This is the matugen/wallust/HyDE model, owned by the user.

## Layout (`~/.config/hypr-rice/`)

```
palette.conf       # source of truth: KEY=hex (+ scheme, wallpaper, fonts). Also the rice "state".
templates/         # <app>.tmpl files using {{key}} placeholders (user-editable)
templates.list     # manifest: name <TAB> template <TAB> output <TAB> reload-cmd
render-templates.sh# the render engine (rendered from palette.conf -> outputs -> reload)
rice               # the CLI: `rice apply`, `rice palette`, …
profiles/          # saved theme profiles (theme-profiles skill)
```

Scaffold/refresh it with `scripts/rice-init.sh` (idempotent — never clobbers `palette.conf`,
`templates.list`, or user-edited templates unless `--force`).

## Palette contract (keys in `palette.conf`)

Hex without `#`: `bg fg surface muted cursor accent accent2 red green yellow blue magenta cyan`
and `color0`..`color15`. Plus metadata: `scheme`, `wallpaper`, `font_ui`, `font_mono`. Templates
add their own wrappers — `#{{accent}}` (CSS), `rgb({{bg}})` (Hyprland), `#{{color1}}` (kitty).

## Render flow

`rice apply` → `render-templates.sh`:
1. Loads `palette.conf` into variables.
2. For each manifest line: substitute `{{key}}` in the template → write the output file.
3. Runs the app's reload hook (guarded — a no-op if the app isn't running).

Re-theming = rewrite `palette.conf` and `rice apply`. Adding an app = drop a `<name>.tmpl` in
`templates/` and add a TAB-separated manifest line; no code changes.

## Wiring each app (one-time)

The render writes a **separate colors file**; wire the app to read it (done once, survives
re-theming):

- Hyprland: `source = ~/.config/hypr/colors.conf` in `hyprland.conf`.
- kitty: `include colors.conf` in `kitty.conf`.
- waybar: `@import "colors.css";` at the top of `style.css`.
- wofi: `@import "colors.css";`. rofi: `@import "colors.rasi"` from the theme. gtk4: the output
  *is* `~/.config/gtk-4.0/gtk.css`.

Apps without an include mechanism (mako, dunst) are not in the default manifest — their config is
written whole by the desktop-shell skill, which folds the colors in. Templates for them ship in
`templates/` for manual use.

## Palette sources → `palette.conf`

- **Named / manual** — the theme-config skill writes `palette.conf` directly from `palettes.md`
  (or user hex).
- **Wallpaper-generated (matugen/wallust)** — use the generator to *produce* the palette, then let
  the engine render everything:
  - **matugen**: `matugen image <wall> --json hex` prints the Material You palette as JSON; map
    `primary→accent`, `secondary→accent2`, `surface→bg`, `on_surface→fg`, neutrals→`muted/surface`,
    and the source/extended colors → `color0..15`; write those into `palette.conf`.
  - **wallust**: emits a 16-color scheme (pywal-compatible) → maps straight onto
    `color0..15`/`bg`/`fg`; derive `accent` from a chosen `colorN`.
  - The wallpaper path goes into `palette.conf` as `wallpaper=…`.

## matugen as an additional renderer (optional, for breadth)

matugen ships templates for **50+ apps** (btop, cava, starship, spicetify, discord, firefox,
neovim, qt/kvantum, niri, ghostty, helix, zed, yazi, zathura, tmux, zellij, …). To cover apps beyond
our template set, *also* configure matugen (`~/.config/matugen/config.toml` with `[templates.<app>]`
`input_path`/`output_path`/`post_hook`, optional `index` for ordering) using the same wallpaper, so
it themes the long tail while our engine owns the core + non-templated bits (gsettings, cursor,
login). Pick the scheme with `-t scheme-tonal-spot` (or `-expressive`/`-vibrant`/`-content`/
`-neutral`/`-monochrome`) and `-m dark|light`; a `[config.wallpaper] set = true; command = "swww img {{ image }}"`
block makes one `matugen image <wall>` set the wallpaper and regenerate everything. Keep one palette
source per run so the two stay consistent.

## State & reproducibility

`palette.conf` records the current `scheme`, `wallpaper`, and fonts — it *is* the rice state.
Saving a profile (theme-profiles) snapshots it; version-controlling `~/.config/hypr-rice/` (and
the app configs) in git makes the whole rice reproducible. See the dotfiles skill.

## CLI

```
rice apply              # render all + reload
rice apply --no-reload  # render only
rice palette            # show current palette
rice templates          # show the manifest
```

Because `rice` is self-contained, it can be bound to a key, run on wallpaper change, or invoked by
a systemd unit — the desktop re-themes without Claude in the loop.

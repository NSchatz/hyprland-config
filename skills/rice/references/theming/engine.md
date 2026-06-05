# The Rice Engine

A self-contained theming engine the plugin scaffolds into `~/.config/hypr-rice/`. One palette is
the source of truth; templates render it into every app's config; one command re-applies and
reloads. It keeps working **without** the plugin (the `rice` CLI), so it can be version-controlled
and automated. This is the matugen/wallust/HyDE model, owned by the user.

## Where this lives in the new tree

The engine's contracts and per-surface wiring are split across several places — this file is the
architecture; the slices live elsewhere:

- **Palette schema** (the `KEY=hex` set in `palette.conf`, metadata keys, render flow) →
  [`_shared/palette-schema.md`](../_shared/palette-schema.md).
- **Per-app colors contract** (which variable names each component's colors file exports) →
  [`_shared/colors-contract.md`](../_shared/colors-contract.md).
- **Widget-shell theming** (eww, AGS/Astal, Quickshell, HyprPanel) →
  [`components/widgets/template.md`](../components/widgets/template.md) + `widgets/styling.md`.
- **Shell & prompt theming** (fish colors, starship, oh-my-posh) →
  [`components/shell-prompt/template.md`](../components/shell-prompt/template.md) +
  `shell-prompt/styling.md`.
- **Per-surface reload mechanics, GTK gotchas, cursor, Qt** →
  [`theming-architecture.md`](theming-architecture.md).
- **Palette catalog** (the 12 named schemes) → [`palettes.md`](palettes.md).
- **Fonts** → [`fonts.md`](fonts.md).
- **Wallpaper backends + dynamic theming** → [`wallpaper.md`](wallpaper.md).
- **Long-tail apps via matugen** → [`apps.md`](apps.md).

## Layout (`~/.config/hypr-rice/`)

```
palette.conf       # source of truth: KEY=hex (+ scheme, wallpaper, fonts). Also the rice "state".
templates/         # <app>.tmpl files using {{key}} placeholders (user-editable)
templates.list     # manifest: name <TAB> template <TAB> output <TAB> reload-cmd
render-templates.sh# the render engine (palette.conf -> outputs -> reload)
rice               # the CLI: `rice apply`, `rice palette`, …
profiles/          # saved theme profiles (rice skill)
wallpapers.tsv     # curated theme-tagged wallpaper catalog (copied from the plugin)
```

Scaffold/refresh it with `scripts/rice-init.sh` (idempotent — never clobbers `palette.conf`,
`templates.list`, or user-edited templates unless `--force`).

The palette-key list itself (which keys are required, hex format, metadata fields, sizing rules)
lives in [`_shared/palette-schema.md`](../_shared/palette-schema.md). This file does not restate
it.

## Render flow

`rice apply` → `render-templates.sh`:

1. Loads `palette.conf` into shell variables (`bg=...`, `accent=...`, `font_ui=...`, …).
2. For each manifest line: substitute `{{key}}` in the template → write the output file.
3. Run the app's reload hook (guarded — a no-op if the app isn't running).

Re-theming = rewrite `palette.conf` and `rice apply`. Adding an app = drop a `<name>.tmpl` in
`templates/` and add a TAB-separated manifest line; no code changes.

## Manifest format (`templates.list`)

TAB-separated, four fields per line. Empty `reload-cmd` is valid (the app picks colors up on
launch, or hot-reloads on file save).

```
name<TAB>template-path<TAB>output-path<TAB>reload-cmd
```

Example (real tabs between fields):

```
hyprland   ~/.config/hypr-rice/templates/hyprland.tmpl   ~/.config/hypr/colors.conf      hyprctl reload
kitty      ~/.config/hypr-rice/templates/kitty.tmpl      ~/.config/kitty/colors.conf     kill -SIGUSR1 $(pidof kitty)
waybar     ~/.config/hypr-rice/templates/waybar.tmpl     ~/.config/waybar/colors.css     killall -SIGUSR2 waybar
```

Reload commands are always guarded — `render-templates.sh` checks `pidof`/`pgrep` (or uses `|| true`)
so the line is a no-op when the app isn't running. The per-app reload command catalog is in
[`theming-architecture.md`](theming-architecture.md) → "Apply + reload".

## Wiring each app (one-time)

The render writes a **separate colors file**; wire the app to read it once and the wiring survives
every re-theme:

| App | One-time wiring |
|---|---|
| Hyprland | `source = ~/.config/hypr/colors.conf` in `hyprland.conf` |
| kitty | `include colors.conf` in `kitty.conf` |
| waybar | `@import "colors.css";` at the top of `style.css` |
| wofi | `@import "colors.css";` in `style.css` |
| rofi | `@import "colors.rasi"` from the theme |
| gtk4 | the output **is** `~/.config/gtk-4.0/gtk.css` |

Apps without an include mechanism (mako, dunst) are not in the default manifest — their config is
written whole (by rice generate or `edit-config`), which folds the colors in. Templates for them
ship in `templates/` for manual use.

For the widget-shell wiring (eww `@import`, AGS `@use`, Quickshell `Colors.qml` singleton) see
[`components/widgets/template.md`](../components/widgets/template.md). For prompt wiring
(`STARSHIP_CONFIG`, `oh-my-posh init`, fish `conf.d/`) see
[`components/shell-prompt/template.md`](../components/shell-prompt/template.md). The four GTK
gotchas around `gtk-4.0/gtk.css` (symlink, `--libadwaita`, `GTK_THEME` env, `settings.ini` vs
gsettings) are in [`theming-architecture.md`](theming-architecture.md) → "GTK gotchas".

## Palette sources → `palette.conf`

- **Named / manual** — the rice skill writes `palette.conf` directly from
  [`palettes.md`](palettes.md) (or user hex).
- **Wallpaper-generated (matugen / wallust)** — use the generator to *produce* the palette; the
  engine renders everything else. See [`wallpaper.md`](wallpaper.md) → "Dynamic theming" for the
  matugen MD3 → contract map (`primary→accent`, `surface→bg`, …) and the wallust 16-color map.

The wallpaper path goes into `palette.conf` as `wallpaper=…`.

## State & reproducibility

`palette.conf` records the current `scheme`, `wallpaper`, and fonts — it *is* the rice state.
Saving a profile snapshots it; version-controlling `~/.config/hypr-rice/` (and the rendered app
configs) in git makes the whole rice reproducible. See the dotfiles skill.

## CLI

```
rice apply              # render all + reload
rice apply --no-reload  # render only
rice palette            # show current palette
rice templates          # show the manifest
rice wallpaper <img>    # set wallpaper -> regenerate palette -> re-render -> reload
rice random [dir]       # pick a random wallpaper and re-theme
rice wallpapers [scheme]# list the curated catalog
rice get-wallpaper …    # download + optionally apply a curated wallpaper
rice accents <scheme>   # list curated accent variants for a scheme
rice accent <name|hex>  # swap accent (--pin to keep across re-themes)
```

Because `rice` is self-contained, it can be bound to a key, run on wallpaper change, or invoked by
a systemd unit — the desktop re-themes without Claude in the loop. The cycler patterns (systemd
user timer, Hyprland `exec-once` loop) are in [`wallpaper.md`](wallpaper.md) → "Cycling".

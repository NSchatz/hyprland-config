# Hyprland Desktop Theming

The model: **one normalized palette → render it into every app's config → reload each app.** This
is exactly how `matugen` and `wallust` work, and it generalizes to named schemes and manual hex.
Get the palette once, then every surface stays in sync.

## The palette contract

All templates (see `templates.md`) consume this normalized set. Whatever the source (named,
generated, manual), resolve it to these before rendering:

| Key                         | Meaning                                             |
|-----------------------------|-----------------------------------------------------|
| `bg`                        | Primary background                                  |
| `fg`                        | Primary foreground / text                           |
| `surface`                   | Slightly lighter panel/background                   |
| `muted`                     | Dimmed text / inactive                              |
| `accent`                    | Primary accent (active border, highlights)          |
| `accent2`                   | Secondary accent                                    |
| `red green yellow blue magenta cyan` | Semantic/terminal hues                      |
| `color0`..`color15`         | Base16 terminal palette (0 bg/black … 15 bright white) |
| `cursor`                    | Terminal cursor color                               |

Store hex as `RRGGBB` (no `#`) internally and add `#`/`rgba()` per app as needed. Keep a single
generated `colors.conf`/`colors.css` etc. so re-theming = regenerate + reload.

## Palette sources

### Named schemes (`palettes.md`)

Ship a small catalog: Catppuccin (Mocha/Latte), Gruvbox, Nord, Tokyo Night, Rosé Pine. Each maps
directly to the contract. Apply the same palette to every surface for a coherent look.

### Wallpaper-generated

- **matugen** (Material You / Material Design 3). Config `~/.config/matugen/config.toml`. Define
  per-app `[templates.<name>]` tables with `input_path`/`output_path` (+ optional `post_hook`,
  `index`); templates reference `{{colors.primary.default.hex}}`, `{{colors.surface.default.hex}}`,
  etc. (mode-aware `.dark.hex`/`.light.hex`; formats `.hex`/`.hex_stripped`/`.rgb`/`.rgba`; filters
  like `| lighten: 10.0`). Run `matugen image /path/to/wall.png` (`-m dark|light`, `-t scheme-tonal-spot`
  — also `scheme-expressive`/`scheme-vibrant`/`scheme-content`/`scheme-neutral`/etc.). A
  `[config.wallpaper] set = true; command = "swww img {{ image }}"` block lets one invocation set the
  wallpaper **and** regenerate every template. Map Material roles → contract: `primary→accent`,
  `secondary→accent2`, `surface→bg`, `on_surface→fg`.
- **wallust** ("better pywal"). Config `~/.config/wallust/wallust.toml`. `[templates]` entries with
  `template`/`target` (and `pywal = true` to opt into pywal `{color1}` single-brace syntax; the
  default engine is Jinja2-subset `{{color1}}`/`{{background}}`/`{{cursor}}` with filters like
  `{{ color2 | lighten(0.3) }}`). Tunables: `backend` (`Resized`/`FastResize` fast, `Kmeans`/`Full`
  accurate), `palette` (`dark16`/`harddark`/…), `color_space`, `check_contrast`. Outputs a 16-color
  scheme → maps straight onto `color0..15`/`bg`/`fg`. Run `wallust run /path/to/wall.png`. (Note:
  the old `new_engine` key is gone — it's the default now; use `pywal = true` for pywal syntax.)
- **pywal / pywal16** (`wal -i wall.png`) — older; same idea, writes `~/.cache/wal/` (`colors.json`,
  `sequences`). `wal -R` restores the last scheme; re-sourcing `~/.cache/wal/sequences` at shell start
  re-themes open terminals. Largely superseded by wallust (Rust, faster, contrast-checked).

**Running on wallpaper change.** The hook is: generate the palette, (set the wallpaper), reload apps.
matugen's `post_hook` per template (or pywal's `-o script`, or wallust's `target` write) is where the
reloads live; or batch them: `matugen image "$W"` (or `wallust run "$W"` / `wal -i "$W"`) → `hyprctl reload`
→ `makoctl reload || swaync-client -rs` → `pkill -SIGUSR2 waybar`. matugen writes a `colors.conf`
Hyprland `source`s and a `colors.css` waybar `@import`s — the same wiring this plugin's engine uses.

If the chosen generator isn't installed, fall back to a named scheme or manual hex and tell the
user the package to install (`matugen`, `wallust`). Detection: `detect-theme-tools.sh`.

### Manual

User provides at least `bg`, `fg`, `accent`; derive the rest sensibly (or ask for the full 16).

## Per-surface application

### Hyprland (compositor)

Write a `~/.config/hypr/colors.conf` of variables and `source` it from `hyprland.conf`, then use
the vars in `looknfeel.conf`:

```ini
# colors.conf
$accent = rgb({{accent}})
$bg     = rgb({{bg}})
# looknfeel.conf
col.active_border = $accent
```

Apply: `hyprctl reload` (use the plugin's `verify-config.sh` to confirm it parses).

### hyprlock

Edit `~/.config/hypr/hyprlock.conf` colors (`outer_color`, `inner_color`, `font_color`,
`check_color`, `fail_color`). Applied at next lock — no reload command needed.

### Waybar (style)

Waybar styling is CSS at `~/.config/waybar/style.css`. Generate a `~/.config/waybar/colors.css`
of `@define-color` entries and `@import` it. Reload: `killall -SIGUSR2 waybar`.

### Notifications

- **mako**: `~/.config/mako/config` (`background-color`, `text-color`, `border-color`). Reload:
  `makoctl reload`.
- **dunst**: `~/.config/dunst/dunstrc` (`[urgency_*]` `background`/`foreground`/`frame_color`).
  Reload: `dunstctl reload` (falls back to restart `killall dunst; dunst &`).

### Launchers

- **wofi**: `~/.config/wofi/style.css` (GTK CSS). Read at launch — no reload needed.
- **rofi**: `~/.config/rofi/colors.rasi` `@import`ed from the theme; read at launch.

### Terminal

- **kitty**: write `~/.config/kitty/colors.conf` (`background`, `foreground`, `color0`..`color15`,
  `cursor`) and `include colors.conf` from `kitty.conf`. Live-reload running kitties:
  `kill -SIGUSR1 $(pidof kitty)` (or `kitty @ set-colors -a -c colors.conf` with remote control).
- **alacritty**: `~/.config/alacritty/colors.toml` imported from `alacritty.toml`; live-reloads.
- **foot**: `~/.config/foot/foot.ini` `[colors]`; foot reloads on SIGUSR1.

### GTK (3 + 4 / libadwaita)

- **GTK3**: `~/.config/gtk-3.0/settings.ini` + gsettings. Set theme/icons/cursor/font via
  gsettings (applies live to running GTK apps):
  ```bash
  gsettings set org.gnome.desktop.interface gtk-theme '<Theme>'
  gsettings set org.gnome.desktop.interface icon-theme '<Icons>'
  gsettings set org.gnome.desktop.interface cursor-theme '<Cursor>'
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface font-name '<Font> <Size>'   # e.g. 'Inter 11'
  ```
- **GTK4 / libadwaita**: many apps ignore full GTK themes. Lever = color overrides in
  `~/.config/gtk-4.0/gtk.css` with `@define-color` (e.g. `@define-color accent_color #...;`,
  `window_bg_color`, `view_bg_color`). libadwaita honors `color-scheme` (dark/light) and accent.
  Some users symlink a theme's `gtk-4.0` assets into `~/.config/gtk-4.0/`.
- **Caveat (Hyprland):** GTK4 theming can be flaky; cursor changes via gsettings sometimes don't
  apply on Hyprland — also set the cursor live with `hyprctl setcursor <Theme> <size>` and the
  `HYPRCURSOR_THEME`/`XCURSOR_THEME` env. `nwg-look` is a GUI that writes the GTK3 settings +
  gsettings for you.

### Qt

- `qt6ct` (+`qt5ct`): set the color scheme/style in their config; require
  `env = QT_QPA_PLATFORMTHEME,qt6ct` in the Hyprland env (the generate-config skill can add this).
- `kvantum`: SVG theme engine; `kvantummanager` to pick, `env = QT_STYLE_OVERRIDE,kvantum`.
- First-party `hyprland-qt-support`/`hyprqt6engine` theme the hypr tools' Qt dialogs.

### Cursor & icons & fonts

- **Cursor**: gsettings `cursor-theme`/`cursor-size`, env `XCURSOR_THEME`/`XCURSOR_SIZE` +
  `HYPRCURSOR_THEME`/`HYPRCURSOR_SIZE`, and live `hyprctl setcursor <Theme> <size>`.
- **Icons**: gsettings `icon-theme` (e.g. Papirus). Applies live to GTK apps.
- **Fonts**: gsettings `font-name`; per-app font settings (kitty `font_family`, waybar CSS).

## Apply + reload

After writing the theme files, reload each affected, running app so changes show without logout.
The `apply-theme.sh` script does this, guarded by what's installed/running:

| App        | Reload command                                  |
|------------|-------------------------------------------------|
| Hyprland   | `hyprctl reload`                                |
| waybar     | `killall -SIGUSR2 waybar`                       |
| mako       | `makoctl reload`                                |
| dunst      | `dunstctl reload`                               |
| kitty      | `kill -SIGUSR1 $(pidof kitty)`                  |
| GTK/icons/cursor/font | `gsettings set …` (applies live)     |
| cursor (HL)| `hyprctl setcursor <Theme> <size>`              |

Then run the plugin's `verify-config.sh` to confirm the Hyprland color file still parses
(`VERIFY=ok`). Back up every file first with `scripts/backup-path.sh`.

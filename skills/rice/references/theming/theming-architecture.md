# Theming Architecture

The cross-surface theming model: **one normalized palette → render it into every app's config →
reload each app.** This is exactly how `matugen` and `wallust` work, and it generalizes to named
schemes and manual hex. Get the palette once, then every surface stays in sync.

This file holds the per-surface mechanics, GTK/Qt/cursor gotchas, and dark/light handling — the
parts that aren't engine-internal. Engine internals (manifest format, render flow, CLI) are in
[`engine.md`](engine.md).

## The palette contract (overview)

Every template consumes a normalized palette. Whatever the source (named, generated, manual),
resolve to the keys before rendering. The canonical schema (every key, every metadata field, sizing
rules, render flow) is in [`_shared/palette-schema.md`](../_shared/palette-schema.md); the per-app
exported variable names are in [`_shared/colors-contract.md`](../_shared/colors-contract.md).

Wrap formats per app (also in the colors contract):

- **Hyprland** (`hyprland.conf`, `looknfeel.conf`): `rgb({{accent}})` — no `#`, parens around hex.
- **CSS** (`@define-color`, `*` rasi blocks): `#{{accent}}` — leading `#`, semicolon-terminated.
- **kitty / btop**: `#{{accent}}` — leading `#`, space-separated.
- **fuzzel** `[colors]`: `{{accent}}ff` — bare hex with two-digit alpha suffix, no `#`.
- **fish**: bare hex `{{accent}}` on `set -g fish_color_*` lines.

Hyprlock can't read Hyprland `$vars`, and fuzzel `[colors]` is merge-time not include — both fill
literal hex from `palette.conf` at generate-time (the only two exceptions to the "components
`@import`/`include` their colors file" rule).

## Per-surface application

### Hyprland (compositor)

Engine writes `~/.config/hypr/colors.conf` of `$var = rgb(hex)` lines; `hyprland.conf` `source =`s
it; `looknfeel.conf` references `$accent`/`$bg`/… (see
[`components/look-feel/template.md`](../components/look-feel/template.md)). Reload: `hyprctl
reload`. Use `scripts/verify-config.sh` to confirm the colors file still parses.

### hyprlock

Edit `~/.config/hypr/hyprlock.conf` colors (`outer_color`, `inner_color`, `font_color`,
`check_color`, `fail_color`). Applied at next lock — no reload command needed. Hyprlock fills
literal hex at generate-time (it doesn't `source` Hyprland vars).

### Waybar

CSS at `~/.config/waybar/style.css`. The engine writes `~/.config/waybar/colors.css` of
`@define-color` entries and `@import`s it. Reload: `killall -SIGUSR2 waybar`. See
[`components/waybar/template.md`](../components/waybar/template.md).

### Notifications (mako / dunst / swaync)

- **mako**: `~/.config/mako/config` — `background-color`, `text-color`, `border-color`. Reload:
  `makoctl reload`.
- **dunst**: `~/.config/dunst/dunstrc` — `[urgency_*]` `background`/`foreground`/`frame_color`.
  Reload: `dunstctl reload` (falls back to `killall dunst; dunst &`).
- **swaync**: `~/.config/swaync/colors.css` (`@import` from `style.css`). Reload: `swaync-client -rs`.

See [`components/notifications/template.md`](../components/notifications/template.md).

### Launchers (wofi / rofi / fuzzel)

- **wofi**: `~/.config/wofi/style.css` (GTK CSS). Read at launch — no reload needed.
- **rofi**: `~/.config/rofi/colors.rasi` `@import`ed from the theme; read at launch.
- **fuzzel**: `[colors]` merged into `~/.config/fuzzel/fuzzel.ini` at generate-time (no include
  mechanism). Read at launch.

See [`components/launcher/template.md`](../components/launcher/template.md).

### Terminal

- **kitty**: write `~/.config/kitty/colors.conf` (`background`, `foreground`, `color0..color15`,
  `cursor`) and `include colors.conf` from `kitty.conf`. Live-reload running kitties:
  `kill -SIGUSR1 $(pidof kitty)` (or `kitty @ set-colors -a -c colors.conf` with remote control).
- **alacritty**: `~/.config/alacritty/colors.toml` imported from `alacritty.toml`; live-reloads.
- **foot**: `~/.config/foot/foot.ini` `[colors]`; foot reloads on `SIGUSR1`.

See [`components/terminal/template.md`](../components/terminal/template.md).

### GTK (3 + 4 / libadwaita)

**Live apply** with gsettings:

```bash
gsettings set org.gnome.desktop.interface gtk-theme '<Theme>'
gsettings set org.gnome.desktop.interface icon-theme '<Icons>'
gsettings set org.gnome.desktop.interface cursor-theme '<Cursor>'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface font-name '<Font> <Size>'   # e.g. 'Inter 11'
```

**libadwaita** (GTK4) leverages color overrides in `~/.config/gtk-4.0/gtk.css` with
`@define-color` (`accent_color`, `window_bg_color`, `view_bg_color`, the full libadwaita set —
contract in [`_shared/colors-contract.md`](../_shared/colors-contract.md) → `gtk4` row). It honors
`color-scheme=prefer-dark` via the xdg-desktop-portal.

For a *full* GTK4 theme (e.g. an installed Everforest/Catppuccin GTK theme), symlink its
`gtk-4.0/` into `~/.config/gtk-4.0/` (`--libadwaita` installers do this) — but then the rice
engine's `gtk4` render owns the same `gtk.css`, so **disable that manifest line** or it fights the
symlink.

## GTK gotchas (the four that matter)

These are the four GTK theming failure modes that don't show up in casual reading and reliably bite
the rice engine:

### 1. `gtk-4.0/gtk.css` may already be a root-owned symlink

If a system GTK theme (e.g. Catppuccin-GTK) has been installed via `--libadwaita`, the installer
symlinks the **whole `gtk-4.0/`** directory under `~/.config/`. Writing through the symlink fails
with **"Permission denied"** (root-owned target).

Fix: `render-templates.sh` `rm`s a symlinked output before writing, so the render replaces it with
a rice-owned file. If doing it by hand, `rm ~/.config/gtk-4.0/gtk.css` first.

If the user *wants* the full GTK theme to own the file (re-installs via `--libadwaita` after the
rice scaffold), **comment out the `gtk4` manifest line** so the theme owns that file. GTK colors
are then the theme's, not engine-driven; re-enable the line to go back to palette overrides.

### 2. Folder color = icon theme, not GTK theme

Blue folders after a re-theme means the **icon theme** didn't change. The GTK theme controls
window chrome; the icon theme controls folder colors. Use a scheme-matched icon set (Papirus +
`papirus-folders -C <accent>`, or a theme that ships its own icons like the Everforest GTK repo's
`Everforest-Dark`). Rebuild the icon cache afterwards: `gtk-update-icon-cache`.

### 3. `GTK_THEME` env var (uwsm) overrides everything

A session env var `GTK_THEME=<name>` — common with **uwsm** in `~/.config/uwsm/env` — makes GTK
apps use *that* theme regardless of gsettings / `settings.ini` / `gtk.css`. The rendered `gtk.css`
silently has no effect.

Fix: edit `~/.config/uwsm/env` (see `components/env/template.md` and `detect-version.sh` for the
`UWSM_*` lines), then live-propagate:

```bash
hyprctl setenv GTK_THEME <name>
dbus-update-activation-environment --systemd GTK_THEME=<name>
```

nautilus and other GTK apps re-read it on next launch.

### 4. gsettings alone does NOT theme GTK3 apps on Wayland

On a Wayland/Hyprland session, gsettings alone (`gtk-theme` / `color-scheme` / `icon-theme`) does
**not** reliably theme GTK3 apps (e.g. **nm-connection-editor**) — they fall back to the default
**light** theme. Also write the per-version `settings.ini`:

```ini
# ~/.config/gtk-3.0/settings.ini  AND  ~/.config/gtk-4.0/settings.ini
[Settings]
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Inter 11
gtk-cursor-theme-name=<Cursor>
gtk-cursor-theme-size=24
```

And `~/.gtkrc-2.0` for GTK2 apps:

```ini
gtk-theme-name="Adwaita-dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Inter 11"
gtk-cursor-theme-name="<Cursor>"
```

`settings.ini` changes apply **only to newly-launched apps** — already-open apps must be relaunched
to pick them up. libadwaita apps follow `color-scheme=prefer-dark` via the xdg-desktop-portal but
still want the `settings.ini`.

### murrine note (GTK2-only dependency trap)

Several full GTK themes (`everforest-gtk-theme-git`, other Fausto-Korpsvart family themes)
`depends=gtk-engine-murrine`, which on current Arch pulls in the AUR `gtk2` (dropped from the
repos). That builds GTK2 from a giant source clone that often fails on HTTP/2, so `yay` rolls the
whole thing back. **murrine is GTK2-only** — skip the package and build the theme from SCSS with
`sassc`:

```bash
# in the theme repo
themes/build.sh
themes/install.sh -d ~/.local/share/themes -c dark -t <accent> --libadwaita
```

Copy the repo's `icons/` for matching folder colors.

## Qt

- `qt6ct` (+ `qt5ct`): pick the color scheme/style in their config; require
  `env = QT_QPA_PLATFORMTHEME,qt6ct` in `~/.config/hypr/env.conf` (the rice skill can add this).
- `kvantum`: SVG theme engine; `kvantummanager` to pick, `env = QT_STYLE_OVERRIDE,kvantum`.
- First-party `hyprland-qt-support` / `hyprqt6engine` theme the hypr tools' Qt dialogs.

## Cursor

Live cursor switch on Hyprland (gsettings sometimes doesn't apply):

```bash
hyprctl setcursor <Theme> <size>
```

Cursor *theme* is recorded in many places — keep them all in sync or relogins surface the wrong
theme:

| Location | Field |
|---|---|
| gsettings | `cursor-theme`, `cursor-size` |
| `~/.config/hypr/env.conf` | `env = XCURSOR_THEME,<name>` + `XCURSOR_SIZE,<n>` + `HYPRCURSOR_THEME,<name>` + `HYPRCURSOR_SIZE,<n>` |
| `~/.gtkrc-2.0` | `gtk-cursor-theme-name`, `gtk-cursor-theme-size` |
| `~/.config/gtk-{3,4}.0/settings.ini` | `gtk-cursor-theme-name`, `gtk-cursor-theme-size` |
| `~/.config/xsettingsd/xsettingsd.conf` | `Gtk/CursorThemeName`, `Gtk/CursorThemeSize` |
| `~/.icons/default/index.theme` | `Inherits=<theme>` (what nwg-look writes; fastfetch reads it) |
| `~/.config/uwsm/env` if present | `XCURSOR_THEME=…` / `HYPRCURSOR_THEME=…` |

Notes:

- **Bibata is xcursor-only** — leave `HYPRCURSOR_THEME` unset to fall back, or set it to Bibata
  too and Hyprland falls through to xcursor.
- **Disappearing-when-idle cursor on nouveau/NVIDIA** → not a theme issue; set
  `cursor:no_hardware_cursors = true` in `~/.config/hypr/look-feel.conf`.

## Per-surface dark/light handling

For light schemes (catppuccin-latte, solarized-light):

- gsettings: `color-scheme prefer-light`.
- `settings.ini`: `gtk-application-prefer-dark-theme=0`.
- Use the light-variant icon theme (Papirus, not Papirus-Dark).
- Hyprland looks identical (no dark-mode toggle in the compositor) — the difference lives in the
  rendered `colors.conf`.
- waybar/launcher/notifications: `colors.css` re-rendered from the palette covers it.
- kitty/foot/alacritty: same — `colors.conf` re-render.
- libadwaita: honors `color-scheme=prefer-light` via the portal automatically.

The interview asks the palette pick (component 12) before fonts/wallpaper, so the light/dark
decision propagates downstream consistently.

## Apply + reload (full catalog)

After writing the theme files, reload each affected running app so changes show without logout.
`apply-theme.sh` does this guarded by `pidof`/`pgrep`:

| App | Reload command |
|---|---|
| Hyprland | `hyprctl reload` |
| waybar | `killall -SIGUSR2 waybar` |
| mako | `makoctl reload` |
| dunst | `dunstctl reload` |
| swaync | `swaync-client -rs` |
| kitty | `kill -SIGUSR1 $(pidof kitty)` |
| foot | `kill -SIGUSR1 $(pidof foot)` |
| alacritty | live (file watch) |
| btop | restart (`pkill -USR2 btop` for matugen-managed; restart otherwise) |
| cava | restart |
| eww | `eww reload` |
| ags / astal | live (file monitor) |
| quickshell | live (file watch) |
| GTK / icons / cursor / font | `gsettings set …` (applies live) |
| GTK env (`GTK_THEME`) | `hyprctl setenv GTK_THEME …` + `dbus-update-activation-environment --systemd GTK_THEME=…` |
| cursor (Hyprland) | `hyprctl setcursor <Theme> <size>` |

Then `scripts/verify-config.sh` confirms the Hyprland color file still parses (`VERIFY=ok`). Back
up every file first with `scripts/backup-path.sh`.

## Cross-references

- Engine architecture (manifest, render flow, CLI) → [`engine.md`](engine.md).
- Palette schema (the canonical key list) → [`_shared/palette-schema.md`](../_shared/palette-schema.md).
- Per-app exported variable names → [`_shared/colors-contract.md`](../_shared/colors-contract.md).
- Named scheme hex catalog → [`palettes.md`](palettes.md).
- Fonts → [`fonts.md`](fonts.md).
- Wallpaper + dynamic theming → [`wallpaper.md`](wallpaper.md).
- Long-tail apps via matugen → [`apps.md`](apps.md).
- Widget-shell theming → [`components/widgets/template.md`](../components/widgets/template.md).
- Shell & prompt theming → [`components/shell-prompt/template.md`](../components/shell-prompt/template.md).

# App Coverage (long-tail theming via matugen)

The rice engine ships templates for the **core themed surfaces** (Hyprland, kitty, waybar, wofi,
rofi, gtk4, mako/dunst, swaync, wlogout, btop, cava, fuzzel, starship, plus the widget shells and
fish/oh-my-posh prompts — all wired per [`_shared/colors-contract.md`](../_shared/colors-contract.md)
and the per-component `template.md` files).

For everything beyond the core set, use **matugen** as an additional renderer — it ships templates
for 50+ apps and reuses the same wallpaper, so the long tail stays in sync with the engine.

## Engine-shipped templates (recap)

The full list — what the engine renders, where the output goes, and the reload hook — lives in the
per-component `template.md` files. A short index:

| App | Component | Output (manifest line) | Reload |
|---|---|---|---|
| Hyprland | `components/look-feel/` | `~/.config/hypr/colors.conf` (`source =`) | `hyprctl reload` |
| kitty | `components/terminal/` | `~/.config/kitty/colors.conf` (`include`) | `kill -SIGUSR1 $(pidof kitty)` |
| waybar | `components/waybar/` | `~/.config/waybar/colors.css` (`@import`) | `killall -SIGUSR2 waybar` |
| wofi / rofi / fuzzel | `components/launcher/` | colors.css / colors.rasi / `[colors]` merge | (launch) |
| mako / dunst / swaync | `components/notifications/` | colors merge / `colors.css` | `makoctl/dunstctl/swaync-client -rs` |
| wlogout | `components/lock-screen/` | `~/.config/wlogout/colors.css` (`@import`) | (launch) |
| gtk4 | `components/look-feel/` | `~/.config/gtk-4.0/gtk.css` (the file itself) | live |
| btop / cava | `components/utilities/` | merged into app config | restart |
| starship / oh-my-posh / fish | `components/shell-prompt/` | rice-owned config; `STARSHIP_CONFIG`/init | live |
| eww / ags / quickshell | `components/widgets/` | colors.scss / Colors.qml | shell hot-reload |

To add an app to the engine, drop `<name>.tmpl` in `~/.config/hypr-rice/templates/` and add a
TAB-separated line to `templates.list` — see [`engine.md`](engine.md) → "Manifest format".

## Reaching the long tail via matugen

For apps without an engine template, drive **matugen** on the same wallpaper. matugen's official
templates repo ([InioX/matugen-themes](https://github.com/InioX/matugen-themes)) covers:

> btop, cava, starship, rofi, fuzzel, kitty / alacritty / wezterm / ghostty, GTK3/4, Qt/Kvantum,
> neovim, helix, zed, **spicetify (Spotify)**, **Midnight Discord**, **firefox (pywalfox)**, steam,
> obs, telegram, yazi, zathura, tmux, zellij, quickshell, niri, …

This is the same set of templates the bigger rices (HyDE, ml4w, end-4) draw from.

## Setup

1. Get the templates:
   ```bash
   git clone https://github.com/InioX/matugen-themes ~/.config/matugen
   # (or copy just the ones you want into ~/.config/matugen/templates/)
   ```
2. Register them in `~/.config/matugen/config.toml`:
   ```toml
   [config]
   # required header — matugen 4.x rejects bare [templates.*] without it

   [templates.btop]
   input_path  = '~/.config/matugen/templates/btop.theme'
   output_path = '~/.config/btop/themes/matugen.theme'
   post_hook   = 'pkill -USR2 btop || true'

   [templates.spicetify]
   input_path  = '~/.config/matugen/templates/spicetify.ini'
   output_path = '~/.config/spicetify/Themes/matugen/color.ini'
   post_hook   = 'spicetify apply || true'
   ```
3. Run on a wallpaper:
   ```bash
   matugen image ~/Pictures/wall.png
   ```
   matugen renders all registered templates and runs the hooks.

For the matugen 4.x quirks (`[config]` header required, `--prefer image` for headless multi-source)
see [`wallpaper.md`](wallpaper.md) → "matugen 4.x configuration".

## Mapping rule: same wallpaper, one palette source

Keep **one palette source per run**. When using wallpaper-generated colors:

- **The rice engine owns the core surfaces** (Hyprland, kitty, waybar, launcher, notifications,
  GTK, the shell prompt, the widget shell) — its templates render from `palette.conf`.
- **matugen owns the long tail** (spicetify, discord, firefox via pywalfox, helix, zed, tmux,
  yazi, zathura, telegram, …) — its templates render from the **same wallpaper** so both stay
  consistent.

Drive both off the same image:

```bash
rice wallpaper "$wp"          # engine: palette-from-wallpaper -> render -> reload
matugen --prefer image image "$wp"   # long tail: render + hooks
```

For **named or manual** palettes, prefer the engine and skip matugen — matugen is wallpaper-driven
(it pulls Material You roles from an image), so a named scheme has no input image to give it.

## HyprPanel and other Material-You-native shells

HyprPanel, end-4, and caelestia own their colors via a **GUI / `.json` theme import** (HyprPanel) or
read a matugen `colors.json` directly. Don't fight them with a rice template — drive them with
matugen on the same wallpaper, mapping `primary→accent`, `surface→bg`, …, so the shell themes from
the wallpaper while the engine owns the core surfaces. This is the "widget-shell" case covered in
[`components/widgets/template.md`](../components/widgets/template.md) → "HyprPanel and other
Material-You-native shells".

# App Coverage (breadth)

Templates the engine can render beyond the core set, plus how to reach the long tail via matugen.
Add an app to the engine by dropping `<name>.tmpl` in `~/.config/hypr-rice/templates/` and a
TAB-separated line in `templates.list`; then `rice apply`.

## Shipped templates

| App | Template | Output / how to wire | Reload |
|-----|----------|----------------------|--------|
| Hyprland | `hyprland.tmpl` | `~/.config/hypr/colors.conf` — `source=` it | `hyprctl reload` |
| kitty | `kitty.tmpl` | `~/.config/kitty/colors.conf` — `include` it | `kill -SIGUSR1 $(pidof kitty)` |
| waybar | `waybar.tmpl` | `~/.config/waybar/colors.css` — `@import` | `killall -SIGUSR2 waybar` |
| wofi | `wofi.tmpl` | `~/.config/wofi/colors.css` — `@import` | (launch) |
| rofi | `rofi.tmpl` | `~/.config/rofi/colors.rasi` — `@import` | (launch) |
| GTK4 | `gtk4.tmpl` | `~/.config/gtk-4.0/gtk.css` (the file itself) | live |
| mako | `mako.tmpl` | colors for `~/.config/mako/config` (merge) | `makoctl reload` |
| dunst | `dunst.tmpl` | colors for `~/.config/dunst/dunstrc` (merge) | `dunstctl reload` |
| btop | `btop.tmpl` | `~/.config/btop/themes/rice.theme` + set `color_theme="rice"` | restart |
| swaync | `swaync.tmpl` | `~/.config/swaync/colors.css` — `@import` from `style.css` | `swaync-client -rs` |
| wlogout | `wlogout.tmpl` | `~/.config/wlogout/colors.css` — `@import` | (launch) |
| starship | `starship.tmpl` | merge `[palettes.rice]` into `~/.config/starship.toml`; set `palette="rice"` | live |
| fuzzel | `fuzzel.tmpl` | merge `[colors]` into `~/.config/fuzzel/fuzzel.ini` (RRGGBBAA, no `#`) | (launch) |
| cava | `cava.tmpl` | merge `[color]` into `~/.config/cava/config` | restart |

"merge" templates aren't included via a colors file (the app has no include directive) — the rice
generate / edit-config flow folds them into the app's config. The `@import`/`include`/`source`
ones go straight in the manifest. To enable an `@import` app in the engine, add its line to
`templates.list`, e.g.:

```
swaync	~/.config/hypr-rice/templates/swaync.tmpl	~/.config/swaync/colors.css	swaync-client -rs
btop	~/.config/hypr-rice/templates/btop.tmpl	~/.config/btop/themes/rice.theme	
```

(Use a real TAB between fields.)

## The long tail via matugen (40+ apps)

For apps we don't template, drive **matugen**, which ships templates for btop, cava, starship,
rofi, fuzzel, kitty/alacritty/wezterm/ghostty, GTK3/4, Qt/Kvantum, neovim, helix, zed,
**spicetify (Spotify)**, **Midnight Discord**, **firefox (pywalfox)**, steam, obs, telegram,
yazi, zathura, tmux, zellij, quickshell, and more ([matugen-themes](https://github.com/InioX/matugen-themes)).

Setup:
1. Get the templates: `git clone https://github.com/InioX/matugen-themes ~/.config/matugen` (or
   copy the ones you want into `~/.config/matugen/templates/`).
2. Register them in `~/.config/matugen/config.toml`:
   ```toml
   [templates.btop]
   input_path  = '~/.config/matugen/templates/btop.theme'
   output_path = '~/.config/btop/themes/matugen.theme'
   post_hook   = 'pkill -USR2 btop || true'

   [templates.spicetify]
   input_path  = '~/.config/matugen/templates/spicetify.ini'
   output_path = '~/.config/spicetify/Themes/matugen/color.ini'
   post_hook   = 'spicetify apply || true'
   ```
3. Run on a wallpaper: `matugen image ~/Pictures/wall.png` (matugen renders all registered
   templates + runs the hooks).

Keep **one palette source per run**: when using wallpaper-generated colors, let matugen own the
long tail and our engine own the core (so both derive from the same image). For named/manual
palettes, prefer our engine (matugen is wallpaper-driven).

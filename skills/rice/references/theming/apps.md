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

| App | Component | Output (manifest line) | Palette keys exported | Reload |
|---|---|---|---|---|
| Hyprland | `components/look-feel/` | `~/.config/hypr/colors.conf` (`source =`) | `$accent $accent2 $bg $fg $surface $muted` | `hyprctl reload` |
| kitty | `components/terminal/` | `~/.config/kitty/colors.conf` (`include`) | `background foreground cursor cursor_text_color selection_{background,foreground} url_color`, tab-bar (`active_tab_{fg,bg} inactive_tab_{fg,bg} tab_bar_background`), borders (`{active,inactive,bell}_border_color`), ANSI 16 (`color0..color15`) | `kill -SIGUSR1 $(pidof kitty)` |
| waybar | `components/waybar/` | `~/.config/waybar/colors.css` (`@import`) | 12 `@define-color` names per `_shared/colors-contract.md` | `killall -SIGUSR2 waybar` |
| wofi | `components/launcher/` | `~/.config/wofi/colors.css` (`@import`) | `@bg @fg @surface @accent` | (launch) |
| rofi | `components/launcher/` | `~/.config/rofi/colors.rasi` (`@import`) | `bg bg-alt fg muted accent accent2 red green` | (launch) |
| fuzzel | `components/launcher/` | `~/.config/fuzzel/fuzzel.ini` `[colors]` (inline merge) | `background text match selection selection-text selection-match border` (7 keys; fuzzel.ini(5) supports 11 — see flag below) | (launch) |
| mako | `components/notifications/` | `~/.config/mako/config` colors block | `background-color text-color border-color progress-color`, urgency `border-color` overrides | `makoctl reload` |
| dunst | `components/notifications/` | `~/.config/dunst/dunstrc` urgency colors | `background foreground frame_color` per urgency | `killall -USR1 dunst` (or `dunstctl reload`) |
| swaync | `components/notifications/` | `~/.config/swaync/colors.css` (`@import`) | `@bg @fg @surface @muted @accent @accent2 @red` | `swaync-client -rs` |
| wlogout | `components/utilities/` | `~/.config/wlogout/colors.css` (`@import`) | `@bg @fg @accent @surface` | (launch) |
| gtk4 | `components/look-feel/` | `~/.config/gtk-4.0/gtk.css` (the file itself) | M3 `@define-color` palette per `gtk4.tmpl` | live |
| btop | `components/terminal/` | `~/.config/btop/themes/rice.theme` (set `color_theme = "rice"`) | `main_{bg,fg} title hi_fg selected_{bg,fg} inactive_fg graph_text meter_bg proc_misc`, box outlines, 9 gradient triples | restart |
| cava | `components/terminal/` | merged into `~/.config/cava/config` | gradient + foreground | restart |
| hyprlock | `components/lock-screen/` | `~/.config/hypr/hyprlock.conf` (single file; **literal hex** baked at generate-time) | `{{accent}} {{surface}} {{fg}} {{bg}} {{green}} {{red}}` substituted into the conf — hyprlock cannot read `$vars` from Hyprland's `colors.conf` | (launch) |
| hyprbars (plugin) | `components/plugins/` | `plugin { hyprbars { … } }` block in `~/.config/hypr/plugins.conf` | `{{surface}} {{fg}} {{muted}} {{red}} {{yellow}} {{font_ui_family}}` | `hyprctl reload` |
| hyprexpo / borders-plus-plus / hyprtrails (plugins) | `components/plugins/` | `plugin {}` blocks in `~/.config/hypr/plugins.conf` | `{{accent}} {{accent2}} {{bg}}` (hyprexpo); `{{accent}}` (borders-plus-plus, hyprtrails) | `hyprctl reload` |
| starship | `components/shell-prompt/` | `~/.config/hypr-rice/starship.toml` (`STARSHIP_CONFIG` exported in shell rc) | accent/fg/surface roles inlined in segment styles | live (next prompt) |
| oh-my-posh | `components/shell-prompt/` | `~/.config/hypr-rice/rice.omp.json` (`oh-my-posh init <shell> --config …`) | accent/fg/surface roles inlined in segment styles | live (next prompt) |
| fish colors | `components/shell-prompt/` | `~/.config/fish/conf.d/zz-hypr-rice-colors.fish` (auto-sourced) | `fish_color_*` keys | live |
| eww | `components/widgets/` | `~/.config/eww/colors.scss` (`@import "colors";`) | `$bg $fg $surface $muted $cursor $accent $accent2 $red $green $yellow $blue $magenta $cyan $color0..$color15` | `eww reload` |
| ags / astal | `components/widgets/` | `~/.config/ags/colors.scss` | same eww set plus semantic aliases (`$window-bg $on-window $card-bg $primary $secondary $radius $anim-duration`) and a `@define-color` block | shell file-monitor hot-reload |
| quickshell | `components/widgets/` | `~/.config/quickshell/<name>/Colors.qml` (`pragma Singleton`) | `bg fg surface muted cursor accent accent2 red green yellow blue magenta cyan`, `term0..term15` individually (NOT a `term[16]` array — sibling QML references `Colors.term3` directly), plus `fontUi fontMono radius animDuration` and M3 motion tokens (`standard standardAccel standardDecel emphasized emphasizedAccel emphasizedDecel`) | hot-reload on save |

To add an app to the engine, drop `<name>.tmpl` in `~/.config/hypr-rice/templates/` and add a
TAB-separated line to `templates.list` — see [`engine.md`](engine.md) → "Manifest format".

### Literal-hex-at-generate-time apps

Most templates produce an artifact that imports/sources a palette file the engine writes
separately, so a wallpaper cycle re-renders just the palette file and every app picks up
the new colors via its own reload hook. The exception is **hyprlock**: it is a separate
daemon and **cannot read Hyprland `$vars`** from `colors.conf`. The engine substitutes
`{{accent}} {{surface}} {{fg}} {{green}} {{red}} {{bg}}` from `palette.conf` directly into
the **single output file** `~/.config/hypr/hyprlock.conf` at generate-time — re-theming
hyprlock means re-rendering that whole conf, not just a colors file. See
[`components/lock-screen/template.md`](../components/lock-screen/template.md) →
"Colors are LITERAL hex".

### fuzzel — 7-of-11 supported keys (flag)

The current `fuzzel.tmpl` exports the 7 keys the engine actively uses
(`background text match selection selection-text selection-match border`). `fuzzel.ini(5)`
supports 11 in the `[colors]` section (the remaining four are `prompt`, `placeholder`,
`input` text, and `counter`). When the orchestrator approves widening the contract, expand
the template to cover all 11 so a fuzzel rebrand doesn't fall back to defaults on those
surfaces.

## default-apps ricochet — which component's `.tmpl` re-themes each pick

`components/default-apps/` is **structural**: it records the user's `browser` / `files`
choice and emits `$browser` / `$fileManager` `$var`s into `hyprland.conf`. It doesn't ship
its own `.tmpl`. But the picks **determine which other component's template re-themes the
default app**:

| `default_apps` pick | Re-themed by | Owned by | Output destination |
|---|---|---|---|
| `files = thunar` | GTK3 + GTK4 matugen output | `theming/gtk-qt.md`, engine `gtk4.tmpl` | `~/.config/gtk-3.0/gtk.css` + `~/.config/gtk-4.0/gtk.css` |
| `files = nautilus` | GTK4 matugen + gsettings `color-scheme` | `theming/gtk-qt.md`, engine | `~/.config/gtk-4.0/gtk.css` + `gsettings set org.gnome.desktop.interface color-scheme prefer-dark` |
| `files = nemo` / `pcmanfm` | GTK3 + GTK4 matugen output | `theming/gtk-qt.md`, engine | `~/.config/gtk-3.0/gtk.css` + `~/.config/gtk-4.0/gtk.css` |
| `files = dolphin` | Kvantum theme (`QT_STYLE_OVERRIDE=kvantum` + `kvantum.kvconfig`) | `theming/gtk-qt.md` | Kvantum dir |
| `files = yazi` | Out of scope for v0.13 (`yazi/theme.toml` not generated) | flag in interview | — |
| `browser = firefox` | userChrome / pywalfox add-on layer — **out of scope for v0.13** | (none) | chrome stays default |
| `browser = chromium` / `brave` / `zen-browser` | Same — chrome stays default unless a userChrome.css is generated separately | (none) | chrome stays default |

Source: [`components/default-apps/template.md`](../components/default-apps/template.md) →
"Theming linkage". The ricochet only fires through the **other** component's template — the
default-apps writer never writes a colors file itself.

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

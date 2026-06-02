# Theme Templates (per app)

Render these from the resolved palette (`theming.md` contract). `{{key}}` = the contract value as
bare `RRGGBB`. Write each to the path shown, back it up first (`scripts/backup-path.sh`), then
reload the app (`apply-theme.sh`). Keep colors in a **separate file per app** and `include`/
`@import`/`source` it, so re-theming only rewrites the colors file.

## Hyprland — `~/.config/hypr/colors.conf`

```ini
# Generated theme colors — sourced by hyprland.conf
$accent   = rgb({{accent}})
$accent2  = rgb({{accent2}})
$bg       = rgb({{bg}})
$fg       = rgb({{fg}})
$surface  = rgb({{surface}})
$muted    = rgb({{muted}})
```

Add `source = ~/.config/hypr/colors.conf` near the top of `hyprland.conf` (after env), then use the
vars in `looknfeel.conf`:

```ini
general {
    col.active_border = $accent $accent2 45deg
    col.inactive_border = $surface
}
```

## hyprlock — colors inside `~/.config/hypr/hyprlock.conf`

```ini
input-field {
    outer_color = rgb({{accent}})
    inner_color = rgb({{bg}})
    font_color  = rgb({{fg}})
    check_color = rgb({{green}})
    fail_color  = rgb({{red}})
}
```

## Waybar — `~/.config/waybar/colors.css`

```css
@define-color bg      #{{bg}};
@define-color fg      #{{fg}};
@define-color accent  #{{accent}};
@define-color surface #{{surface}};
@define-color muted   #{{muted}};
@define-color red     #{{red}};
@define-color green   #{{green}};
@define-color yellow  #{{yellow}};
```

Add `@import "colors.css";` at the top of `~/.config/waybar/style.css` and reference the names
(e.g. `background: @bg; color: @fg;`). Reload: `killall -SIGUSR2 waybar`.

## mako — `~/.config/mako/config`

```ini
background-color=#{{bg}}
text-color=#{{fg}}
border-color=#{{accent}}
[urgency=high]
border-color=#{{red}}
```

Reload: `makoctl reload`.

## dunst — colors in `~/.config/dunst/dunstrc`

```ini
[global]
    frame_color = "#{{accent}}"
[urgency_low]
    background = "#{{bg}}"
    foreground = "#{{muted}}"
[urgency_normal]
    background = "#{{bg}}"
    foreground = "#{{fg}}"
[urgency_critical]
    background = "#{{bg}}"
    foreground = "#{{fg}}"
    frame_color = "#{{red}}"
```

Reload: `dunstctl reload`.

## wofi — `~/.config/wofi/style.css`

```css
window { background-color: #{{bg}}; color: #{{fg}}; }
#input { background-color: #{{surface}}; color: #{{fg}}; border: 1px solid #{{accent}}; }
#entry:selected { background-color: #{{accent}}; color: #{{bg}}; }
```

Read at launch — no reload needed.

## rofi — `~/.config/rofi/colors.rasi`

```rasi
* {
    background:     #{{bg}}ff;
    foreground:     #{{fg}}ff;
    selected:       #{{accent}}ff;
    urgent:         #{{red}}ff;
}
```

`@import "~/.config/rofi/colors.rasi"` from the rofi theme. Read at launch.

## kitty — `~/.config/kitty/colors.conf`

```conf
background  #{{bg}}
foreground  #{{fg}}
cursor      #{{cursor}}
color0  #{{color0}}
color1  #{{color1}}
color2  #{{color2}}
color3  #{{color3}}
color4  #{{color4}}
color5  #{{color5}}
color6  #{{color6}}
color7  #{{color7}}
color8  #{{color8}}
color9  #{{color9}}
color10 #{{color10}}
color11 #{{color11}}
color12 #{{color12}}
color13 #{{color13}}
color14 #{{color14}}
color15 #{{color15}}
```

Add `include colors.conf` to `~/.config/kitty/kitty.conf`. Live-reload running terminals:
`kill -SIGUSR1 $(pidof kitty)`. If the chosen scheme doesn't specify `cursor` or every
`color0..15` (only Catppuccin Mocha has the full 16 in `palettes.md`), derive them: `cursor` →
`fg`, `color0` → `bg`, `color8` → `muted`, `color7`/`color15` → `fg`, and `color1..6`/`9..14` →
the named `red green yellow blue magenta cyan` hues.

## GTK4 / libadwaita — `~/.config/gtk-4.0/gtk.css`

```css
@define-color accent_color #{{accent}};
@define-color accent_bg_color #{{accent}};
@define-color window_bg_color #{{bg}};
@define-color window_fg_color #{{fg}};
@define-color view_bg_color #{{bg}};
@define-color view_fg_color #{{fg}};
@define-color headerbar_bg_color #{{surface}};
```

(Optionally mirror into `~/.config/gtk-3.0/gtk.css`.) Then set the live appearance via gsettings —
do NOT hand-edit dconf:

```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'   # or prefer-light
gsettings set org.gnome.desktop.interface gtk-theme   '<MatchingTheme>' # only if installed
gsettings set org.gnome.desktop.interface icon-theme  '<Icons>'
gsettings set org.gnome.desktop.interface cursor-theme '<Cursor>'
gsettings set org.gnome.desktop.interface cursor-size 24
gsettings set org.gnome.desktop.interface font-name '<Font> <Size>'   # e.g. 'Inter 11'
```

Also write GTK3 `~/.config/gtk-3.0/settings.ini`:

```ini
[Settings]
gtk-theme-name=<MatchingTheme>
gtk-icon-theme-name=<Icons>
gtk-cursor-theme-name=<Cursor>
gtk-application-prefer-dark-theme=1
```

## Qt — qt6ct / kvantum

- qt6ct: ensure `env = QT_QPA_PLATFORMTHEME,qt6ct` is in the Hyprland env (rice can add
  it). Set the color scheme in `~/.config/qt6ct/qt6ct.conf` (`color_scheme_path=`) or point it at a
  generated `~/.config/qt6ct/colors/<scheme>.conf`. Mirror for qt5ct.
- kvantum: pick a theme with `kvantummanager`; set `env = QT_STYLE_OVERRIDE,kvantum`.

## Cursor (Hyprland live apply)

After setting the gsettings cursor, also apply it to the running session:

```bash
hyprctl setcursor '<Cursor>' 24
```

and ensure the env is set (rice env.conf): `XCURSOR_THEME`, `XCURSOR_SIZE`,
`HYPRCURSOR_THEME`, `HYPRCURSOR_SIZE`.

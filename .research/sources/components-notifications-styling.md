# Sources - skills/rice/references/components/notifications/styling.md

Research provenance for `skills/rice/references/components/notifications/styling.md`.

Extracted from the load path: these citations are why the recommendations in that
file are what they are, and are read by a human reviewing them - never by an agent
authoring a config.

## Sources

- mako(5) man page — <https://man.archlinux.org/man/mako.5.en>
- mako example configuration (wiki) — <https://github.com/emersion/mako/wiki/Example-configuration>
- dunst default `dunstrc` — <https://github.com/dunst-project/dunst/blob/master/dunstrc>
- dunst(5) / project wiki — <https://github.com/dunst-project/dunst/wiki>
- SwayNotificationCenter README + `swaync-client` flags — <https://github.com/ErikReider/SwayNotificationCenter>
- swaync default `style.scss` (selectors) — <https://github.com/ErikReider/SwayNotificationCenter/blob/main/data/style/style.scss>
- swaync(1)/(5) man pages — <https://man.archlinux.org/man/swaync.1.en>, <https://man.archlinux.org/man/swaync.5.en>
- Catppuccin mako — <https://github.com/catppuccin/mako>
- Catppuccin dunst — <https://github.com/catppuccin/dunst>
- Catppuccin swaync — <https://github.com/catppuccin/swaync>
- Rosé Pine swaync — <https://github.com/rose-pine/swaync>
- HyDE / JaKooLit / ml4w dotfiles (notification configs) — <https://github.com/HyDE-Project/HyDE>, <https://github.com/JaKooLit/Hyprland-Dots>, <https://github.com/mylinuxforwork/dotfiles>

**Config corpus read for the techniques catalog:**
- mako: catppuccin/mako (`themes/catppuccin-mocha/*` per-accent overlays, `progress-color over`) — <https://github.com/catppuccin/mako>; omarchy theme `mako.ini` (DND mode + app-name mute + `outer-margin`) — e.g. <https://github.com/P0LoYT/omarchy-gruvbox-dark-soft>; dusklinux/dusky `.config/matugen/templates/mako.ini` (matugen mako template, OSD app-name section, click-action triad, `icon-border-radius`) — <https://github.com/dusklinux/dusky/blob/main/.config/matugen/templates/mako.ini>; emersion/mako `doc/mako.5.scd` (verified `outer-margin` and `margin` coexist; verified urgency criteria values are low/normal/critical) — <https://github.com/emersion/mako/blob/master/doc/mako.5.scd>.
- dunst: upstream sample `dunstrc` (canonical keys, critical pattern) — <https://github.com/dunst-project/dunst/blob/master/dunstrc>; dunst-project/dunst `src/settings_data.h` (verified `highlight` is a real key) — <https://github.com/dunst-project/dunst/blob/master/src/settings_data.h>; prasanthrangan/hyprdots `Configs/.config/dunst/dunstrc` (rounded translucent card, `icon_corner_radius`, inverted critical, `notification_limit`, `gap_size`) — <https://github.com/prasanthrangan/hyprdots/blob/main/Configs/.config/dunst/dunstrc>; catppuccin/dunst `themes/mocha.conf` (`highlight = "#…"` for progress fill) — <https://github.com/catppuccin/dunst>; linuxmobile/hyprland-dots (Sakura) `.config/dunst/dunstrc` (rose-pine + frame-coloured separator, `frame_color = "#f5c2e7"`) — <https://github.com/linuxmobile/hyprland-dots/blob/Sakura/.config/dunst/dunstrc>; drewgrif/dotfiles `dunstrc` (`icon_path` chain, `corner_radius 15`).
- swaync: ErikReider/SwayNotificationCenter `data/style/style.scss` + `pre-gtk4-variables.scss` + `data/style/widgets/*.scss` + `src/config.json.in` (canonical selectors, `--cc-bg` vars, widget stack) — <https://github.com/ErikReider/SwayNotificationCenter>; catppuccin/swaync `src/_theme.scss` (palette-var swap, `inset` hairlines, `scale trough progress`); HyDE-Project/HyDE `Configs/.config/swaync/config.json` (functional widget stack); xZepyx/hyprzepyx swaync `style.css` + `config.json` (semantic `@color` tokens, pill toggles); mylinuxforwork/dotfiles `dotfiles/.config/swaync/{config.json,themes/glass/{control_center,notifications}.css}` (buttons-grid with `update-command`, scoped `.widget-volume trough highlight`, full `.floating-notifications.background ...` selector chain) — <https://github.com/mylinuxforwork/dotfiles/tree/main/dotfiles/.config/swaync>; JaKooLit/Hyprland-Dots `config/swaync/{config.json,style.css}` (waybar-colors `@import`, `noti-border-color @color12`, large buttons-grid) — <https://github.com/JaKooLit/Hyprland-Dots/tree/main/config/swaync>; Matt-FTW/dotfiles `.config/swaync/{config.json,style.css}` (catppuccin-macchiato hand-baked hex, `layer-shell-cover-screen`, `positionY: bottom`, inset critical shadow) — <https://github.com/Matt-FTW/dotfiles/tree/main/.config/swaync>; binnewbs/arch-hyprland `.config/swaync/{config.json,style.css}` (JaKooLit-derivative, `@import '../../.config/waybar/colors.css'` to reuse waybar palette across the notification surface) — <https://github.com/binnewbs/arch-hyprland/tree/main/.config/swaync>.

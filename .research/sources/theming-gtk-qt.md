# Sources - skills/rice/references/theming/gtk-qt.md

Research provenance for `skills/rice/references/theming/gtk-qt.md`.

Extracted from the load path: these citations are why the recommendations in that
file are what they are, and are read by a human reviewing them - never by an agent
authoring a config.

## Sources

- Hyprland wiki — App Themes / cursors: <https://wiki.hypr.land/> · hyprcursor: <https://wiki.hypr.land/Hypr-Ecosystem/hyprcursor/>
- adw-gtk3: <https://github.com/lassekongo83/adw-gtk3> · adw-colors: <https://github.com/lassekongo83/adw-colors>
- libadwaita named colors / CSS variables: <https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/css-variables.html> (verified June 2026 — main 1.7+ adds `overview_*` + `active_toggle_*`; `sidebar_*` + `secondary_sidebar_*` since 1.4; `dialog_*` since 1.2; `popover_shade_color` + `thumbnail_*` since 1.3/1.4)
- hyprqt6engine (Qt6 platform theme, replacement for qt6ct, KColorScheme-compatible): <https://wiki.hypr.land/Hypr-Ecosystem/hyprqt6engine/>
- xdg-desktop-portal-hyprland (the `dbus-update-activation-environment --systemd --all` form the wiki recommends, plus the KDE-file-picker `~/.config/xdg-desktop-portal/hyprland-portals.conf` recipe): <https://wiki.hypr.land/Hypr-Ecosystem/xdg-desktop-portal-hyprland/>
- Catppuccin GTK (archived June 2024): <https://github.com/catppuccin/gtk>
- Catppuccin Papirus folders: <https://github.com/catppuccin/papirus-folders> · papirus-folders: <https://github.com/PapirusDevelopmentTeam/papirus-folders>
- Papirus icon theme: <https://github.com/PapirusDevelopmentTeam/papirus-icon-theme>
- Bibata hyprcursor: <https://github.com/PythonTryHard/Bibata-Cursor-hyprcursor>
- matugen GTK template: <https://github.com/InioX/matugen-themes>
- nwg-look: <https://github.com/nwg-piotr/nwg-look> · <https://nwg-piotr.github.io/nwg-shell/nwg-look.html>
- ArchWiki — Uniform look for Qt and GTK applications: <https://wiki.archlinux.org/title/Uniform_look_for_Qt_and_GTK_applications>
- HyDE application theming: <https://deepwiki.com/JaKooLit/Hyprland-Dots/4.4-application-theming> · hyprqt6engine: <https://wiki.hypr.land/Hypr-Ecosystem/hyprqt6engine/>
- Flatpak desktop integration / theme access: <https://docs.flatpak.org/en/latest/desktop-integration.html>

**Config corpus read for the techniques catalog:**
- catppuccin/gtk `docs/USAGE.md` (libadwaita symlink + Flatpak override) and catppuccin/Kvantum README (`kvantummanager --set`, folder==name rule): <https://github.com/catppuccin/gtk> · <https://github.com/catppuccin/Kvantum>
- vinceliuice Graphite-/Colloid-gtk-theme `install.sh` (`-l/--libadwaita`, `-t` accent, `--round`, `--tweaks` named palettes): <https://github.com/vinceliuice/Graphite-gtk-theme> · <https://github.com/vinceliuice/Colloid-gtk-theme>
- JaKooLit/Hyprland-Dots `initial-boot.sh` + `DarkLight.sh` + `configs/ENVariables.conf` (gsettings quartet, dual qt5ct/qt6ct, QtQuick + scale env): <https://github.com/JaKooLit/Hyprland-Dots>
- prasanthrangan/hyprdots `Configs/.config/qt5ct,qt6ct/*.conf` (style=kvantum + Tela-circle + Cantarell/Nerd-mono fonts): <https://github.com/prasanthrangan/hyprdots>
- Matt-FTW/dotfiles `.config/hypr/configs/env.conf` (single env source of truth, QT_STYLE_OVERRIDE=kvantum, matched XCURSOR/HYPRCURSOR): <https://github.com/Matt-FTW/dotfiles>
- end-4/dots-hyprland (KDE platform theme route, in-repo Kvantum themes, runtime `hyprctl setcursor`) and mylinuxforwork/dotfiles (nwg-look workflow, Breeze qt6ct): <https://github.com/end-4/dots-hyprland> · <https://github.com/mylinuxforwork/dotfiles>
- papirus-folders (`-C <accent>`, `-Ru` after update) and vinceliuice Tela-circle-icon-theme: <https://github.com/PapirusDevelopmentTeam/papirus-folders> · <https://github.com/vinceliuice/Tela-circle-icon-theme>
- matugen `gtk-colors.css` templates (for the libadwaita named-color superset audit — `popover_fg_color`, `card_fg_color`, `sidebar_*`, `headerbar_backdrop_color`, `error_*`): end-4 `dots/.config/matugen/templates/gtk-4.0/gtk.css`, ml4w `dotfiles/.config/matugen/templates/gtk-colors.css`, AvengeMedia/DankMaterialShell `quickshell/matugen/templates/gtk-colors.css` (annotates `headerbar_backdrop_color` as "prevents white flash on window unfocus"), dusklinux/dusky and binnewbs/arch-hyprland `.config/matugen/templates/gtk-colors.css` (ml4w-derived).

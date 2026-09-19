# Sources - skills/rice/references/components/launcher/styling.md

Research provenance for `skills/rice/references/components/launcher/styling.md`.

Extracted from the load path: these citations are why the recommendations in that
file are what they are, and are read by a human reviewing them - never by an agent
authoring a config.

## Sources

- fuzzel.ini(5) — Arch manual: <https://man.archlinux.org/man/fuzzel.ini.5.en>
- rofi-theme(5) — Arch manual: <https://man.archlinux.org/man/rofi-theme.5.en>
- rofi-theme(5) markdown (upstream): <https://github.com/davatorium/rofi/blob/next/doc/rofi-theme.5.markdown>
- tofi config reference: <https://github.com/philj56/tofi/blob/master/doc/config>
- adi1090x/rofi (launchers/applets collection): <https://github.com/adi1090x/rofi>
- adi1090x type-1 launcher style: <https://github.com/adi1090x/rofi/blob/master/files/launchers/type-1/style-1.rasi>
- catppuccin/rofi: <https://github.com/catppuccin/rofi>
- catppuccin/fuzzel: <https://github.com/catppuccin/fuzzel>
- catppuccin/tofi: <https://github.com/catppuccin/tofi>
- alxndr13/wofi-catppuccin: <https://github.com/alxndr13/wofi-catppuccin>
- quantumfate/wofi (Catppuccin): <https://github.com/quantumfate/wofi>
- wofi(5) styling: <https://manpages.ubuntu.com/manpages/questing/man5/wofi.5.html>
- rofi-wayland fork (lbonn / in0ni): <https://github.com/in0ni/rofi-wayland>
- HyDE: <https://github.com/HyDE-Project/HyDE> · JaKooLit Hyprland-Dots: <https://github.com/JaKooLit/Hyprland-Dots> · ml4w dotfiles: <https://github.com/mylinuxforwork/dotfiles>
- Hyprland layer-rule blur for launchers: <https://github.com/hyprwm/Hyprland/issues/8408>

**Theme corpus read for the techniques catalog** (each theme file read directly):
- adi1090x/rofi — `files/launchers/type-1/style-1.rasi` (pill list), `type-3/style-3.rasi` (icon grid), `files/colors/*.rasi` (shared palette): <https://github.com/adi1090x/rofi>
- catppuccin/rofi — `catppuccin-default.rasi` layout + `themes/catppuccin-mocha.rasi` (26-name palette, `em` icon sizing): <https://github.com/catppuccin/rofi>
- lr-tech/rofi-themes-collection — `spotlight-*`, `rounded-template.rasi` + variants, `windows11-*`: <https://github.com/lr-tech/rofi-themes-collection>
- HyDE-Project/HyDE — `Configs/.config/rofi/theme.rasi` (generated palette) + `Configs/.local/share/hyde/rofi/themes/style_1.rasi` (wallpaper sidebar): <https://github.com/HyDE-Project/HyDE>
- JaKooLit/Hyprland-Dots — `config/rofi/themes/KooL_style-*.rasi` (`white/NN%` algebra, fullscreen `%`-icon grid): <https://github.com/JaKooLit/Hyprland-Dots>
- quantumfate/wofi (`src/mocha/style.css`, outline-ring selection) and alxndr13/wofi-catppuccin (`style.css`, zebra rows + focus glow): <https://github.com/quantumfate/wofi> · <https://github.com/alxndr13/wofi-catppuccin>
- catppuccin/fuzzel, catppuccin/tofi, philj56/tofi `themes/*` (fullscreen/dos two-ring), and real `fuzzel.ini`s from vaelixd/niri-dotfiles, caelestia-dots, chikobara/dotfiles (`include=` colors split, `layer=overlay`).
- end-4/dots-hyprland — `dots/.config/fuzzel/fuzzel.ini` (`include="…/fuzzel_theme.ini"` + `[border]` + `[dmenu] exit-immediately-if-empty=yes`), `dots/.config/matugen/templates/fuzzel/fuzzel_theme.ini` (matugen-driven `[colors]` block, 7 keys), `dots/.config/hypr/hyprland/rules.lua` (`namespace = "launcher"` for fuzzel blur — confirms fuzzel's default layer namespace).
- dusklinux/dusky — `.config/rofi/config.rasi` (verbose comments documenting the `sort + sorting-method:"fzf" + matching:"fuzzy"` frecency idiom, the `me-select-entry`/`me-accept-entry` single-click setup, and the `drun-match-fields` "drop categories" trick), `.config/matugen/templates/rofi-colors.rasi` (47-key M3 token dump).
- mylinuxforwork/dotfiles — `dotfiles/.config/rofi/config.rasi` (split `imagebox`/`listbox` with wallpaper-fill imagebox, M3 `@primary`/`@on-surface` references) + `dotfiles/.config/rofi/config-compact.rasi` (top-drop ML4W variant), `dotfiles/.config/matugen/templates/rofi-colors.rasi` (47-key M3 dump, same shape as dusky/binnewbs).
- binnewbs/arch-hyprland — `.config/rofi/config.rasi` (`@theme "/dev/null"` idiom to nullify rofi's default theme before `@import "colors.rasi"`), `.config/matugen/templates/rofi-colors.rasi` (47-key M3 dump).
- Matt-FTW/dotfiles — `.config/rofi/theme/catppuccin-macchiato.rasi` (rofi `linear-gradient()` as a value, used via `background-image: @selected;`), `.config/rofi/style.rasi` (modi `[ MousePrimary, MouseSecondary, MouseDPrimary ]` array for `me-accept-entry`).
- abenz1267/walker — `resources/config.toml` (upstream default; confirms `[shell]`/`[columns]`/`[placeholders]`/`[keybinds]`/`[providers]` sections plus 20+ flat keys including `ext_background_effect_blur` for `ext-background-effect-v1` compositor blur).
- prasanthrangan/hyprdots — `Configs/.config/hyde/wallbash/Wall-Dcol/rofi.dcol` (six-name semantic palette `main-bg`/`main-fg`/`main-br`/`main-ex`/`select-bg`/`select-fg`, `#<wallbash_pry1>E6` value syntax), `Configs/.config/hypr/windowrules.conf` (uses the pre-0.54 single-line `layerrule = blur,rofi` form — broken on current Hyprland; see `gotchas.md`).

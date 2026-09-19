# Sources - skills/rice/references/components/lock-screen/styling.md

Research provenance for `skills/rice/references/components/lock-screen/styling.md`.

Extracted from the load path: these citations are why the recommendations in that
file are what they are, and are read by a human reviewing them - never by an agent
authoring a config.

## Sources

- Official hyprlock wiki: <https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/>
- Shipped reference config (`assets/example.conf`):
  <https://github.com/hyprwm/hyprlock/blob/main/assets/example.conf>
- DeepWiki — hyprlock Background / Labels-Images-Shapes / Configuration:
  <https://deepwiki.com/hyprwm/hyprlock/5.2-background>,
  <https://deepwiki.com/hyprwm/hyprlock/5.3-labels-images-and-shapes>
- Catppuccin hyprlock port: <https://github.com/catppuccin/hyprlock/blob/main/hyprlock.conf>
- HyprFlux hyprlock examples: <https://www.hyprflux.dev/features/hyprlock.html>
- Arch Wiki — Hyprlock: <https://wiki.archlinux.org/title/Hyprlock>

**Config corpus read for the techniques catalog** (each `hyprlock.conf` read directly):
- hyprwm/hyprlock `assets/example.conf` — canonical key list + gradient state colors + `$LAYOUT` switcher: <https://github.com/hyprwm/hyprlock>
- catppuccin/hyprlock `hyprlock.conf` — `source = mocha.conf` palette vars, `.face` avatar, `$FPRINTPROMPT`: <https://github.com/catppuccin/hyprlock>
- HyDE-Project/HyDE `Configs/.config/hypr/hyprlock/*.conf` — clickable playerctl media controls, `$fn_greet` time-of-day greeting, `pkill -SIGUSR2` refresh, MPRIS album art: <https://github.com/HyDE-Project/HyDE>
- JaKooLit/Hyprland-Dots `config/hypr/hyprlock.conf` — tiered `cmd[update:N]` rates, full frosted-depth background stack, `##` Pango escaping, corner info HUD, `$colorN` ANSI palette refs from wallust: <https://github.com/JaKooLit/Hyprland-Dots>
- mylinuxforwork/dotfiles `dotfiles/.config/hypr/hyprlock.conf` — pre-baked blurred/square wallpaper assets, drop-shadows, matugen Material-You vars: <https://github.com/mylinuxforwork/dotfiles>
- Matt-FTW/dotfiles `.config/hypr/hyprlock.conf` — `rounding = -1` circle avatar, `fail_transition`, now-playing script label: <https://github.com/Matt-FTW/dotfiles>
- basecamp/omarchy `config/hypr/hyprlock.conf` + `default/themed/hyprlock.conf.tpl` — templated color source, `ignore_empty_input`, oversized single pill, flat `auth { fingerprint:enabled = false }`: <https://github.com/basecamp/omarchy>
- mahaveergurjar/Hyprlock-Dots `.config/hypr/hyprlock.conf` — `source`-swappable layout packs (13+ layouts), `zindex` over `shape{}` panels, split-stack clock: <https://github.com/mahaveergurjar/Hyprlock-Dots>
- end-4/dots-hyprland `dots/.config/hypr/hyprlock.conf` + `dots/.config/matugen/templates/hyprland/hyprlock-colors.conf` — matugen-rendered `$text_color`/`$entry_*` vars sourced from a tiny side file: <https://github.com/end-4/dots-hyprland>
- Axenide/Ax-Shell `config/hypr/hyprlock.conf` + matugen `hyprland-colors.conf` — `source`d `$foreground`/`$primary` matugen vars, `rgb($foreground)` wrap in label colors: <https://github.com/Axenide/Ax-Shell>
- fufexan/dotfiles `home/programs/wayland/hyprlock.nix` — NixOS-flavoured `programs.hyprlock` `settings { general = {…} }` + per-monitor `input-field { monitor = "eDP-1" }`: <https://github.com/fufexan/dotfiles>
- dusklinux/dusky `.config/hypr/hyprlock_themes/006_stacked_clock/hyprlock.conf` — split-stack hours/minutes, `animations { bezier = ... }` per-element fade timings, gradient `check_color`/`fail_color`: <https://github.com/dusklinux/dusky>
- binnewbs/arch-hyprland `.config/hypr/hyprlock.conf` — Material-You matugen vars (`$on_secondary_container`, `$secondary`) directly in label colors: <https://github.com/binnewbs/arch-hyprland>

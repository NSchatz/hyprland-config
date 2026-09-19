# Sources - skills/rice/references/components/waybar/styling.md

Research provenance for `skills/rice/references/components/waybar/styling.md`.

Extracted from the load path: these citations are why the recommendations in that
file are what they are, and are read by a human reviewing them - never by an agent
authoring a config.

## Sources

- Waybar Styling wiki (selectors, states, GTK CSS subset): https://github.com/Alexays/Waybar/wiki/Styling
- Waybar default `config.jsonc` (module syntax, format-icons): https://github.com/Alexays/Waybar/blob/master/resources/config.jsonc
- Floating-bar discussion (margins, transparent bar, passthrough): https://github.com/Alexays/Waybar/discussions/2594
- HyDE Waybar architecture (layouts/styles, CSS cascade, group/pill): https://deepwiki.com/HyDE-Project/HyDE/7-status-bar-(waybar) and https://hydeproject.pages.dev/de/configuring/waybar/
- JaKooLit Hyprland-Dots — Customizing Waybar (symlink model, font %): https://github.com/JaKooLit/Hyprland-Dots/wiki/Customizing_waybar
- ml4w dotfiles Waybar wiki (theme folders, custom overrides): https://github.com/mylinuxforwork/dotfiles/wiki/Waybar
- Catppuccin Waybar port (`@import`, `@define-color`, alpha/shade): https://github.com/catppuccin/waybar and `themes/mocha.css`
- Hyprland blur-on-waybar quirk: https://github.com/hyprwm/Hyprland/issues/6130
- Hyprland layer rules reference: https://deepwiki.com/hyprwm/hyprland-wiki/3.4-layer-rules
- Waybar `group`/drawer module (collapsible clusters, sliders): https://github.com/Alexays/Waybar/wiki/Module:-Group
- Waybar multiple-bars (the JSON array of named bars, per-bar config): https://github.com/Alexays/Waybar/wiki/Configuration
- Waybar `wlr/taskbar` module (the dock/taskbar in dock-mimic looks): https://github.com/Alexays/Waybar/wiki/Module:-Wlr-Taskbar
- Vertical-bar discussion (position left/right, rotate, narrow width): https://github.com/Alexays/Waybar/discussions/484
- Waybar Examples gallery (index of the configs below): https://github.com/Alexays/Waybar/wiki/Examples

**Community config corpus** — the techniques above were harvested by reading the `style.css` + `config.jsonc` of **~55 configs** linked off the Examples wiki directly. Grouped by what they best demonstrate:

- *Modern floating glass island*: zen0x00 (`zen0x00/dotfiles` → `themes/waybar`, glassmorphism stack), saibhargav (`gitlab.com/saibhargav/arch-hyprland-custom0`, `border-radius: 7rem` single-lozenge), Lynndroid21 (`Lynndroid21/Niri21`+`Sway21`, per-zone glowing pills + per-bar `name` + SIGUSR1 toggle), d00m1k (`d00m1k/SimpleBlueColorWaybar`, two-level pill nesting), dpgraham4401 (`dpgraham4401/.dotfiles`, differential island alpha), DerAnsari (`DerAnsari/hyprland-dots`, bracket/pipe separator modules).
- *Catppuccin / per-module hue + glow*: mechabar (`sejjy/mechabar`, powerline divider modules), soaddevgit (`soaddevgit/WaybarTheme`, inverted candy pills + autohide), HANCORE (`HANCORE-linux/waybar-themes`, `font-size:0` underline + `.empty` collapse + mpris glow + Omarchy inherit), manish12ys (`manish12ys/waybar`, `all: unset` + glow + frosted tooltip), theCode-Breaker (`theCode-Breaker/riverwm`, candy pastel-on-dark), hajosattila (`hajosattila/dotfiles`, gradient workspace fill + split `colors.css`), notscripter (`gitlab.com/notscripter/dotfiles`, inset-glow 999px islands + spring easing).
- *Drawer groups + GTK sliders*: saatvik333 (`saatvik333/niri-dotfiles`, wallust vertical bar), Sudhboi (`Sudhboi/niri-rice-dotfiles`, vertical, nested drawers + `.empty` morph + left-spine accent), gdots (`niksingh710/gdots`, vertical, GTK color math + rotated modules), Harsh-bin (`Harsh-bin/waybar-config`, countdown/todo widgets + 11-theme cycler), ashish-kus (`ashish-kus/waybar-minimal`, sliders-in-drawers + off-edge radii), Anik200 (`Anik200/dotfiles` super-waybar, icon-gauge ramps + end-cap modules), haikal-hakim (`haikal-hakim/athena`, matugen token-files + growing pill).
- *Material / elevation / segmented pills*: Prateek7071 (`Prateek7071/dotfiles`, inset-ring active + sparkline cpu + pomodoro), kamlendras (`kamlendras/waybar-macos-sequoia`, macOS dual-bar/dock recipe), TheFrankyDoll (`TheFrankyDoll/win10-style-waybar`, Win10 taskbar + collapse-to-zero reveal), Pipshag (`Pipshag/dotfiles_nord` + `dotfiles_kitties` vertical, two-stage blink + governor module), benny-e (`benny-e/waybar-config`, numbered-CSS cascade + `currentColor` underline), Zilero232 (`Zilero232/arch-install-kit`, colored left-edge tabs), MBestKing (`MBestKing/dotfiles`, gradient-as-brand).
- *Powerline / segmented & per-module hue*: cjbassi (`cjbassi/config`, triple-clock + 4-arrow powerline), mxkrsv (`mxkrsv/dotfiles-old`, 10-arrow gradient chain), arkboix (`arkboix/sway`, palette stacking + stepped blink), jbauernberger (`gitlab.com/jbauernberger/dotfiles`, 16-shade Nord heatmap + COVID module), oscarcp (`git.sr.ht/~oscarcp/ghostfiles`, directional half-radius weld).
- *Minimal / mono / flat*: mechakotik (`mechakotik/dots`, pure-black mono + glyph dots), elifouts (`elifouts/Dotfiles`), rocketmike12 (`rocketmike12/.dotfiles`, outlined-chip theme-as-folder), Robinhuett (`Robinhuett/dotfiles`, `.solo` backdrop + balanced underline), Senior-Ori (`Senior-Ori/dotfiles`, CFFI Rust ws-tabs), Egosummiki / sephid86 / Senior-Ori (red-accent transparent).
- *Dock / dual-bar / OS-mimic*: cxOrz (`cxOrz/dotfiles-hyprland`, ChromeOS shelf + dot workspaces), kamlendras (macOS Sequoia), TheFrankyDoll (Win10), Bwc9876 (`Bwc9876/nix-conf`, dual-bar + `border-color`-as-state + Nix/nushell modules), EviLuci (`EviLuci/dotfiles`, vertical + old dual-bar + gradient border-image), qoheniac (`qoheniac/config`, dual-bar + split-network modules), Jan-Aarela (`Jan-Aarela/dotfiles`, indicator bar + skew tabs).
- *Not reachable when surveyed* (left here so they aren't re-chased): cowboycodr/dotfiles, abdus/dotfiles, OriginCode/dotfiles (no waybar dir), tim3dman/.dotfiles, lgaboury/Sway-Waybar-Install-Script, DIvan2000 (gitea, auth-walled); genofire/toger5 gists are JSONC-only (no CSS to harvest).

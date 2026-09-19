# Sources - skills/rice/references/components/terminal/styling.md

Research provenance for `skills/rice/references/components/terminal/styling.md`.

Extracted from the load path: these citations are why the recommendations in that
file are what they are, and are read by a human reviewing them - never by an agent
authoring a config.

## Sources

- kitty — kitty.conf reference: <https://sw.kovidgoyal.net/kitty/conf/>
- kitty padding+opacity issue: <https://github.com/kovidgoyal/kitty/issues/7921>
- alacritty — TOML config reference: <https://alacritty.org/config-alacritty.html>
- alacritty YAML→TOML migration: <https://medium.com/@pachoyan/migrate-alacritty-terminal-configuration-yaml-to-toml-for-0-13-x-versions-67fda01be18c>
- foot — foot.ini(5) man page: <https://man.archlinux.org/man/foot.ini.5.en>
- wezterm — Colors & Appearance: <https://wezterm.org/config/appearance.html>
- ghostty — Configuration reference: <https://ghostty.org/docs/config/reference>
- ghostty — Configuration guide: <https://ghostty.org/docs/config>
- Catppuccin kitty (Mocha port, 16-color map): <https://github.com/catppuccin/kitty/blob/main/themes/mocha.conf>
- Catppuccin palette: <https://catppuccin.com/palette/>
- HyDE Project dotfiles: <https://github.com/HyDE-Project/HyDE>
- JaKooLit Hyprland-Dots: <https://github.com/JaKooLit/Hyprland-Dots>
- DankMaterialShell matugen templates: <https://github.com/AvengeMedia/DankMaterialShell/tree/main/quickshell/matugen/templates>
- ML4W matugen btop template: <https://github.com/mylinuxforwork/dotfiles/blob/main/dotfiles/.config/matugen/templates/btop.theme>
- btop canonical theme key set (upstream): <https://github.com/aristocratos/btop/blob/main/themes/dracula.theme>
- ghostty config-file `?` optional include: <https://ghostty.org/docs/config>

**Config corpus read for the techniques catalog:**
- catppuccin/kitty, catppuccin/foot (`themes/catppuccin-mocha.ini` — dual `[colors-dark]`/`[colors-light]`, `cursor=<text> <fill>` two-token form, `search-box-*`/`jump-labels`/`urls`/256-color slots `16=`/`17=`), catppuccin/alacritty (`.toml`), catppuccin/wezterm (built-in `color_scheme`): the canonical 16-color ports.
- alacritty/alacritty-theme — canonical TOML table layout + themes dir import idiom: <https://github.com/alacritty/alacritty-theme>
- HyDE-Project/HyDE `Configs/.config/kitty/{kitty.conf,theme.conf}` + `Configs/.config/hyde/wallbash/Wall-Dcol/kitty.dcol` — 3-file include chain, `window_padding_width 25`, powerline slanted tabs, opacity-via-compositor, full chrome theming via wallbash placeholders (`cursor_text_color`, `active_tab_*`, `inactive_tab_*`).
- HyDE-Project/HyDE `Configs/.config/hyde/wallbash/Wall-Ways/cava.dcol` — 8-stop monotonic gradient pattern across the palette.
- JaKooLit/Hyprland-Dots `config/kitty/kitty.conf` + `config/wallust/templates/colors-{kitty,cava,ghostty}.conf` — `background_opacity 0.9` + `dynamic_background_opacity 1`, `cursor_trail 1`, `selection-background = {{color12}}`, 8-stop cava gradient, `font-size 16` for high-DPI default.
- JaKooLit/Hyprland-Dots `config/ghostty/ghostty.config` — `config-file = ?path` optional include layered on top of a base config, `bold-is-bright = false` (Catppuccin discipline), `quick-terminal-position = center`, `shell-integration-features = cursor,sudo`.
- AvengeMedia/DankMaterialShell `quickshell/matugen/templates/{kitty,kitty-tabs,alacritty,foot,ghostty,wezterm}.{conf,toml,ini,lua}` — Material You with `dank16` namespace for the 16 ANSI cells (NOT mapped from `primary`/`secondary`/`tertiary`), split kitty into `dank-theme.conf` + `dank-tabs.conf`, `tab_title_template` with bell/activity symbols.
- end-4/dots-hyprland `dots/.config/kitty/kitty.conf` — `include ~/.local/state/quickshell/user/generated/terminal/kitty-theme.conf` (XDG state for generated file), `window_margin_width 21.75` (margin not padding — note the quirk).
- end-4/dots-hyprland `dots/.config/foot/foot.ini` — `bold-text-in-bright=no`, `dpi-aware=no`, `beam-thickness=1.5`.
- caelestia-dots/caelestia `foot/foot.ini` — `[colors-dark] alpha=0.78` only-on-dark transparency, `gamma-correct-blending=no` for crisp alpha compositing.
- mylinuxforwork/dotfiles `dotfiles/.config/matugen/templates/btop.theme` — the upstream-complete btop key set (cached_/available_/download_/upload_/process_ meters in addition to free_/used_/temp_/cpu_), with empty `_mid` for 2-stop fades.
- binnewbs/arch-hyprland `.config/kitty/kitty.conf` + `.config/matugen/templates/kitty-colors.conf` — JetBrainsMono NF Bold, matugen `surface`/`surface_bright` → `color0`/`color8`, `cursor_text_color` exported.
- dusky `.config/{kitty,foot,alacritty}/*` — dusky kitty uses `font_family auto` (NOT documented as valid by upstream — see Pitfalls), `cursor_trail 10`, `cursor_trail_decay 0.15 0.4`, `shell_integration no-cursor`, `tab_bar_edge top`. dusky alacritty uses `general.import = [...]` dotted-key form. dusky foot uses `font=...:fontfeatures=-liga` to disable ligatures inline.
- Matt-FTW/dotfiles `.config/kitty/kitty.conf` + `.config/ghostty/config` — `modify_font cell_height 122%`, `tab_bar_min_tabs 2`, `tab_fade 0.25 0.5 0.75 1`, `cursor_trail_decay 0.1 0.2`; ghostty `font-feature = +ss02/+ss03` stylistic sets, `adjust-cell-height = 28%`, `window-padding-balance = true`, `shell-integration-features = no-cursor`.
- linuxmobile/hyprland-dots `.config/wezterm/wezterm.lua` — `font_with_fallback` pattern, `bold_brightens_ansi_colors = true`, `font_rules` for explicit italic/bold variants.
- fufexan/dotfiles `home/base/gui/terminal/foot.nix` — `colors-dark.alpha=0.9 blur=yes` + `colors-light.alpha=0.9 blur=yes` (alpha+blur INSIDE the `[colors-*]` blocks, not `[main]`), `selection-target=clipboard`, `scrollback.{multiplier=3,indicator-position=relative,indicator-format=line}`.
- eulersson/dotfiles (alacritty `transparent_background_colors` + `decorations="transparent"`, neovim-extras theme import), lukpank/dotfiles (split config, `draw_bold_text_with_bright_colors=false`), taylor85345/hyprland-dotfiles (`foot.ini` `alpha`/`dpi-aware`).
- ghostty.org config reference (`config-file ?path`, `theme = light:,dark:`, `palette = N=COLOR`, `cell-foreground` cursor, `background-blur` integer/bool) and the upstream `aristocratos/btop/main/themes/dracula.theme` (canonical full btop key list verified).

# Styling Terminals (kitty / alacritty / foot / wezterm / ghostty)

A terminal's look is almost entirely four knobs: the **16-color ANSI palette** (plus
foreground/background/cursor/selection), the **font**, **padding**, and **background opacity**.
The palette is the star — match it to the rest of the desktop and the terminal instantly looks
"riced." Everything else is breathing room and polish.

## What you're styling

| Terminal    | Config file                          | Format            | How colors are set                                   | Reload                                                        |
|-------------|--------------------------------------|-------------------|------------------------------------------------------|--------------------------------------------------------------|
| **kitty**   | `~/.config/kitty/kitty.conf` (+ `include colors.conf`) | `key value` (space-separated) | `foreground`, `background`, `cursor`, `color0`..`color15` | Auto-reloads on save; or `kill -SIGUSR1 $KITTY_PID` / `kitten @ load-config` / `ctrl+shift+f5` |
| **alacritty** | `~/.config/alacritty/alacritty.toml` | **TOML** (was YAML pre-0.13) | `[colors.primary]`, `[colors.normal]`, `[colors.bright]`, `[colors.cursor]` | Live reload on save (`live_config_reload = true`, default)   |
| **foot**    | `~/.config/foot/foot.ini`            | **INI** sections  | `[colors]` `foreground=`/`background=`/`regular0..7`/`bright0..7` (bare RRGGBB, no `#`); or dual `[colors-dark]` / `[colors-light]` | No config-reload signal. `SIGUSR1` swaps to `[colors-dark]`, `SIGUSR2` to `[colors-light]` (existing blocks only). Other changes: restart. |
| **wezterm** | `~/.config/wezterm/wezterm.lua`      | **Lua** (returns a config table) | `config.colors = { foreground, background, ansi = {…}, brights = {…} }` | Auto-reloads on save (`automatically_reload_config = true`)  |
| **ghostty** | `~/.config/ghostty/config`           | `key = value`     | `foreground`, `background`, `cursor-color`, `palette = N=#hex` | `ctrl+shift+,` reload, or restart                            |

Hex format differs: kitty/alacritty/wezterm/ghostty want a leading `#` (`#1e1e2e`); **foot uses
bare RRGGBB with no `#`** (`1e1e2e`).

## Design anatomy — the knobs that change the look

**The 16-color ANSI palette (dominant).** This is what `ls`, `git`, your prompt, and every TUI
draw with. It maps directly from a rice palette: `background`/`foreground` are the base, then
`color0..color15`. The mapping convention is universal:

| Index   | Role                          | Bright (8–15)        |
|---------|-------------------------------|----------------------|
| `color0`  | black (≈ background / dark)  | `color8`  bright-black (muted gray — used for comments/dim text) |
| `color1`  | red                          | `color9`  bright red |
| `color2`  | green                        | `color10` bright green |
| `color3`  | yellow                       | `color11` bright yellow |
| `color4`  | blue                         | `color12` bright blue |
| `color5`  | magenta                      | `color13` bright magenta |
| `color6`  | cyan                         | `color14` bright cyan |
| `color7`  | white (≈ foreground / light) | `color15` bright white |

Get `color0` and `color8` right or `ls`/`git status` become unreadable: `color0` should read as a
near-background dark, `color8` as a distinguishable muted gray.

**Font.** Family + size. Use a **Nerd Font** (patched with Powerline/Devicon glyphs) so prompts
(starship/powerlevel10k), `eza`/`lsd` icons, and TUIs render their symbols instead of tofu boxes.
Popular: JetBrainsMono Nerd Font, FiraCode Nerd Font, CaskaydiaCove (Cascadia Code) Nerd Font.
Ligatures are a taste call (FiraCode/Cascadia have them; kitty disables with `disable_ligatures`).

**Padding / margins.** `window_padding_width` (kitty), `[window].padding` x/y (alacritty),
`pad=` (foot), `window_padding` (wezterm), `window-padding-x/-y` (ghostty). 8–15px gives the text
room to breathe; this is one of the biggest "looks designed vs. default" differences.

**Background opacity + blur.** Slight transparency (0.85–0.95) over a blurred compositor reads as
glassy and premium. kitty has its own `background_blur` (Wayland/KDE); pair it with Hyprland's
`decoration { blur { enabled = true } }` and a layer/window rule so the wallpaper behind blurs
cleanly. ghostty has `background-blur`. alacritty/foot/wezterm rely on the compositor's blur.

**Cursor.** Shape (`block`/`beam`/`underline`) and blink. Block reads classic; beam reads modern.

**Decorations / tab bar.** Minimalists hide window decorations and the tab bar
(`hide_window_decorations yes`, `tab_bar_style hidden` in kitty;
`decorations = "None"` in alacritty) and let Hyprland draw the border/gaps instead.

**Chrome that needs theming if it's shown.** kitty has several palette-driven slots
beyond the 16 ANSI cells that fall back to hardcoded defaults if left unset, and
those defaults clash badly with most riced palettes — caught across
catppuccin/kitty mocha.conf, HyDE Wall-Dcol/kitty.dcol, DankMaterialShell
kitty.conf + kitty-tabs.conf, and binnewbs matugen kitty-colors.conf:

| Slot | Visible when | Community mapping |
|---|---|---|
| `cursor_text_color` | block-cursor draws a glyph underneath | `bg` (catppuccin sets it to `base`) |
| `url_color` | mouse hovers a URL | `accent` (catppuccin → `lavender`, HyDE → `wallbash_pry4`) |
| `active_tab_foreground` / `active_tab_background` | `tab_bar_style != hidden` AND `tab_bar_min_tabs <= active count` | `bg` / `accent` |
| `inactive_tab_foreground` / `inactive_tab_background` | same | `muted` / `surface` |
| `tab_bar_background` | `tab_bar_style != hidden` | `bg` (matches window so the strip blends in) |
| `active_border_color` / `inactive_border_color` / `bell_border_color` | `window_border_width >= 1pt` | `accent` / `surface` / `red` |
| `selection_background` / `selection_foreground` | text selection | `accent` / `bg` (or `accent` / `fg`) |

The plugin's `kitty.tmpl` ships all of these wired through the palette — see
`references/components/terminal/kitty.tmpl`.

## How the community styles it

- **Matched-to-everything.** The signature riced look: the terminal's 16 colors *are* the desktop
  palette — same scheme as waybar, the launcher, hyprlock, GTK. Catppuccin, Tokyo Night, Gruvbox,
  Nord, Rosé Pine, and Kanagawa all ship first-party ports for every terminal here
  (e.g. `catppuccin/kitty`, `catppuccin/alacritty`, `catppuccin/foot`, `catppuccin/ghostty`).
- **Slight transparency + blur.** The most common "neon over wallpaper" aesthetic
  (Catppuccin Mocha, Tokyo Night Storm): opacity ~0.85–0.92, compositor blur on, dark base.
- **Opaque minimal.** The other camp: opacity `1.0`, generous padding, one bold accent — crisp and
  legible, no glass.
- **Padding.** Commonly 8–15px. HyDE/JaKooLit-style Hyprland dotfiles lean kitty with ~10px
  padding and ~0.9 opacity; many r/unixporn posts go 15–20px for an airy look.
- **Nerd Fonts.** JetBrainsMono Nerd Font is the de-facto default in HyDE and most Hyprland
  dotfiles; FiraCode and CaskaydiaCove are the usual alternates.

## Battle-tested techniques (from real terminal configs)

Concrete, attributed moves harvested from real configs and the first-party theme repos. Grouped by
what they buy you.

**Theme indirection — the maintainability idiom (differs per terminal).**
- *kitty: an `include` chain* (HyDE): `kitty.conf` → `include hyde.conf` → `include theme.conf` (generated). The user file holds layout, a middle file holds font/padding, and the theming engine only ever rewrites the leaf `theme.conf`. This is exactly the plugin's `include colors.conf` pattern, one layer deeper. The end-4 illogical-impulse Quickshell variant goes a step further: `include ~/.local/state/quickshell/user/generated/terminal/kitty-theme.conf` (`dots/.config/kitty/kitty.conf`) — the generated file lives in XDG state, never overwritten by config-restore, and matugen writes it on every wallpaper cycle.
- *ghostty: `theme = name` with built-in light/dark auto-switch* — `theme = light:catppuccin-latte,dark:catppuccin-mocha` flips with the system appearance from one key (documented in `ghostty.org/docs/config/reference` → theme); list with `ghostty +list-themes`. Override individual slots without redefining the palette via `palette = 5=#BB78D9` (also documented; palette is `N=COLOR` for N=0–255, hex with or without `#`, or named X11 colors).
- *ghostty: optional `config-file = ?path`* — prefixing the path with `?` makes the include optional (the file is silently skipped if missing). JaKooLit (`config/ghostty/ghostty.config`) layers `config-file = ?~/.config/ghostty/theme.conf` and `config-file = ?~/.config/ghostty/wallust.conf` so users can drop in a fixed theme OR let wallust render one without editing the main config. Important order note: `config-file` is processed at the END of the current file, so any keys AFTER it in the parent don't override the included file's values.
- *foot: dual `[colors-dark]` / `[colors-light]` in one file* (catppuccin/foot) so foot follows the system preference with zero swapping. Each section can independently set `alpha=` and `blur=` (per `foot.ini(5)`), so the light theme can be opaque and the dark theme translucent — and `blur=yes` is a foot-side hint to the compositor (KDE-style server-side blur), NOT a foot-rendered effect; on Hyprland the actual blur still comes from the compositor's decoration block. fufexan's nix-managed `foot.nix` is the cleanest worked example with `inherit alpha blur` across both color blocks.
- *alacritty: `[general] import`* a standalone `.toml` color file (catppuccin/alacritty, alacritty-theme) — swap one import to re-theme; light/dark = swap the imported file (lukpank keeps font/env in the base, colors in `dark.toml`). dusky's inline TOML uses the dotted form `general.import = ["alacritty-colors.toml"]` — strictly equivalent to `[general] import = [...]`, just denser. `import` skips missing files silently (per upstream docs), so the rice's first-run race condition (colors file rendered AFTER alacritty config installed) is harmless.
- *wezterm: built-in `color_scheme` by name, no file* — `color_scheme = "Catppuccin Mocha"`; fork one with `wezterm.color.get_builtin_schemes()["Catppuccin Mocha"]`, tweak `background`/`tab_bar`, register under `color_schemes` (the OLED true-black trick), or layer a single `config.colors = { background = … }` override on top of the named scheme.
- *matugen pattern — keep the 16 ANSI colors namespaced* (DankMaterialShell `quickshell/matugen/templates/{kitty,alacritty,foot,ghostty,wezterm}.*`): material-derived names (`primary`, `on_surface`, `primary_container`) drive selection / cursor / chrome, but the 16 ANSI cells come from a SEPARATE `dank16.colorN.default.hex` namespace, not from `primary`/`secondary`/`tertiary`. This is the only sane way to do Material You + terminal — Material's `tertiary` makes a terrible `color3` because it isn't constrained to "yellowish." Worth knowing because copy-pasting matugen's `primary.default.hex` into a `color1=` slot (a common shortcut) gives you a terminal whose "red" tracks the wallpaper's accent — confusing for `git status`.

**Transparency that actually shows (the gotchas).**
- *alacritty needs `[colors] transparent_background_colors = true`* (eulersson) — without it, `[window] opacity` is ignored because cells paint the theme's solid background. The key lives under **`[colors]`**, not `[window]`. Pair `opacity = 0.75` + `decorations = "Transparent"` (transparent titlebar — note capitalized enum: `Full`/`None`/`Transparent`/`Buttonless`) with Hyprland blur. Note `[window] blur` is **macOS-only** — on Wayland the blur comes from the compositor.
- *wezterm splits `window_background_opacity` from `text_background_opacity`* — keep text opaque (`1.0`) over a translucent background so glyphs stay crisp.
- *HyDE leaves kitty `background_opacity` commented* and drives transparency from a Hyprland `windowrule = opacity` instead — one place controls every window's translucency, terminal included. JaKooLit instead sets `background_opacity 0.9` + `dynamic_background_opacity 1` (so it can be changed at runtime) + `cursor_trail 1`.

**Per-terminal details worth knowing.**
- *foot cursor is `cursor = <text> <cursor-bg>`* — per `foot.ini(5)`: "Two space separated RRGGBB values specifying the foreground (text) and background (cursor) colors for the cursor." catppuccin/foot mocha sets `cursor=11111b f5e0dc` (crust as text-on-cursor, rosewater as cursor fill). DankMaterialShell's foot template uses the same shape: `cursor = {background.hex_stripped} {primary.hex_stripped}` (text inverts to bg color, cursor fills with the accent). `dpi-aware = no` honors the literal font `size=` instead of scaling on a fractional-scaled Hyprland output. `pad = 4x4` is `<x>x<y>` pixels; appending ` center` (e.g. `pad=12x12 center`) centers the grid in the window when there's extra room (caelestia/foot uses `pad=25x25` without center; fufexan uses `pad=4x4 center`).
- *foot `[colors-*]` is where alpha AND blur live* — `alpha=0.85` and `blur=yes` both belong inside `[colors-dark]` / `[colors-light]` per `foot.ini(5)`, NOT under `[main]`. Putting them at the top level silently no-ops because foot drops unknown keys. caelestia's `foot/foot.ini` uses exactly this pattern: top-level for fonts/scrollback/cursor, then a bare `[colors-dark] alpha=0.78` block to dim the dark theme. `blur=yes` is the KDE-style hint to the compositor; on Hyprland the actual blur still comes from the `decoration { blur { ... } }` block.
- *foot extras worth keeping* — `bold-text-in-bright=no` (catppuccin/foot, end-4) keeps bold text in the regular palette instead of jumping to bright (avoids washed-out bold, mirrors alacritty's `draw_bold_text_with_bright_colors=false`). `selection-target=clipboard` (fufexan) makes selecting text copy straight to the system clipboard. `scrollback.multiplier=3` + `scrollback.indicator-position=relative` + `scrollback.indicator-format=line` adds a visible scrollback indicator. catppuccin/foot's full mocha file also exports `selection-foreground`, `selection-background`, `search-box-match`, `search-box-no-match`, `jump-labels`, `urls`, and 256-color slots `16=` / `17=` — the plugin doesn't ship those today but they're available if a user pastes them.
- *ghostty cursor invert* — `cursor-color = cell-foreground` (or `cell-background`) makes the cursor invert against whatever cell it sits over, instead of a fixed hue. `cursor-style = block` + `cursor-style-blink = false` for a steady block.
- *ghostty `background-blur` values* — per `ghostty.org/docs/config/reference`: a non-negative integer is the blur intensity, `true` aliases to the default intensity 20, `false` aliases to 0. So `background-blur = 20` (Matt-FTW) and `background-blur = true` are equivalent. JaKooLit goes harder: `background-blur-radius = 60` (the deprecated alias still accepted).
- *ghostty stylistic sets* — `font-feature = +ss02` (Matt-FTW with Maple Mono) enables OpenType stylistic set 2 (cursive italics, alt zeros, etc., depending on the font). Combine with `font-feature = +calt` for contextual alternates. Lives one feature per line.
- *wezterm borderless on a tiling WM* — `window_decorations = "RESIZE"` drops the OS titlebar but keeps resize borders; `hide_tab_bar_if_only_one_tab = true` hides the strip until you open a second tab; guard the config with `wezterm.config_builder()` for clearer errors. `window_padding` is per-side and accepts `"1cell"` as well as px. Valid `window_decorations` values per upstream: `"NONE"`, `"TITLE"`, `"RESIZE"`, `"TITLE | RESIZE"` (the default), `"INTEGRATED_BUTTONS|RESIZE"` — strings, uppercase enum. Default `default_cursor_style` is `SteadyBlock`; valid set: `SteadyBlock`, `BlinkingBlock`, `SteadyUnderline`, `BlinkingUnderline`, `SteadyBar`, `BlinkingBar`. Blinking variants increase GPU load — tune `animation_fps` if needed.
- *alacritty bold-color discipline* — `draw_bold_text_with_bright_colors = false` (lukpank) keeps bold text its normal hue instead of jumping to the bright palette (avoids washed-out bold). Default `[font] size` per upstream is `11.25` (float) — render integer answers as `<n>.0` to be strict-TOML-clean.
- *kitty `cursor_trail` is a millisecond threshold, not a boolean* — per upstream: "Set this to a value larger than zero to enable...measured in milliseconds. The trail animation only follows cursors that have stayed in their position for longer than the specified number of milliseconds." So `cursor_trail 1` (JaKooLit, end-4) means "trail any cursor that's been still for >1ms" — effectively always. binnewbs cranks it: `cursor_trail 10` + `cursor_trail_decay 0.15 0.4` (the decay is "two positive float values specifying the fastest and slowest decay times in seconds") + `cursor_trail_start_threshold 2` (cells the cursor must move before the trail kicks in). Pair with `shell_integration no-cursor` so the shell doesn't fight kitty for the cursor shape.
- *kitty `cursor_blink_interval` is seconds, and supports CSS easing* — upstream: "The interval to blink the cursor (in seconds). Set to zero to disable blinking. Negative values mean use system default." Modern kitty accepts `0.5 ease-in-out` (one-second animated blink cycle); `cursor_stop_blinking_after 1` (ML4W) freezes the cursor after 1s of keyboard idle so the screen settles. `cursor_blink_interval 0` is the plain "no blink."
- *kitty powerline tab bar — the full chrome* — `tab_bar_edge top|bottom` (default `bottom`; binnewbs uses `top`, DankMaterialShell uses `top`, Matt-FTW uses `bottom`); `tab_bar_style powerline` + `tab_powerline_style slanted` (`angled`/`round`/`slanted`); `tab_bar_min_tabs 2` hides the strip until you open a second tab (Matt-FTW, Dank); `tab_bar_align left`; `active_tab_font_style bold` + `inactive_tab_font_style normal`. The Dank `kitty-tabs.conf` template is the canonical "Material You powerline" — splits out `tab_bar_margin_color`, `tab_bar_background`, and uses a `tab_title_template "{fmt.fg.red}{bell_symbol}{activity_symbol}{fmt.fg.tab}{title[:30]}{title[30:] and '…'} [{index}]"` for index+truncation.
- *kitty fine font-metric tweaks* — `modify_font cell_height 122%` (Matt-FTW) increases line height for "airy" reading; `modify_font` is documented as taking a value with `px` / `%` suffixes. Cells too tight or too wide? `modify_font cell_width 80%`.
- *Catppuccin's normal/bright share the 6 hues* — only the grays differ (`color0`/`color8` = surface1/surface2, `color7`/`color15` = subtext1/subtext0). So when hand-mapping a palette, the bright row mostly copies normal; spend your effort on the two gray pairs (the `color0`/`color8` contrast warning above).
- *Palette coherence across tools* (eulersson): import the terminal theme straight from your Neovim colorscheme's `extras/` dir (e.g. `tokyonight.nvim/extras/alacritty/…`) so editor and terminal can never drift.

## Tasteful default recipe

This plugin's rice **renders kitty's `colors.conf`** from the palette, so kitty is primary. Keep
the look in `kitty.conf` and the palette in an `include`d `colors.conf` — re-theming only rewrites
the colors file.

**`~/.config/kitty/kitty.conf`** (the look; palette-agnostic):

```conf
include colors.conf

font_family            {{font_mono}}     # a Nerd Font, e.g. JetBrainsMono Nerd Font
font_size              11.0

background_opacity     0.92
background_blur        1                 # pair with Hyprland decoration blur
window_padding_width   12

cursor_shape           beam
cursor_blink_interval  0.5

hide_window_decorations yes              # let Hyprland draw the border/gaps
tab_bar_style          powerline
confirm_os_window_close 0
```

**`~/.config/kitty/colors.conf`** (palette-driven; rice keys, hex **without** `#` in the key,
template adds it). This is exactly what the plugin generates:

```conf
background  #{{bg}}
foreground  #{{fg}}
cursor      #{{cursor}}
selection_background #{{accent}}
selection_foreground #{{bg}}
color0  #{{color0}}   color8  #{{color8}}
color1  #{{color1}}   color9  #{{color9}}
color2  #{{color2}}   color10 #{{color10}}
color3  #{{color3}}   color11 #{{color11}}
color4  #{{color4}}   color12 #{{color12}}
color5  #{{color5}}   color13 #{{color13}}
color6  #{{color6}}   color14 #{{color14}}
color7  #{{color7}}   color15 #{{color15}}
```

**Catppuccin Mocha worked example** (`colors.conf`), straight from `catppuccin/kitty`:

```conf
background  #1e1e2e
foreground  #cdd6f4
cursor      #f5e0dc
selection_background #f5e0dc
selection_foreground #1e1e2e
color0  #45475a   color8  #585b70
color1  #f38ba8   color9  #f38ba8
color2  #a6e3a1   color10 #a6e3a1
color3  #f9e2af   color11 #f9e2af
color4  #89b4fa   color12 #89b4fa
color5  #f5c2e7   color13 #f5c2e7
color6  #94e2d5   color14 #94e2d5
color7  #bac2de   color15 #a6adc8
```

**alacritty** — `~/.config/alacritty/alacritty.toml`:

```toml
[font]
normal = { family = "JetBrainsMono Nerd Font" }
size = 11.0

[window]
opacity = 0.92
padding = { x = 12, y = 12 }
decorations = "None"

[colors.primary]
background = "#1e1e2e"
foreground = "#cdd6f4"

[colors.cursor]
cursor = "#f5e0dc"
text   = "#1e1e2e"

[colors.normal]
black = "#45475a"; red = "#f38ba8"; green = "#a6e3a1"; yellow = "#f9e2af"
blue = "#89b4fa"; magenta = "#f5c2e7"; cyan = "#94e2d5"; white = "#bac2de"

[colors.bright]
black = "#585b70"; red = "#f38ba8"; green = "#a6e3a1"; yellow = "#f9e2af"
blue = "#89b4fa"; magenta = "#f5c2e7"; cyan = "#94e2d5"; white = "#a6adc8"
```

**foot** — `~/.config/foot/foot.ini` (note: bare hex, no `#`; alpha lives in `[colors]`):

```ini
[main]
font=JetBrainsMono Nerd Font:size=11
pad=12x12 center

[cursor]
style=beam

[colors]
alpha=0.92
foreground=cdd6f4
background=1e1e2e
regular0=45475a  regular1=f38ba8  regular2=a6e3a1  regular3=f9e2af
regular4=89b4fa  regular5=f5c2e7  regular6=94e2d5  regular7=bac2de
bright0=585b70   bright1=f38ba8   bright2=a6e3a1   bright3=f9e2af
bright4=89b4fa   bright5=f5c2e7   bright6=94e2d5   bright7=a6adc8
```

**ghostty** — `~/.config/ghostty/config` (or just `theme = catppuccin-mocha`, which ships built-in):

```
font-family = JetBrainsMono Nerd Font
font-size = 11
background = #1e1e2e
foreground = #cdd6f4
cursor-color = #f5e0dc
background-opacity = 0.92
background-blur = 20
window-padding-x = 12
window-padding-y = 12
window-decoration = none
cursor-style = bar
palette = 0=#45475a
palette = 8=#585b70
# … 1–7 and 9–15 likewise, or use `theme = catppuccin-mocha`
```

**wezterm** — `~/.config/wezterm/wezterm.lua` (sketch): set `config.color_scheme =
'Catppuccin Mocha'` (built-in), then `config.window_background_opacity = 0.92`,
`config.window_padding = { left = 12, right = 12, top = 12, bottom = 12 }`,
`config.font = wezterm.font('JetBrainsMono Nerd Font')`, `config.default_cursor_style =
'BlinkingBar'`.

## Pitfalls

- **Non-Nerd font.** Prompts, `eza`/`lsd` icons, and TUI glyphs render as tofu boxes (□) or
  missing Powerline separators. Install and select a `* Nerd Font` family.
- **Opacity too low.** Below ~0.8, text fights the wallpaper and becomes unreadable, especially on
  busy images. 0.85–0.95 is the sweet spot.
- **Transparency without compositor blur.** Plain transparency over a detailed wallpaper looks
  dirty/noisy. Enable Hyprland's blur (and kitty `background_blur` / ghostty `background-blur`)
  for the clean glass effect.
- **kitty padding + opacity bug.** On some kitty versions the `window_padding_width` area renders
  with a solid (opaque) background while the cells are transparent, leaving a visible bar — known
  upstream issue; if you hit it, reduce padding or check your kitty version.
- **alacritty old YAML examples.** alacritty migrated to **TOML** at 0.13. Copy-pasted
  `alacritty.yml` snippets won't load; run `alacritty migrate` and use TOML sections. Note
  `style = { shape = "Beam" }` lives under `[cursor]`, not `[colors]`.
- **foot `#` and alpha mistakes.** foot rejects `#`-prefixed hex, and transparency must go through
  `[colors]` `alpha=` — there's no per-color alpha and no opacity key under `[main]`.
- **Bad color0 / color8 contrast.** If `color0` ≈ pure black on a dark bg, or `color8` is too dark,
  `git status`, `ls` dirs, and dimmed/comment text disappear. Keep `color8` a readable muted gray.

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

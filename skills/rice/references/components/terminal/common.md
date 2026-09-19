# terminal - common

Cross-tool content for the `terminal` surface: what holds no matter which tool was picked.
Read this **plus** the one `tools/<your-tool>.md` the interview selected.

## Contents

- Template
- Validation
- Reload

---

## Template


Per-emulator recipes. Each emulator's main config holds the **look** (font family/size, opacity,
padding, cursor, decorations) and `include` / `source` / `import` / `require`s a separate
**colors file** that the rice engine renders from `palette.conf`. Re-theming only rewrites the
colors file; the main config stays palette-agnostic.

The colors file's exported variable names per emulator are the contract in
`_shared/colors-contract.md` (`background`, `foreground`, `cursor`, `selection_background`,
`selection_foreground`, `color0..color15`). The kitty template (`references/components/terminal/kitty.tmpl`) is the
canonical shape — alacritty/foot/wezterm/ghostty mirror the same 16-color mapping in their native
formats.

The `{{font_mono}}` / `{{bg}}` / `{{fg}}` / `{{cursor}}` / `{{color0..15}}` placeholders below
resolve to keys in `palette.conf` (`_shared/palette-schema.md`); the integer-typed `{{opacity}}`,
`{{padding}}`, `{{font_size}}` come from `answers.json` (`terminal.*`).

The `{{cursor.shape_capitalized}}`, `{{cursor.wezterm_style}}`, `{{cursor.ghostty_style}}` are
derived by the writer from `terminal.cursor.shape` + `terminal.cursor.blink` (see `schema.md`
for the full per-emulator mapping). E.g. `shape=beam, blink=true` resolves to alacritty
`"Beam"`, wezterm `'BlinkingBar'`, ghostty `bar`.

## Cross-references

- Colors-file variable names → `../../_shared/colors-contract.md`
- Palette source keys → `../../_shared/palette-schema.md`
- Engine render manifest line shape → `../../theming/engine.md`
- The design knobs (palette, fonts, padding, opacity/blur, decorations) → `styling.md`
- The `$terminal` variables line in `hyprland.conf` → `../keybinds/template.md`
- `enable_swallow` + `swallow_regex` lines → `../look-feel/template.md`

---

## Styling


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

# a Nerd Font, e.g. JetBrainsMono Nerd Font
font_family            {{font_mono}}
font_size              11.0

background_opacity     0.92
# pair with Hyprland decoration blur
background_blur        1
window_padding_width   12

cursor_shape           beam
cursor_blink_interval  0.5

# let Hyprland draw the border/gaps
hide_window_decorations yes
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

## Provenance

Citations for this file live at `.research/sources/components-terminal-styling.md` (repo root), kept out of
the load path on purpose. Read them when reviewing a recommendation, not when
authoring a config.

---

## Validation


Parse + sanity checks the writer (or `validate.sh`) runs on the emitted terminal configs
**before** the reload hook fires. kitty's parser is the strictest of the bunch — it reads
everything after the key as the value, so a trailing `# comment` on `background_blur 1` is
silently treated as part of the value and the setting goes inactive on every launch. That class
of defect is what these checks exist to catch.

## Cross-references

- The comment hazard itself → `gotchas.md` (kitty section).
- Per-emulator parser quirks → `template.md` per-emulator subsections.
- The contract between `kitty.conf` (look) and `colors.conf` (palette) → `template.md`,
  `../../_shared/colors-contract.md`.

---

## Gotchas


## Font **family** ≠ font **size** — keep them apart

The colors file (`colors.conf`, `colors.toml`, `colors.lua`, the `[colors]` block of `foot.ini`,
the `palette = …` lines of `ghostty/config`) holds **palette only**. It does **not** include
`font_family` and **does not** include `font_size`. Both font keys live in the emulator's main
config (`kitty.conf`, `alacritty.toml`, etc.) and are written **once** at generate-time.

Why this matters: re-theming runs `rice apply`, which rewrites the colors file and **only** the
colors file. If the colors file carried `font_size 11`, every re-theme would silently revert the
user's `font_size 13` edit. Treat the colors file as palette-pure; the main config owns sizing
and the family resolves from `fonts.mono` (group 13).

The contract is enforced by `_shared/colors-contract.md`: kitty's `colors.conf` exports exactly
`background foreground cursor selection_background selection_foreground color0..color15` — no
font keys, no opacity.

## Window-swallowing needs two ingredients

If the user picks `swallow` in `terminal.extras`, both lines have to land in
`look-feel/looknfeel.conf` (the **look-feel** component owns these — not this one):

```ini
misc {
    enable_swallow = true
    swallow_regex  = ^(<terminal-class>)$
}
```

The `<terminal-class>` map (from `hyprctl clients` on a running system):

| emulator | window class (regex literal) |
|---|---|
| kitty | `kitty` |
| alacritty | `Alacritty` |
| foot | `foot` |
| wezterm | `org.wezfurlong.wezterm` |
| ghostty | `com.mitchellh.ghostty` |

Missing the regex → swallowing never triggers (Hyprland has no class to match). Missing
`enable_swallow` → the regex is dead config. Both must ship together, gated on
`terminal.swallow == true`. See the **look-feel** component for the actual block.

## `$terminal` in `hyprland.conf` must match the chosen emulator

The variables block at the top of `hyprland.conf` declares `$terminal = <command>`. The
`keybinds` component's `bind = $mainMod, Return, exec, $terminal` line is the **only** path users
launch a new terminal — so if `terminal.emulator` is `alacritty` but `$terminal = kitty`, the bind
opens kitty and the rest of the rice (themed alacritty config, palette in `alacritty.toml`) is
invisible.

The rule: `terminal.emulator` from `answers.json` is the single source. The `hyprland`-component
writer reads it and emits `$terminal = <emulator>` verbatim (no aliases, no `$TERM`, no shell
wrappers).

## Alacritty TOML vs YAML history

Alacritty migrated from YAML to **TOML at 0.13** (Dec 2023). Stale copy-paste from old guides will
hand you `alacritty.yml` with snake_case nesting; current alacritty silently ignores it. The rice
template emits **TOML only** (`alacritty.toml`), and the install step warns if a pre-existing
`alacritty.yml` is detected alongside (offer to run `alacritty migrate`).

Other TOML-era gotchas worth flagging:
- `[cursor.style]` is `{ shape = "Beam", blinking = "On" }` (capitalized values: `Block`/
  `Underline`/`Beam` for shape, `Never`/`Off`/`On`/`Always` for blinking) — **not** under
  `[colors]` (a common port mistake).
- `transparent_background_colors = true` lives under **`[colors]`**, not `[window]`. It is
  required for `[window].opacity` to actually look transparent — without it, the theme's solid
  background paints every cell and opacity is dead. (alacritty/alacritty docs section is
  `[colors]`.)
- `[window].blur` is **macOS-only**; on Wayland the blur comes from Hyprland's decoration block,
  not alacritty. Don't waste a key on it.
- `import = [...]` and `live_config_reload = true` both live under the `[general]` table in
  ≥0.13, not at the top level. The 0.13 release was 2023-12-27 (`alacritty/alacritty` v0.13.0).
- `[font] size` is typed `<float>`; render integer answers as `11.0` (not `11`) so strict TOML
  parses without an `invalid type: integer` error.
- Per-terminal shell override lives at `[terminal] shell = "/usr/bin/fish"` or
  `[terminal] shell = { program = "/usr/bin/fish", args = ["-l"] }`.

## Opacity below ~0.8 is unreadable

The interview offers `1.0` / `0.95` / `0.85` / custom. The validator warns if the user types a
custom value below `0.7` — over a busy wallpaper, text legibility collapses. See
`styling.md` "Pitfalls" for the full reasoning. If the user insists, write the value and move on
(the warning is non-blocking).

## Per-emulator `shell` directive vs `chsh`

Each emulator has its own way of overriding the user's login shell. Rice writes **none of these
by default** — `chsh` is the source of truth and the per-emulator overrides exist only as
opt-ins for users who want, say, fish in their terminal and bash everywhere else.

| Emulator | Directive | Default behaviour |
|---|---|---|
| kitty | `shell /usr/bin/fish` (top-level kitty.conf) | `shell .` → `$SHELL` or login shell |
| alacritty | `[terminal] shell = "/usr/bin/fish"` or `{ program = "...", args = [...] }` | uses `$SHELL` |
| foot | `shell=/usr/bin/fish` (top-level / `[main]`) | uses `$SHELL` or login shell |
| wezterm | `config.default_prog = { '/usr/bin/fish', '-l' }` | uses login shell |
| ghostty | `command = /usr/bin/fish` | uses login shell |

## btop `_mid` empty for 2-stop fades is documented

The plugin's `btop.tmpl` covers all 42 upstream theme keys (verified against
`aristocratos/btop/main/themes/dracula.theme`). For 2-stop fades, leaving the optional `_mid`
as `""` is the documented idiom — upstream themes use it. Example pattern:
`theme[cached_start]="#X" theme[cached_mid]="" theme[cached_end]="#Y"` produces a clean linear
fade between X and Y without a forced midpoint hue. ML4W's `dotfiles/.config/matugen/templates/
btop.theme` is the corroborating community reference; v0.13.1-research added the missing
`cached_*`, `available_*`, `download_*`, `upload_*`, `process_*` meter gradients.

## cava 8 gradient stops vs 6

Cava's `[color]` block supports `gradient_color_1..8` (eight stops). The previous `cava.tmpl`
populated only 1..6, leaving 7 and 8 empty, which made cava fall back to a hardcoded
green→red gradient for the last 25% of the bar height — visible on tall bars and very visible
when the bar isn't dominated by green/red. Both HyDE (`Wall-Ways/cava.dcol`) and JaKooLit
(`wallust/templates/colors-cava`) use all 8 stops; v0.13.1-research extended the .tmpl to match.
`gradient_count = 8` is set explicitly so cava reads exactly 8 stops.

## Version branch — none today

No Hyprland-version cliffs touch this component's templates (the swallow keys have been stable
since 0.30). See `_shared/version-matrix.md` for the cliffs other components branch on; nothing
here on the terminal side.

---

## Reload


Terminal config changes apply to **newly-launched terminal windows only**. There is no signal
broadcast that reliably re-renders a running shell session's font/opacity/palette across every
emulator, and rice does **not** try to fake one.

## Reload scope

| Surface | New terminals | Already-open terminals |
|---|---|---|
| Font family / size | applied | unchanged until restart |
| Background opacity | applied | unchanged until restart |
| Padding | applied | unchanged until restart |
| Cursor shape / blink | applied | unchanged until restart |
| 16-color palette | applied | **see below** |

The 16-color palette is the one knob some emulators **can** push to running sessions, but
behaviour varies enough that rice's default flow is "next window picks it up." Per-emulator
specifics:

| Emulator | Live-reload mechanism | rice behaviour |
|---|---|---|
| kitty | `kill -SIGUSR1 $KITTY_PID` reloads `kitty.conf`; or `kitten @ load-config`. Modern kitty also auto-reloads on save (controlled by the `auto_reload_config` option). | rice **does not** send `SIGUSR1` by default. New terminals pick up the new colors. |
| alacritty | `live_config_reload = true` (default) — re-reads on file save. | Live in already-open windows after save. No action required from rice. |
| foot | **No config-reload signal.** `SIGUSR1` switches to `[colors-dark]` and `SIGUSR2` to `[colors-light]` — both swap **between existing color blocks**, not reload the file from disk. For other key changes, restart. | rice does not send any signal. To live-swap themes, ship dual `[colors-dark]` / `[colors-light]` blocks and use `kill -SIGUSR1/2 $(pidof foot)`. |
| wezterm | `automatically_reload_config = true` (default). | Live in already-open windows on save. |
| ghostty | `ctrl+shift+,` in-app reload; otherwise restart. | New windows pick it up. |

The intentional default is **passive**: write the file, do nothing. The user's existing terminals
keep their old colors until they close, the new ones come up with the rice palette. Two reasons:

1. **No risk of broken state.** Sending `SIGUSR1` to kitty while it's mid-prompt or attached to
   `tmux` is safe in practice, but inconsistent across versions — kitty 0.30+ handles it cleanly,
   older builds occasionally corrupt the scrollback. Skipping the signal avoids the failure mode.
2. **Convergence is automatic.** Users close and reopen terminals constantly. Within a session or
   two the new theme is universal — without any extra step from rice and without the chance of
   touching an unrelated process.

If a user **wants** the immediate reload, the manual command is documented per emulator in
`styling.md` ("How colors are set" table). For kitty specifically:

```bash
kill -SIGUSR1 $(pidof kitty)        # blanket reload all kitty instances
# or, in a single kitty window:
#   ctrl+shift+f5
```

## What rice **does** do on `rice apply`

1. Renders the colors file (`~/.config/<emulator>/colors.<ext>` or the `[colors]` block of
   `foot.ini`).
2. Writes the emulator's main config (`kitty.conf` / `alacritty.toml` / `foot.ini` /
   `wezterm.lua` / `ghostty/config`) **only on first generate** — `rice apply` for re-theming
   touches the colors file only (engine guarantee, see `theming/engine.md`).
3. Logs `# terminal: new windows will pick up the new palette` and moves on.

## Failure modes

- **Stale running shell.** Expected — see above. Not an error.
- **Colors file missing.** The main config's `include colors.conf` / `import` / `require` line
  fails the emulator's own parse on next launch (kitty/foot/wezterm complain in stderr;
  alacritty/ghostty silently fall back to defaults). The validator checks the include target
  exists at generate-time.
- **Palette key mismatch.** If a renamed `_shared/colors-contract.md` variable lands without the
  matching template update, the emulator config either errors (alacritty's strict TOML) or
  silently un-themes (kitty drops unknown lines). Caught by `_shared/colors-contract.md` being
  the single source.

## Cross-references

- Engine reload-hook discipline → `theming/engine.md`
- Per-emulator live-reload UX → `styling.md` "How colors are set"
- Other components' reload behaviour → `components/<x>/reload.md`


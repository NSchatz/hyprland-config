# terminal — template

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

## kitty — `~/.config/kitty/kitty.conf` (+ `colors.conf`)

```conf
include colors.conf

font_family            {{font_mono}}
font_size              {{font_size}}

background_opacity     {{opacity}}
background_blur        1                 # pair with Hyprland decoration blur
window_padding_width   {{padding}}

cursor_shape           {{cursor.shape}}
{{#if cursor.blink}}cursor_blink_interval  0.5
cursor_stop_blinking_after  1{{else}}cursor_blink_interval  0{{/if}}    # seconds; supports CSS easing per upstream docs

hide_window_decorations yes                    # yes | no | titlebar-only | titlebar-and-corners

# Tab bar — the recipe ships powerline + slanted because the colors.conf chrome
# (active_tab_*/inactive_tab_*/tab_bar_background) is wired specifically for it.
# Set `tab_bar_style hidden` to suppress the strip; the colors are then unused but harmless.
tab_bar_style          powerline               # fade | slant | separator | powerline | hidden | custom
tab_powerline_style    slanted                 # angled | round | slanted (community default)
tab_bar_min_tabs       2                       # hide strip until a second tab opens (Matt-FTW, Dank)

{{#if extras.no-confirm-close}}confirm_os_window_close 0{{/if}}     # 0 = never confirm; >0 = confirm if N+ children alive
{{#if extras.bell-off}}enable_audio_bell      no{{/if}}             # yes | no
{{#if extras.scrollback-10k}}scrollback_lines       10000{{/if}}    # int; default 2000
{{#if extras.ligatures}}disable_ligatures      never{{else}}disable_ligatures      always{{/if}}  # never | cursor | always

# Optional: kitty has a `shell` directive (default `.` = $SHELL). Rice does not write it —
# the user's chsh / login shell wins. Set explicitly only if the user picks a per-terminal
# override:  shell /usr/bin/fish
```

`~/.config/kitty/colors.conf` — see `references/components/terminal/kitty.tmpl` (rendered from `palette.conf`).
The colors file exports the 16 ANSI cells **plus** the kitty chrome slots that fall back to
hardcoded gray defaults (`cursor_text_color`, `url_color`, `active_tab_*`, `inactive_tab_*`,
`tab_bar_background`, `active_border_color`, `inactive_border_color`, `bell_border_color`) —
see `styling.md` "Chrome that needs theming if it's shown" for the full table.

## alacritty — `~/.config/alacritty/alacritty.toml` (+ `colors.toml`)

```toml
[general]
import = ["~/.config/alacritty/colors.toml"]
live_config_reload = true

[font]
normal = { family = "{{font_mono}}" }
size   = {{font_size}}.0    # schema is <float>; render `11` as `11.0` so strict TOML accepts it

[window]
opacity                     = {{opacity}}
padding                     = { x = {{padding}}, y = {{padding}} }
decorations                 = "None"

[colors]
# Required for `[window].opacity` to actually show through cell backgrounds.
transparent_background_colors = true

[cursor.style]
shape    = "{{cursor.shape_capitalized}}"     # "Block" | "Underline" | "Beam"
blinking = "{{#if cursor.blink}}On{{else}}Off{{/if}}"  # "Never" | "Off" | "On" | "Always"

[scrolling]
{{#if extras.scrollback-10k}}history = 10000{{/if}}

[bell]
# `command = "None"` is the documented sentinel for "no command" (default).
{{#if extras.bell-off}}command = "None"{{/if}}
```

`~/.config/alacritty/colors.toml` — `[colors.primary]`, `[colors.cursor]`, `[colors.normal]`,
`[colors.bright]` (the rice engine fills these from the 16-color palette).

## foot — `~/.config/foot/foot.ini` (colors merged in)

foot **does** support `include=<abs path>` (top-level / [main]; absolute path or `~/`-prefixed,
nested imports OK — see `foot.ini(5)`). However the rice engine still **merges** the `[colors]`
block into `foot.ini` in-place (similar to `mako`/`fuzzel`) so that dual `[colors-dark]` /
`[colors-light]` blocks can coexist with the rest of the user's edits without an extra file.
Hex is bare `RRGGBB`, **no `#`**.

Important: `alpha=` and `blur=` are **colors-section keys**, NOT `[main]` keys. Per
`foot.ini(5)` they're documented under `[colors-dark]` / `[colors-light]` (or the legacy single
`[colors]`). Putting them in `[main]` silently no-ops — foot drops unknown top-level keys
without a warning. See `gotchas.md` "foot `alpha` and `blur` live in `[colors-*]`."

```ini
# Top-level `key=value` pairs live in the implicit [main] section.
font={{font_mono}}:size={{font_size}}
pad={{padding}}x{{padding}} center
# dpi-aware=no honors the literal font size= on fractional-scaled outputs (end-4 default).
dpi-aware=no
# Keep bold text in the regular palette instead of jumping to bright (catppuccin discipline).
bold-text-in-bright=no

[scrollback]
{{#if extras.scrollback-10k}}lines=10000{{/if}}

[cursor]
style={{cursor.shape}}            # block | beam | underline | hollow
{{#if cursor.blink}}blink=yes{{else}}blink=no{{/if}}

[bell]
# foot has no `bell=none` under [main]; bell lives in its own section.
{{#if extras.bell-off}}system=no
urgent=no
visual=no{{/if}}

# Single-mode colors block. For dual light/dark, replace [colors] with two
# [colors-dark] / [colors-light] blocks, each carrying its own alpha= / blur=
# and palette (catppuccin/foot is the canonical example; fufexan/dotfiles
# foot.nix is the nix-managed worked example).
[colors]
alpha={{opacity}}
foreground={{fg}}
background={{bg}}
regular0={{color0}}  regular1={{color1}}  regular2={{color2}}  regular3={{color3}}
regular4={{color4}}  regular5={{color5}}  regular6={{color6}}  regular7={{color7}}
bright0={{color8}}   bright1={{color9}}   bright2={{color10}}  bright3={{color11}}
bright4={{color12}}  bright5={{color13}}  bright6={{color14}}  bright7={{color15}}
```

## wezterm — `~/.config/wezterm/wezterm.lua` (+ `colors.lua`)

```lua
local wezterm = require 'wezterm'
local colors  = require 'colors'   -- ~/.config/wezterm/colors.lua, rice-rendered
local config  = wezterm.config_builder()

config.font                          = wezterm.font('{{font_mono}}')
config.font_size                     = {{font_size}}
config.window_background_opacity     = {{opacity}}
config.text_background_opacity       = 1.0
config.window_padding                = { left = {{padding}}, right = {{padding}}, top = {{padding}}, bottom = {{padding}} }
config.window_decorations            = 'RESIZE'
config.hide_tab_bar_if_only_one_tab  = true
config.default_cursor_style          = '{{cursor.wezterm_style}}'   -- 'SteadyBlock' | 'BlinkingBlock' | 'SteadyBar' | …
config.audible_bell                  = '{{#if extras.bell-off}}Disabled{{else}}SystemBeep{{/if}}'
config.scrollback_lines              = {{#if extras.scrollback-10k}}10000{{else}}3500{{/if}}
config.colors                        = colors

return config
```

`~/.config/wezterm/colors.lua` returns a Lua table of `foreground`, `background`, `cursor_bg`,
`cursor_fg`, `cursor_border`, `selection_bg`, `selection_fg`, `ansi = { … 8 }`, `brights = { … 8 }`.

## ghostty — `~/.config/ghostty/config` (+ `theme = …` or `palette = N=#hex`)

```
font-family = {{font_mono}}
font-size = {{font_size}}

background-opacity = {{opacity}}
background-blur = 20                                     # integer = intensity; `true` aliases to 20, `false` to 0
window-padding-x = {{padding}}
window-padding-y = {{padding}}
window-decoration = none
# Catppuccin discipline — keep bold in the regular palette.
bold-is-bright = false

cursor-style = {{cursor.ghostty_style}}                 # block | bar | underline
cursor-style-blink = {{#if cursor.blink}}true{{else}}false{{/if}}

{{#if extras.bell-off}}audible-bell = false{{/if}}
{{#if extras.scrollback-10k}}scrollback-limit = 10000000{{/if}}      # bytes (≈10 MB ≈ many thousands of lines)
{{#if extras.no-confirm-close}}confirm-close-surface = false{{/if}}

# Theme indirection — the `?` prefix marks the include OPTIONAL (silently skipped if missing).
# This lets the rice engine drop a generated colors file in WITHOUT breaking the main config on
# first run. Per upstream: config-file is processed at the END of the current file, so any
# key the rice writes into ghostty-rice-palette.conf overrides what's set above. Pattern
# borrowed from JaKooLit/Hyprland-Dots config/ghostty/ghostty.config.
config-file = ?~/.config/ghostty/ghostty-rice-palette.conf
```

The included `ghostty-rice-palette.conf` is what the engine writes from `palette.conf`:

```
# Palette — 16 lines + foreground/background/cursor-color:
foreground = #{{fg}}
background = #{{bg}}
cursor-color = #{{cursor}}
selection-foreground = #{{bg}}
selection-background = #{{accent}}
palette = 0=#{{color0}}
palette = 1=#{{color1}}
# … palette = 2..15
```

ghostty also ships built-in named themes (`theme = catppuccin-mocha`, `theme = tokyonight`) and
supports light/dark auto-switch via `theme = light:catppuccin-latte,dark:catppuccin-mocha`; the
rice engine **prefers the explicit `palette = N=#hex` form** so wallpaper-generated and manual
palettes work the same as named schemes. Override individual cells without redefining the whole
palette via `palette = 5=#BB78D9` (documented in `ghostty.org/docs/config/reference`).

## Cross-references

- Colors-file variable names → `../../_shared/colors-contract.md`
- Palette source keys → `../../_shared/palette-schema.md`
- Engine render manifest line shape → `../../theming/engine.md`
- The design knobs (palette, fonts, padding, opacity/blur, decorations) → `styling.md`
- The `$terminal` variables line in `hyprland.conf` → `../keybinds/template.md`
- `enable_swallow` + `swallow_regex` lines → `../look-feel/template.md`

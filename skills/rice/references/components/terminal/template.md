# terminal — template

Per-emulator recipes. Each emulator's main config holds the **look** (font family/size, opacity,
padding, cursor, decorations) and `include` / `source` / `import` / `require`s a separate
**colors file** that the rice engine renders from `palette.conf`. Re-theming only rewrites the
colors file; the main config stays palette-agnostic.

The colors file's exported variable names per emulator are the contract in
`_shared/colors-contract.md` (`background`, `foreground`, `cursor`, `selection_background`,
`selection_foreground`, `color0..color15`). The kitty template (`templates/kitty.tmpl`) is the
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
{{#if cursor.blink}}cursor_blink_interval  0.5{{else}}cursor_blink_interval  0{{/if}}

hide_window_decorations yes                    # yes | no | titlebar-only | titlebar-and-corners
tab_bar_style          powerline               # fade | slant | separator | powerline | hidden | custom
{{#if extras.no-confirm-close}}confirm_os_window_close 0{{/if}}     # 0 = never confirm; >0 = confirm if N+ children alive
{{#if extras.bell-off}}enable_audio_bell      no{{/if}}             # yes | no
{{#if extras.scrollback-10k}}scrollback_lines       10000{{/if}}    # int; default 2000
{{#if extras.ligatures}}disable_ligatures      never{{else}}disable_ligatures      always{{/if}}  # never | cursor | always

# Optional: kitty has a `shell` directive (default `.` = $SHELL). Rice does not write it —
# the user's chsh / login shell wins. Set explicitly only if the user picks a per-terminal
# override:  shell /usr/bin/fish
```

`~/.config/kitty/colors.conf` — see `templates/kitty.tmpl` (rendered from `palette.conf`).

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

```ini
# Top-level `key=value` pairs live in the implicit [main] section.
font={{font_mono}}:size={{font_size}}
pad={{padding}}x{{padding}} center

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
background-blur = 20
window-padding-x = {{padding}}
window-padding-y = {{padding}}
window-decoration = none

cursor-style = {{cursor.ghostty_style}}                 # block | bar | underline
cursor-style-blink = {{#if cursor.blink}}true{{else}}false{{/if}}

{{#if extras.bell-off}}audible-bell = false{{/if}}
{{#if extras.scrollback-10k}}scrollback-limit = 10000000{{/if}}      # bytes (≈10 MB ≈ many thousands of lines)
{{#if extras.no-confirm-close}}confirm-close-surface = false{{/if}}

# Palette — rice fills these from palette.conf (16 lines + foreground/background/cursor-color):
foreground = #{{fg}}
background = #{{bg}}
cursor-color = #{{cursor}}
palette = 0=#{{color0}}
palette = 1=#{{color1}}
# … palette = 2..15
```

ghostty also ships built-in named themes (`theme = catppuccin-mocha`, `theme = tokyonight`); the
rice engine **prefers the explicit `palette = N=#hex` form** so wallpaper-generated and manual
palettes work the same as named schemes.

## Cross-references

- Colors-file variable names → `../../_shared/colors-contract.md`
- Palette source keys → `../../_shared/palette-schema.md`
- Engine render manifest line shape → `../../theming/engine.md`
- The design knobs (palette, fonts, padding, opacity/blur, decorations) → `styling.md`
- The `$terminal` variables line in `hyprland.conf` → `../keybinds/template.md`
- `enable_swallow` + `swallow_regex` lines → `../look-feel/template.md`

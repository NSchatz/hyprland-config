# wezterm - terminal

Everything this plugin knows about authoring **wezterm** for the `terminal` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template

---

## Template


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


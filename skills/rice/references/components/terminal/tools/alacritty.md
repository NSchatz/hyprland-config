# alacritty - terminal

Everything this plugin knows about authoring **alacritty** for the `terminal` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template
- Validation

---

## Template


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

---

## Validation


TOML (alacritty) and Lua (wezterm) tolerate trailing `# …` / `-- …` on value lines, so the
strict lint above does not apply. The kitty load-test, foot.ini lint, and ghostty lint cover the
comment-strict cases; alacritty/wezterm need only their normal TOML/Lua parse check.


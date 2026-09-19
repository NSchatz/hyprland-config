# ghostty - terminal

Everything this plugin knows about authoring **ghostty** for the `terminal` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template
- Validation
- Gotchas

---

## Template


```
font-family = {{font_mono}}
font-size = {{font_size}}

background-opacity = {{opacity}}
# integer = intensity; `true` aliases to 20, `false` to 0
background-blur = 20
window-padding-x = {{padding}}
window-padding-y = {{padding}}
window-decoration = none
# Catppuccin discipline — keep bold in the regular palette.
bold-is-bright = false

# block | bar | underline
cursor-style = {{cursor.ghostty_style}}
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

---

## Validation


Ghostty's documented rule (`ghostty.org/docs/config`) is *"Comments must be on their own line.
Comments cannot be at the end of a line containing a configuration setting."* Same lint shape:

```bash
if grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*=[^#]*[[:space:]]+#' \
     "$HOME/.config/ghostty/config"; then
  echo "ERROR: ghostty config has trailing inline comments on setting lines" >&2
  exit 1
fi
```

---

## Gotchas


Per `ghostty.org/docs/config`: *"If the value is prefixed with `?`, the file is optional and if it
doesn't exist, it is ignored."* This is the cleanest theme-indirection mechanism in ghostty —
JaKooLit's `config/ghostty/ghostty.config` ends with `config-file = ?~/.config/ghostty/theme.conf`
and `config-file = ?~/.config/ghostty/wallust.conf`, so the engine can write either or both
without ever breaking the main config when nothing's there yet.

Subtle ordering footgun upstream calls out: *"config-file directives are processed at the
conclusion of the current file, meaning any keys appearing AFTER the config-file directive
won't override settings from the loaded file."* If the user has `background-opacity = 1.0`
followed by `config-file = ?colors.conf` where colors.conf sets `background-opacity = 0.9`, the
0.9 wins — the parent's `1.0` does NOT override. Recipes put `config-file` lines LAST when an
override is intended.

## ghostty `background-blur` accepts ints, true, and false

Per upstream reference: *"a nonnegative integer specifying the blur intensity," "false (equivalent
to intensity 0)," "true (equivalent to default intensity 20)."* So `background-blur = 20`
(Matt-FTW), `background-blur = true`, and `background-blur-radius = 60` (JaKooLit, deprecated
alias) are all equivalent or near-equivalent. The macOS extras (`macos-glass-regular`,
`macos-glass-clear`) are platform-only and irrelevant on Hyprland.


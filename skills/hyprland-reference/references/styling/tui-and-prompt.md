# Styling TUI Tools & the Shell Prompt (btop · cava · fastfetch · starship)

These tools live *inside* the terminal emulator, so they inherit its font and 16-color
palette by default — but each also ships its own theme/config file that can override colors
independently. A **Nerd Font** (e.g. JetBrainsMono Nerd Font, FiraCode Nerd Font) is mandatory:
btop braille graphs, cava is plain bars, but fastfetch logos, starship powerline separators, and
every module symbol are Nerd Font glyphs that render as tofu (□) without one. Style these together
and the terminal side of the rice reads as one piece.

## What you're styling

| Tool | Config file + format | How color is set | Reload |
|------|----------------------|------------------|--------|
| **btop** | `~/.config/btop/btop.conf` (INI) + `~/.config/btop/themes/<name>.theme` | `.theme` file of `theme[key]="#hex"` lines; selected via `color_theme` in `btop.conf` | Restart btop, or press `Esc → Options → color_theme` (live) |
| **cava** | `~/.config/cava/config` (INI sections) | `[color]` block: `foreground`, `background`, `gradient_color_1..8` | Restart cava (`q` then relaunch); some builds reload on config save |
| **fastfetch** | `~/.config/fastfetch/config.jsonc` (JSONC) | `display.color`, per-module `keyColor`, `logo.color` | Re-run `fastfetch` (it runs on shell start) |
| **starship** | `~/.config/starship.toml` (TOML) | `palette` + `[palettes.x]` table; module `style`/`format` | Instant — new prompt on next command (re-source not needed) |

Generate starting points: `fastfetch --gen-config`, `starship preset <name> -o ~/.config/starship.toml`,
copy `btop`'s default theme from `/usr/share/btop/themes/`, and `cava`'s example from
`/usr/share/doc/cava/example_files/config` (or the repo `example_files/config`).

## Design anatomy — the knobs that change the look

### btop (`.theme` file)
A theme is flat `theme[key]="#rrggbb"` lines. The look-defining keys:

- **Surface:** `theme[main_bg]` (box background — leave empty `""` to use the terminal's bg, important for transparency), `theme[main_fg]` (default text), `theme[title]`, `theme[hi_fg]` (highlighted shortcut letters), `theme[selected_bg]`/`theme[selected_fg]`, `theme[inactive_fg]`, `theme[div_line]` (dividers).
- **Box outlines (accent placement):** `theme[cpu_box]`, `theme[mem_box]`, `theme[net_box]`, `theme[proc_box]`, `theme[meter_bg]`, `theme[proc_misc]`.
- **Graph gradients (3-stop):** each metric takes `_start`, `_mid`, `_end`. `theme[temp_start/mid/end]` (cold→hot, classic green→yellow→red), `theme[cpu_start/mid/end]`, `theme[free_/cached_/available_/used_start..end]` (memory meters), `theme[download_/upload_start..end]` (net), `theme[process_start/mid/end]`. Give a stop only `_start` and `_end` for a 2-color gradient; add `_mid` for 3.

In `btop.conf` the visual knobs are `color_theme = "<name>"` (must match the `.theme` filename without extension), `theme_background = False` (let terminal bg show through), `rounded_corners = True`, and `graph_symbol = "braille"` (vs `block`/`tty`) which sets the dot density of the graphs.

### cava (`config`)
The `[color]` section is the whole show:

- `gradient = 1` **enables** the multi-stop gradient (off by default — without it cava uses the single `foreground` color).
- `gradient_color_1` … `gradient_color_8` are ordered **low bar → high bar**. Classic default runs green→yellow→orange→red; for a rice, run your `accent → accent2` so the spectrum analyzer is an eye-catcher in your scheme.
- `foreground` / `background` accept `'default'` (inherit terminal) or `'#hex'`. Set `background = default` to stay transparent over your terminal/wallpaper.

`[general]` shapes the bars: `framerate = 60`, `bar_width = 2`, `bar_spacing = 1`, `bars` (0 = auto-fit). `[output]` `method = noncurses` and `channels = stereo` are typical.

### fastfetch (`config.jsonc`)
Three things define the look — logo, key/title colors, and which modules:

- **Logo:** `logo.type` is `builtin` (distro ASCII art, auto-colored), `file`/`data` (your own ASCII with `$1..$9` color placeholders), or an **image** via `kitty`/`kitty-direct`/`sixel`/`chafa`. `logo.source` is the distro name or image path; `logo.color` overrides the `$1`/`$2` placeholders; `logo.padding.right` spaces it from the text.
- **Accent keys:** `display.color.keys` and `display.color.title` set global key/title color; per-module `keyColor` overrides one row. Point these at your accent. `display.separator` (default `": "`) sits between key and value.
- **Modules:** the `modules` array mixes bare strings (`"title"`, `"os"`, `"kernel"`) and objects (`{ "type": "cpu", "key": "  CPU", "keyColor": "blue" }`). Prefix keys with a Nerd Font glyph for the iconified look. A `"separator"` (or `"break"`) module draws a divider row.

Color values accept named (`"blue"`, `"red"`, `"bright_magenta"`), palette indices (`"1"`–`"9"`), or raw SGR like `"38;2;137;180;250"` for true-color hex.

### starship (`starship.toml`)
- **`palette = "rice"`** selects one `[palettes.rice]` table that maps friendly names (`accent`, `red`, `bg`…) to hex. Define palettes *below* the `palette =` line. This is the single point of recoloring.
- **Module `format` + `symbol`:** every module has a `symbol` (a Nerd Font glyph, e.g. `git_branch.symbol = ""`) and a `format` template referencing `$symbol`, `$path`, etc., wrapped in `[...](style)` where style is `fg:x bg:y bold`.
- **Powerline vs plain:** the top-level `format` strings the modules together. Powerline presets emit ``/`` separators with each segment's `bg` becoming the next segment's `fg` (`[](bg:peach fg:red)`), producing the solid colored-block prompt. A minimal two-line prompt skips separators and ends with `$line_break$character`.
- **Right side & symbols:** `right_format` for a right-aligned clock; `[character]` sets the `success_symbol`/`error_symbol` (`❯`, `✗`, or Nerd glyphs).

## How the community styles it

The dominant idiom is **everything matches one scheme**: btop, cava, fastfetch, and starship all
flavored the same (Catppuccin Mocha is the default reach, then Gruvbox, Nord, Tokyo Night). Every
one of these tools has a first-party **Catppuccin port** that ships a ready theme file:
[catppuccin/btop](https://github.com/catppuccin/btop) (drop `.theme` files in `themes/`, set
`color_theme`), [catppuccin/cava](https://github.com/catppuccin/cava) (paste a `themes/<flavor>.cava`
`[color]` block, including `-transparent` variants), and
[catppuccin/starship](https://github.com/catppuccin/starship) (a palette TOML you `import`).

Concrete idioms:
- **cava gradient as the accent showcase** — people run `gradient_color_1..8` straight across their
  accent ramp (e.g. mauve→pink→peach) so the visualizer is the loudest splash of scheme color on screen.
- **fastfetch with a colored ASCII distro logo** (`logo.type = builtin`) and `keyColor`/`display.color.keys`
  set to the accent — or a **kitty-protocol image** of the wallpaper/a custom logo next to accent-colored keys.
- **starship powerline presets** are the popular ready-mades: `starship preset catppuccin-powerline`
  and `starship preset gruvbox-rainbow` (the powerline preset is gruvbox-rainbow restyled with the
  Catppuccin palette), plus `tokyo-night`, `pastel-powerline`, `nerd-font-symbols`. Minimalists run a
  plain **two-line** prompt (path + `❯`) with just an accent on the character.

Whole-desktop dotfile projects wire these into their theme switcher so the prompt and fetch recolor
with the wallpaper: **HyDE** (Hyprland, 70+ themes, retheming starship/fastfetch/btop), **ml4w**
(wallpaper-driven palette across starship + fastfetch + mako), and **caelestia** (fish + starship +
fastfetch). The plugin's own rice engine plays the same role — palette keys feed every file below.

## Tasteful default recipe

Palette-driven. Replace `{{key}}` with your rice palette
(`bg fg accent accent2 red green yellow blue magenta cyan color0..15`, all hex without `#` unless shown).
A Catppuccin **Mocha** worked example follows each (accent = mauve `#cba6f7`, accent2 = pink `#f5c2e7`).

### btop — `~/.config/btop/themes/rice.theme`
```ini
# rice.theme — palette-driven
theme[main_bg]="#{{bg}}"
theme[main_fg]="#{{fg}}"
theme[title]="#{{fg}}"
theme[hi_fg]="#{{accent}}"
theme[selected_bg]="#{{color8}}"
theme[selected_fg]="#{{accent}}"
theme[inactive_fg]="#{{color8}}"
theme[graph_text]="#{{fg}}"
theme[meter_bg]="#{{color8}}"
theme[proc_misc]="#{{accent2}}"
theme[cpu_box]="#{{accent}}"
theme[mem_box]="#{{green}}"
theme[net_box]="#{{magenta}}"
theme[proc_box]="#{{blue}}"
theme[div_line]="#{{color8}}"
# CPU + temp gradients (cool -> warn -> hot)
theme[temp_start]="#{{green}}"
theme[temp_mid]="#{{yellow}}"
theme[temp_end]="#{{red}}"
theme[cpu_start]="#{{accent}}"
theme[cpu_mid]="#{{accent2}}"
theme[cpu_end]="#{{red}}"
theme[free_start]="#{{green}}"
theme[free_mid]=""
theme[free_end]="#{{green}}"
theme[used_start]="#{{accent}}"
theme[used_mid]="#{{accent2}}"
theme[used_end]="#{{red}}"
theme[download_start]="#{{blue}}"
theme[download_mid]="#{{accent}}"
theme[download_end]="#{{magenta}}"
theme[upload_start]="#{{green}}"
theme[upload_mid]="#{{yellow}}"
theme[upload_end]="#{{red}}"
theme[process_start]="#{{accent}}"
theme[process_mid]="#{{accent2}}"
theme[process_end]="#{{red}}"
```
Then in `~/.config/btop/btop.conf`: `color_theme = "rice"`, `theme_background = False`,
`rounded_corners = True`, `graph_symbol = "braille"`.
*(Mocha example: `main_bg="#1e1e2e"`, `main_fg="#cdd6f4"`, `hi_fg="#cba6f7"`, `cpu_box="#cba6f7"`, `div_line="#45475a"`, `temp_start/mid/end="#a6e3a1"/"#f9e2af"/"#f38ba8"`.)*

### cava — `[color]` block in `~/.config/cava/config`
```ini
[general]
framerate = 60
bar_width = 2
bar_spacing = 1

[output]
method = noncurses
channels = stereo

[color]
background = default
foreground = '#{{accent}}'
gradient = 1
gradient_color_1 = '#{{accent}}'
gradient_color_2 = '#{{accent2}}'
gradient_color_3 = '#{{magenta}}'
gradient_color_4 = '#{{red}}'
gradient_color_5 = '#{{yellow}}'
gradient_color_6 = '#{{green}}'
gradient_color_7 = '#{{cyan}}'
gradient_color_8 = '#{{blue}}'
```
*(Mocha example: `gradient_color_1='#cba6f7'` … `_2='#f5c2e7'` … `_4='#f38ba8'` … `_8='#89b4fa'`, `background = default` to stay transparent.)*

### fastfetch — `~/.config/fastfetch/config.jsonc`
```jsonc
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "builtin",
    "source": "arch",
    "color": { "1": "magenta", "2": "blue" },
    "padding": { "top": 1, "right": 3 }
  },
  "display": {
    "separator": "  ",
    "color": { "keys": "magenta", "title": "magenta" }
  },
  "modules": [
    "title",
    "separator",
    { "type": "os",       "key": "  OS",     "keyColor": "magenta" },
    { "type": "kernel",   "key": "  Kernel", "keyColor": "magenta" },
    { "type": "wm",       "key": "  WM",     "keyColor": "magenta" },
    { "type": "shell",    "key": "  Shell",  "keyColor": "magenta" },
    { "type": "terminal", "key": "  Term",   "keyColor": "magenta" },
    { "type": "cpu",      "key": "  CPU",    "keyColor": "magenta" },
    { "type": "memory",   "key": "  RAM",    "keyColor": "magenta" },
    "break",
    { "type": "colors", "symbol": "circle" }
  ]
}
```
`keyColor`/`display.color.keys` is your accent. For an image logo instead:
`"logo": { "type": "kitty", "source": "~/.config/fastfetch/logo.png", "width": 30, "height": 15 }`
(needs a kitty-graphics-capable terminal — kitty, ghostty, wezterm, Konsole). For true-color hex
keys without a 16-color slot, use a raw SGR string, e.g. `"keyColor": "38;2;203;166;247"`.

### starship — `~/.config/starship.toml`
```toml
add_newline = false
palette = "rice"

[palettes.rice]
bg      = "#{{bg}}"
fg      = "#{{fg}}"
accent  = "#{{accent}}"
accent2 = "#{{accent2}}"
red     = "#{{red}}"
green   = "#{{green}}"
yellow  = "#{{yellow}}"
blue    = "#{{blue}}"

# Clean powerline: dir -> git -> lang -> two-line character
format = """
[](accent)\
$directory\
[](bg:accent2 fg:accent)\
$git_branch$git_status\
[](bg:bg fg:accent2)\
$python$nodejs$rust$golang\
[ ](fg:bg)\
$cmd_duration\
$line_break\
$character"""

[directory]
style = "fg:bg bg:accent"
format = "[ $path ]($style)"
truncation_length = 3

[git_branch]
symbol = ""
style = "fg:bg bg:accent2"
format = "[ $symbol $branch ]($style)"

[git_status]
style = "fg:bg bg:accent2"
format = "[$all_status$ahead_behind ]($style)"

[cmd_duration]
format = "[  $duration ](fg:yellow)"

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"
```
*(Mocha example: `accent = "#cba6f7"`, `accent2 = "#f5c2e7"`, `bg = "#1e1e2e"`, `fg = "#cdd6f4"`. Or just `starship preset catppuccin-powerline -o ~/.config/starship.toml`.)*

**Font requirement:** point your terminal's `font_mono`/`font` at a Nerd Font
(`JetBrainsMono Nerd Font`, `FiraCode Nerd Font`, `CaskaydiaCove Nerd Font`). All glyphs above
(``, ``, ``, ``, powerline `/`) depend on it.

## Pitfalls

- **No Nerd Font → broken glyphs.** Missing icons (□/▯) and mangled powerline separators are
  almost always a non-Nerd terminal font. Fix the terminal `font_mono`, not the tool config.
- **btop theme not applying.** The `color_theme` value must exactly match the `.theme` filename
  (minus extension) *and* the file must live in `~/.config/btop/themes/`. Built-in themes need no
  path; custom ones do. Verify via `Esc → Options`.
- **cava gradient ignored.** You set `gradient_color_*` but forgot `gradient = 1` — without it cava
  uses only `foreground`. Colors must be quoted `'#hex'` and ordered low→high (1→8).
- **fastfetch image logo shows nothing / falls back to ASCII.** `kitty`/`sixel` need a terminal that
  supports the protocol; over SSH or in a plain VTE terminal it silently degrades. Use `chafa` (ASCII
  approximation) or a `builtin` logo as a portable fallback.
- **starship feels laggy.** Slow modules block the prompt — disable VCS-heavy or network modules you
  don't need (`[gcloud] disabled = true`, `[aws] disabled = true`), and `command_timeout` guards hangs.
- **Pure-black btop background over a transparent terminal looks wrong.** If your terminal is
  transparent/blurred, a solid `theme[main_bg]` paints an opaque rectangle. Set `theme[main_bg]=""`
  and `theme_background = False` so the wallpaper/blur shows through — or match `main_bg` to your
  terminal's exact bg so it's seamless. Same logic for cava `background = default`.

## Sources

- btop themes — [catppuccin/btop](https://github.com/catppuccin/btop), [themes dir](https://github.com/catppuccin/btop/tree/main/themes), [README](https://github.com/catppuccin/btop/blob/main/README.md), [lokesh-krishna/catppuccin-btop theme](https://github.com/lokesh-krishna/catppuccin-btop/blob/main/catppuccin.theme)
- cava config — [karlstav/cava example config](https://raw.githubusercontent.com/karlstav/cava/master/example_files/config), [catppuccin/cava](https://github.com/catppuccin/cava), [cava README](https://github.com/catppuccin/cava/blob/main/README.md)
- fastfetch — [Configuration wiki](https://github.com/fastfetch-cli/fastfetch/wiki/Configuration), [Logo options wiki](https://github.com/fastfetch-cli/fastfetch/wiki/Logo-options), [fastfetch(1) man page](https://man.archlinux.org/man/extra/fastfetch/fastfetch.1.en)
- starship — [Catppuccin Powerline preset](https://starship.rs/presets/catppuccin-powerline), [Gruvbox Rainbow preset](https://starship.rs/presets/gruvbox-rainbow), [Presets index](https://starship.rs/presets/), [catppuccin/starship](https://github.com/catppuccin/starship)
- distro dotfiles — [HyDE](https://github.com/HyDE-Project/HyDE), [ml4w-dotfiles](https://gitlab.com/xeroxero8x/ml4w-dotfiles), [caelestia-dots/fish](https://github.com/caelestia-dots/fish), [It's FOSS: best Hyprland dotfiles](https://itsfoss.com/best-hyprland-dotfiles/)

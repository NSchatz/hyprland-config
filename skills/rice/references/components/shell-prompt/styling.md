# Styling TUI Tools & the Shell Prompt (btop · cava · fastfetch · starship · oh-my-posh · fish)

These tools live *inside* the terminal emulator, so they inherit its font and 16-color
palette by default — but each also ships its own theme/config file that can override colors
independently. A **Nerd Font** (e.g. JetBrainsMono Nerd Font, FiraCode Nerd Font) is mandatory:
btop braille graphs, cava is plain bars, but fastfetch logos, the powerline separators of starship
and oh-my-posh, and every module symbol are Nerd Font glyphs that render as tofu (□) without one.
Style these together and the terminal side of the rice reads as one piece.

The **prompt** is its own surface: starship and **oh-my-posh** are the two cross-shell engines (both
recolor from a single named *palette* block), while **fish** additionally themes its own *syntax
highlighting* via `fish_color_*` variables — independent of the prompt engine. zsh's powerlevel10k is
the zsh-only alternative.

## What you're styling

| Tool | Config file + format | How color is set | Reload |
|------|----------------------|------------------|--------|
| **btop** | `~/.config/btop/btop.conf` (INI) + `~/.config/btop/themes/<name>.theme` | `.theme` file of `theme[key]="#hex"` lines; selected via `color_theme` in `btop.conf` | Restart btop, or press `Esc → Options → color_theme` (live) |
| **cava** | `~/.config/cava/config` (INI sections) | `[color]` block: `foreground`, `background`, `gradient_color_1..8` | Restart cava (`q` then relaunch); some builds reload on config save |
| **fastfetch** | `~/.config/fastfetch/config.jsonc` (JSONC) | `display.color`, per-module `keyColor`, `logo.color` | Re-run `fastfetch` (it runs on shell start) |
| **starship** | `~/.config/starship.toml` (TOML) | `palette` + `[palettes.x]` table; module `style`/`format` | Instant — new prompt on next command (re-source not needed) |
| **oh-my-posh** | a theme `*.omp.json`/`.toml`/`.yaml` (init `--config`) | top-level `palette` of named colors referenced as `p:name`; per-segment `foreground`/`background` + `*_templates` | Instant — re-evaluated each prompt |
| **fish** (colors) | universal/global `fish_color_*` vars; or a `~/.config/fish/themes/<name>.theme` | `set -g fish_color_command <hex>` etc., or `fish_config theme choose <name>` | Instant in new shells; `set -g` re-applies on re-source |

Generate starting points: `fastfetch --gen-config`, `starship preset <name> -o ~/.config/starship.toml`,
`oh-my-posh config export --output ~/.config/ohmyposh/rice.omp.json` (or pick a built-in with
`oh-my-posh init <shell> --config $(brew --prefix oh-my-posh)/themes/<name>.omp.json`),
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

### oh-my-posh (theme `*.omp.json`)
- **`palette` is the single recolor point** — a top-level `"palette": { "accent": "#hex", … }` of named colors; every segment references them as `"foreground": "p:accent"`. (`palettes` with a `template` switches between several palettes by shell/condition.) This is the oh-my-posh analogue of starship's `[palettes.rice]`.
- **Blocks → segments:** `blocks` are prompt rows (`"alignment": "left"`/`"right"`, `"newline": true` for a second line); each `segment` has a `type` (`path`, `git`, `text`, `os`, language modules…), a `style` (`plain`/`powerline`/`diamond`/`accordion`), and a `template` (Go template, e.g. `{{ .Path }}`, `{{ .HEAD }}`). `powerline` segments draw a `powerline_symbol` () between them, bleeding each segment's `background` into the next — the solid colored-block look.
- **Conditional color:** `foreground_templates`/`background_templates` are lists of Go-template expressions; the first non-empty result wins (`"{{ if gt .Code 0 }}p:red{{ end }}"` turns the prompt char red on a failed command). Color keywords: `transparent`, `foreground`, `background`, `parentForeground`, `accent`, plus hex/ANSI names/256-indices.
- **Wiring:** unlike starship there's no `include` — the whole theme is one file, pointed at via `oh-my-posh init <shell> --config <file>`. So a rice renders the *complete* theme (palette + segments) and the shell inits against it.

### fish (`fish_color_*` variables / `.theme` file)
- **Two independent layers:** the *prompt* (starship/oh-my-posh/tide/native `fish_prompt`) and fish's *syntax highlighting & pager* colors. The latter are ~25 `fish_color_*` vars set with `set -g fish_color_<role> <hex> [--bold|--underline|--background=<hex>]` (fish takes bare hex, no `#`). Roles that carry the look: `command` (the accent), `param`, `quote`, `keyword`, `redirection`, `operator`, `error` (red), `comment`/`autosuggestion` (muted), `selection`/`search_match` (a `--background=` highlight), plus prompt-side `cwd`/`user`/`host`. Pager: `fish_pager_color_prefix`/`_completion`/`_description`/`_selected_background`.
- **`.theme` files vs `conf.d`:** fish ships themes as `~/.config/fish/themes/<name>.theme` (plain `fish_color_command 89b4fa` lines, no prefix on the value), loaded with `fish_config theme choose <name>` (persists to universal vars) — good for hand-switching, but a re-rendering rice prefers a `conf.d/*.fish` snippet using `set -g` (auto-sourced every interactive start, so a re-render wins over the stale universal-variable store).
- **Pitfall — bare `set` updates the universal:** an explicit `set -g` in `conf.d` does win over a `set -U` (smaller scope wins per fish's scoping rules), but `set fish_color_command …` with no flag, when a universal already exists, *updates the universal* instead of creating a fresh global. Always write explicit `set -g` in the `conf.d` snippet; don't mix `.theme` choosing and `conf.d` snippets in one rice.

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

### Prompt archetypes seen across the corpus

Boiled down from the top-19 Hyprland rices that ship any kind of prompt config
(`/workspace/.research/corpus.md`):

| Archetype | Rices | Defining moves |
|---|---|---|
| **Minimal two-line** (`$directory $character`) | `dusklinux/dusky .config/starship.toml`, `flickowoa/dotfiles config/hypr/themes/base/starship.toml`, `basecamp/omarchy config/starship.toml` (one-line variant) | `add_newline = false`, `format = "$directory$character"`, `right_format` for git/duration so the cursor never moves; `command_timeout` on omarchy. |
| **Powerline pill segments** | `prasanthrangan/hyprdots Configs/.config/starship/powerline.toml`, the starship preset `gruvbox-rainbow` (cited by `ml4w` and `dusky`'s alt theme) | Each module is `[ $content ](fg:X bg:Y)`; `[](fg:prev_bg bg:next_bg)` separator bleeds bg→fg into the next pill; `bg` chained through `palette` colors so one palette swap recolors every segment. |
| **`right_format` firehose** | `caelestia-dots/caelestia starship.toml` (every language module pushed to right_format) | Left prompt stays at `$cmd_duration $hostname $character`; everything detective (git, lang versions, kube, aws, …) goes to `right_format` so the cursor sits at the end of the input line. |
| **Two-row newline omp** | `mylinuxforwork/dotfiles .config/ohmyposh/zen.toml` | First `[[blocks]]` row prints `{{ .Path }}` + git on a `newline: true` row; second row is just `❯` with `foreground_templates` switching on `gt .Code 0`. Pairs with `[transient_prompt]` so scrollback collapses to one symbol per command. |
| **Decorative two-line wedge** | `end-4/dots-hyprland dots/.config/starship.toml` (wedges 🭧🭒, powerline glyphs, custom directory format with `→`), `Matt-FTW/dotfiles .config/starship/starship.toml` (custom `detect_files = ["hyprland.conf"]` custom module for a Hyprland glyph) | Visual nerd-font flex; needs a Nerd Font with the powerline-extra block. |
| **No prompt config** (relies on shell default or powerlevel10k) | `prasanthrangan/hyprdots Configs/.p10k.zsh`, `JaKooLit/Hyprland-Dots` (no starship/p10k file), `binnewbs/arch-hyprland` (oh-my-zsh `robbyrussell`), `Ax-Shell`, `DankMaterialShell`, `koeqaife/hyprland-material-you` | Out of scope for this plugin's starship/omp/fish lineup; the rice picks zsh + p10k or just leaves the shell unstyled. The interview's `prompt = "keep-current"` answer maps here. |

## Battle-tested techniques (from real configs)

Concrete, attributed moves harvested from the first-party theme repos and real rice configs.

**btop.**
- *One accent per box, 3-shade gradient per metric* (catppuccin/btop): `cpu_box`/`mem_box`/`net_box`/`proc_box` each take a distinct palette accent so the four panels read as separate; every graph is a `*_start`/`*_mid`/`*_end` triple — arrange them ordered (cool→warm for temp `green→yellow→red`, teal→lavender for CPU). `hi_fg` and `selected_fg` share the primary accent for keybind/selection coherence.
- *Transparent vs solid is one key* (JaKooLit `theme_background = False` vs omarchy `theme_background = true`): `False` (plus `main_bg=""` in the theme) floats btop over the terminal blur; `true` gives an opaque panel. Both are valid — pick per whether btop should blend into glass or stand on a surface.
- *`color_theme = "current"` sentinel* (omarchy): a fixed theme name that the rice's theme-switcher overwrites/symlinks, so one `btop.conf` works across every theme. Pair with `graph_symbol = "braille"` + `rounded_corners = True` to match rounded Hyprland windows, and `presets` to Tab-cycle layouts.

**cava.**
- *8-stop cool→warm gradient* (catppuccin/cava): map `gradient_color_1..8` low→high with cool hues at the base and red/pink at the peaks (`teal → … → red`) so loud spikes glow hot. Set `background` to the terminal bg or leave it for transparency over blur.
- *Denser, smoother spectrum* (Matt-FTW): `[general] framerate = 75` + `bar_width = 3` for a high-FPS thin-bar look — most rices touch only `[color]`, but these two `[general]` keys noticeably sharpen it.

**fastfetch.**
- *Logo, three tiers* — static PNG path `"source": "logo.png"` (Matt-FTW, simplest), dynamic command substitution `"source": "\"$(hyde-shell fastfetch logo)\""` (HyDE, per-distro), or omit for the built-in ASCII distro logo. `"height": 18` is the de-facto size; force `"type": "kitty"` when auto-detection fails. Image logos need a kitty-graphics-capable terminal (kitty/ghostty/wezterm/Konsole).
- *Category grouping via `keyColor` + tree glyphs* (JaKooLit): give each logical group one key color (distro=yellow, DE/WM=blue, system=green, audio=magenta) and fake a collapsible tree with Nerd-Font box-drawing in the `key` strings (`│ ├`, `│ └`); `"break"` rows separate groups.
- *ASCII box framing + format-index trimming* (HyDE): wrap a module group in `type: custom` rows drawing `┌──────┐`/`└──────┘`, and trim verbose modules with `format` index strings — `os {2}`, `cpu {1} @ {7}`, and a second `gpu {3}` row to surface the **GPU driver** on its own line. A `command` module (`hyprctl splash`) injects a dynamic header; the `colors` module footer is `symbol: circle` (HyDE) or `symbol: block` (Matt-FTW).

**starship.**
- *Named palette + `palette =` switch* (catppuccin/starship): define `[palettes.catppuccin_mocha]` with named colors and style every module by **name** (`style = "bold mauve"`), so one `palette =` line reskins the whole prompt across flavors. Nest style markup to color icon and arrow independently — `success_symbol = "[[󰄛](green) ❯](peach)"`.
- *Powerline segment mechanics* (Gruvbox Rainbow / Pastel Powerline presets): a segment is `format = '[ $content ](fg:X bg:Y)'`; between two segments a separator `[](fg:<prev_bg> bg:<next_bg>)` color-bleeds the arrow; the whole bar is one `format = """…"""` with each line ending `\`, and `$line_break$character` drops the input arrow to its own line.
- *`right_format` for the language firehose* (HyDE): push 50+ language/cloud modules to `right_format` so they never shove the cursor; keep the left prompt to dir + git + character. HyDE also ships a separate `powerline.toml` users opt into, and customises git glyphs — `ahead = '⇡${count}'`, `behind = '⇣${count}'`, `diverged = '⇕⇡${ahead_count}⇣${behind_count}'`.
- *Transient prompt for clean scrollback* — `enable_transience` (fish: a `starship_transient_prompt_func` returning `starship module character`) collapses past prompts to a bare symbol. Pair with `add_newline = false` for density. The **Nerd Font Symbols** preset is a composable glyph-only layer (drop-in `symbol`/`os.symbols`); `[directory.substitutions]` swaps folder names for icons.
- *powerlevel10k is the zsh-only alternative* — its headline is **Instant Prompt** (renders before plugins load, killing zsh startup lag), configured by the `p10k configure` wizard. starship wins for theming bash/fish/zsh uniformly from one TOML; p10k wins on pure-zsh startup speed. Confirmed in `prasanthrangan/hyprdots Configs/.p10k.zsh` — HyDE picks p10k, not starship, so it falls outside this plugin's starship/omp/fish lineup.

**oh-my-posh.**
- *Theme = one file, no include* — `oh-my-posh init <shell> --config <path>` is the **only** wiring. `mylinuxforwork/dotfiles dotfiles/.config/ohmyposh/zen.toml` is the in-the-wild reference: a single TOML with `[secondary_prompt]`, `[transient_prompt]`, `[[blocks]]` arrays, `[[blocks.segments]]` per row. There is no upstream "@import" for the palette — the rice renders the whole theme.
- *Transient prompt block* (ml4w `zen.toml`): a top-level `[transient_prompt]` with `template = '❯ '` and `foreground_templates` that switch to red on `gt .Code 0` and to the success color on `eq .Code 0`. This is the omp analogue of starship's `enable_transience`; ml4w opts in by default. Pair with `[secondary_prompt]` (continuation symbol on multi-line input).
- *Right-side prompt* — omp uses `"type": "rprompt"` block (`ml4w zen.toml` shows it with `overflow = 'hidden'` and a single `executiontime` segment) instead of starship's `right_format` string. Same intent: keep the left clean, push duration/status to the right.

**fish.**
- *Stale universal vars are real* — `end-4/dots-hyprland dots/.config/fish/fish_variables` ships a `SETUVAR fish_color_*` block (`SETUVAR fish_color_command:blue`, `SETUVAR fish_color_param:cyan`, …) baked into the dotfiles. Layer a rice on top of a config like this and a bare `set fish_color_command …` will silently update the universal instead of creating a fresh global — `gotchas.md` covers the fix (always explicit `set -g`, cleanup-loop for orphans).
- *Theme files vs `conf.d` snippets* — `catppuccin/fish themes/catppuccin-mocha.theme` lists each color as `fish_color_command 1e66f5` (no `#`, no `fish_color_` prefix on the LHS, no `set` keyword); these load only via `fish_config theme choose catppuccin-mocha` and persist to universals. A re-rendering rice prefers the explicit `set -g fish_color_command {{accent}}` form in `conf.d/zz-hypr-rice-colors.fish` (covered in `fish.tmpl`) — the snippet wins on every shell start instead of fighting a stale universal.
- *Transient prompt for starship-on-fish* — `caelestia-dots/caelestia fish/config.fish` ships
  ```fish
  function starship_transient_prompt_func
      starship module character
  end
  if test "$TERM" != "linux"
      starship init fish | source
      enable_transience
  end
  ```
  TTY guard (`$TERM != "linux"`) avoids invoking transience over the bare-Linux VT where the cursor-rewrite escapes don't render. Not in our template — opt-in.
- *`config.fish` can stay empty* — `mylinuxforwork/dotfiles dotfiles/.config/fish/config.fish` is **0 bytes**; everything lives in `conf.d/00_init.fish`, `10-aliases.fish`, `20-customization.fish`, `30-autostart.fish`. fish auto-sources `conf.d/*.fish` on every interactive start (before `config.fish`), so this is a legitimate design. Our managed-block sits in `config.fish` because find-and-replace on one file is simpler than coordinating multiple `conf.d` snippets, but a user who prefers the ml4w split can move our block into `conf.d/zz-hypr-rice.fish`; the snippets cohabit cleanly.
- *`set -U fish_greeting ""`* (ml4w `conf.d/00_init.fish`) — universal scope silences the default fish greeting forever, across all sessions and re-installs. Our template doesn't set it (interview hasn't asked); users who want a silent shell can run it once by hand.
- *atuin Up-arrow rebind* — `Matt-FTW/dotfiles .config/fish/conf.d/atuin.fish` sets `ATUIN_NOBIND true`, runs `atuin init fish | source`, then explicitly binds Up to `_atuin_bind_up` for fish's default + insert modes, including the `\eOA` and `\e[A` escape variants for terminals that send the alt form. Without this Up only opens the atuin fullscreen UI on Ctrl+R; binding Up makes it the history-up replacement. Our template only emits the init line — the rebind is an opt-in follow-up.

**Cross-engine glyph dict (battle-tested across 3+ rices).**
- Ahead `⇡${count}`, behind `⇣${count}`, diverged `⇕⇡${ahead_count}⇣${behind_count}` — `basecamp/omarchy config/starship.toml`, `prasanthrangan/hyprdots Configs/.config/starship/starship.toml`, `mylinuxforwork/dotfiles .config/ohmyposh/zen.toml`. This is more or less the de-facto idiom across Hyprland rices — adopt it in both `starship.tmpl` and `oh-my-posh.tmpl` for cross-engine recognition.
- `command_timeout = 200` (omarchy) on starship — slow VCS or cloud modules over a flaky network will otherwise stall every prompt redraw. The rice template uses 500 (room for `git_status` on big repos); cap at 1000.

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

### oh-my-posh — a `rice.omp.json` (palette + two-line prompt)
```json
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "version": 3,
  "final_space": true,
  "palette": { "accent": "#{{accent}}", "green": "#{{green}}", "red": "#{{red}}", "yellow": "#{{yellow}}" },
  "blocks": [
    { "type": "prompt", "alignment": "left", "segments": [
      { "type": "path", "style": "plain", "foreground": "p:accent", "template": "{{ .Path }}",
        "properties": { "style": "agnoster_short", "max_depth": 3 } },
      { "type": "git", "style": "plain", "foreground": "p:green",
        "foreground_templates": ["{{ if or (.Working.Changed) (.Staging.Changed) }}p:yellow{{ end }}"],
        "template": "  {{ .HEAD }}", "properties": { "fetch_status": true } } ] },
    { "type": "prompt", "alignment": "left", "newline": true, "segments": [
      { "type": "text", "style": "plain", "foreground": "p:accent",
        "foreground_templates": ["{{ if gt .Code 0 }}p:red{{ end }}"], "template": "❯" } ] }
  ]
}
```
*Init it: `oh-my-posh init fish --config ~/.config/ohmyposh/rice.omp.json | source` (or `bash`/`zsh`).
The `{{ .Path }}`/`{{ .HEAD }}` are oh-my-posh's own Go templates — distinct from the `{{accent}}`
palette placeholders a rice renderer substitutes.*

### fish — `~/.config/fish/conf.d/zz-rice-colors.fish` (syntax highlighting)
```fish
set -g fish_color_command        {{accent}}
set -g fish_color_param          {{fg}}
set -g fish_color_quote          {{green}}
set -g fish_color_keyword        {{magenta}}
set -g fish_color_redirection    {{cyan}}
set -g fish_color_error          {{red}}
set -g fish_color_comment        {{muted}}
set -g fish_color_autosuggestion {{muted}}
set -g fish_color_selection      {{fg}} --background={{surface}}
set -g fish_color_search_match   --background={{surface}}
set -g fish_pager_color_prefix     {{accent}} --bold
set -g fish_pager_color_completion {{fg}}
set -g fish_pager_color_selected_background --background={{surface}}
```
*Auto-sourced on every interactive start — no `fish_config theme choose` needed; re-rendering recolors
the next shell. Bare hex, no `#`. This is the syntax/pager layer; pair it with starship or oh-my-posh
for the prompt itself.*

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
- **oh-my-posh palette colors render as literal text (`p:accent`).** The segment used `p:name` but the
  name isn't defined in the top-level `palette` (or you're on an oh-my-posh too old for palettes) —
  define every referenced name. Invalid JSON (a trailing comma) makes the whole prompt silently fall
  back; validate the theme file. Don't confuse `p:` palette refs with Go templates (`{{ .Path }}`).
- **fish colors won't change after a re-theme.** Per fish's documented scoping
  (`local > function > global > universal`), an explicit `set -g fish_color_command …` in a
  `conf.d` snippet *does* override a `set -U` left by `fish_config theme choose`. The real
  trap is writing `set fish_color_command …` with **no scope flag** — fish then updates the
  existing scope (the universal), so re-renders silently re-write the universal store instead
  of creating a fresh global. Always use explicit `set -g` in the conf.d snippet; if shells
  still look stale, clear leftover universals with
  `for v in (set --names -U | string match 'fish_color_*'); set -e $v; end`. Also: `.theme`
  files list values **without** the `fish_color_` prefix and without `#`; `set` lines need the
  prefix.
- **Pure-black btop background over a transparent terminal looks wrong.** If your terminal is
  transparent/blurred, a solid `theme[main_bg]` paints an opaque rectangle. Set `theme[main_bg]=""`
  and `theme_background = False` so the wallpaper/blur shows through — or match `main_bg` to your
  terminal's exact bg so it's seamless. Same logic for cava `background = default`.

## Sources

- btop themes — [catppuccin/btop](https://github.com/catppuccin/btop), [themes dir](https://github.com/catppuccin/btop/tree/main/themes), [README](https://github.com/catppuccin/btop/blob/main/README.md), [lokesh-krishna/catppuccin-btop theme](https://github.com/lokesh-krishna/catppuccin-btop/blob/main/catppuccin.theme)
- cava config — [karlstav/cava example config](https://raw.githubusercontent.com/karlstav/cava/master/example_files/config), [catppuccin/cava](https://github.com/catppuccin/cava), [cava README](https://github.com/catppuccin/cava/blob/main/README.md)
- fastfetch — [Configuration wiki](https://github.com/fastfetch-cli/fastfetch/wiki/Configuration), [Logo options wiki](https://github.com/fastfetch-cli/fastfetch/wiki/Logo-options), [fastfetch(1) man page](https://man.archlinux.org/man/extra/fastfetch/fastfetch.1.en)
- starship — [Catppuccin Powerline preset](https://starship.rs/presets/catppuccin-powerline), [Gruvbox Rainbow preset](https://starship.rs/presets/gruvbox-rainbow), [Presets index](https://starship.rs/presets/), [catppuccin/starship](https://github.com/catppuccin/starship)
- oh-my-posh — [Colors & palette docs](https://ohmyposh.dev/docs/configuration/colors), [Segment/block config](https://ohmyposh.dev/docs/configuration/general), [pywal palette discussion #6010](https://github.com/JanDeDobbeleer/oh-my-posh/discussions/6010), [polarNord theme example](https://github.com/MirkoR89/polarNord)
- fish — [Interactive use / `fish_color_*`](https://fishshell.com/docs/current/interactive.html), [`set_color`](https://fishshell.com/docs/current/cmds/set_color.html), [`fish_config`](https://fishshell.com/docs/current/cmds/fish_config.html), [catppuccin/fish theme files](https://github.com/catppuccin/fish), [pywal fish template PR #568](https://github.com/dylanaraps/pywal/pull/568)
- distro dotfiles — [HyDE](https://github.com/HyDE-Project/HyDE), [ml4w-dotfiles](https://gitlab.com/xeroxero8x/ml4w-dotfiles), [caelestia-dots/fish](https://github.com/caelestia-dots/fish), [It's FOSS: best Hyprland dotfiles](https://itsfoss.com/best-hyprland-dotfiles/)

**Config corpus read for the techniques catalog:**
- catppuccin/btop `themes/catppuccin_mocha.theme` (per-box accents, gradient triples) and real `btop.conf`s — JaKooLit `config/btop/btop.conf` (`theme_background=False`), basecamp/omarchy `config/btop/btop.conf` (`color_theme="current"`, `vim_keys`).
- catppuccin/cava `themes/mocha.cava` (8-stop gradient) and Matt-FTW `.config/cava/config` (`framerate=75`, `bar_width=3`).
- fastfetch `config.jsonc` — JaKooLit (tree-glyph `keyColor` grouping), HyDE-Project/HyDE (`$(hyde-shell fastfetch logo)` dynamic logo, ASCII box framing, GPU-driver row), Matt-FTW (PNG logo, block colors footer).
- starship — catppuccin/starship (`themes/mocha.toml` named palette + nested style markup), the official Gruvbox Rainbow / Pastel Powerline / Nerd Font Symbols presets (`starship.rs/presets`), HyDE `Configs/.config/starship/{starship,powerline}.toml` (`right_format`, custom git_status glyphs), `starship.rs/advanced-config` (transient prompt), and romkatv/powerlevel10k (instant prompt).
- 2026-06-05 corpus pass on `/workspace/.research/corpus.md`:
  - `dusklinux/dusky` `.config/starship.toml` + `.config/matugen/templates/starship-colors.toml` (palette-only matugen template, commented-out post-hook `ln -nfs` over `~/.config/starship.toml` — direct proof starship has no `include`/`@import`).
  - `noctalia-dev/noctalia-shell` `Assets/Templates/terminal/starship.toml` + `starship-predefined.toml` (palette-only `.tmpl` shape — emits **only** a `[palettes.noctalia]` block, no `palette = ...` switch, no format strings; relies on the user's own `starship.toml` to import the palette name).
  - `basecamp/omarchy` `config/starship.toml` (`command_timeout = 200`, `repo_root_format`, the ⇡⇣⇕ git glyph dict).
  - `mylinuxforwork/dotfiles` `dotfiles/.config/ohmyposh/zen.toml` (`[transient_prompt]` block, `[[blocks]] type='rprompt'` for omp's right-side prompt, foreground-template recolor on `.Code`) and `dotfiles/.config/fish/conf.d/{00_init,10-aliases,20-customization,30-autostart}.fish` (per-tool conf.d fragmentation, empty `config.fish`).
  - `caelestia-dots/caelestia` `fish/config.fish` (transient-prompt sugar `starship_transient_prompt_func` + `enable_transience`, `cat ~/.local/state/caelestia/sequences.txt` to inject the matugen-generated ANSI palette into kitty), `starship.toml` (caelestia's `right_format` firehose), `fish/functions/fish_greeting.fish` (custom ASCII art + `fastfetch --key-padding-left 5`).
  - `Matt-FTW/dotfiles` `.config/fish/conf.d/{starship,zoxide,atuin}.fish` (per-tool `type -q` guards, atuin Up-arrow rebind: `bind up _atuin_bind_up` + `\eOA`/`\e[A` variants + insert-mode binds), `.config/starship/starship.toml` + `STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship/starship.toml` (precedent for our `~/.config/hypr-rice/starship.toml` redirect), `.config/fish/fish_plugins` (`catppuccin/fish`, `franciscolourenco/done`, `jorgebucaran/autopair.fish`, plus tools-specific plugins like `gazorby/fish-abbreviation-tips`, `nickeb96/puffer-fish`).
  - `end-4/dots-hyprland` `dots/.config/fish/fish_variables` (the in-the-wild `SETUVAR fish_color_*` block that motivates our `set -g` discipline) and `dots/.config/fish/config.fish` (`alias clear "printf '\033[2J\033[3J\033[1;1H'"` to work around kitty's stale-scrollback clear bug — niche but real).
  - `catppuccin/fish` `themes/catppuccin-mocha.theme` (`.theme` file format reference: no `set` keyword, no `fish_color_` prefix on the LHS, bare hex without `#`).
  - Confirmed-absent: `prasanthrangan/hyprdots` (powerlevel10k via `.p10k.zsh`, not starship/omp), `JaKooLit/Hyprland-Dots` (no prompt engine in tree), `binnewbs/arch-hyprland` (oh-my-zsh `robbyrussell`), `Ax-Shell` / `DankMaterialShell` / `koeqaife/hyprland-material-you` (Quickshell/Python shells — no terminal-prompt component).

# kitty - terminal

Everything this plugin knows about authoring **kitty** for the `terminal` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template
- Validation
- Gotchas

---

## Template


```conf
include colors.conf

font_family            {{font_mono}}
font_size              {{font_size}}

background_opacity     {{opacity}}
# pair with Hyprland decoration blur
background_blur        1
window_padding_width   {{padding}}

cursor_shape           {{cursor.shape}}
# seconds; supports CSS easing per upstream docs
{{#if cursor.blink}}cursor_blink_interval  0.5
cursor_stop_blinking_after  1{{else}}cursor_blink_interval  0{{/if}}

# yes | no | titlebar-only | titlebar-and-corners
hide_window_decorations yes

# Tab bar — the recipe ships powerline + slanted because the colors.conf chrome
# (active_tab_*/inactive_tab_*/tab_bar_background) is wired specifically for it.
# Set `tab_bar_style hidden` to suppress the strip; the colors are then unused but harmless.
# fade | slant | separator | powerline | hidden | custom
tab_bar_style          powerline
# angled | round | slanted (community default)
tab_powerline_style    slanted
# hide strip until a second tab opens (Matt-FTW, Dank)
tab_bar_min_tabs       2

# 0 = never confirm; >0 = confirm if N+ children alive
{{#if extras.no-confirm-close}}confirm_os_window_close 0{{/if}}
# yes | no
{{#if extras.bell-off}}enable_audio_bell      no{{/if}}
# int; default 2000
{{#if extras.scrollback-10k}}scrollback_lines       10000{{/if}}
# never | cursor | always
{{#if extras.ligatures}}disable_ligatures      never{{else}}disable_ligatures      always{{/if}}

# Optional: kitty has a `shell` directive (default `.` = $SHELL). Rice does not write it —
# the user's chsh / login shell wins. Set explicitly only if the user picks a per-terminal
# override:  shell /usr/bin/fish
```

`~/.config/kitty/colors.conf` — see `references/components/terminal/kitty.tmpl` (rendered from `palette.conf`).
The colors file exports the 16 ANSI cells **plus** the kitty chrome slots that fall back to
hardcoded gray defaults (`cursor_text_color`, `url_color`, `active_tab_*`, `inactive_tab_*`,
`tab_bar_background`, `active_border_color`, `inactive_border_color`, `bell_border_color`) —
see `styling.md` "Chrome that needs theming if it's shown" for the full table.

---

## Validation


### 1. No trailing inline comments on typed value lines (HARD FAIL)

kitty has no comment-stripping on value lines. Every explanatory comment must be on its own line
above the setting — never `<key> <value>  # comment`. The lint is a single grep against the
emitted `kitty.conf`:

```bash
# Reject lines of the form: `<key> <value...> # ...`
# Allow: pure comment lines (`# foo`), and key/value lines without a trailing comment.
if grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]+[^#[:space:]].*[[:space:]]+#' \
     "$HOME/.config/kitty/kitty.conf"; then
  echo "ERROR: kitty.conf has trailing inline comments on typed value lines" >&2
  echo "       move the comment to its own line above the setting" >&2
  exit 1
fi
```

The same lint applies to `colors.conf` — but the engine template (`kitty.tmpl`) has no value-line
comments by construction, so this guards against drift if the template is hand-edited.

### 2. kitty load-test (full parse)

The authoritative check is kitty itself parsing the file. Run when kitty is installed:

```bash
if command -v kitty >/dev/null; then
  kitty +runpy "
from kitty.config import load_config
from kitty.constants import config_dir
import os
load_config(os.path.join(config_dir, 'kitty.conf'))
print('OK')
" || { echo "ERROR: kitty rejected kitty.conf" >&2; exit 1; }
fi
```

If kitty isn't available in the rice-render environment (CI, headless validator), the grep lint
in check (1) is the minimum acceptable substitute — it catches the dominant defect class (trailing
inline comments) without needing the binary.

---

## Gotchas


`auto` is documented as a valid value for `bold_font`, `italic_font`, and `bold_italic_font`
(meaning "derive from the base") — NOT for `font_family` itself, where the upstream default is
`monospace`. dusky's `font_family auto` (in their kitty.conf) is undefined behavior; kitty either
falls back to its compiled default or to whatever fontconfig returns for `auto` as a literal family
name. The rice template always names a real Nerd Font family (e.g. `JetBrainsMono Nerd Font`) and
should not propagate `auto` even if the user requests it.

## kitty `cursor_trail` is a millisecond threshold (not a boolean)

The upstream doc string: *"Set this to a value larger than zero to enable a 'cursor trail' animation
...measured in milliseconds. The trail animation only follows cursors that have stayed in their
position for longer than the specified number of milliseconds."* So `cursor_trail 1` (JaKooLit, end-4)
means "trail any cursor still for >1ms" — effectively always. `cursor_trail 10` (dusky, binnewbs) is
"only trail clearly stationary cursors." `0` disables. Pair with `cursor_trail_decay <fast> <slow>`
(seconds, two floats) and `cursor_trail_start_threshold <int>` (cells of movement before the trail
kicks in) for full control. If `cursor.blink=true`, also consider `cursor_stop_blinking_after 1`
(seconds) so the cursor settles on idle.

## kitty's powerline tab bar has hardcoded fallback colors

`tab_bar_style powerline` is in the recipe; without exporting `active_tab_*`, `inactive_tab_*`,
`tab_bar_background`, the powerline strip falls back to kitty's hardcoded `#444` / `#888` /
`#000` defaults, which always clash with a riced palette (the strip looks gray-on-gray on a
catppuccin terminal). The plugin's `kitty.tmpl` exports all six tab keys plus
`active_border_color`/`inactive_border_color`/`bell_border_color` — see the "Chrome that needs
theming" table in `styling.md`. None of these add palette keys; they're all derived from
existing `bg`/`fg`/`accent`/`surface`/`muted`/`red`.

## kitty rejects trailing inline comments on typed value lines

kitty has no comment-stripping on value lines — it reads everything after the key as the value.
So `background_blur 1  # pair with Hyprland decoration blur` is parsed as
`background_blur = "1  # pair with Hyprland decoration blur"`, which is not a valid int/bool, and
kitty silently disables the setting on every launch. (No diagnostic surfaces unless you run
`kitty +runpy "from kitty.config import load_config; …"` — see `validation.md`.)

The same hazard applies to other strict-parser configs the rice writes: **foot.ini**, **ghostty
config**, **qt6ct INI** all require comments on their own lines. TOML (alacritty) and Lua
(wezterm) accept trailing comments; everything else does not. The recipe in `template.md`
matches this rule and the parse lint in `validation.md` (step 1) enforces it on every emit.


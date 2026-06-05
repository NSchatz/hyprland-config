# terminal — gotchas

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

## foot uses bare hex; the other four want `#`

The rice engine's per-emulator colors writer branches on this. kitty/alacritty/wezterm/ghostty get
`#1e1e2e`; foot's `[colors]` block takes `1e1e2e` (no `#`, alpha lives in `alpha=` not in the hex).
Easy to get wrong by reusing kitty's writer for foot — foot then silently rejects every color.

## foot `cursor=` is `<text> <cursor-bg>`, not `<cursor-bg> <text>`

Per `foot.ini(5)`: *"Two space separated RRGGBB values specifying the foreground (text) and
background (cursor) colors for the cursor."* — text comes first, cursor fill second.
catppuccin/foot mocha: `cursor=11111b f5e0dc` (crust as text-on-cursor, rosewater as cursor
fill). DankMaterialShell's matugen foot template uses the same shape:
`cursor = {background} {primary}`. Getting the order wrong gives you an accent-on-accent cursor
that's invisible whenever the cursor sits on a glyph. The plugin's `foot.ini` template does
NOT currently emit a `cursor=` line — it relies on foot's default of inverse-of-cell — but if
the user adds one, text comes first.

## foot `alpha` and `blur` live in `[colors-*]`, not `[main]`

`foot.ini(5)` documents `alpha`, `blur`, `foreground`, `background`, `regular0..7`, `bright0..7`,
`dim0..7`, `selection-foreground`, `selection-background` all inside the `[colors-dark]` /
`[colors-light]` sections (or the legacy `[colors]` section). Putting `alpha=0.85` or
`blur=yes` under `[main]` silently no-ops — foot drops unknown top-level keys without a warning.

`blur=yes` is foot's server-side blur hint (read by KDE/Sway compositors). On Hyprland the
actual blur still comes from `decoration { blur { ... } }`; foot's `blur=yes` is a no-op
visual-wise on Hyprland but harmless. Reference: fufexan's nix-managed `foot.nix` sets
`colors-dark.alpha=0.9 blur=yes`, both inside the colors block — that's the right shape.

The plugin's template puts `alpha=` under the right block — `[colors]` is the legacy single-mode
form that still works for "dark only." If the user wants dual light/dark, the foot template
needs both `[colors-dark]` and `[colors-light]` blocks each with their own `alpha=`.

## foot bell config is in `[bell]`, not `[main]`

Stale snippets put `bell=none` under `[main]`; foot silently drops unknown keys, so the bell
stays on. The real keys live in their own section (`foot.ini(5)`):

```ini
[bell]
system=no       # default yes — ring the system bell
urgent=no       # default no  — signal urgency to the compositor
visual=no       # default no  — flash the terminal window
notify=no       # default no  — emit a desktop notification
command=        # default empty — run a command on BEL
```

To silence the bell completely, set `system=no` (the others default off). There is **no
`bell=none`** shortcut.

## foot cursor `style` values

`[cursor] style` accepts `block | beam | underline | hollow` — exactly four values per
`foot.ini(5)`. `bar` (alacritty/ghostty's name for beam) is **not** a valid foot value.

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

## kitty `font_family auto` is NOT documented as valid

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

## ghostty `config-file = ?path` is the optional-include idiom

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

# launcher — template

Per-tool config + style recipes. The engine **always** writes a colors file the tool's style
`@import`s/`include`s — never hardcode hex in the style file. The canonical var names are
fixed by `_shared/colors-contract.md`; the rice templates in `skills/rice/templates/{wofi,rofi,
fuzzel}.tmpl` render those names from `palette.conf`.

The deep styling catalog — selection idioms, blur, `em`/`%` sizing, layout variants — lives in
`styling.md`. This file is the minimum viable recipe per tool, sufficient for the engine.

## Hyprland variables emitted (by `keybinds` component)

```ini
$menu  = {{menu_invocation}}     # e.g. wofi --show drun
$dmenu = {{dmenu_invocation}}    # e.g. wofi --dmenu   — NEVER `$menu --dmenu`
```

Per-tool invocations:

| tool    | `$menu`                       | `$dmenu`             |
|---|---|---|
| wofi    | `wofi --show drun`            | `wofi --dmenu`       |
| rofi    | `rofi -show drun`             | `rofi -dmenu`        |
| fuzzel  | `fuzzel`                      | `fuzzel --dmenu`     |
| tofi    | `tofi-drun \| sh`             | `tofi`               |
| walker  | `walker`                      | `walker --dmenu`     |
| vicinae | `vicinae`                     | `vicinae --dmenu`    |
| anyrun  | `anyrun`                      | `anyrun --dmenu`     |

## wofi — `~/.config/wofi/`

`config` (line-based INI; behavior only):

```ini
show=drun                    ; or "drun,run" for run-drun
prompt=Search
width=600                    ; from layout=centered
height=400
location=center              ; layout=compact-top → "top"
insensitive=true             ; from behavior.fuzzy
allow_images=true            ; from icons=true
image_size=24
hide_scroll=true             ; from behavior.hide-scrollbar
matching=fuzzy               ; from behavior.fuzzy
no_actions=true
gtk_dark=true
key_expand=Tab
term=kitty                   ; {{terminal.emulator}} for run-in-terminal entries
```

`style.css` (look; `@import`s the engine-generated colors file):

```css
@import "colors.css";        /* defines @bg @fg @surface @accent */

window {
  margin: 0;
  background-color: alpha(@bg, 0.92);
  border-radius: 14px;
  border: 1px solid @accent;
  font-family: "{{fonts.ui_family}}", sans-serif;
  font-size: 14px;
}
#input        { margin: 10px; padding: 8px 12px; border-radius: 10px;
                border: none; background-color: @surface; color: @fg; }
#inner-box    { margin: 6px; }
#outer-box    { padding: 8px; }
#entry        { padding: 6px 10px; border-radius: 8px; }
#text         { color: @fg; }
#entry:selected         { background-color: @accent; }
#entry:selected #text   { color: @bg; }
```

`colors.css` rendered by the engine from `wofi.tmpl` — exports `bg fg surface accent`. Vars
referenced in `style.css` MUST be one of those four (see `_shared/colors-contract.md`).

## rofi — `~/.config/rofi/`

`config.rasi` (behavior + theme pointer):

```rasi
configuration {
    modi: "drun";              /* "drun,run" for run-drun */
    show-icons: true;           /* from icons=true; omit when false */
    icon-theme: "Papirus";
    drun-display-format: "{name}";
    drun-match-fields: "name,generic,exec,categories";
    kb-cancel: "Escape";
}
@theme "~/.config/rofi/theme.rasi"
```

`theme.rasi` (look; `@import`s the engine colors file at the top):

```rasi
@import "colors.rasi"        /* * { bg: …; bg-alt: …; fg: …; muted: …; accent: …; accent2: …; red: …; green: …; } */

window {
  width: 700px;
  border-radius: 14px;
  border: 1px solid;
  border-color: @accent;
  background-color: @bg;
  padding: 12px;
}
inputbar  { spacing: 8px; padding: 8px; margin: 0 0 8px 0;
            background-color: @bg-alt; border-radius: 10px; }
prompt    { text-color: @accent; }
entry     { text-color: @fg; placeholder: "Search…"; placeholder-color: @muted; }
listview  { lines: 8; columns: 1; spacing: 4px; scrollbar: false; }
element   { padding: 7px 10px; border-radius: 8px; }
element-icon { size: 22px; }
element selected               { background-color: @accent; text-color: @bg; }
element selected normal.normal { background-color: @accent; text-color: @bg; }
```

`colors.rasi` rendered by the engine from `rofi.tmpl`. The `*{}` block exports
`@bg @bg-alt @fg @muted @accent @accent2 @red @green` — `theme.rasi` MUST reference exactly
these names (an unknown var fails to resolve and the launcher silently won't open).

For `layout=fullscreen-grid`: `window { fullscreen: true; }` + `listview { columns: 5; lines:
5; }` + `element-icon { size: 5%; }`. For `layout=multi-column`: `listview { columns: 3;
lines: 5; }` + `element { orientation: vertical; }` + `element-icon { size: 72px; }`.

## fuzzel — `~/.config/fuzzel/fuzzel.ini`

Colors live **inside** `fuzzel.ini` (no `include=` for the colors section in stock fuzzel —
the engine merges them at render time). The colors block exports
`background text match selection selection-text selection-match border` per
`_shared/colors-contract.md`. Hex values are **`RRGGBBAA` without `#`** — see `gotchas.md`.

```ini
[main]
font=Inter:size=13                ; {{fonts.ui_family}} : size = {{fonts.ui_size}}
prompt=">   "
icon-theme=Papirus
icons-enabled=yes                  ; from icons=true; "no" when false
width=32                           ; characters, not px (gotchas.md)
lines=12                           ; layout=fullscreen-grid: 24+; compact-top: 6
horizontal-pad=20
vertical-pad=12
inner-pad=8
layer=overlay                      ; floats above Hyprland layers
exit-on-keyboard-focus-loss=yes    ; from behavior.close-on-focus-loss
fuzzy=yes                          ; from behavior.fuzzy

[colors]
background={{bg}}f2                ; rendered from fuzzel.tmpl
text={{fg}}ff
match={{accent}}ff
selection={{accent}}ff
selection-text={{bg}}ff
selection-match={{accent2}}ff
border={{accent}}ff

[border]
width=1
radius=14
```

## Briefer recipes (engine themes only what the tool exposes)

### tofi — `~/.config/tofi/config`

INI-ish `key = value`. Colors take a leading `#`. Forced text-only (no app icons). Worth offering
when the user wants a fast, minimal picker.

```ini
anchor = center
width = 640
height = 320
font = "Inter"                   ; {{fonts.ui_family}}
font-size = 14
num-results = 7

background-color = #{{bg}}ee
border-width = 2
border-color = #{{accent}}
corner-radius = 12
padding-top = 16
padding-bottom = 16
padding-left = 18
padding-right = 18

prompt-text = ">  "
prompt-color = #{{accent}}
text-color = #{{fg}}
selection-color = #{{accent}}
selection-background = #{{surface}}80
```

### walker — `~/.config/walker/config.toml` + `style.css`

Walker runs as a service (`walker --gapplication-service`) for instant startup; `walker`
launches the picker. Config is TOML; styling is GTK4 CSS. The engine writes a `colors.css`
the user's `style.css` `@import`s — same shape as wofi.

```toml
# config.toml (excerpt)
[search]
fuzzy = true
placeholder = "Search"

[ui]
icons = true
width = 600
height = 400
anchor = "center"

[modules.drun]
show = true
```

### vicinae — `~/.config/vicinae/config.json`

Qt 6 Raycast-for-Linux. Themes follow vicinae's own internal format (not GTK CSS, not rasi);
the engine writes a minimal `theme.json` mapping `accent`, `bg`, `fg`, `surface` into vicinae's
schema, and the user picks built-in extensions through vicinae's own UI. **The engine themes
only what vicinae exposes** — geometry/layout knobs are largely fixed by the app.

### anyrun — `~/.config/anyrun/config.ron` + `style.css`

Krunner-style plugin runner. `config.ron` is Rust object notation (`(plugins: [...], width:
Fraction(0.3), …)`); `style.css` is GTK4 CSS. Engine writes `colors.css` the user `@import`s.
Plugin selection (`applications`, `shell`, `randr`, `dictionary`, `kidex`, …) is captured by
`utilities`/`plugins`, not here.

## Colors contract

| File written by engine | Format | Var names |
|---|---|---|
| `~/.config/wofi/colors.css` | CSS `@define-color` | `bg fg surface accent` |
| `~/.config/rofi/colors.rasi` | rasi `* { name: #hex; }` | `bg bg-alt fg muted accent accent2 red green` |
| `~/.config/fuzzel/fuzzel.ini` `[colors]` | `key=RRGGBBAA` (no `#`) | `background text match selection selection-text selection-match border` |
| `~/.config/tofi/colors.tofi` (sourced) | leading-`#` hex | `background-color border-color prompt-color text-color selection-color selection-background` |
| `~/.config/walker/colors.css` | CSS `@define-color` | `bg fg surface accent` |
| `~/.config/anyrun/colors.css` | CSS `@define-color` | `bg fg surface accent` |

See `_shared/colors-contract.md` — these names ARE the contract.

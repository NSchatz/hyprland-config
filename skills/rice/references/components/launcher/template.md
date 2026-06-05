# launcher — template

Per-tool config + style recipes. The engine **always** writes a colors file the tool's style
`@import`s/`include`s — never hardcode hex in the style file. The canonical var names are
fixed by `_shared/colors-contract.md`; the rice templates in `skills/rice/references/components/launcher/{wofi,rofi,
fuzzel}.tmpl` render those names from `palette.conf`.

The deep styling catalog — selection idioms, blur, `em`/`%` sizing, layout variants — lives in
`styling.md`. This file is the minimum viable recipe per tool, sufficient for the engine.

## Hyprland variables emitted (by `keybinds` component)

```ini
$menu  = {{menu_invocation}}     # e.g. wofi --show drun
$dmenu = {{dmenu_invocation}}    # e.g. wofi --dmenu   — NEVER `$menu --dmenu`
```

Per-tool invocations:

| tool    | `$menu`                       | `$dmenu`                              |
|---|---|---|
| wofi    | `wofi --show drun`            | `wofi --dmenu`                        |
| rofi    | `rofi -show drun`             | `rofi -dmenu`                         |
| fuzzel  | `fuzzel`                      | `fuzzel --dmenu`                      |
| tofi    | `tofi-drun \| sh`             | `tofi`                                |
| walker  | `walker`                      | `walker --dmenu` (also `-d`)          |
| vicinae | `vicinae toggle`              | `vicinae dmenu` (subcommand, no `--`) |
| anyrun  | `anyrun`                      | `anyrun --plugins libstdin.so`        |

Notes on the less-obvious ones:
- **walker** needs its service running for the `walker` command to be instant
  (`walker --gapplication-service` in `companion-daemons`). `--dmenu` / `-d` are first-class
  flags (verified in walker ≥ 2.3).
- **vicinae** runs as a persistent daemon (`vicinae server --replace`, typically autostarted).
  Window control is via the IPC subcommands `vicinae open` / `close` / `toggle`. dmenu mode
  is invoked as a subcommand (`vicinae dmenu`), not a flag.
- **anyrun has no dedicated `--dmenu` flag** — its dmenu-style picker is the `libstdin.so`
  plugin, invoked via `anyrun --plugins libstdin.so` (which then reads stdin).

## wofi — `~/.config/wofi/`

`config` (line-based INI; behavior only):

```ini
show=drun                    ; or "drun,run" for run-drun
prompt=Search
width=600                    ; from layout=centered
height=400
location=center              ; layout=compact-top → "top"
insensitive=true             ; case-insensitive matching (always-on convenience)
allow_images=true            ; from icons=true
image_size=24
hide_scroll=true             ; from behavior.hide-scrollbar
matching=fuzzy               ; from behavior.fuzzy (else "contains" — the default)
no_actions=true
gtk_dark=true
key_expand=Tab
term=kitty                   ; {{terminal.emulator}} for run-in-terminal entries
close_on_focus_loss=true     ; from behavior.close-on-focus-loss
```

All wofi config keys use **underscores**, never hyphens (e.g. `allow_images`, NOT
`allow-images`; `close_on_focus_loss`, NOT `close-on-focus-loss`). A hyphenated key is
silently ignored — wofi just falls back to the default. See `man 5 wofi`.

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
    drun-match-fields: "name,generic,exec,keywords";  /* dusky: drop "categories"
                                                         so Firefox stops matching
                                                         every Network/WebBrowser
                                                         query */
    kb-cancel: "Escape";

    /* Single-click activation — rofi's default is double-click, which feels
       broken to anyone reaching for the mouse. Clear me-select-entry first
       (MousePrimary is bound there by default; rofi refuses to bind the same
       event twice). Idiom from dusky, ML4W, Matt-FTW. */
    me-select-entry: "";
    me-accept-entry: "MousePrimary";

    /* Frecency-aware fuzzy search — rofi maintains ~/.cache/rofi3.druncache
       launch counts; these three options consult it (sort by match quality,
       launch history breaks ties; PowerToys/Albert style). Dusky idiom. */
    sort: true;
    sorting-method: "fzf";
    matching: "fuzzy";
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
/* visible-modifier.state syntax per rofi-theme(5) — period (not space)
   is the dominant community form (HyDE, JaKooLit, ML4W, dusky, Matt-FTW,
   binnewbs all use this). Cover the three states or the highlight won't
   apply to drun rows that rofi has marked active/urgent. */
element selected.normal  { background-color: @accent; text-color: @bg; }
element selected.urgent  { background-color: @red;    text-color: @bg; }
element selected.active  { background-color: @green;  text-color: @bg; }
```

`colors.rasi` rendered by the engine from `rofi.tmpl`. The `*{}` block exports
`@bg @bg-alt @fg @muted @accent @accent2 @red @green` — `theme.rasi` MUST reference exactly
these names (an unknown var fails to resolve and the launcher silently won't open).

For `layout=fullscreen-grid`: `window { fullscreen: true; }` + `listview { columns: 5; lines:
5; }` + `element-icon { size: 5%; }`. For `layout=multi-column`: `listview { columns: 3;
lines: 5; }` + `element { orientation: vertical; }` + `element-icon { size: 72px; }`.

## fuzzel — `~/.config/fuzzel/fuzzel.ini`

The engine writes the colors **inline** into `fuzzel.ini` `[colors]` (merge-time render).
Fuzzel does in fact support `include=<abs-path-or-~/relative>` per `fuzzel.ini(5)` and the
community usually splits colors into a separate file that gets included (end-4 uses
`include="~/.config/fuzzel/fuzzel_theme.ini"`; catppuccin/fuzzel ships pure `[colors]` files
intended to be included; caelestia points include at a `current.ini` symlink). The rice's
current engine wiring merges instead — switch to `include=` is a one-manifest-line change if a
future engine pass wants the split. The colors block exports
`background text match selection selection-text selection-match border` per
`_shared/colors-contract.md` — that's the 7-key subset the rice covers. Fuzzel's full
upstream set is 11 (`+prompt placeholder input counter`); recipe extension flagged in the
research report, not added unilaterally. Hex values are **`RRGGBBAA` without `#`** — see
`gotchas.md`.

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
match-mode=fuzzy                   ; from behavior.fuzzy — valid values: exact|fzf|fuzzy (default fzf)

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

### walker — `~/.config/walker/config.toml` + `themes/<name>/style.css`

Walker runs as a service (`walker --gapplication-service`) for instant startup; `walker`
launches the picker, and `walker --dmenu` (or `-d`) is the dmenu mode. Config is TOML;
styling is GTK4 CSS placed in `~/.config/walker/themes/<name>/style.css`. The engine writes a
sibling `colors.css` the theme's `style.css` `@import`s — same shape as wofi.

The actual top-level sections in upstream `config.toml` (verified against the bundled default
on `abenz1267/walker`, v2.x) are **`[shell]`, `[columns]`, `[placeholders]`, `[keybinds]`,
`[providers]`** plus a flat set of top-level keys (`theme`, `close_when_open`,
`force_keyboard_focus`, `as_window`, `single_click_activation`, …). There is no `[search]`,
`[ui]`, or `[modules.drun]` section — that is **not** walker's schema.

```toml
# config.toml (excerpt — real upstream keys)
theme = "rice"                     # picks ~/.config/walker/themes/rice/style.css
close_when_open = true             ; from behavior.close-on-focus-loss
as_window = false                  ; layer-shell vs regular window
force_keyboard_focus = true

[providers.default]
# providers map to the picker's data sources (desktopapplications, calc, websearch, …);
# their full schema lives in walker's upstream docs.
```

### vicinae — `~/.config/vicinae/settings.json`

Qt 6 Raycast-for-Linux. Config file is **`settings.json`** (JSONC — JSON with comments
allowed); the daemon is started via `vicinae server --replace` (typically autostarted), and
the window is controlled with `vicinae open|close|toggle`. Dmenu mode is the `vicinae dmenu`
subcommand (not a `--dmenu` flag).

Run `vicinae config default` to dump the fully-annotated default `settings.json` — that's the
authoritative key reference; the schema evolves between releases. Themes follow vicinae's own
internal format (not GTK CSS, not rasi); the engine writes a minimal theme block into
`settings.json` mapping `accent`, `bg`, `fg`, `surface` into vicinae's schema, and the user
picks built-in extensions through vicinae's own UI. **The engine themes only what vicinae
exposes** — geometry/layout knobs are largely fixed by the app.

### anyrun — `~/.config/anyrun/config.ron` + `style.css`

Krunner-style plugin runner. `config.ron` is Rust Object Notation; `style.css` is GTK4 CSS.
Engine writes `colors.css` the user `@import`s. Plugin selection (`applications`, `shell`,
`randr`, `dictionary`, `kidex`, …) is captured by `utilities`/`plugins`, not here.

The actual top-level `Config` struct keys (verified against
`anyrun-org/anyrun/examples/config.ron`) are **`snake_case`** — `x`, `y`, `width`, `height`
(all wrapped in `Fraction(_)` or `Absolute(_)`), `hide_icons`, `ignore_exclusive_zones`,
`layer` (`Background|Bottom|Top|Overlay`), `hide_plugin_info`, `close_on_click`,
`show_results_immediately`, `max_entries` (Option), `plugins` (list of plugin paths). Example:

```ron
Config(
  x: Fraction(0.5),
  y: Absolute(0),
  width: Absolute(800),
  height: Absolute(1),
  hide_icons: false,
  ignore_exclusive_zones: false,
  layer: Overlay,
  hide_plugin_info: false,
  close_on_click: false,
  show_results_immediately: false,
  max_entries: None,
  plugins: ["libapplications.so", "libshell.so"],
)
```

**Anyrun has no `--dmenu` flag.** The dmenu-style picker is the `libstdin.so` plugin —
invoke as `anyrun --plugins libstdin.so` (which reads newline-separated entries from stdin
and prints the selection). That's the right value for `$dmenu` when `launcher.tool=anyrun`.

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

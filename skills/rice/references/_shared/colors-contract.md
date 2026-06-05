# Per-app colors contract

Every visual component emits a colors file the app reads. Each colors file exports a fixed set of
variable names the component's `style.css` / `theme.rasi` / `Colors.qml` / etc. references. Renaming
or removing a name **breaks the component's styling silently** (CSS no-ops on unknown
`@define-color`; rofi errors), so the names below are the contract.

## Canonical variable names (per component)

| Component | Output file | Format | Var names exported |
|---|---|---|---|
| hyprland | `~/.config/hypr/colors.conf` | hyprlang `$var = rgb(hex)` | `accent accent2 bg fg surface muted` |
| waybar | `~/.config/waybar/colors.css` | CSS `@define-color` | `bg fg surface muted accent accent2 red green yellow blue magenta cyan` |
| wofi | `~/.config/wofi/colors.css` | CSS `@define-color` | `bg fg surface accent` |
| rofi | `~/.config/rofi/colors.rasi` | rasi `* { name: #hex; }` | `bg bg-alt fg muted accent accent2 red green` |
| mako | inline section of `~/.config/mako/config` | INI `key=#hex` | `background-color text-color border-color` |
| dunst | merged into `~/.config/dunst/dunstrc` | INI per-`[urgency_*]` block | `frame_color separator_color background foreground` |
| swaync | `~/.config/swaync/colors.css` | CSS `@define-color` | `bg fg surface muted accent accent2 red` |
| fuzzel | merged into `[colors]` of `fuzzel.ini` | `key=RRGGBBAA` (no `#`) | `background text match selection selection-text selection-match border` |
| kitty | `~/.config/kitty/colors.conf` | space-separated `name #hex` | `background foreground cursor selection_background selection_foreground color0..color15` |
| wlogout | `~/.config/wlogout/colors.css` | CSS `@define-color` | `bg fg accent surface` |
| gtk4 | `~/.config/gtk-4.0/gtk.css` | libadwaita `@define-color` | `accent_color accent_bg_color accent_fg_color window_bg_color window_fg_color view_bg_color view_fg_color headerbar_bg_color headerbar_fg_color card_bg_color popover_bg_color destructive_color success_color warning_color` |
| btop | `~/.config/btop/themes/rice.theme` | btop `theme[key]="#hex"` | `main_bg main_fg title hi_fg selected_* inactive_fg graph_text meter_bg proc_misc *_box div_line temp_* cpu_* free_* used_*` |
| cava | merged into `[color]` of cava config | INI `gradient_color_N = '#hex'` | `gradient_color_1..8 foreground background` (cava supports up to 8 gradient stops; the rice template uses 1..6 by default, leaving 7-8 free for the user to extend) |
| eww | `~/.config/eww/colors.scss` | SCSS `$var: #hex;` | `bg fg surface muted cursor accent accent2 red green yellow blue magenta cyan color0..color15` |
| ags / astal | `~/.config/ags/colors.scss` | SCSS `$var: #hex;` + GTK4 `@define-color` interop | `bg fg surface muted cursor accent accent2 red green yellow blue magenta cyan color0..color15` + semantic aliases `window-bg on-window card-bg primary secondary radius anim-duration` |
| quickshell | `~/.config/quickshell/Colors.qml` | QML singleton `readonly property color name: "#hex"` | `bg fg surface muted cursor accent accent2 red green yellow blue magenta cyan term[16] fontUi fontMono radius animDuration` |
| starship | `~/.config/hypr-rice/starship.toml` | starship `[palettes.rice]` table | `bg fg surface muted accent accent2 red green yellow blue magenta cyan` |
| oh-my-posh | `~/.config/hypr-rice/rice.omp.json` | oh-my-posh top-level `palette` object | `bg fg surface muted accent accent2 red green yellow blue magenta cyan` |
| fish | `~/.config/fish/conf.d/zz-hypr-rice-colors.fish` | fish `set -g fish_color_*` (bare hex, no `#`) | bound to: `fish_color_{normal,command,keyword,quote,redirection,end,error,param,option,valid_path,comment,operator,escape,autosuggestion,selection,search_match,history_current,cwd,cwd_root,user,host,host_remote,status,cancel}` + `fish_pager_color_*` |

## Wrap formats

- **Hyprland** (`hyprland.conf`, `looknfeel.conf`): `rgb({{accent}})` — no `#`, parens around the hex.
- **CSS** (`@define-color`, `*` rasi blocks): `#{{accent}}` — leading `#`, semicolon-terminated.
- **kitty / btop**: `#{{accent}}` — leading `#`, no quote, space-separated.
- **fuzzel** (`fuzzel.ini` `[colors]`): `{{accent}}ff` — bare hex with two-digit alpha suffix, no `#`.
- **fish**: bare hex `{{accent}}` (no `#`) on `set -g fish_color_*` lines.

## Rules for templates

1. **Reference colors through the engine** — every component config file should `@import` /
   `include` / `source =` its colors file, not hardcode hex. The two exceptions where literal hex
   is required:
   - **hyprlock** — can't read Hyprland `$vars`, fill from palette.conf at generate-time.
   - **fuzzel** — `[colors]` section in `fuzzel.ini` is merge-time, not include.
2. **Names must match the component's stylesheet exactly.** Renaming a var without updating the
   stylesheet silently un-themes that surface.
3. **Skip semantic-state vars that don't apply.** mako/wofi/wlogout use a thin set; kitty/eww/ags
   need the full 16-color terminal palette.

## Palette source

All the `{{var}}` values resolve to keys in `palette.conf` — see `palette-schema.md`.

# notifications — template

Per-daemon recipes. The rice engine renders the **colors** portion from `palette.conf` via
`_shared/colors-contract.md`; the rest of the config is emitted by this component's writer from the
`notifications.*` answers. Every literal color shown below as `#{{accent}}` etc. is engine-rendered
— **never hardcode hex** in this component's output.

For the full styling library (anatomy, urgency conventions, swaync widget patterns,
battle-tested moves), see `styling.md`.

## mako — `~/.config/mako/config`

Single file holds layout + behavior + colors. Colors come from the rice-rendered `mako.tmpl`
(inline keys + `[urgency=low]` and `[urgency=critical]` sections — mako's three urgency criteria
values are `low`/`normal`/`critical`, **not** `high`). The writer merges this with the user's
`position` / `timeout` / `behavior` picks.

```ini
font={{font_ui}} 11
width=340
height=120
margin=10
padding=14
border-size=2
border-radius=10
anchor={{anchor}}                     # top-right | top-center | top-left | bottom-right
layer=overlay
{{#if max-visible-5}}max-visible=5{{/if}}
{{#if app-icons}}icons=1
max-icon-size=48{{else}}icons=0{{/if}}
markup=1
format=<b>%s</b>\n%b
default-timeout={{timeout_ms}}        # answers.timeout * 1000, or 0 for "never"
ignore-timeout=1
{{#if group-by-app}}group-by=app-name{{/if}}

# --- colors (from rice palette via mako.tmpl) ---
background-color=#{{surface}}ee
text-color=#{{fg}}
border-color=#{{accent}}
progress-color=over #{{accent}}44

[urgency=low]
border-color=#{{muted}}

[urgency=critical]
border-color=#{{red}}
default-timeout=0                     # critical NEVER auto-dismisses — see styling.md

{{#if group-by-app}}
[grouped]
format=<b>%s</b>\n%b\n<small>(%g)</small>
{{/if}}

{{#if (eq utilities.osd_route "notification")}}
# --- OSD routing (utilities.osd_route == "notification") ---
# Volume/brightness keybinds fire `notify-send -a OSD …` instead of swayosd-client.
# This block themes those toasts to match the rest of the rice's palette (dusky pattern;
# avoids Matt-FTW's coherence-miss where the OSD falls back to stock GTK colors). The
# `-h int:value:N` hint renders the progress bar mako uses for transient OSDs.
[app-name=OSD]
default-timeout=900                    # short — OSD is transient, not actionable
border-color=#{{accent}}
background-color=#{{surface}}f2        # slightly more opaque than normal notifications
progress-color=over #{{accent}}
ignore-timeout=1
{{/if}}

[mode=do-not-disturb]
invisible=1
```

**Anchor map** (9b → `anchor=`): `top-right` → `top-right`, `top-center` → `top-center`,
`top-left` → `top-left`, `bottom-right` → `bottom-right`.

## dunst — `~/.config/dunst/dunstrc`

INI sections; `[global]` + `[urgency_*]` blocks. The rice-rendered `dunst.tmpl` contributes the
per-urgency colors (`background`/`foreground`/`frame_color`); this writer emits the layout +
behavior + reads those rendered colors back into the urgency sections.

```ini
[global]
    font = {{font_ui}} 11
    width = 340
    height = (0, 120)
    origin = {{origin}}               # top-right | top-center | top-left | bottom-right
    offset = (12, 12)
    corner_radius = 10
    frame_width = 2
    padding = 14
    horizontal_padding = 14
    separator_color = frame
    gap_size = 8
    corners = all                          # round every corner (dunst 1.10+)
    markup = full
    format = "<b>%s</b>\n%b"
    {{#if app-icons}}icon_position = left
    min_icon_size = 16
    max_icon_size = 48
    icon_corner_radius = 10                # round app icons to match the card (hyprdots)
    {{else}}icon_position = off{{/if}}
    progress_bar = true
    progress_bar_height = 8
    progress_bar_corner_radius = 4
    highlight = "#{{accent}}"              # progress_bar fill — themes volume/brightness OSD (catppuccin/dunst)
    {{#if group-by-app}}stack_duplicates = true
    hide_duplicate_count = false{{/if}}
    mouse_left_click = do_action, close_current
    mouse_middle_click = close_all
    mouse_right_click = context

[urgency_low]
    background = "#{{bg}}"
    foreground = "#{{muted}}"
    frame_color = "#{{surface}}"
    timeout = {{timeout_s}}

[urgency_normal]
    background = "#{{bg}}"
    foreground = "#{{fg}}"
    frame_color = "#{{accent}}"
    timeout = {{timeout_s}}

[urgency_critical]
    background = "#{{bg}}"
    foreground = "#{{fg}}"
    frame_color = "#{{red}}"
    timeout = 0                       # critical NEVER auto-dismisses

{{#if (eq utilities.osd_route "notification")}}
# --- OSD routing (utilities.osd_route == "notification") ---
# When volume/brightness binds use `notify-send -a OSD`, dunst can target the OSD app via
# a `[app_name="OSD"]` rule. Keeps the OSD palette coherent with the rest of the rice
# (avoids stock GTK fallback). The notification body still drives the progress bar via
# the existing `highlight = #{{accent}}` from `[global]`.
[osd_app]
    appname = "OSD"
    background = "#{{surface}}"
    foreground = "#{{fg}}"
    frame_color = "#{{accent}}"
    timeout = 1                       # transient — short
    history_ignore = yes              # don't clutter the history with OSD events
{{/if}}
```

`timeout_s` = `answers.timeout` (seconds). `0` for "never". `offset = (12, 12)` is the modern split
form; **do not** emit the legacy `geometry = "WxH-X+Y"` string.

## swaync — `~/.config/swaync/config.json` + `style.css`

Two files. `config.json` is **behaviour + widget array** (the panel layout is data, not CSS).
`style.css` is GTK CSS that `@import`s the rice-rendered `colors.css`.

### `config.json`

```json
{
  "positionX": "{{positionX}}",
  "positionY": "{{positionY}}",
  "control-center-width": 440,
  "timeout": {{timeout_s}},
  "timeout-low": 4,
  "timeout-critical": 0,
  "notification-window-width": 360,
  "fit-to-screen": true,
  "hide-on-clear": false,
  "hide-on-action": true,
  "script-fail-notify": true,
  "widgets": [
    "title",
    "dnd",
    "notifications",
    "mpris",
    "volume"
    {{#if has_backlight}}, "backlight"{{/if}}
    , "buttons-grid"
  ],
  "widget-config": {
    "title":   { "text": "Notifications", "clear-all-button": true, "button-text": "Clear All" },
    "dnd":     { "text": "Do Not Disturb" },
    "mpris":   { "show-album-art": "always", "autohide": false, "blacklist": [] },
    "volume":  { "label": "" },
    "buttons-grid": {
      "buttons-per-row": 4,
      "actions": [
        { "label": "", "command": "nm-connection-editor", "type": "toggle" },
        { "label": "", "command": "blueman-manager",       "type": "toggle" },
        { "label": "", "command": "hyprlock",              "type": "toggle" },
        { "label": "", "command": "wlogout",               "type": "toggle" }
      ]
    }
  }
}
```

**Position map** (9b → `positionX` / `positionY`):

| 9b answer | `positionX` | `positionY` |
|---|---|---|
| top-right    | `right`  | `top`    |
| top-center   | `center` | `top`    |
| top-left     | `left`   | `top`    |
| bottom-right | `right`  | `bottom` |

`has_backlight` is `true` iff `/sys/class/backlight` has at least one entry (laptop with internal
panel). On a desktop, **drop the `"backlight"` widget entirely** — see `gotchas.md`.

### `style.css`

```css
@import "colors.css";    /* rendered by rice from swaync.tmpl — exports @bg @fg @surface @muted @accent @accent2 @red */

* { font-family: "{{font_ui}}", "Symbols Nerd Font"; font-size: 14px; }

/* upstream selector chain: .notification-row > .notification-background > .notification.
   The .floating-notifications.background prefix scopes the toast (not the
   per-row entry inside .control-center). Mirrors ml4w + Matt-FTW. */
.floating-notifications.background .notification-row .notification-background .notification {
  border-radius: 10px;
  border: 2px solid @accent;
  margin: 6px 12px;
  background: alpha(@surface, 0.93);
  box-shadow: 0 2px 8px 0 rgba(0,0,0,0.6);
}
.floating-notifications.background .notification-row .notification-background .notification.critical {
  border-color: @red;
  box-shadow: inset 0 0 7px 0 @red;       /* Matt-FTW: critical reads instantly even in muted palettes */
}
.notification .summary { color: @fg; font-weight: bold; }
.notification .body,
.notification .time   { color: alpha(@fg, 0.8); }
.close-button {
  background: @surface; color: @fg;
  border-radius: 100%; min-width: 24px; min-height: 24px;
  margin: 8px 8px 0 0;
}

/* slide-out control center */
.control-center {
  background: alpha(@bg, 0.95);
  border: 1px solid @muted;
  border-radius: 12px;
  padding: 14px;
  color: @fg;
}
/* match the toast selector chain inside the panel too */
.control-center .notification-row .notification-background .notification.critical { border: 2px solid @red; }
.widget-dnd > switch:checked { background: @accent; }
.widget-title > button { background: @surface; color: @fg; border-radius: 8px; }

/* sliders — accent-filled trough, scoped to the slider widgets.
   GTK4 selector is `.<widget> trough highlight` (ml4w/glass, catppuccin/swaync).
   The unscoped `trough highlight` catches every progress bar (notification.critical
   progress included) — fine, but the scoped form prevents bleed-through into
   3rd-party themed sub-widgets. */
.widget-volume    trough highlight,
.widget-backlight trough highlight { background: @accent; }
slider { background: @fg; border-radius: 100%; }

.widget-buttons-grid flowboxchild > button.toggle:checked {
  background-color: @accent; color: @bg;
}
```

`@import "colors.css"` resolves to `~/.config/swaync/colors.css` — the rice engine writes that
file from `swaync.tmpl`. **Reference colors only by name** (`@accent`, `@red`, …); never inline
hex into `style.css`.

## What does NOT belong here

- The `exec-once = <daemon>` line. That's `components/autostart/`.
- The DND-toggle bind (`bind = $mainMod, N, exec, makoctl mode -t do-not-disturb` etc.). That's
  `components/keybinds/`, gated on `"dnd-bind" ∈ notifications.behavior`.
- The swaync `layerrule` blur block. That's `components/window-rules/`.
- The waybar `custom/notification` module. That's `components/waybar/`, gated on
  `notifications.daemon == "swaync"`.
- The rice-rendered colors file content. That's `theming/engine.md` + the per-daemon `.tmpl`.

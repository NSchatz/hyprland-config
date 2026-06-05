# notifications — template

Per-daemon recipes. The rice engine renders the **colors** portion from `palette.conf` via
`_shared/colors-contract.md`; the rest of the config is emitted by this component's writer from the
`notifications.*` answers. Every literal color shown below as `#{{accent}}` etc. is engine-rendered
— **never hardcode hex** in this component's output.

For the full styling library (anatomy, urgency conventions, swaync widget patterns,
battle-tested moves), see `styling.md`.

## mako — `~/.config/mako/config`

Single file holds layout + behavior + colors. Colors come from the rice-rendered `mako.tmpl`
(inline keys + a `[urgency=high]` section). The writer merges this with the user's `position` /
`timeout` / `behavior` picks.

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
    markup = full
    format = "<b>%s</b>\n%b"
    {{#if app-icons}}icon_position = left
    min_icon_size = 16
    max_icon_size = 48{{else}}icon_position = off{{/if}}
    progress_bar = true
    progress_bar_height = 8
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
    "mpris":   { "image-size": 96, "image-radius": 8 },
    "volume":  { "label": "" },
    "buttons-grid": {
      "actions": [
        { "label": "", "command": "nm-connection-editor" },
        { "label": "", "command": "blueman-manager" },
        { "label": "", "command": "hyprlock" },
        { "label": "", "command": "wlogout" }
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

.notification-row .notification {
  border-radius: 10px;
  border: 2px solid @accent;
  margin: 6px 12px;
  background: alpha(@surface, 0.93);
  box-shadow: 0 2px 8px 0 rgba(0,0,0,0.6);
}
.notification-row .notification.critical { border-color: @red; }
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
.widget-dnd > switch:checked { background: @accent; }
.widget-title > button { background: @surface; color: @fg; border-radius: 8px; }

/* sliders — accent-filled trough */
scale trough progress { background: @accent; }
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

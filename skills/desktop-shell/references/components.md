# Desktop Shell Components

Functional configs for the Wayland "shell" around Hyprland: the status bar, the app launcher, and
the notification daemon. This is the **structure/behavior** (modules, layout, behavior) — colors
come from the **rice** skill (each config `@import`s/includes the generated colors file).
Reload commands are in `apply-theme.sh` and below.

## Waybar

Two files in `~/.config/waybar/`: `config.jsonc` (modules) and `style.css` (look).

### `config.jsonc`

A modern **floating-islands** default (transparent bar + three rounded glass groups). For the full
styling-technique catalog (capsule formula, tinted-accent workspaces, drawer/slider groups, blink
keyframes, …) and the system/ecosystem module recipes (temperature hwmon path, `mpris`,
`idle_inhibitor`, swaync `custom/notification`, `group/drawer`), see
`${CLAUDE_PLUGIN_ROOT}/skills/hyprland-reference/references/styling/waybar.md`.

```jsonc
{
  "layer": "top",
  "position": "top",
  "height": 38,
  "spacing": 0,
  "margin-top": 8,
  "margin-left": 14,
  "margin-right": 14,
  "reload_style_on_change": true,

  "modules-left": ["hyprland/workspaces", "hyprland/window"],
  "modules-center": ["mpris", "clock"],
  "modules-right": ["cpu", "memory", "temperature", "pulseaudio", "network", "bluetooth", "idle_inhibitor", "tray"],

  "hyprland/workspaces": { "on-click": "activate", "format": "{id}", "sort-by-number": true },
  "hyprland/window": { "max-length": 60, "separate-outputs": true },
  "mpris": {
    "format": "{player_icon}  {title}",
    "format-paused": "{status_icon}  {title}",
    "player-icons": { "default": "▶", "spotify": "", "firefox": "󰈹" },
    "status-icons": { "playing": "", "paused": "" },
    "max-length": 40,
    "on-click": "playerctl play-pause"
  },
  "clock": {
    "format": "  {:%a %d %b  %H:%M}",
    "tooltip-format": "<tt><small>{calendar}</small></tt>"
  },
  "cpu": { "format": "  {usage}%", "interval": 2 },
  "memory": { "format": "  {percentage}%", "interval": 5 },
  "temperature": {
    "hwmon-path-abs": "/sys/devices/platform/coretemp.0/hwmon",
    "input-filename": "temp1_input",
    "critical-threshold": 85,
    "format": "{icon} {temperatureC}°C",
    "format-icons": ["", "", ""]
  },
  "pulseaudio": {
    "format": "{icon} {volume}%",
    "format-muted": "󰝟 muted",
    "format-icons": { "default": ["󰕿", "󰖀", "󰕾"] },
    "on-click": "pavucontrol",
    "scroll-step": 5
  },
  "network": {
    "format-wifi": "󰖩 {signalStrength}%",
    "format-ethernet": "󰈀 wired",
    "format-disconnected": "󰖪 off",
    "tooltip-format": "{ifname} {ipaddr}",
    "on-click": "nm-connection-editor"
  },
  "bluetooth": {
    "format": "",
    "format-connected": " {num_connections}",
    "format-off": "󰂲",
    "on-click": "blueman-manager"
  },
  "idle_inhibitor": { "format": "{icon}", "format-icons": { "activated": "", "deactivated": "" } },
  "tray": { "icon-size": 16, "spacing": 10 }
}
```

This default targets a **desktop**. On a laptop add `"battery"` (and `"backlight"`) to
`modules-right`. Either `//`-commented JSONC **or** strict comment-free JSON parses (waybar accepts
both; `reload_style_on_change` hot-reloads the CSS as you tweak). Match `modules-right` to installed
tools — every `on-click` assumes its tool exists (`pulseaudio`→`pavucontrol`,
`network`→`nm-connection-editor`, `bluetooth`→`blueman-manager`); drop the `on-click` or the whole
module if it's missing. The `temperature` `hwmon-path-abs` shown is **Intel `coretemp`**; on AMD use
`k10temp`/`Tctl`, and verify the path (zone numbers drift across boots) — see the styling reference.
The glyphs need a Nerd Font (see Fonts below); fall back to text labels if none is installed.

### `style.css`

```css
/* rice renders colors.css: @bg @fg @surface @muted @accent @accent2 @red @green @yellow */
@import "colors.css";

* {
  font-family: "JetBrainsMono Nerd Font", sans-serif;
  font-size: 13px; font-weight: bold; min-height: 0;
  border: none; border-radius: 0; box-shadow: none;
}

/* transparent bar -> three floating glass islands */
window#waybar { background: transparent; color: @fg; }
.modules-left, .modules-center, .modules-right {
  background: alpha(@bg, 0.78);
  border: 1px solid alpha(@accent, 0.18);
  border-radius: 16px; padding: 1px 6px;
  box-shadow: 0 6px 24px rgba(0,0,0,0.40), 0 1px 3px rgba(0,0,0,0.30);
}

/* workspaces: tinted-accent active (calmer than a solid fill) */
#workspaces button {
  color: @muted; padding: 0 9px; margin: 4px 2px;
  border: 1px solid transparent; border-radius: 10px; transition: all 0.2s ease;
}
#workspaces button.active { color: @accent; background: alpha(@accent,0.14); border-color: alpha(@accent,0.45); }
#workspaces button:hover  { color: @fg; background: alpha(@surface,0.6); }
#workspaces button.urgent { color: @red; background: alpha(@red,0.14); border-color: alpha(@red,0.45); }
#workspaces button.empty  { color: alpha(@muted,0.55); }

/* per-module hues from the rice palette */
#clock { color: @accent2; padding: 0 14px; }
#mpris { color: @green; padding: 0 10px; }
#mpris.playing { animation: nowplaying 2s ease-in-out infinite alternate; }
@keyframes nowplaying { from { color: @green; } to { color: @accent; } }
#cpu, #memory, #temperature, #pulseaudio, #network, #bluetooth, #idle_inhibitor, #tray, #window {
  padding: 0 9px; margin: 4px 2px; border-radius: 10px; transition: all 0.2s ease;
}
#cpu { color: @yellow; }
#memory { color: @green; }
#temperature { color: @accent2; }
#temperature.critical { color: @red; }
#pulseaudio { color: @accent; }
#pulseaudio.muted { color: @muted; }
#network { color: @accent2; }
#network.disconnected { color: @red; }
#bluetooth { color: @accent2; }
#idle_inhibitor.activated { color: @accent; }
#window { color: @fg; }
window#waybar.empty #window { color: @muted; }
#tray > .needs-attention { -gtk-icon-effect: highlight; }

tooltip { background: @bg; border: 1px solid alpha(@accent,0.4); border-radius: 10px; }
tooltip label { color: @fg; padding: 4px 6px; }
```

The translucent islands look muddy without compositor blur — add the Waybar `layerrule` block
(0.54+ form) in `hyprland.conf` so Hyprland blurs what's behind the bar (see
`${CLAUDE_PLUGIN_ROOT}/skills/hyprland-reference/references/styling/waybar.md` → *Transparency +
Hyprland blur*). Reload after editing either file: `killall -SIGUSR2 waybar` (config + style
hot-reload; with `reload_style_on_change: true`, CSS edits also reload on save).

## App launcher

For the styling-technique catalog (palette/layout split, the three selection idioms, icon-grid vs
pill-list, `em`/`%` sizing, blur) see
`${CLAUDE_PLUGIN_ROOT}/skills/hyprland-reference/references/styling/launchers.md`.

### wofi — `~/.config/wofi/config` + `style.css`

`config` (behavior; the look is in `style.css`):
```ini
show=drun
prompt=Search
width=600
height=400
location=center
insensitive=true          # case-insensitive matching
allow_images=true
image_size=24
no_actions=true           # don't show drun actions submenu
hide_scroll=true
matching=fuzzy
gtk_dark=true
key_expand=Tab
term=kitty                # terminal for run-in-terminal entries
```
`style.css`: `@import "colors.css";` then style `window/#input/#entry:selected` (see rice
templates). Launch: `wofi --show drun`. Read at launch — no reload. For frosted glass, add a
`layerrule` blur block for the `wofi` namespace in `hyprland.conf` (see launchers.md → Pitfalls).

### rofi — `~/.config/rofi/config.rasi`

```rasi
configuration {
    modi: "drun,run,window";
    show-icons: true;
    icon-theme: "Papirus";
    drun-display-format: "{name}";
    display-drun: "  Apps";
    display-run:  "  Run";
    display-window: "  Windows";
    drun-match-fields: "name,generic,exec,categories";
    kb-cancel: "Escape";
}
@theme "custom"      /* loads ~/.config/rofi/custom.rasi */
```

Put the colors import **inside the theme file** it points to — e.g. in
`~/.config/rofi/custom.rasi` add `@import "colors.rasi"` at the top, then reference the color names.
Use a **Wayland-capable** build (`rofi-wayland`, or rofi ≥ 2.0) so layer-shell blur/anchoring works;
classic X11 rofi runs through XWayland and ignores the `layerrule`. Launch: `rofi -show drun`.

## Notification daemon

**Run exactly one** — mako, dunst, and swaync all claim the `org.freedesktop.Notifications` D-Bus
name; the second to start exits. For the styling-technique catalog (DND mode, per-urgency accents,
rounded translucent cards, swaync widget stack) see
`${CLAUDE_PLUGIN_ROOT}/skills/hyprland-reference/references/styling/notifications.md`.

### mako — `~/.config/mako/config`

```ini
font=Sans 11
width=360
height=120
margin=10
padding=12
border-size=2
border-radius=8
anchor=top-right
layer=overlay
max-visible=5
icons=1
max-icon-size=48
markup=1
format=<b>%s</b>\n%b
default-timeout=5000
ignore-timeout=1
# colors come from rice: background-color / text-color / border-color / progress-color

[urgency=high]
default-timeout=0
# border-color set red by rice

[mode=do-not-disturb]
invisible=1
```
Toggle DND with `makoctl mode -t do-not-disturb`; dismiss with `makoctl dismiss` (`-a` for all).
Reload: `makoctl reload`.

### dunst — `~/.config/dunst/dunstrc`

dunst uses **INI sections** (`[section]` then indented `key = value` lines) — **not** brace blocks.
```ini
[global]
    font = Sans 11
    frame_width = 2
    corner_radius = 8
    origin = top-right
    offset = (12, 12)
    gap_size = 8
    separator_color = frame
    markup = full
    format = "<b>%s</b>\n%b"
    icon_position = left
    min_icon_size = 16
    max_icon_size = 48
    progress_bar = true
    mouse_left_click = do_action, close_current
    mouse_middle_click = close_all
    mouse_right_click = context

[urgency_low]
    timeout = 5

[urgency_normal]
    timeout = 8

[urgency_critical]
    timeout = 0
    # frame_color set red by rice
```
Per-urgency colors (`background`/`foreground`/`frame_color`) come from rice. Note
`offset = (x, y)` is the modern form (older configs used a `geometry` string). Reload:
`dunstctl reload`.

### swaync — `~/.config/swaync/config.json` + `style.css`

swaync adds a slide-out control center (DND toggle, MPRIS, sliders, quick toggles). The panel layout
is **data** in `config.json`'s `widgets` array, not CSS:
```json
{
  "positionX": "right",
  "positionY": "top",
  "control-center-width": 440,
  "timeout": 8,
  "timeout-low": 4,
  "timeout-critical": 0,
  "widgets": ["title", "dnd", "notifications", "mpris", "volume", "backlight", "buttons-grid"],
  "widget-config": {
    "title": { "text": "Notifications", "clear-all-button": true, "button-text": "Clear All" },
    "dnd": { "text": "Do Not Disturb" }
  }
}
```
`style.css` is **GTK CSS**: `@import "colors.css";` then style `.control-center`, `.notification`,
`.widget-dnd switch:checked`, and the slider `scale trough progress` (see notifications.md). For a
frosted control center, add a block-form `layerrule` blur on the `swaync-control-center` and
`swaync-notification-window` namespaces. Reload: `swaync-client -rs` (CSS), `swaync-client -R` (config).

## Fonts (glyphs)

Bars and notifications use icon glyphs from a **Nerd Font** (e.g. `ttf-jetbrains-mono-nerd`,
`ttf-firacode-nerd`). If none is installed, the glyphs render as tofu boxes — either install one or
switch the modules to plain text labels. Detect with `fc-list | grep -i nerd`. Do not install
fonts automatically — suggest the package. The font **catalog and selection** (and applying a
Nerd Font as the bar's `font-family`) live in the rice skill —
`${CLAUDE_PLUGIN_ROOT}/skills/rice/references/fonts.md`.

## Coordination with other skills

- **Colors**: never hardcode hex here — reference the rice colors file
  (`@import "colors.css"` / `colors.rasi`). Generate functional config here; theme it there.
- **Autostart**: `exec-once = waybar` / `mako` etc. live in the Hyprland config — the
  **rice** skill manages those. This skill writes the component's own config files.
- **All-in-one builds**: a from-scratch `rice` run (Mode A) already generates these functional
  configs itself, by reference to this file — so the user gets a working, themed shell in one pass.
  This standalone skill is for **editing just the bar/launcher/notifications later** (add a module,
  change position) without re-running the whole rice interview.

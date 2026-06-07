# waybar — template

This component owns three files under `~/.config/waybar/`:

| File | Owned by | Format |
|---|---|---|
| `config.jsonc` | this component (the writer) | **Strict JSON** in practice — see `gotchas.md`. |
| `style.css` | this component (the writer) | GTK3 CSS — opens with `@import "colors.css";`. |
| `colors.css` | the rice **engine** (`render-templates.sh`) | 12 `@define-color` names per [`_shared/colors-contract.md`](../../_shared/colors-contract.md). |

The recipe below is the **floating-islands / single-accent / smooth-motion / inline** default — the
most common interview path. Swap blocks per the schema; the long catalog of swappable patterns
lives in `styling.md`.

> **Color contract.** `style.css` may reference **only** the 12 `@define-color` names rice's
> `waybar.tmpl` emits — `@bg @fg @surface @muted @accent @accent2 @red @green @yellow @blue
> @magenta @cyan`. Don't add new names; don't hardcode hex. The GTK-CSS `alpha(@c, 0.8)` function
> is valid here (2-arg).

## `config.jsonc` — the default

A modern floating-islands desktop bar. Author this file via a Python script —
`json.dump(obj, f, ensure_ascii=False, indent=2)` — to keep the 4-byte MDI glyphs intact through
linters (see `gotchas.md`).

```jsonc
{
  "layer": "top",
  "position": "top",
  "height": 38,
  "spacing": 0,
  "margin-top": 8,
  "margin-left": 14,
  "margin-right": 14,
  "fixed-center": true,
  "ipc": true,
  "reload_style_on_change": true,

  "modules-left":   ["hyprland/workspaces", "hyprland/window"],
  "modules-center": ["mpris", "clock"],
  "modules-right":  ["cpu", "memory", "temperature", "pulseaudio", "network", "bluetooth", "idle_inhibitor", "tray"],

  "hyprland/workspaces": { "format": "{id}", "sort-by": "number" },
  "hyprland/window":     { "max-length": 60, "separate-outputs": true },

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
  "cpu":    { "format": "󰻠 {usage}%",    "interval": 2 },
  "memory": { "format": "󰍛 {percentage}%", "interval": 5 },
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
    "format-wifi":         "󰖩 {signalStrength}%",
    "format-ethernet":     "󰈀 wired",
    "format-disconnected": "󰖪 off",
    "tooltip-format":      "{ifname} {ipaddr}",
    "on-click":            "nm-connection-editor"
  },
  "bluetooth": {
    "format":           "",
    "format-connected": " {num_connections}",
    "format-off":       "󰂲",
    "on-click":         "blueman-manager"
  },
  "idle_inhibitor": { "format": "{icon}", "format-icons": { "activated": "", "deactivated": "" } },
  "tray":           { "icon-size": 16, "spacing": 10 }
}
```

**Laptop addendum.** When `IS_LAPTOP=1`, append `"battery"` (and `"backlight"` only when
`/sys/class/backlight/*` is non-empty — see `gotchas.md`) to `modules-right`:

```jsonc
"battery": {
  "states": { "warning": 30, "critical": 15 },
  "format": "{icon} {capacity}%",
  "format-charging": "󰂄 {capacity}%",
  "format-icons": ["", "", "", "", ""]
},
"backlight": {
  "format": "{icon} {percent}%",
  "format-icons": ["󰃞", "󰃟", "󰃠"]
}
```

**Swaync addendum.** Only when `notifications.daemon == "swaync"` (see `gotchas.md`):

```jsonc
"custom/notification": {
  "return-type": "json",
  "exec-if": "which swaync-client",
  "exec":    "swaync-client -swb",
  "on-click":       "swaync-client -t -sw",
  "on-click-right": "swaync-client -d -sw",
  "format": "{icon}", "tooltip": true, "escape": true,
  "format-icons": {
    "notification": "<span foreground='#f38ba8'><sup></sup></span>", "none": "",
    "dnd-notification": "<span foreground='#f38ba8'><sup></sup></span>", "dnd-none": "",
    "inhibited-notification": "<span foreground='#f38ba8'><sup></sup></span>", "inhibited-none": "",
    "dnd-inhibited-notification": "", "dnd-inhibited-none": ""
  }
}
```

Append `"custom/notification"` to `modules-right` (after `tray`).

**Power-menu addendum (defect #17).** When `utilities.selected` ∋ `power-menu`, the waybar
writer emits a `custom/power` module wired to the same `powermenu.sh` / `wlogout` the keybind
fires — without it the power utility is selected but never appears on the bar. The bar-module
contract is declared in [`_shared/expected-binds.md`](../../_shared/expected-binds.md) →
"Waybar modules". Append to `modules-right` (right of `tray`):

```jsonc
"custom/power": {
  // rofi flavor — driven by the shipped powermenu.sh
  "format": "⏻",
  "tooltip": false,
  "on-click": "~/.config/hypr/scripts/powermenu.sh"
  // wlogout flavor — substitute "wlogout -p layer-shell" for the on-click instead
}
```

The writer reads `utilities.selected` and the power-menu flavor (rofi vs wlogout) from
`utilities.power_menu_tool` (see `components/utilities/schema.md`) to pick the `on-click`
target. This is the same shape as the `keybinds` writer's `$mainMod, Escape` / `$mainMod
SHIFT, M` bind — both consume the contract instead of one writer guessing.

## MDI glyph table (verified, 4-byte safe)

These are the codepoints the writer must use for module icons. Authoring through Python's
`json.dump(ensure_ascii=False)` keeps them intact through linters; any 3-byte legacy PUA glyph
(U+E000–U+F8FF) **will be silently stripped on save** (see `gotchas.md`).

| Use | Glyph | Codepoint | Use | Glyph | Codepoint |
|---|---|---|---|---|---|
| cpu | 󰻠 | U+F0EE0 | memory | 󰍛 | U+F035B |
| clock | 󰥔 | U+F0954 | thermometer | 󰔏 | U+F050F |
| idle on (coffee) | 󰅶 | U+F0176 | idle off | 󰅷 | U+F0177 |
| mpris play | 󰐊 | U+F040A | mpris pause | 󰏤 | U+F03E4 |
| notif bell | 󰂚 | U+F009A | bell-outline | 󰂛 | U+F009B |
| power | 󰐥 | U+F0425 | updates | 󰚰 | U+F06B0 |
| volume low | 󰕿 | U+F057F | volume med | 󰖀 | U+F0580 |
| volume high | 󰕾 | U+F057E | mute | 󰝟 | U+F075F |
| wifi | 󰖩 | U+F05A9 | wifi-off | 󰖪 | U+F05AA |
| ethernet | 󰈀 | U+F0200 | bluetooth-off | 󰂲 | U+F00B2 |

Workspace **dots** use the Geometric-Shapes block (every font renders them, nothing strips them):
filled `●` (U+25CF) / hollow `○` (U+25CB).

## `style.css` — archetype by archetype

The opening four lines never change:

```css
@import "colors.css";

* {
  font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font", sans-serif;
  font-size: 13px; font-weight: bold; min-height: 0;
  border: none; border-radius: 0; box-shadow: none;
  font-feature-settings: '"zero", "ss01", "ss02", "ss03", "ss04", "ss05", "cv31"';
}
```

> `font-feature-settings` enables JetBrainsMono's dotted-zero (`zero`) + stylistic sets `ss01-05`
> and the alt `@`/`$` (`cv31`) — every JaKooLit theme sets this for crisper rendering at 13–14px.
> Harmless when the font isn't JetBrainsMono (other Nerd Fonts ignore unknown features).

### Archetype: `floating-islands` (default)

```css
window#waybar { background: transparent; color: @fg; }
.modules-left, .modules-center, .modules-right {
  background: alpha(@bg, 0.78);
  border: 1px solid alpha(@accent, 0.18);
  border-radius: 16px; padding: 1px 6px;
  box-shadow: 0 6px 24px rgba(0,0,0,0.40), 0 1px 3px rgba(0,0,0,0.30);
}
```

### Archetype: `separated-pills`

Every module gets its own pill; the **first and last touch the screen edge** unless you add a
margin (see `gotchas.md`).

```css
window#waybar { background: transparent; color: @fg; }
#workspaces, #window, #clock, #mpris, #cpu, #memory, #temperature,
#pulseaudio, #network, #bluetooth, #idle_inhibitor, #tray {
  background: alpha(@surface, 0.85);
  border-radius: 999px;
  padding: 2px 12px;
  margin: 6px 3px;
}
#workspaces { margin-left: 8px; }   /* first module on the left */
#tray       { margin-right: 8px; }  /* last module on the right */
```

### Archetype: `single-lozenge`

```css
window#waybar {
  background: transparent;
  border: 2px solid @accent;
  border-radius: 7rem;
}
#workspaces, #window, #clock, #mpris, #cpu, #memory, #temperature,
#pulseaudio, #network, #bluetooth, #idle_inhibitor, #tray { background: transparent; }
```

### Archetype: `edge-to-edge`

```css
window#waybar {
  background: alpha(@bg, 0.92);
  border-bottom: 1px solid alpha(@accent, 0.25);
  border-radius: 0;
}
```

### Workspace indicator (the `pill-fill` default)

```css
#workspaces button {
  color: @muted; padding: 0 9px; margin: 4px 2px;
  border: 1px solid transparent; border-radius: 10px;
  transition: all 0.2s ease;
}
#workspaces button.active { color: @accent; background: alpha(@accent,0.14); border-color: alpha(@accent,0.45); }
#workspaces button:hover  { color: @fg;     background: alpha(@surface,0.6); }
#workspaces button.urgent { color: @red;    background: alpha(@red,0.14);    border-color: alpha(@red,0.45); }
#workspaces button.empty  { color: alpha(@muted,0.55); }
```

Indicator variants (`underline`, `dots`, `numbers`) are in `styling.md` →
*Workspaces & active state*; swap this block, leave the rest.

### Per-module hues (the `single` accent-strategy default, with state cues)

```css
#clock   { color: @accent2; padding: 0 14px; }
#mpris   { color: @green;   padding: 0 10px; }
#mpris.playing { animation: nowplaying 2s ease-in-out infinite alternate; }
@keyframes nowplaying { from { color: @green; } to { color: @accent; } }

#cpu, #memory, #temperature, #pulseaudio, #network, #bluetooth,
#idle_inhibitor, #tray, #window {
  padding: 0 9px; margin: 4px 2px; border-radius: 10px;
  transition: all 0.2s ease;
}
#cpu                  { color: @yellow; }
#memory               { color: @green; }
#temperature          { color: @accent2; }
#temperature.critical { color: @red; }
#pulseaudio           { color: @accent; }
#pulseaudio.muted     { color: @muted; }
#network              { color: @accent2; }
#network.disconnected { color: @red; }
#bluetooth            { color: @accent2; }
#idle_inhibitor.activated { color: @accent; }
#window               { color: @fg; }
window#waybar.empty #window { color: @muted; }
#tray > .needs-attention { -gtk-icon-effect: highlight; }

tooltip       { background: @bg; border: 1px solid alpha(@accent,0.4); border-radius: 10px; }
tooltip label { color: @fg; padding: 4px 6px; }
```

The full library of motion variants (blink-critical, opacity-breathe, spring overshoot, conditional
backdrop) is in `styling.md` → *Motion & state animation*.

## Vertical / dual / dock — the other forms

These restructure `config.jsonc` enough that they get their own recipe blocks in `styling.md`:

- **Vertical** — `"position": "left"`, `width` ≈ 32–44, `rotate: 90/270`, two-line clock formats,
  vertical sliders in drawers, edge-hugging asymmetric `border-radius`.
- **Dual** — `config.jsonc` is a JSON **array** of two named bar objects (`top`/`bottom`); CSS
  targets each via `window#waybar.top { ... }` / `.bottom#workspaces { ... }`.
- **Dock / ChromeOS-shelf / macOS / Win10** — `position: bottom`, `wlr/taskbar` as the actual dock,
  `border-radius: 24px 24px 0 0`, status-pill grouping via first/last-child rounding.

For each form, read `styling.md` → *Bar form* and adapt the relevant section above.

## `colors.css` — emitted by the engine

The engine renders `~/.config/waybar/colors.css` from `palette.conf` via the template at
`skills/rice/references/components/waybar/waybar.tmpl`:

```css
/* Generated by hypr-rice — @import "colors.css"; from waybar/style.css. */
@define-color bg      #{{bg}};
@define-color fg      #{{fg}};
@define-color surface #{{surface}};
@define-color muted   #{{muted}};
@define-color accent  #{{accent}};
@define-color accent2 #{{accent2}};
@define-color red     #{{red}};
@define-color green   #{{green}};
@define-color yellow  #{{yellow}};
@define-color blue    #{{blue}};
@define-color magenta #{{magenta}};
@define-color cyan    #{{cyan}};
```

Those 12 names are the contract — see [`_shared/colors-contract.md`](../../_shared/colors-contract.md)
(waybar row).

## What does NOT belong here

- The `exec-once = waybar` autostart line → [`autostart`](../autostart/).
- The `layerrule { ... blur = true; ... }` block that makes translucency look right →
  [`window-rules`](../window-rules/).
- Window gaps / rounding / blur on **windows** → [`look-feel`](../look-feel/).
- The Nerd Font itself → [`theming/fonts.md`](../../theming/fonts.md) (this component just assumes
  it's installed).

# waybar look - floating-islands

The `bar.archetype = floating-islands` look. Read this **and** the component's shared recipe set
(`../template.md`, `../styling.md`, `../gotchas.md`, `../validation.md`,
`../reload.md`); do not read
the other files in `looks/`.

## Contents

- What the look is
- `style.css` skeleton
---

## What the look is

**(a) Floating island bar** — *the dominant modern look* (HyDE, ml4w themes, countless r/unixporn posts). Bar itself is transparent and detached via `margin`; the three module groups become opaque rounded islands.
```css
window#waybar { background: transparent; }
.modules-left, .modules-center, .modules-right {
    background: rgba(30, 30, 46, 0.85);
    border-radius: 14px;
    padding: 0 8px;
    margin: 6px;
}
```
Pair with the `layerrule … blur = true` block (above) for the frosted-glass effect.
---

## `style.css` skeleton

### Archetype: `floating-islands` (default)

```css
window#waybar { background: transparent; color: @fg; }
.modules-left, .modules-center, .modules-right {
  background: alpha(@bg, 0.78);
  border: 1px solid alpha(@accent, 0.18);
  border-radius: 16px; padding: 1px 6px;
  /* No box-shadow on the default — GTK/cairo renders heavy shadows on small
   * rounded translucent surfaces as a visible rectangular halo on most stacks.
   * The base `box-shadow: none` in `* { … }` takes over. The "elevated" knob
   * below opts back in to a light single-layer shadow for users who want it. */
}
```

To opt back in to a soft elevation (use sparingly — see `styling.md`):

```css
.modules-left, .modules-center, .modules-right {
  box-shadow: 0 1px 2px rgba(0,0,0,0.20);
}
```
---

## Tasteful default recipe

A floating-island bar: workspaces left, clock center, system tray + network + volume + battery right. Palette-driven using the plugin's rice keys (hex without `#`). The rice engine renders a `colors.css` for Waybar, so `@import` it and reference the variables.

**`config.jsonc`**
```jsonc
{
    "layer": "top",
    "position": "top",
    "height": 36,
    "spacing": 4,
    "margin-top": 6,
    "margin-left": 8,
    "margin-right": 8,

    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["tray", "network", "pulseaudio", "battery"],

    "hyprland/workspaces": {
        "format": "{icon}",
        "on-click": "activate",
        "format-icons": {
            "active": "",
            "default": ""
        }
    },
    "clock": {
        "format": "{:%a %d %b  %H:%M}",
        "format-alt": "{:%Y-%m-%d %H:%M:%S}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    "tray": { "icon-size": 16, "spacing": 8 },
    "network": {
        "format-wifi": "  {signalStrength}%",
        "format-ethernet": " ",
        "format-disconnected": "󰖪 ",
        "tooltip-format": "{ifname} {ipaddr}",
        "on-click": "nm-connection-editor"
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "󰝟 muted",
        "format-icons": { "default": ["", "", ""] },
        "on-click": "pavucontrol"
    },
    "battery": {
        "states": { "warning": 30, "critical": 15 },
        "format": "{icon} {capacity}%",
        "format-charging": "󰂄 {capacity}%",
        "format-icons": ["", "", "", "", ""]
    }
}
```

**`style.css`** (rice placeholders — `#{{key}}` is substituted by the rice engine)
```css
@import "colors.css";

* {
    font-family: "{{font_mono}}", "Symbols Nerd Font";
    font-size: 14px;
    font-weight: bold;
    min-height: 0;
}

/* transparent bar -> floating islands */
window#waybar {
    background: transparent;
    color: #{{fg}};
}

.modules-left, .modules-center, .modules-right {
    background: rgba({{bg.r}}, {{bg.g}}, {{bg.b}}, 0.85);
    border-radius: 14px;
    padding: 0 6px;
    margin: 4px;
}

/* workspaces */
#workspaces button {
    color: #{{muted}};
    padding: 0 8px;
    margin: 4px 2px;
    border-radius: 10px;
    background: transparent;
    transition: all 0.2s ease;
}
#workspaces button.active {
    color: #{{bg}};
    background: #{{accent}};
}
#workspaces button:hover {
    color: #{{fg}};
    background: rgba({{surface.r}}, {{surface.g}}, {{surface.b}}, 0.6);
}
#workspaces button.urgent {
    color: #{{bg}};
    background: #{{red}};
}

/* center + right modules */
#clock { color: #{{accent2}}; padding: 0 14px; }
#tray, #network, #pulseaudio, #battery {
    padding: 0 10px;
    margin: 4px 2px;
}
#network    { color: #{{blue}}; }
#pulseaudio { color: #{{cyan}}; }
#battery    { color: #{{green}}; }

/* states */
#battery.warning  { color: #{{yellow}}; }
#battery.critical { color: #{{red}}; }
#battery.charging { color: #{{green}}; }

/* tooltip */
tooltip {
    background: #{{surface}};
    border: 1px solid #{{accent}};
    border-radius: 10px;
}
tooltip label { color: #{{fg}}; padding: 4px; }
```

**Worked example — Catppuccin Mocha** (`bg 1e1e2e`, `fg cdd6f4`, `surface 313244`, `accent cba6f7`, `accent2 89b4fa`). Substituting the loadbearing lines:
```css
* { font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font"; }
window#waybar { background: transparent; color: #cdd6f4; }
.modules-left, .modules-center, .modules-right {
    background: rgba(30, 30, 46, 0.85);   /* 1e1e2e @ 0.85 */
    border-radius: 14px; padding: 0 6px; margin: 4px;
}
#workspaces button.active { color: #1e1e2e; background: #cba6f7; }   /* accent on focus */
#workspaces button:hover  { background: rgba(49, 50, 68, 0.6); }     /* surface 313244 */
#clock   { color: #89b4fa; }    /* accent2 */
#battery { color: #a6e3a1; }    /* green */
tooltip  { background: #313244; border: 1px solid #cba6f7; }
```
If you prefer the official Catppuccin port's variable style, `@import "mocha.css";` and reference `@text`, `@base`, `@mauve`, `@blue`, with `alpha(@base, 0.85)` for the translucent group bg.

Then enable blur in `hyprland.conf` (0.54.x block form — see `../../window-rules/template.md`):
```conf
layerrule {
    name = blur-waybar
    match:namespace = waybar
    blur = true
    ignore_alpha = 0.1
}
```

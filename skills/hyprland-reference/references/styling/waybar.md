# Styling Waybar

Waybar is the de-facto status bar for Hyprland. This page is about making it *look* good: the geometry, shape, color, and typography knobs that turn a flat grey bar into the floating, glassy, pill-module bars you see on r/unixporn — grounded in how HyDE, JaKooLit, ml4w, and Catppuccin actually do it.

## What you're styling

Two files, two jobs. Both live in `~/.config/waybar/`.

| File | Format | Controls |
|------|--------|----------|
| `config.jsonc` | JSONC (JSON + comments) | **Layout & behavior**: `position`, `height`, `spacing`, `margin-*`, which modules appear in `modules-left` / `modules-center` / `modules-right`, and each module's options (`format`, `format-icons`, `on-click`, etc.) |
| `style.css` | GTK3 CSS (a *subset* of CSS) | **The visual**: backgrounds, `border-radius`, `padding`/`margin`, `color`, `font-family`, `font-size`, hover/active/urgent states, tooltips |

Reload after editing **either** file without a full restart:

```bash
killall -SIGUSR2 waybar
```

`SIGUSR2` re-reads config + CSS in place. (`SIGUSR1` toggles visibility.) If you changed `position`/`exclusive`/`gtk-layer-shell` and things look wrong, do a hard restart: `killall waybar; waybar & disown`.

> Note: GTK3 CSS is **not** web CSS. No flexbox, no `gap`, no `transform`, no `calc()`, limited `box-shadow`. You get `background`/`background-color`, `color`, `border`/`border-radius`, `padding`, `margin`, `min-width`/`min-height`, `font-*`, `opacity`, `transition`, and `@keyframes` animations. Color helpers: `alpha(@c, 0.6)`, `shade(@c, 0.9)`, `mix(@a, @b, 0.5)`.

## Design anatomy — the knobs that change the look

**Bar geometry** — the single biggest "look" lever.
- `"position": "top"` (or `"bottom"`). Top is conventional; bottom reads more like a dock.
- `"height": 34` — a tight bar is ~30–40px; chunky pill bars run 40–48px. (HyDE/JaKooLit drive height via font-size %, not a fixed px.)
- `"margin-top"/"-bottom"/"-left"/"-right"`: non-zero margins **detach** the bar from the screen edge → the *floating bar* look. Pair with `"exclusive": true` (default) so windows still avoid it, or `false` to let windows slide under.
- `"spacing": 4` — pixels between modules in a group. Set to `0` when you want modules to fuse into one pill, larger when you want separated pills.

**Module shape** — turns flat text into pills/islands.
- `border-radius` on a module (or on a `.modules-*` group) = rounded pill. Common values: `8px`–`12px` for soft pills, `16px`+ or `border-radius: 999px` for fully-round capsules.
- `padding: 0 12px` gives modules horizontal breathing room; without it glyphs touch the rounded edges.
- `margin: 4px 6px` separates adjacent pills. Apply to individual modules for the *separated pills* archetype, or to the three `.modules-*` boxes for the *grouped island* archetype.

**Color & transparency.**
- Backgrounds use `rgba()` or `alpha(@color, a)`. The alpha channel is everything: `rgba(30,30,46, 0.85)` is a tasteful translucent surface; `0.6` is glassy; `1.0` is solid.
- A common, clean pattern: **transparent bar, opaque-ish module groups** — `window#waybar { background: transparent; }` then give each `.modules-*` box a translucent surface bg. This is the floating-island recipe.
- Accent color goes on the **active workspace**, **hover**, and one or two signal modules (battery-charging, network). Per-module accents (volume = blue, battery = green, clock = mauve) read as intentional, not noisy — use sparingly.

**Typography.**
- `font-family` **must be a Nerd Font** (or include one in the stack) or every module icon renders as a tofu box (▯). Good picks: `"JetBrainsMono Nerd Font"`, `"FiraCode Nerd Font"`, `"CaskaydiaCove Nerd Font"`. Install e.g. `ttf-jetbrains-mono-nerd`.
- `font-size`: 13–15px is the sweet spot. JaKooLit and HyDE scale the whole bar by setting `font-size` as a **percentage** (e.g. `97%`, bump to `104%` on 4K) so geometry tracks the font.
- `font-weight: bold;` on the workspace/clock reads crisper on a translucent bg.

**Transparency + Hyprland blur.** A translucent bar over a busy wallpaper looks muddy *unless the compositor blurs what's behind it*. Add a layer rule in `hyprland.conf` targeting Waybar's layer namespace (`waybar`). **On Hyprland 0.54.x use the block form — the single-line `layerrule = blur, waybar` is rejected** (`invalid field blur: missing a value`) and fails the whole reload. The current (0.54+) form, with the required `name` key (see `../window-rules.md`):

```conf
layerrule {
    name = blur-waybar
    match:namespace = waybar
    blur = true
    ignore_alpha = 0.1   # don't blur the fully-transparent gaps between pills
}
```

On **older targets (pre-0.53)** use the single-line form instead (`layerrule = blur, waybar` / `layerrule = ignorealpha 0.1, waybar`). Pick the form by version; never mix them for one rule.

Confirm the namespace with `hyprctl layers` (look for `namespace: waybar`). Known quirk: blur may not apply to the bar until the first window opens on that workspace ([Hyprland #6130](https://github.com/hyprwm/Hyprland/issues/6130)).

**Icons / glyphs & states.**
- Module text comes from `format` strings with `{icon}` placeholders resolved by `format-icons` (an array picked by level, or a keyed map). E.g. battery `"format-icons": ["", "", "", "", ""]`, volume keyed by `"headphone"`/`"default"`.
- Stateful classes you can target in CSS:

| Selector | When |
|----------|------|
| `#workspaces button.active` | focused workspace (Hyprland). Sway uses `button.focused` |
| `#workspaces button.urgent` | urgent window on that workspace |
| `#workspaces button:hover` | pointer hover |
| `#battery.warning`, `#battery.critical`, `#battery.charging` | driven by `"states"` thresholds |
| `tooltip`, `tooltip label` | the hover popup — style it too, or it stays default-GTK ugly |

## How the community styles it

Five recognizable archetypes. Most popular dotfiles ship one of these:

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

**(b) Edge-to-edge solid bar** — the classic Waybar default and many minimalist Sway rices. No margins, `exclusive: true`, a solid or lightly-translucent full-width bar, square corners. The official sample uses `background: rgba(43,48,59, 0.5); border-bottom: 3px solid rgba(100,114,125,0.5);` with `#workspaces button.focused { border-bottom: 3px solid white; }`.

**(c) Per-module separated pills** — every module is its own floating capsule. Achieved with `margin` + `border-radius` on **individual** module IDs and a transparent bar. High visual separation; reads "techy".
```css
#clock, #battery, #network, #pulseaudio, #tray {
    background: rgba(49, 50, 68, 0.9);
    border-radius: 999px;
    padding: 2px 12px;
    margin: 6px 3px;
}
```

**(d) Single grouped pill** — one continuous rounded capsule per side with `spacing: 0`, internal dividers via subtle `border` between modules. HyDE leans on this with its `group/pill` and `group/leaf-inverse` Waybar groups; the inner radius is computed to match Hyprland's window rounding.

**(e) Minimal mono** — JetBrains/Fira Nerd mono font, near-monochrome (`@text` on transparent), accent used *only* on the active workspace dot. Tiny height, `spacing` tight. Common in "clean desktop" showcases.

**Project idioms worth stealing:**
- **HyDE** (`HyDE-Project/HyDE`): layouts in `~/.config/waybar/layouts/`, matched style by basename in `styles/`; a 4-layer CSS cascade (`defaults.css` → wallbash-generated palette → `theme.css` → `user-style.css`). Border-radius and font-size live in generated `includes/` files derived from Hyprland's rounding. Don't hand-edit the symlinked `config`/`style.css` — edit `user-style.css`.
- **JaKooLit** (`JaKooLit/Hyprland-Dots`): `config` and `style.css` are **symlinks** into `configs/` and `styles/`. Switch with `SUPER+ALT+B` (layout) / `SUPER+CTRL+B` (style). Default font-size `97%`. Edit copies, never the symlinks.
- **ml4w** (`mylinuxforwork/dotfiles`): theme folders under `~/.config/waybar/themes/<name>/` each with their own `config`/`style.css`/`modules.json`. Override by making `config-custom` / `style-custom.css`. Colors fed by matugen.
- **Catppuccin** (`catppuccin/waybar`): drop `mocha.css` next to `style.css`, `@import "mocha.css";` at top, reference `@text`/`@base`/`@mauve` etc., and use `alpha()`/`shade()` for translucency.
- **end-4** (`end-4/dots-hyprland`): *not Waybar* — it uses a custom AGS/Quickshell shell. Great for visual inspiration, but none of its styling transfers to a `style.css`.

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

Then enable blur in `hyprland.conf` (0.54.x block form — see `../window-rules.md`):
```conf
layerrule {
    name = blur-waybar
    match:namespace = waybar
    blur = true
    ignore_alpha = 0.1
}
```

## Pitfalls

- **Tofu boxes (▯) instead of icons** — `font-family` isn't a Nerd Font, or the Nerd Font isn't installed. Always list a Nerd Font first (and `"Symbols Nerd Font"` as a fallback for raw glyphs).
- **Muddy translucency** — translucent bar with **no** `layerrule … blur` block, so the wallpaper bleeds through at full sharpness. Add the blur rule; add `ignore_alpha = 0.1` so the transparent gaps between pills aren't blurred into a haze.
- **Harsh pure-black, full-opacity bg** (`#000` / `rgba(0,0,0,1)`) — reads heavy and dated. Use your palette `bg` at `0.8–0.9` alpha instead.
- **Inconsistent `border-radius`** — bar islands at `14px` but inner workspace buttons at `4px` looks accidental. Keep inner radius a notch smaller than outer (e.g. islands `14`, buttons `10`).
- **Modules touching / text clipped by rounded edges** — no `padding` or `min-width`. Give every module `padding: 0 10px` (and `min-width` for jittery ones like clock/battery so the bar doesn't reflow each second).
- **Oversized/undersized tray icons** — set `"icon-size": 16` and `"spacing"` in the tray module; default-size tray icons rarely match your font scale.
- **Wrong active-workspace class** — Hyprland uses `button.active`; `button.focused` is Sway. Styling `.focused` on Hyprland silently does nothing.
- **Editing the symlink** — on JaKooLit/HyDE/ml4w, `style.css` is a managed symlink; edits get clobbered on theme switch. Edit the real style file or the dedicated `user-style.css` / `style-custom.css` override.
- **Forgetting to reload** — CSS changes need `killall -SIGUSR2 waybar`; layout/`gtk-layer-shell` changes often need a full restart.

## Sources

- Waybar Styling wiki (selectors, states, GTK CSS subset): https://github.com/Alexays/Waybar/wiki/Styling
- Waybar default `config.jsonc` (module syntax, format-icons): https://github.com/Alexays/Waybar/blob/master/resources/config.jsonc
- Floating-bar discussion (margins, transparent bar, passthrough): https://github.com/Alexays/Waybar/discussions/2594
- HyDE Waybar architecture (layouts/styles, CSS cascade, group/pill): https://deepwiki.com/HyDE-Project/HyDE/7-status-bar-(waybar) and https://hydeproject.pages.dev/de/configuring/waybar/
- JaKooLit Hyprland-Dots — Customizing Waybar (symlink model, font %): https://github.com/JaKooLit/Hyprland-Dots/wiki/Customizing_waybar
- ml4w dotfiles Waybar wiki (theme folders, custom overrides): https://github.com/mylinuxforwork/dotfiles/wiki/Waybar
- Catppuccin Waybar port (`@import`, `@define-color`, alpha/shade): https://github.com/catppuccin/waybar and `themes/mocha.css`
- Hyprland blur-on-waybar quirk: https://github.com/hyprwm/Hyprland/issues/6130
- Hyprland layer rules reference: https://deepwiki.com/hyprwm/hyprland-wiki/3.4-layer-rules

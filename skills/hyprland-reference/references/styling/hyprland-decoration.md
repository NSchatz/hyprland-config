# Styling the Hyprland Look (gaps · borders · rounding · blur · shadow · animations)

This is the page for the *compositor's own* aesthetic — the floating-gap layout, the gradient
border around the focused window, rounded corners, frosted blur behind transparent surfaces, drop
shadows, and the way windows glide on and off screen. It lives in three blocks of `hyprland.conf`:
`general{}`, `decoration{}`, and `animations{}`. Get these right and the desktop reads as
"designed" before you touch a single bar or launcher.

All values below are verified against the **shipped default config on Hyprland 0.54.3**
(`/usr/share/hypr/hyprland.conf`) and the wiki Variables table. Where syntax is version-sensitive,
it is flagged. Apply changes live with `hyprctl reload` (then `hyprctl configerrors` to confirm a
clean parse).

> Version note: the upstream wiki examples migrated to a **Lua** config format in v0.55+
> (`hl.config{}`, `hl.curve{}`, `hl.animation{}`). This plugin targets the classic **hyprlang
> `.conf`** syntax (`option = value`, `bezier = …`, `animation = …`), which 0.4x–0.54 use and
> which 0.55 still reads. Everything here is hyprlang.

## What you're styling

```ini
general {
    gaps_in = 5                 # gap between adjacent windows
    gaps_out = 20               # gap between windows and screen edge
    border_size = 2             # outline thickness in px
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg   # gradient on focused window
    col.inactive_border = rgba(595959aa)
    layout = dwindle            # or master
}

decoration {
    rounding = 10               # corner radius in layout px
    rounding_power = 2          # corner curve exponent (0.45+); 2 = circle, higher = squircle
    active_opacity = 1.0
    inactive_opacity = 1.0

    blur {
        enabled = true
        size = 3
        passes = 1
        vibrancy = 0.1696
    }

    shadow {
        enabled = true
        range = 4
        render_power = 3
        color = rgba(1a1a1aee)
    }
}

animations {
    enabled = yes
    bezier = easeOutQuint, 0.23, 1, 0.32, 1
    animation = windows, 1, 4.79, easeOutQuint
    # ... (full set below)
}
```

Reload after edits: `hyprctl reload`. Inspect a live value: `hyprctl getoption decoration:rounding`.

The `blur{}` and `shadow{}` **subcategories** are the modern form (0.40+). The old flat keys
(`blur = true`, `blur_size`, `drop_shadow`, `shadow_range`, `col.shadow`) are deprecated — see
`deprecations.md`. `rounding_power` exists only on **0.45+**.

## Design anatomy — the knobs that change the look

### Spacing — `general:gaps_in` / `gaps_out`
The single biggest lever on "feel." Both accept CSS-style multi-values (`gaps_out = 10 20` for
vertical/horizontal, or four values).

| | airy / floating | balanced (default) | dense / efficient |
|---|---|---|---|
| `gaps_in` | 6–8 | **5** | 2–3 |
| `gaps_out` | 20–30 | **20** | 6–10 |

Big `gaps_out` makes every window look like it floats on the wallpaper (the unixporn signature).
Small/zero gaps maximize screen real estate for a tiling-purist look.

### Borders — `border_size` + `col.active_border` / `col.inactive_border`
- `border_size`: **1–4**. `0` removes the outline entirely (clean, but you lose the focus cue —
  pair with opacity/shadow instead). Default `2` is a good middle.
- **The signature gradient border.** `col.active_border` takes one or more `rgba()`/`rg8` colors,
  and with two-plus colors **plus an angle** it renders a gradient:
  ```ini
  col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
  ```
  This is *the* recognizable Hyprland accent. Tie both stops to your palette accent(s).
  `col.inactive_border` is usually a single muted color (`rgba(595959aa)`) so only the focused
  window "lights up." Colors are `rgba(RRGGBBAA)` hex (note: alpha last, no `#`), or `$vars`.

### Rounding — `decoration:rounding` (+ `rounding_power`)
- `rounding`: **8–16** is the tasteful band; `10` is the default. `0` = sharp corners.
- `rounding_power` (0.45+): exponent on the corner curve. `2.0` is a true circle quarter; **2.3–4**
  gives a softer "squircle" (iOS-like) corner that many modern rices prefer. Default `2`.
- Rounding without any border or shadow can look slightly "floaty/cut-out" — see Pitfalls.

### Transparency — `active_opacity` / `inactive_opacity` (+ `dim_inactive`)
- `active_opacity` / `inactive_opacity`: **0.0–1.0**. The classic rice move is
  `active_opacity = 1.0`, `inactive_opacity = 0.90–0.95` — focused window crisp, background windows
  slightly recede. `fullscreen_opacity = 1.0` keeps fullscreen apps solid.
- `dim_inactive = true` + `dim_strength` (default `0.5`) darkens unfocused windows instead of (or
  with) opacity — a calmer alternative to transparency.
- **Opacity is what makes blur visible.** A fully opaque window shows no blur behind it.

### Blur — `decoration:blur{}`
Kawase background blur, seen through transparent windows and layer surfaces (bars, launchers).

| key | default | range / effect |
|---|---|---|
| `size` | 3 | 1–12; blur radius/distance |
| `passes` | 1 | 1–4; more = smoother but **GPU-heavy** (2 is the sweet spot) |
| `vibrancy` | 0.1696 | 0–1; saturation boost of blurred colors (keeps it from going grey) |
| `vibrancy_darkness` | 0.0 | vibrancy effect on dark areas |
| `noise` | 0.0117 | film-grain to fight banding |
| `contrast` | 0.8916 | blurred-layer contrast |
| `brightness` | 0.8172 | blurred-layer brightness |
| `new_optimizations` | true | keep on; large speedup |
| `xray` | false | floating windows blur the wallpaper, ignoring tiled windows under them |
| `popups` | false | also blur right-click menus/popups |
| `special` | false | blur behind the special workspace |

Rule of thumb: `size 5–8`, `passes 2` for a rich frosted-glass look; `size 3`, `passes 1` for a
light touch.

### Shadow — `decoration:shadow{}`
Drop shadow that separates floating/rounded windows from the wallpaper.

| key | default | effect |
|---|---|---|
| `enabled` | true | |
| `range` | 4 | shadow size in px; **6–25** for a pronounced lift |
| `render_power` | 3 | 1–4; falloff steepness (higher = tighter, darker edge) |
| `sharp` | false | hard-edged shadow instead of soft |
| `color` | rgba(1a1a1aee) | shadow color+alpha; lower the alpha (`…66`) for subtlety |
| `color_inactive` | unset | separate shadow tint for unfocused windows |
| `offset` | 0 0 | x/y push (e.g. `0 4` for a "light from above" drop) |
| `scale` | 1.0 | shadow scale |

### Animation feel — `animations:bezier` + `animation`
- `bezier = NAME, x0, y0, x1, y1` defines a cubic-Bézier curve. **Y values >1 overshoot** (the
  springy "bounce past then settle" feel); `linear` is `0,0,1,1`.
- `animation = NAME, ONOFF, SPEED, CURVE [, STYLE]` — **SPEED is in deciseconds** (1 ds = 100 ms),
  so *lower = faster*. `STYLE` is per-item: `popin 87%`, `slide [dir]`, `fade`, `slidefade`, etc.
- Animatable items (children inherit from parents): `global` → `windows`(`windowsIn`/`windowsOut`/
  `windowsMove`), `layers`(`layersIn`/`layersOut`), `fade`(`fadeIn`/`fadeOut`/`fadeLayersIn`/…),
  `border`, `borderangle`, `workspaces`(`workspacesIn`/`workspacesOut`), `specialWorkspace`,
  `zoomFactor`.
- **Snappy vs smooth** is mostly the SPEED numbers: low single-digit speeds + an `easeOutQuint`-type
  curve feel quick and modern; larger speeds (7–10) feel relaxed/cinematic.
- `borderangle` with `, 1, 100, liner, loop` makes the gradient border slowly *rotate* — a popular
  flourish (`liner` = `1,1,1,1`, a constant-velocity curve used for loops).

## How the community styles it

A few recognizable "feels" you'll see across r/unixporn and the big dotfile projects:

**The unixporn floating signature.** Big outer gaps, a 2px gradient border in the palette accent,
moderate rounding, blur behind slightly-transparent windows, soft shadow:
```ini
general { gaps_in = 6; gaps_out = 20; border_size = 2
          col.active_border = rgba(cba6f7ff) rgba(89b4faff) 45deg }   # e.g. Catppuccin mauve→blue
decoration { rounding = 12; inactive_opacity = 0.92
             blur { size = 6; passes = 2; vibrancy = 0.17 }
             shadow { range = 12; color = rgba(00000055) } }
```
This is the look most people mean by "a Hyprland rice." Swap the two border stops for your accent.

**Minimal no-gaps tiling.** `gaps_in = 0–2`, `gaps_out = 0–6`, `border_size = 1`, `rounding = 0`,
no blur, no shadow, near-instant animations (or `animations { enabled = no }`). Maximizes space;
favored by keyboard-driven, screen-real-estate-first users.

**Heavy glass.** `blur { size = 8–10; passes = 3; vibrancy = 0.2 }`, `inactive_opacity ≈ 0.85`,
chunky rounding (14–16), `xray = true` so floating terminals frost the wallpaper. Gorgeous,
GPU-hungry — back off `passes` on a laptop.

**Animation camps.** *Snappy* people copy short, `easeOutQuint`/overshoot curves at low speeds
(the 0.54 default is already in this camp). *Smooth/cinematic* people run speeds of 7–10 with gentle
ease-in-out curves. *Off* people disable animations for latency.

**Bezier presets people copy** (all hyprlang, real configs):

```ini
# Hyprland 0.54 shipped defaults — well-tuned, snappy
bezier = easeOutQuint,   0.23, 1,    0.32, 1
bezier = easeInOutCubic, 0.65, 0.05, 0.36, 1
bezier = linear,         0,    0,    1,    1
bezier = almostLinear,   0.5,  0.5,  0.75, 1
bezier = quick,          0.15, 0,    0.1,  1

# JaKooLit set — widely forked; "winIn" overshoots for a poppy entrance
bezier = wind,      0.05, 0.9,  0.1,  1.05
bezier = winIn,     0.1,  1.1,  0.1,  1.1
bezier = winOut,    0.3, -0.3,  0,    1
bezier = liner,     1,    1,    1,    1     # loop driver for borderangle
bezier = overshot,  0.05, 0.9,  0.1,  1.05
bezier = smoothOut, 0.5,  0,    0.99, 0.99
bezier = smoothIn,  0.5, -0.5,  0.68, 1.5
```

Named projects worth studying: **end-4/dots-hyprland** (Material-Design motion curves, layered
fade-outs), **HyDE** and **ml4w/JaKooLit looknfeel** modules (clean, swappable animation presets),
and the upstream **Hyprland wiki Animations** page (curve reference + the default block).

## Tasteful default recipe

Drop-in `general{}` + `decoration{}` + `animations{}` that looks great immediately and reads as
"designed." Palette `$vars` come from this plugin's rice-rendered `colors.conf`, which must be
`source`d *before* this block. If you're not using the rice engine, substitute literal `rgba()`.

```ini
# colors.conf provides: $accent $accent2 $surface (rgba hex, e.g. $accent = rgba(cba6f7ff))

general {
    gaps_in = 5
    gaps_out = 16
    border_size = 2
    col.active_border = $accent $accent2 45deg
    col.inactive_border = $surface
    layout = dwindle
    resize_on_border = true
}

decoration {
    rounding = 10
    rounding_power = 2          # remove this line on Hyprland < 0.45
    active_opacity = 1.0
    inactive_opacity = 0.92

    blur {
        enabled = true
        size = 6
        passes = 2
        vibrancy = 0.17
        new_optimizations = true
    }

    shadow {
        enabled = true
        range = 12
        render_power = 3
        color = rgba(1a1a1a99)
    }
}

animations {
    enabled = yes

    bezier = easeOutQuint,   0.23, 1,    0.32, 1
    bezier = easeInOutCubic, 0.65, 0.05, 0.36, 1
    bezier = linear,         0,    0,    1,    1
    bezier = almostLinear,   0.5,  0.5,  0.75, 1
    bezier = quick,          0.15, 0,    0.1,  1

    animation = global,        1, 10,   default
    animation = border,        1, 5.39, easeOutQuint
    animation = windows,       1, 4.79, easeOutQuint
    animation = windowsIn,     1, 4.1,  easeOutQuint, popin 87%
    animation = windowsOut,    1, 1.49, linear,       popin 87%
    animation = fadeIn,        1, 1.73, almostLinear
    animation = fadeOut,       1, 1.46, almostLinear
    animation = fade,          1, 3.03, quick
    animation = layers,        1, 3.81, easeOutQuint
    animation = layersIn,      1, 4,    easeOutQuint, fade
    animation = layersOut,     1, 1.5,  linear,       fade
    animation = workspaces,    1, 1.94, almostLinear, fade
    animation = workspacesIn,  1, 1.21, almostLinear, fade
    animation = workspacesOut, 1, 1.94, almostLinear, fade
}
```

**Snappy variant** — scale every animation SPEED down ~0.6× (e.g. `windows` → `2.9`, `border` →
`3.2`, `workspaces` → `1.2`) for a quicker, more reactive desktop. Same curves.

**Off / low-power variant** — for laptops or latency-sensitive setups:
```ini
animations { enabled = no }
decoration {
    rounding = 8
    blur   { enabled = false }
    shadow { enabled = false }
}
```

## Pitfalls

- **Blur passes too high = lag.** Each pass is a full-screen GPU op; `passes ≥ 3` with a large
  `size` can drop frames on integrated graphics. Stay at `passes 2` unless you've tested.
- **Opaque + blur does nothing.** Blur only shows through *transparent* surfaces. If
  `active_opacity = 1.0` and the app draws an opaque background, you'll see no blur on that window —
  lower opacity or use apps/terminals with their own transparency. (Bars/launchers blur via
  `layerrule`, not this block — see `window-rules.md`.)
- **Gradient needs valid colors.** `col.active_border` must be real `rgba()`/`rgb()` values or
  defined `$vars`. An undefined `$var` or a bad hex fails the reload and (under `safe-apply.sh`)
  rolls the whole config back.
- **Rounding without a border or shadow** can look like windows were "cut out" of the screen — pair
  rounding with at least a thin border or a soft shadow so corners read intentionally.
- **Over-animation feels sluggish.** Long speeds on `windowsMove`/`workspaces` make the desktop feel
  laggy even when it's fast. When in doubt, keep the snappy defaults.
- **`rounding_power` is 0.45+.** Emitting it on an older target errors. Gate on
  `hyprctl version`; drop the line for < 0.45.
- **Don't emit deprecated blocks on modern targets.** Use the `blur{}`/`shadow{}` subcategories, not
  `drop_shadow`/`blur_size`/`col.shadow`; don't emit `gestures{}` or `windowrulev2` on new versions.
  Full mappings in `deprecations.md`.

## Sources

- Hyprland Wiki — Variables (`general`, `decoration`, `blur`, `shadow` tables, defaults):
  <https://wiki.hypr.land/Configuring/Basics/Variables/>
- Hyprland Wiki — Animations (bezier/animation syntax, animation tree, styles):
  <https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/>
- Shipped default config, Hyprland **0.54.3** (`/usr/share/hypr/hyprland.conf`) — source of the
  verbatim default `general`/`decoration`/`animations` blocks above.
- JaKooLit Hyprland-Dots — community bezier presets:
  <https://github.com/JaKooLit/Hyprland-Dots>
- end-4/dots-hyprland — Material-Design motion curves & layered animations:
  <https://github.com/end-4/dots-hyprland>
- This skill's `deprecations.md` (blur/shadow subcategory migration, `rounding_power`, gestures,
  windowrule) and `window-rules.md` / layer-rule blur (`layerrule { blur = true }`).

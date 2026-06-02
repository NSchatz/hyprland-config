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

## Battle-tested techniques (harvested from ~20 real configs)

A catalog of concrete, reusable moves pulled from real `hyprland.conf` / nix / Lua-wrapper configs
across the big rice projects. Each is attributed and quoted close to verbatim — swap literal hexes
for the rice `$accent`/`$accent2`/`$surface` vars. All values verified valid on 0.54.3 via
`hyprctl getoption`. Grouped by what they buy you.

**Borders & accent.**
- *Two-stop accent→accent2 gradient, full-alpha active / muted-translucent inactive* (HyDE, hyprdots, typecraft): the dominant polished look. `col.active_border = rgba(ca9ee6ff) rgba(f2d5cfff) 45deg`, `col.inactive_border = rgba(b4befecc) rgba(6c7086cc) 45deg` — same idea on both, but the inactive pair is muted and dropped to `cc` alpha so only the focused window "lights up." Never a 3-stop rainbow; two adjacent palette hues at `45deg` (or `90deg`, typecraft) is the convention.
- *Animated rotating gradient border.* One-shot sweep on focus — `animation = borderangle, 1, 30, liner, once` (hyprdots) — is cheap; continuous spin — `animation = borderangle, 1, 180, liner, loop` (JaKooLit) — is the "living RGB border" but runs the GPU forever (skip on laptops). `liner = 1, 1, 1, 1` is the constant-velocity driver both need.
- *Borderless, emphasis from suppression* (end-4, chadcat7, koeqaife/HyprYou, linkfrg, Frost-Phoenix): `border_size = 0` or `1` with a **fully transparent inactive border** — `col.inactive_border = rgba(31313600)` / `0x00000000` — so the active window shows a faint accent edge and inactive ones show nothing. Separation then comes from gaps + blur + shadow, not outlines.
- *One accent funneled through a single variable* (basecamp/omarchy, Matt-FTW): define `$activeBorderColor = rgb(dcd7ba)` once, then reuse it for **both** the window and the group border — `general { col.active_border = $activeBorderColor }` and `group { col.border_active = $activeBorderColor }`. Re-theming = change one line. (`group:col.border_active` is itself a gradient field — verified on 0.54.3.)
- *Reserve a second hue strictly for tabbed groups* (justchokingaround): monochrome window borders (`col.active_border = rgb(393939)`) but bright accents only on `col.group_border_active` / `col.group_border` — the color tells you "this is a grouped/tabbed stack," nothing else.
- *Dual color forms in the palette file* (catppuccin/hyprland): export every color twice — `$mauve = rgb(cba6f7)` (solid) and `$mauveAlpha = cba6f7` (bare hex) — so transparency is spliced at the use site as `rgba($mauveAlphaee)`. Decouples hue from opacity; this is exactly how a `source`d `colors.conf` should be shaped.

**Blur (frosted glass).**
- *See-through frosted terminals* (HyDE, JaKooLit): `blur { ignore_opacity = on; xray = true }` together — `ignore_opacity` makes blur apply under semi-transparent windows, `xray` blurs the wallpaper rather than the windows stacked beneath. The combo is what makes a translucent kitty read as frosted glass instead of muddy.
- *The Nix community frosted preset* (fufexan and sioodmy, independently identical): `blur { size = 7; passes = 4; vibrancy = 0.2; vibrancy_darkness = 0.5; noise = 0.01; popups = true; popups_ignorealpha = 0.2 }`. A de-facto shared default — heavier passes than the stock `1`, with `vibrancy` keeping colors from going grey.
- *Full polish stack* (end-4): `blur { size = 10; passes = 3; noise = 0.05; contrast = 0.89; vibrancy = 0.5; vibrancy_darkness = 0.5 }` — the most complete tuning of the set, for pronounced glassmorphism.
- *Punchy blur via contrast* (Frost-Phoenix): `blur { passes = 2; contrast = 1.4; noise = 0 }` — bumping `contrast` above 1 keeps blurred content crisp instead of washed out.
- *Dimmed, calmer glass* (omarchy): `blur { size = 2; passes = 2; brightness = 0.60; contrast = 0.75 }` — drop brightness/contrast below 1 for a darker, restrained frost rather than a bright bloom.

**Shadow (depth).**
- *Theme-tinted shadow that tracks the palette* (JaKooLit, Matt-FTW): `shadow { color = $color12; color_inactive = $color10 }` (JaKooLit) or `color = $surface0; color_inactive = $crust` (Matt-FTW) — the drop shadow recolors with the wallust/Catppuccin palette instead of being flat black, and unfocused windows get a quieter shadow. `color_inactive` verified on 0.54.3.
- *Big soft floating-card shadow* (fufexan, linkfrg): `shadow { range = 30; render_power = 4; offset = 0 2; color = rgba(00000055) }` — a wide diffuse shadow with a downward `offset` fakes a light source above; `scale = 0.97` (fufexan) insets it slightly. Lifts rounded windows off the wallpaper without any border.
- *Shadow off, blur carries the depth* (hyprdots): `shadow { enabled = false }` when the blur is already strong — avoids the doubled-up "halo + frost" heaviness.

**Rounding.**
- *Squircle corners* (end-4 `rounding = 18; rounding_power = 2.5`; ml4w/fufexan `rounding_power = 2.0–2.5`): bump `rounding_power` above the default `2` for the softer iOS-style corner that modern rices favour, independent of the radius.
- *Flat doctrine* (omarchy, Frost-Phoenix, sioodmy): `rounding = 0` as a deliberate designed identity — crisp/technical, leaning on gaps + a single accent border. (omarchy rejects rounded corners across its whole theme set.)

**Motion (beziers & animation).**
- *The `wind/winIn/winOut/liner` slide-with-overshoot family* — the most-forked set in the scene (prasanthrangan/hyprdots → JaKooLit → HyDE). `wind = 0.05, 0.9, 0.1, 1.05` for slides; `winIn = 0.1, 1.1, 0.1, 1.1` overshoots past 1 on both axes for a poppy entrance; `winOut = 0.3, -0.3, 0, 1` undershoots on exit. Already in the preset block below.
- *Material Design 3 motion* (ml4w, koeqaife/HyprYou, chadcat7): pair a decel curve on enter with an accel curve on exit — `bezier = md3_decel, 0.05, 0.7, 0.1, 1` and `bezier = md3_accel, 0.3, 0, 0.8, 0.15`, then `animation = windowsIn, 1, 5, md3_decel, popin 60%` / `animation = windowsOut, 1, 4, md3_accel, popin 60%`. The `popin 60%` (vs the gentler `80–94%`) gives a stronger shrink-in.
- *Animate layers separately from windows* (ml4w, end-4, koeqaife): give bars/menus/popups their own `layersIn`/`layersOut` with a slide + `popin 93%` so chrome animates distinctly from window open/close — `animation = layersIn, 1, 3, md3_decel, slide`.
- *Role-mapped easing palette* (Frost-Phoenix): distinct named beziers per job — `easeOutCubic` for windows, `fluent_decel` for moves, a dedicated `fade_curve` for opacity — deliberate motion design instead of one global curve. The opposite school is *one curve everywhere* (linkfrg: `bezier = quart, 0.25, 1, 0.5, 1` reused across windows/border/fade/workspaces) for maximal consistency.
- *Spend the motion budget on the border, not the windows* (typecraft): near-instant window/fade speeds (`0.1`) with the only lively motion being a looping `borderangle` — a calm desktop whose one flourish is the rotating gradient.
- *Spring-physics curves* (fufexan): expressed through the home-manager Lua wrapper as `spring { mass = 1; stiffness = 50; dampening = 10 }` for natural overshoot without hand-tuned beziers. Note this is a **wrapper abstraction**, not vanilla hyprlang `.conf` syntax — on a plain `.conf` setup, reach for an overshoot bezier (`winIn`, `expressiveFastSpatial = 0.42, 1.67, 0.21, 0.90` from end-4) instead.

**Per-app & special-workspace transparency.**
- *Make terminals translucent per-app, keep content windows opaque* (omarchy, Matt-FTW): global `active_opacity = 1.0` (content stays crisp) plus a per-app rule for chrome only — `windowrule = opacity 0.95 0.90, class:^(kitty)$` (block form on 0.53+). omarchy tunes this *per theme* (e.g. terminals to `0.98 0.95` only when a theme's backdrop is too strong).
- *Dim + blur the scratchpad layer* (hyprdots, JaKooLit): `decoration { dim_special = 0.3; blur { special = true } }` so the special/scratchpad workspace recedes behind a dimmed frost. JaKooLit pushes `dim_special = 0.8` for a strong fade.

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

**Community config corpus** — the "Battle-tested techniques" section was harvested by reading these
`hyprland.conf` / nix / Lua-wrapper configs directly. Grouped by what they best demonstrate:

- *Two-stop gradient borders + rotating `borderangle` + wind/winIn/winOut beziers*: prasanthrangan/hyprdots (`Configs/.config/hypr/themes/theme.conf`, `animations/animations-default.conf` — origin of the `wind` family + the one-shot `borderangle … once`), HyDE-Project/HyDE (`Configs/.config/hypr/themes/theme.conf`, swappable `animations/*.conf` presets), JaKooLit/Hyprland-Dots (`UserConfigs/UserDecorations.conf` + `UserAnimations.conf` — `$color12` shadow tint, `borderangle … loop`), typecraft-dev/dotfiles (`$mauve $flamingo 90deg`, `borderangle` loop with near-instant windows).
- *Material Design 3 motion + borderless rounding*: mylinuxforwork/dotfiles / ml4w (`conf/decorations/default.lua`, `conf/animations/default.lua` — full MD3 bezier set, `rounding_power 2`, `passes 4`), koeqaife/hyprland-material-you "HyprYou" (`hypryou-assets/hyprland/animation.conf` — MD3 decel/accel, `border_size 0`), chadcat7/crystal (MD3 set, `gaps_in = gaps_out = 20` airy borderless).
- *Expressive-spatial / heavy frosted glass*: end-4/dots-hyprland (`dots/.config/hypr/hyprland/general.lua` — `rounding 18`/`rounding_power 2.5`, full `noise`+`contrast`+`vibrancy` blur, "expressive spatial" overshoot beziers; **shell is AGS/Quickshell, inspiration-only — only the decoration/animation values transfer**), linkfrg/dotfiles (`home/desktop/hyprland/general.nix` — `size 12`/`passes 4` glass, one `quart` curve everywhere).
- *Nix frosted preset + spring physics + role-mapped easing*: fufexan/dotfiles (`system/programs/hyprland/{settings,animations}.lua`, `variables.nix` — `spring { mass/stiffness/dampening }`, `passes 4`/`size 7`, `scale 0.97` shadow), sioodmy/dotfiles (`user/wrapped/hypr/configs/Hyprland.nix` — same blur preset, `rounding 0`), Frost-Phoenix/nixos-config (`modules/home/hyprland/settings.nix` — modern `shadow {}` block, `contrast 1.4`, per-property beziers).
- *Flat designer-distro doctrine + single-accent variable*: basecamp/omarchy (`default/hypr/looknfeel.conf` + per-theme `themes/*/hyprland.conf` — `rounding 0`, `$activeBorderColor` reused for window+group border, per-theme terminal opacity), Matt-FTW/dotfiles (`.config/hypr/theme/decoration.conf` — `color`/`color_inactive` shadow depth, selective per-app opacity).
- *Named-palette source convention*: catppuccin/hyprland (`themes/mocha.conf` @ tag `v1.3` — dual `$mauve`/`$mauveAlpha` color forms, semantic neutral ladder), SolDoesTech/HyprV4 (`HyprV/hypr/hyprland.conf` — tutorial-grade solid-accent starter; note its `drop_shadow`/`shadow_range` is the deprecated flat form).

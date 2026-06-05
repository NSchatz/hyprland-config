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
    rounding = 10               # corner radius in layout px (default 0)
    rounding_power = 2          # corner curve exponent (0.47+); 2 = circle, higher = squircle
    active_opacity = 1.0
    inactive_opacity = 1.0

    blur {
        enabled = true          # default true
        size = 8                # default 8 (NOT 3 — that's a stale older-wiki claim)
        passes = 1              # default 1
        vibrancy = 0.1696       # default 0.1696
    }

    shadow {
        enabled = true          # default true
        range = 4               # default 4
        render_power = 3        # default 3
        color = rgba(1a1a1aee)  # default 0xee1a1a1a
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
`deprecations.md`. `rounding_power` exists only on **0.47+** (verified — absent from
`src/config/ConfigManager.cpp` at v0.46.0, present at v0.47.0 line 470 with default `2.F`).
The rice version matrix gates it at 0.53+ which is safe but overly conservative.

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
Defaults verified against `src/config/ConfigManager.cpp` at v0.54.3 (lines 585–600) and
`src/config/values/ConfigValues.cpp` at v0.55.2 (lines 228–244).

| key | default | range / effect |
|---|---|---|
| `enabled` | true | master switch |
| `size` | 8 | 0–100; blur radius/distance (was once 3 in older betas — current default is 8) |
| `passes` | 1 | 0–10; more = smoother but **GPU-heavy** (2 is the sweet spot) |
| `vibrancy` | 0.1696 | 0–1; saturation boost of blurred colors (keeps it from going grey) |
| `vibrancy_darkness` | 0.0 | vibrancy effect on dark areas (0–1) |
| `noise` | 0.0117 | film-grain to fight banding (0–1) |
| `contrast` | 0.8916 | blurred-layer contrast (0–2) |
| `brightness` | 1.0 | blurred-layer brightness (0–2) — NOT 0.8172 (that was an old wiki value) |
| `new_optimizations` | true | keep on; large speedup |
| `ignore_opacity` | true | make the blur layer ignore the opacity of the window |
| `xray` | false | floating windows blur the wallpaper, ignoring tiled windows under them |
| `popups` | false | also blur right-click menus/popups |
| `popups_ignorealpha` | 0.2 | if pixel opacity below this, do not blur (0–1) |
| `special` | false | blur behind the special workspace |
| `input_methods` | false | blur input methods (e.g. fcitx5) — 0.54+ |
| `input_methods_ignorealpha` | 0.2 | same as popups_ignorealpha for IMEs — 0.54+ |

Rule of thumb: `size 5–8`, `passes 2` for a rich frosted-glass look; `size 3`, `passes 1` for a
light touch.

### Shadow — `decoration:shadow{}`
Drop shadow that separates floating/rounded windows from the wallpaper.
Defaults verified against `src/config/ConfigManager.cpp` at v0.54.3 (lines 604–612) and
`src/config/values/ConfigValues.cpp` at v0.55.2 (lines 203–210).

| key | default | effect |
|---|---|---|
| `enabled` | true | |
| `range` | 4 | shadow size in px (int, 0–100); **6–25** for a pronounced lift |
| `render_power` | 3 | int 1–4; falloff steepness (higher = tighter, darker edge) |
| `sharp` | false | hard-edged shadow instead of soft |
| `color` | rgba(1a1a1aee) | shadow color+alpha (`0xee1a1a1a`); lower the alpha (`…66`) for subtlety |
| `color_inactive` | unset | separate shadow tint for unfocused windows |
| `offset` | 0 0 | vec2 x/y push (e.g. `0 4` for a "light from above" drop); range ±250 |
| `scale` | 1.0 | shadow scale (0–1) |
| `ignore_window` | `1` (≤0.54) → **removed** in 0.55+ | always-on behaviour in 0.55+; don't emit |

### Glow — `decoration:glow{}` (0.55+ only)
Inner glow on windows — new effect added in 0.55. Verified against
`src/config/values/ConfigValues.cpp` at v0.55.2 (lines 211–215). Absent in 0.54.3 source.

| key | default | effect |
|---|---|---|
| `enabled` | false | master switch |
| `range` | 10 | int 0–100; glow size in px |
| `render_power` | 3 | int 1–4; falloff steepness |
| `color` | rgba(33ccffee) (`0xee33ccff`) | active glow color |
| `color_inactive` | rgba(33ccff00) (`0x0033ccff`) | inactive glow (alpha 0 = invisible by default) |

Do NOT emit a `glow {}` block on targets `< 0.55` — it would not be a hard error (unknown keys
are tolerated under some hyprlang error modes) but it does nothing and pollutes parse-error logs.

### Motion blur — `decoration:motion_blur{}` (0.55+ only)
Motion blur on moving/resizing windows. Verified at v0.55.2 source. Two knobs only:
`enabled` (false), `samples` (7). Absent in 0.54.

### Animation feel — `animations:bezier` + `animation`
- `bezier = NAME, x0, y0, x1, y1` defines a cubic-Bézier curve. **Y values >1 overshoot** (the
  springy "bounce past then settle" feel); `linear` is `0,0,1,1`. Verified `handleBezier` at
  `src/config/legacy/ConfigManager.cpp` v0.55.2 line 1382 — exactly 4 numeric args.
- `animation = NAME, ONOFF, SPEED, CURVE [, STYLE]` — **SPEED is in deciseconds** (1 ds = 100 ms),
  so *lower = faster*. `STYLE` is per-item: `popin 87%`, `slide [dir]`, `fade`, `slidefade`, etc.
  Verified `handleAnimation` at v0.55.2 line 1421.
- **Spring curves are Lua-only.** The hyprlang `.conf` `animation =` handler at v0.55.2 still only
  validates `bezierExists(bezierName)` — spring curves require the Lua `hl.curve(..., { type =
  "spring", ... })` + `hl.animation({ ..., spring = "name" })` API. Don't try to emit
  `animation = windows, 1, 5, easy` referencing a spring curve in `.conf` — it errors with
  "no such bezier". On 0.55+ Lua configs this works.
- Animatable items (children inherit from parents): `global` → `windows`(`windowsIn`/`windowsOut`/
  `windowsMove`), `layers`(`layersIn`/`layersOut`), `fade`(`fadeIn`/`fadeOut`/`fadeSwitch`/
  `fadeShadow`/`fadeDim`/`fadeLayers`(`In`/`Out`)/`fadePopups`(`In`/`Out`)/`fadeDpms`),
  `border`, `borderangle`, `workspaces`(`workspacesIn`/`workspacesOut`),
  `specialWorkspace`(`In`/`Out`), `zoomFactor`, `monitorAdded` (0.55+).
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

**Window-groups / tabs (when 11h = yes).** Defaults upstream for `col.border_locked_active` are a loud `0x66ff5500` orange — every palette-aware rice re-tints them.
- *Three-tier color ladder (active / inactive / locked)* (caelestia, hyprdots): unlocked uses the primary accent, inactive uses muted, **locked** uses a third hue. caelestia: `col.border_locked_active = $error` (signal red); hyprdots: `col.border_locked_active = $secondary`. Tells you state at a glance without reading text.
- *Same gradient on every group color field* (omarchy, hyprdots): `group { col.border_active = $activeBorderColor; col.border_inactive = $inactiveBorderColor; col.border_locked_active = $activeBorderColor; col.border_locked_inactive = $inactiveBorderColor }` — locked vs. unlocked is *not* a visual signal; the tab bar is.
- *Match the groupbar to the window corner language* (caelestia: `groupbar { gradient_rounding = 5; gradient_round_only_edges = true; indicator_height = 0 }`; omarchy: `gradient_rounding = 0; gradient_round_only_edges = false; indicator_height = 0`). The tab pill takes its corner radius from the same value as `decoration:rounding`; `gradient_round_only_edges = true` so only the first/last tab round — a hard-won detail. `indicator_height = 0` suppresses the default accent bar above the tabs.
- *Pad the groupbar visually* (caelestia, omarchy): `groupbar { gaps_in = 3; gaps_out = 0; height = 22-25 }` — internal gap between tabs, no outer gap, taller bar. The "chunky tabbed terminal" look.

**Compositor primitives most rices ignore (and shouldn't).**
- *`misc:background_color`* (caelestia: `background_color = rgb($surfaceContainer)`; hyprdots: implicit via theme block): the color you see for the split-second before hyprpaper paints, and behind any uncovered area. Default `0xff111111` jumps to near-black on session start — tie to `$bg` so the flash matches the wallpaper instead of "rebooting into a void". Verified `misc:background_color` (Color, default `0xff111111`) at v0.55.2 `src/config/values/ConfigValues.cpp` line 465.
- *`general:gaps_workspaces`* (end-4 sets `50`, caelestia parameterises as `$workspaceGaps = 20`): visible gap *between* workspaces during a swipe/slide animation. Stacks with `gaps_out`. Default `0` (workspaces butt against each other). 0–100 int. Use when the workspace animation is `slide`/`slidefade` and you want the swipe to read as a swipe; leave at `0` for `fade`-only.
- *`misc:vrr`* (caelestia: `vrr = 1`): adaptive sync — distinct from `debug:vfr` (variable frame rate). `0` off, `1` on, `2` fullscreen-only. Default `0`. `2` is a near-pure win on VRR-capable monitors when one fullscreen game/video is running, while leaving the desktop at fixed refresh.
- *`general:col.nogroup_border` / `nogroup_border_active`* (rare but ugly when triggered): upstream defaults are loud pink/magenta (`0xffffaaff` / `0xffff00ff`). Re-tint from palette; you don't want a *no_focus_fallback* float showing up in default Hyprpink. Verified at v0.54.3 `src/config/ConfigManager.cpp` line 479–480.

**Cross-surface coherence — what to match where.**
- *Border radius is shared with bar/launcher/notification pills.* `decoration:rounding` is the canonical source — waybar pill `border-radius`, rofi `border-radius`, fuzzel `border-radius`, mako `border-radius` should all read from the same answer. If the user picked `rounded` (10), every surface gets 10px. The rice's renderer is responsible for this; this component owns the value.
- *Border accent is the canonical accent.* `general:col.active_border = $accent $accent2 45deg` makes the focused window the *brightest* element of the rice; everything else (waybar active-workspace pill, launcher selection, mako border) should *also* read `$accent` from `colors.css`/`colors.rasi`/etc. — they're the same key, not a copy.
- *Blur on this layer is what makes layer-rules visible.* `decoration:blur { enabled = true }` is the master switch; `layerrule = blur, waybar` / `…launcher` / `…notifications` (emitted by `window-rules`) only does anything when blur is on here. The "Blur off" interview answer therefore disables blur on EVERY surface, not just windows — surface this in re-theming (Mode B) when the user toggles blur off.

**Design-system pattern — externalize every knob to a single file.**
- *Caelestia's `$variables.conf` pattern.* Every visual knob — `$blurEnabled`, `$blurSize`, `$blurPasses`, `$shadowRange`, `$shadowColour`, `$workspaceGaps`, `$windowGapsIn`, `$windowGapsOut`, `$singleWindowGapsOut`, `$windowOpacity`, `$windowRounding`, `$windowBorderSize`, `$activeWindowBorderColour`, `$inactiveWindowBorderColour` — lives in `hypr/variables.conf` and the other conf files (`general.conf`, `decoration.conf`, `group.conf`) just reference the `$vars`. Re-theming is editing a single file; the layout is invariant. This rice's split — `colors.conf` (palette) + `looknfeel.conf` (typography of gaps/rounding/blur) — is the same idea at lower granularity. Don't bake gaps/rounding/blur *into* `looknfeel.conf` if you can splice them in from a sibling — but for the rice's interview-driven model, baking them at generate-time is cheaper than the runtime $var indirection.

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
    rounding_power = 2          # remove this line on Hyprland < 0.47 (verified added at v0.47.0)
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
- **`rounding_power` is 0.47+.** Emitting it on an older target errors. Gate on
  `hyprctl version`; drop the line for < 0.47. (Verified: not in `ConfigManager.cpp` at v0.46.0,
  added at v0.47.0 line 470.) The rice version matrix conservatively gates at 0.53+.
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
- *Window-groups three-tier ladder + matched groupbar pills*: caelestia-dots/caelestia (`hypr/hyprland/group.conf`, `hypr/variables.conf` — `$activeWindowBorderColour` reused on `group:col.border_active` + `col.border_locked_active`, `groupbar { gradient_rounding = 5; gradient_round_only_edges = false; indicator_height = 0 }`), basecamp/omarchy (`default/hypr/looknfeel.conf` — `$activeBorderColor` reused across `general:col.active_border`, `group:col.border_active`, `group:col.border_locked_active`; `groupbar { gradient_rounding = 0 }`), prasanthrangan/hyprdots (`Configs/.config/hypr/themes/theme.conf` — gradient-on-everything: same `rgba(ca9ee6ff) rgba(f2d5cfff) 45deg` on all four group color fields).
- *`$variables.conf` design-system externalisation*: caelestia-dots/caelestia (`hypr/variables.conf` — full sliding-knob set: `$blurEnabled`/`$blurSize`/`$blurPasses`/`$blurXray`/`$blurSpecialWs`/`$shadowEnabled`/`$shadowRange`/`$shadowColour`/`$workspaceGaps`/`$windowGapsIn`/`$windowGapsOut`/`$windowOpacity`/`$windowRounding`/`$windowBorderSize`/`$activeWindowBorderColour`/`$inactiveWindowBorderColour`), mylinuxforwork/dotfiles (`conf/decorations/default.lua` — Lua-table equivalent: `hl.config({ decoration = { rounding = 10, rounding_power = 2, blur = { size = 4, passes = 4, … } } })`).
- *Compositor fallback bg = palette bg*: caelestia-dots/caelestia (`hypr/hyprland/misc.conf` — `background_color = rgb($surfaceContainer)`), prasanthrangan/hyprdots (theme blocks set `$base` as the background tone). Pre-hyprpaper flash matches the rice instead of jumping to upstream's `0xff111111` near-black.
- *Workspace-slide gutter via `gaps_workspaces`*: end-4/dots-hyprland (`dots/.config/hypr/hyprland/general.lua` — `gaps_workspaces = 50` in `hl.config({ general = { … } })`), caelestia-dots/caelestia (`$workspaceGaps = 20` in `variables.conf`). Only valuable when the workspace animation has a spatial component (`slide`, `slidevert`, `slidefade`); harmless but invisible with `fade`-only.
- *Spring-physics animations via Lua* (0.55+): fufexan/dotfiles (`system/programs/hyprland/animations.lua` — `hl.curve("bounce", { type = "spring", mass = 1, stiffness = 50, dampening = 10 })` + `hl.animation({ leaf = "windows", spring = "bounce", style = "popin 80%" })`). **Lua-only — hyprlang `.conf` `animation =` rejects non-bezier curve names** (verified `handleAnimation` at v0.55.2 line 1421). This rice emits `.conf`, so it's a reference for what's deliberately *not* offered (use overshoot beziers instead).
- *MD3 + full named-bezier set*: mylinuxforwork/dotfiles (`conf/animations/default.lua` — `md3_standard`/`md3_decel`/`md3_accel`/`overshot`/`crazyshot`/`hyprnostretch`/`menu_decel`/`menu_accel`/`easeInOutCirc`/`easeOutCirc`/`easeOutExpo`/`softAcDecel`/`md2` curves all registered, with `style = "popin 60%"` and `style = "slide"` on layer animations).

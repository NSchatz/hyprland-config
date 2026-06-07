# look-feel — gotchas

## Cursor disappears when idle (nouveau / NVIDIA)

The most-reported "weird Hyprland thing" — the cursor vanishes after sitting still a few seconds,
then reappears the moment you move the mouse. It is **not** `cursor:inactive_timeout` (which
defaults to `0` already). The cause is the GPU's **hardware cursor plane**: on `nouveau` (and the
proprietary `nvidia` driver under some conditions) the plane blanks/flickers when nothing else is
repainting.

Fix: render the cursor in software. Emit the following block in `looknfeel.conf` **only when**
`scripts/detect-version.sh` set `CURSOR_NO_HARDWARE_RECOMMENDED=1` (true when `GPU_DRIVER` is
`nouveau` or `nvidia`):

```ini
cursor {
    no_hardware_cursors = 1    # int: 0=disable, 1=enable, 2=auto (default 2)
    inactive_timeout    = 0    # float seconds; 0 = never hide
}
```

`cursor:no_hardware_cursors` is an **int**, not a bool (verified against
`src/config/ConfigManager.cpp` at v0.45.0 onward — `Hyprlang::INT{2}` with map
`{Disabled:0, Enabled:1, Auto:2}`). The hyprlang parser also accepts `true` (→1) / `false` (→0)
so older "= true" configs keep working, but the int form is the canonical type and the only one
that lets you say "auto" (= 2) without ambiguity.

Live fix: `hyprctl keyword cursor:no_hardware_cursors 1`. Do not emit the block unconditionally
— on Intel / AMD the default `auto` (2) is already correct and forcing software cursors slightly
raises CPU use for no benefit.

## `misc:vfr` → `debug:vfr` in 0.55+

Hyprland 0.55 reclassified VFR as a debug variable. Leaving `misc:vfr = true` on 0.55+ is a
**parse error** that fails the whole reload. Branch by `HYPR_VERSION` (see
[`_shared/version-matrix.md`](../../_shared/version-matrix.md)):

| `HYPR_VERSION` | Where `vfr = true` goes |
|---|---|
| `< 0.55` | `misc { vfr = true; … }`  (default true upstream — verified `Hyprlang::INT{1}` at v0.54.3) |
| `≥ 0.55` | `debug { vfr = true }`  (default true upstream — verified at v0.55.2; `misc:vfr` is gone) |

Verified against `src/config/ConfigManager.cpp` at v0.54.3 (line 490, `misc:vfr` present) and
`src/config/values/ConfigValues.cpp` at v0.55.2 (line 608, `debug:vfr` present; `misc:vfr` absent).

This is the single most common parse error when porting an older config forward — flag it loudly
in the validator's output. **Because `debug:vfr` already defaults to `true` on 0.55+, the safest
0.55+ output is to OMIT the line entirely** — the only reason to emit it is to be defensive against
upstream flipping the default.

## `dwindle:pseudotile` removed in 0.55+

The `dwindle { pseudotile = true }` line stopped doing anything before 0.55 and the key was
**removed** in 0.55. Emitting it on 0.55+ is a parse error. The `pseudo` dispatcher and the
`windowrule = pseudo` form **still work** — only the layout-block key is gone.

| `HYPR_VERSION` | dwindle block |
|---|---|
| `< 0.55` | `dwindle { pseudotile = true; preserve_split = true }` |
| `≥ 0.55` | `dwindle { preserve_split = true }` |

## `decoration:shadow:ignore_window` removed in 0.55+

The shadow's "skip the window's own area" behaviour is now **always on** and the key was removed.
Never emit `ignore_window = true` (or `false`) on 0.55+. The rest of the `shadow {}` block
(`enabled`, `range`, `render_power`, `color`, `offset`, `scale`) is unchanged.

## Scrolling layout is CORE in 0.54+ — not a plugin

In 0.53 and earlier, scrolling layouts were provided by the `hyprscrolling` / `hyprscroller`
plugins. In **0.54+** the layout was merged into Hyprland core. Verified: the `scrolling:*`
config keys are absent from `src/config/ConfigManager.cpp` at v0.53.0 and present at v0.54.0
(lines 651–657, `scrolling:fullscreen_on_one_column` etc.). The rice version matrix currently
says 0.53+ — that's wrong; see the cross-component flag in this component's changes report.

Implications for this component:

- `general:layout = scrolling` and the top-level `scrolling { … }` block are **safe uncommented**
  on any target ≥ 0.54. They will NOT hard-error the reload.
- `layoutmsg, move +col` / `colresize +conf` / `fit active` etc. are core dispatchers and the
  validator allows them uncommented (see [`_shared/dispatchers.md`](../../_shared/dispatchers.md)).
- 0.55+ adds extra layoutmsg verbs: `expel`, `consume`, `consume_or_expel`, `promote`, `swapcol l/r`,
  `inhibit_scroll`. Verified via the upstream Scrolling-Layout wiki page.
- Only **non-core** layouts (`hy3`, anything plugin-provided) need to be kept commented until the
  plugin is loaded — and `look-feel` does not offer those; they live in `components/plugins/`.
- The old `hyprscrolling` plugin's README now says "DEPRECATED" — do not install it.

## Blur is a no-op on opaque windows

`decoration:blur { enabled = true }` only does anything **behind translucent surfaces**. A fully
opaque window has nothing behind it to blur. Two consequences:

1. If the user picks "Blur on" (11c) but leaves opacity at 1.0/1.0 (11d), the blur enabled flag is
   set but visually nothing changes for tiled windows. That's expected; per-app `opacity` rules
   (e.g. translucent terminals) are where blur actually shows.
2. The frosted preset (`blur { size = 6; passes = 2 }`) is only worth raising the GPU cost for if
   *something* in the stack is translucent — terminals via per-app rules, layer-surfaces via
   `layerrule { blur = true }` (waybar, launcher, notifications). Upstream defaults are
   `size = 8, passes = 1` (verified `src/config/ConfigManager.cpp` v0.45+ through v0.54.3 and
   `src/config/values/ConfigValues.cpp` at v0.55.2 line 229–230).

## "Frosted" preset values

If the user explicitly asks for a "frosted glass" look:

```ini
blur {
    enabled  = true
    size     = 6        # default = 8 (this is actually a lighter touch); for a darker frost use 8–12
    passes   = 2        # default = 1; 2 is the sweet spot; 3+ is GPU-heavy
    vibrancy = 0.1696   # default 0.1696
}
```

(Some older guides claim `size`'s default is 3 — that was true in a 0.3x era. From 0.45.0 onward
the source registers `Hyprlang::INT{8}` for `decoration:blur:size`. Verified against multiple
tags.)

Pair with `layerrule { blur = true }` on `waybar` / `wofi`/`rofi` / `mako` namespaces (those rules
live in `window-rules` on 0.54+ — block form — see
[`_shared/version-matrix.md`](../../_shared/version-matrix.md)).

## Plugin layouts (`hy3` etc.) — don't emit uncommented

If the user somehow expressed a preference for `hy3` or another plugin layout, **do not** write
`general:layout = hy3` here. A bare plugin layout line HARD-ERRORS the reload when the plugin is
not loaded. Route the preference through `components/plugins/` (which handles the hyprpm install
+ gating) and let that component emit the line once the plugin is on disk.

## Animation speed scaling

For `animations = snappy`, multiply each `animation = TARGET, ENABLED, SPEED, CURVE[, STYLE]`
second-from-end **SPEED** by ~0.6. Do **not** rescale the curves themselves — the bezier
definitions stay the same. For `animations = off`, set `enabled = false` and drop the
`animation = ` lines entirely; leaving them with an `enabled = false` parent is harmless but
noisier.

## `misc:vfr` vs `misc:vrr` — easy to confuse, do different things

Two single-letter-different keys, both in `misc {}` (pre-0.55), both Int defaults that change idle
behaviour. They are **not the same knob**:

| Key | What it does | Type | Default | Where in 0.55+ |
|---|---|---|---|---|
| `vfr` | Variable **frame** rate. Skip repaints when nothing's moving. Idle/battery win. | Bool-ish int (0/1) | 1 | moved to `debug { vfr = … }` |
| `vrr` | Variable **refresh** rate. Adaptive sync (FreeSync/G-SYNC). 0=off, 1=on, 2=fullscreen-only. | Int (0/1/2) | 0 | stays in `misc { vrr = … }` |

Verified at `src/config/ConfigManager.cpp` v0.54.3 (line 490 `misc:vfr`, line 491 `misc:vrr`) and
`src/config/values/ConfigValues.cpp` v0.55.2 (line 448 `misc:vrr`, line 608 `debug:vfr`). The two
travel separately — emitting `vrr = 1` on a monitor that doesn't advertise VRR is harmless (the
output never opts in), but emitting `vfr` on the wrong block on 0.55+ hard-errors the reload.

When to emit each:
- `vfr = true` — always; it's the single biggest idle/battery improvement and Hyprland defaults it
  to `true` anyway. The rice sets it explicitly to defend against upstream flipping the default.
- `vrr = 2` — only when the user has a VRR-capable monitor and asked for it (no rice
  sub-question owns this today — the gaming/monitors components could grow one). The rice's
  default is `0`. Setting it ≥ 1 on a non-VRR display does nothing; it doesn't error.

## Compositor `background_color` flashes before hyprpaper paints

Hyprland draws a solid fallback color until the wallpaper daemon paints. Upstream's default is
`0xff111111` (near-black). On a paletted rice that's a jarring transition from "boot splash → split
second of black → wallpaper." Set `misc:background_color = $bg` so the brief flash is the palette
base, not raw black.

> **Do not wrap `$bg` (or any other palette var) in `rgb(...)`.** The rice's `colors.conf`
> already stores each palette key as `$accent = rgb(cba6f7)` — wrapping again produces
> `rgb(rgb(cba6f7))` which Hyprland rejects with "invalid color" and the whole reload fails.
> Use `$bg` / `$accent` / `$surface` bare. (Caelestia's `background_color = rgb($surfaceContainer)`
> pattern works *only* because their palette stores bare hex; the rice's stores already-wrapped
> values.) Defect #3.

Verified `misc:background_color` (Color, default `0xff111111`) at `src/config/values/ConfigValues.cpp`
v0.55.2 line 465; same key at v0.46.0 ConfigManager.cpp line 383.

This also shows through any uncovered monitor area (multi-monitor with no wallpaper assigned,
hyprpaper crash, etc.) — palette-tinted `$bg` reads as "this is intentional" instead of "the
wallpaper daemon died."

## `gaps_workspaces` is NOT the same as `gaps_out`

Both are gaps; they apply at different moments.

- `gaps_out` = gap between a window and the **screen edge**. Visible at rest.
- `gaps_workspaces` = visible gap **between two workspaces during a workspace-switch animation**.
  Stacks with `gaps_out`. Default `0` (workspaces butt against each other during the slide). Range
  0–100 int.

If you set `gaps_workspaces = 50` and your animation is `fade`-only, you'll see nothing — fades
don't expose the inter-workspace seam. The knob is valuable for `slide` / `slidevert` /
`slidefade` styles, where it makes the swipe read as a swipe instead of a snap. end-4 sets `50`,
caelestia parameterises as `$workspaceGaps = 20`. Leave at `0` for the rice's defaults.

Verified `general:gaps_workspaces` (Int, default `0`, range 0–100) at v0.55.2
`src/config/values/ConfigValues.cpp` line 172.

## Window-groups default colors are loud out of the box

Upstream defaults that bite when the user turns groups on (11h):

| Key | Default | What you see |
|---|---|---|
| `general:col.nogroup_border` | `0xffaaff` (loud pink) | tile-floor pink border on un-groupable floats |
| `general:col.nogroup_border_active` | `0xffff00ff` (full magenta) | same, focused |
| `group:col.border_locked_active` | `0x66ff5500` (orange) | locked-group focused border |
| `group:col.border_locked_inactive` | `0x66775500` (olive) | locked-group inactive border |
| `group:groupbar:col.locked_active` | `0x66ff5500` | locked-group tab bar focused |
| `group:groupbar:col.locked_inactive` | `0x66775500` | locked-group tab bar inactive |

Every palette-aware rice in the corpus re-tints these (caelestia → `$error`/`$secondary`;
hyprdots → palette gradient on all four; omarchy → reuses `$activeBorderColor`). The rice's
template emits `$accent2` / `$surface` for the locked tier so the palette stays coherent.

Verified field types and defaults at `src/config/ConfigManager.cpp` v0.54.3 lines 479–480
(nogroup), 780–786 (locked) and v0.55.2 `ConfigValues.cpp` lines 175, 391–392, 429–430.

## Spring animation curves are Lua-only

`animation = TARGET, ENABLED, SPEED, CURVE` in hyprlang `.conf` validates `CURVE` through
`bezierExists(name)` — the parser does **not** know spring curves. Verified `handleAnimation` at
`src/config/legacy/ConfigManager.cpp` v0.55.2 line 1421.

To emit a spring you have to write `~/.config/hypr/hyprland.lua` and use:

```lua
hl.curve("bounce", { type = "spring", mass = 1, stiffness = 50, dampening = 10 })
hl.animation({ leaf = "windows", enabled = true, spring = "bounce", style = "popin 80%" })
```

The rice emits `.conf`, so spring curves are out of scope. The `wind`/`winIn`/`winOut` overshoot
bezier family or `expressiveFastSpatial = 0.42, 1.67, 0.21, 0.90` (end-4) gets you most of the way
to that "bouncy" feel inside `.conf`. See `styling.md` "Motion (beziers & animation)."

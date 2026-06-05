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

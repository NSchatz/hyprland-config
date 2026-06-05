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
    no_hardware_cursors = true
    inactive_timeout    = 0
}
```

Live fix: `hyprctl keyword cursor:no_hardware_cursors true`. Do not emit the block unconditionally
— on Intel / AMD it slightly raises CPU use for no benefit.

## `misc:vfr` → `debug:vfr` in 0.55+

Hyprland 0.55 reclassified VFR as a debug variable. Leaving `misc:vfr = true` on 0.55+ is a
**parse error** that fails the whole reload. Branch by `HYPR_VERSION` (see
[`_shared/version-matrix.md`](../../_shared/version-matrix.md)):

| `HYPR_VERSION` | Where `vfr = true` goes |
|---|---|
| `< 0.55` | `misc { vfr = true; … }` |
| `≥ 0.55` | `debug { vfr = true }`  (and `misc {}` no longer carries `vfr`) |

This is the single most common parse error when porting an older config forward — flag it loudly
in the validator's output.

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

## Scrolling layout is CORE in 0.53+ — not a plugin

In 0.52 and earlier, scrolling layouts were provided by the `hyprscrolling` / `hyprscroller`
plugins. In **0.53+** the layout was merged into Hyprland core (see
[`_shared/version-matrix.md`](../../_shared/version-matrix.md)). Implications for this component:

- `general:layout = scrolling` and the top-level `scrolling { … }` block are **safe uncommented**
  on any target ≥ 0.53. They will NOT hard-error the reload.
- `layoutmsg, move +col` / `colresize +conf` / `fit active` etc. are core dispatchers and the
  validator allows them uncommented (see [`_shared/dispatchers.md`](../../_shared/dispatchers.md)).
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
   `layerrule { blur = true }` (waybar, launcher, notifications).

## "Frosted" preset values

If the user explicitly asks for a "frosted glass" look:

```ini
blur {
    enabled  = true
    size     = 6        # vs default 3
    passes   = 2        # vs default 1
    vibrancy = 0.1696
}
```

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

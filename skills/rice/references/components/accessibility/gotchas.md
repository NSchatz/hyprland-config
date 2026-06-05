# accessibility — gotchas

## Larger-UI triggers the fractional-scaling caveat

Bumping monitor `scale` to `1.25` (or any non-integer value) is **fractional scaling**, which
is the exact case `../monitors/gotchas.md` flags. The downstream cost is real: XWayland apps
render blurry unless `xwayland:force_zero_scaling = true` is set, and `GDK_SCALE` must be set
to the integer ceiling (`1.25` → `2`) in `../env/template.md` to keep GTK windows crisp.

The rule: if `accessibility` contains `larger-ui` **and** the picked scale is non-integer, the
`monitors` and `env` writers must follow the full fractional-scaling fix block (see
`../monitors/gotchas.md` — the `monitors.scaling != 1.0` flag is the trigger). Don't ship
larger-UI with a fractional scale and the rest of the gotcha unaddressed; users will see blurry
XWayland fonts and assume the rice is broken.

If the user picks an integer scale bump (e.g. `2.0` on a 4K display), the caveat doesn't apply.

## Magnifier is built-in — no external tool

`cursor:zoom_factor` is a core Hyprland keyword. There is **no separate magnifier package**, no
plugin, no `magnus`/`xzoom` equivalent to install. The `packages.md` for this component
deliberately doesn't list one. If the magnifier bind silently does nothing, the diagnosis is
the Hyprland version (`zoom_factor` lands in 0.40+) — not a missing package.

## Cursor size requires BOTH `XCURSOR_SIZE` and `HYPRCURSOR_SIZE`

Hyprland reads cursor size from two env vars depending on the surface:

- **`XCURSOR_SIZE`** — used by XWayland apps and legacy Wayland apps using `wl_shm` cursors.
- **`HYPRCURSOR_SIZE`** — used by native Hyprcursor-aware apps (the modern Hypr cursor format,
  vector-based, the default since 0.40+).

Emit **both** lines, both at the same size, or the cursor will be inconsistent across surfaces
(small on Hyprland-aware apps, large on XWayland — or vice versa). The `env` component already
emits the pair in lockstep; this component just bumps the value.

A `hyprctl setcursor <theme> <size>` call in `autostart` is also needed so already-running
sessions pick up the new size without a full restart.

## Night-light overlaps `../utilities/` night-light

Both `accessibility` and `utilities` can emit a `hyprsunset` bind. **Pick one home.** The rule:

- If `utilities.selected` contains `"night-light"`, the bind is owned by `utilities` — this
  component does **not** also emit the bind even if `accessibility` contains `"night-light"`.
- If `utilities.selected` does **not** contain `"night-light"` but `accessibility` does, this
  component emits the bind.

The `keybinds` writer dedupes on bind key (`$mainMod SHIFT, N`), so a duplicate is a validator
error, not a silent override. Surface the choice to the user during the review pass if both
groups picked it.

## GTK `cursor-size` doesn't take effect on already-running apps

The GTK settings file (`gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`) is read at app launch.
Bumping `gtk-cursor-theme-size` after the fact means **already-open GTK apps keep the old
size** until restarted. Combine the settings file write with `hyprctl setcursor` (which
re-broadcasts cursor surfaces to all clients) for the best chance of in-session uptake — and
warn the user that a full logout/login is the only sure fix.

## Version note

- `cursor:zoom_factor` — core since 0.40 (well before the rice's 0.50.x minimum).
- `cursor:zoom_rigid` — core; same vintage.
- `hyprsunset` — separate package, version-independent from Hyprland.
- `xwayland:force_zero_scaling` — present in all currently-supported Hyprland versions; see
  `../../_shared/version-matrix.md` for the full scaling-related cliff list.

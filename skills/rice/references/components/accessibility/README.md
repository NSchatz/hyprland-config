# accessibility

Opt-in low-vision / visibility helpers. **All four helpers are off by default**, and the whole
component is a single multi-select with **nothing pre-checked**. If the user checks zero items,
this component writes an empty array to `answers.json` and emits nothing.

The four helpers are pure Hyprland surfaces (cursor zoom, cursor size, monitor scale) plus one
shared utility (`hyprsunset`). This folder owns the **answers slice + the routing rules**; the
actual `.conf` lines all land in sibling components (`keybinds`, `env`, `monitors`, `theming`).

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | The single multi-select call (group 22). Nothing pre-checked. |
| `schema.md` | The `accessibility` key: a string array with four recognised values. |
| `template.md` | The per-helper output map — which sibling file each helper writes into. |
| `gotchas.md` | Fractional-scale caveat for larger-UI, dual-cursor env requirement, night-light home conflict. |
| `packages.md` | `hyprsunset` (only when night-light is selected). |

## Where this component lands

This component doesn't own a `.conf` file of its own. Each selected helper routes to a sibling:

| Helper | Lands in |
|---|---|
| `magnifier` | `../keybinds/template.md` (`SUPER+=`, `SUPER+-` — keysyms `equal` / `minus`) + optional one line in `../look-feel/template.md` (`cursor:zoom_rigid`). |
| `large-cursor` | `../env/template.md` (`XCURSOR_SIZE`, `HYPRCURSOR_SIZE`) + `../autostart/template.md` (`hyprctl setcursor`) + `theming/` GTK `cursor-size` (settings.ini + `gsettings`). |
| `night-light` | `../autostart/template.md` (`exec-once = hyprsunset` — daemon) + `../keybinds/template.md` (two binds: `hyprctl hyprsunset temperature 4000` on; `hyprctl hyprsunset identity` off). Overlaps `../utilities/` night-light — see `gotchas.md`. |
| `larger-ui` | `../monitors/template.md` (bumped `scale`) + `theming/` `gsettings ... text-scaling-factor 1.25`. |

## Related components

- [`monitors`](../monitors/) — owns the `scale` value larger-UI bumps; owns the fractional-scaling gotcha.
- [`env`](../env/) — owns `XCURSOR_SIZE` / `HYPRCURSOR_SIZE` lines.
- [`keybinds`](../keybinds/) — owns `binds.conf`; the magnifier and night-light binds land here.
- [`utilities`](../utilities/) — also has a `night-light` option (overlap; see `gotchas.md`).
- [`look-feel`](../look-feel/) — owns `looknfeel.conf` where `cursor:zoom_rigid` lands.
- [`theming/`](../../theming/) — GTK `cursor-size` and `text-scaling-factor` land in the GTK colors/settings template.

## Opt-in gate behaviour

Per `_interview-protocol.md`: opt-in gates are **always asked**, even on a re-theme. The gate
itself is the multi-select — no separate yes/no precedes it. On zero picks, the component
records `[]` and downstream writers skip every routing rule above.

## Corpus posture (deep-research pass, batch 2)

A survey of the top ~19 Hyprland rices found:

- **Magnifier**: only ~30% ship a `cursor:zoom_factor` bind (dusky, JaKooLit, Matt-FTW).
  Multiplicative `×1.25` with a floor clamp is the cleanest shape; see `template.md`.
- **Night-light**: ML4W and JaKooLit both ship a stateful wrapper script bound to a single key.
  The two-bind IPC shape appears in no popular rice as the primary surface.
- **Large cursor**: every rice that has any opinion sets `XCURSOR_SIZE` + `HYPRCURSOR_SIZE` in
  lockstep. Caelestia + fufexan indirect through hyprlang variables (`$cursorTheme`,
  `$cursorSize`) — the rice should match.
- **High-contrast palette mode**: **zero** rices ship one. See `gotchas.md`.
- **Font-scale variable**: **zero** rices expose a shared font-scale. See `gotchas.md`.
- **Vestibular / motion-off profile**: **zero** rices ship a one-switch animations-off /
  blur-off accessibility profile. See `gotchas.md` — currently a gap, not surfaced in the
  interview.

The four helpers this component already surfaces are the well-trodden ones. The three gaps
above are flagged for the orchestrator, not silently filled.

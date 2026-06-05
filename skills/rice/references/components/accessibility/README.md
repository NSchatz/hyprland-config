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

# accessibility — packages

Most accessibility helpers are **Hyprland-internal** — the magnifier (`cursor:zoom_factor`),
cursor size (env vars + `hyprctl setcursor`), and larger UI (monitor `scale` + GTK settings)
all run on what's already shipped with Hyprland and the toolkits. **One** helper has an
external dependency.

## Map

| Pick | Package | Repo / AUR | Notes |
|---|---|---|---|
| `night-light` | `hyprsunset` | repo (`extra`) | The Hypr-ecosystem warm-temp tool. Replaces `gammastep`/`redshift`/`wlsunset` on Wayland. |
| `magnifier` | — | — | Hyprland-internal (`cursor:zoom_factor`). No package. |
| `large-cursor` | — | — | Env vars + `hyprctl setcursor`. No package; the cursor **theme** itself is handled by the palette/theme pipeline (see `theming/`). |
| `larger-ui` | — | — | Monitor `scale` + GTK setting. No package. |

## Assembly rule

```bash
# Only night-light adds to the package list.
if jq -e '.accessibility | index("night-light")' answers.json >/dev/null; then
  pkgs+=("hyprsunset")
fi
```

If `../utilities/` also emits `hyprsunset` (because the user picked night-light there too),
**don't add it twice**. The installer is idempotent via `pacman --needed`, but the assembly
list should still be deduped before install for clean logging.

## Cross-references

- The night-light bind shape (and the overlap rule with utilities) → `gotchas.md`
- Cursor themes (packaged separately, palette-driven) → `theming/`
- The shared install-script shape → the installer agent's prompt; per-component package maps
  live in their respective `components/<x>/packages.md`.

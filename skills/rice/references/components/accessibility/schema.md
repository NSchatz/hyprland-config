# accessibility — answers.json slice

This component owns a single top-level key, `accessibility`, holding a string array.

```json
{
  "accessibility": ["magnifier", "large-cursor", "night-light", "larger-ui"]
}
```

The array is the multi-select result from group 22. Empty array means "user opted out of every
helper" — the key still exists; downstream writers branch on length, not presence.

## Type

- `accessibility` — **array of strings**. Each element is one of the four recognised values
  below. Order is not significant. Duplicates are not expected; downstream code may dedupe but
  should not error on them.

## Recognised values

| Value | Meaning |
|---|---|
| `"magnifier"` | Cursor zoom via Hyprland's `cursor:zoom_factor`, bound to `SUPER+=` / `SUPER+-`. |
| `"large-cursor"` | Bumped `XCURSOR_SIZE` / `HYPRCURSOR_SIZE` + `hyprctl setcursor` + GTK `cursor-size`. |
| `"night-light"` | `hyprsunset` toggle bound to `SUPER+SHIFT+N`. |
| `"larger-ui"` | Bumped monitor `scale` + GTK `text-scaling-factor 1.25`. |

Any other value is a validator error.

## Who reads this key

| Reader | Use |
|---|---|
| `hyprland-component-writer` (`keybinds`) | Adds the magnifier `SUPER+=` / `SUPER+-` binds and the `SUPER+SHIFT+N` night-light bind when those values are present. |
| `hyprland-component-writer` (`env`) | Adds `XCURSOR_SIZE,32` + `HYPRCURSOR_SIZE,32` to `env.conf` when `large-cursor` is present (or 48 — see `template.md`). |
| `hyprland-component-writer` (`autostart`) | Adds `exec-once = hyprctl setcursor <theme> <size>` when `large-cursor` is present. |
| `hyprland-component-writer` (`monitors`) | Bumps the picked monitor `scale` when `larger-ui` is present (typically to 1.25 or 1.5). |
| `hyprland-component-writer` (`look-feel`) | Adds `cursor:zoom_rigid = true` to `looknfeel.conf` when `magnifier` is present and the user opted into the centred-cursor variant. |
| `theming/` GTK template writer | Sets `cursor-size` (large-cursor) and `text-scaling-factor` (larger-ui) in the GTK 3/4 settings file. |
| `hyprland-package-installer` | Adds `hyprsunset` to the package list when `night-light` is present (only). |

## Validation

- Key is **required** — must be an array, even if empty.
- Every element must match one of the four recognised strings (case-sensitive, lowercase, hyphenated).
- No length constraint upper bound. Length zero is valid (user opted out of everything).

## Cross-references

- Per-helper output routing → `template.md`
- The `XCURSOR_SIZE` / `HYPRCURSOR_SIZE` shape → `../env/schema.md`
- The monitor `scale` field → `../monitors/schema.md`
- The night-light bind overlap with utilities → `../utilities/schema.md`

# look-feel — answers.json slice

Keys this component owns under the top-level `look_feel` key.

```json
{
  "look_feel": {
    "gaps_preset":        "comfortable | tight | none | spacious",
    "rounding":           "rounded | subtle | square",
    "blur_shadows":       "both-on | blur-on-shadows-off | both-off",
    "opacity":            { "active": 1.0, "inactive": 0.9 },
    "animations":         "smooth | snappy | off",
    "border_color":       "palette | custom-gradient",
    "border_gradient":    "rgba(33ccffee) rgba(00ff99ee) 45deg",
    "layout":             "dwindle | master | scrolling",
    "master_orientation": "left | right | top | bottom | center",
    "groups":             false,
    "per_app_rules":      [{ "class": "firefox-developer-edition", "effects": ["pin"] }],
    "blur_toggle":        false
  }
}
```

## Types

| Key | Type | Notes |
|---|---|---|
| `gaps_preset` | string enum | One of `comfortable / tight / none / spacious`. Decides `gaps_in / gaps_out / border_size` in `template.md`. |
| `rounding` | string enum | `rounded` (10) / `subtle` (5) / `square` (0). The template substitutes the integer. |
| `blur_shadows` | string enum | Branches both `blur { enabled }` and `shadow { enabled }` in the decoration block. |
| `opacity.active` | number 0.0–1.0 | Window opacity when focused. Defaults to `1.0`. |
| `opacity.inactive` | number 0.0–1.0 | Window opacity when unfocused. Defaults to `1.0` (only differs on the "slightly translucent inactive" pick). |
| `animations` | string enum | `smooth` (shipped speeds), `snappy` (~0.6× speeds), `off` (`enabled = false`, drop curves). |
| `border_color` | string enum | `palette` → emit `$accent $accent2 45deg`; `custom-gradient` → emit `border_gradient` verbatim. |
| `border_gradient` | string (optional) | Free-text Hyprland gradient. **Required only when `border_color == "custom-gradient"`**; absent otherwise. |
| `layout` | string enum | `dwindle` / `master` / `scrolling`. `scrolling` is core in 0.53+ (see `_shared/version-matrix.md`); any plugin layout (`hy3`) lives in `plugins`. |
| `master_orientation` | string enum | `left / right / top / bottom / center`. **Required only when `layout == "master"`**; absent otherwise. |
| `groups` | boolean | Emit a `group {}` block + bind `SUPER+G` / `SUPER+TAB` in `keybinds`. |
| `per_app_rules` | array of `{class, effects[]}` | Effects are any combination of `float`, `pin`, `pseudo`, `tile`, `workspace <n>`, `opacity <a> <i>`. Consumed by `window-rules`. Empty array is the "no extras" answer. |
| `blur_toggle` | boolean | When true, ships `blur-toggle.sh` and the `SUPER+SHIFT+B` bind. |

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (look-feel) | Renders `looknfeel.conf` from `template.md` substituting every key above. |
| `hyprland-component-writer` (window-rules) | Reads `look_feel.per_app_rules[]` and emits one block-form `windowrule { ... }` per entry. |
| `hyprland-component-writer` (keybinds) | Reads `look_feel.groups` (emits `SUPER+G` togglegroup, `SUPER+TAB` changegroupactive) and `look_feel.blur_toggle` (emits `SUPER+SHIFT+B` exec). |
| `hyprland-component-writer` (plugins) | If `look_feel.layout` were ever set to a plugin name, the plugins component would gate it. (`scrolling` is core; nothing to gate.) |
| `rice retheme` (Mode B) | Re-asks every key in this slice and overwrites them; leaves sibling-component slices alone. |
| validator | Cross-checks: `master_orientation` present iff `layout == "master"`; `border_gradient` present iff `border_color == "custom-gradient"`; `per_app_rules[].effects[]` are known dispatchers/rules. |

## Validation

- `gaps_preset`, `rounding`, `blur_shadows`, `animations`, `border_color`, `layout` are required.
- `opacity` is required; both `active` and `inactive` default to `1.0`.
- `master_orientation` is required when `layout == "master"` and forbidden otherwise.
- `border_gradient` is required when `border_color == "custom-gradient"` and forbidden otherwise.
- `groups` and `blur_toggle` are required booleans (the gate question always runs).
- `per_app_rules` is required; `[]` is the "no extras" answer (the question still gets asked —
  see `_interview-protocol.md`).

## Sibling slices NOT owned here

- `palette.*` → `theming/palettes.md` — but the engine's `$accent`/`$accent2`/`$muted`/`$surface`
  variables flow through `colors.conf` and are referenced by this component's template.
- `keybinds.extras[]` may include `blur-toggle`; that's an alternative path to `look_feel.blur_toggle`
  living in the `keybinds` slice. Treat `look_feel.blur_toggle = true` as canonical here.

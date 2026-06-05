# window-rules — answers.json slice

This component **owns no top-level key** in `answers.json`. It is a pure consumer: its template
stitches together schema slices owned by sibling components. The slices it reads are listed below
with their **owning component** so the source of truth is unambiguous.

## Read paths (owned elsewhere)

```json
{
  "look_feel": {
    "per_app_rules": [
      { "class": "kitty",   "effects": ["opacity = 0.92 0.85"] },
      { "class": "Spotify", "effects": ["workspace = 9 silent"] }
    ]
  },
  "monitors": {
    "pin_apps": {
      "firefox": "1",
      "Spotify": "9",
      "discord": "9"
    },
    "workspace_rules": {
      "smart_gaps": true,
      "scratchpad": "magic",
      "persistent": ["1", "2", "9"]
    }
  }
}
```

## Types

### `look_feel.per_app_rules` — array of rule objects (owned by `../look-feel/schema.md`)

Each element:

| Field | Type | Notes |
|---|---|---|
| `class` | string | The `match:class` regex body (no anchors — the template wraps it in `^( … )$`). E.g. `kitty`, `[Ff]irefox`. |
| `effects` | array of strings | Rule properties verbatim, one per emitted line inside the `windowrule { … }` block. Every line must be `<effect> = <value>` (Hyprlang special-category syntax). E.g. `"float = yes"`, `"opacity = 0.92 0.85"`, `"workspace = 9 silent"`, `"no_blur = true"`. The template trusts these strings and emits them as-is. See `gotchas.md` for the canonical 0.54.3 effect name list (snake_case — `no_blur` not `noblur`, `border_color` not `bordercolor`, etc.). |

May be absent or `[]`; the template just skips the per-app iteration.

### `monitors.pin_apps` — object of class→workspace (owned by `../monitors/schema.md`)

Map of `class string → workspace string` (the workspace is a string so `"name:web"` and
`"special:magic"` are valid alongside numeric `"1"`–`"10"`). Each entry becomes one
`windowrule { match:class = ^(<class>)$; workspace = <ws> silent }` block. The `silent` suffix is
emitted unconditionally — see `gotchas.md`.

May be absent or `{}`.

### `monitors.workspace_rules.smart_gaps` — bool (owned by `../monitors/schema.md`)

When `true`, the template emits the paired smart-gaps `windowrule`s (`border_size = 0` and
`rounding = 0` on `match:float = false; match:workspace = w[tv1]`). **Note:** the matchers are
`match:float` (not `match:floating`) and `match:workspace` (not `match:onworkspace`) — see
`gotchas.md` for the canonical matcher list. The companion `workspace = w[tv1], gapsout:0,
gapsin:0` line is **not** emitted here — it lives in `monitors.conf` because it's a workspace
rule, not a window rule.

### Chosen-tool flags (read for `layerrule` blocks)

| Source key | Used for |
|---|---|
| `waybar.enabled` (owned by `../waybar/schema.md`) | Emit `layerrule blur-waybar` if `true`. The block uses `blur_popups = true`, `xray = true`, `ignore_alpha = 0.5` — see `template.md` "Waybar layerrule — beyond just blur = true" for the per-rice citations. |
| `launcher.tool` (owned by `../launcher/schema.md`) | Map tool name → **namespace string** and emit `layerrule blur-<namespace>`. Map (verified, see `gotchas.md` "Launcher → namespace map"): `rofi`→`rofi`, **`fuzzel`→`launcher`** (NOT `fuzzel`), `wofi`→`wofi`, `anyrun`→`anyrun`, `walker`→`walker`. Only emit when the tool is a layer-shell surface. |
| `launcher.is_layer` (derived) | Set to `false` for transient X-popup launchers (e.g. dmenu). The template guards the `layerrule` on this. |
| `launcher.namespace` (derived) | The namespace string from the map above. The component writer **must** populate this from `launcher.tool` using the table — do not ask the user for it. |
| `notifications.tool` (owned by `../notifications/schema.md`) | Map tool → namespace(s) and emit blur block(s). **`swaync` emits TWO blocks**, one for each namespace (`swaync-control-center` and `swaync-notification-window`) — see `gotchas.md` "swaync exposes TWO namespaces". `mako` and `dunst` both use namespace `notifications`. |
| `utilities.session_picker` (owned by `../utilities/schema.md`) | If `wlogout`, emit `layerrule blur-logout_dialog` (`logout_dialog` is wlogout's namespace; verified across end-4, dusky, hyprdots, caelestia). |

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (`window-rules`) | Renders `windowrules.conf` from `template.md`, version-branching by `HYPR_VERSION`. |
| `validator` | Checks that emitted `match:` fields and rule properties exist for the target version (per `_shared/version-matrix.md`). |

## Validation

- Empty `per_app_rules` / `pin_apps` are fine — the template just emits the shipped-default rules.
- A class regex with unbalanced parens or unescaped `(`/`)` in `class` strings fails the reload —
  pre-validate before write (`hyprctl reload` rolls back via `safe-apply.sh`).
- See `gotchas.md` for the 0.54+ `layerrule` hard break — the writer **must** branch on version
  before emitting any `layerrule`.

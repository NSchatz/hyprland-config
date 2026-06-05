# waybar — answers.json slice

Keys this component owns under the top-level `bar` key.

```json
{
  "bar": {
    "strategy": "waybar | waybar+widgets | full-shell | hyprpanel | none",
    "form":     "top | bottom | vertical-left | vertical-right | dual",
    "height":   34,
    "archetype": "floating-islands | separated-pills | single-lozenge | edge-to-edge | powerline | dock",
    "corner":   "rounded | pill | subtle | square",
    "transparency": "opaque | translucent | glassy | frosted",
    "depth":    "flat | shadow | ring | inset-glow",
    "workspace_indicator": "pill-fill | underline | dots | numbers",
    "accent_strategy":    "single | per-module | monochrome | semantic-state",
    "accent_application": "text | inverted-pill",
    "motion":   "smooth | snappy | none",
    "modules":  ["workspaces","window","clock","pulseaudio","network","cpu","memory","tray"],
    "grouping": "inline | drawer | powerline",
    "clock_format": "24h-date-tooltip | 12h | date-inline"
  }
}
```

## Types

| Key | Type | Default | Notes |
|---|---|---|---|
| `bar.strategy` | enum | `waybar` | Gate. `full-shell`/`hyprpanel` short-circuit the rest of the interview; `none` skips the whole component. |
| `bar.form` | enum | `top` | `vertical-*` and `dual` flip the template — see `styling.md` → *Bar form*. |
| `bar.height` | int (px) | `34` | On vertical bars, repurposed as the column **width** (32–44). |
| `bar.archetype` | enum | `floating-islands` | Sets `style.css` skeleton. |
| `bar.corner` | enum | `rounded` | Sets `border-radius` constant — `rounded` ≈ 12px, `pill` ≈ 999px, `subtle` ≈ 4px, `square` = 0. |
| `bar.transparency` | enum | `translucent` | Anything non-opaque demands the `layerrule` blur block in `window-rules`. |
| `bar.depth` | enum | `flat` | Adds `box-shadow` / `border` / `inset` to the islands. |
| `bar.workspace_indicator` | enum | `pill-fill` | Drives `#workspaces button.active` rule. |
| `bar.accent_strategy` | enum | `single` | `per-module` activates the 12-name palette across CPU/mem/network/clock; others use mainly `@accent`. |
| `bar.accent_application` | enum | `text` | `inverted-pill` flips `background:@accent; color:@bg`. |
| `bar.motion` | enum | `smooth` | `none` strips all `transition` / `@keyframes`; `snappy` adds spring easing + blink-critical. |
| `bar.modules` | string[] | sensible-set | Drives both `modules-left/center/right` placement and which module config blocks land in `config.jsonc`. Order is meaningful. |
| `bar.grouping` | enum | `inline` | `drawer` collapses cpu/mem/temp behind `group/stats`; `powerline` chains arrow-separator modules. |
| `bar.clock_format` | enum | `24h-date-tooltip` | Maps to the `clock` module's `format` / `tooltip-format` strings. |

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (waybar) | Reads every key. Writes `~/.config/waybar/config.jsonc` (`bar.{modules, grouping, clock_format, form}`) and `~/.config/waybar/style.css` (`bar.{archetype, corner, transparency, depth, workspace_indicator, accent_*, motion, height}`). |
| `hyprland-component-writer` (autostart) | Reads `bar.strategy`; emits `exec-once = waybar` only when `strategy` ∈ `{waybar, waybar+widgets}`. |
| `hyprland-component-writer` (window-rules) | Reads `bar.transparency`; emits the `layerrule { ... blur = true }` block when `transparency != opaque`. |
| `hyprland-component-writer` (widgets) | Reads `bar.strategy`; when `full-shell`/`hyprpanel`, **owns** the bar surface and ignores everything else in this slice. |
| `hyprland-component-writer` (notifications) | Reads `bar.modules`; if `custom/notification` is present, asserts the chosen `notifications.daemon == "swaync"` (see `gotchas.md`). |
| `hyprland-package-installer` | Reads `bar.strategy` + `bar.modules` against `packages.md`; adds `waybar`, plus the on-click tools each enabled module requires. |
| Rice engine (`render-templates.sh`) | Reads palette → writes `~/.config/waybar/colors.css` (the 12 `@define-color` names — see [`_shared/colors-contract.md`](../../_shared/colors-contract.md)). The component's `style.css` `@import "colors.css";` makes those names available. |

## Validation

- `bar.strategy` required.
- When `bar.strategy ∈ {waybar, waybar+widgets}`: `form`, `archetype`, `corner`, `transparency`,
  `workspace_indicator`, `accent_strategy`, `accent_application`, `motion`, `modules` are all
  required.
- `bar.modules` is order-sensitive: the renderer slices it into `modules-left/center/right` based
  on a fixed partition (workspaces+window → left; clock+mpris → center; the rest → right).
- If `bar.modules` includes `custom/notification`, `notifications.daemon` **must** be `swaync`.
- If `bar.modules` includes `backlight`, the writer must verify `/sys/class/backlight/*` is
  non-empty at install time (laptop-only).

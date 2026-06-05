# monitors — answers.json slice

Keys this component owns under the top-level `monitors` key.

```json
{
  "monitors": {
    "setup": "single-auto | single-specific | dual-side-by-side | complex",
    "list": [
      {
        "name":      "DP-1",
        "mode":      "2560x1440@144",
        "pos":       "0x0",
        "scale":     1.0,
        "transform": 0,
        "vrr":       0,
        "bitdepth":  8,
        "mirror":    null,
        "icc":       null,
        "disabled":  false
      }
    ],
    "scaling":         1.0,
    "dock_undock":     false,
    "workspace_rules": {
      "1-5":        "DP-1",
      "6-10":       "HDMI-A-1",
      "scratchpad": false,
      "smart_gaps": false
    },
    "pin_apps": { "firefox": 1, "thunderbird": 9 }
  }
}
```

## Types

- `monitors.setup` — string, one of `single-auto`, `single-specific`, `dual-side-by-side`,
  `complex`. Drives how `template.md` chooses between a catch-all `monitor =, preferred, auto, auto`
  line and explicit per-output lines.
- `monitors.list` — array of monitor objects. **Always populated** (even for `single-auto` — one
  entry with `name: ""` and `mode: "preferred"`). Per-entry fields:
  - `name` — string. Detected from `hyprctl monitors`, or a placeholder (`DP-1`, `HDMI-A-1`,
    `eDP-1`), or a `desc:Dell Inc. ...` string for dock/undock (1d).
  - `mode` — string. `WxH@R`, `preferred`, `highrr`, `highres`, `maxwidth`, or a full `modeline …`
    string. The "highrr" / "highres" magic modes pick the highest refresh / resolution from the
    monitor's reported mode list.
  - `pos` — string. `<X>x<Y>` (e.g. `0x0`, `2560x0`) or one of `auto`, `auto-right`, `auto-left`,
    `auto-up`, `auto-down`, `auto-center-right` / `auto-center-left` / `auto-center-up` /
    `auto-center-down`. Negative coordinates are valid (Hyprland uses an inverse-Y layout).
  - `scale` — number. `1.0` / `1.5` / `2.0` / custom float, or the string `"auto"` (Hyprland picks
    a scale based on PPI; valid alongside any mode value, not just `preferred`). Invalid
    fractional scales that don't yield integer logical pixels emit a runtime warning.
  - `transform` — integer 0–7 (0 normal; 1/2/3 = 90/180/270°; 4–7 = flipped variants).
  - `vrr` — integer 0–3 (0 off, 1 on, 2 fullscreen-only, 3 fullscreen with `video` or `game`
    content type — the per-window `content` rule drives mode 3).
  - `bitdepth` — integer, `8` or `10`.
  - `mirror` — string or null. Name of the source monitor when mirroring; null otherwise.
  - `icc` — string or null. **Absolute** path to an ICC profile (`.icm`); null otherwise. Applying
    an ICC forces `sdr_eotf=sRGB` on that output and overrides any `cm` color-management preset.
  - `disabled` — boolean. When `true`, the template emits `monitor = NAME, disable` (no other
    fields). Removes the output from the layout; use the `dpms` dispatcher instead for a
    screensaver-style power-off.
- `monitors.scaling` — number. The **global** answer to 1b. Mirrors the scale of the primary
  monitor; the per-monitor `list[*].scale` is the source of truth for the template. Carried
  separately so `../env/` can branch (`!= 1.0` → emit `GDK_SCALE,N`) without iterating the list.
- `monitors.dock_undock` — boolean. `true` switches the template to `desc:`-prefixed monitor
  lines and triggers the `kanshi`/`shikane` package pick in `packages.md`.
- `monitors.workspace_rules` — object. Range-keyed map of `"<low>-<high>": "<monitor-name>"`
  entries (e.g. `"1-5": "DP-1"`), plus two booleans: `scratchpad` and `smart_gaps`. Empty `{}`
  when 1e is "No."
- `monitors.pin_apps` — object. `class -> workspace_number` map. Empty `{}` when 1f is "No."
  Consumed by `../window-rules/`, **not** rendered into `monitors.conf`.

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (monitors topic — `monitors.conf`) | Renders `monitor = …` lines from `list[]`, the `workspace = …` block from `workspace_rules`, smart-gaps `windowrule` lines, and the `desc:` catch-all when `dock_undock`. |
| `hyprland-component-writer` (`env`) | If `scaling != 1.0`, emits `env = GDK_SCALE,N` (rounded up). |
| `hyprland-component-writer` (Hyprland top-level / `look-feel`) | If `scaling != 1.0`, emits `xwayland { force_zero_scaling = true }`. |
| `hyprland-component-writer` (`window-rules`) | Reads `pin_apps`; emits one `windowrule = workspace N silent, match:class ^(<cls>)$` per entry (anonymous form), or the equivalent `windowrule { name = pin-<cls>; match:class = ^(<cls>)$; workspace = N silent }` block on 0.53+. |
| `hyprland-package-installer` | Reads `dock_undock`; if `true`, adds `kanshi` (or `shikane`) per `packages.md`. |
| validator | Cross-checks every `monitor:NAME` referenced by `workspace_rules` against the names in `list[]`. |

## Validation

- `setup` is required.
- `list` must be non-empty; every entry must have `name` and `mode` set (other fields default to
  0/`null`/`8`/`auto` as listed above).
- `scaling` is required; `1.0` is the no-op value, not an absent key.
- `dock_undock` is required (boolean — never absent).
- `workspace_rules` and `pin_apps` are required objects; `{}` represents "user said No."
- When `dock_undock == true`, at least one `list[]` entry should have `name` starting with `desc:`.
- Every monitor named in `workspace_rules` (right-hand side of a range key) must appear in
  `list[].name` (sans `desc:` prefix matching is OK), else the validator errors.

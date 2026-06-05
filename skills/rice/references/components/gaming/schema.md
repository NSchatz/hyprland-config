# gaming — answers.json slice

Keys this component owns under the top-level `gaming` key.

```json
{
  "gaming": {
    "enabled": false,
    "tearing_classes": ["^(cs2)$", "^(steam_app_\\d+)$"],
    "vrr_mode": 0,
    "strip_fullscreen_effects": true,
    "gamemode_toggle": true
  }
}
```

## Types

| Key | Type | Allowed values | Notes |
|---|---|---|---|
| `gaming.enabled` | bool | `true` / `false` | The gate. On `false`, every downstream reader treats the other keys as their off-defaults and emits nothing. |
| `gaming.tearing_classes` | array of string | regex strings matched against window `class` | Empty array (`[]`) means tearing is off. Each entry is a Hyprland window-rule `match:class` pattern — surface as-given, do not auto-anchor. |
| `gaming.vrr_mode` | integer | `0`, `2`, `3` (also `1` if hand-edited) | `0` off, `1` always-on (not offered in the interview but legal if a user hand-edits), `2` fullscreen-only, `3` content-aware. |
| `gaming.strip_fullscreen_effects` | bool | `true` / `false` | Emits six `match:fullscreen = true` block rules: `no_blur`, `border_size = 0`, `rounding = 0`, `no_anim`, `no_shadow`, `idle_inhibit = fullscreen`. (Note: `no_border` is not a valid field — verified against the 0.54 and main Window-Rules wikis.) The `idle_inhibit` rule duplicates a default already shipped by the `window-rules` component; the writer should de-dupe. |
| `gaming.gamemode_toggle` | bool | `true` / `false` | Installs `gamemode.sh` and binds `SUPER+F1` to it. |

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (`look-feel`) | If `tearing_classes` is non-empty → set `general:allow_tearing = true` in `looknfeel.conf`. |
| `hyprland-component-writer` (`window-rules`) | One `windowrule { immediate = true }` block per entry in `tearing_classes`; the six `match:fullscreen = true` effect-strip rules when `strip_fullscreen_effects` is true (de-dupe `idle_inhibit` against the shipped default). |
| `hyprland-component-writer` (`monitors`) | Appends `, vrr, {{vrr_mode}}` to every `monitor =` line when `vrr_mode != 0`. |
| `hyprland-component-writer` (`keybinds`) | Emits `bind = $mainMod, F1, exec, ~/.config/hypr/scripts/gamemode.sh` when `gamemode_toggle` is true. |
| `hyprland-component-writer` (`env`) | Emits **nothing**. Hyprland's aquamarine backend (since 0.42) ignores `WLR_*` env vars; the aquamarine equivalent `AQ_NO_ATOMIC` is upstream-flagged "not recommended" — see `gotchas.md`. |
| `hyprland-package-installer` | Optional `gamemoded` pick — see `packages.md`. |
| Script-install step | When `gamemode_toggle` is true, copies `gamemode.sh` to `~/.config/hypr/scripts/` and `chmod +x`. |

## Validation

- `enabled` is required (the gate answer is always recorded — even the `false` branch persists
  the other keys as their off-defaults).
- `tearing_classes` may be `[]`; never `null`.
- `vrr_mode` must be one of `0 | 1 | 2 | 3` (the interview only offers `0 | 2 | 3`; `1` is
  hand-edit-only).
- `strip_fullscreen_effects` and `gamemode_toggle` are bools, no `null`.

## Cross-references

- Where each key turns into config lines → [`template.md`](template.md).
- Why no env line is emitted (aquamarine since 0.42) → [`gotchas.md`](gotchas.md) and
  [`../env/gotchas.md`](../env/gotchas.md) "2026 slim NVIDIA set".
- Per-monitor `vrr` field shape (positional `, vrr, N` on 0.54-ish hyprlang; `vrr = N` key in
  the lua `hl.monitor({...})` form on 0.55+) → [`../monitors/template.md`](../monitors/template.md)
  and the monitors-schema entry it consumes.

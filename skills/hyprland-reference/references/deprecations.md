# Hyprland Deprecated / Renamed Options

Hyprland evolves quickly and option names move between releases. Old blog posts and starter
configs frequently use removed syntax. Check anything suspicious here. When a real system is
available, confirm the installed version with `hyprctl version` and consult the official wiki
for that release.

Use this list when **auditing/validating** a config: each entry is a `OLD → NEW` mapping plus a
note on which behavior to expect.

## Decoration: shadow

| Deprecated (top-level `decoration:`) | Modern (`decoration:shadow {}`) |
|--------------------------------------|----------------------------------|
| `drop_shadow = true`                 | `shadow { enabled = true }`      |
| `shadow_range = 4`                   | `shadow { range = 4 }`           |
| `shadow_render_power = 3`            | `shadow { render_power = 3 }`    |
| `col.shadow = rgba(...)`             | `shadow { color = rgba(...) }`   |
| `shadow_offset`, `shadow_scale`      | `shadow { offset = .. , scale = .. }` |

## Decoration: blur

| Deprecated                  | Modern (`decoration:blur {}`)         |
|-----------------------------|----------------------------------------|
| `blur = true` (bool)        | `blur { enabled = true }`              |
| `blur_size`, `blur_passes`  | `blur { size = .. , passes = .. }`     |
| `blur_new_optimizations`    | `blur { new_optimizations = true }`    |

## Master layout

| Deprecated                  | Modern                                 |
|-----------------------------|----------------------------------------|
| `master:new_is_master = true` | `master:new_status = master`         |
| `master:no_gaps_when_only`  | workspace rule / removed               |
| `master:orientation` values | unchanged (`left/right/top/bottom/center`) |

## Dwindle

| Deprecated                          | Modern                          |
|-------------------------------------|---------------------------------|
| `dwindle:no_gaps_when_only`         | removed — use a `workspace` rule with `gapsout:0` |

## Cursor (moved out of general/input)

| Deprecated                          | Modern (`cursor {}`)            |
|-------------------------------------|---------------------------------|
| `general:no_cursor_warps`           | `cursor:no_warps`               |
| `general:cursor_inactive_timeout`   | `cursor:inactive_timeout`       |
| `input:no_hardware_cursors`         | `cursor:no_hardware_cursors`    |
| `misc:no_hardware_cursors` (older)  | `cursor:no_hardware_cursors`    |

## General / input

| Deprecated                          | Modern                          |
|-------------------------------------|---------------------------------|
| `general:sensitivity`               | `input:sensitivity`             |
| `general:apply_sens_to_raw`         | `input:sensitivity` behavior / removed |
| `general:damage_tracking`           | removed (auto)                  |

## Misc

| Deprecated                          | Modern                          |
|-------------------------------------|---------------------------------|
| `misc:no_vfr = false`               | `misc:vfr = true` (inverted)    |
| `misc:vfr` (≤0.54)                  | `debug:vfr` (moved in **0.55** — now a debug variable) |
| `misc:render_ahead_of_time`         | removed                         |
| `misc:layers_hog_keyboard_focus`    | renamed/relocated; verify       |

## Window rules

| Older form                          | Modern (0.53+)                  |
|-------------------------------------|---------------------------------|
| `windowrulev2 = float, class:^(x)$` | `windowrule = float, class:^(x)$` (v2 matcher merged into `windowrule`) |
| single-line `windowrule = ...`      | `windowrule { match:class = ...; float = yes }` block form |

The **block form** (`windowrule { name=…; match:<field>=…; <prop>=… }`) arrived around **0.53**
and is what the shipped 0.54 default uses. Single-line forms still parse (compat), but emit the
block form on 0.53+. JaKooLit's dotfiles literally ship `WindowRules-pre-53.conf` vs
`WindowRules-config-v3.conf` to handle the break. See `window-rules.md`.

## Layer rules

| Older form                  | Modern (0.54+)                                                   |
|-----------------------------|-----------------------------------------------------------------|
| `layerrule = blur, waybar`  | `layerrule { name = …; match:namespace = waybar; blur = true }` block form |

`layerrule` moved to the same unified **block form** as `windowrule`, with `name` as the required
key. **Unlike `windowrule`, this is a hard break** — on 0.54.3 the single-line
`layerrule = blur, waybar` is *rejected* at parse time with:

```
Config error: invalid field blur: missing a value
... special category's first value must be the key. Key for <layerrule> is <name>
```

So a single bad `layerrule =` line fails the whole reload (and rolls back under `safe-apply.sh`).
Emit the block form on 0.54+:

```ini
layerrule {
    name = blur-waybar
    match:namespace = waybar
    blur = true
}
```

Properties map from the old single-line keyword: `blur, ns` → `blur = true`,
`noanim, ns` → `no_anim = true` (underscore). Other verified 0.54.3 fields: `ignore_alpha = <0-1>`,
`xray = true`, `animation = <style>`. Note there is **no** `ignore_zero`/`ignorezero` field in the
block form (use `ignore_alpha`). Match the surface with `match:namespace = <ns>` (find namespaces
via `hyprctl layers`). All field names above verified on 0.54.3 via `hyprctl keyword source`. On
older targets that reject the block form, keep the single-line form.

## Dispatchers / binds

| Older form                          | Modern                          |
|-------------------------------------|---------------------------------|
| `bind = $m, J, togglesplit`         | `bind = $m, J, layoutmsg, togglesplit` (split toggle is a layout message) |

## Removed / moved in 0.55 (latest stable)

Hyprland 0.55 (latest stable upstream; this machine runs 0.54.3) dropped or relocated several
options. Flag these when auditing a config that targets 0.55+:

| Old (≤0.54)                       | 0.55+                                                        |
|-----------------------------------|-------------------------------------------------------------|
| `misc:vfr`                        | `debug:vfr` (reclassified as a debug variable)              |
| `dwindle:pseudotile`              | **removed** (was non-functional; the `pseudo` dispatcher/`windowrule = pseudo` still work) |
| `decoration:shadow:ignore_window` | **removed** — that behavior is now always on (shadows skip the window's own area) |
| `render:cm_fs_passthrough`        | **removed** — automatic when `render:cm_auto_hdr` is set    |

These are hard removals: leaving the old key in a config on 0.55 is a parse error. On ≤0.54 keep
them. Branch on `hyprctl version`.

### 0.55 also *adds* (not deprecations, but worth knowing when on 0.55+)

- **Lua is the config language** (`~/.config/hypr/hyprland.lua`), and a `hyprland.lua` is loaded
  **instead of** `hyprland.conf` when both are present. hyprlang is supported for **1 - 2 releases
  starting from 0.55**, after which it is dropped, and no new config features are added to it
  ([upstream](https://hypr.land/news/26_lua/)), so `.conf` is a closing window, not an
  indefinite one. What this plugin emits is decided by
  `${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/config-language.sh`, not assumed. See the Lua notes in
  `config-syntax.md` / `keybindings.md`.
- **User-defined layouts** — a Layout API to define custom layouts in-config, per-workspace /
  per-monitor / globally (`layout = <name>`).
- **Spring animations** — a spring-based curve in addition to bezier (`animation = …, …, …, spring`).
- **Glow** decoration effect for windows (`decoration { … }`).
- Per-output **ICC profiles** via `icc = "<path>"` on a `monitor`/output; FP16 + improved color
  pipeline on by default.
- New window rule `confine_pointer`; scrolling-layout rules/messages (`scrolling_width`,
  `expel`/`consume`/`consume_or_expel`, `rotatesplit`); binds flag `auto_consuming`; input
  **device tags** for device-specific binds.
- Dispatcher `moveintoorcreategroup`; `groupbar:middle_click_close`.

## New options to know (not deprecations, but recent additions)

- `decoration:rounding_power` (0.5x) — corner curve exponent.
- `gesture = FINGERS, DIR, ACTION` keyword (0.45+) — replaces the `gestures {}` swipe block.
- `ecosystem { enforce_permissions }` + `permission =` lines — opt-in permission system
  (requires Hyprland restart to apply).
- `monitor = , preferred, auto, auto` — scale `auto` lets Hyprland choose (incl. fractional).

## Gestures (recent rework)

Newer Hyprland introduced a `gesture = ...` keyword API and may deprecate the
`gestures { workspace_swipe = ... }` block:

```ini
# Newer API
gesture = 3, horizontal, workspace
gesture = 4, horizontal, move
```

If targeting an older version, keep the `gestures {}` block. If the installed version is recent
and rejects `gestures:workspace_swipe`, migrate to the `gesture =` form.

## How to verify against the live system

- `hyprctl version` — installed version/commit.
- `hyprctl configerrors` — current parse errors from the running instance.
- `hyprctl getoption decoration:rounding` — confirm an option exists and its value/type.
- Official wiki "Configuring" pages are versioned; match the page to the installed release.

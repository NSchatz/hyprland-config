# Hyprland version matrix (cross-cutting)

What's been added, removed, renamed, and how rice components branch by version. Authoritative
deprecation list: `${CLAUDE_PLUGIN_ROOT}/skills/hyprland-reference/references/deprecations.md` —
this file summarizes the *branches the rice components have to make* on top of that. Branch on the
`HYPR_VERSION` field that `scripts/detect-version.sh` emits.

## Version cliffs that components branch on

| Cliff | What changed | Components affected |
|---|---|---|
| **0.45+** | `gesture = FINGERS, DIR, ACTION` keyword API replaces `gestures { workspace_swipe = … }` block. | `input` (gestures sub-question). Older targets use the block form. |
| **0.53+** | Window-rule **block form** (`windowrule { match:class = …; float = yes }`) is the shipped default. Single-line `windowrule = float, class:…` still parses for backward compat. | `window-rules`, `look-feel` (window-groups), `monitors` (workspace smart-gaps rules). |
| **0.53+** | `scrolling` is **core** (not a plugin). `general:layout = scrolling` + `scrolling {}` block + `layoutmsg` binds — safe uncommented. The old `hyprscrolling`/`hyprscroller` plugins are deprecated/superseded. | `look-feel` (layout option), `keybinds` (`layoutmsg, move +col` etc.), `plugins` (do NOT offer scrolling as a plugin). |
| **0.53+** | `decoration:rounding_power` added — corner-curve exponent. Use 2 by default; 2.3–4 for softer "squircle". | `look-feel`. |
| **0.54+** | `layerrule` moved to the **block form**. **HARD BREAK**: single-line `layerrule = blur, waybar` is *rejected* at parse time (`invalid field blur: missing a value`) and fails the entire reload. Use `layerrule { name = …; match:namespace = …; blur = true }`. | `window-rules` (the `layerrule` blocks), `waybar`, `launcher`, `notifications` (their blur rules). |
| **0.54+** | Verified `layerrule` block fields: `blur`, `no_anim`, `ignore_alpha = <0-1>`, `xray`, `animation = <style>`. **No `ignore_zero`** in block form. | `window-rules`. |
| **0.55+** | `misc:vfr` → `debug:vfr` (reclassified). Leaving `misc:vfr` set on 0.55 is a parse error. | `look-feel` (the `misc {}` block; `vfr = true` is set unconditionally as a default — branch the section by version). |
| **0.55+** | `dwindle:pseudotile` **removed** (was non-functional). The `pseudo` dispatcher and `windowrule = pseudo` still work. | `look-feel` (dwindle layout block — omit on 0.55+). |
| **0.55+** | `decoration:shadow:ignore_window` **removed** — behavior is now always on. | `look-feel`. |
| **0.55+** | `render:cm_fs_passthrough` **removed** — automatic when `render:cm_auto_hdr` is set. | (rarely used; uninvolved in defaults). |
| **0.55+** | **Lua is the default config language** (`~/.config/hypr/hyprland.lua`); hyprlang `.conf` "remains functional for several releases." | All components — rice still emits `.conf` on 0.55+; track when to switch. |
| **0.55+** | `decoration { glow {} }` (new effect), spring-based animation curve (`animation = …, …, …, spring`), per-output ICC `icc = "<path>"`, dispatcher `moveintoorcreategroup`, `groupbar:middle_click_close`, scrolling-layout rules/messages (`scrolling_width`, `expel`/`consume`/`consume_or_expel`, `rotatesplit`), input device tags. | (additive — opt-in surfaces). |

## Quick decision flow

```
detect-version → HYPR_VERSION

if HYPR_VERSION ≥ 0.55:
  - emit debug:vfr instead of misc:vfr
  - omit dwindle:pseudotile from layout block
  - omit decoration:shadow:ignore_window
  - layerrule  → block form
  - windowrule → block form (already 0.53+)
  - scrolling layout safe uncommented (already 0.53+)

elif HYPR_VERSION ≥ 0.54:
  - layerrule → block form (HARD: line form fails parse)
  - keep misc:vfr (not yet moved)
  - keep dwindle:pseudotile

elif HYPR_VERSION ≥ 0.53:
  - windowrule → block form (preferred; line form still parses)
  - layerrule → line form (block form not yet)
  - scrolling layout core

elif HYPR_VERSION ≥ 0.45:
  - gesture = … keyword API
  - windowrulev2 / line forms

else:
  - gestures {} block
  - windowrulev2 prefix
```

## Components' job

Each component's `gotchas.md` notes the version branches that touch its template; this matrix is
the index. The **validator** uses this file (plus `deprecations.md`) to flag deprecated syntax
emitted against the wrong target.

## Detect

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/detect-version.sh"
# HYPR_VERSION=0.54.3
# HYPR_VERSION_MAJOR=0  HYPR_VERSION_MINOR=54  HYPR_VERSION_PATCH=3
```

If neither `hyprctl` nor `Hyprland` is on PATH, assume the latest stable syntax and tell the user.

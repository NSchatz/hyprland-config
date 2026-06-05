# window-rules

Owns `~/.config/hypr/windowrules.conf` — the `windowrule { … }` and `layerrule { … }` blocks that
shape per-window behavior (float, pin, send-to-workspace, opacity) and per-layer surface effects
(blur on bar/launcher/notifications). This is an **infrastructure** component: it has no dedicated
interview group of its own. The picks that drive it are collected by sibling components whose
interview flow naturally raises them.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | No questions of its own — pointer to the sibling groups (`look-feel` 11i, `monitors` 1e + 1f) that collect everything this component emits. |
| `schema.md` | The schema slices this component **reads** (it owns no `answers.json` keys itself): `look_feel.per_app_rules`, `monitors.pin_apps`, `monitors.workspace_rules`, plus chosen-tool flags from `waybar`/`launcher`/`notifications`. |
| `template.md` | The full `windowrules.conf` template — shipped defaults, float-utilities, PiP-pin, idleinhibit-fullscreen, per-app rule iteration, and the `layerrule` blur block. Version-branched (cites `_shared/version-matrix.md`). |
| `gotchas.md` | The 0.53+ `layerrule = blur, <ns>` legacy form is **rejected at parse and fails the reload** (`invalid field blur: missing a value`); the modern single-line `layerrule = blur on, match:namespace <ns>` parses, but we emit the block form. Plus: `match:` prefix on matchers, the snake_case rename for matchers (`initial_class`, `float`, `workspace`), verified 0.54.3 block-form fields, `windowrule` block preferred on 0.53+, `windowrulev2` hard-rejected. |
| `packages.md` | None — window rules are built into Hyprland. |

## Where this component lands

- **Hyprland config:** `~/.config/hypr/windowrules.conf`, sourced from `hyprland.conf` (the
  top-level `source = ~/.config/hypr/windowrules.conf` line lives in the keybinds component's
  `hyprland.conf` template).
- **No colors file.** Window rules don't theme — `bordercolor` overrides are emitted from
  `look-feel` (the borders block) when a user asks for a per-app border tint, not here.
- **No keybinds.** The runtime `SUPER+SHIFT+B` blur-toggle (look-feel 11j) goes in
  `binds.conf`, not `windowrules.conf`.

## Interview sources (where the data comes from)

This component **emits** rules, but the **answers** are collected elsewhere:

| Group | Lives in | Feeds |
|---|---|---|
| 1e — workspace rules (bind 1–5→primary, persistent, smart gaps, scratchpad) | `../monitors/interview.md` | `monitors.workspace_rules` → mostly `monitors.conf`, but smart-gaps emits paired `windowrule` lines here. |
| 1f — pin apps to workspaces (class → workspace) | `../monitors/interview.md` | `monitors.pin_apps` → per-app `workspace N silent` rules in this component's template. |
| 11i — per-app window rules (float / pin / opacity / send-to-workspace beyond the defaults) | `../look-feel/interview.md` | `look_feel.per_app_rules` → arbitrary `windowrule` blocks in this component's template. |

If a downstream pass discovers a missing pick, **re-ask in the sibling component that owns the
group** (don't invent a question here) and re-record. See `_interview-protocol.md`.

## Related components

- [`monitors`](../monitors/) — collects 1e (workspace rules) + 1f (pin apps); writes `monitors.conf`.
- [`look-feel`](../look-feel/) — collects 11i (per-app rules) + 11j (blur-toggle keybind).
- [`waybar`](../waybar/) / [`launcher`](../launcher/) / [`notifications`](../notifications/) — each
  contributes a `layerrule` blur block keyed to its `namespace` (the chosen tool determines the
  namespace string).
- [`keybinds`](../keybinds/) — owns `hyprland.conf`, which `source =`s `windowrules.conf`.

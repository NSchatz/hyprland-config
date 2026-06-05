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
| `template.md` | The full `windowrules.conf` template — shipped defaults, float-utilities, PiP-pin, idleinhibit-fullscreen, per-app rule iteration, and the per-surface `layerrule` blur blocks (waybar with `blur_popups`/`xray`, launcher mapped by tool name, swaync with **two** blocks, mako/dunst with one, wlogout). Version-branched (cites `_shared/version-matrix.md`). Now includes a "Theming-relevant idioms" section: per-app opacity values, workspace pinning bindings, `idle_inhibit` per class, screen-share-indicator pattern. |
| `gotchas.md` | The 0.53+ `layerrule = blur, <ns>` legacy form is **rejected at parse and fails the reload** (`invalid field blur: missing a value`); modern single-line `layerrule = blur on, match:namespace <ns>` parses (verified against `v0.54.3/src/config/ConfigManager.cpp::handleLayerrule`), but we emit the block form. Plus: `match:` prefix on matchers, snake_case rename (`initial_class`, `float`, `workspace`), verified 0.54.3 block-form fields, `windowrule` block preferred on 0.53+, `windowrulev2` hard-rejected. Plus the **theming cliffs**: fuzzel namespace is `launcher` not `fuzzel` (verified `fuzzel.ini(5)`), swaync exposes TWO namespaces both needing blur (verified `controlCenter.vala` + `notificationWindow.vala`), `decoration:blur:enabled = false` makes every `layerrule blur` a no-op (verified `OpenGL.cpp::preRender`), Matt-FTW's `layer-shell-cover-screen: true` is an alternative to `dim_around`, full `launcher.tool → namespace` map. |
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
  namespace string). **Critical**: `launcher.tool == "fuzzel"` ⇒ namespace `launcher`, NOT
  `fuzzel` (see `gotchas.md`). `notifications.tool == "swaync"` ⇒ **two** namespaces, both
  needing blur.
- [`look-feel`](../look-feel/) — **owns the master blur switch** (`decoration:blur:enabled` via
  the 11-Blur question). If the user picks "Blur off" there, every `layerrule blur` block
  this component emits becomes a no-op (verified upstream — see `gotchas.md`). The visual
  work in waybar/launcher/notifications still depends on it.
- [`utilities`](../utilities/) — if `utilities.session_picker == "wlogout"`, this component
  emits the `layerrule blur-logout_dialog` block.
- [`keybinds`](../keybinds/) — owns `hyprland.conf`, which `source =`s `windowrules.conf`.

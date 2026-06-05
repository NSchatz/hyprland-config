# monitors

Outputs (physical displays), their modes/positions/scales, workspace-to-monitor bindings, smart
gaps, named scratchpad, and dock/undock profiles. Lands in its own `monitors.conf`. App-to-workspace
pinning is **window rules**, not output config — it lives in `../window-rules/` but is **collected**
here because the user is already thinking about workspaces.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 1a–1f (setup, scaling, multi-monitor extras, dock/undock, workspace rules, pin-apps). |
| `schema.md` | The `monitors.*` keys this component owns in `answers.json` and who reads them. |
| `template.md` | The `monitors.conf` template — monitor lines, per-monitor extras, dock/undock `desc:` rules, workspace bindings, smart-gaps. |
| `gotchas.md` | Fractional-scale + `GDK_SCALE` + `xwayland.force_zero_scaling`; detected-vs-placeholder names; kanshi/shikane for hotplug auto-switch. |
| `packages.md` | `kanshi` / `shikane` — only when the user opts into auto-switching profiles. |

## Where this component lands

- **Hyprland config:** `~/.config/hypr/monitors.conf`, sourced from `hyprland.conf` (see
  `../keybinds/template.md` for the top-level sourcing block).
- **env:** when a fractional `scale` is pinned, `../env/` adds `GDK_SCALE,N`; `../look-feel/` (or the
  Hyprland top-level template) needs `xwayland { force_zero_scaling = true }`.
- **Window rules:** the `pin_apps` answers (1f) become `windowrule` lines emitted by
  `../window-rules/` — not in `monitors.conf`. Schema-wise the picks are still owned here.

## Related components

- [`window-rules`](../window-rules/) — consumes `monitors.pin_apps` and emits per-app
  `workspace N silent` rules.
- [`env`](../env/) — `GDK_SCALE` on fractional scaling.
- [`keybinds`](../keybinds/) — workspace-switch binds and the `special:magic` toggle that this
  component's scratchpad rule wires up.
- [`laptop`](../laptop/) — when `monitors.dock_undock == true`, this component names the package
  (`kanshi`/`shikane`); the daemon config lives in laptop's territory if scripted at all.

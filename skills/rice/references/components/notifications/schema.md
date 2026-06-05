# notifications — answers.json slice

Keys this component owns under the top-level `notifications` key.

```json
{
  "notifications": {
    "daemon":   "mako | dunst | swaync | none",
    "position": "top-right | top-center | top-left | bottom-right",
    "timeout":  5,
    "behavior": ["group-by-app", "app-icons", "dnd-bind", "max-visible-5"]
  }
}
```

## Types

- `notifications.daemon` — string. One of `mako`, `dunst`, `swaync`, `none`. Always populated.
  When `none`, every other key in this slice is moot and downstream writers must skip the entire
  component (no `exec-once`, no config files, no waybar notification module).
- `notifications.position` — string. One of `top-right`, `top-center`, `top-left`, `bottom-right`.
  Maps to `anchor` (mako), `origin` + `offset` (dunst), or `positionX`/`positionY` (swaync) per
  `template.md`. Required when `daemon != "none"`.
- `notifications.timeout` — integer (seconds). `0` means "never auto-dismiss" (the user picked
  "Never"); positive values are emitted as the daemon's default timeout. Critical-urgency
  notifications always override this to `0` in the rendered config regardless of this value (see
  `styling.md` — that's an invariant, not a setting). Required when `daemon != "none"`.
- `notifications.behavior` — array of strings, any subset of:
  `group-by-app`, `app-icons`, `dnd-bind`, `max-visible-5`. Empty array is valid (user
  deselected everything). Required when `daemon != "none"`.

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (`notifications`) | Renders mako `config` / dunst `dunstrc` / swaync `config.json`+`style.css` from `template.md`. Branches on `daemon`. |
| `hyprland-component-writer` (`autostart`) | Adds `exec-once = mako` / `dunst` / `swaync` when `daemon != "none"` (dunst's `exec-once` is optional since it's D-Bus activatable, but rice ships it for explicitness). |
| `hyprland-component-writer` (`keybinds`) | Emits a DND-toggle bind when `"dnd-bind" ∈ behavior` — `makoctl mode -t do-not-disturb`, `dunstctl set-paused toggle`, or `swaync-client -d` (NOT `-t`; `-t` toggles the panel). |
| `hyprland-component-writer` (`window-rules`) | When `daemon == "swaync"`, emits a block-form `layerrule` blur for `swaync-control-center` and `swaync-notification-window`. |
| `hyprland-component-writer` (`waybar`) | When `daemon == "swaync"` AND waybar includes the `custom/notification` module, the module wires to `swaync-client -swb`. Skipped otherwise. |
| `theming-engine` | Renders the daemon-specific colors file from `palette.conf` per `_shared/colors-contract.md` (mako/dunst inline INI, swaync `colors.css`). |
| `hyprland-package-installer` | Reads `daemon` against `packages.md` and adds to the install batch. `none` adds nothing. |

## Validation

- `daemon` is required and must be one of the four enum values.
- When `daemon == "none"`, the other three keys may be absent — the component writer skips them.
- When `daemon != "none"`, `position`, `timeout`, and `behavior` are all required (set, even if
  to defaults / empty array).
- `timeout` is an integer ≥ 0. Floats are rejected.
- `behavior` items outside the enum (`group-by-app`, `app-icons`, `dnd-bind`, `max-visible-5`)
  are rejected at validate-time so a typo doesn't silently no-op.

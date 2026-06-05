# input — packages

**None.** Input handling (keyboard, mouse, touchpad, gestures) is built into Hyprland itself;
configuring `~/.config/hypr/input.conf` requires no additional packages.

The installer agent walks `components/<name>/packages.md` for every component when assembling
the global `PKGS` list — this file exists to make the walk explicit (and to keep the pattern
consistent across all 21 components). For `input`, the contribution is empty.

## What's already pulled in elsewhere

- `hyprland` itself — installed by the base session, not this component.
- `libinput` — a transitive dependency of `hyprland` (the touchpad/gesture backend).
- `xkeyboard-config` — also transitive; supplies the layouts referenced by
  `input.kb_layout` and the options referenced by `input.kb_options`.

None of these need to be added by `hyprland-package-installer` on behalf of `input` — they're
already on the system if Hyprland is running.

## Cross-references

- The xkb option tokens recognized in `input.kb_options` are validated against
  `setxkbmap -query` at runtime — see `gotchas.md` and the validator agent's prompt.
- For components that **do** contribute packages, see e.g. `../default-apps/packages.md`.

# look-feel — packages

**None.** Everything this component emits is part of Hyprland core:

- `general` / `decoration` / `animations` / `cursor` / `misc` / `debug` / `group` / `dwindle` /
  `master` / `scrolling` blocks — all built in.
- `scrolling` layout — **core in 0.53+**, not a plugin (see
  [`_shared/version-matrix.md`](../../_shared/version-matrix.md)). Do not add `hyprscrolling` /
  `hyprscroller` to any package list; both are deprecated/superseded.
- Window groups (`group {}`, `groupbar {}`) — core.

## What other components may add on this component's behalf

These are tracked in their own `packages.md` — listed here so the cross-cutting picture is clear:

| Component | Adds when | Package |
|---|---|---|
| `plugins` | user opts in to a plugin **layout** (e.g. `hy3`) | hyprpm-managed; see `components/plugins/packages.md` |
| `keybinds` | `look_feel.blur_toggle = true` | nothing on the package side — the script ships in `assets/scripts/blur-toggle.sh` from the plugin repo itself |

If the user picked the `scrolling` layout, **no extra package** is installed (it's core). If they
picked `hy3` (only reachable through the plugins gate), the install routes through
`components/plugins/`, not here.

## Assembly rule

This component contributes **nothing** to `pkgs+=()`. The installer agent walks every
`components/<x>/packages.md`; this file's purpose is to make that walk a no-op for `look-feel`.

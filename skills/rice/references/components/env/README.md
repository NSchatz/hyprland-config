# env

The environment variables Hyprland exports to every child process via `env.conf` — cursor sizes,
toolkit hints (Qt/GTK), Qt theming bridge, the `XDG_CURRENT_DESKTOP=Hyprland` portal hint, Firefox
Wayland, and the (driver-gated) NVIDIA proprietary block.

This component owns the **env-var slice of interview group 15**. Group 15 is split across two
`AskUserQuestion` calls; the **services + `exec-once` picks** (wallpaper tool, polkit agent,
clipboard history, NetworkManager tray, idle, …) live in [`../autostart/`](../autostart/). The
two components share the `autostart_env` top-level key in `answers.json` — `env` writes
`autostart_env.env`, `autostart` writes `autostart_env.wallpaper_tool` / `.polkit` / `.autostart`.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Call 2 of group 15 — the env-var multi-select sub-question. Cross-link to `../autostart/interview.md` for call 1. |
| `schema.md` | The `autostart_env.env` slice (string array of `"NAME,value"` entries). |
| `template.md` | The full `env.conf` template — cursor, toolkit, Qt theme, session, Firefox-Wayland, the NVIDIA proprietary block. |
| `gotchas.md` | NVIDIA-driver gating, uwsm `~/.config/uwsm/env` override, fractional-scale → `GDK_SCALE`, the 2026 slim NVIDIA set. |
| `packages.md` | None — env-only. |

## Where this component lands

- **Hyprland config:** `~/.config/hypr/env.conf`, sourced from `hyprland.conf`'s top-of-file
  `source = ~/.config/hypr/env.conf` line. Must be sourced first so later programs inherit.
- **uwsm sessions:** mirror cursor / GTK / toolkit vars into `~/.config/uwsm/env` — uwsm
  exports that file **before** the compositor starts, so it overrides `env.conf` for app
  launches. See `gotchas.md`.
- **Live propagation:** `hyprctl setenv VAR value` **and**
  `dbus-update-activation-environment --systemd VAR=value` (explicit pairs) for already-running
  apps and portals.

## Related components

- [`autostart`](../autostart/) — the other half of group 15 (services + `exec-once` lines, the
  portal env-propagation pair).
- [`default-apps`](../default-apps/) — its `browser == "firefox"` answer gates `MOZ_ENABLE_WAYLAND,1`.
- [`monitors`](../monitors/) — fractional-scale picks (`scale != 1.0`) gate the matching
  `GDK_SCALE,N` env var here.
- [`look-feel`](../look-feel/) — when `NVIDIA_PROPRIETARY=1` or `nouveau`, also offers
  `cursor:no_hardware_cursors = true`; coordinated detection but separate file.
- [`companion-daemons`](../companion-daemons/) — hyprcursor's `HYPRCURSOR_THEME,…` /
  `XCURSOR_THEME,…` belong here when a non-default theme is picked there.

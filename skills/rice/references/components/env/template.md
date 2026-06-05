# env — template

Output file: **`~/.config/hypr/env.conf`**, sourced from `hyprland.conf`'s top-of-file
`source = ~/.config/hypr/env.conf` line. Must be sourced before any `exec-once` so the spawned
processes inherit the env.

## env.conf

```ini
# Environment — sourced first so later programs inherit these.
{{#if session}}
env = XDG_CURRENT_DESKTOP,Hyprland     # helps portals pick the Hyprland backend
{{/if}}
{{#if cursor}}
env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24
{{/if}}
{{#if toolkit}}
env = QT_QPA_PLATFORM,wayland;xcb
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = GDK_BACKEND,wayland,x11,*
{{/if}}
{{#if qt_theme}}
env = QT_QPA_PLATFORMTHEME,qt6ct
{{/if}}
{{#if kvantum}}
env = QT_STYLE_OVERRIDE,kvantum
{{/if}}
{{#if firefox_wayland}}
env = MOZ_ENABLE_WAYLAND,1
{{/if}}
{{#if nvidia_proprietary}}
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
env = ELECTRON_OZONE_PLATFORM_HINT,auto
{{/if}}
{{#if fractional_scale}}
env = GDK_SCALE,{{gdk_scale}}
{{/if}}
```

The `{{#if}}` blocks are authoring guidance — emit the chosen lines verbatim, with no template
markers. The order matters: `XDG_CURRENT_DESKTOP` first (portal handshake), then cursor, then
toolkit, then theming, then Firefox, then NVIDIA, with fractional `GDK_SCALE` last.

## Mapping `autostart_env.env` → template gates

The generator reads `autostart_env.env` from `answers.json` and lights each gate by checking for
the corresponding `NAME` (case-sensitive, first segment of each `"NAME,value"` entry):

| Gate | NAME presence triggering it |
|---|---|
| `session` | `XDG_CURRENT_DESKTOP` |
| `cursor` | `XCURSOR_SIZE` **or** `HYPRCURSOR_SIZE` (emit both lines if either present) |
| `toolkit` | `QT_QPA_PLATFORM` **or** `GDK_BACKEND` |
| `qt_theme` | `QT_QPA_PLATFORMTHEME` |
| `kvantum` | `QT_STYLE_OVERRIDE` |
| `firefox_wayland` | `MOZ_ENABLE_WAYLAND` |
| `nvidia_proprietary` | `LIBVA_DRIVER_NAME` **and** `__GLX_VENDOR_LIBRARY_NAME` (both required — see `gotchas.md`) |
| `fractional_scale` | `GDK_SCALE` (also see `gotchas.md` — cross-set from monitor picks, not asked here) |

Any `NAME,value` in `autostart_env.env` that doesn't match a gate is **passed through verbatim**
as an extra `env = NAME,value` line at the end of the file — the env-var question is
multi-select but the schema accepts arbitrary entries so power users can hand-edit
`answers.json`.

## What does NOT belong here

- `exec-once = …` lines (wallpaper tool, polkit agent, clipboard history, `nm-applet`,
  `hypridle`, …). Those are in [`../autostart/template.md`](../autostart/template.md) and write
  to `~/.config/hypr/autostart.conf`.
- The portal env-propagation pair (`dbus-update-activation-environment --systemd …` +
  `systemctl --user import-environment …`). Those are runtime `exec-once` calls, not env vars;
  they're in `../autostart/template.md`.
- `XDG_CURRENT_TYPE` / `XDG_SESSION_TYPE` — set by the login manager / uwsm, never in
  `env.conf`.
- GTK theme variables (`GTK_THEME=`). uwsm's `~/.config/uwsm/env` is the authoritative source on
  uwsm systems; see `gotchas.md`.

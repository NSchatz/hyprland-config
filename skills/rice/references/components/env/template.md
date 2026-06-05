# env — template

Output file: **`~/.config/hypr/env.conf`**, sourced from `hyprland.conf`'s top-of-file
`source = ~/.config/hypr/env.conf` line. Must be sourced before any `exec-once` so the spawned
processes inherit the env.

## env.conf

```ini
# Environment — sourced first so later programs inherit these.
# Syntax: `env = NAME,value` (the parser splits on the FIRST comma only — values may contain
# further commas, e.g. `env = GDK_BACKEND,wayland,x11,*`). On Hyprland 0.55+ the equivalent
# Lua form is `hl.env("NAME", "value")`. Runtime: `hyprctl keyword env NAME,value`.
#
# `envd = NAME,value` (pre-0.55 hyprlang) ALSO pushes the var into the systemd / D-Bus
# activation environment — useful for XDG_* so portals and DBus-activated apps see them
# without an explicit `dbus-update-activation-environment` call. On 0.55+ Lua, `hl.env()`
# does this automatically unless `HYPRLAND_NO_SD_VARS=1` is set; the `envd` distinction
# matters only for legacy `.conf` configs (Matt-FTW's `env.conf` is the canonical example).
{{#if session}}
envd = XDG_CURRENT_DESKTOP,Hyprland    # `envd` (not `env`) — pushes into D-Bus + systemd
                                       # so portal/portal-spawned apps see it (Matt-FTW pattern)
{{/if}}
{{#if cursor}}
env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24
{{#if cursor_theme}}
env = XCURSOR_THEME,{{cursor_theme}}
env = HYPRCURSOR_THEME,{{cursor_theme}}
{{/if}}
{{/if}}
{{#if toolkit}}
env = QT_QPA_PLATFORM,wayland;xcb
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = QT_AUTO_SCREEN_SCALE_FACTOR,1
env = GDK_BACKEND,wayland,x11,*
env = SDL_VIDEODRIVER,wayland
env = CLUTTER_BACKEND,wayland
env = _JAVA_AWT_WM_NONREPARENTING,1    # fixes blank Java AWT windows on tiling WMs
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
{{#if electron_wayland}}
env = ELECTRON_OZONE_PLATFORM_HINT,auto   # safe on any GPU — fixes Electron/CEF flicker
{{/if}}
{{#if nvidia_proprietary}}
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
{{#if have_libva_nvidia_driver}}
env = NVD_BACKEND,direct
{{/if}}
{{/if}}
{{#if fractional_scale}}
env = GDK_SCALE,{{gdk_scale}}
{{/if}}
```

The `{{#if}}` blocks are authoring guidance — emit the chosen lines verbatim, with no template
markers. The order matters: `XDG_CURRENT_DESKTOP` first (portal handshake), then cursor, then
toolkit, then theming, then Firefox, then Electron, then NVIDIA, with fractional `GDK_SCALE`
last. Corpus citations for each block are in `styling.md`.

## Mapping `autostart_env.env` → template gates

The generator reads `autostart_env.env` from `answers.json` and lights each gate by checking for
the corresponding `NAME` (case-sensitive, first segment of each `"NAME,value"` entry):

| Gate | NAME presence triggering it |
|---|---|
| `session` | `XDG_CURRENT_DESKTOP` (emitted as `envd =` so it propagates to the session bus) |
| `cursor` | `XCURSOR_SIZE` **or** `HYPRCURSOR_SIZE` (emit both lines if either present) |
| `cursor_theme` | `XCURSOR_THEME` **or** `HYPRCURSOR_THEME` (sub-gate inside `cursor`; emit both — they must match the `companion-daemons` cursor theme pick) |
| `toolkit` | `QT_QPA_PLATFORM` **or** `GDK_BACKEND` (emits the full toolkit block: GDK + Qt + SDL + Clutter + Java AWT non-reparenting) |
| `qt_theme` | `QT_QPA_PLATFORMTHEME` |
| `kvantum` | `QT_STYLE_OVERRIDE` |
| `firefox_wayland` | `MOZ_ENABLE_WAYLAND` |
| `electron_wayland` | `ELECTRON_OZONE_PLATFORM_HINT` — **NOT NVIDIA-gated**; the Hyprland NVIDIA wiki notes it's safe on any GPU and fixes Electron/CEF flicker (Vesktop / VSCodium / Obsidian) |
| `nvidia_proprietary` | `LIBVA_DRIVER_NAME` **and** `__GLX_VENDOR_LIBRARY_NAME` (both required — see `gotchas.md`) |
| `have_libva_nvidia_driver` | `NVD_BACKEND` (sub-gate inside `nvidia_proprietary`; only emit if `libva-nvidia-driver` is installed — see `gotchas.md`) |
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
- `XDG_SESSION_TYPE` / `XDG_SESSION_DESKTOP` — the
  [Hyprland env-vars wiki](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/)
  lists them as "not a bad idea to set" alongside `XDG_CURRENT_DESKTOP`, but the login manager
  (or uwsm) sets them already in every supported flow we target, so the rice generator omits
  them. (uwsm explicitly notes its users don't need to set XDG vars at all.) If a portal
  malfunctions and you suspect missing XDG env, hand-add them via the validator's "extra env
  passthrough" path.
- GTK theme variables (`GTK_THEME=`). uwsm's `~/.config/uwsm/env` is the authoritative source on
  uwsm systems; see `gotchas.md`.

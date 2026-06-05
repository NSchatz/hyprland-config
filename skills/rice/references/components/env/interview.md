# env — interview

One sub-question, one `AskUserQuestion` call (call 2 of interview group 15). The other call —
services + `exec-once` (wallpaper tool, polkit, clipboard, NM-applet, hypridle, …) — lives in
[`../autostart/interview.md`](../autostart/interview.md) and runs **first**.

The env-var question is multi-select with sensible defaults checked. The user picks the lines;
this component then writes them into `autostart_env.env` and the generator emits the matching
`env.conf` lines. Detection (`scripts/detect-version.sh`) reorders the options and sets the
default checks but **does not skip the question** (see `_interview-protocol.md`).

## Sub-question

**15e. Environment variables** (multiSelect):

| Option | Default | Notes |
|---|---|---|
| Cursor sizes — `XCURSOR_SIZE,24` + `HYPRCURSOR_SIZE,24` | on | Always pair; bare XCURSOR_SIZE leaves XWayland apps unscaled. |
| Toolkit — `QT_QPA_PLATFORM,wayland;xcb` + `GDK_BACKEND,wayland,x11,*` | on | Wayland-first with X11 fallback. |
| Qt theming — `QT_QPA_PLATFORMTHEME,qt6ct` | on if qt6ct present | Add `QT_STYLE_OVERRIDE,kvantum` instead/also if Kvantum is the pick. |
| Session — `XDG_CURRENT_DESKTOP,Hyprland` | on | Required for `xdg-desktop-portal-hyprland`. |
| Firefox Wayland — `MOZ_ENABLE_WAYLAND,1` | on if `default_apps.browser == "firefox"` | Gated on the `default-apps` answer. |
| NVIDIA proprietary set — `LIBVA_DRIVER_NAME,nvidia` + `__GLX_VENDOR_LIBRARY_NAME,nvidia` + `NVD_BACKEND,direct` (with nvidia-vaapi-driver) + `ELECTRON_OZONE_PLATFORM_HINT,auto` | off, on only if `NVIDIA_PROPRIETARY=1` | See `gotchas.md` — gated on the **active driver**, not the card. |

Do **not** ask "is it NVIDIA?" — read `NVIDIA_PROPRIETARY` / `GPU_DRIVER` from
`detect-version.sh` and confirm the result. The 2026 slim NVIDIA set deliberately **omits**
`GBM_BACKEND` and `WLR_NO_HARDWARE_CURSORS` (driver 555+ with explicit sync makes them
unnecessary) — `gotchas.md` covers this.

## Record path

After the user picks, record the chosen lines as an array of `"NAME,value"` strings:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" \
  autostart_env.env --json \
  '["XCURSOR_SIZE,24","HYPRCURSOR_SIZE,24","QT_QPA_PLATFORM,wayland;xcb","GDK_BACKEND,wayland,x11,*","XDG_CURRENT_DESKTOP,Hyprland","MOZ_ENABLE_WAYLAND,1"]'
```

Empty selection records `[]` (env.conf is then generated with only a header comment).

## Cross-references

- The services / `exec-once` half of group 15 → [`../autostart/interview.md`](../autostart/interview.md).
- Schema → `schema.md`.
- The `env.conf` lines emitted → `template.md`.
- Driver gating, uwsm override, fractional-scale tie → `gotchas.md`.
- Firefox-Wayland tie-back → [`../default-apps/gotchas.md`](../default-apps/gotchas.md).

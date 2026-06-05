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
| Firefox Wayland — `MOZ_ENABLE_WAYLAND,1` | on if `default_apps.browser == "firefox"` | No-op on Firefox 121+ (Wayland is the default since Dec 2023). Kept as a documentation marker; see `gotchas.md`. |
| NVIDIA proprietary set — `LIBVA_DRIVER_NAME,nvidia` + `__GLX_VENDOR_LIBRARY_NAME,nvidia` + `NVD_BACKEND,direct` (only with `libva-nvidia-driver` package — Arch name) + `ELECTRON_OZONE_PLATFORM_HINT,auto` | off, on only if `NVIDIA_PROPRIETARY=1` | See `gotchas.md` — gated on the **active driver**, not the card. `ELECTRON_OZONE_PLATFORM_HINT` is safe on any GPU and may also be offered to non-NVIDIA users. |

Do **not** ask "is it NVIDIA?" — read `NVIDIA_PROPRIETARY` / `GPU_DRIVER` from
`detect-version.sh` and confirm the result. The 2026 slim NVIDIA set deliberately **omits**
`GBM_BACKEND`, `WLR_NO_HARDWARE_CURSORS`, and `WLR_DRM_NO_ATOMIC`: driver 555+ with explicit
sync makes the GBM forcing unnecessary, and the `WLR_*` vars are no-ops on modern Hyprland
(which uses aquamarine, not wlroots) — `gotchas.md` covers this.

If the user wants software cursors anyway, that's `cursor:no_hardware_cursors = true` in
`hyprland.conf` (owned by `look-feel`), not an env var.

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

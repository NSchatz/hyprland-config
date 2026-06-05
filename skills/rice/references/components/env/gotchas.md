# env — gotchas

## NVIDIA env is gated on the *active driver*, not the card

`scripts/detect-version.sh` prints both `GPU_DRIVER=…` and `NVIDIA_PROPRIETARY=…`. Emit the
NVIDIA block **only** when `NVIDIA_PROPRIETARY=1` — the proprietary `nvidia` kmod is loaded.

An NVIDIA GPU running the open **`nouveau`** driver (`GPU_DRIVER=nouveau`, no working
`nvidia-smi`) must **not** get them. Specifically:

- `LIBVA_DRIVER_NAME=nvidia` forces libva to load `nvidia_drv_video.so`, which doesn't exist on
  nouveau — VA-API silently dies for every video player (mpv falls back to CPU decode; Firefox
  loses hardware video acceleration).
- `__GLX_VENDOR_LIBRARY_NAME=nvidia` forces GLX through the proprietary vendor library; on
  nouveau, glvnd has no such library and the GLX dispatch breaks (visible as black windows in
  Electron apps, broken OpenGL in older toolkits).

Under mesa (nouveau / AMD / Intel) leave the whole block out — mesa autodetects the right driver.
The only generically-safe line is `env = ELECTRON_OZONE_PLATFORM_HINT,auto` (harmless
everywhere). Re-add the proprietary block only if the user later switches to the `nvidia`
driver.

Do **not** ask "is it NVIDIA?" in the interview — read the driver from `detect-version.sh` and
present the gated default. See `interview.md` for the option wording.

## The 2026 slim NVIDIA set — do not emit `GBM_BACKEND` / `WLR_NO_HARDWARE_CURSORS` / `WLR_DRM_NO_ATOMIC`

The current [Hyprland NVIDIA wiki](https://wiki.hypr.land/Nvidia/) recommends **only**:

```
hl.env("LIBVA_DRIVER_NAME", "nvidia")           # always
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")   # always
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")  # for Electron flickering — safe on any GPU
hl.env("NVD_BACKEND", "direct")                 # ONLY if libva-nvidia-driver is installed
```

Pre-555 NVIDIA guides also told users to set `GBM_BACKEND=nvidia-drm`,
`WLR_NO_HARDWARE_CURSORS=1`, and `WLR_DRM_NO_ATOMIC=1`. **All three are out of the slim set:**

- `GBM_BACKEND=nvidia-drm` — the older Hyprland Configuring/Environment-variables wiki page
  still lists it as a "force GBM backend" knob, but the canonical NVIDIA page does not. Driver
  555+ with explicit sync picks the right GBM backend automatically. Leaving it in is mostly
  harmless but can confuse multi-GPU setups.
- `WLR_NO_HARDWARE_CURSORS=1` — Hyprland is no longer wlroots-based (it uses **aquamarine**),
  so the `WLR_*` env vars do nothing. The aquamarine equivalent (`AQ_NO_ATOMIC=1`) is
  flagged "**NOT** recommended" on the env-vars wiki. If software cursors are needed, use
  `cursor:no_hardware_cursors = true` in `hyprland.conf` — owned by the `look-feel` component,
  not env.
- `WLR_DRM_NO_ATOMIC=1` — same story; replaced by the aquamarine `AQ_NO_ATOMIC` (not
  recommended). Leaving it in does nothing on modern Hyprland.

The validator flags `GBM_BACKEND`, `WLR_NO_HARDWARE_CURSORS`, `WLR_DRM_NO_ATOMIC`, and
`AQ_NO_ATOMIC` as warnings. The 2026 slim set is the four lines above.

## uwsm sessions: `~/.config/uwsm/env` is the authoritative source

If `detect-version.sh` reports `UWSM_SESSION=1`, the session is launched by **uwsm**, which
sources `~/.config/uwsm/env` (theming / xcursor / Nvidia / toolkit vars) and
`~/.config/uwsm/env-hyprland` (Hyprland-only vars: `HYPR*`, `AQ_*`) **before** the compositor
starts. The wiki explicitly tells uwsm users to put env vars *there*, not in `env.conf`:

> uwsm users should avoid placing environment variables in the `hyprland.lua` file. Instead, use
> `~/.config/uwsm/env` for theming, xcursor, Nvidia and toolkit variables, and
> `~/.config/uwsm/env-hyprland` for `HYPR*` and `AQ_*` variables.
> — <https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/>

The values uwsm exports propagate into the systemd user manager and the D-Bus activation
environment via `dbus-update-activation-environment` + `systemctl --user import-environment`
(uwsm does this automatically). Anything spawned through a portal / DBus activation reads from
that exported set — not from `env = …` lines later added in `env.conf`. So on a uwsm system,
**write cursor / GTK / toolkit / `XCURSOR_THEME` / `HYPRCURSOR_THEME` / `GTK_THEME` into
`~/.config/uwsm/env`** (back it up first); the matching `env = …` lines in `env.conf` still
apply to things Hyprland itself spawns, but DBus-activated / portal-spawned apps will see the
uwsm-stage values, and there is no clean "override" — both flows have to agree.

uwsm also sets `XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE`, `XDG_SESSION_DESKTOP` automatically;
users don't need to add those to either file when running under uwsm.

The format differs: `env.conf` uses `env = NAME,value` (comma, one per line); `~/.config/uwsm/env`
is sourced by POSIX `/bin/sh`, so use `export NAME=value` (equals, one per line, **with**
`export` — confirmed by both the Hyprland env-vars wiki and the
[uwsm README §4](https://github.com/Vladimir-csp/uwsm#4-environments-and-shell-profile)).

### Live-propagate to the running session

For env changes to reach already-running apps and portals **without a re-login**:

```bash
hyprctl keyword env NAME,value
dbus-update-activation-environment --systemd VAR=value
systemctl --user import-environment VAR
```

`hyprctl setenv VAR value` was the pre-0.55 spelling; modern Hyprland (0.55+, after the Lua
config rewrite) only exposes the runtime form as `hyprctl keyword env NAME,value` (driving the
same `env` config keyword the `.conf` parser uses; equivalent to `hl.env(name, value)` in Lua).
Hyprland's own `env = NAME,value` keyword does the `setenv` for the compositor; the second and
third commands above push it into the DBus activation environment and the systemd user manager
so portals and user services spawned afterwards see it. (Equivalent: `env = NAME,value` in
hyprlang **with the dbus flag**, or `hl.env("NAME", "value", true)` in Lua — both call the same
dbus-update + systemctl-import shell command internally.)

Pass **explicit `VAR=value` pairs** to `dbus-update-activation-environment`. Passing bare names
re-reads the *calling shell's* stale values — usually the opposite of what you want. The
`--systemd` flag also pushes the value into `systemctl --user`'s environment so user-services
spawned after the call see it.

## Fractional scale ties: pin `GDK_SCALE,N` here

When the `monitors` component pins a fractional `scale` (e.g. `1.5` or `1.25`), GTK apps that
don't speak the Wayland fractional-scale protocol fall back to integer scaling driven by
`GDK_SCALE`. The cleanest match is to set `GDK_SCALE,N` where `N = ceil(scale)` (so `1.5 → 2`,
`1.25 → 2`); the toolkit then renders at integer scale and Hyprland downscales, which is sharper
than the unscaled fallback.

The monitor component's writer **cross-sets** this into `autostart_env.env` after the user
finishes the monitor pass — it's not a separate interview question. The `template.md` gate
table calls out `GDK_SCALE` as the trigger.

Don't set `GDK_SCALE` when every monitor is at integer scale (`1.0`, `2.0`) — it overrides the
per-monitor scale Hyprland sends and breaks mixed-DPI setups.

## `NVD_BACKEND,direct` only with `libva-nvidia-driver`

`NVD_BACKEND=direct` configures the **`libva-nvidia-driver`** (Arch package name; upstream
project is `elFarto/nvidia-vaapi-driver` on GitHub — the libva → CUDA/NVDEC bridge) to use the
direct-NVDEC backend. The Hyprland NVIDIA wiki gates this env var on the package being
installed; see
<https://github.com/elFarto/nvidia-vaapi-driver#upstream-regressions>.

The line is harmless if the driver isn't installed (libva ignores the env when the bridge isn't
loaded) but it's misleading in `env.conf`. Only emit it when the package is queued in the
install batch — `packages.md` of the related components (or `detect-version.sh`'s
`HAVE_NVIDIA_VAAPI=1`) is the source.

## `MOZ_ENABLE_WAYLAND=1` is now a no-op on Firefox 121+

Firefox shipped Wayland-by-default in **121.0** (December 2023). The variable is still respected
(setting it to `0` forces X11/XWayland) but `=1` is the default and a no-op on any current
Firefox. Keep the line for older Firefox builds and as a clear opt-in marker; do not present it
in the interview as "required for Wayland Firefox" — phrase it as "force Wayland (no-op on
current Firefox; useful as documentation)".

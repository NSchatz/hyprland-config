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

## The 2026 slim NVIDIA set — do not emit `GBM_BACKEND` / `WLR_NO_HARDWARE_CURSORS`

Pre-555 NVIDIA guides told users to set `GBM_BACKEND=nvidia-drm` and
`WLR_NO_HARDWARE_CURSORS=1`. Both are **out of the recommended set** as of driver 555+ with
explicit sync — the driver now picks the right GBM backend automatically, and hardware cursors
work without the killswitch. Leaving them in produces a working but suboptimal session (no
hardware cursor on multi-monitor; potential cursor flicker on driver upgrades).

The validator flags either of these names as a warning. The slim set is: `LIBVA_DRIVER_NAME`,
`__GLX_VENDOR_LIBRARY_NAME`, `NVD_BACKEND` (only if `nvidia-vaapi-driver` is installed), and
`ELECTRON_OZONE_PLATFORM_HINT`.

## uwsm sessions: `~/.config/uwsm/env` overrides `env.conf` for app launches

If `detect-version.sh` reports `UWSM_SESSION=1`, the session is launched by **uwsm**, which
exports `~/.config/uwsm/env` (plus the optional `env-hyprland`) **before** the compositor
starts. Those values then **override** hypr `env.conf` for app launches — Hyprland inherits its
parent env (uwsm's), and `env = …` lines in `env.conf` are applied *on top*, but anything spawned
through a portal / DBus activation re-reads the uwsm-stage env.

The practical consequence: on a uwsm system, write cursor / GTK / toolkit / `XCURSOR_THEME` /
`HYPRCURSOR_THEME` / `GTK_THEME=` into `~/.config/uwsm/env` too (back it up first), not just
`env.conf`. Otherwise GTK apps and the cursor keep the previous theme even after a Hyprland
reload, because uwsm's already-exported `GTK_THEME=` wins.

The format differs: `env.conf` uses `env = NAME,value` (comma); `~/.config/uwsm/env` uses
shell-style `NAME=value` (equals, one per line, no `export`).

### Live-propagate to the running session

For env changes to reach already-running apps and portals **without a re-login**:

```bash
hyprctl setenv VAR value
dbus-update-activation-environment --systemd VAR=value
```

Pass **explicit `VAR=value` pairs**. Passing bare names (`dbus-update-activation-environment --systemd VAR`)
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

## `NVD_BACKEND,direct` only with `nvidia-vaapi-driver`

`NVD_BACKEND=direct` configures the `nvidia-vaapi-driver` (the libva → CUDA bridge) to use the
direct-NVDEC backend. The line is harmless if the driver isn't installed (libva ignores the env
when the bridge isn't loaded) but it's misleading in `env.conf`. Only emit it when the package
is queued in the install batch — `packages.md` of the related components (or
`detect-version.sh`'s `HAVE_NVIDIA_VAAPI=1`) is the source.

# autostart

The `exec-once` services Hyprland launches at session start — wallpaper daemon, polkit agent,
clipboard watchers, idle daemon, trays, OSD, and the portal-env propagation pair. This component
owns `autostart.conf` and the **services half** of interview group 15. The other half (the
`env = …` toolkit / cursor / NVIDIA lines that land in `env.conf`) lives in [`../env/`](../env/).

The bar daemon, notification daemon, and lock screen are **not chosen here** — those picks come
from their own components (`waybar`, `notifications`, `lock-screen`) and this component just wires
their startup line into `autostart.conf` based on the values already in `answers.json`.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 15a–15d (wallpaper tool, polkit agent, also-autostart multi-select, screen-share portals). |
| `schema.md` | The `autostart_env.{wallpaper_tool, polkit, dbus_propagation, autostart}` slice of `answers.json`. |
| `template.md` | The full `autostart.conf` template — every `exec-once` line, the conditional gates, the two corpus-attested ordering schools, and the engine wallpaper-restore hook. |
| `gotchas.md` | `hyprctl reload` does NOT re-run `exec-once`; one polkit + one wallpaper daemon max; `SWWW_DAEMON_BIN` detection; notification-owner conflicts; portal env propagation; `--all` vs explicit-var propagation debate; `resetxdgportal.sh` kill+restart pattern; wallpaper restore on login; systemd-user-unit vs raw `exec-once` for `hyprpolkitagent` / `hypridle`; uwsm `uwsm app --` wrapping. |
| `packages.md` | Wallpaper / polkit / tray / clipboard / idle / OSD package map. Bar and notification daemon packages live in their own components. |

## Where this component lands

- **Hyprland config:** `~/.config/hypr/autostart.conf`, `source =`d from `hyprland.conf` (the
  hyprland component owns the `source` line).
- **No keybinds and no env emissions from this component.** The `env = …` set is the env
  component's workload; this component is purely `exec-once` lines.
- **One detection input:** `SWWW_DAEMON_BIN` from `detect-version.sh` — gates which swww binary
  the wallpaper `exec-once` line invokes (see `gotchas.md`).

## Related components

- [`env`](../env/) — the other half of interview group 15: the `env = …` cursor / toolkit / Qt /
  portal / NVIDIA lines that land in `env.conf`.
- [`waybar`](../waybar/) — the bar daemon. Its `exec-once = waybar` is emitted by this component
  when `bar.strategy` is `waybar` or `waybar+widgets`.
- [`notifications`](../notifications/) — the notification daemon. Its `exec-once` line (`mako` /
  `dunst` / `swaync`) is emitted by this component when `notifications.daemon` is non-null.
- [`companion-daemons`](../companion-daemons/) — generates the *config files* for `hypridle`,
  `hyprpaper`, etc.; this component decides whether to **start** them at login.
- [`lock-screen`](../lock-screen/) — `hyprlock` is invoked by `hypridle`, not from
  `autostart.conf`, so the lock-screen pick does not feed `autostart.conf` directly.
- [`utilities`](../utilities/) — the **on-demand** scripts (screenshot, power menu) live there;
  this component only handles the **always-on** background services.
- [`../../theming/wallpaper.md`](../../theming/wallpaper.md) and
  [`../../theming/engine.md`](../../theming/engine.md) — the wallpaper-restore script's *content*
  (matugen post-hook / wallust template / wallbash regenerator). This component only emits the
  `exec-once` that runs it; the engine writes the script body. See `template.md` "Theme-restore on
  login".
- [`../env/`](../env/) — `XDG_CURRENT_DESKTOP=Hyprland` is set there; this component just
  propagates whatever value is already in the compositor env to the systemd-user manager and to
  dbus. Do **not** re-assign `XDG_CURRENT_DESKTOP` in the propagation line — that fights with uwsm
  sessions that set `Hyprland:wlroots`.

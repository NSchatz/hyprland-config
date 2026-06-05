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
| `schema.md` | The `autostart_env.{wallpaper_tool, polkit, autostart}` slice of `answers.json`. |
| `template.md` | The full `autostart.conf` template — every `exec-once` line and the conditional gates. |
| `gotchas.md` | `hyprctl reload` does NOT re-run `exec-once`; one polkit + one wallpaper daemon max; `SWWW_DAEMON_BIN` detection; notification-owner conflicts; portal env propagation. |
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

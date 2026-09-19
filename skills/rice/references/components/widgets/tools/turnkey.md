# turnkey - widgets

Everything this plugin knows about authoring **turnkey** for the `widgets` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template
- Styling
- Validation
- Reload

---

## Template


The project's own installer lays out its config (typically `~/.config/quickshell/<project>/`).
Once installed, autostart is the project's command (`caelestia shell -d`, `dms run`, …) and
theming is matugen-driven per above.

The rice skill **does not** hand-theme a turnkey shell. It does:

- Add the package to the install batch (see `packages.md`).
- Add `matugen` to the install batch.
- Write a matugen config that re-runs on every `rice apply` against the current wallpaper.
- Warn the user that the plugin's per-app theming yields to the shell's own (the shell's bar,
  notifications, launcher, etc., use *its* palette, not the engine's).

---

## Styling


For users who want widgets without programming. These are configured through a GUI or JSON, not a stylesheet — so "styling" means picking a theme, not writing CSS.

**HyprPanel** (`Jas-SinghFSU/HyprPanel`) — an **AGSv2/Astal**-based, batteries-included bar + widget suite configured almost entirely through a **GUI settings dialog**: the closest thing to "install a panel, click options, done." Ships a configurable bar (workspaces, clock, tray, CPU/RAM/GPU/disk, battery + power-profiles, network, bluetooth, volume, media, updates, notifications), a **dashboard** (resource monitors, power menu, shortcuts, snapshot/record, color picker), **quick-settings**, **calendar**, **media**, **notifications**, and bluetooth/network/audio dropdown menus.
- **Install/run:** needs AGSv2 (Aylur's GTK Shell) first; on Arch `yay -S ags-hyprpanel-git`, then `exec-once = hyprpanel`. Config in `~/.config/hyprpanel/` as JSON.
- **Theming (its strongest feature):** a dedicated **Theming** section in the settings dialog. Themes **import/export as `.json` files** (`Theming > General Settings > Import/Export`) — how community theme catalogs are shared. **Matugen integration** (`Theming > Matugen Settings`, needs the `matugen` binary) recolors the panel to the wallpaper. Underlying styling is SCSS, but end users never touch it — the GUI writes the tokens.
- **⚠️ Archived 2026-04** (read-only). Maintainer points to a Rust successor (**Wayle**, TOML config, Pywal/Matugen/Wallust). Still installs and runs; don't expect fixes. For the rice engine, drive it via **matugen** (point matugen at the wallpaper, enable Matugen in HyprPanel's settings) rather than hand-editing its JSON.

**nwg-shell** (`nwg-piotr`) — a coordinated, **still-maintained** GTK/Python suite for sway *and* Hyprland: **nwg-panel** (the bar — Controls with brightness/volume sliders, clock+calendar, executors, taskbars, workspaces, menu-start, openweather, playerctl, tray), **nwg-drawer** (app grid), **nwg-dock**, **nwg-bar** (power menu). Configured via the `nwg-shell-config` / `nwg-panel-config` GUIs (JSON underneath); themed with a per-panel **`style.css`** (standard GTK CSS — Waybar knowledge transfers directly) plus preset styles. The maintained alternative to HyprPanel for a GUI-configured suite.

**Lower-effort still:** **Waybar `custom/*` modules** + `group/drawer` give you weather, notification bells, todo/pomodoro, and hover-out sliders without a new framework — see [`waybar.md`](../../waybar/styling.md). And **swaync** is the standard drop-in **notification-center widget** for any bar (GTK CSS `~/.config/swaync/style.css`; pair via a `custom/notification` toggle).

---

## Validation


Validation lands on the project's installer (`caelestia install`, `dms init`, the end-4 install
script, etc.). The rice skill verifies:

- The shell's autostart command (`caelestia shell -d`, `dms run`, …) is on `$PATH`.
- The shell's config directory (`~/.config/quickshell/<name>/`) exists.
- `matugen` is installed (every turnkey shell uses it).

Past that, the shell's own startup logs are the source of truth — the rice skill points the user
at them on failure.

---

## Reload


Each project's installer provides its own reload mechanism, typically a CLI wrapping
`pkill -USR1` or a `qs ipc`. The rice skill doesn't hand-wire these — instead it re-runs
**matugen against the wallpaper** (every turnkey shell consumes matugen output) and lets the
shell's own watcher repaint:

| Shell | Matugen target | Notes |
|---|---|---|
| `end-4` | `~/.local/state/quickshell/.../generated/colors.json` (QML `FileView` watches) | Instant repaint via the singleton. |
| `caelestia` | `~/.config/caelestia/shell.json` (matugen template ships in the install script) | `caelestia shell -d` is the daemon; it watches `shell.json`. |
| `noctalia` | per-monitor `colors.json` (matugen) | Plugin-driven reload. |
| `dankmaterial` | `~/.config/dms/colors.json` (matugen) | Hot-reloads on file change. |

If repaint doesn't happen, the per-project CLI is the escape hatch: `caelestia restart`,
`dms reload`, etc. The rice skill logs the matugen run and leaves these to the user.


# autostart — template

Lands at `~/.config/hypr/autostart.conf`, `source =`d from `hyprland.conf`. Every line is an
`exec-once = …` directive; this file is not read by any daemon other than Hyprland itself.

## Full `autostart.conf` template

```ini
# Autostart — exec-once runs once at session start.
# Re-running `hyprctl reload` does NOT re-execute these lines (see gotchas).

# --- Polkit agent (exactly one, or none) ---
{{#if polkit_hypr}}exec-once = systemctl --user start hyprpolkitagent{{/if}}
{{#if polkit_gnome}}exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1{{/if}}
{{#if polkit_kde}}exec-once = /usr/lib/polkit-kde-authentication-agent-1{{/if}}

# --- Wallpaper daemon (exactly one, or none) ---
# See _shared/binaries.md for the binary registry. `swww_daemon_bin` is `swww-daemon` (upstream,
# archived) or `awww-daemon` (the maintained fork — declares `provides=swww`). If detection ran
# before the install (the normal Mode A flow) neither variant is on disk yet, so the writer emits
# the binary-agnostic launcher instead of a hard-coded name; the launcher picks whichever variant
# exists at first run.
{{#if hyprpaper}}exec-once = hyprpaper{{/if}}
{{#if swww_known_bin}}exec-once = {{swww_daemon_bin}}{{/if}}
{{#if swww_agnostic}}exec-once = sh -c 'command -v swww-daemon >/dev/null && exec swww-daemon || exec awww-daemon'{{/if}}
{{#if has_restore_script}}exec-once = {{restore_script_path}}{{/if}}

# --- Portal env propagation (always emitted — the "screen-share is black" fix) ---
exec-once = systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
{{#if dbus_all}}exec-once = dbus-update-activation-environment --systemd --all{{/if}}

# --- Bar (read from bar.strategy in answers.json — owned by ../waybar/) ---
{{#if bar_waybar}}exec-once = waybar{{/if}}

# --- Notification daemon (read from notifications.daemon — owned by ../notifications/) ---
{{#if notif_mako}}exec-once = mako{{/if}}
{{#if notif_dunst}}exec-once = dunst{{/if}}
{{#if notif_swaync}}exec-once = swaync{{/if}}

# --- Idle, blue light, OSD ---
{{#if hypridle}}exec-once = hypridle{{/if}}
{{#if hyprsunset}}exec-once = hyprsunset -t 4000{{/if}}
{{#if swayosd}}exec-once = swayosd-server{{/if}}

# --- Trays + clipboard watchers ---
{{#if nm_applet}}exec-once = nm-applet --indicator{{/if}}
{{#if blueman}}exec-once = blueman-applet{{/if}}
{{#if cliphist_text}}exec-once = wl-paste --type text --watch cliphist store{{/if}}
{{#if cliphist_image}}exec-once = wl-paste --type image --watch cliphist store{{/if}}
```

Emit only the chosen branches — drop the template markers and any branch that's not selected.
**Do not leave empty `exec-once =` lines.**

## Variable resolution

| Template var | Source |
|---|---|
| `polkit_hypr` / `polkit_gnome` / `polkit_kde` | `autostart_env.polkit == "hyprpolkitagent"` / `"polkit-gnome"` / `"polkit-kde"`. |
| `hyprpaper` | `autostart_env.wallpaper_tool == "hyprpaper"`. |
| `swww_known_bin` | `autostart_env.wallpaper_tool == "swww"` AND detection has a concrete `SWWW_DAEMON_BIN` (one of the two variants is on disk at generate time). |
| `swww_agnostic` | `autostart_env.wallpaper_tool == "swww"` AND detection reports `MISSING_swww=1` (neither variant installed yet — the normal Mode A flow before the install batch runs). Emits the `sh -c …` agnostic launcher so first boot picks whichever variant the install batch landed. See `_shared/binaries.md`. |
| `swww_daemon_bin` | `SWWW_DAEMON_BIN` from `detect-version.sh` — literally `swww-daemon` or `awww-daemon`. **Never hard-code `swww-daemon`** (see `gotchas.md` and `_shared/binaries.md`). Used only when `swww_known_bin` is true. |
| `bar_waybar` | `bar.strategy` is `"waybar"` or `"waybar+widgets"`. |
| `notif_mako` / `notif_dunst` / `notif_swaync` | `notifications.daemon` matches that string. If a widget shell owns notifications (see `gotchas.md`), set the daemon to `null` upstream — none of these branches fire. |
| `hypridle` / `hyprsunset` | Entry present in `autostart_env.autostart`. |
| `swayosd` | `utilities.osd_route == "swayosd"`. The swayosd-server daemon must be running before the first volume/brightness keybind fires; emit this exec-once unconditionally for that route (no separate autostart toggle — the route decision is what gates it). |
| `nm_applet` / `blueman` / `cliphist_text` / `cliphist_image` | Entry present in `autostart_env.autostart`. |
| `dbus_all` | `true` when `autostart_env.dbus_propagation == "all"` (the HyDE/dusky-style maximum-compat broadcast). Off by default — the explicit-var pair above is enough for screen-share; only flip on when the user reports portal-activated apps missing the rice's `PATH` (see `gotchas.md` for the `--all` vs explicit-var debate). |
| `has_restore_script` / `restore_script_path` | `true` and the generated path when `theming.engine` is `matugen` / `wallust` / `wallbash` and the engine writes a wallpaper/theme-restore hook. Off when `theming.engine == "none"` or the engine has no restore step. See "Theme-restore on login" below. The line is emitted *after* the wallpaper-daemon line so the daemon is alive when the script calls `swww img <path>`. |

## Ordering rules

1. Polkit first — auth prompts depend on the agent being live before any other startup script
   that might call `pkexec`. Matches HyDE (`Configs/.config/hypr/hyprland.conf`), JaKooLit
   (`config/hypr/configs/Startup_Apps.conf` — polkit just after env propagation), caelestia
   (`hypr/hyprland/execs.conf`).
2. Wallpaper second — first paint before the bar layers on. (HyDE places wallpaper *after* the
   bar; both work — first-paint-then-bar reads as more polished, bar-first reads as faster, but
   the difference is sub-second.)
3. Portal env propagation third — must run before any client that opens a Pipewire stream.
   Emit `systemctl --user import-environment` first, then `dbus-update-activation-environment
   --systemd` second, so the dbus update observes the already-imported systemd user environment.
   Cited corpus pattern: linuxmobile/kenos (`.config/hypr/startup.conf`), ML4W
   (`dotfiles/.config/hypr/conf/autostart.lua`). HyDE emits them in the opposite order and also
   works — both directions converge, but the documented order avoids a propagation race.
4. Bar / notifications fourth.
5. Idle / sunset / OSD next.
6. Trays + clipboard last — they're fast and order-independent.

The template above is already in this order; preserve it when emitting.

The corpus shows two stable orderings (see `gotchas.md` "exec-once ordering across the corpus")
— the recipe follows School A (auth/portal first). If the user enables an engine wallpaper-restore
script, place its `exec-once` line **after** the wallpaper daemon's line in the wallpaper block;
that's the only ordering constraint the engine adds.

## Theme-restore on login (engine integration)

When the rice's theming engine (matugen / wallust / wallbash) generates per-component color files
from the current wallpaper, **the last theme must be re-applied on every login** — otherwise the
user logs in to a stale palette (or, with `swww-daemon`, to no wallpaper at all because the
animated daemon starts empty). The corpus pattern:

1. On each `rice apply` / wallpaper-pick, write a generated restore script to
   `~/.config/hypr/scripts/restore-theme.sh` (or equivalent) — see `theming/wallpaper.md` for the
   engine-side recipe.
2. Add a single `exec-once = ~/.config/hypr/scripts/restore-theme.sh` line to `autostart.conf`,
   placed **after** the wallpaper daemon's `exec-once` line so the daemon is alive when the
   restore script calls `swww img <path>`.

The autostart template doesn't generate the restore script (that's the engine's job, owned by
`theming/`); it just emits the `exec-once` line that runs it. The conditional gate is:

```ini
{{#if has_restore_script}}exec-once = {{restore_script_path}}{{/if}}
```

Set `has_restore_script = true` and `restore_script_path` to the generated path whenever
`theming.engine` in `answers.json` is `matugen` / `wallust` / `wallbash` and the engine writes a
restore hook. For the `none` / hand-rolled cases, leave the gate off — there's nothing to restore.

Cited patterns: end-4 `dots/.config/hypr/custom/scripts/__restore_video_wallpaper.sh`
(generated on every wallpaper switch by `switchwall.sh`); ML4W
`dotfiles/.config/ml4w/scripts/ml4w-autostart` (reads `current_wallpaper` cache and re-applies);
HyDE `Configs/.config/hypr/hyprland.conf` `exec-once = $scrPath/swwwallpaper.sh` (single script
that re-runs the wallbash regen + `swww img`).

## Cross-references to other components' templates

- `hyprland.conf` `source =` line for this file → `../keybinds/template.md` (keybinds owns the
  `hyprland.conf` index file in this carve).
- The `env.conf` half of group 15 — cursor/toolkit/Qt/portal env lines → `../env/template.md`.
- Companion-tool *configuration* (e.g. `hypridle.conf`, `hyprpaper.conf`) → `../companion-daemons/`.
- The wallpaper-restore script's content (matugen post-hook / wallust template / wallbash
  regenerator) → `../../theming/wallpaper.md` and `../../theming/engine.md`. This component only
  schedules the `exec-once` call; the engine writes the script body.

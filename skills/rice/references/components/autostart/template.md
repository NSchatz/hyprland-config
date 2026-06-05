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
{{#if hyprpaper}}exec-once = hyprpaper{{/if}}
{{#if swww}}exec-once = {{swww_daemon_bin}}{{/if}}

# --- Portal env propagation (always emitted — the "screen-share is black" fix) ---
exec-once = systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

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
| `hyprpaper` / `swww` | `autostart_env.wallpaper_tool == "hyprpaper"` / `"swww"`. |
| `swww_daemon_bin` | `SWWW_DAEMON_BIN` from `detect-version.sh` — literally `swww-daemon` or `awww-daemon`. **Never hard-code `swww-daemon`** (see `gotchas.md`). |
| `bar_waybar` | `bar.strategy` is `"waybar"` or `"waybar+widgets"`. |
| `notif_mako` / `notif_dunst` / `notif_swaync` | `notifications.daemon` matches that string. If a widget shell owns notifications (see `gotchas.md`), set the daemon to `null` upstream — none of these branches fire. |
| `hypridle` / `hyprsunset` / `swayosd` | Entry present in `autostart_env.autostart`. |
| `nm_applet` / `blueman` / `cliphist_text` / `cliphist_image` | Entry present in `autostart_env.autostart`. |

## Ordering rules

1. Polkit first — auth prompts depend on the agent being live before any other startup script
   that might call `pkexec`.
2. Wallpaper second — first paint before the bar layers on.
3. Portal env propagation third — must run before any client that opens a Pipewire stream.
   Emit `systemctl --user import-environment` first, then `dbus-update-activation-environment
   --systemd` second, so the dbus update observes the already-imported systemd user environment.
4. Bar / notifications fourth.
5. Idle / sunset / OSD next.
6. Trays + clipboard last — they're fast and order-independent.

The template above is already in this order; preserve it when emitting.

## Cross-references to other components' templates

- `hyprland.conf` `source =` line for this file → `../keybinds/template.md` (keybinds owns the
  `hyprland.conf` index file in this carve).
- The `env.conf` half of group 15 — cursor/toolkit/Qt/portal env lines → `../env/template.md`.
- Companion-tool *configuration* (e.g. `hypridle.conf`, `hyprpaper.conf`) → `../companion-daemons/`.

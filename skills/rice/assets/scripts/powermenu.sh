#!/usr/bin/env bash
# Rofi power menu (lock / logout / suspend / reboot / shutdown).
# Plain text labels for portability — add Nerd Font / Material Design glyphs to the
# entries below if your bar font has them (avoids tofu boxes on fonts that don't).
# Deps: rofi; hyprlock (lock); systemd (suspend/reboot/poweroff).
set -euo pipefail

chosen="$(printf 'Lock\nLogout\nSuspend\nReboot\nShutdown' \
    | rofi -dmenu -i -p "Power" -theme-str 'window {width: 14em;} listview {lines: 5;}')"

case "$chosen" in
    Lock)     command -v hyprlock >/dev/null 2>&1 && hyprlock || loginctl lock-session ;;
    Logout)   hyprctl dispatch exit ;;
    Suspend)  systemctl suspend ;;
    Reboot)   systemctl reboot ;;
    Shutdown) systemctl poweroff ;;
esac

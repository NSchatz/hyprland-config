#!/usr/bin/env bash
# Set the desktop wallpaper via the available backend: swww > hyprpaper > swaybg.
# Usage: set-wallpaper.sh <image> [--dry-run]
# Persists hyprpaper.conf when hyprpaper is the backend. Does not touch the palette
# (the `rice wallpaper` flow records the wallpaper path in palette.conf).
set -uo pipefail

img="${1:-}"
[ -n "$img" ] || { echo "ERROR: usage: set-wallpaper.sh <image> [--dry-run]" >&2; exit 2; }
dry=0; [ "${2:-}" = "--dry-run" ] && dry=1
case "$img" in "~"*) img="${HOME}${img#\~}";; esac
[ -f "$img" ] || { echo "ERROR: no such image: $img" >&2; exit 2; }

run() { if [ "$dry" -eq 1 ]; then echo "DRY: $*"; else eval "$*"; fi; }

if command -v swww >/dev/null 2>&1; then
    if [ "$dry" -eq 0 ]; then swww query >/dev/null 2>&1 || { setsid swww-daemon >/dev/null 2>&1 & sleep 1; }; fi
    run "swww img '$img' --transition-type any --transition-fps 60"
    echo "SET_WALLPAPER=ok (swww)"
elif command -v hyprpaper >/dev/null 2>&1; then
    if [ "$dry" -eq 0 ]; then
        hyprctl hyprpaper preload "$img" >/dev/null 2>&1 || true
        hyprctl hyprpaper wallpaper ",$img" >/dev/null 2>&1 || true
        printf 'preload = %s\nwallpaper = , %s\nsplash = false\n' "$img" "$img" > "$HOME/.config/hypr/hyprpaper.conf"
    else
        echo "DRY: hyprctl hyprpaper preload '$img' && wallpaper ',$img' && write hyprpaper.conf"
    fi
    echo "SET_WALLPAPER=ok (hyprpaper)"
elif command -v swaybg >/dev/null 2>&1; then
    run "pkill -x swaybg 2>/dev/null; setsid swaybg -i '$img' -m fill >/dev/null 2>&1 &"
    echo "SET_WALLPAPER=ok (swaybg)"
else
    echo "SET_WALLPAPER=none (install swww or hyprpaper)" >&2
    exit 3
fi

#!/usr/bin/env bash
# Reload running apps after theme files have been written, so changes show without a logout.
# Only reloads apps that are actually running; everything else is a skip. Changes nothing on
# disk — assumes the theme files were already written + backed up by the skill.
#
# Usage: apply-theme.sh [--cursor <Theme> <size>]
#   --cursor  also apply a cursor theme live via `hyprctl setcursor`.
#
# Prints RELOAD_<app>=ok|skipped lines.
set -uo pipefail

cursor_theme=""
cursor_size="24"
if [ "${1:-}" = "--cursor" ]; then
    cursor_theme="${2:-}"
    cursor_size="${3:-24}"
fi

running() { pgrep -x "$1" >/dev/null 2>&1; }

# Hyprland
if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 && echo "RELOAD_hyprland=ok" || echo "RELOAD_hyprland=failed"
else
    echo "RELOAD_hyprland=skipped (not running)"
fi

# Waybar — SIGUSR2 reloads style + config
if running waybar; then
    killall -SIGUSR2 waybar 2>/dev/null && echo "RELOAD_waybar=ok" || echo "RELOAD_waybar=failed"
else
    echo "RELOAD_waybar=skipped (not running)"
fi

# mako
if running mako && command -v makoctl >/dev/null 2>&1; then
    makoctl reload 2>/dev/null && echo "RELOAD_mako=ok" || echo "RELOAD_mako=failed"
else
    echo "RELOAD_mako=skipped (not running)"
fi

# dunst — prefer dunstctl reload, else restart
if running dunst; then
    if command -v dunstctl >/dev/null 2>&1 && dunstctl reload 2>/dev/null; then
        echo "RELOAD_dunst=ok"
    else
        killall dunst 2>/dev/null; setsid dunst >/dev/null 2>&1 & echo "RELOAD_dunst=restarted"
    fi
else
    echo "RELOAD_dunst=skipped (not running)"
fi

# kitty — SIGUSR1 reloads config (incl. included colors)
if running kitty; then
    pkill -SIGUSR1 -x kitty 2>/dev/null && echo "RELOAD_kitty=ok" || echo "RELOAD_kitty=failed"
else
    echo "RELOAD_kitty=skipped (not running)"
fi

# Cursor (live), optional
if [ -n "$cursor_theme" ] && command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    hyprctl setcursor "$cursor_theme" "$cursor_size" >/dev/null 2>&1 \
        && echo "RELOAD_cursor=ok ($cursor_theme $cursor_size)" || echo "RELOAD_cursor=failed"
fi

echo "APPLY_THEME=done"

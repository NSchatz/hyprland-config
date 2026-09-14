#!/usr/bin/env bash
# Reload running apps after theme files have been written, so changes show without a logout.
# Only reloads apps that are actually running; everything else is a skip. Changes nothing on
# disk - assumes the theme files were already written + backed up by the skill.
#
# Usage: apply-theme.sh [--cursor <Theme> <size>]
#   --cursor  also apply a cursor theme live via `hyprctl setcursor`.
#
# Example:
#   apply-theme.sh --cursor Bibata-Modern-Ice 24
#
# Options: -h, --help, help, --cursor
# Subcommands: none
#
# Prints RELOAD_<app>=ok|skipped lines.
#
# Exit codes:
#   0  ok: every running app this knows how to reload was asked to. An app that is not running
#      is a skip and an app that refused the reload is reported as RELOAD_<app>=failed; neither
#      is a failure of this command
#   2  usage: an option this script does not have
set -uo pipefail

cursor_theme=""
cursor_size="24"
case "${1:-}" in   # [cli-parser]
    -h|--help|help)
        sed -n '2,${/^#/!q;s/^#\{1,2\} \{0,1\}//p}' "$0"
        exit 0 ;;   # rc=ok
    --cursor)
        cursor_theme="${2:-}"
        cursor_size="${3:-24}" ;;
    -*)
        echo "ERROR: unknown option '$1' (usage: apply-theme.sh [--cursor <Theme> <size>])" >&2
        exit 2 ;;   # rc=usage
esac

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
exit 0   # rc=ok

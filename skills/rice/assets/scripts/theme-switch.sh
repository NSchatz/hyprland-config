#!/usr/bin/env bash
# Searchable theme switcher — lists the saved rice profiles in a menu and applies the pick.
# Leans entirely on the rice engine: `rice themes` to list, `rice theme <name>` to apply
# (so the whole desktop re-themes coherently). No hardcoded theme names.
# Deps: the rice CLI (<config base>/hypr-rice/rice); one of rofi/wofi/fuzzel.
set -euo pipefail

# This script is dropped into the user's own hypr config dir by the component writer, not
# installed beside the engine, so it cannot source scripts/xdg-config.sh. It restates that
# file's rule - and only that rule - inline: an explicit override wins, else an ABSOLUTE
# XDG_CONFIG_HOME, else $HOME/.config. Keep the two in step.
_rice_base="${XDG_CONFIG_HOME:-}"
case "$_rice_base" in /*) ;; *) _rice_base="${HOME:-}/.config" ;; esac   # XDG-OK: the same rule, restated where no library can be sourced
RICE="${RICE_BIN:-$_rice_base/hypr-rice/rice}"
[ -x "$RICE" ] || { command -v notify-send >/dev/null 2>&1 && notify-send "rice" "engine not found ($RICE)"; exit 1; }

menu() {
    if   command -v rofi   >/dev/null 2>&1; then rofi -dmenu -i -p "Theme" -theme-str 'window {width: 20em;}'
    elif command -v wofi   >/dev/null 2>&1; then wofi --dmenu -i -p "Theme"
    elif command -v fuzzel >/dev/null 2>&1; then fuzzel --dmenu
    else
        command -v notify-send >/dev/null 2>&1 && notify-send "rice" "Install rofi, wofi, or fuzzel"
        return 1
    fi
}

chosen="$(bash "$RICE" themes | grep -v '^(' | menu || true)"
[ -n "$chosen" ] && bash "$RICE" theme "$chosen"

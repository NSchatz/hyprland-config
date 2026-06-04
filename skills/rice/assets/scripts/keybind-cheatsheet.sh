#!/usr/bin/env bash
# Searchable keybind cheat-sheet — reads the LIVE binds from Hyprland and lists them in a menu.
# Robust (no config-file parsing): uses `hyprctl binds -j`. Best results when your binds use
# `bindd` (described) so each row shows a human label instead of the raw dispatcher.
# Deps: hyprctl, jq; one of rofi/wofi/fuzzel.
set -euo pipefail

menu() {
    if   command -v rofi   >/dev/null 2>&1; then rofi -dmenu -i -p "Keybinds" -theme-str 'window {width: 50%;}'
    elif command -v wofi   >/dev/null 2>&1; then wofi --dmenu -i -p "Keybinds"
    elif command -v fuzzel >/dev/null 2>&1; then fuzzel --dmenu
    else
        command -v notify-send >/dev/null 2>&1 && notify-send "Keybinds" "Install rofi, wofi, or fuzzel"
        return 1
    fi
}

# Decode Hyprland's modmask bitfield → readable names (SHIFT=1 CTRL=4 ALT=8 SUPER=64).
modname() {
    local m=$1 out=""
    (( m & 64 )) && out+="SUPER+"
    (( m & 8 ))  && out+="ALT+"
    (( m & 4 ))  && out+="CTRL+"
    (( m & 1 ))  && out+="SHIFT+"
    printf '%s' "$out"
}

hyprctl binds -j \
    | jq -r '.[] | "\(.modmask)\t\(.key)\t\(if (.description // "") != "" then .description else (.dispatcher + " " + (.arg // "")) end)"' \
    | while IFS=$'\t' read -r mask key desc; do
          printf '%s%s\t%s\n' "$(modname "${mask:-0}")" "$key" "$desc"
      done \
    | column -t -s $'\t' \
    | menu >/dev/null

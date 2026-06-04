#!/usr/bin/env bash
# Toggle "game mode": strip animations/blur/shadows/rounding/gaps for max performance.
# Re-run to restore — restoring just reloads the config, so it always returns to your
# real settings (no drift). Bind it to a key (e.g. SUPER+F1).
# Deps: hyprctl (Hyprland).
set -euo pipefail

# animations:enabled is the proxy for "are effects on?" — read it as JSON int.
state="$(hyprctl getoption animations:enabled -j 2>/dev/null \
            | grep -oE '"int"[ ]*:[ ]*[0-9]+' | grep -oE '[0-9]+$' || echo 1)"

if [ "${state:-1}" = "1" ]; then
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0" >/dev/null
    notify-send "Game mode" "ON — effects disabled" 2>/dev/null || true
else
    hyprctl reload >/dev/null
    notify-send "Game mode" "OFF — effects restored" 2>/dev/null || true
fi

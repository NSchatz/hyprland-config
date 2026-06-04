#!/usr/bin/env bash
# Toggle Hyprland blur at runtime (handy on weaker GPUs or for screenshots). Transient —
# a config reload restores your real setting. Bind to a key, e.g. SUPER+SHIFT+B.
# Deps: hyprctl.
set -euo pipefail

state="$(hyprctl getoption decoration:blur:enabled -j 2>/dev/null \
            | grep -oE '"int"[ ]*:[ ]*[0-9]+' | grep -oE '[0-9]+$' || echo 1)"

if [ "${state:-1}" = "1" ]; then
    hyprctl keyword decoration:blur:enabled 0 >/dev/null
    notify-send "Blur" "Off" 2>/dev/null || true
else
    hyprctl keyword decoration:blur:enabled 1 >/dev/null
    notify-send "Blur" "On" 2>/dev/null || true
fi

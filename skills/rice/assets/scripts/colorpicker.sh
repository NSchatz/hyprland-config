#!/usr/bin/env bash
# Screen color picker: eyedropper a pixel, copy its hex to the clipboard.
# Deps: hyprpicker, wl-clipboard.
set -euo pipefail

# -a copies to clipboard automatically; -f hex sets the format; also prints to stdout.
color="$(hyprpicker -a -f hex 2>/dev/null || true)"
[ -n "${color:-}" ] && notify-send "Color picker" "Copied $color" 2>/dev/null || true

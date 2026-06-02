#!/usr/bin/env bash
# Make a timestamped backup of the Hyprland config dir before editing it.
# Prints: BACKUP=<path>  (or BACKUP=none if there's nothing to back up).
# Honors HYPR_DIR (default ~/.config/hypr).
set -euo pipefail

target="${HYPR_DIR:-$HOME/.config/hypr}"

if [ -d "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="${target}.bak.${ts}"
    cp -a "$target" "$backup"
    echo "BACKUP=${backup}"
else
    echo "BACKUP=none (no existing config to back up)"
fi

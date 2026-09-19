#!/usr/bin/env bash
# Searchable keybind cheat-sheet — reads the LIVE binds from Hyprland and lists them in a menu.
# Robust (no config-file parsing): uses `hyprctl binds -j`. Best results when your binds use
# `bindd` (described) so each row shows a human label instead of the raw dispatcher.
# Deps: hyprctl, jq; one of rofi/wofi/fuzzel.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/desktop/helpers.py, action: keybind-cheatsheet). Installed
# beside the engine by rice-init.sh, so it keeps working with the plugin removed.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
libdir=""
for c in "$here" "$here/../../../../scripts" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -f "$c/ricelib/__init__.py" ]; then libdir="$(cd "$c" && pwd)"; break; fi
done
if [ -z "$libdir" ]; then
    command -v notify-send >/dev/null 2>&1 && notify-send "rice" "ricelib not found - re-run rice-init.sh"
    echo "ERROR: the ricelib package was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in \$RICE_DIR." >&2
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    command -v notify-send >/dev/null 2>&1 && notify-send "rice" "python3 is not installed"
    echo "ERROR: python3 is required and is not installed (sudo pacman -S --needed python)." >&2
    exit 2
fi
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.desktop.helpers keybind-cheatsheet "$@"

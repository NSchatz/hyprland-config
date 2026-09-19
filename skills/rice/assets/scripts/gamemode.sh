#!/usr/bin/env bash
# Toggle "game mode": strip animations/blur/shadows/rounding/gaps for max performance.
# Re-run to restore — restoring just reloads the config, so it always returns to your
# real settings (no drift). Bind it to a key (e.g. SUPER+F1).
# Deps: hyprctl (Hyprland).
# animations:enabled is the proxy for "are effects on?" — read it as JSON int.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/desktop/helpers.py, action: gamemode). Installed
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.desktop.helpers gamemode "$@"

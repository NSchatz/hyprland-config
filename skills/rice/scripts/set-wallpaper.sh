#!/usr/bin/env bash
# Set the desktop wallpaper via the available backend: swww > hyprpaper > swaybg.
# Usage: set-wallpaper.sh <image> [--dry-run]
# Persists hyprpaper.conf when hyprpaper is the backend. Does not touch the palette
# (the `rice wallpaper` flow records the wallpaper path in palette.conf).
#
# Maintains <config base>/hypr-rice/current-wallpaper as a symlink to the active image —
# the base being $XDG_CONFIG_HOME when it is absolute and $HOME/.config otherwise; see
# scripts/xdg-config.sh. $RICE_DIR and $HYPR_DIR still override outright —
# the stable pointer every wallpaper consumer (autostart wallpaper-daemon exec-once,
# hyprlock background, hypridle, widgets, dynamic-theme restore) references instead of
# a literal path captured at generation time. Re-theme / re-pick changes one symlink,
# every consumer follows.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/setwallpaper.py). This file locates
# the package and hands off; the name is the interface every caller, doc and test uses.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
libdir=""
for c in "$here" "$here/../../../scripts" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -f "$c/ricelib/__init__.py" ]; then libdir="$(cd "$c" && pwd)"; break; fi
done
if [ -z "$libdir" ]; then
    echo "ERROR: the ricelib package was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in \$RICE_DIR." >&2
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required and is not installed (sudo pacman -S --needed python)." >&2
    exit 2
fi
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.setwallpaper "$@"

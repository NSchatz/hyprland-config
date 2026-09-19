#!/usr/bin/env bash
# Generate <config base>/hypr-rice/palette.conf from a wallpaper, using an installed generator.
# The base is $RICE_DIR when set, else $XDG_CONFIG_HOME when it is an absolute path, else
# $HOME/.config - one decision, made in scripts/xdg-config.sh.
# Order of preference: matugen (Material You) > wallust / pywal (16-color, pywal-compatible JSON).
# Best-effort: on failure it keeps the existing palette and reports.
#
# Usage: palette-from-wallpaper.sh <image>
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/palettefromwallpaper.py). This file locates
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.palettefromwallpaper "$@"

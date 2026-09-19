#!/usr/bin/env bash
# Reload running apps after theme files have been written, so changes show without a logout.
# Only reloads apps that are actually running; everything else is a skip. Changes nothing on
# disk — assumes the theme files were already written + backed up by the skill.
#
# Usage: apply-theme.sh [--cursor <Theme> <size>]
#   --cursor  also apply a cursor theme live via `hyprctl setcursor`.
#
# Prints RELOAD_<app>=ok|skipped lines.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/applytheme.py).
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/applytheme.py). This file locates
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.applytheme "$@"

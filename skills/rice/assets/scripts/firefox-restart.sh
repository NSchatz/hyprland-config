#!/usr/bin/env bash
# Reload hook for Firefox userChrome theming (Issue 15.2).
#
# Firefox reads userChrome.css and rice-colors.css only at process startup,
# so a `rice apply` while Firefox is open leaves the chrome on the old
# palette. This hook closes Firefox cleanly (relies on
# `browser.startup.page = 3` from user.js so tabs restore) and relaunches
# detached.
#
# Manifest line in templates.list:
#   firefox  TAB  <tmpl>/firefox.tmpl  TAB  <profile>/chrome/rice-colors.css  TAB  bash ~/.config/hypr-rice/firefox-restart.sh
#
# Behavior:
#   - Firefox not running              -> no-op, exit 0  (FIREFOX_RESTART=skipped)
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/firefoxrestart.py).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
libdir=""
for c in "$here" "$here/../../../../scripts" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -f "$c/ricelib/__init__.py" ]; then libdir="$(cd "$c" && pwd)"; break; fi
done
if [ -z "$libdir" ]; then
    echo "ERROR: the ricelib package was not found next to $0." >&2; exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required and is not installed." >&2; exit 2
fi
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.firefoxrestart "$@"

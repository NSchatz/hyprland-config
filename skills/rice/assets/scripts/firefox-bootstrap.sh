#!/usr/bin/env bash
# One-time bootstrap for Firefox userChrome theming (Issue 15.1).
# Run by install.sh (or invoked manually after the user runs Firefox once).
#
# Resolves the default Firefox profile from ~/.mozilla/firefox/profiles.ini
# (the profile dir name is dynamic — `xxxxxxxx.default-release` etc.),
# creates <profile>/chrome/ if missing, copies the static userChrome.css +
# user.js into place, and prints the resolved path so install.sh can write
# the templates.list manifest line.
#
# Usage:
#   firefox-bootstrap.sh                     # bootstrap default profile
#   firefox-bootstrap.sh --profile <dir>     # bootstrap a specific profile
#   firefox-bootstrap.sh --no-create-profile # don't auto-create if missing
#
# Output (stdout):
#   FIREFOX_PROFILE=<absolute-path>          # resolved profile directory
#   FIREFOX_CHROME=<absolute-path>           # the chrome/ subdir we wrote
#   FIREFOX_RICE_COLORS=<absolute-path>      # rice-colors.css render target
#   RESTORE_POINT=<apply-id>                 # undo it: rice restore <apply-id>
#
# Every profile file this touches is backed up first and enrolled in the apply's restore point,
# under the SAME apply id as every other surface of that apply when RICE_APPLY_ID is exported by
# the caller. A file whose backup cannot be written is not written at all (FIREFOX_SKIPPED).
#
# Exit codes:
#   0  bootstrap succeeded
#   1  no profile + --no-create-profile (user must launch Firefox first)
#   2  bad arguments / no Firefox installed

#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/firefoxbootstrap.py). The static assets
# (userChrome.css, user.js) sit beside this script when installed into $RICE_DIR, so their
# location is handed over explicitly.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
libdir=""
for c in "$here" "$here/../../../../scripts" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -d "$c/ricelib" ] && [ -f "$c/ricelib/firefoxbootstrap.py" ]; then
        libdir="$(cd "$c" && pwd)"; break
    fi
done
if [ -z "$libdir" ]; then
    echo "ERROR: the ricelib package was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in \$RICE_DIR." >&2
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required and is not installed (sudo pacman -S --needed python)." >&2
    echo "ERROR: no profile file was touched." >&2
    exit 2
fi
# The assets live beside this script (installed) or in the plugin's browser component (dev).
assets="$here"
[ -f "$assets/userChrome.css" ] || assets="${CLAUDE_PLUGIN_ROOT:-}/skills/rice/references/components/browser"
RICE_FIREFOX_ASSETS="${RICE_FIREFOX_ASSETS:-$assets}" \
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.firefoxbootstrap "$@"

#!/usr/bin/env bash
# Syntax-check a shell rc file WITHOUT executing it — the "test after every change" step for
# shell configs. Never sources the file (so it can't run side effects); only parses it.
#
# Usage: verify-shell.sh <rcfile> [bash|zsh|fish]
#   Shell is inferred from the filename if not given.
#
# Output:
#   VERIFY_SHELL=ok (<shell>)
#   VERIFY_SHELL=errors (<shell>)   followed by the parser output
#   VERIFY_SHELL=skipped (<shell> not installed)
#   VERIFY_SHELL=error (...)        bad usage / missing file
# Exit: 0 ok, 1 errors, 2 skipped/usage.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/verifyshell.py).
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/verifyshell.py). This file locates
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.verifyshell "$@"

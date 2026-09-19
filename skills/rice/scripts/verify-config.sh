#!/usr/bin/env bash
# Test that the live Hyprland config actually loads, by reloading and reading
# `hyprctl configerrors`. This is the real "does it work" check — static analysis
# cannot catch everything.
#
# Usage:
#   verify-config.sh              reload, then report parse errors
#   verify-config.sh --no-reload  do NOT reload; just read current errors (read-only)
#   verify-config.sh --expect <file>
#                                 additionally require the compositor to CONFIRM
#                                 that <file> is the config it loaded. Without a
#                                 positive match there is no `ok`.
#
# Output (machine-parseable first line):
#   VERIFY=ok           config is loaded with no parse errors
#   VERIFY=errors       parse errors present (printed below the status line)
#   VERIFY=skipped      no running Hyprland instance / hyprctl missing (cannot live-test)
#   VERIFY=unconfirmed  --expect was given and the compositor did NOT confirm it
#                       loaded that file: either it named a different one (printed
#                       as LOADED_CONFIG=) or it named none at all
#
# Exit codes: 0 = ok, 1 = errors, 2 = skipped (could not test), 3 = unconfirmed.
#
# Note: `hyprctl configerrors` always exits 0 and prints nothing when clean, so the
# verdict comes from whether its (non-blank) output is empty, not from its exit code.
#
# WHY --expect exists: an empty `configerrors` is ALSO exactly what a config that
# was never parsed produces: a `hyprland.lua` shadowing the `hyprland.conf` this
# plugin just wrote, or an instance started with `-c` somewhere else. Reading that
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/verifyconfig.py).
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/verifyconfig.py). This file locates
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.verifyconfig "$@"

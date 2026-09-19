#!/usr/bin/env bash
# Ask the RUNNING compositor which configuration file it actually loaded.
#
# Usage: loaded-config.sh
#
# Why this exists: `hyprctl configerrors` printing nothing is NOT proof that the
# config this plugin wrote is the one Hyprland is running. An empty error list is
# exactly what a config that was never parsed produces - which is the state a
# shadowed (`hyprland.lua` over `hyprland.conf`) or simply-ignored file leaves
# behind. "Live" has to mean the compositor names the file.
#
# Hyprland has no hyprctl command that reports its config path (checked against
# 0.56.2's own `hyprctl --help`; see `tests/integration/offline-check-contract.md`).
# It does, however, LOG the path, once per config file it reads, as
#   Using config: <absolute path>
# and that log is reachable through hyprctl itself. Those log lines are re-emitted
# on every `hyprctl reload`, so a caller that reloads first gets a fresh answer.
#
# Output (KEY=value lines):
#   LOADED_CONFIG=<absolute path>   one line per config file the compositor names
#   LOADED_CONFIG=unknown           when no route could establish it
#   LOADED_CONFIG_SOURCE=<rollinglog|instance-log|systeminfo|none>
#
# Exit: 0 identified, 2 no running instance (nothing to ask), 3 running but the
#       loaded config could not be established.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/loadedconfig.py).
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/loadedconfig.py). This file locates
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.loadedconfig "$@"

#!/usr/bin/env bash
# Run a generated desktop in a throwaway container, nested as one window on this desktop, so
# a rice can be looked at and driven BEFORE anything is written to a home directory.
#
# Usage: rice-preview.sh <command> [args]
#   start [--from <dir>] [--size WxH] [--replace] [--no-install]
#   status | shot [--out <path>] | exec -- <cmd> | logs [--tail N] | stop
#
# Prints one terminal line:
#   PREVIEW=started|running|stopped|none
#   PREVIEW=refused-no-source|refused-no-session|refused-no-docker|refused-already-running
#   PREVIEW=failed-image|failed-start|failed-record|failed-shot
#
# Exit: 0 when the preview is in the state asked for, 1 on a failure or an orphaned record,
# 2 on bad usage or a missing prerequisite, 3 when a preview is already running.
#
# The preview container is given the host's Wayland socket and a DRM RENDER node, and never a
# `card` node - a card node is the machine's real display. That policy is enforced in
# scripts/ricelib/preview/container.py, not here, and tests/test_preview_device_policy.sh
# reads the generated argv to prove it.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/preview/previewcli.py). This file locates the
# package and hands off. It stays a `.sh` because every skill doc, test and keybind invokes it
# by this name, and the entry point is not the thing worth churning.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

# Where the package lives: beside this script, in the plugin, or installed beside the engine.
# The engine copy is what keeps this working on a machine that no longer has the plugin.
libdir=""
for c in "$here" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -f "$c/ricelib/preview/previewcli.py" ]; then libdir="$c"; break; fi
done
if [ -z "$libdir" ]; then
    echo "ERROR: the ricelib package was not found (looked next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, and in \$RICE_DIR)." >&2
    echo "PREVIEW=refused-no-library"
    exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required to run a preview and is not installed." >&2
    echo "ERROR: install it with: sudo pacman -S --needed python" >&2
    echo "       (or run: bash \"${CLAUDE_PLUGIN_ROOT:-<plugin>}/scripts/ensure-python.sh\")" >&2
    echo "PREVIEW=refused-no-python"
    exit 2
fi

PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.preview.previewcli "$@"

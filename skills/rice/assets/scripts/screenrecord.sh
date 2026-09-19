#!/usr/bin/env bash
# Toggle screen recording. Prefers `wf-recorder` (repo C package, no ffmpeg-next pin); falls
# back to `wl-screenrec` (HW-encoded via VAAPI — drastically lower CPU on AMD/Intel) when the
# user has opted in to the AUR Rust build. This order intentionally inverts the obvious "HW
# first" choice — defect #7: wl-screenrec 0.2.0 pins ffmpeg-next 8.0.0 and breaks on every
# ffmpeg cliff. wf-recorder is the reliable default.
#   Usage: screenrecord.sh [region|output] [audio]
#   - first call starts recording, second call (any args) stops it
#   - "audio" captures the default sink/monitor as well
# Deps: one of {wf-recorder, wl-screenrec}; slurp (region mode); wl-clipboard optional.
# Both recorders stop cleanly on SIGINT.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/desktop/helpers.py, action: screenrecord). Installed
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.desktop.helpers screenrecord "$@"

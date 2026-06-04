#!/usr/bin/env bash
# Toggle screen recording with wf-recorder.
#   Usage: screenrecord.sh [region|output] [audio]
#   - first call starts recording, second call (any args) stops it
#   - "audio" captures the default sink/monitor as well
# Deps: wf-recorder, slurp (region mode), wl-clipboard optional.
set -euo pipefail

dir="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
mkdir -p "$dir"

if pgrep -x wf-recorder >/dev/null 2>&1; then
    pkill -INT -x wf-recorder
    notify-send "Recording" "Stopped" 2>/dev/null || true
    exit 0
fi

mode="${1:-region}"
audio="${2:-}"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"
args=(-f "$file")
[ "$mode" = "region" ] && args+=(-g "$(slurp)")
[ "$audio" = "audio" ] && args+=(--audio)

wf-recorder "${args[@]}" &
notify-send "Recording" "Started → $(basename "$file")" 2>/dev/null || true

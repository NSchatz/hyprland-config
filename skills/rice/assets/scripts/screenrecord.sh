#!/usr/bin/env bash
# Toggle screen recording. Prefers wl-screenrec (HW-encoded via VAAPI — drastically lower
# CPU on AMD/Intel) and falls back to wf-recorder (software-encoded).
#   Usage: screenrecord.sh [region|output] [audio]
#   - first call starts recording, second call (any args) stops it
#   - "audio" captures the default sink/monitor as well
# Deps: one of {wl-screenrec, wf-recorder}; slurp (region mode); wl-clipboard optional.
# Both recorders stop cleanly on SIGINT.
set -euo pipefail

dir="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
mkdir -p "$dir"

# If either recorder is already running, stop it and exit.
for rec in wl-screenrec wf-recorder; do
    if pgrep -x "$rec" >/dev/null 2>&1; then
        pkill -INT -x "$rec"
        notify-send "Recording" "Stopped" 2>/dev/null || true
        exit 0
    fi
done

mode="${1:-region}"
audio="${2:-}"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"

if command -v wl-screenrec >/dev/null 2>&1; then
    args=(-f "$file")
    [ "$mode" = "region" ] && args+=(-g "$(slurp)")
    [ "$audio" = "audio" ] && args+=(--audio)
    wl-screenrec "${args[@]}" &
elif command -v wf-recorder >/dev/null 2>&1; then
    args=(-f "$file")
    [ "$mode" = "region" ] && args+=(-g "$(slurp)")
    [ "$audio" = "audio" ] && args+=(--audio)
    wf-recorder "${args[@]}" &
else
    notify-send "Recording" "Install wl-screenrec or wf-recorder" 2>/dev/null || true
    exit 1
fi

notify-send "Recording" "Started → $(basename "$file")" 2>/dev/null || true

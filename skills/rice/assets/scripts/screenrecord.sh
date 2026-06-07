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
set -euo pipefail

dir="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
mkdir -p "$dir"

# If either recorder is already running, stop it and exit.
for rec in wf-recorder wl-screenrec; do
    if pgrep -x "$rec" >/dev/null 2>&1; then
        pkill -INT -x "$rec"
        notify-send "Recording" "Stopped" 2>/dev/null || true
        exit 0
    fi
done

mode="${1:-region}"
audio="${2:-}"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"

if command -v wf-recorder >/dev/null 2>&1; then
    args=(-f "$file")
    [ "$mode" = "region" ] && args+=(-g "$(slurp)")
    [ "$audio" = "audio" ] && args+=(--audio)
    wf-recorder "${args[@]}" &
elif command -v wl-screenrec >/dev/null 2>&1; then
    args=(-f "$file")
    [ "$mode" = "region" ] && args+=(-g "$(slurp)")
    [ "$audio" = "audio" ] && args+=(--audio)
    wl-screenrec "${args[@]}" &
else
    notify-send "Recording" "Install wf-recorder (or wl-screenrec)" 2>/dev/null || true
    exit 1
fi

notify-send "Recording" "Started → $(basename "$file")" 2>/dev/null || true

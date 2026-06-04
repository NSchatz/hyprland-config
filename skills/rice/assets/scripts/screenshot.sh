#!/usr/bin/env bash
# Screenshot helper for Hyprland.
#   Usage: screenshot.sh [region|window|output] [edit]
#   - copies the PNG to the clipboard AND saves it to ~/Pictures/Screenshots
#   - "edit" opens an annotator (satty, else swappy) before saving
# Prefers grimblast > hyprshot > grim+slurp, using whatever is installed.
# Deps: one of {grimblast, hyprshot, grim+slurp}; wl-clipboard; (jq for window mode w/ grim).
set -euo pipefail

mode="${1:-region}"      # region | window | output(full)
annotate="${2:-}"        # "edit" to open an annotator
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

if command -v grimblast >/dev/null 2>&1; then
    case "$mode" in
        window) grimblast save active "$file" ;;
        output) grimblast save output "$file" ;;
        *)      grimblast save area   "$file" ;;
    esac
elif command -v hyprshot >/dev/null 2>&1; then
    case "$mode" in
        window) m=window ;; output) m=output ;; *) m=region ;;
    esac
    hyprshot -m "$m" -o "$dir" -f "$(basename "$file")" -s
else
    case "$mode" in
        window) grim -g "$(hyprctl activewindow -j \
                    | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" "$file" ;;
        output) grim "$file" ;;
        *)      grim -g "$(slurp)" "$file" ;;
    esac
fi

if [ "$annotate" = "edit" ]; then
    if   command -v satty  >/dev/null 2>&1; then satty  --filename "$file" --output-filename "$file"
    elif command -v swappy >/dev/null 2>&1; then swappy -f "$file" -o "$file"
    fi
fi

wl-copy < "$file"
notify-send "Screenshot" "Saved & copied — $(basename "$file")" -i "$file" 2>/dev/null || true

#!/usr/bin/env bash
# OCR: drag-select a screen region, extract its text, copy to the clipboard.
#   Usage: ocr.sh [lang]   (default lang: eng)
# Deps: grim, slurp, tesseract (+ tesseract-data-<lang>), wl-clipboard.
set -euo pipefail

lang="${1:-eng}"
img="$(mktemp --suffix=.png)"
trap 'rm -f "$img"' EXIT

grim -g "$(slurp)" "$img"
text="$(tesseract "$img" - -l "$lang" 2>/dev/null)"

if [ -z "${text//[$' \t\n']/}" ]; then
    notify-send "OCR" "No text detected" 2>/dev/null || true
    exit 0
fi
printf '%s' "$text" | wl-copy
notify-send "OCR" "Copied $(printf '%s' "$text" | wc -w) words to clipboard" 2>/dev/null || true

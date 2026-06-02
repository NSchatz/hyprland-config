#!/usr/bin/env bash
# Back up any existing Hyprland config, then install a freshly generated one.
#
# Usage:   install-config.sh <staging-dir>
#   <staging-dir>  Directory containing the generated *.conf files.
#
# Behavior:
#   - Target dir is $HYPR_DIR (default: ~/.config/hypr).
#   - If the target exists and is non-empty, it is copied to
#     <target>.bak.<YYYYmmdd-HHMMSS> before anything is changed.
#   - The generated *.conf files are then copied into the target.
#
# Prints a summary including the backup path (BACKUP=...), which the caller relays.
set -euo pipefail

staging="${1:-}"
if [ -z "$staging" ]; then
    echo "ERROR: missing <staging-dir> argument" >&2
    exit 2
fi
if [ ! -d "$staging" ]; then
    echo "ERROR: staging dir '$staging' does not exist" >&2
    exit 2
fi

shopt -s nullglob
conf_files=("$staging"/*.conf)
if [ ${#conf_files[@]} -eq 0 ]; then
    echo "ERROR: no .conf files found in '$staging'" >&2
    exit 2
fi
if [ ! -e "$staging/hyprland.conf" ]; then
    echo "ERROR: staging dir is missing the main hyprland.conf" >&2
    exit 2
fi

target="${HYPR_DIR:-$HOME/.config/hypr}"

backup=""
if [ -d "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="${target}.bak.${ts}"
    cp -a "$target" "$backup"
    echo "BACKUP=${backup}"
else
    echo "BACKUP=none (no existing config to back up)"
fi

mkdir -p "$target"
for f in "${conf_files[@]}"; do
    cp -f "$f" "$target/"
    echo "INSTALLED=$(basename "$f")"
done

echo "TARGET=${target}"
echo "DONE=ok"

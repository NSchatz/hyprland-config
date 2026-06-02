#!/usr/bin/env bash
# Timestamped backup of arbitrary config files/dirs before editing them.
# Used by the rice / shell-config / desktop-shell skills (they touch files
# outside ~/.config/hypr, so the hypr-specific backup-config.sh does not apply).
#
# Usage: backup-path.sh <path> [<path> ...]
# Prints one line per path:
#   BACKUP <original> -> <backup>            (copied)
#   BACKUP <original> -> none (did not exist)
# All backups in one invocation share a timestamp so a whole change set restores together.
set -euo pipefail

if [ "$#" -eq 0 ]; then
    echo "ERROR: usage: backup-path.sh <path> [<path> ...]" >&2
    exit 2
fi

ts="$(date +%Y%m%d-%H%M%S)"
for p in "$@"; do
    case "$p" in "~"*) p="${HOME}${p#\~}" ;; esac   # expand leading ~
    if [ -e "$p" ]; then
        b="${p%/}.bak.${ts}"
        cp -a "$p" "$b"
        echo "BACKUP $p -> $b"
    else
        echo "BACKUP $p -> none (did not exist)"
    fi
done

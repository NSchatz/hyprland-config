#!/usr/bin/env bash
# Timestamped backup of arbitrary config files/dirs before editing them.
# Used by the rice and edit-config skills (they touch files outside ~/.config/hypr, so the
# hypr-specific backup-config.sh does not apply).
#
# Usage: backup-path.sh <path> [<path> ...]
# Prints one line per path:
#   BACKUP <original> -> <backup>            (copied)
#   BACKUP <original> -> none (did not exist)
#   BACKUP <original> -> FAILED (<why>)      (could not be backed up: DO NOT edit that path)
# and one trailing line:
#   RESTORE_POINT=<apply-id>                 (undo the whole set: rice restore <apply-id>)
#
# All backups in one invocation share a timestamp so a whole change set restores together, and
# every path is enrolled in that apply's restore point (scripts/restore-point.sh) so
# `rice restore <apply-id>` puts the set back with one command. Set RICE_APPLY_ID in the
# environment to join an apply already in progress (that is how a shell-rc edit made as part of
# a theming apply shares that apply's timestamp); leave it unset and this invocation gets its own
# restore point, restorable on its own.
#
# Exit: 0 when every path is backed up (or did not exist), 1 when at least one could not be -
# the caller must not edit a path whose backup failed, 2 on bad usage.
set -uo pipefail

if [ "$#" -eq 0 ]; then
    echo "ERROR: usage: backup-path.sh <path> [<path> ...]" >&2
    exit 2
fi

here="$(cd "$(dirname "$0")" && pwd)"
lib=""
for c in "$here/restore-point.sh" \
         "${CLAUDE_PLUGIN_ROOT:-}/scripts/restore-point.sh" \
         "${RICE_DIR:-$HOME/.config/hypr-rice}/restore-point.sh"; do
    if [ -n "$c" ] && [ -f "$c" ]; then lib="$c"; break; fi
done
if [ -z "$lib" ]; then
    echo "ERROR: restore-point library not found (looked next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, and in \$RICE_DIR)" >&2
    exit 2
fi
# shellcheck source=restore-point.sh
. "$lib"

rp_ensure_apply_id || { echo "ERROR: unusable RICE_APPLY_ID '${RICE_APPLY_ID:-}' (no '/', no whitespace, no leading dot)" >&2; exit 2; }
id="$RICE_APPLY_ID"
rc=0

for p in "$@"; do
    p="$(rp_expand "$p")"
    if rp_excluded "$p"; then
        # Out of the restore point's scope: back it up exactly as this script always has, but
        # do not enrol it - that directory's restore is a separate contract.
        if [ -e "$p" ] || [ -L "$p" ]; then
            b="${p%/}.bak.${id}"
            if cp -a "$p" "$b" 2>/dev/null; then
                echo "BACKUP $p -> $b"
            else
                echo "BACKUP $p -> FAILED (could not write $b)"
                rc=1
            fi
        else
            echo "BACKUP $p -> none (did not exist)"
        fi
        continue
    fi
    if rp_protect "$p"; then
        case "$RP_LAST_STATE" in
            file|already-file) echo "BACKUP $p -> $RP_LAST_BACKUP" ;;
            new)               echo "BACKUP $p -> none (did not exist)" ;;
            already-new)       echo "BACKUP $p -> none (created by this apply; restoring removes it)" ;;
            *)                 echo "BACKUP $p -> none (did not exist)" ;;
        esac
    else
        echo "BACKUP $p -> FAILED ($RP_LAST_ERROR)"
        rc=1
    fi
done

echo "RESTORE_POINT=$id"
exit "$rc"

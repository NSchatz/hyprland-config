#!/usr/bin/env bash
#   rice-restore.sh <apply-id>     restore everything that apply touched
#   rice-restore.sh --list         list the restore points that exist, newest first
#
# For every file in the restore point:
#   the apply overwrote it -> the backup taken before that write is copied back   (RESTORED)
#   the apply created it   -> it is removed, so no orphan is left behind          (REMOVED)
#   it sits inside another surface in the same point -> that surface puts it back (RESTORED with)
#
# One apply writes both a directory and files inside it, so the entries are not disjoint paths.
# They are replayed CONTAINER FIRST (rp_replay_order): a surface is put back wholesale before
# anything enrolled inside it, so a nested entry always has the last word and can never be undone
# by the copy that follows it. A nested path enrolled while its container was already in the point
# carries no backup of its own (kind `covered`) - the container's backup predates every write this
# apply made under it, so it already holds that path's prior content.
#
# One unreadable backup, or one target that cannot be written, does not abort the run: every
# other file in the point is still restored, the failure is reported by path, and the restore
# point is KEPT so re-running finishes the job. Re-running is always safe - files already put
# back in an earlier (or interrupted) attempt are skipped, not restored twice.
#
# Exit codes:
#   0  every file in the restore point was restored or removed; the point is cleared
#   1  partially restored: some files failed; the point is kept, fix them and re-run
#   2  usage error, or the restore-point library could not be found
#   3  nothing to restore for that identifier (never applied under it, or already restored)
#      (a cleared point is the normal, successful end state, so this is what a second restore
#       against the same identifier reports - it is deliberately NOT exit 0, which would be
#       "success with nothing restored")
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/ricerestore.py). This file locates the package
# and hands off. It stays a `.sh` because `rice restore` and every doc and test invoke it by
# this name.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

libdir=""
for c in "$here" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -f "$c/ricelib/ricerestore.py" ]; then libdir="$c"; break; fi
done
if [ -z "$libdir" ]; then
    echo "ERROR: the ricelib package was not found (looked next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, and in \$RICE_DIR)." >&2
    echo "RESTORE=refused-no-library (nothing was restored)" >&2
    exit 2
fi

# Fail loudly rather than reporting a restore that did not happen.
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required to restore and is not installed." >&2
    echo "ERROR: nothing was restored. Your backups are untouched on disk as .bak.<apply-id>." >&2
    echo "       Install it with: sudo pacman -S --needed python" >&2
    echo "RESTORE=refused-no-python (nothing was restored)" >&2
    exit 2
fi

PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.ricerestore "$@"

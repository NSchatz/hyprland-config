#!/usr/bin/env bash
# Timestamped backup of arbitrary config files/dirs before editing them.
# Used by the rice and edit-config skills (they touch files outside the hypr config dir, so the
# hypr-specific backup-config.sh does not apply).
#
# Usage: backup-path.sh <path> [<path> ...]
# Prints one line per path:
#   BACKUP <original> -> <backup>            (copied)
#   BACKUP <original> -> none (did not exist)
#   BACKUP <original> -> FAILED (<why>)      (could not be backed up: DO NOT edit that path)
#   NOT_ENROLLED <original>                  (copied, but left out of the restore point: it
#                                             contains a surface with its own separate restore,
#                                             so `rice restore` must never put it back)
# and one trailing line:
#   RESTORE_POINT=<apply-id>                 (undo the whole set: rice restore <apply-id>)
#
# All backups in one invocation share an apply id so a whole change set restores together. Set
# RICE_APPLY_ID in the environment to join an apply already in progress; leave it unset and this
# invocation gets its own restore point, restorable on its own.
#
# Exit: 0 when every path is backed up (or did not exist), 1 when at least one could not be -
# the caller must not edit a path whose backup failed, 2 on bad usage or a missing runtime.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/backuppath.py). This file locates the package
# and hands off. It stays a `.sh` because every caller, skill doc and test invokes it by this
# name, and the entry point is not the thing worth churning.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

# Where the package lives: beside this script, in the plugin, or installed beside the engine.
# The engine copy is what keeps this working on a machine that no longer has the plugin.
libdir=""
for c in "$here" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -f "$c/ricelib/backuppath.py" ]; then libdir="$c"; break; fi
done
if [ -z "$libdir" ]; then
    echo "ERROR: the ricelib package was not found (looked next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, and in \$RICE_DIR)." >&2
    echo "ERROR: nothing was backed up. Do not edit the paths you meant to back up." >&2
    exit 2
fi

# Fail SAFE, loudly. A missing interpreter must never read as "there was nothing to back up":
# the whole contract of this script is that a caller may only edit what it has backed up, so no
# backup means no edit.
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required to take a backup and is not installed." >&2
    echo "ERROR: nothing was backed up, so nothing may be edited. Install it with:" >&2
    echo "         sudo pacman -S --needed python" >&2
    echo "       (or run: bash \"${CLAUDE_PLUGIN_ROOT:-<plugin>}/scripts/ensure-python.sh\")" >&2
    exit 2
fi

PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.backuppath "$@"

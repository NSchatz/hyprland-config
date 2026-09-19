#!/usr/bin/env bash
# Back a path up and enrol it in this apply's restore point, so the caller may overwrite it.
#
#   restore-point.sh new-id                 mint an apply id
#   restore-point.sh record <path> [...]    protect paths, print RESTORE_POINT=<id>
#   restore-point.sh list                   the restore points that exist, newest first
#   restore-point.sh show <id>              one point's ledger
#
# Sourced, it defines the two helpers its remaining bash callers need:
#   rp_protect <path>    0 = the caller may write; 1 = it MUST NOT, and $RP_LAST_ERROR says why
#   rp_state_root        where durable per-machine state lives
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/restorepoint.py) - the ledger format, the
# containment rules, the fold-into-an-ancestor logic and the hypr-config-dir boundary all live
# there, and tests/test_restorepoint_parity.sh proved the port byte-for-byte against the bash
# this replaced. What is left here is the seam: two shell functions over one subprocess each,
# for the callers that are still bash (firefox-prefs.sh, firefox-bootstrap.sh,
# render-templates.sh). When those move, this file becomes a plain dispatcher.
#
# No `set` at the top on purpose: this file is both a CLI and a library other scripts source,
# and changing a caller's shell options behind its back would be a bug in every caller at once.

RP_LAST_ERROR=""   # why the last rp_protect refused (empty on success)
RP_LAST_STATE=""   # excluded | already-<kind> | covered | file | new | contains-excluded
RP_LAST_BACKUP=""  # the sidecar holding the prior content, when there is one
RP_LAST_ID=""      # the apply id this enrolment joined
RP_LAST_COVER=""   # the enrolled ancestor a `covered` entry folds into

# Locate the package: beside this script, in the plugin, or installed beside the engine. The
# engine copy is what keeps this working on a machine that no longer has the plugin.
_rp_libdir() {
    local here c
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    for c in "$here" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
        if [ -n "$c" ] && [ -f "$c/ricelib/restorepoint.py" ]; then printf '%s\n' "$c"; return 0; fi
    done
    return 1
}

_rp_py() {
    local libdir
    libdir="$(_rp_libdir)" || {
        RP_LAST_ERROR="the ricelib package was not found (looked next to ${BASH_SOURCE[0]}, in \$CLAUDE_PLUGIN_ROOT/scripts, and in \$RICE_DIR)"
        return 127
    }
    if ! command -v python3 >/dev/null 2>&1; then
        RP_LAST_ERROR="python3 is required to take a backup and is not installed (sudo pacman -S --needed python)"
        return 127
    fi
    PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" python3 -m ricelib.restorepoint "$@"
}

# Where durable per-machine state lives. One answer, shared with the install record and the
# browser-preference record, so a record cannot land where nothing later reads it.
rp_state_root() {
    _rp_py state-root
}

# rp_protect <path> - back the path up and enrol it, so the caller may overwrite it.
#
# Returns 0 when the caller may write, 1 when it MUST NOT (nothing was overwritten). A path with
# no prior content is enrolled too: the "this apply created it" record is what lets a later
# restore remove the file again, so failing to persist THAT is exactly as fatal as failing to
# copy a backup.
rp_protect() {
    local out rc line
    RP_LAST_ERROR=""; RP_LAST_STATE=""; RP_LAST_BACKUP=""; RP_LAST_ID=""; RP_LAST_COVER=""
    out="$(_rp_py protect "${1:-}")"; rc=$?
    if [ "$rc" -eq 127 ] && [ -n "$RP_LAST_ERROR" ]; then
        return 1
    fi
    while IFS= read -r line; do
        case "$line" in
            RP_STATE=*)       RP_LAST_STATE="${line#RP_STATE=}" ;;
            RP_BACKUP=*)      RP_LAST_BACKUP="${line#RP_BACKUP=}" ;;
            RP_ID=*)          RP_LAST_ID="${line#RP_ID=}" ;;
            RP_COVER=*)       RP_LAST_COVER="${line#RP_COVER=}" ;;
            RP_ERROR=*)       RP_LAST_ERROR="${line#RP_ERROR=}" ;;
            # The id the child settled on has to reach THIS shell, so every later surface in
            # this process joins the same restore point instead of minting one per file.
            RICE_APPLY_ID=*)  RICE_APPLY_ID="${line#RICE_APPLY_ID=}"; export RICE_APPLY_ID ;;
        esac
    done <<< "$out"
    return "$rc"
}

# --- CLI (only when run, never when sourced) -------------------------------------------------
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -uo pipefail
    if ! _rp_libdir >/dev/null; then
        echo "ERROR: the ricelib package was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in \$RICE_DIR." >&2
        exit 2
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        echo "ERROR: python3 is required and is not installed (sudo pacman -S --needed python)." >&2
        echo "ERROR: nothing was backed up or enrolled." >&2
        exit 2
    fi
    _rp_py "$@"
    exit $?
fi

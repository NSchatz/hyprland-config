#!/usr/bin/env bash
# Restore points: one identifier per apply, every file that apply is about to write copied to a
# timestamped backup BEFORE it is overwritten, so a single `rice restore <apply-id>` puts the
# whole set back the way it was.
#
# Sourced as a library by every writer that touches a user file (skills/rice/scripts/
# render-templates.sh, skills/rice/assets/scripts/firefox-bootstrap.sh, scripts/backup-path.sh),
# and usable on its own:
#   restore-point.sh new-id            print a fresh apply id (export it as RICE_APPLY_ID so
#                                      every stage of one apply shares one restore point)
#   restore-point.sh record <path>...  back up + enroll paths under $RICE_APPLY_ID
#   restore-point.sh list              list the restore points that exist, newest first
#   restore-point.sh show <apply-id>   print one restore point's entries
# Restoring is a separate command: rice-restore.sh (or `rice restore <apply-id>`).
#
# Store layout ($RICE_RESTORE_DIR, default ${XDG_STATE_HOME:-~/.local/state}/hypr-rice/restore):
#   <store>/<apply-id>/entries.tsv   kind <tab> target <tab> backup   (append-only)
#   <store>/<apply-id>/done.tsv      one target per line, appended as a restore completes it
# kind is `file` (the target existed; the backup holds its prior content) or `new` (the target
# did not exist; restoring removes it again). The backup copy itself is the sidecar
# <target>.bak.<apply-id> - the same shape scripts/backup-path.sh has always written, now with a
# ledger over it so a whole apply restores as one set.
#
# Entries are appended BEFORE the write they protect, so an apply killed at any point - during
# any stage or between stages - leaves a restore point covering everything written so far.
#
# RP_EXCLUDE: the Hyprland config dir (~/.config/hypr) is NEVER enrolled here. It has its own,
# separate backup/restore contract that this file does not read, call, or duplicate; see
# rp_excluded below. Nothing under it is ever put in a restore point, so no restore ever
# touches it.
#
# No `set` here on purpose: this file is sourced, and changing the caller's shell options
# behind its back (e.g. dropping its `set -e`) would be a bug in every caller at once.

RP_LAST_ERROR=""    # why the last rp_protect refused (empty on success)
RP_LAST_STATE=""    # file | new | already-file | already-new | excluded
RP_LAST_BACKUP=""   # the sidecar holding the prior content (empty when there was none)
RP_LAST_ID=""       # the apply id the last rp_protect enrolled under

# Where restore points live.
rp_state_dir() {
    if [ -n "${RICE_RESTORE_DIR:-}" ]; then
        printf '%s\n' "${RICE_RESTORE_DIR%/}"
    else
        printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/hypr-rice/restore"
    fi
}

# Expand a leading ~ the way the rest of the engine does.
rp_expand() {
    local p="${1:-}"
    case "$p" in "~"*) p="${HOME}${p#\~}" ;; esac
    printf '%s\n' "$p"
}

# RP_EXCLUDE: true for any path inside the Hyprland config dir. Those paths are out of this
# mechanism's scope entirely - they are never backed up here, never enrolled, never restored
# here, and never reported on by the restore command. Their backup/restore is somebody else's
# contract and this file neither reads nor invokes it.
rp_excluded() {
    local p d
    p="$(rp_expand "${1:-}")"
    d="${HYPR_DIR:-$HOME/.config/hypr}"   # RP_EXCLUDE
    d="${d%/}"
    case "$p" in
        "$d"|"$d"/*) return 0 ;;
    esac
    return 1
}

# A fresh apply id: the timestamp every file of one apply shares. Suffixed if a point with that
# second already exists, so two applies in the same second stay separate restore points.
rp_new_id() {
    local base cand store n
    base="$(date +%Y%m%d-%H%M%S)" || return 1
    store="$(rp_state_dir)"
    cand="$base"
    n=1
    while [ -e "$store/$cand" ] && [ "$n" -lt 100 ]; do
        cand="${base}-${n}"
        n=$((n + 1))
    done
    printf '%s\n' "$cand"
}

# Settle the id this process enrols under and leave it in RICE_APPLY_ID: the caller's own value
# when it set one (that is how the three write stages of a single apply share one restore
# point), otherwise a fresh one, exported so every later surface in this process - and every
# child it starts - joins the same point rather than minting one per file.
# Must NOT be called through a command substitution: the export would die with the subshell.
rp_ensure_apply_id() {
    local new
    if [ -n "${RICE_APPLY_ID:-}" ]; then
        case "$RICE_APPLY_ID" in
            *[/[:space:]]*|.*) return 1 ;;
        esac
        return 0
    fi
    new="$(rp_new_id)" || return 1
    RICE_APPLY_ID="$new"
    export RICE_APPLY_ID
    return 0
}

rp_apply_id() {
    rp_ensure_apply_id || return 1
    printf '%s\n' "$RICE_APPLY_ID"
}

rp_point_dir() {
    printf '%s/%s\n' "$(rp_state_dir)" "${1:-}"
}

# Print the kind recorded for a target in one entries file; non-zero when it is not enrolled.
rp_entry_kind() {
    local f="${1:-}" t="${2:-}"
    [ -f "$f" ] || return 1
    awk -F'\t' -v t="$t" '$2 == t { print $1; found = 1; exit } END { exit !found }' "$f"
}

rp_append() {
    local dir="$1" kind="$2" target="$3" backup="$4"
    printf '%s\t%s\t%s\n' "$kind" "$target" "$backup" >> "$dir/entries.tsv" 2>/dev/null
}

# A target this mechanism is allowed to write to or remove during a restore. Guards against a
# hand-edited ledger turning a restore into `rm -rf $HOME`.
rp_safe_target() {
    local p="${1:-}"
    case "$p" in
        /) return 1 ;;
        /*) ;;
        *) return 1 ;;
    esac
    [ "$p" = "${HOME%/}" ] && return 1
    return 0
}

# rp_protect <path>
#   Back the path up and enroll it in this apply's restore point, so the caller may overwrite it.
#   Returns 0 when the caller may write, 1 when it MUST NOT (nothing was overwritten, and
#   $RP_LAST_ERROR says why). A path with no prior content is enrolled too: the "this apply
#   created it" record is what lets a later restore remove the file again, so failing to persist
#   THAT is exactly as fatal as failing to copy a backup - the caller skips the surface either
#   way rather than writing a file nothing can take back.
rp_protect() {
    local target backup id dir kind
    RP_LAST_ERROR=""; RP_LAST_STATE=""; RP_LAST_BACKUP=""; RP_LAST_ID=""
    target="$(rp_expand "${1:-}")"
    if [ -z "$target" ]; then
        RP_LAST_ERROR="empty path"
        return 1
    fi
    if rp_excluded "$target"; then
        RP_LAST_STATE="excluded"
        return 0
    fi
    if ! rp_ensure_apply_id; then
        RP_LAST_ERROR="unusable apply id '${RICE_APPLY_ID:-}' (no '/', no whitespace, no leading dot)"
        return 1
    fi
    id="$RICE_APPLY_ID"
    RP_LAST_ID="$id"
    dir="$(rp_point_dir "$id")"
    if ! mkdir -p "$dir" 2>/dev/null; then
        RP_LAST_ERROR="restore point is not writable: $dir"
        return 1
    fi
    kind="$(rp_entry_kind "$dir/entries.tsv" "$target")" || kind=""
    if [ -n "$kind" ]; then
        # Already enrolled earlier in this same apply. The first enrollment holds the prior
        # state; re-copying now would capture this apply's own output as "what was there before".
        RP_LAST_STATE="already-$kind"
        if [ "$kind" = "file" ]; then
            RP_LAST_BACKUP="${target%/}.bak.${id}"
        fi
        return 0
    fi
    if [ -e "$target" ] || [ -L "$target" ]; then
        backup="${target%/}.bak.${id}"
        if ! cp -a "$target" "$backup" 2>/dev/null; then
            RP_LAST_ERROR="backup could not be written: $backup"
            return 1
        fi
        if ! rp_append "$dir" file "$target" "$backup"; then
            RP_LAST_ERROR="restore point entry could not be written: $dir/entries.tsv"
            return 1
        fi
        RP_LAST_STATE="file"
        RP_LAST_BACKUP="$backup"
    else
        if ! rp_append "$dir" new "$target" "-"; then
            RP_LAST_ERROR="restore point entry could not be written: $dir/entries.tsv"
            return 1
        fi
        RP_LAST_STATE="new"
    fi
    return 0
}

# Mark one target as fully restored, so an interrupted restore that is re-run skips it.
rp_mark_done() {
    local dir="${1:-}" target="${2:-}"
    printf '%s\n' "$target" >> "$dir/done.tsv" 2>/dev/null
}

rp_is_done() {
    local dir="${1:-}" target="${2:-}"
    [ -f "$dir/done.tsv" ] || return 1
    grep -Fxq -- "$target" "$dir/done.tsv" 2>/dev/null
}

# Drop a restore point. Only ever called once every file in it is back the way it was. The
# .bak.<apply-id> sidecars are deliberately left on disk: they are the user's own copies, and
# clearing the ledger is what makes a second restore report "nothing to restore".
rp_clear() {
    local id="${1:-}" dir
    [ -n "$id" ] || return 1
    case "$id" in */*|.*) return 1 ;; esac
    dir="$(rp_point_dir "$id")"
    rm -rf "$dir"
}

rp_list() {
    local store d id n found=0
    store="$(rp_state_dir)"
    if [ -d "$store" ]; then
        while IFS= read -r d; do
            [ -s "$d/entries.tsv" ] || continue
            id="$(basename "$d")"
            n="$(grep -c . "$d/entries.tsv" 2>/dev/null)" || n=0
            printf '%s\t%s file(s)\n' "$id" "$n"
            found=1
        done < <(find "$store" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r)
    fi
    if [ "$found" -eq 0 ]; then
        echo "(no restore points under $store)"
    fi
}

# --- CLI (only when run, never when sourced) -------------------------------------------------
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -uo pipefail
    _rp_cmd="${1:-help}"; shift 2>/dev/null || true
    case "$_rp_cmd" in
        new-id) rp_new_id ;;
        list)   rp_list ;;
        show)
            _rp_dir="$(rp_point_dir "${1:-}")"
            if [ -s "$_rp_dir/entries.tsv" ]; then cat "$_rp_dir/entries.tsv"; else
                echo "(no restore point '${1:-}' under $(rp_state_dir))" >&2; exit 3
            fi
            ;;
        record)
            [ "$#" -gt 0 ] || { echo "ERROR: usage: restore-point.sh record <path> [<path> ...]" >&2; exit 2; }
            _rp_rc=0
            for _rp_p in "$@"; do
                if rp_protect "$_rp_p"; then
                    printf 'PROTECTED %s (%s)\n' "$(rp_expand "$_rp_p")" "$RP_LAST_STATE"
                else
                    printf 'PROTECT_FAILED %s (%s)\n' "$(rp_expand "$_rp_p")" "$RP_LAST_ERROR" >&2
                    _rp_rc=1
                fi
            done
            [ -n "${RP_LAST_ID:-}" ] && printf 'RESTORE_POINT=%s\n' "$RP_LAST_ID"
            exit "$_rp_rc"
            ;;
        help|-h|--help) sed -n '2,16p' "$0" ;;
        *) echo "unknown command: $_rp_cmd (try: restore-point.sh help)" >&2; exit 2 ;;
    esac
fi

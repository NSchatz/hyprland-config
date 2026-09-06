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
# kind is `file` (the target existed; the backup holds its prior content), `new` (the target did
# not exist; restoring removes it again) or `covered` (the target sits inside a surface already
# enrolled in this same point; column 3 names that surface, which restores it). The backup copy
# itself is the sidecar <target>.bak.<apply-id> - the same shape scripts/backup-path.sh has always
# written, now with a ledger over it so a whole apply restores as one set.
#
# Containment. One apply legitimately writes both a directory (~/.config/waybar) and files inside
# it, so entries in one point are NOT disjoint paths. Two rules keep that honest:
#   * enrolling a path that sits inside an already-enrolled surface folds into that surface
#     (kind `covered`) instead of writing a second, nested sidecar. The enclosing backup was
#     taken before this apply wrote anything here, so it already holds the nested path's prior
#     content - and a nested sidecar would live INSIDE the surface the restore replaces
#     wholesale, which would destroy it;
#   * enrolling a surface that CONTAINS already-enrolled paths is allowed as-is: the restore
#     replays containers before their contents, so the nested entries correct whatever the
#     wholesale copy brought back.
#
# Entries are appended BEFORE the write they protect, so an apply killed at any point - during
# any stage or between stages - leaves a restore point covering everything written so far.
#
# RP_EXCLUDE: the Hyprland config dir (<config base>/hypr, resolved exactly as the writing
# scripts resolve it - see scripts/xdg-config.sh) is NEVER enrolled here. It has its own,
# separate backup/restore contract that this file does not read, call, or duplicate; see
# rp_excluded below. Nothing under it is ever put in a restore point, so no restore ever
# touches it - and neither is any path that CONTAINS it (rp_contains_excluded), because a
# directory is restored wholesale and putting an ancestor back would take that directory with
# it. Enrolment is refused there, so the caller does not write; a plain copy of such a path is
# still allowed, it just is not this mechanism's to restore.
#
# No `set` here on purpose: this file is sourced, and changing the caller's shell options
# behind its back (e.g. dropping its `set -e`) would be a bug in every caller at once.

# The one decision about where configuration lives (xdg-config.sh). Both the RP_EXCLUDE
# boundary and the `~` expansion below are answers to "which directory is that, really?",
# and answering it differently from the scripts that WRITE there is how a backup ends up
# taken from one directory while another is overwritten. Sourced by ${BASH_SOURCE[0]}, not
# $0: this file is a library and $0 is whoever sourced it.
if [ -z "${RP_XDG_LIB:-}" ]; then
    RP_XDG_LIB=""
    for _rp_x in "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/xdg-config.sh" \
                 "${CLAUDE_PLUGIN_ROOT:-}/scripts/xdg-config.sh"; do
        if [ -n "$_rp_x" ] && [ -f "$_rp_x" ]; then RP_XDG_LIB="$_rp_x"; break; fi
    done
    if [ -n "$RP_XDG_LIB" ]; then
        # shellcheck source=xdg-config.sh
        . "$RP_XDG_LIB"
    fi
    unset _rp_x
fi

RP_LAST_ERROR=""    # why the last rp_protect refused (empty on success)
RP_LAST_STATE=""    # file | new | covered | already-{file,new,covered} | excluded | contains-excluded
RP_LAST_BACKUP=""   # the sidecar holding the prior content (empty when there was none)
RP_LAST_ID=""       # the apply id the last rp_protect enrolled under
RP_LAST_COVER=""    # for a `covered` state: the enrolled surface that holds the prior content

# Where this plugin's durable per-machine state lives - the base every state surface hangs off
# (restore points, the install record, the browser-preference record). One answer, in one place,
# for the same reason xdg-config.sh is the one answer for configuration: a second script spelling
# its own `$HOME/.local/state` is how a record gets written where nothing later reads it.
# $XDG_STATE_HOME is the XDG base directory for state, and `$HOME/.local/state` is the default
# the specification names when it is unset or empty.
rp_state_root() {
    printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/hypr-rice"
}

# Where restore points live.
rp_state_dir() {
    if [ -n "${RICE_RESTORE_DIR:-}" ]; then
        printf '%s\n' "${RICE_RESTORE_DIR%/}"
    else
        printf '%s/restore\n' "$(rp_state_root)"
    fi
}

# Expand a leading ~ the way the rest of the engine does - which now means routing a
# `~/.config/...` path through the shared config base, so the path enrolled here is
# byte-for-byte the path the render pass writes.
rp_expand() {
    local p="${1:-}"
    if command -v xdg_expand_path >/dev/null 2>&1; then
        xdg_expand_path "$p"
        return 0
    fi
    case "$p" in "~"*) p="${HOME:-}${p#\~}" ;; esac
    printf '%s\n' "$p"
}

# RP_EXCLUDE: the one directory this mechanism must never enrol, restore, or report on. Its
# backup/restore is somebody else's contract and this file neither reads nor invokes it.
# It has to be the SAME directory install-config.sh / reset-config.sh write to; resolving it
# any other way would quietly re-open the boundary for a user who moved XDG_CONFIG_HOME.
rp_excluded_dir() {
    local d
    if command -v xdg_config_path >/dev/null 2>&1; then
        d="$(xdg_config_path hypr "${HYPR_DIR:-}")" || d="${HYPR_DIR:-${HOME:-}/.config/hypr}"   # RP_EXCLUDE  XDG-OK: fallback only
    else
        d="${HYPR_DIR:-${HOME:-}/.config/hypr}"   # RP_EXCLUDE  XDG-OK: library absent, legacy answer
    fi
    rp_canon "$d"   # RP_EXCLUDE
}

# True for any path inside the excluded dir. Those paths are out of this mechanism's scope
# entirely - never backed up here, never enrolled, never restored here, never reported on.
rp_excluded() {
    local p d
    p="$(rp_canon "$(rp_expand "${1:-}")")"
    d="$(rp_excluded_dir)"
    case "$p" in
        "$d"|"$d"/*) return 0 ;;
    esac
    return 1
}

# True when the excluded dir sits INSIDE this path. Containment cuts both ways and the guard has
# to answer both questions: rp_excluded asks "is this path inside it?", this one asks "does this
# path swallow it?". A directory is restored wholesale (rm -rf + cp -a), so putting an ancestor of
# the excluded dir back would revert that directory too - the one thing no restore here may do.
# The test is lexical, like rp_excluded's: it holds whether or not that directory exists yet.
rp_contains_excluded() {
    local p d
    p="$(rp_canon "$(rp_expand "${1:-}")")"
    [ -n "$p" ] || return 1
    d="$(rp_excluded_dir)"
    if [ "$p" = "/" ]; then
        case "$d" in /?*) return 0 ;; esac
        return 1
    fi
    case "$d" in
        "$p"/*) return 0 ;;
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

# Strip trailing slashes so `~/.config/waybar/` and `~/.config/waybar` are one path. Containment
# is decided by string prefix, so the ledger has to be canonical about this.
rp_canon() {
    local p="${1:-}"
    while [ "${#p}" -gt 1 ] && [ "${p%/}" != "$p" ]; do p="${p%/}"; done
    printf '%s\n' "$p"
}

# Print the kind recorded for a target in one entries file; non-zero when it is not enrolled.
rp_entry_kind() {
    local f="${1:-}" t="${2:-}"
    [ -f "$f" ] || return 1
    awk -F'\t' -v t="$t" '$2 == t { print $1; found = 1; exit } END { exit !found }' "$f"
}

# Print the surface a `covered` entry folds into; non-zero when there is no such entry.
rp_entry_cover() {
    local f="${1:-}" t="${2:-}"
    [ -f "$f" ] || return 1
    awk -F'\t' -v t="$t" '$1 == "covered" && $2 == t { print $3; found = 1; exit } END { exit !found }' "$f"
}

# Print the deepest already-enrolled surface that strictly CONTAINS <target>, if any. `covered`
# entries are never answers: they hold no backup of their own, so folding into one would fold
# into nothing. The deepest real container is the one whose backup is closest in time to this
# write, and it is the one the restore replays immediately before this path.
rp_enrolled_ancestor() {
    local f="${1:-}" t="${2:-}"
    [ -f "$f" ] || return 1
    awk -F'\t' -v t="$t" '
        $1 == "covered" { next }
        NF >= 2 {
            a = $2
            sub(/\/+$/, "", a)
            if (a != "" && index(t, a "/") == 1 && length(a) > length(best)) best = a
        }
        END { if (best != "") { print best; exit 0 } exit 1 }
    ' "$f"
}

# Drop the done-marks of everything nested inside <parent>. A surface restored wholesale replaces
# its whole content, so anything inside it that an earlier (interrupted or partial) attempt had
# already put back has just been overwritten and must be replayed.
rp_unmark_below() {
    local dir="${1:-}" parent="${2:-}" tmpf
    [ -n "$dir" ] && [ -n "$parent" ] || return 1
    [ -f "$dir/done.tsv" ] || return 0
    parent="$(rp_canon "$parent")"
    tmpf="$dir/done.tsv.$$"
    awk -v p="$parent/" 'index($0, p) != 1' "$dir/done.tsv" > "$tmpf" 2>/dev/null || { rm -f "$tmpf"; return 1; }
    mv -f "$tmpf" "$dir/done.tsv" 2>/dev/null || { rm -f "$tmpf"; return 1; }
}

# Replay order for one entries file: a surface always comes BEFORE anything enrolled inside it.
# Depth (the number of '/' in the target) decides that on its own - a container always has fewer
# path components than what it contains - and entries at equal depth keep their enrolment order,
# so an apply's own write order is otherwise untouched.
rp_replay_order() {
    local f="${1:-}"
    [ -f "$f" ] || return 1
    awk -F'\t' 'BEGIN { OFS = "\t" } NF { t = $2; n = gsub(/\//, "/", t); print n, NR, $0 }' "$f" \
        | sort -k1,1n -k2,2n | cut -f3-
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
    local target backup id dir kind ancestor
    RP_LAST_ERROR=""; RP_LAST_STATE=""; RP_LAST_BACKUP=""; RP_LAST_ID=""; RP_LAST_COVER=""
    target="$(rp_canon "$(rp_expand "${1:-}")")"
    if [ -z "$target" ]; then
        RP_LAST_ERROR="empty path"
        return 1
    fi
    if rp_excluded "$target"; then
        RP_LAST_STATE="excluded"
        return 0
    fi
    if rp_contains_excluded "$target"; then
        # The excluded dir sits inside this path, so restoring it would replace that directory
        # wholesale along with everything else - the one thing this mechanism never does. There is
        # no way back from this write that respects that boundary, so there is no write: the same
        # fail-safe the caller applies to a backup that cannot be taken. (A plain COPY of such a
        # path is still fine and scripts/backup-path.sh still takes one - a copy touches nothing;
        # what is refused is making this mechanism responsible for putting it back.)
        RP_LAST_ERROR="refusing to enrol a path that contains a surface with its own separate restore"
        RP_LAST_STATE="contains-excluded"
        return 1
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
        case "$kind" in
            file)    RP_LAST_BACKUP="${target%/}.bak.${id}" ;;
            covered) RP_LAST_COVER="$(rp_entry_cover "$dir/entries.tsv" "$target")" || RP_LAST_COVER="" ;;
        esac
        return 0
    fi
    ancestor="$(rp_enrolled_ancestor "$dir/entries.tsv" "$target")" || ancestor=""
    if [ -n "$ancestor" ]; then
        # This path sits inside a surface already enrolled in this apply. That surface was copied
        # before this apply wrote anything under it, so its backup already holds this path's prior
        # content - and a sidecar written here would live INSIDE the surface a restore replaces
        # wholesale, which is exactly how it would be destroyed. Fold into the surface instead:
        # the entry records what holds the prior content, and the restore replays the surface
        # first. Failing to persist THAT is as fatal as a failed copy, for the same reason the
        # `new` branch below is: the caller must not write what nothing can take back.
        if ! rp_append "$dir" covered "$target" "$ancestor"; then
            RP_LAST_ERROR="restore point entry could not be written: $dir/entries.tsv"
            return 1
        fi
        RP_LAST_STATE="covered"
        RP_LAST_COVER="$ancestor"
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
        help|-h|--help) sed -n '2,23p' "$0" ;;
        *) echo "unknown command: $_rp_cmd (try: restore-point.sh help)" >&2; exit 2 ;;
    esac
fi

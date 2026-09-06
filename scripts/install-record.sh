#!/usr/bin/env bash
# The install record: what this plugin put on the machine, left ON the machine.
#
# A package install is the one thing this plugin does that a config restore cannot undo - the
# packages stay. Until now the only account of a transaction was a verdict line in a chat
# transcript, which is gone the moment the session is. This file is the durable half: every
# transaction leaves a record naming every package installed, every one already present, every
# one that failed (with the one-line reason the install reported) and every AUR helper built
# from source, and the user can read it back later without knowing where it is stored.
#
# It records. It never installs and never removes anything: what to do about what is in the
# record is the user's call.
#
# Usage:
#   install-record.sh record [--route <name>] [--helper <name>] [--label <text>]
#                                     read a transaction on stdin and persist it
#   install-record.sh list            list the recorded transactions, newest first
#   install-record.sh show <id>       print one recorded transaction in full
#   install-record.sh where           print the directory the records live in
#
# `record` reads TAB-separated lines on stdin:
#   <status> <tab> <package> [<tab> <origin> [<tab> <note>]]
# status is one of:
#   installed           this transaction installed it
#   present             it was already there and was left alone
#   failed              it did not install; <note> carries the one-line reason
#   built-from-source   built here from source rather than installed from a repository;
#                       <origin> is the URL it was cloned from
# origin is `repo`, `aur`, a URL, or empty. Unknown statuses are reported and dropped.
#
# Output (stdout, this repo's KEY=value convention):
#   the whole transaction, one line per package, always - whether or not it could be persisted
#   INSTALL_RECORD=<path>       the file it was written to     (only when it really was)
#   INSTALL_RECORD_ID=<id>      the identifier `show` takes    (only when it really was)
#   INSTALL_RECORD=unwritten    when the record could not be written; the failure and the path
#                               it tried are on stderr, and the install is NOT reported recorded
#   INSTALL_RECORD=empty        nothing was installed, already present or failed, so there was
#                               no transaction to record and nothing was written
#
# Exit codes:
#   0  recorded (or nothing to record)
#   2  usage error
#   3  `show` was given an identifier with no record
#   5  there was a transaction but it could not be written where it belongs
#
# Env:
#   RICE_INSTALL_RECORD_DIR  where records live (default <state root>/installs, the state root
#                            being the one restore-point.sh resolves - see rp_state_root)
#
# No `set` at the top on purpose: this file is both a CLI and a library other scripts source,
# and changing a caller's shell options behind its back would be a bug in every caller at once.

# The one answer to "where does durable per-machine state live?" (scripts/restore-point.sh).
# Resolving it here instead would re-open exactly the split xdg-config.sh exists to prevent,
# one directory down.
if [ -z "${IR_RP_LIB:-}" ]; then
    IR_RP_LIB=""
    for _ir_c in "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/restore-point.sh" \
                 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../../scripts/restore-point.sh" \
                 "${CLAUDE_PLUGIN_ROOT:-}/scripts/restore-point.sh"; do
        if [ -n "$_ir_c" ] && [ -f "$_ir_c" ]; then IR_RP_LIB="$_ir_c"; break; fi
    done
    if [ -n "$IR_RP_LIB" ]; then
        # shellcheck source=restore-point.sh
        . "$IR_RP_LIB"
    fi
    unset _ir_c
fi

IR_LAST_ERROR=""   # why the last ir_write refused (empty on success)
IR_LAST_PATH=""    # the file it wrote, or the one it could not write
IR_LAST_ID=""      # the identifier of the record it wrote

# Where install records live.
ir_state_dir() {
    if [ -n "${RICE_INSTALL_RECORD_DIR:-}" ]; then
        printf '%s\n' "${RICE_INSTALL_RECORD_DIR%/}"
    elif command -v rp_state_root >/dev/null 2>&1; then
        printf '%s/installs\n' "$(rp_state_root)"
    else
        # Library absent (a partial install): the same answer, spelled once, as a last resort.
        printf '%s\n' "${XDG_STATE_HOME:-${HOME:-}/.local/state}/hypr-rice/installs"
    fi
}

# A fresh record id: the timestamp, suffixed if one already exists for that second.
ir_new_id() {
    local base cand store n
    base="$(date +%Y%m%d-%H%M%S)" || return 1
    store="$(ir_state_dir)"
    cand="$base"
    n=1
    while [ -e "$store/$cand.tsv" ] && [ "$n" -lt 100 ]; do
        cand="${base}-${n}"
        n=$((n + 1))
    done
    printf '%s\n' "$cand"
}

ir_is_status() {
    case "${1:-}" in
        installed|present|failed|built-from-source) return 0 ;;
    esac
    return 1
}

# `ir_human <status> <package> <origin> <note>` - one transaction line, for a person.
ir_human() {
    local status="${1:-}" pkg="${2:-}" origin="${3:-}" note="${4:-}" tail=""
    case "$status" in
        built-from-source)
            tail=" (built from source"
            [ -n "$origin" ] && tail="$tail from $origin"
            tail="$tail)"
            ;;
        *)
            [ -n "$origin" ] && [ "$origin" != "-" ] && tail=" ($origin)"
            ;;
    esac
    if [ -n "$note" ] && [ "$note" != "-" ] && [ "$status" != "built-from-source" ]; then
        tail="$tail: $note"
    fi
    printf '  %-18s %s%s\n' "$status" "$pkg" "$tail"
}

# `ir_summary_line <file>` - the counts, from a record file or a transaction body.
ir_summary_line() {
    awk -F'\t' '
        /^#/ { next }
        NF < 2 { next }
        { n++ }
        $1 == "installed"         { i++ }
        $1 == "present"           { p++ }
        $1 == "failed"            { f++ }
        $1 == "built-from-source" { b++ }
        END {
            printf "%d package(s): %d installed, %d already present, %d failed, %d built from source\n",
                   n+0, i+0, p+0, f+0, b+0
        }
    ' "${1:-/dev/stdin}"
}

# `ir_print_transaction <body-file> <route> <helper>` - the whole transaction, for a person.
# This is printed whether or not the record could be persisted: a transaction the user cannot
# read anywhere is the failure this file exists to end.
ir_print_transaction() {
    local body="${1:-}" route="${2:-}" helper="${3:-}" status pkg origin note
    printf '=== install transaction (route: %s, helper: %s) ===\n' "${route:-unknown}" "${helper:-none}"
    while IFS=$'\t' read -r status pkg origin note; do
        [ -n "${status:-}" ] || continue
        case "$status" in \#*) continue ;; esac
        ir_human "$status" "${pkg:-}" "${origin:-}" "${note:-}"
    done < "$body"
    printf '=== %s ===\n' "$(ir_summary_line "$body")"
}

# `ir_write <body-file> <route> <helper> <label>` - persist one transaction. Returns non-zero
# with IR_LAST_ERROR set when it could not be written; the caller reports that and must NOT
# claim the install was recorded.
ir_write() {
    local body="${1:-}" route="${2:-}" helper="${3:-}" label="${4:-}"
    local store id dest tmp
    IR_LAST_ERROR=""; IR_LAST_PATH=""; IR_LAST_ID=""
    store="$(ir_state_dir)"
    if [ -z "$store" ]; then
        IR_LAST_ERROR="cannot determine where install records live (no XDG_STATE_HOME and no HOME)"
        return 1
    fi
    if ! mkdir -p "$store" 2>/dev/null; then
        IR_LAST_PATH="$store"
        IR_LAST_ERROR="the install record directory could not be created"
        return 1
    fi
    id="$(ir_new_id)" || { IR_LAST_PATH="$store"; IR_LAST_ERROR="could not mint a record identifier"; return 1; }
    dest="$store/$id.tsv"
    IR_LAST_PATH="$dest"
    tmp="$store/.$id.$$.tmp"
    {
        printf '# hypr-rice install record\n'
        printf '# id\t%s\n' "$id"
        printf '# when\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
        printf '# route\t%s\n' "${route:-unknown}"
        printf '# helper\t%s\n' "${helper:-none}"
        [ -n "$label" ] && printf '# label\t%s\n' "$label"
        cat "$body"
    } > "$tmp" 2>/dev/null || {
        rm -f "$tmp" 2>/dev/null
        IR_LAST_ERROR="the record could not be written"
        return 1
    }
    if ! mv -f "$tmp" "$dest" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null
        IR_LAST_ERROR="the record could not be written"
        return 1
    fi
    IR_LAST_ID="$id"
    return 0
}

# `ir_list` - every recorded transaction, newest first. Says so plainly when there are none.
ir_list() {
    local store f id found=0
    store="$(ir_state_dir)"
    if [ -d "$store" ]; then
        while IFS= read -r f; do
            [ -s "$f" ] || continue
            id="$(basename "$f" .tsv)"
            printf '%s\t%s\t%s\n' "$id" "$(ir_summary_line "$f")" \
                "route=$(sed -n 's/^# route\t//p' "$f" | head -n1)"
            found=1
        done < <(find "$store" -mindepth 1 -maxdepth 1 -name '*.tsv' -type f 2>/dev/null | sort -r)
    fi
    if [ "$found" -eq 0 ]; then
        echo "(no install has been recorded yet, under $store)"
    fi
    return 0
}

# `ir_show <id>` - one recorded transaction in full.
ir_show() {
    local id="${1:-}" store f route helper
    store="$(ir_state_dir)"
    case "$id" in
        ''|*/*|.*) return 2 ;;
    esac
    f="$store/$id.tsv"
    [ -s "$f" ] || return 3
    route="$(sed -n 's/^# route\t//p' "$f" | head -n1)"
    helper="$(sed -n 's/^# helper\t//p' "$f" | head -n1)"
    printf 'INSTALL_RECORD=%s\n' "$f"
    printf 'INSTALL_RECORD_ID=%s\n' "$id"
    printf 'WHEN=%s\n' "$(sed -n 's/^# when\t//p' "$f" | head -n1)"
    ir_print_transaction "$f" "$route" "$helper"
    return 0
}

# --- CLI (only when run, never when sourced) -------------------------------------------------
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -uo pipefail
    _ir_cmd="${1:-help}"; shift 2>/dev/null || true
    case "$_ir_cmd" in
        where) ir_state_dir ;;
        list)  ir_list ;;
        show)
            ir_show "${1:-}"; _ir_rc=$?
            if [ "$_ir_rc" -eq 3 ]; then
                echo "(no install record '${1:-}' under $(ir_state_dir))" >&2
                exit 3
            elif [ "$_ir_rc" -ne 0 ]; then
                echo "ERROR: usage: install-record.sh show <id>  (see: install-record.sh list)" >&2
                exit 2
            fi
            ;;
        record)
            _ir_route=""; _ir_helper=""; _ir_label=""
            while [ "$#" -gt 0 ]; do
                _ir_opt="$1"; shift
                case "$_ir_opt" in
                    --route)  _ir_route="${1:-}";  [ "$#" -gt 0 ] && shift ;;
                    --helper) _ir_helper="${1:-}"; [ "$#" -gt 0 ] && shift ;;
                    --label)  _ir_label="${1:-}";  [ "$#" -gt 0 ] && shift ;;
                    *) echo "ERROR: unknown option '$_ir_opt' (usage: install-record.sh record [--route N] [--helper N] [--label T])" >&2; exit 2 ;;
                esac
            done
            _ir_body="$(mktemp "${TMPDIR:-/tmp}/hypr-rice-txn.XXXXXX")" || {
                echo "ERROR: could not stage the transaction (no writable temporary directory)" >&2
                exit 5
            }
            _ir_n=0
            while IFS=$'\t' read -r _s _p _o _n; do
                [ -n "${_s:-}" ] || continue
                case "$_s" in \#*) continue ;; esac
                if ! ir_is_status "$_s"; then
                    printf 'INSTALL_RECORD_DROPPED=%s (unknown status; expected installed|present|failed|built-from-source)\n' "$_s" >&2
                    continue
                fi
                if [ -z "${_p:-}" ]; then
                    printf 'INSTALL_RECORD_DROPPED=%s (no package name)\n' "$_s" >&2
                    continue
                fi
                printf '%s\t%s\t%s\t%s\n' "$_s" "$_p" "${_o:-}" "${_n:-}" >> "$_ir_body"
                _ir_n=$((_ir_n + 1))
            done
            if [ "$_ir_n" -eq 0 ]; then
                # No package was installed, already present or failed. There was no transaction,
                # so there is no record: a record claiming one would be an invented history.
                echo "INSTALL_RECORD=empty (no package was installed, already present or failed; nothing was recorded)"
                rm -f "$_ir_body"
                exit 0
            fi
            ir_print_transaction "$_ir_body" "$_ir_route" "$_ir_helper"
            if ir_write "$_ir_body" "$_ir_route" "$_ir_helper" "$_ir_label"; then
                printf 'INSTALL_RECORD=%s\n' "$IR_LAST_PATH"
                printf 'INSTALL_RECORD_ID=%s\n' "$IR_LAST_ID"
                rm -f "$_ir_body"
                exit 0
            fi
            printf 'INSTALL_RECORD_FAILED=%s (%s)\n' "${IR_LAST_PATH:-$(ir_state_dir)}" "$IR_LAST_ERROR" >&2
            printf 'ERROR: the transaction above was NOT recorded - it is printed here and nowhere else.\n' >&2
            echo "INSTALL_RECORD=unwritten"
            rm -f "$_ir_body"
            exit 5
            ;;
        help|-h|--help) sed -n '2,45p' "$0" ;;
        *) echo "unknown command: $_ir_cmd (try: install-record.sh help)" >&2; exit 2 ;;
    esac
fi

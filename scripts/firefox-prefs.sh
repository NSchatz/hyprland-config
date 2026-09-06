#!/usr/bin/env bash
# The browser-preference record, and the supported way to take those preferences back off.
#
# A preference merged into `<profile>/user.js` is not like the rest of what this plugin writes:
# Firefox re-applies it at EVERY start, and the browser's own UI will not show it as changed, so
# a config restore does not undo it and there is nothing in the interface to undo it with. The
# only way back is to edit that file. This records exactly which lines this plugin put there, in
# which profile, and removes exactly those lines again on request.
#
# Usage:
#   firefox-prefs.sh list                what this plugin set, and where; whether it is still set
#   firefox-prefs.sh record <profile> <user_pref line>
#                                        record one preference line as set (the bootstrap's call)
#   firefox-prefs.sh remove [<profile>]  remove the recorded preferences again, all profiles or one
#   firefox-prefs.sh where               print the record's path
#
# What `remove` guarantees, because the file it edits may be one the user has since made their
# own:
#   * it copies the file to a restorable backup BEFORE editing it, enrolled in a restore point,
#     so the edit itself goes back with `rice restore <apply-id>`; a file it cannot back up is
#     not edited at all;
#   * it removes ONLY the lines the record names for that profile, byte-for-byte; every other
#     line of that file is left exactly as it was;
#   * a recorded preference whose line has been changed by hand since is LEFT ALONE and reported
#     as changed - deleting a value the user chose is not this script's to do;
#   * a profile file that is no longer there is reported by path, never created, and never stops
#     the other profiles from being handled.
#
# Removing `toolkit.legacyUserProfileCustomizations.stylesheets` turns off Firefox's processing
# of userChrome.css, which is the whole of this plugin's browser theming: the chrome goes back to
# the browser's default look. That is why removal is a documented command and not something the
# plugin does on its own.
#
# Output (stdout, this repo's KEY=value convention):
#   PREF_REMOVED=<file> <key>          that line was removed
#   PREF_CHANGED=<file> <key>          changed by hand since; left alone
#   PREFS_MISSING=<file>               recorded, but the file is not there; nothing was created
#   PREFS_NOTHING=<file>               nothing recorded is still set there; the file was untouched
#   PREFS_SKIPPED=<file> (<why>)       could not be backed up, so it was NOT edited
#   RESTORE_POINT=<apply-id>           undo the removal itself: rice restore <apply-id>
#   PREFS=removed:<n> changed:<n> missing:<n> untouched:<n>
#
# Exit codes:
#   0  the run completed (including reported skips)
#   1  a profile file could not be backed up, so it was not edited
#   2  usage error, or the restore-point library is missing
#   3  nothing is recorded (a second `remove` reports this: there is nothing left to remove)
#
# Env:
#   RICE_PREF_RECORD  the record file (default <state root>/browser-prefs.tsv)
#
# No `set` at the top on purpose: this file is both a CLI and a library the Firefox bootstrap
# sources, and changing a caller's shell options behind its back would be a bug in every caller.

# The restore-point library answers both "where does durable state live?" (rp_state_root) and
# "how is a file backed up before it is edited?" (rp_protect). Resolving either here would be a
# second answer to a question this plugin decided once.
if [ -z "${FP_RP_LIB:-}" ]; then
    FP_RP_LIB=""
    for _fp_c in "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/restore-point.sh" \
                 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../../scripts/restore-point.sh" \
                 "${CLAUDE_PLUGIN_ROOT:-}/scripts/restore-point.sh"; do
        if [ -n "$_fp_c" ] && [ -f "$_fp_c" ]; then FP_RP_LIB="$_fp_c"; break; fi
    done
    if [ -n "$FP_RP_LIB" ]; then
        # shellcheck source=restore-point.sh
        . "$FP_RP_LIB"
    fi
    unset _fp_c
fi

FP_LAST_ERROR=""

# Where the record lives.
fp_record_file() {
    if [ -n "${RICE_PREF_RECORD:-}" ]; then
        printf '%s\n' "$RICE_PREF_RECORD"
    elif command -v rp_state_root >/dev/null 2>&1; then
        printf '%s/browser-prefs.tsv\n' "$(rp_state_root)"
    else
        printf '%s\n' "${XDG_STATE_HOME:-${HOME:-}/.local/state}/hypr-rice/browser-prefs.tsv"
    fi
}

# `fp_pref_key <user_pref line>` - the preference key a `user_pref("key", value);` line sets.
fp_pref_key() {
    printf '%s' "${1:-}" | sed -n 's/^[[:space:]]*user_pref("\([^"]*\)".*$/\1/p'
}

# `fp_record <profile> <line>` - record one preference as set in one profile. Idempotent: the
# same profile+key is recorded once. Returns non-zero (FP_LAST_ERROR set) when the record could
# not be written, which is a caller's cue NOT to set the preference.
fp_record() {
    local profile="${1:-}" line="${2:-}" key f dir
    FP_LAST_ERROR=""
    key="$(fp_pref_key "$line")"
    if [ -z "$profile" ] || [ -z "$key" ]; then
        FP_LAST_ERROR="a preference record needs a profile path and a user_pref line"
        return 1
    fi
    # TABs are the record's field separator; a pref line has none, but never trust that.
    line="$(printf '%s' "$line" | tr -d '\t')"
    f="$(fp_record_file)"
    dir="$(dirname "$f")"
    if ! mkdir -p "$dir" 2>/dev/null; then
        FP_LAST_ERROR="the preference record directory could not be created: $dir"
        return 1
    fi
    if [ -f "$f" ] && awk -F'\t' -v p="$profile" -v k="$key" '$1 == p && $2 == k { found = 1 } END { exit !found }' "$f"; then
        return 0
    fi
    if ! printf '%s\t%s\t%s\t%s\n' "$profile" "$key" "$line" \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)" >> "$f" 2>/dev/null; then
        FP_LAST_ERROR="the preference record could not be written: $f"
        return 1
    fi
    return 0
}

# `fp_list` - what is recorded, and whether it is still set.
fp_list() {
    local f profile key line state target found=0
    f="$(fp_record_file)"
    if [ ! -s "$f" ]; then
        echo "(no browser preference is recorded under $f)"
        return 0
    fi
    while IFS=$'\t' read -r profile key line _when; do
        [ -n "${profile:-}" ] || continue
        target="$profile/user.js"
        if [ ! -f "$target" ]; then
            state="profile file missing"
        elif grep -Fxq -- "$line" "$target" 2>/dev/null; then
            state="still set"
        elif grep -qF -- "user_pref(\"$key\"" "$target" 2>/dev/null; then
            state="changed by hand"
        else
            state="already removed"
        fi
        printf '%s\t%s\t%s\n' "$target" "$key" "$state"
        found=1
    done < "$f"
    [ "$found" -eq 1 ] || echo "(no browser preference is recorded under $f)"
    return 0
}

# `fp_remove [profile]` - the documented removal path.
fp_remove() {
    local only="${1:-}" f profiles p target line key
    local removed=0 changed=0 missing=0 untouched=0 skipped=0 edited=0
    f="$(fp_record_file)"
    if [ ! -s "$f" ]; then
        echo "PREFS=nothing-to-remove (no browser preference is recorded under $f: this plugin has set none, or they have already been removed)"
        return 3
    fi
    if ! command -v rp_protect >/dev/null 2>&1; then
        echo "ERROR: the restore-point library was not found, so no file could be backed up before editing. Refusing to edit a profile with no way back - re-run rice-init.sh." >&2
        return 2
    fi

    # Profiles in the order they were recorded, de-duplicated.
    mapfile -t profiles < <(awk -F'\t' -v only="$only" '
        NF >= 3 && (only == "" || $1 == only) { if (!seen[$1]++) print $1 }' "$f")
    if [ "${#profiles[@]}" -eq 0 ]; then
        echo "PREFS=nothing-to-remove (nothing is recorded for ${only:-any profile} under $f)"
        return 3
    fi

    # Entries that survive this run: everything for a profile we are not touching, plus the
    # hand-changed lines we deliberately left alone.
    local keep; keep="$(mktemp "${TMPDIR:-/tmp}/hypr-rice-prefs.XXXXXX")" || {
        echo "ERROR: no writable temporary directory; refusing to edit a profile whose record cannot be updated." >&2
        return 1
    }
    if [ -n "$only" ]; then
        awk -F'\t' -v only="$only" '$1 != only' "$f" > "$keep" 2>/dev/null
    fi

    for p in "${profiles[@]}"; do
        target="$p/user.js"
        if [ ! -f "$target" ]; then
            # Recorded, but gone. Say so by path, create nothing, carry on with the rest - and
            # keep the record, because nothing was removed and that file may yet come back.
            printf 'PREFS_MISSING=%s (recorded, but that file is not there; nothing was created)\n' "$target"
            awk -F'\t' -v p="$p" '$1 == p' "$f" >> "$keep"
            missing=$((missing + 1))
            continue
        fi

        local to_remove staged
        to_remove="$(mktemp "${TMPDIR:-/tmp}/hypr-rice-prefs-rm.XXXXXX")" || continue
        staged="$(mktemp "${TMPDIR:-/tmp}/hypr-rice-prefs-st.XXXXXX")" || { rm -f "$to_remove"; continue; }
        local this_changed=0
        while IFS=$'\t' read -r rprofile key line _when; do
            [ "$rprofile" = "$p" ] || continue
            if grep -Fxq -- "$line" "$target" 2>/dev/null; then
                printf '%s\n' "$line" >> "$to_remove"
                printf '%s\t%s\t%s\t%s\n' "$rprofile" "$key" "$line" "$_when" >> "$staged"
            elif grep -qF -- "user_pref(\"$key\"" "$target" 2>/dev/null; then
                # The key is still there but the line is not the one this plugin wrote: the user
                # changed the value. That value is theirs; report it, keep the record, move on.
                printf 'PREF_CHANGED=%s %s (changed by hand since this plugin set it; left alone)\n' "$target" "$key"
                printf '%s\t%s\t%s\t%s\n' "$rprofile" "$key" "$line" "$_when" >> "$keep"
                changed=$((changed + 1)); this_changed=1
            fi
            # Neither present nor changed: it is already gone, so it leaves the record.
        done < "$f"

        if [ ! -s "$to_remove" ]; then
            rm -f "$to_remove" "$staged"
            if [ "$this_changed" -eq 0 ]; then
                printf 'PREFS_NOTHING=%s (nothing this plugin recorded is still set there; the file was not touched)\n' "$target"
                untouched=$((untouched + 1))
            fi
            continue
        fi

        # Back up before editing, or do not edit. The same rule every writer in this plugin follows.
        if ! rp_protect "$target"; then
            printf 'PREFS_SKIPPED=%s (%s)\n' "$target" "$RP_LAST_ERROR"
            cat "$staged" >> "$keep"   # still set, so still recorded
            skipped=$((skipped + 1))
            rm -f "$to_remove" "$staged"
            continue
        fi

        local filtered
        filtered="$(mktemp "${TMPDIR:-/tmp}/hypr-rice-userjs.XXXXXX")" || { rm -f "$to_remove" "$staged"; continue; }
        # Exact whole-line matches only, so every other byte of the file survives untouched.
        if ! awk 'NR == FNR { drop[$0] = 1; next } !($0 in drop)' "$to_remove" "$target" > "$filtered" 2>/dev/null; then
            printf 'PREFS_SKIPPED=%s (the edited copy could not be written)\n' "$target"
            cat "$staged" >> "$keep"
            skipped=$((skipped + 1))
            rm -f "$to_remove" "$staged" "$filtered"
            continue
        fi
        # Write back through the existing file so its permissions and inode survive the edit.
        if ! cat "$filtered" > "$target" 2>/dev/null; then
            printf 'PREFS_SKIPPED=%s (the file could not be rewritten)\n' "$target"
            cat "$staged" >> "$keep"
            skipped=$((skipped + 1))
            rm -f "$to_remove" "$staged" "$filtered"
            continue
        fi
        while IFS= read -r line; do
            key="$(fp_pref_key "$line")"
            printf 'PREF_REMOVED=%s %s\n' "$target" "$key"
            removed=$((removed + 1))
        done < "$to_remove"
        edited=1
        rm -f "$to_remove" "$staged" "$filtered"
    done

    # Rewrite the record: what was removed is no longer set, so it is no longer recorded.
    if [ -s "$keep" ]; then
        cat "$keep" > "$f" 2>/dev/null
    else
        : > "$f" 2>/dev/null
    fi
    rm -f "$keep"

    [ "$edited" -eq 1 ] && [ -n "${RICE_APPLY_ID:-}" ] && printf 'RESTORE_POINT=%s\n' "$RICE_APPLY_ID"
    printf 'PREFS=removed:%d changed:%d missing:%d untouched:%d\n' "$removed" "$changed" "$missing" "$untouched"
    [ "$skipped" -gt 0 ] && return 1
    return 0
}

# --- CLI (only when run, never when sourced) -------------------------------------------------
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -uo pipefail
    _fp_cmd="${1:-help}"; shift 2>/dev/null || true
    case "$_fp_cmd" in
        where)  fp_record_file ;;
        list)   fp_list ;;
        record)
            if [ "$#" -lt 2 ]; then
                echo "ERROR: usage: firefox-prefs.sh record <profile> <user_pref line>" >&2
                exit 2
            fi
            if fp_record "$1" "$2"; then
                printf 'PREF_RECORDED=%s/user.js %s\n' "$1" "$(fp_pref_key "$2")"
            else
                printf 'PREF_RECORD_FAILED=%s (%s)\n' "$(fp_record_file)" "$FP_LAST_ERROR" >&2
                exit 1
            fi
            ;;
        remove) fp_remove "${1:-}"; exit $? ;;
        help|-h|--help) sed -n '2,45p' "$0" ;;
        *) echo "unknown command: $_fp_cmd (try: firefox-prefs.sh help)" >&2; exit 2 ;;
    esac
fi

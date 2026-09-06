#!/usr/bin/env bash
# The single restore command: put every file one apply wrote back the way it was, as one set.
#
# Usage:
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
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# Resolve $RICE_DIR the one way the plugin resolves it, so the last-resort lookup below
# still finds an engine a user installed under a moved XDG_CONFIG_HOME.
rice_dir="${RICE_DIR:-}"
if [ -z "$rice_dir" ] && [ -f "$here/xdg-config.sh" ]; then
    # shellcheck source=xdg-config.sh
    . "$here/xdg-config.sh"
    rice_dir="$(xdg_config_path hypr-rice)" || rice_dir="${HOME:-}/.config/hypr-rice"   # XDG-OK: fallback only
fi
[ -n "$rice_dir" ] || rice_dir="${HOME:-}/.config/hypr-rice"   # XDG-OK: library absent, legacy answer
lib=""
for c in "$here/restore-point.sh" \
         "$here/../scripts/restore-point.sh" \
         "${CLAUDE_PLUGIN_ROOT:-}/scripts/restore-point.sh" \
         "$rice_dir/restore-point.sh"; do
    if [ -n "$c" ] && [ -f "$c" ]; then lib="$c"; break; fi
done
if [ -z "$lib" ]; then
    echo "ERROR: restore-point library not found (looked next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, and in \$RICE_DIR)" >&2
    exit 2
fi
# shellcheck source=restore-point.sh
. "$lib"

id="${1:-}"
case "$id" in
    ''|-h|--help)
        sed -n '2,32p' "$0"
        exit 2
        ;;
    --list|list)
        rp_list
        exit 0
        ;;
    -*)
        echo "ERROR: unknown option '$id' (usage: rice-restore.sh <apply-id> | --list)" >&2
        exit 2
        ;;
esac

dir="$(rp_point_dir "$id")"
entries="$dir/entries.tsv"
if [ ! -s "$entries" ]; then
    echo "RESTORE=nothing-to-restore $id (no restore point under $(rp_state_dir): nothing was applied under that identifier, or it was already restored and the point cleared)"
    exit 3
fi

restored=0; removed=0; already=0; failed=0

while IFS=$'\t' read -r kind target backup; do
    [ -n "${kind:-}" ] || continue
    case "$kind" in \#*) continue ;; esac
    [ -n "${target:-}" ] || continue
    # Defence in depth: the recorder never enrols an out-of-scope path, and this skips one
    # silently rather than reporting on it if a ledger is ever hand-edited to contain one.
    if rp_excluded "$target"; then
        continue
    fi
    # The other direction of the same guard: a directory goes back wholesale, so putting a path
    # back that CONTAINS an out-of-scope surface would take that surface with it. The recorder
    # refuses to enrol such a path in the first place; this refuses to act on one if a ledger is
    # ever hand-edited to hold it, and says so by path rather than skipping it quietly.
    if rp_contains_excluded "$target"; then
        echo "RESTORE_FAILED $target (refusing: it contains a surface this command must never touch)"
        failed=$((failed + 1))
        continue
    fi
    if ! rp_safe_target "$target"; then
        echo "RESTORE_FAILED $target (refusing to touch that path)"
        failed=$((failed + 1))
        continue
    fi
    if rp_is_done "$dir" "$target"; then
        echo "ALREADY_RESTORED $target"
        already=$((already + 1))
        continue
    fi
    case "$kind" in
        file)
            if [ ! -e "$backup" ]; then
                echo "RESTORE_FAILED $target (backup missing: $backup)"
                failed=$((failed + 1))
                continue
            fi
            if [ ! -r "$backup" ]; then
                echo "RESTORE_FAILED $target (backup unreadable: $backup)"
                failed=$((failed + 1))
                continue
            fi
            mkdir -p "$(dirname "$target")" 2>/dev/null
            if [ -d "$backup" ]; then
                # Directory surface: replace it wholesale from the backup, so files the apply
                # added inside it go away too.
                rm -rf "$target" 2>/dev/null
            fi
            if err="$(cp -a "$backup" "$target" 2>&1)"; then
                echo "RESTORED $target"
                restored=$((restored + 1))
                # Wholesale replacement overwrote everything inside it, including anything an
                # earlier attempt had already put back. Those entries are replayed after this one
                # (container first), so their done-marks have to go.
                [ -d "$backup" ] && rp_unmark_below "$dir" "$target"
                rp_mark_done "$dir" "$target"
            else
                echo "RESTORE_FAILED $target (cannot write target: ${err##*cp: })"
                failed=$((failed + 1))
            fi
            ;;
        new)
            was_dir=0
            [ -d "$target" ] && [ ! -L "$target" ] && was_dir=1
            if [ ! -e "$target" ] && [ ! -L "$target" ]; then
                echo "REMOVED $target (already gone)"
                removed=$((removed + 1))
                rp_mark_done "$dir" "$target"
            elif err="$(rm -rf "$target" 2>&1)"; then
                echo "REMOVED $target"
                removed=$((removed + 1))
                [ "$was_dir" -eq 1 ] && rp_unmark_below "$dir" "$target"
                rp_mark_done "$dir" "$target"
            else
                echo "RESTORE_FAILED $target (cannot remove the file this apply created: ${err##*rm: })"
                failed=$((failed + 1))
            fi
            ;;
        covered)
            # Folded into an enclosing surface at enrolment time: that surface holds this path's
            # prior content and was replayed just above. Nothing to copy here - a nested backup
            # would have been destroyed by the wholesale replacement, which is why none was taken.
            if [ -n "${backup:-}" ] && rp_is_done "$dir" "$backup"; then
                if [ -e "$target" ] || [ -L "$target" ]; then
                    echo "RESTORED $target (with $backup)"
                    restored=$((restored + 1))
                else
                    echo "REMOVED $target (with $backup)"
                    removed=$((removed + 1))
                fi
                rp_mark_done "$dir" "$target"
            else
                echo "RESTORE_FAILED $target (the surface that holds it was not restored: ${backup:-unknown})"
                failed=$((failed + 1))
            fi
            ;;
        *)
            echo "RESTORE_FAILED $target (unknown restore-point entry kind '$kind')"
            failed=$((failed + 1))
            ;;
    esac
done < <(rp_replay_order "$entries")

if [ "$failed" -eq 0 ]; then
    rp_clear "$id"
    echo "RESTORE=done $id ($restored restored, $removed removed, $already already restored; restore point cleared)"
    exit 0
fi

echo "RESTORE=partial $id ($restored restored, $removed removed, $failed failed; restore point kept at $dir - fix the paths reported above and re-run: rice restore $id)"
exit 1

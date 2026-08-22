#!/usr/bin/env bash
# The single restore command: one apply, one identifier, everything that apply touched put back.
# Covers the round trip (AC2), a file the apply created being removed rather than orphaned
# (AC7), an identifier with no restore point (AC8), one damaged backup not aborting the rest
# (AC9), the point being cleared on success so a second restore reports nothing to restore
# (AC11), a restore interrupted partway being safely re-invocable to completion (AC12), and a
# target that cannot be written behaving like AC9's damaged backup rather than aborting the run
# (verdict-spec-2 F7).
#
# It also proves the boundary this item is fenced by: the restore command does not read, call,
# wrap, or duplicate the Hyprland config dir's own separate backup/restore, does not touch or
# report on anything under that directory, and neither does any test here - the assertions below
# read the restore point's own ledger and the command's own output, never that directory.

tmp="$(mktemp_test_dir restore-command)"
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

export HOME="$tmp"
export RICE_DIR="$HOME/.config/hypr-rice"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
export RICE_RESTORE_DIR="$tmp/state/restore"
unset RICE_APPLY_ID

RESTORE="$PLUGIN_ROOT/scripts/rice-restore.sh"
bash "$PLUGIN_ROOT/skills/rice/scripts/rice-init.sh" >/dev/null 2>&1

# A small manifest so every surface in the apply is known by name.
mkdir -p "$tmp/tpl" "$tmp/orig" "$HOME/.config/app1" "$HOME/.config/app2" "$HOME/.config/app3"
printf 'accent={{accent}}\n' > "$tmp/tpl/x.tmpl"
printf 'accent=ff0000\n'     > "$tmp/pal.conf"
{
    printf 'app1\t%s/tpl/x.tmpl\t%s/.config/app1/colors.conf\t\n' "$tmp" "$HOME"
    printf 'app2\t%s/tpl/x.tmpl\t%s/.config/app2/colors.conf\t\n' "$tmp" "$HOME"
    printf 'app3\t%s/tpl/x.tmpl\t%s/.config/app3/colors.conf\t\n' "$tmp" "$HOME"
    printf 'made\t%s/tpl/x.tmpl\t%s/.config/app4/created.conf\t\n' "$tmp" "$HOME"
} > "$tmp/manifest.list"

seed_apply() {   # seed_apply <apply-id>: three known-content files + one path that does not exist
    local id="$1" n
    for n in 1 2 3; do
        printf 'ORIGINAL app%s content\n' "$n" > "$HOME/.config/app$n/colors.conf"
        cp -a "$HOME/.config/app$n/colors.conf" "$tmp/orig/app$n"
    done
    rm -rf "$HOME/.config/app4"
    RICE_APPLY_ID="$id" bash "$RICE_DIR/render-templates.sh" --no-reload "$tmp/pal.conf" "$tmp/manifest.list" >/dev/null 2>&1
}

# --- AC2 / AC7 / AC11: the round trip -------------------------------------------------------
seed_apply apply-round
assert_eq "accent=ff0000" "$(cat "$HOME/.config/app1/colors.conf")" "the apply overwrote the surfaces (precondition)"
assert_file_exists "$HOME/.config/app4/created.conf" "the apply created a file where nothing existed (precondition)"

rout="$(bash "$RESTORE" apply-round 2>&1)"; rrc=$?
assert_eq "0" "$rrc" "AC2: a successful restore exits 0"
same=1
for n in 1 2 3; do
    cmp -s "$HOME/.config/app$n/colors.conf" "$tmp/orig/app$n" || same=0
done
if [ "$same" -eq 1 ]; then
    pass "AC2: every covered surface the apply touched is byte-identical to its prior state"
else
    fail "AC2: every covered surface the apply touched is byte-identical to its prior state" "$rout"
fi
if [ ! -e "$HOME/.config/app4/created.conf" ]; then
    pass "AC7: the file the apply created where nothing existed is removed, not orphaned"
else
    fail "AC7: the file the apply created where nothing existed is removed" "$rout"
fi
if printf '%s\n' "$rout" | grep -q '^RESTORE=done apply-round'; then
    pass "AC2: the restore reports what it did (RESTORE=done)"
else
    fail "AC2: the restore reports what it did" "$rout"
fi

# AC2 boundary: the apply's own restore point is the only thing this command reads, and it says
# nothing at all about the directory this item never covers.
excluded_dir="$HOME/.config/hypr"                                                    # RP_EXCLUDE
if printf '%s\n' "$rout" | grep -qF "$excluded_dir/"; then                           # RP_EXCLUDE
    fail "AC2: the restore command reports on no file in the excluded directory" "$rout"
else
    pass "AC2: the restore command reported on no file under the Hyprland config dir"
fi

# --- AC11 / AC8: cleared on success, so a second restore has nothing to do ------------------
if [ ! -d "$RICE_RESTORE_DIR/apply-round" ]; then
    pass "AC11: a successful restore clears the restore point"
else
    fail "AC11: a successful restore clears the restore point" "$RICE_RESTORE_DIR/apply-round still exists"
fi
again="$(bash "$RESTORE" apply-round 2>&1)"; arc=$?
assert_eq "3" "$arc" "AC8/AC11: restoring the same identifier again is not a success"
if printf '%s\n' "$again" | grep -q '^RESTORE=nothing-to-restore apply-round'; then
    pass "AC8/AC11: the second restore says there is nothing to restore for that apply"
else
    fail "AC8/AC11: the second restore says there is nothing to restore" "$again"
fi
if cmp -s "$HOME/.config/app1/colors.conf" "$tmp/orig/app1"; then
    pass "AC11: the second restore changed nothing on disk"
else
    fail "AC11: the second restore changed nothing on disk" "app1 differs from its prior state"
fi

# --- AC8: an identifier nothing was ever applied under --------------------------------------
never="$(bash "$RESTORE" never-applied-at-all 2>&1)"; nrc=$?
assert_eq "3" "$nrc" "AC8: an unknown apply identifier is not reported as success"
if printf '%s\n' "$never" | grep -q '^RESTORE=nothing-to-restore never-applied-at-all'; then
    pass "AC8: an unknown apply identifier gets a plain 'nothing to restore', not an opaque error"
else
    fail "AC8: an unknown apply identifier gets a plain 'nothing to restore'" "$never"
fi

# --- AC9: one damaged backup does not abort the restore -------------------------------------
seed_apply apply-damaged
rm -f "$HOME/.config/app2/colors.conf.bak.apply-damaged"      # the backup is destroyed
dout="$(bash "$RESTORE" apply-damaged 2>&1)"; drc=$?
assert_eq "1" "$drc" "AC9: a restore that could not finish everything is not reported as success"
if printf '%s\n' "$dout" | grep -q "^RESTORE_FAILED $HOME/.config/app2/colors.conf "; then
    pass "AC9: the file whose backup is gone is reported by path"
else
    fail "AC9: the file whose backup is gone is reported by path" "$dout"
fi
if cmp -s "$HOME/.config/app1/colors.conf" "$tmp/orig/app1" && cmp -s "$HOME/.config/app3/colors.conf" "$tmp/orig/app3"; then
    pass "AC9: every other file in the restore point was still restored"
else
    fail "AC9: every other file in the restore point was still restored" "$dout"
fi
if [ ! -e "$HOME/.config/app4/created.conf" ]; then
    pass "AC9: the created-file removal in the same point still happened"
else
    fail "AC9: the created-file removal in the same point still happened" "$dout"
fi
if [ -d "$RICE_RESTORE_DIR/apply-damaged" ]; then
    pass "AC9/AC11: a restore point with an unfinished file is NOT cleared"
else
    fail "AC9/AC11: a restore point with an unfinished file is NOT cleared" "the point was cleared anyway"
fi

# --- F7: the backup is intact but the TARGET cannot be written ------------------------------
seed_apply apply-rofail
if [ "$(id -u)" -eq 0 ]; then
    skip "F7: unwritable restore target" "running as root ignores the permission bits"
else
    chmod 400 "$HOME/.config/app2/colors.conf"
    chmod 500 "$HOME/.config/app2"
    fout="$(bash "$RESTORE" apply-rofail 2>&1)"; frc=$?
    chmod 700 "$HOME/.config/app2"
    chmod 600 "$HOME/.config/app2/colors.conf"
    assert_eq "1" "$frc" "F7: a target that cannot be written does not make the restore claim success"
    if printf '%s\n' "$fout" | grep -q "^RESTORE_FAILED $HOME/.config/app2/colors.conf (cannot write target"; then
        pass "F7: the unwritable target is reported by path, with the reason"
    else
        fail "F7: the unwritable target is reported by path, with the reason" "$fout"
    fi
    if printf '%s\n' "$fout" | grep -q "^RESTORED $HOME/.config/app1/colors.conf" && \
       printf '%s\n' "$fout" | grep -q "^RESTORED $HOME/.config/app3/colors.conf"; then
        pass "F7: one unwritable target does not abort the run - every other file is restored"
    else
        fail "F7: one unwritable target does not abort the run" "$fout"
    fi
    if [ -d "$RICE_RESTORE_DIR/apply-rofail" ]; then
        pass "F7: the restore point is kept so the failed path can be retried"
    else
        fail "F7: the restore point is kept so the failed path can be retried" "the point was cleared"
    fi
    # ...and once the target is writable again, re-running finishes the job and clears the point.
    retry="$(bash "$RESTORE" apply-rofail 2>&1)"; rrc2=$?
    assert_eq "0" "$rrc2" "F7: re-running after fixing the target completes the restore"
    if cmp -s "$HOME/.config/app2/colors.conf" "$tmp/orig/app2"; then
        pass "F7: the retried file is back to its prior state"
    else
        fail "F7: the retried file is back to its prior state" "$retry"
    fi
    if printf '%s\n' "$retry" | grep -q "^ALREADY_RESTORED $HOME/.config/app1/colors.conf"; then
        pass "F7: files restored in the first attempt are skipped, not restored twice"
    else
        fail "F7: files restored in the first attempt are skipped, not restored twice" "$retry"
    fi
fi

# --- AC12: the restore itself is interrupted partway through --------------------------------
# app2's target is turned into a FIFO after the apply, so the copy back blocks forever there:
# a deterministic stand-in for the host dying mid-restore. The run is killed once it has put the
# first file back, then re-invoked.
seed_apply apply-int
rm -f "$HOME/.config/app2/colors.conf"
mkfifo "$HOME/.config/app2/colors.conf" 2>/dev/null
if [ ! -p "$HOME/.config/app2/colors.conf" ]; then
    skip "AC12: interrupted restore" "could not create a FIFO to block the restore on"
else
    bash "$RESTORE" apply-int >"$tmp/int.log" 2>&1 &
    killme=$!
    blocked=0
    for _ in $(seq 1 100); do
        if [ -s "$RICE_RESTORE_DIR/apply-int/done.tsv" ]; then blocked=1; break; fi
        sleep 0.05
    done
    kill -9 "$killme" 2>/dev/null
    wait "$killme" 2>/dev/null
    if [ "$blocked" -eq 1 ]; then
        pass "AC12: the restore was killed after it had already put some files back"
    else
        fail "AC12: the restore was killed after it had already put some files back" "$(cat "$tmp/int.log" 2>/dev/null)"
    fi
    if [ -s "$RICE_RESTORE_DIR/apply-int/entries.tsv" ]; then
        pass "AC12: the interrupted restore left the restore point intact and uncleared"
    else
        fail "AC12: the interrupted restore left the restore point intact and uncleared" "the point is gone"
    fi
    # Whatever it managed before the kill must be sound, not half-written.
    if cmp -s "$HOME/.config/app1/colors.conf" "$tmp/orig/app1"; then
        pass "AC12: the file restored before the interruption is intact"
    else
        fail "AC12: the file restored before the interruption is intact" "app1 differs from its prior state"
    fi
    rm -f "$HOME/.config/app2/colors.conf"   # the blocking FIFO goes away with the crash
    iout="$(bash "$RESTORE" apply-int 2>&1)"; irc=$?
    assert_eq "0" "$irc" "AC12: re-invoking the same identifier runs to completion"
    if printf '%s\n' "$iout" | grep -q "^ALREADY_RESTORED $HOME/.config/app1/colors.conf"; then
        pass "AC12: the re-run skips what the interrupted attempt already restored"
    else
        fail "AC12: the re-run skips what the interrupted attempt already restored" "$iout"
    fi
    ok=1
    for n in 1 2 3; do
        cmp -s "$HOME/.config/app$n/colors.conf" "$tmp/orig/app$n" || ok=0
    done
    if [ "$ok" -eq 1 ] && [ ! -e "$HOME/.config/app4/created.conf" ]; then
        pass "AC12: every remaining file is restored or removed, none corrupted or duplicated"
    else
        fail "AC12: every remaining file is restored or removed" "$iout"
    fi
    if [ ! -d "$RICE_RESTORE_DIR/apply-int" ]; then
        pass "AC12/AC11: the completed re-run clears the restore point"
    else
        fail "AC12/AC11: the completed re-run clears the restore point" "the point survives"
    fi
fi

# ── Boundary, statically ────────────────────────────────────────────────────────────────────
# Nothing this item ships or tests may read, call, wrap, or duplicate the Hyprland config dir's
# own separate backup/restore - which is exactly what these greps check, over the restore
# command, the library behind it, and this item's own three test files.
new_files=(
    "$PLUGIN_ROOT/scripts/restore-point.sh"
    "$PLUGIN_ROOT/scripts/rice-restore.sh"
    "$PLUGIN_ROOT/tests/test_restore_point.sh"
    "$PLUGIN_ROOT/tests/test_restore_command.sh"
    "$PLUGIN_ROOT/tests/test_restore_interrupt.sh"
)
hypr_dir_re='\.config/hypr([^-]|$)'                                                  # RP_EXCLUDE
offenders=""
for f in "${new_files[@]}"; do
    [ -f "$f" ] || { offenders+="missing: $f"$'\n'; continue; }
    hits="$(grep -nE 'safe-apply|backup-config\.sh' "$f" | grep -v RP_EXCLUDE || true)"   # RP_EXCLUDE
    [ -n "$hits" ] && offenders+="$f calls the excluded dir's own backup/restore: $hits"$'\n'
done
if [ -z "$offenders" ]; then
    pass "boundary: no code path or test here reads, calls, or wraps that directory's own restore"
else
    fail "boundary: no code path or test here reads, calls, or wraps that directory's own restore" "$offenders"
fi

# The restore command itself never so much as names that directory.
cmd_hits="$(grep -nE "$hypr_dir_re|HYPR_DIR" "$PLUGIN_ROOT/scripts/rice-restore.sh" || true)"   # RP_EXCLUDE
if [ -z "$cmd_hits" ]; then
    pass "boundary: the restore command contains no reference to the excluded directory at all"
else
    fail "boundary: the restore command contains no reference to the excluded directory" "$cmd_hits"
fi

# Everywhere else it appears, it appears only in the marked exclusion guard (RP_EXCLUDE) - never
# in a line that opens, copies, or removes anything there.
unmarked=""
for f in "${new_files[@]}"; do
    [ -f "$f" ] || continue
    while IFS= read -r line; do
        case "$line" in *RP_EXCLUDE*) continue ;; esac
        unmarked+="$f: $line"$'\n'
    done < <(grep -nE "$hypr_dir_re|HYPR_DIR" "$f" || true)   # RP_EXCLUDE
done
if [ -z "$unmarked" ]; then
    pass "boundary: every mention of that directory sits in the marked exclusion guard"
else
    fail "boundary: every mention of that directory sits in the marked exclusion guard" "$unmarked"
fi

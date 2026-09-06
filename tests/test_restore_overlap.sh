#!/usr/bin/env bash
# Overlapping paths inside ONE restore point: an apply enrols a directory AND files inside it.
# That is the documented flow, not a corner case - the rice skill backs up ~/.config/waybar (and
# wofi, rofi, kitty) as whole directories while the render pass writes ~/.config/waybar/colors.css
# INSIDE one of them, and the edit-config flow can join an apply already in progress from the
# other direction. Both orders are covered here, plus the interrupted-restore variant of each:
#
#   A. directory enrolled first, then a file inside it  (rice SKILL A5 step 5, then A4 step 4)
#   B. file enrolled first, then the directory around it (render pass, then edit-config step 2)
#   C. a restore of A/B interrupted partway and re-invoked to completion       (AC12)
#   D. a path the apply CREATED inside a directory it also enrolled            (AC7)
#   E. a path that CONTAINS the surface this item must never touch             (AC2 boundary)
#   F. D in the other order - created first, directory enrolled after it       (AC7 under B)
#
# What must hold in every case: the single restore returns every covered surface to its PRIOR
# state - never the apply's own output - exits 0, and clears the point (AC2, AC11, AC12).

tmp="$(mktemp_test_dir restore-overlap)"
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

# XDG_CONFIG_HOME goes with HOME: a `~/.config/...` path now resolves under the config base,
# so an inherited value would send this test's writes outside its sandbox.
unset XDG_CONFIG_HOME
export HOME="$tmp"
export RICE_DIR="$HOME/.config/hypr-rice"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
export RICE_RESTORE_DIR="$tmp/state/restore"
unset RICE_APPLY_ID

RESTORE="$PLUGIN_ROOT/scripts/rice-restore.sh"
BACKUP="$PLUGIN_ROOT/scripts/backup-path.sh"
RENDER="$PLUGIN_ROOT/skills/rice/scripts/render-templates.sh"

mkdir -p "$tmp/tpl"
printf 'RENDERED {{accent}}\n' > "$tmp/tpl/x.tmpl"
printf 'accent=cba6f7\n'       > "$tmp/pal.conf"

# One manifest line that writes INSIDE the directory the apply also backs up whole.
{
    printf 'waybar\t%s/tpl/x.tmpl\t%s/.config/waybar/colors.css\t\n' "$tmp" "$HOME"
} > "$tmp/manifest.list"

seed_waybar() {   # a directory of known content no apply ever wrote
    rm -rf "$HOME/.config/waybar" "$tmp/orig-waybar"
    mkdir -p "$HOME/.config/waybar"
    printf 'ORIGINAL\n' > "$HOME/.config/waybar/colors.css"
    printf 'USER-BAR\n' > "$HOME/.config/waybar/config.jsonc"
    cp -a "$HOME/.config/waybar" "$tmp/orig-waybar"
}

render() { bash "$RENDER" --no-reload "$tmp/pal.conf" "$tmp/manifest.list" 2>&1; }

# --- A. directory enrolled first, then a file inside it -------------------------------------
seed_waybar
export RICE_APPLY_ID="apply-dir-first"
bash "$BACKUP" "$HOME/.config/waybar" >/dev/null 2>&1     # A5 step 5: the whole directory
printf 'STAGED\n'   > "$HOME/.config/waybar/colors.css"   # the staged tree lands on top
printf 'RICE-BAR\n' > "$HOME/.config/waybar/config.jsonc"
aout="$(render)"                                          # A4 step 4: the render writes inside it
assert_eq "RENDERED cba6f7" "$(cat "$HOME/.config/waybar/colors.css")" \
    "A: precondition - the apply overwrote the nested surface"

# The nested path must NOT get a sidecar of its own inside the directory: the directory restore
# replaces that directory wholesale, which is exactly what destroyed such a sidecar before.
if [ -e "$HOME/.config/waybar/colors.css.bak.apply-dir-first" ]; then
    fail "A: no second backup is written inside the surface that will be replaced wholesale" \
         "colors.css.bak.apply-dir-first exists inside the directory it protects"
else
    pass "A: no second backup is written inside the surface that will be replaced wholesale"
fi
if awk -F'\t' '$1=="covered" && $2 ~ /waybar\/colors\.css$/ && $3 ~ /waybar$/ {f=1} END{exit !f}' \
       "$RICE_RESTORE_DIR/apply-dir-first/entries.tsv"; then
    pass "A: the nested path is recorded as covered by the enrolled directory (AC3)"
else
    fail "A: the nested path is recorded as covered by the enrolled directory" \
         "$(cat "$RICE_RESTORE_DIR/apply-dir-first/entries.tsv")"
fi

arout="$(bash "$RESTORE" apply-dir-first 2>&1)"; arc=$?
assert_eq "0" "$arc" "A/AC2: the single restore reports success"
assert_eq "ORIGINAL" "$(cat "$HOME/.config/waybar/colors.css" 2>/dev/null)" \
    "A/AC2: the nested file is back to its PRIOR state, not the apply's output"
assert_eq "USER-BAR" "$(cat "$HOME/.config/waybar/config.jsonc" 2>/dev/null)" \
    "A/AC2: the rest of the directory is back to its prior state"
if [ ! -d "$RICE_RESTORE_DIR/apply-dir-first" ]; then
    pass "A/AC11: the restore point is cleared after the successful restore"
else
    fail "A/AC11: the restore point is cleared after the successful restore" "$arout"
fi
again="$(bash "$RESTORE" apply-dir-first 2>&1)"; agrc=$?
assert_eq "3" "$agrc" "A/AC8: a second restore of the same id hits 'nothing to restore'"

# --- B. file enrolled first, then the directory around it -----------------------------------
seed_waybar
export RICE_APPLY_ID="apply-file-first"
bout="$(render)"                                          # the render pass enrols the FILE
assert_eq "RENDERED cba6f7" "$(cat "$HOME/.config/waybar/colors.css")" \
    "B: precondition - the apply overwrote the nested surface"
printf 'HELLO\n' > "$HOME/.bashrc"
cp -a "$HOME/.bashrc" "$tmp/orig-bashrc"
# edit-config step 2, joining the same apply: its own documented example line.
bash "$BACKUP" "$HOME/.config/waybar" "$HOME/.bashrc" >/dev/null 2>&1
printf 'HELLO\nexport RICE=1\n' > "$HOME/.bashrc"

brout="$(bash "$RESTORE" apply-file-first 2>&1)"; brc=$?
assert_eq "0" "$brc" "B/AC2: the single restore reports success"
assert_eq "ORIGINAL" "$(cat "$HOME/.config/waybar/colors.css" 2>/dev/null)" \
    "B/AC2: the nested file is back to its PRIOR state, not the apply's output"
assert_eq "USER-BAR" "$(cat "$HOME/.config/waybar/config.jsonc" 2>/dev/null)" \
    "B/AC2: the rest of the directory is back to its prior state"
assert_eq "HELLO" "$(cat "$HOME/.bashrc" 2>/dev/null)" \
    "B/AC2: the unrelated surface in the same point is back to its prior state"
if [ ! -d "$RICE_RESTORE_DIR/apply-file-first" ]; then
    pass "B/AC11: the restore point is cleared after the successful restore"
else
    fail "B/AC11: the restore point is cleared after the successful restore" "$brout"
fi
# The container has to be replayed before what it contains, or the wholesale copy wins.
dir_line="$(printf '%s\n' "$brout" | grep -n "^RESTORED $HOME/.config/waybar\$" | cut -d: -f1)"
file_line="$(printf '%s\n' "$brout" | grep -n "^RESTORED $HOME/.config/waybar/colors\.css\$" | cut -d: -f1)"
if [ -n "$dir_line" ] && [ -n "$file_line" ] && [ "$dir_line" -lt "$file_line" ]; then
    pass "B: the enclosing directory is replayed before the file inside it"
else
    fail "B: the enclosing directory is replayed before the file inside it" "$brout"
fi

# --- C. a restore of an overlapping point that only finishes on the second attempt -----------
# Order B again, so the nested file has a backup of its own. The DIRECTORY's backup is made
# unreadable, so the first attempt puts the nested file back and fails on the directory: the point
# survives with the nested entry already marked done. The second attempt then replaces the
# directory wholesale - which overwrites that already-restored file with the apply's output. The
# nested entry has to be replayed afterwards, not skipped as done, or the "completed" restore ends
# holding the apply's own output (AC12: no corruption, everything restored, then cleared).
seed_waybar
export RICE_APPLY_ID="apply-retry-overlap"
cout="$(render)"
bash "$BACKUP" "$HOME/.config/waybar" >/dev/null 2>&1
dir_backup="$HOME/.config/waybar.bak.apply-retry-overlap"
if [ "$(id -u)" -eq 0 ] || [ ! -d "$dir_backup" ]; then
    skip "C/AC12: an overlapping restore that completes on the second attempt" \
         "needs an unreadable backup (running as root ignores the permission bits)"
else
    chmod 000 "$dir_backup"
    c1="$(bash "$RESTORE" apply-retry-overlap 2>&1)"; c1rc=$?
    chmod 700 "$dir_backup"
    assert_eq "1" "$c1rc" "C/AC9: the attempt that could not replace the directory is not a success"
    assert_eq "ORIGINAL" "$(cat "$HOME/.config/waybar/colors.css" 2>/dev/null)" \
        "C/AC9: the nested file was still put back while the directory failed"
    if [ -s "$RICE_RESTORE_DIR/apply-retry-overlap/entries.tsv" ]; then
        pass "C/AC12: the unfinished overlapping point is left intact and uncleared"
    else
        fail "C/AC12: the unfinished overlapping point is left intact and uncleared" "$c1"
    fi
    c2="$(bash "$RESTORE" apply-retry-overlap 2>&1)"; c2rc=$?
    assert_eq "0" "$c2rc" "C/AC12: re-invoking the same identifier runs to completion"
    assert_eq "ORIGINAL" "$(cat "$HOME/.config/waybar/colors.css" 2>/dev/null)" \
        "C/AC12: the nested file the wholesale replacement overwrote is replayed, not skipped as done"
    assert_eq "USER-BAR" "$(cat "$HOME/.config/waybar/config.jsonc" 2>/dev/null)" \
        "C/AC12: the rest of the directory ends at its prior state"
    if [ ! -d "$RICE_RESTORE_DIR/apply-retry-overlap" ]; then
        pass "C/AC12: the completed re-run clears the point"
    else
        fail "C/AC12: the completed re-run clears the point" "$c2"
    fi
fi

# --- D. a file the apply CREATED inside a directory it also enrolled -------------------------
seed_waybar
rm -f "$HOME/.config/waybar/colors.css"      # the nested output does not exist beforehand
rm -rf "$tmp/orig-waybar"; cp -a "$HOME/.config/waybar" "$tmp/orig-waybar"
export RICE_APPLY_ID="apply-created-nested"
bash "$BACKUP" "$HOME/.config/waybar" >/dev/null 2>&1
dout="$(render)"
assert_file_exists "$HOME/.config/waybar/colors.css" "D: precondition - the apply created the nested file"
drout="$(bash "$RESTORE" apply-created-nested 2>&1)"; drc=$?
assert_eq "0" "$drc" "D/AC2: the restore reports success"
if [ ! -e "$HOME/.config/waybar/colors.css" ]; then
    pass "D/AC7: the file the apply created inside the enrolled directory is gone, not orphaned"
else
    fail "D/AC7: the file the apply created inside the enrolled directory is gone" "$drout"
fi
assert_eq "USER-BAR" "$(cat "$HOME/.config/waybar/config.jsonc" 2>/dev/null)" \
    "D/AC2: the directory's own prior content is back"
if diff -r "$HOME/.config/waybar" "$tmp/orig-waybar" >/dev/null 2>&1; then
    pass "D/AC2: the whole directory is byte-identical to its prior state"
else
    fail "D/AC2: the whole directory is byte-identical to its prior state" \
         "$(diff -r "$HOME/.config/waybar" "$tmp/orig-waybar" 2>&1)"
fi

# --- E. a path that CONTAINS the surface with its own separate restore -----------------------
# Containment cuts both ways. A-D are entries that overlap EACH OTHER; this is an entry that
# would swallow the one surface AC2 says this command never touches. A directory is put back
# wholesale (rm -rf + cp -a), so enrolling an ancestor of that surface would revert it too, from
# the other direction. Enrolment is refused; the plain backup this script has always taken is
# still taken, because a copy touches nothing.
seed_waybar
excluded_dir="$HOME/.config/hypr"                                                    # RP_EXCLUDE
mkdir -p "$excluded_dir"
printf 'AT-APPLY-TIME\n' > "$excluded_dir/its-own.conf"
printf 'HELLO\n' > "$HOME/.bashrc"
export RICE_APPLY_ID="apply-ancestor"
eout="$(bash "$BACKUP" "$HOME/.config" "$HOME/.bashrc" 2>&1)"
eledger="$RICE_RESTORE_DIR/apply-ancestor/entries.tsv"
if [ -f "$eledger" ] && awk -F'\t' -v t="$HOME/.config" '$2 == t {f=1} END{exit !f}' "$eledger"; then
    fail "E/AC2: a path that contains that surface is left out of the restore point" "$(cat "$eledger")"
else
    pass "E/AC2: a path that contains that surface is left out of the restore point"
fi
assert_file_exists "$HOME/.config.bak.apply-ancestor/waybar/config.jsonc" \
    "E: the plain backup this script has always taken is still taken"
if printf '%s\n' "$eout" | grep -q "^NOT_ENROLLED $HOME/.config "; then
    pass "E: the caller is told that backup is not this mechanism's to put back"
else
    fail "E: the caller is told that backup is not this mechanism's to put back" "$eout"
fi
# A WRITE to such a path has no way back that respects the boundary, so it is refused outright.
eprc=0; eprot="$(bash "$PLUGIN_ROOT/scripts/restore-point.sh" record "$HOME/.config" 2>&1)" || eprc=$?
assert_eq "1" "$eprc" "E/AC10: enrolling a path that contains that surface is refused, so nothing writes over it"

# The surface moves on under its own separate contract after the apply. The restore must not
# know or care - it puts the enrolled file back and leaves that directory exactly as it found it.
printf 'CHANGED-BY-ITS-OWN-CONTRACT\n' > "$excluded_dir/its-own.conf"
printf 'HELLO\nexport RICE=1\n' > "$HOME/.bashrc"
erout="$(bash "$RESTORE" apply-ancestor 2>&1)"; erc=$?
assert_eq "0" "$erc" "E/AC2: the restore of the rest of that apply still succeeds"
assert_eq "HELLO" "$(cat "$HOME/.bashrc" 2>/dev/null)" \
    "E/AC2: the surface that WAS enrolled is back to its prior state"
assert_eq "CHANGED-BY-ITS-OWN-CONTRACT" "$(cat "$excluded_dir/its-own.conf" 2>/dev/null)" \
    "E/AC2: nothing under the out-of-scope surface is reverted by this restore"

# Defence in depth: a ledger hand-edited to hold such a path is refused, not acted on.
mkdir -p "$RICE_RESTORE_DIR/apply-forged"
cp -a "$HOME/.config" "$tmp/forged-backup"
printf 'file\t%s\t%s\n' "$HOME/.config" "$tmp/forged-backup" > "$RICE_RESTORE_DIR/apply-forged/entries.tsv"
printf 'CHANGED-AGAIN\n' > "$excluded_dir/its-own.conf"
efout="$(bash "$RESTORE" apply-forged 2>&1)"; efrc=$?
assert_eq "1" "$efrc" "E/AC2: a forged ledger entry that would swallow that surface is not a success"
assert_eq "CHANGED-AGAIN" "$(cat "$excluded_dir/its-own.conf" 2>/dev/null)" \
    "E/AC2: the forged entry did not revert anything under that surface"
if printf '%s\n' "$efout" | grep -q "^RESTORE_FAILED $HOME/.config "; then
    pass "E/AC9: the refused path is reported by path, with the reason"
else
    fail "E/AC9: the refused path is reported by path, with the reason" "$efout"
fi
rm -rf "$excluded_dir" "$RICE_RESTORE_DIR/apply-forged"
unset RICE_APPLY_ID

# --- F. D in the other order: the apply CREATES the file, THEN enrols the directory -----------
# D enrols the directory first, so its backup predates the created file and the wholesale copy
# never brings it back. Reverse the order - render first (kind `new`), edit-config joins the same
# apply afterwards (rice SKILL A4 step 4 before an A5-style backup of the same tree) - and the
# directory's backup now HOLDS the file this apply created. Putting the directory back therefore
# re-creates it, and only the container-first replay lets the `new` entry have the last word and
# take it away again. Without that ordering AC7 fails silently while the restore reports success.
seed_waybar
rm -f "$HOME/.config/waybar/colors.css"      # the nested output does not exist beforehand
rm -rf "$tmp/orig-waybar"; cp -a "$HOME/.config/waybar" "$tmp/orig-waybar"
export RICE_APPLY_ID="apply-created-then-dir"
fout="$(render)"                                          # creates ~/.config/waybar/colors.css
assert_file_exists "$HOME/.config/waybar/colors.css" "F: precondition - the apply created the nested file"
bash "$BACKUP" "$HOME/.config/waybar" >/dev/null 2>&1     # the dir backup now holds that file
printf 'RICE-BAR\n' > "$HOME/.config/waybar/config.jsonc"
assert_file_exists "$HOME/.config/waybar.bak.apply-created-then-dir/colors.css" \
    "F: precondition - the directory's backup does hold the file this apply created"
frout="$(bash "$RESTORE" apply-created-then-dir 2>&1)"; frc=$?
assert_eq "0" "$frc" "F/AC2: the restore reports success"
if [ ! -e "$HOME/.config/waybar/colors.css" ]; then
    pass "F/AC7: the created file is removed even though the later directory backup restored it"
else
    fail "F/AC7: the created file is removed even though the later directory backup restored it" \
         "colors.css survives with: $(cat "$HOME/.config/waybar/colors.css" 2>/dev/null)
$frout"
fi
assert_eq "USER-BAR" "$(cat "$HOME/.config/waybar/config.jsonc" 2>/dev/null)" \
    "F/AC2: the directory's own prior content is back"
if diff -r "$HOME/.config/waybar" "$tmp/orig-waybar" >/dev/null 2>&1; then
    pass "F/AC2: the whole directory is byte-identical to its prior state"
else
    fail "F/AC2: the whole directory is byte-identical to its prior state" \
         "$(diff -r "$HOME/.config/waybar" "$tmp/orig-waybar" 2>&1)"
fi
if [ ! -d "$RICE_RESTORE_DIR/apply-created-then-dir" ]; then
    pass "F/AC11: the restore point is cleared after the successful restore"
else
    fail "F/AC11: the restore point is cleared after the successful restore" "the point survives"
fi
unset RICE_APPLY_ID

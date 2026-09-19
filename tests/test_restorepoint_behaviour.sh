#!/usr/bin/env bash
# Restore-point behaviours that no other test file pins.
#
# This file replaces tests/test_restorepoint_parity.sh, which drove the bash and Python
# implementations through the same scenarios and diffed the ledger and every byte on disk. That
# test did its job - it proved the port before the switch-over - and became meaningless the
# moment the bash became a shim over the Python it was being compared against.
#
# What survives is the part worth keeping: the scenarios. Each is asserted against the expected
# OUTCOME now, rather than against a second implementation.
#
# Deliberately not duplicated here: fold-into-an-ancestor (test_restore_point.sh), the HYPR_DIR
# boundary during a restore (test_restore_command.sh), the enrolment round trip
# (test_restore_overlap.sh).
#
# Grades:
#   B-1  a symlink is enrolled and backed up AS A LINK, not as the file it points at
#   B-2  a trailing slash names the same surface, so it enrols once, not twice
#   B-3  the excluded dir follows HYPR_DIR at ENROLMENT time, both directions
#   B-4  a path that contains the excluded dir is refused, and nothing is written
#   B-5  re-enrolling within one apply keeps the FIRST backup, never this apply's own output

RP="$PLUGIN_ROOT/scripts/restore-point.sh"
assert_file_exists "$RP" "restore-point.sh ships"

if ! command -v python3 >/dev/null 2>&1; then
    skip "restore-point behaviour" "python3 missing"
    return 0
fi

tmp="$(mktemp_test_dir rp-behaviour)"
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

# `protect <home> <apply-id> <path> [extra-env]` - one enrolment, printing the RP_* fields.
protect() {
    local h="$1" id="$2" p="$3" extra="${4:-}"
    env -i PATH="$PATH" HOME="$h" RICE_APPLY_ID="$id" XDG_STATE_HOME="$h/state" \
        CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" ${extra:+$extra} \
        bash -c '. "$1" >/dev/null 2>&1
                 if rp_protect "$2"; then printf "ok\t%s\t%s\n" "$RP_LAST_STATE" "$RP_LAST_BACKUP"
                 else printf "no\t%s\n" "$RP_LAST_ERROR"; fi' _ "$RP" "$p" 2>/dev/null
}
ledger() { cat "$1/state/hypr-rice/restore/$2/entries.tsv" 2>/dev/null; }

# --- B-1  a symlink is enrolled as a link ------------------------------------------------------
h1="$tmp/h1"; mkdir -p "$h1/.config"
printf 'real content\n' > "$h1/.config/real.css"
ln -s "$h1/.config/real.css" "$h1/.config/linked.css"
out="$(protect "$h1" a1 "$h1/.config/linked.css")"
assert_eq "ok" "$(printf '%s' "$out" | cut -f1)" "B-1: a symlink is enrolled"
bk="$h1/.config/linked.css.bak.a1"
if [ -L "$bk" ]; then
    pass "B-1: the backup is itself a symlink, not a copy of the target's bytes"
else
    fail "B-1: the backup is itself a symlink, not a copy of the target's bytes" "$(ls -l "$bk" 2>&1)"
fi
if [ "$(readlink "$bk")" = "$h1/.config/real.css" ]; then
    pass "B-1: and it points where the original pointed"
else
    fail "B-1: and it points where the original pointed" "$(readlink "$bk")"
fi
# Restoring must not have rewritten the file the link points at.
assert_file_contains "$h1/.config/real.css" "real content" "B-1: the link target is untouched"

# --- B-2  a trailing slash is the same surface -------------------------------------------------
h2="$tmp/h2"; mkdir -p "$h2/.config/mako"
printf 'cfg\n' > "$h2/.config/mako/config"
protect "$h2" a2 "$h2/.config/mako"  >/dev/null
out="$(protect "$h2" a2 "$h2/.config/mako/")"
state="$(printf '%s' "$out" | cut -f2)"
case "$state" in
    already-*) pass "B-2: a trailing slash re-enrols the SAME surface (state: $state)" ;;
    *)         fail "B-2: a trailing slash re-enrols the SAME surface" "state: $state" ;;
esac
assert_eq "1" "$(ledger "$h2" a2 | wc -l)" "B-2: it is one ledger entry, not two"

# --- B-3  the excluded dir follows HYPR_DIR ----------------------------------------------------
h3="$tmp/h3"; mkdir -p "$h3/.config/waybar" "$tmp/elsewhere/hypr"
printf 'bar\n' > "$h3/.config/waybar/style.css"
# With HYPR_DIR moved, ~/.config/hypr is an ORDINARY path and must enrol normally.
mkdir -p "$h3/.config/hypr"; printf 'conf\n' > "$h3/.config/hypr/hyprland.conf"
out="$(protect "$h3" a3 "$h3/.config/hypr/hyprland.conf" "HYPR_DIR=$tmp/elsewhere/hypr")"
assert_eq "file" "$(printf '%s' "$out" | cut -f2)" \
    "B-3: with HYPR_DIR moved, the default hypr path is an ordinary surface and is backed up"
# And the moved directory is the one now out of scope.
out="$(protect "$h3" a3 "$tmp/elsewhere/hypr/hyprland.conf" "HYPR_DIR=$tmp/elsewhere/hypr")"
assert_eq "excluded" "$(printf '%s' "$out" | cut -f2)" \
    "B-3: the directory HYPR_DIR names is the one excluded, wherever it is"

# --- B-4  a path containing the excluded dir is refused ----------------------------------------
h4="$tmp/h4"; mkdir -p "$h4/.config/hypr"
printf 'conf\n' > "$h4/.config/hypr/hyprland.conf"
before="$(find "$h4" | sort)"
out="$(protect "$h4" a4 "$h4/.config")"
assert_eq "no" "$(printf '%s' "$out" | cut -f1)" "B-4: enrolling a path that contains the hypr dir is refused"
if printf '%s' "$out" | grep -q "separate restore"; then
    pass "B-4: the refusal says why"
else
    fail "B-4: the refusal says why" "$out"
fi
assert_eq "$before" "$(find "$h4" | sort)" "B-4: and nothing was written - no sidecar, no ledger"

# --- B-5  re-enrolling keeps the FIRST backup ---------------------------------------------------
# The whole point of the ledger: the first enrolment holds what was there BEFORE the apply. A
# second copy taken after the apply has written would capture the apply's own output and call it
# "the prior state", which would make the restore a no-op that looks like a success.
h5="$tmp/h5"; mkdir -p "$h5/.config/waybar"
printf 'ORIGINAL\n' > "$h5/.config/waybar/style.css"
protect "$h5" a5 "$h5/.config/waybar/style.css" >/dev/null
printf 'THE APPLY OVERWROTE IT\n' > "$h5/.config/waybar/style.css"
out="$(protect "$h5" a5 "$h5/.config/waybar/style.css")"
assert_eq "already-file" "$(printf '%s' "$out" | cut -f2)" "B-5: the second enrolment is recognised as already enrolled"
assert_file_contains "$h5/.config/waybar/style.css.bak.a5" "ORIGINAL" \
    "B-5: the backup still holds the PRE-apply content, not the apply's own output"
assert_eq "1" "$(ledger "$h5" a5 | wc -l)" "B-5: and it is still one ledger entry"

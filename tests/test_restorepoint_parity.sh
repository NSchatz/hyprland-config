#!/usr/bin/env bash
# The Python restore-point module must behave EXACTLY like the bash one it replaces.
#
# `scripts/restore-point.sh` implements the invariant this whole plugin rests on: every write
# outside the hypr config dir is reversible, and reversibility is proven BEFORE the write. It is
# not code to port on faith. So the port lands alongside the original and this test drives both
# through the same scenarios, comparing not just verdicts but the LEDGER AND THE BYTES ON DISK
# each one leaves behind.
#
# Until this is green the bash stays in charge; the switch-over is a separate step with the
# proof already in hand.
#
# Grades:
#   R-1  the pure predicates agree (canon, expand, excluded, contains-excluded, safe-target)
#   R-2  state roots and dirs agree across the env matrix
#   R-3  `protect` agrees on verdict, state and the entries ledger it writes
#   R-4  `protect` leaves byte-identical backups on disk
#   R-5  the fold-into-an-ancestor and already-enrolled cases agree
#   R-6  the refusals agree (contains-excluded, unusable apply id, unwritable point)

SH="$PLUGIN_ROOT/scripts/restore-point.sh"
PYMOD="$PLUGIN_ROOT/scripts/ricelib/restorepoint.py"
assert_file_exists "$SH" "the bash restore-point ships"
assert_file_exists "$PYMOD" "the python restore-point ships"

if ! command -v python3 >/dev/null 2>&1; then
    skip "restore-point parity" "python3 missing"
    return 0
fi

tmp="$(mktemp_test_dir rp-parity)"
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

# Run one bash expression with the restore-point library sourced.
# NOTE on $0: restore-point.sh only defines functions when SOURCED, and it decides that with
# `[ "${BASH_SOURCE[0]}" = "$0" ]`. Sourcing it as `. "$0"` makes those equal, so it runs its CLI
# instead - which is why this passes `_` as $0 and the library path as $1.
bsh() {  # bsh <home> <extra-env-assignments> <expr>
    env -i PATH="$PATH" HOME="$1" ${2:+$2} \
        bash -c '. "$1" >/dev/null 2>&1; shift; '"$3" _ "$SH" 2>/dev/null
}
pysh() { # pysh <home> <extra-env> <args...>
    local h="$1" extra="$2"; shift 2
    env -i PATH="$PATH" HOME="$h" PYTHONPATH="$PLUGIN_ROOT/scripts" ${extra:+$extra} \
        python3 -m ricelib.restorepoint "$@" 2>/dev/null
}

H="$tmp/home"; mkdir -p "$H"

# --- R-1  pure predicates ----------------------------------------------------------------------
for p in '/a/b' '/a/b/' '/a/b///' '/' 'rel/path' '~' '~/.config' '~/.config/waybar' \
         '~/.config/hypr' '~/.config/hypr/hyprland.conf' '~/.cache/x' ''; do
    assert_eq "$(bsh "$H" "" "rp_canon \"$p\"")" "$(pysh "$H" "" canon "$p")" \
        "R-1: canon '$p' agrees"
    assert_eq "$(bsh "$H" "" "rp_expand \"$p\"")" "$(pysh "$H" "" expand "$p")" \
        "R-1: expand '$p' agrees"

    bsh "$H" "" "rp_excluded \"$p\""; b=$?
    pysh "$H" "" excluded "$p" >/dev/null; y=$?
    assert_eq "$b" "$y" "R-1: excluded '$p' agrees"

    bsh "$H" "" "rp_contains_excluded \"$p\""; b=$?
    pysh "$H" "" contains-excluded "$p" >/dev/null; y=$?
    assert_eq "$b" "$y" "R-1: contains-excluded '$p' agrees"

    bsh "$H" "" "rp_safe_target \"$p\""; b=$?
    pysh "$H" "" safe-target "$p" >/dev/null; y=$?
    assert_eq "$b" "$y" "R-1: safe-target '$p' agrees"
done

# HYPR_DIR moves the excluded dir; both must follow it.
for p in "$tmp/elsewhere/hypr" "$tmp/elsewhere/hypr/x" "$tmp/elsewhere"; do
    bsh "$H" "HYPR_DIR=$tmp/elsewhere/hypr" "rp_excluded \"$p\""; b=$?
    pysh "$H" "HYPR_DIR=$tmp/elsewhere/hypr" excluded "$p" >/dev/null; y=$?
    assert_eq "$b" "$y" "R-1: excluded honours HYPR_DIR for '$p'"
done

# --- R-2  state roots ---------------------------------------------------------------------------
assert_eq "$(bsh "$H" "" 'rp_state_root')" "$(pysh "$H" "" state-root)" "R-2: state root agrees"
assert_eq "$(bsh "$H" "" 'rp_state_dir')" "$(pysh "$H" "" state-dir)" "R-2: state dir agrees"
assert_eq "$(bsh "$H" "XDG_STATE_HOME=$tmp/st" 'rp_state_root')" \
          "$(pysh "$H" "XDG_STATE_HOME=$tmp/st" state-root)" "R-2: XDG_STATE_HOME is honoured by both"
assert_eq "$(bsh "$H" "RICE_RESTORE_DIR=$tmp/rd/" 'rp_state_dir')" \
          "$(pysh "$H" "RICE_RESTORE_DIR=$tmp/rd/" state-dir)" "R-2: RICE_RESTORE_DIR is honoured by both"

# --- R-3..R-6  `protect`, compared on disk -------------------------------------------------------
# `scenario <name> <setup-fn> <paths...>` builds two identical sandboxes, protects the same paths
# through each implementation, and compares the ledger, the verdicts and the backup bytes.
scenario() {
    local name="$1" setup="$2"; shift 2
    local bdir="$tmp/sc/$name/bash" pdir="$tmp/sc/$name/py"
    rm -rf "$tmp/sc/$name"; mkdir -p "$bdir" "$pdir"
    "$setup" "$bdir"; "$setup" "$pdir"

    local bout pout brc prc
    bout=""; brc=0
    for p in "$@"; do
        local line
        line="$(env -i PATH="$PATH" HOME="$bdir" RICE_APPLY_ID=fixed-id XDG_STATE_HOME="$bdir/state" \
            bash -c '. "$1" >/dev/null 2>&1
                     if rp_protect "$2"; then printf "ok\t%s\t%s\n" "$RP_LAST_STATE" "$RP_LAST_COVER"
                     else printf "no\t%s\t%s\n" "$RP_LAST_STATE" "$RP_LAST_ERROR"; fi' \
            _ "$SH" "${p/#SANDBOX/$bdir}" 2>/dev/null)"
        bout="$bout$line"$'\n'
    done
    pout=""
    for p in "$@"; do
        local line st
        line="$(env -i PATH="$PATH" HOME="$pdir" RICE_APPLY_ID=fixed-id XDG_STATE_HOME="$pdir/state" \
            PYTHONPATH="$PLUGIN_ROOT/scripts" python3 -m ricelib.restorepoint protect \
            "${p/#SANDBOX/$pdir}" 2>/dev/null)"; st=$?
        local state cover err
        state="$(printf '%s\n' "$line" | sed -n 's/^RP_STATE=//p')"
        cover="$(printf '%s\n' "$line" | sed -n 's/^RP_COVER=//p')"
        err="$(printf '%s\n' "$line" | sed -n 's/^RP_ERROR=//p')"
        if [ "$st" -eq 0 ]; then pout="$pout$(printf 'ok\t%s\t%s' "$state" "$cover")"$'\n'
        else pout="$pout$(printf 'no\t%s\t%s' "$state" "$err")"$'\n'; fi
    done

    # A `covered` verdict carries the ancestor's absolute path, which differs only by sandbox.
    # Normalise it the same way the ledger comparison below does.
    bout="$(printf '%s' "$bout" | sed "s|$bdir|SANDBOX|g")"
    pout="$(printf '%s' "$pout" | sed "s|$pdir|SANDBOX|g")"
    assert_eq "$bout" "$pout" "R-3: [$name] verdicts and states agree"

    # The ledger, with the sandbox prefix normalised away.
    local bl pl
    bl="$(sed "s|$bdir|SANDBOX|g" "$bdir/state/hypr-rice/restore/fixed-id/entries.tsv" 2>/dev/null | sort)"
    pl="$(sed "s|$pdir|SANDBOX|g" "$pdir/state/hypr-rice/restore/fixed-id/entries.tsv" 2>/dev/null | sort)"
    assert_eq "$bl" "$pl" "R-3: [$name] the entries ledger agrees"

    # Everything on disk, including the .bak sidecars' bytes.
    local btree ptree
    btree="$(cd "$bdir" && find . -not -path './state/*' | sort | while read -r f; do
                if [ -f "$f" ] && [ ! -L "$f" ]; then printf '%s %s\n' "$f" "$(cksum < "$f")"; else printf '%s\n' "$f"; fi; done)"
    ptree="$(cd "$pdir" && find . -not -path './state/*' | sort | while read -r f; do
                if [ -f "$f" ] && [ ! -L "$f" ]; then printf '%s %s\n' "$f" "$(cksum < "$f")"; else printf '%s\n' "$f"; fi; done)"
    assert_eq "$btree" "$ptree" "R-4: [$name] the files on disk agree byte-for-byte"
}

setup_plain() {
    mkdir -p "$1/.config/waybar" "$1/.config/hypr"
    printf 'old waybar css\n' > "$1/.config/waybar/style.css"
    printf 'hypr conf\n' > "$1/.config/hypr/hyprland.conf"
}
setup_dir() {
    setup_plain "$1"
    mkdir -p "$1/.config/mako"
    printf 'mako cfg\n' > "$1/.config/mako/config"
}
setup_link() {
    setup_plain "$1"
    printf 'real\n' > "$1/.config/real.css"
    ln -sf "$1/.config/real.css" "$1/.config/linked.css"
}

# R-3/R-4  a plain file, a file that does not exist yet, and the excluded dir.
scenario existing-file setup_plain 'SANDBOX/.config/waybar/style.css'
scenario new-file      setup_plain 'SANDBOX/.config/waybar/colors.css'
scenario excluded      setup_plain 'SANDBOX/.config/hypr/hyprland.conf'
scenario symlink       setup_link  'SANDBOX/.config/linked.css'

# R-5  a directory first, then a file inside it: the second must FOLD INTO the first.
scenario dir-then-child setup_dir 'SANDBOX/.config/mako' 'SANDBOX/.config/mako/config'
# The same path twice: the second is already-enrolled and must not re-copy.
scenario twice          setup_plain 'SANDBOX/.config/waybar/style.css' 'SANDBOX/.config/waybar/style.css'
# A trailing slash is the same path.
scenario trailing-slash setup_dir  'SANDBOX/.config/mako' 'SANDBOX/.config/mako/'

# R-6  a path that CONTAINS the excluded dir must be refused by both.
scenario contains-excluded setup_plain 'SANDBOX/.config'

# R-6  an unusable apply id is refused identically.
for bad in 'has/slash' 'has space' '.leading'; do
    b="$(env -i PATH="$PATH" HOME="$H" RICE_APPLY_ID="$bad" XDG_STATE_HOME="$tmp/s1" \
         bash -c '. "$1" >/dev/null 2>&1; rp_protect "$2" >/dev/null 2>&1; echo "$?"' _ "$SH" "$H/x" 2>/dev/null)"
    env -i PATH="$PATH" HOME="$H" RICE_APPLY_ID="$bad" XDG_STATE_HOME="$tmp/s1" \
        PYTHONPATH="$PLUGIN_ROOT/scripts" python3 -m ricelib.restorepoint protect "$H/x" >/dev/null 2>&1
    y=$?
    assert_eq "$b" "$y" "R-6: apply id '$bad' is refused by both"
done

# --- new-id shape --------------------------------------------------------------------------------
bid="$(bsh "$H" "XDG_STATE_HOME=$tmp/s2" 'rp_new_id')"
yid="$(pysh "$H" "XDG_STATE_HOME=$tmp/s2" new-id)"
if printf '%s' "$bid" | grep -qE '^[0-9]{8}-[0-9]{6}$' && printf '%s' "$yid" | grep -qE '^[0-9]{8}-[0-9]{6}$'; then
    pass "R-2: both mint ids in the same YYYYmmdd-HHMMSS shape"
else
    fail "R-2: both mint ids in the same YYYYmmdd-HHMMSS shape" "bash=$bid python=$yid"
fi

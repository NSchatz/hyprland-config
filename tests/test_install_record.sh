#!/usr/bin/env bash
# S0037-hyprland-config-install-7 - say what was put on the machine.
#
# Grades the install-record half of the spec:
#   AC-1   a package install writes a record naming every package installed, every one already
#          present and every one that failed, and leaves it on the machine
#   AC-6   the recorded installs list newest first and any one prints in full by identifier,
#          without the user needing to know where the record is stored
#   AC-7   each package says installed / already present / failed, and a failure carries the
#          one-line reason the install reported
#   AC-8   an ad-hoc package list records in the same form and the same place as a scripted one
#   AC-9   a record that cannot be written is reported by path, the transaction is still printed,
#          and the install is NOT reported as recorded
#   AC-10  an empty listing says so plainly and exits zero
#   AC-11  an install where nothing was installed, skipped or failed leaves no record
#   AC-14  an AUR helper built from source is in the same record, named as a source build
#
# Everything runs against stubbed package tooling on PATH: CI is not an Arch machine, and no
# assertion here may install anything or touch a path outside this test's own tempdir.

PS="$PLUGIN_ROOT/scripts"
IR="$PS/install-record.sh"
IP="$PS/install-packages.sh"

tmp="$(mktemp_test_dir install-record)"
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

unset XDG_CONFIG_HOME XDG_STATE_HOME RICE_DIR RICE_APPLY_ID RICE_INSTALL_RECORD_DIR
export HOME="$tmp/home"
mkdir -p "$HOME"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
BIN_PATH="/usr/bin:/bin"

assert_file_exists "$IR" "scripts/install-record.sh ships"
assert_file_exists "$IP" "scripts/install-packages.sh ships"

field() {   # <KEY> <output>
    printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -n1
}
assert_out_has() {   # <needle> <output> <name>
    if printf '%s\n' "$2" | grep -qF -- "$1"; then pass "$3"; else
        fail "$3" "missing: $1
--- output ---
$2"
    fi
}
assert_out_lacks() { # <needle> <output> <name>
    if printf '%s\n' "$2" | grep -qF -- "$1"; then
        fail "$3" "present but must not be: $1
--- output ---
$2"
    else pass "$3"; fi
}

# ---------------------------------------------------------------------------------------------
# A stubbed Arch: pacman keeps its "installed" set in a file, so a package installed by one call
# is present to the next, exactly as the real one behaves. Every invocation of every package
# tool is logged so a test can assert what was and was not run.
# ---------------------------------------------------------------------------------------------
mk_arch_stubs() {   # <dir> <repo-pkgs> <present-pkgs> <fail-pkgs>
    local d="$1" repo="$2" present="$3" failing="$4"
    mkdir -p "$d"
    printf '%s\n' "$repo"    > "$d/.repo"
    printf '%s\n' "$failing" > "$d/.fail"
    : > "$d/.log"
    : > "$d/.installed"
    for p in $present; do printf '%s\n' "$p" >> "$d/.installed"; done
    cat > "$d/pacman" <<'STUB'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"
printf 'pacman %s\n' "$*" >> "$d/.log"
case "${1:-}" in
    -Qq|-Q)
        grep -Fxq -- "${2:-}" "$d/.installed" 2>/dev/null && exit 0
        exit 1 ;;
    -Si)
        grep -qw -- "${2:-}" "$d/.repo" 2>/dev/null && exit 0
        exit 1 ;;
    -S)
        rc=0
        for a in "$@"; do
            case "$a" in -*|--*) continue ;; esac
            if grep -qw -- "$a" "$d/.fail" 2>/dev/null; then
                echo "error: target not found: $a" >&2
                echo "error: target not found: $a"
                rc=1
            else
                grep -Fxq -- "$a" "$d/.installed" 2>/dev/null || printf '%s\n' "$a" >> "$d/.installed"
                echo "installing $a..."
            fi
        done
        exit "$rc" ;;
esac
exit 0
STUB
    cat > "$d/sudo" <<'STUB'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"
printf 'sudo %s\n' "$*" >> "$d/.log"
exec "$@"
STUB
    cat > "$d/git" <<'STUB'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"
printf 'git %s\n' "$*" >> "$d/.log"
if [ "${1:-}" = "clone" ]; then mkdir -p "${3:-}" && printf 'PKGBUILD\n' > "${3:-}/PKGBUILD"; fi
exit 0
STUB
    cat > "$d/makepkg" <<'STUB'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"
printf 'makepkg %s\n' "$*" >> "$d/.log"
# A successful `makepkg -si` leaves a working paru on PATH and in pacman's installed set.
cat > "$d/paru" <<'PARU'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"
printf 'paru %s\n' "$*" >> "$d/.log"
[ "${1:-}" = "--version" ] && { echo "paru v2.0.0"; exit 0; }
if [ "${1:-}" = "-S" ]; then
    for a in "$@"; do
        case "$a" in -*|--*) continue ;; esac
        if grep -qw -- "$a" "$d/.fail" 2>/dev/null; then
            echo "==> ERROR: A failure occurred in build(): $a" >&2
            echo "==> ERROR: A failure occurred in build(): $a"
            exit 1
        fi
        grep -Fxq -- "$a" "$d/.installed" 2>/dev/null || printf '%s\n' "$a" >> "$d/.installed"
        echo "building $a..."
    done
fi
exit 0
PARU
chmod +x "$d/paru"
printf 'paru\n' >> "$d/.installed"
exit 0
STUB
    chmod +x "$d/pacman" "$d/sudo" "$d/git" "$d/makepkg"
}

# =============================================================================================
# AC-1 / AC-7 / AC-14  a scripted install leaves a record naming every package, its outcome,
#                      the reason for a failure, and the helper it built from source
# =============================================================================================
s1="$tmp/s1"; stub="$s1/stubs"
export HOME="$s1/home"; mkdir -p "$HOME"
mk_arch_stubs "$stub" "waybar kitty" "kitty" "wl-screenrec"

out="$(printf 'y\n' | PATH="$stub:$BIN_PATH" bash "$IP" --route install.sh --noconfirm \
        waybar kitty wl-screenrec 2>&1)"; rc=$?

assert_out_has "PACKAGES=waybar kitty wl-screenrec" "$out" "AC-1: the install prints the list it was given"
rec_path="$(field INSTALL_RECORD "$out")"
rec_id="$(field INSTALL_RECORD_ID "$out")"
if [ -n "$rec_path" ] && [ -f "$rec_path" ]; then
    pass "AC-1: the install left a record on the machine ($rec_path)"
else
    fail "AC-1: the install left a record on the machine" "no readable INSTALL_RECORD= path
$out"
fi
case "$rec_path" in
    "$HOME/.local/state/hypr-rice/installs/"*) pass "AC-1: the record lives in the plugin's state area, resolved not hardcoded" ;;
    *) fail "AC-1: the record lives in the plugin's state area" "got: $rec_path" ;;
esac

body="$(cat "$rec_path" 2>/dev/null)"
assert_out_has $'installed\twaybar' "$body" "AC-1/AC-7: waybar is recorded as installed"
assert_out_has $'present\tkitty'    "$body" "AC-1/AC-7: kitty is recorded as already present"
assert_out_has $'failed\twl-screenrec' "$body" "AC-1/AC-7: wl-screenrec is recorded as failed"
if printf '%s\n' "$body" | grep -q '^failed	wl-screenrec	aur	.*ERROR'; then
    pass "AC-7: the failure carries the one-line reason the install reported"
else
    fail "AC-7: the failure carries the one-line reason the install reported" "$body"
fi
if printf '%s\n' "$body" | grep -q '^built-from-source	paru	https://aur.archlinux.org/paru.git'; then
    pass "AC-14: the AUR helper built from source is in the same record, named as a source build"
else
    fail "AC-14: the AUR helper built from source is in the same record" "$body"
fi
assert_out_has "# route	install.sh" "$body" "AC-1: the record names the route it came from"

# =============================================================================================
# AC-6  list newest first, show one in full by identifier, without knowing where it is stored
# =============================================================================================
lst="$(PATH="$stub:$BIN_PATH" bash "$IR" list 2>&1)"
assert_out_has "$rec_id" "$lst" "AC-6: the listing names the record just written"
assert_out_has "1 installed" "$lst" "AC-6: the listing summarises what the transaction did"

# A second, later record must list ABOVE the first one. Deliberately with NO `sleep` between the
# two installs: an ordering that holds only when the wall clock happens to tick between two
# transactions is not the ordering AC-6 asks for, and a re-run of an idempotent install.sh
# finishes well inside a second.
mk_arch_stubs "$stub" "waybar kitty rofi" "kitty waybar paru" "wl-screenrec"
out2="$(PATH="$stub:$BIN_PATH" bash "$IP" --route package-list --noconfirm rofi 2>&1)"
id2="$(field INSTALL_RECORD_ID "$out2")"
lst="$(PATH="$stub:$BIN_PATH" bash "$IR" list 2>&1)"
first_listed="$(printf '%s\n' "$lst" | head -n1 | cut -f1)"
assert_eq "$id2" "$first_listed" "AC-6: the listing is newest first"

# Two records in the SAME second, made to collide by construction rather than by luck: a frozen
# `date` is the only way to assert this every run instead of on whichever machine is fast enough.
# The ordinal that disambiguates them is also the sort key the listing reads back, so the newer
# one has to lead - and `show` has to keep finding it under the identifier it was given.
s6="$tmp/s6"; store6="$s6/store"; dstub="$s6/stubs"
mkdir -p "$dstub"
cat > "$dstub/date" <<'STUB'
#!/usr/bin/env bash
if [ "${1:-}" = "+%Y%m%d-%H%M%S" ]; then printf '20260101-121212\n'; exit 0; fi
for d in /usr/bin/date /bin/date; do [ -x "$d" ] && exec "$d" "$@"; done
exit 127
STUB
chmod +x "$dstub/date"

o1="$(printf 'installed\tfirst-package\trepo\t\n' \
      | RICE_INSTALL_RECORD_DIR="$store6" PATH="$dstub:$BIN_PATH" bash "$IR" record --route install.sh 2>&1)"
o2="$(printf 'installed\tsecond-package\trepo\t\n' \
      | RICE_INSTALL_RECORD_DIR="$store6" PATH="$dstub:$BIN_PATH" bash "$IR" record --route package-list 2>&1)"
same1="$(field INSTALL_RECORD_ID "$o1")"
same2="$(field INSTALL_RECORD_ID "$o2")"
assert_eq "20260101-121212" "$same1" "AC-6: the first record of a second is the plain timestamp"
assert_eq "20260101-121212-01" "$same2" "AC-6: a record minted in the same second takes an ordinal that sorts after it"
lst6="$(RICE_INSTALL_RECORD_DIR="$store6" PATH="$BIN_PATH" bash "$IR" list 2>&1)"
assert_eq "$same2" "$(printf '%s\n' "$lst6" | head -n1 | cut -f1)" \
    "AC-6: two records written in the same second still list newest first"
shown6="$(RICE_INSTALL_RECORD_DIR="$store6" PATH="$BIN_PATH" bash "$IR" show "$same2" 2>&1)"; s6rc=$?
assert_eq "0" "$s6rc" "AC-6: show <id> still finds a record whose identifier carries an ordinal"
assert_out_has "second-package" "$shown6" "AC-6: it shows that record, not the other one from the same second"

# Ten transactions in one second: the ordinal is zero-padded precisely so "-10" sorts after
# "-02" as text. Built by hand so the assertion is about the ORDER, not about minting speed.
store7="$tmp/s7/store"; mkdir -p "$store7"
for n in "" -01 -02 -03 -04 -05 -06 -07 -08 -09 -10; do
    printf '# route\tinstall.sh\ninstalled\tpkg%s\trepo\t\n' "${n:-00}" > "$store7/20260101-121212$n.tsv"
done
lst7="$(RICE_INSTALL_RECORD_DIR="$store7" PATH="$BIN_PATH" bash "$IR" list 2>&1)"
assert_eq "20260101-121212-10" "$(printf '%s\n' "$lst7" | head -n1 | cut -f1)" \
    "AC-6: the tenth record of a second leads the listing"
assert_eq "20260101-121212" "$(printf '%s\n' "$lst7" | tail -n1 | cut -f1)" \
    "AC-6: the first record of that second is listed last"
assert_eq "11" "$(printf '%s\n' "$lst7" | grep -c .)" "AC-6: every record in the store is listed"

shown="$(PATH="$stub:$BIN_PATH" bash "$IR" show "$rec_id" 2>&1)"; srr=$?
assert_eq "0" "$srr" "AC-6: show <id> prints that record"
assert_out_has "waybar" "$shown" "AC-6: the shown record names every package it recorded"
assert_out_has "wl-screenrec" "$shown" "AC-6: the shown record includes the failure"
assert_out_has "built from source" "$shown" "AC-6: the shown record reads as prose, not raw TSV"

nos="$(PATH="$stub:$BIN_PATH" bash "$IR" show 19700101-000000 2>&1)"; nrc=$?
assert_eq "3" "$nrc" "AC-6: an unknown identifier is reported, not invented"
assert_out_has "no install record" "$nos" "AC-6: the unknown identifier is named"

# The engine's own CLI is the route a user has: no path knowledge required.
export RICE_DIR="$HOME/.config/hypr-rice"
PATH="$BIN_PATH" bash "$PLUGIN_ROOT/skills/rice/scripts/rice-init.sh" >/dev/null 2>&1
assert_file_exists "$RICE_DIR/install-record.sh" "AC-6: rice-init installs the record component beside the engine"
cli="$(PATH="$BIN_PATH" bash "$RICE_DIR/rice" installs 2>&1)"; clirc=$?
assert_eq "0" "$clirc" "AC-6: 'rice installs' runs from the installed engine"
assert_out_has "$rec_id" "$cli" "AC-6: 'rice installs' lists the recorded transaction"
cli="$(PATH="$BIN_PATH" bash "$RICE_DIR/rice" installs "$rec_id" 2>&1)"
assert_out_has "waybar" "$cli" "AC-6: 'rice installs <id>' prints that record in full"
unset RICE_DIR

# =============================================================================================
# AC-8  an ad-hoc package list records in the same form and the same place as a scripted install
# =============================================================================================
s2="$tmp/s2"; stub2="$s2/stubs"
export HOME="$s2/home"; mkdir -p "$HOME"
mk_arch_stubs "$stub2" "rofi mako" "mako" ""

scripted="$(PATH="$stub2:$BIN_PATH" bash "$IP" --route install.sh --noconfirm rofi mako 2>&1)"
sp="$(field INSTALL_RECORD "$scripted")"
mk_arch_stubs "$stub2" "rofi mako" "mako" ""
adhoc="$(PATH="$stub2:$BIN_PATH" bash "$IP" --noconfirm rofi mako 2>&1)"
ap="$(field INSTALL_RECORD "$adhoc")"

assert_eq "$(dirname "$sp")" "$(dirname "$ap")" "AC-8: the ad-hoc route records in the same place as the scripted one"
sbody="$(grep -v '^#' "$sp" 2>/dev/null)"
abody="$(grep -v '^#' "$ap" 2>/dev/null)"
assert_eq "$sbody" "$abody" "AC-8: the ad-hoc route records in the same form as the scripted one"
assert_out_has "# route	package-list" "$(cat "$ap")" "AC-8: the record still says which route wrote it"

# =============================================================================================
# AC-9  a record that cannot be written: reported by path, transaction still printed, and the
#       install NOT reported as recorded
# =============================================================================================
s3="$tmp/s3"; stub3="$s3/stubs"
export HOME="$s3/home"; mkdir -p "$HOME"
mk_arch_stubs "$stub3" "rofi" "" ""
# A regular file where the store's parent directory belongs: `mkdir -p` cannot succeed, whoever
# is running (a permission bit would not bind as root, and CI may be root).
printf 'not a directory\n' > "$s3/blocked"
blocked_store="$s3/blocked/installs"

out="$(RICE_INSTALL_RECORD_DIR="$blocked_store" PATH="$stub3:$BIN_PATH" \
       bash "$IP" --route install.sh --noconfirm rofi 2>&1)"; rc=$?
assert_out_has "$blocked_store" "$out" "AC-9: the failure names the path it could not write"
assert_out_has "INSTALL_RECORD_FAILED=" "$out" "AC-9: the failure is reported as such"
assert_out_has "installed" "$out" "AC-9: the full transaction is still printed"
assert_out_has "rofi" "$out" "AC-9: the printed transaction names the package"
assert_out_has "INSTALL_RECORD=unwritten" "$out" "AC-9: the install is not reported as recorded"
if printf '%s\n' "$out" | grep -qE '^INSTALL_RECORD=/'; then
    fail "AC-9: no record path is claimed when none was written" "$out"
else
    pass "AC-9: no record path is claimed when none was written"
fi
assert_eq "1" "$rc" "AC-9: the run does not report success when the record was not written"

# =============================================================================================
# AC-10  an empty listing says so plainly and exits zero
# =============================================================================================
s4="$tmp/s4"
export HOME="$s4/home"; mkdir -p "$HOME"
out="$(PATH="$BIN_PATH" bash "$IR" list 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-10: an empty listing exits zero rather than reporting an error"
assert_out_has "no install has been recorded yet" "$out" "AC-10: an empty listing says so plainly"

# =============================================================================================
# AC-11  an install where nothing was installed, skipped or failed leaves no record
# =============================================================================================
out="$(printf '' | PATH="$BIN_PATH" bash "$IR" record --route install.sh 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-11: an empty transaction is not an error"
assert_out_has "INSTALL_RECORD=empty" "$out" "AC-11: an empty transaction says nothing was recorded"
if [ -d "$HOME/.local/state/hypr-rice/installs" ] && \
   [ -n "$(find "$HOME/.local/state/hypr-rice/installs" -name '*.tsv' 2>/dev/null)" ]; then
    fail "AC-11: no record claims a transaction that did not happen" "a record file exists"
else
    pass "AC-11: no record claims a transaction that did not happen"
fi

# An unknown status is dropped rather than persisted as a package outcome nobody defined.
out="$(printf 'maybe\tsomething\n' | PATH="$BIN_PATH" bash "$IR" record --route install.sh 2>&1)"
assert_out_has "INSTALL_RECORD_DROPPED=maybe" "$out" "AC-11: an unknown status is reported and dropped"
assert_out_has "INSTALL_RECORD=empty" "$out" "AC-11: dropping every line leaves no record"

# =============================================================================================
# The component refuses to install at all when it cannot record. An install nobody can look up
# afterwards is the defect this path exists to close, so it is a refusal, not a warning.
# =============================================================================================
s5="$tmp/s5"; stub5="$s5/stubs"
export HOME="$s5/home"; mkdir -p "$HOME"
mk_arch_stubs "$stub5" "rofi" "" ""
mkdir -p "$s5/lone/scripts"
cp "$IP" "$s5/lone/scripts/install-packages.sh"
out="$( unset CLAUDE_PLUGIN_ROOT; PATH="$stub5:$BIN_PATH" bash "$s5/lone/scripts/install-packages.sh" --noconfirm rofi 2>&1 )"; rc=$?
assert_eq "2" "$rc" "no recorder: the install refuses rather than installing unrecorded"
assert_out_has "install-record.sh" "$out" "no recorder: the refusal names what is missing"
if grep -q 'pacman -S' "$stub5/.log" 2>/dev/null; then
    fail "no recorder: nothing was installed" "$(cat "$stub5/.log")"
else
    pass "no recorder: nothing was installed"
fi

export HOME="$tmp/home"

#!/usr/bin/env bash
# scripts/ensure-python.sh - the interpreter the generation path assumes is made present, or
# its absence is reported plainly.
#
# Why this test exists: the reference layer asserted that Arch's `pacman` pulls in `python3` as
# a base dependency, and the whole generation path was built on it - `answers.py` and
# `record-answer.py` run during the interview, long before `install.sh` exists. The claim is
# false. `base` depends on 28 packages and python is not one of them; `pacman` lists python only
# as a CHECK dependency, which is never installed on a user's machine. On a genuinely minimal
# Arch install the interview could not record a single answer.
#
# Grades:
#   P-1  python already present -> reports present, installs nothing
#   P-2  python absent -> says so, and --check reports without installing
#   P-3  a decline installs nothing and is its own outcome, not a failure
#   P-4  no pacman -> reported as missing, no package manager is invoked at all
#   P-5  an accepted install runs pacman and is written to the install record
#   P-6  the script is bash-only - it cannot depend on the thing it installs

EP="$PLUGIN_ROOT/scripts/ensure-python.sh"
assert_file_exists "$EP" "scripts/ensure-python.sh ships"

tmp="$(mktemp_test_dir python-bootstrap)"
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT
unset RICE_INSTALL_RECORD_DIR
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

out_has() {
    if printf '%s\n' "$2" | grep -qF -- "$1"; then pass "$3"; else
        fail "$3" "missing: $1
--- output ---
$2"
    fi
}
log_lacks() {
    if grep -qE "$2" "$1" 2>/dev/null; then
        fail "$3" "ran but must not have: $(grep -E "$2" "$1")"
    else pass "$3"; fi
}

# python3 is omitted on purpose: this test's whole subject is a machine without it, and a
# python3 inherited from the host would make every "absent" scenario silently pass.
BIN="$(hermetic_bin_path "$tmp/.hermetic-bin" python3)"
assert_hermetic "$BIN" "P-0: no real package manager is reachable from this test"

# `mk <dir> <has-python 0|1> <has-pacman 0|1> <install-succeeds 0|1>`
mk() {
    local d="$1" has_py="$2" has_pac="$3" ok="$4"
    mkdir -p "$d"; : > "$d/.log"
    if [ "$has_py" -eq 1 ]; then
        cat > "$d/python3" <<'S'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"; printf 'python3 %s\n' "$*" >> "$d/.log"; exit 0
S
        chmod +x "$d/python3"
    fi
    if [ "$has_pac" -eq 1 ]; then
        cat > "$d/pacman" <<S
#!/usr/bin/env bash
d="\$(cd "\$(dirname "\$0")" && pwd)"; printf 'pacman %s\n' "\$*" >> "\$d/.log"
if [ "$ok" -eq 1 ]; then
    # A REAL interpreter, not a stub that exits 0. ensure-python.sh records what it installed
    # through install-record.sh, which is Python now - a fake python3 would make the recorder a
    # silent no-op and the "it was recorded" assertion vacuous.
    ln -sf "$(command -v python3)" "\$d/python3"; exit 0
fi
exit 1
S
        chmod +x "$d/pacman"
        cat > "$d/sudo" <<'S'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"; printf 'sudo %s\n' "$*" >> "$d/.log"; exec "$@"
S
        chmod +x "$d/sudo"
    fi
}

# --- P-1  already present -------------------------------------------------------------------
s1="$tmp/present"; mk "$s1" 1 1 1
out="$(PATH="$s1:$BIN" HOME="$tmp/h1" bash "$EP" 2>&1)"; rc=$?
out_has "PYTHON=present" "$out" "P-1: an installed python3 is reported as present"
assert_eq "0" "$rc" "P-1: present exits zero"
log_lacks "$s1/.log" '^pacman ' "P-1: nothing was installed when python was already there"

# --- P-2  absent, --check ---------------------------------------------------------------------
s2="$tmp/check"; mk "$s2" 0 1 1
out="$(PATH="$s2:$BIN" HOME="$tmp/h2" bash "$EP" --check 2>&1)"; rc=$?
out_has "PYTHON=missing" "$out" "P-2: --check reports a missing python"
out_has "NOT part of Arch" "$out" "P-2: it says why a minimal Arch box may not have it"
assert_eq "1" "$rc" "P-2: --check exits non-zero when python is missing"
log_lacks "$s2/.log" '^pacman ' "P-2: --check installs nothing"

# --- P-3  declined ------------------------------------------------------------------------------
s3="$tmp/declined"; mk "$s3" 0 1 1
out="$(printf 'n\n' | PATH="$s3:$BIN" HOME="$tmp/h3" bash "$EP" 2>&1)"; rc=$?
out_has "PYTHON=declined" "$out" "P-3: a decline is its own outcome"
assert_eq "4" "$rc" "P-3: a decline has its own exit status, not a failure's"
log_lacks "$s3/.log" '^pacman ' "P-3: a decline installs nothing"
# An unanswered prompt is a decline, never an assumed yes - same rule as the AUR build.
s3b="$tmp/declined-eof"; mk "$s3b" 0 1 1
out="$(printf '' | PATH="$s3b:$BIN" HOME="$tmp/h3b" bash "$EP" 2>&1)"
out_has "PYTHON=declined" "$out" "P-3: an unanswered prompt is a decline"
log_lacks "$s3b/.log" '^pacman ' "P-3: an unanswered prompt installs nothing"
out="$(PATH="$s3b:$BIN" HOME="$tmp/h3c" bash "$EP" --assume-no 2>&1)"
out_has "PYTHON=declined" "$out" "P-3: --assume-no declines without prompting"

# --- P-4  no pacman -------------------------------------------------------------------------------
s4="$tmp/nopacman"; mk "$s4" 0 0 0
out="$(PATH="$s4:$BIN" HOME="$tmp/h4" bash "$EP" --assume-yes 2>&1)"; rc=$?
out_has "PYTHON=missing" "$out" "P-4: no pacman is reported as missing, not failed"
out_has "No pacman on this host" "$out" "P-4: it names why it will not try"
assert_eq "1" "$rc" "P-4: no pacman exits non-zero"

# --- P-5  accepted install is performed AND recorded ---------------------------------------------
s5="$tmp/install"; mk "$s5" 0 1 1
store="$tmp/rec5"
out="$(printf 'y\n' | RICE_INSTALL_RECORD_DIR="$store" PATH="$s5:$BIN" HOME="$tmp/h5" bash "$EP" 2>&1)"; rc=$?
out_has "PYTHON=installed" "$out" "P-5: an accepted install reports installed"
assert_eq "0" "$rc" "P-5: a successful install exits zero"
if grep -qE '^(sudo )?pacman .*-S' "$s5/.log"; then
    pass "P-5: pacman was invoked to install it"
else
    fail "P-5: pacman was invoked to install it" "log: $(cat "$s5/.log")"
fi
rec="$(find "$store" -name '*.tsv' 2>/dev/null | head -n1)"
if [ -n "$rec" ] && grep -q "python" "$rec"; then
    pass "P-5: the bootstrap install is written to the install record"
else
    fail "P-5: the bootstrap install is written to the install record" \
        "no record naming python under $store"
fi
if [ -n "$rec" ] && grep -q "ensure-python" "$rec"; then
    pass "P-5: the record names the route that installed it"
else
    fail "P-5: the record names the route that installed it" "record: $(cat "$rec" 2>/dev/null)"
fi

# --- P-5b  a failed install is reported as failed, not as success -------------------------------
s5b="$tmp/installfail"; mk "$s5b" 0 1 0
out="$(printf 'y\n' | PATH="$s5b:$BIN" HOME="$tmp/h5b" bash "$EP" 2>&1)"; rc=$?
out_has "PYTHON=failed" "$out" "P-5b: a failed install reports failed"
assert_eq "1" "$rc" "P-5b: a failed install exits non-zero"

# --- P-6  the bootstrap cannot depend on what it installs ---------------------------------------
# It is the one script here that must run before python exists, so it may not invoke python at
# all - not even the helpers this repo otherwise routes everything through.
# Only actual invocations count - the word "python" inside a printf message is not a dependency.
bad="$(grep -nE '(^|[;&|(]|\$\()[[:space:]]*(exec[[:space:]]+)?python3?[[:space:]]' "$EP" \
       | grep -vE '^[0-9]+:[[:space:]]*#' \
       | grep -vE "command -v python3" || true)"
if [ -z "$bad" ]; then
    pass "P-6: the bootstrap never executes python (it runs before python exists)"
else
    fail "P-6: the bootstrap never executes python (it runs before python exists)" "$bad"
fi
if head -n1 "$EP" | grep -q 'bash'; then
    pass "P-6: the bootstrap is a bash script"
else
    fail "P-6: the bootstrap is a bash script" "shebang: $(head -n1 "$EP")"
fi

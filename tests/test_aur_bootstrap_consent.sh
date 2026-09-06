#!/usr/bin/env bash
# S0037-hyprland-config-install-7 - name what you are about to build, and ask first.
#
# Grades:
#   AC-2   when the install would build an AUR helper from source, it names what it is about to
#          build and the URL it comes from, and requires confirmation before building
#   AC-12  the confirmation names the package, states that it will be built from source on this
#          machine, and shows the repository URL, before any clone or build begins
#   AC-13  a declined confirmation clones nothing, builds nothing, installs no AUR package, and
#          reports that it stopped because the build was declined - distinctly from a build that
#          failed
#
# The whole point is that nothing is cloned or built, so every package tool is a stub that only
# LOGS what it was asked to do. An assertion here that actually ran makepkg would be a bug.

PS="$PLUGIN_ROOT/scripts"
IP="$PS/install-packages.sh"
IR="$PS/install-record.sh"
AUR_URL="https://aur.archlinux.org/paru.git"

tmp="$(mktemp_test_dir aur-consent)"
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

unset XDG_CONFIG_HOME XDG_STATE_HOME RICE_DIR RICE_APPLY_ID RICE_INSTALL_RECORD_DIR
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
BIN_PATH="/usr/bin:/bin"

field() { printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -n1; }
assert_out_has() {
    if printf '%s\n' "$2" | grep -qF -- "$1"; then pass "$3"; else
        fail "$3" "missing: $1
--- output ---
$2"
    fi
}
assert_log_lacks() {   # <log> <pattern> <name>
    if grep -qE "$2" "$1" 2>/dev/null; then
        fail "$3" "ran but must not have: $(grep -E "$2" "$1")"
    else
        pass "$3"
    fi
}

# `mk_stubs <dir> <build-succeeds 0|1>` - an Arch with no AUR helper installed. Every tool logs.
mk_stubs() {
    local d="$1" build_ok="$2"
    mkdir -p "$d"
    rm -f "$d/paru" "$d/yay"
    : > "$d/.log"
    : > "$d/.installed"
    printf 'waybar\n' > "$d/.repo"
    cat > "$d/pacman" <<'STUB'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"
printf 'pacman %s\n' "$*" >> "$d/.log"
case "${1:-}" in
    -Qq|-Q) grep -Fxq -- "${2:-}" "$d/.installed" 2>/dev/null && exit 0; exit 1 ;;
    -Si)    grep -qw -- "${2:-}" "$d/.repo" 2>/dev/null && exit 0; exit 1 ;;
    -S)     for a in "$@"; do case "$a" in -*) continue ;; esac
                grep -Fxq -- "$a" "$d/.installed" 2>/dev/null || printf '%s\n' "$a" >> "$d/.installed"
            done; exit 0 ;;
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
[ "${1:-}" = "clone" ] && mkdir -p "${3:-}"
exit 0
STUB
    if [ "$build_ok" -eq 1 ]; then
        cat > "$d/makepkg" <<'STUB'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"
printf 'makepkg %s\n' "$*" >> "$d/.log"
cat > "$d/paru" <<'PARU'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"
printf 'paru %s\n' "$*" >> "$d/.log"
[ "${1:-}" = "--version" ] && { echo "paru v2.0.0"; exit 0; }
if [ "${1:-}" = "-S" ]; then
    for a in "$@"; do case "$a" in -*) continue ;; esac
        grep -Fxq -- "$a" "$d/.installed" 2>/dev/null || printf '%s\n' "$a" >> "$d/.installed"
    done
fi
exit 0
PARU
chmod +x "$d/paru"
exit 0
STUB
    else
        cat > "$d/makepkg" <<'STUB'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"
printf 'makepkg %s\n' "$*" >> "$d/.log"
echo "==> ERROR: A failure occurred in build()." >&2
exit 1
STUB
    fi
    chmod +x "$d/pacman" "$d/sudo" "$d/git" "$d/makepkg"
}

# =============================================================================================
# AC-2 / AC-12 / AC-13  the confirmation is declined
# =============================================================================================
d1="$tmp/declined"; stub="$d1/stubs"
export HOME="$d1/home"; mkdir -p "$HOME"
mk_stubs "$stub" 1

out="$(printf 'n\n' | PATH="$stub:$BIN_PATH" bash "$IP" --route install.sh --noconfirm hyprshade 2>&1)"; rc=$?

assert_out_has "AUR_BUILD_REQUIRED=paru"   "$out" "AC-12: the disclosure names the package it would build"
assert_out_has "BUILT FROM SOURCE on this machine" "$out" "AC-12: it says the package would be built from source on this machine"
assert_out_has "AUR_BUILD_URL=$AUR_URL"    "$out" "AC-12: it shows the repository URL it would be cloned from"
assert_out_has "Nothing has been cloned, built or installed from the AUR yet." "$out" \
    "AC-12: the disclosure is made before any clone or build, and says so"
assert_out_has "hyprshade" "$out" "AC-12: the disclosure names the AUR packages that need the helper"

assert_out_has "AUR_BOOTSTRAP=declined" "$out" "AC-13: a decline is reported as a decline"
assert_out_has "INSTALL=declined-aur-build" "$out" \
    "AC-13: the verdict says it stopped because the build was declined"
assert_eq "4" "$rc" "AC-13: a decline has its own exit status, not a failure's"

assert_log_lacks "$stub/.log" '^git '     "AC-13: nothing was cloned"
assert_log_lacks "$stub/.log" '^makepkg ' "AC-13: nothing was built"
assert_log_lacks "$stub/.log" '^paru '    "AC-13: no AUR package was installed"
if grep -Fxq "hyprshade" "$stub/.installed" 2>/dev/null; then
    fail "AC-13: the AUR package was not installed" "hyprshade is in the stubbed installed set"
else
    pass "AC-13: the AUR package was not installed"
fi

# The record still names what did not happen, and why.
rec="$(field INSTALL_RECORD "$out")"
if [ -n "$rec" ] && grep -q '^failed	hyprshade	aur	.*declined' "$rec" 2>/dev/null; then
    pass "AC-13: the record names the package as failed with the decline as its reason"
else
    fail "AC-13: the record names the package as failed with the decline as its reason" \
        "record=$rec
$(cat "$rec" 2>/dev/null)"
fi

# =============================================================================================
# AC-2  the build really is gated on the answer: no answer at all is a decline, not a build
# =============================================================================================
d2="$tmp/noanswer"; stub2="$d2/stubs"
export HOME="$d2/home"; mkdir -p "$HOME"
mk_stubs "$stub2" 1
out="$(PATH="$stub2:$BIN_PATH" bash "$IP" --noconfirm hyprshade < /dev/null 2>&1)"; rc=$?
assert_out_has "AUR_BOOTSTRAP=declined" "$out" "AC-2: with no answer at all the build does not happen"
assert_eq "4" "$rc" "AC-2: an unanswered confirmation is a decline, not an assumed yes"
assert_log_lacks "$stub2/.log" '^makepkg ' "AC-2: an unanswered confirmation builds nothing"

# ... and --assume-no is the same answer for an unattended run.
mk_stubs "$stub2" 1
out="$(PATH="$stub2:$BIN_PATH" bash "$IP" --noconfirm --assume-no hyprshade 2>&1)"
assert_out_has "AUR_BOOTSTRAP=declined" "$out" "AC-2: --assume-no declines without prompting"
assert_log_lacks "$stub2/.log" '^git ' "AC-2: --assume-no clones nothing"

# =============================================================================================
# AC-2 / AC-12  the confirmation is accepted: only then is anything cloned or built
# =============================================================================================
d3="$tmp/accepted"; stub3="$d3/stubs"
export HOME="$d3/home"; mkdir -p "$HOME"
mk_stubs "$stub3" 1
out="$(printf 'y\n' | PATH="$stub3:$BIN_PATH" bash "$IP" --route install.sh --noconfirm hyprshade 2>&1)"; rc=$?

assert_out_has "AUR_BUILD_URL=$AUR_URL" "$out" "AC-12: the accepted path disclosed the URL too"
assert_out_has "AUR_BOOTSTRAP=built" "$out" "AC-2: an accepted confirmation builds the helper"
if grep -q "^git clone $AUR_URL" "$stub3/.log"; then
    pass "AC-2: the clone used the URL that was disclosed"
else
    fail "AC-2: the clone used the URL that was disclosed" "$(cat "$stub3/.log")"
fi
if grep -q '^makepkg -si' "$stub3/.log"; then
    pass "AC-2: the helper was built from source with makepkg"
else
    fail "AC-2: the helper was built from source with makepkg" "$(cat "$stub3/.log")"
fi
rec="$(field INSTALL_RECORD "$out")"
if [ -n "$rec" ] && grep -q "^built-from-source	paru	$AUR_URL" "$rec" 2>/dev/null; then
    pass "AC-2: the source build is recorded as a source build, not a repository install"
else
    fail "AC-2: the source build is recorded as a source build" "record=$rec
$(cat "$rec" 2>/dev/null)"
fi
assert_out_has "INSTALL=ok" "$out" "AC-2: the accepted path installs the AUR package it needed the helper for"

# =============================================================================================
# AC-13  a build that FAILS reads differently from a build that was declined
# =============================================================================================
d4="$tmp/buildfail"; stub4="$d4/stubs"
export HOME="$d4/home"; mkdir -p "$HOME"
mk_stubs "$stub4" 0
out="$(printf 'y\n' | PATH="$stub4:$BIN_PATH" bash "$IP" --route install.sh --noconfirm hyprshade 2>&1)"; rc=$?
assert_out_has "AUR_BOOTSTRAP=failed" "$out" "AC-13: a failed build reports as failed"
assert_out_has "INSTALL=failed" "$out" "AC-13: a failed build's verdict is not the decline's verdict"
assert_eq "1" "$rc" "AC-13: a failed build exits differently from a decline"
rec="$(field INSTALL_RECORD "$out")"
if [ -n "$rec" ] && grep -q 'source build failed' "$rec" 2>/dev/null; then
    pass "AC-13: the record distinguishes a failed build from a declined one"
else
    fail "AC-13: the record distinguishes a failed build from a declined one" "$(cat "$rec" 2>/dev/null)"
fi

# =============================================================================================
# The confirmation is the BUILD's, not the install's: with a working helper already present
# nothing is disclosed and nothing is asked.
# =============================================================================================
d5="$tmp/helper-present"; stub5="$d5/stubs"
export HOME="$d5/home"; mkdir -p "$HOME"
mk_stubs "$stub5" 1
cat > "$stub5/paru" <<'PARU'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"
printf 'paru %s\n' "$*" >> "$d/.log"
[ "${1:-}" = "--version" ] && { echo "paru v2.0.0"; exit 0; }
if [ "${1:-}" = "-S" ]; then
    for a in "$@"; do case "$a" in -*) continue ;; esac
        grep -Fxq -- "$a" "$d/.installed" 2>/dev/null || printf '%s\n' "$a" >> "$d/.installed"
    done
fi
exit 0
PARU
chmod +x "$stub5/paru"
out="$(PATH="$stub5:$BIN_PATH" bash "$IP" --noconfirm hyprshade < /dev/null 2>&1)"
assert_out_has "AUR_HELPER=paru" "$out" "an existing working helper is used"
if printf '%s\n' "$out" | grep -q 'AUR_BUILD_REQUIRED='; then
    fail "no disclosure when nothing would be built" "$out"
else
    pass "no disclosure when nothing would be built"
fi
assert_log_lacks "$stub5/.log" '^makepkg ' "nothing is built when a helper already works"

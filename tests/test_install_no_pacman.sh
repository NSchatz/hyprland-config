#!/usr/bin/env bash
# S0037-hyprland-config-install-7 - regression guard: no pacman, no install.
#
# This is already the behaviour; it is written down here so it cannot regress quietly. Nothing in
# this file changes what the plugin does on a non-Arch host.
#
# Grades:
#   AC-5   IF the host has no pacman THEN the package list is printed and nothing is installed
#   AC-24  no package manager and no AUR helper is invoked AT ALL, and the non-Arch outcome reads
#          distinctly from a failed install

PS="$PLUGIN_ROOT/scripts"
IP="$PS/install-packages.sh"

tmp="$(mktemp_test_dir install-no-pacman)"
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

unset XDG_CONFIG_HOME XDG_STATE_HOME RICE_DIR RICE_APPLY_ID RICE_INSTALL_RECORD_DIR
export HOME="$tmp/home"; mkdir -p "$HOME"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
BIN_PATH="/usr/bin:/bin"

assert_out_has() {
    if printf '%s\n' "$2" | grep -qF -- "$1"; then pass "$3"; else
        fail "$3" "missing: $1
--- output ---
$2"
    fi
}

# A host with every package tool EXCEPT pacman. Each one logs the moment it is invoked, so
# "invoked nothing" is an assertion about a file, not about the absence of an error.
stub="$tmp/stubs"; mkdir -p "$stub"
: > "$stub/.log"
for t in paru yay sudo makepkg git; do
    cat > "$stub/$t" <<STUB
#!/usr/bin/env bash
printf '$t %s\n' "\$*" >> "$stub/.log"
exit 0
STUB
    chmod +x "$stub/$t"
done

if PATH="$BIN_PATH" command -v pacman >/dev/null 2>&1; then
    skip "AC-5: no-pacman behaviour" "this host HAS pacman; the non-Arch path cannot be exercised here"
else
    out="$(PATH="$stub:$BIN_PATH" bash "$IP" --route install.sh waybar wofi mako 2>&1)"; rc=$?

    # AC-5: the list is printed ...
    assert_out_has "PACKAGES=waybar wofi mako" "$out" "AC-5: the package list is printed"
    for p in waybar wofi mako; do
        assert_out_has "  $p" "$out" "AC-5: the list names $p, so it can be installed by hand"
    done
    assert_out_has "PACMAN=absent" "$out" "AC-5: it says why nothing was installed"

    # ... and nothing is installed.
    if [ -s "$stub/.log" ]; then
        fail "AC-24: no package manager and no AUR helper was invoked" "$(cat "$stub/.log")"
    else
        pass "AC-24: no package manager and no AUR helper was invoked at all"
    fi

    # AC-24: the outcome is its own, not a failure's.
    assert_out_has "INSTALL=skipped (non-arch)" "$out" "AC-24: the non-Arch outcome is reported as skipped"
    if printf '%s\n' "$out" | grep -qE '^INSTALL=(failed|partial)'; then
        fail "AC-24: a non-Arch host is not reported as a failed install" "$out"
    else
        pass "AC-24: a non-Arch host is not reported as a failed install"
    fi
    assert_eq "0" "$rc" "AC-24: skipping on a non-Arch host is not an error exit"

    # Nothing was installed, nothing was already present, nothing failed: there was no
    # transaction, so there is no record inventing one.
    if [ -n "$(find "$HOME/.local/state/hypr-rice/installs" -name '*.tsv' 2>/dev/null)" ]; then
        fail "AC-24: no record claims an install that never happened" \
            "$(find "$HOME/.local/state/hypr-rice/installs" -name '*.tsv')"
    else
        pass "AC-24: no record claims an install that never happened"
    fi

    # AC-24: distinct from a failed install. With pacman present but the install itself failing,
    # the same script reports `failed` and exits non-zero - a different verdict and a different
    # exit code from the non-Arch skip.
    fstub="$tmp/failing"; mkdir -p "$fstub"
    cat > "$fstub/pacman" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
    -Qq|-Q) exit 1 ;;
    -Si)    exit 0 ;;
esac
echo "error: failed to commit transaction: ${*: -1}" >&2
echo "error: failed to commit transaction: ${*: -1}"
exit 1
STUB
    printf '#!/usr/bin/env bash\nexec "$@"\n' > "$fstub/sudo"
    chmod +x "$fstub/pacman" "$fstub/sudo"
    fout="$(PATH="$fstub:$BIN_PATH" bash "$IP" --assume-no --route install.sh waybar 2>&1)"; frc=$?
    assert_out_has "INSTALL=failed" "$fout" "AC-24: a real failure reports as a failure"
    if printf '%s\n' "$fout" | grep -q 'INSTALL=skipped (non-arch)'; then
        fail "AC-24: a real failure is not reported as the non-Arch outcome" "$fout"
    else
        pass "AC-24: a real failure is not reported as the non-Arch outcome"
    fi
    if [ "$frc" -eq "$rc" ]; then
        fail "AC-24: a failed install exits differently from a skipped one" "both exited $rc"
    else
        pass "AC-24: a failed install exits differently from a skipped one (skipped=$rc, failed=$frc)"
    fi
fi

#!/usr/bin/env bash
# `scripts/ricelib/xdg.py` - the ONE decision about where configuration lives.
#
# This replaces tests/test_xdg_parity.sh, which drove a bash and a Python resolver through the
# same environments and diffed them. That test existed only while both implementations did, and
# it did its job: the bash resolver is gone and the Python one is the single answer. What
# survives is the coverage - the same 13-environment matrix, asserted against the rule directly
# rather than against a second implementation.
#
# The rule, in order:
#   1. an explicit override wins outright, whatever XDG_CONFIG_HOME holds
#   2. else $XDG_CONFIG_HOME when it is ABSOLUTE
#   3. else $HOME/.config
#   4. else nothing: refuse and write nothing
#
# A RELATIVE XDG_CONFIG_HOME is invalid per the XDG base directory specification, so it is
# ignored AND the fallback is announced - a silent fallback is how a user ends up with a config
# they cannot find.
#
# Grades:
#   X-1  the base resolves per the rule, across the matrix
#   X-2  an unresolvable environment REFUSES rather than inventing a path
#   X-3  an override wins outright, and surfaces hang off the base
#   X-4  `~` expansion is config-aware: `~/.config/...` follows the base, everything else $HOME
#   X-5  a rejected relative value is announced, not taken in silence

PY="$PLUGIN_ROOT/scripts/ricelib/xdg.py"
assert_file_exists "$PY" "the config-path resolver ships"

if ! command -v python3 >/dev/null 2>&1; then
    skip "xdg resolver" "python3 missing"
    return 0
fi

tmp="$(mktemp_test_dir xdg-resolver)"
trap 'rm -rf "$tmp"' EXIT

# `resolve <cmd> <args...>` in a scrubbed environment; SET_HOME / SET_XCH steer it.
run_xdg() {
    env -i PATH="$PATH" PYTHONPATH="$PLUGIN_ROOT/scripts" \
        ${SET_HOME+HOME="$SET_HOME"} ${SET_XCH+XDG_CONFIG_HOME="$SET_XCH"} \
        python3 -m ricelib.xdg "$@" 2>/dev/null
}
run_xdg_rc() {
    env -i PATH="$PATH" PYTHONPATH="$PLUGIN_ROOT/scripts" \
        ${SET_HOME+HOME="$SET_HOME"} ${SET_XCH+XDG_CONFIG_HOME="$SET_XCH"} \
        python3 -m ricelib.xdg "$@" >/dev/null 2>&1
}

H="$tmp/home"; X="$tmp/xdg"
mkdir -p "$H" "$X"

# label | HOME | XDG_CONFIG_HOME | expected base ("REFUSE" when nothing may resolve)
# UNSET means the variable is not exported at all, which differs from empty.
MATRIX=(
    "plain home|$H|UNSET|$H/.config"
    "empty xch|$H||$H/.config"
    "absolute xch|$H|$X|$X"
    "absolute xch, trailing slash|$H|$X/|$X"
    "absolute xch, many slashes|$H|$X///|$X"
    "RELATIVE xch is invalid|$H|relative/cfg|$H/.config"
    "relative xch, dotted|$H|./cfg|$H/.config"
    "home with trailing slash|$H/|UNSET|$H/.config"
    "home is root|/|UNSET|/.config"
    "no home, absolute xch|UNSET|$X|$X"
    "no home, relative xch|UNSET|rel|REFUSE"
    "no home, no xch|UNSET|UNSET|REFUSE"
    "no home, empty xch|UNSET||REFUSE"
)

for row in "${MATRIX[@]}"; do
    label="${row%%|*}"; rest="${row#*|}"
    h="${rest%%|*}"; rest="${rest#*|}"
    x="${rest%%|*}"; want="${rest#*|}"
    unset SET_HOME SET_XCH
    [ "$h" != "UNSET" ] && SET_HOME="$h"
    [ "$x" != "UNSET" ] && SET_XCH="$x"

    got="$(run_xdg path "" "")"
    if [ "$want" = "REFUSE" ]; then
        # X-2  nothing resolvable: refuse, print no path, exit non-zero.
        assert_eq "" "$got" "X-2: [$label] no path is invented"
        if run_xdg_rc path "" ""; then
            fail "X-2: [$label] an unresolvable environment exits non-zero" "it exited 0"
        else
            pass "X-2: [$label] an unresolvable environment exits non-zero"
        fi
        continue
    fi

    assert_eq "$want" "$got" "X-1: [$label] the base resolves per the rule"
    assert_eq "$want/hypr" "$(run_xdg path hypr "")" "X-3: [$label] hypr hangs off the base"
    assert_eq "$want/hypr-rice" "$(run_xdg path hypr-rice "")" "X-3: [$label] hypr-rice too"
    assert_eq "$tmp/override" "$(run_xdg path hypr "$tmp/override")" \
        "X-3: [$label] an explicit override wins outright"

    # X-4  `~` expansion: the CONFIG surface follows the base, every other base does not.
    assert_eq "$want" "$(run_xdg expand '~/.config')" "X-4: [$label] ~/.config follows the base"
    assert_eq "$want/waybar/colors.css" "$(run_xdg expand '~/.config/waybar/colors.css')" \
        "X-4: [$label] a config surface follows the base"
    # `~` is replaced by $HOME verbatim, so a HOME with a trailing slash yields `//` - the same
    # path to the kernel, and the behaviour every version of this resolver has had. Asserted as
    # it is rather than as it might look nicer.
    # With HOME unset, `$HOME` is empty, so `~/x` becomes `/x`. The row's literal is UNSET.
    home_expand="$h"; [ "$h" = "UNSET" ] && home_expand=""
    assert_eq "${home_expand}/.cache/hypr-rice/x.png" "$(run_xdg expand '~/.cache/hypr-rice/x.png')" \
        "X-4: [$label] a CACHE path still expands under \$HOME"
    assert_eq "${home_expand}/Pictures/wallpapers" "$(run_xdg expand '~/Pictures/wallpapers')" \
        "X-4: [$label] a user dir still expands under \$HOME"
    assert_eq "/absolute/unchanged" "$(run_xdg expand /absolute/unchanged)" \
        "X-4: [$label] an absolute path is returned unchanged"
    assert_eq "relative/unchanged" "$(run_xdg expand relative/unchanged)" \
        "X-4: [$label] a bare relative path is returned unchanged"
done

# --- X-5  a rejected relative value is ANNOUNCED ------------------------------------------------
unset SET_HOME SET_XCH; SET_HOME="$H"; SET_XCH="relative/cfg"
out="$(run_xdg target hypr "")"
if printf '%s\n' "$out" | grep -q '^XDG_CONFIG_HOME_IGNORED=relative/cfg$'; then
    pass "X-5: the rejected value is named"
else
    fail "X-5: the rejected value is named" "$out"
fi
if printf '%s\n' "$out" | grep -q 'which the XDG base directory specification says is invalid'; then
    pass "X-5: and the notice says why it was rejected"
else
    fail "X-5: and the notice says why it was rejected" "$out"
fi
assert_eq "$H/.config/hypr" "$(printf '%s\n' "$out" | tail -n1)" \
    "X-5: the absolute path actually used is printed after the notice"

# An ABSOLUTE value is not reported as ignored - the notice is for rejections only.
SET_XCH="$X"
out="$(run_xdg target hypr "")"
if printf '%s\n' "$out" | grep -q 'XDG_CONFIG_HOME_IGNORED'; then
    fail "X-5: an absolute value is not reported as ignored" "$out"
else
    pass "X-5: an absolute value is not reported as ignored"
fi

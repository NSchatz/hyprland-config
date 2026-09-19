#!/usr/bin/env bash
# The bash and Python config-path resolvers must give the SAME answer, always.
#
# `scripts/xdg-config.sh` is sourced by scripts that run before python exists on the machine -
# `detect-version.sh` during detection, and `safe-apply.sh` / `install-config.sh` /
# `reset-config.sh` / `backup-config.sh` on the write path this plugin's whole invariant rests
# on. Putting a python dependency under those would add a new way for a backup to fail, so the
# bash implementation stays.
#
# `scripts/ricelib/xdg.py` exists because the ported cluster (restore points, the install
# record, the renderer) is Python and shelling out per call would be both slow and circular.
#
# Two implementations of one rule is a split waiting to happen - which is the exact failure
# `scripts/xdg-config.sh` was written to end. So it is allowed only with this test: the same
# environment matrix through both, asserting identical answers. If they ever disagree, this
# goes red and names the environment that separated them.
#
# Grades:
#   X-1  base resolution agrees across the matrix (path and source)
#   X-2  the refusal cases agree (both refuse, neither invents a path)
#   X-3  surface paths agree, including overrides
#   X-4  `~` expansion agrees, including the config-aware `~/.config/...` case

SH="$PLUGIN_ROOT/scripts/xdg-config.sh"
PY="$PLUGIN_ROOT/scripts/ricelib/xdg.py"
assert_file_exists "$SH" "the bash resolver ships"
assert_file_exists "$PY" "the python resolver ships"

if ! command -v python3 >/dev/null 2>&1; then
    skip "xdg parity" "python3 missing"
    return 0
fi

tmp="$(mktemp_test_dir xdg-parity)"
trap 'rm -rf "$tmp"' EXIT

# `bash_path <name> <override>` - resolve through the sourced bash library.
bash_path() {
    env -i PATH="$PATH" \
        ${SET_HOME+HOME="$SET_HOME"} \
        ${SET_XCH+XDG_CONFIG_HOME="$SET_XCH"} \
        bash -c '. "$1"; xdg_config_path "$2" "$3"' _ "$SH" "$1" "$2" 2>/dev/null
}
py_path() {
    env -i PATH="$PATH" \
        ${SET_HOME+HOME="$SET_HOME"} \
        ${SET_XCH+XDG_CONFIG_HOME="$SET_XCH"} \
        python3 "$PY" path "$1" "$2" 2>/dev/null
}
bash_expand() {
    env -i PATH="$PATH" \
        ${SET_HOME+HOME="$SET_HOME"} \
        ${SET_XCH+XDG_CONFIG_HOME="$SET_XCH"} \
        bash -c '. "$1"; xdg_expand_path "$2"' _ "$SH" "$1" 2>/dev/null
}
py_expand() {
    env -i PATH="$PATH" \
        ${SET_HOME+HOME="$SET_HOME"} \
        ${SET_XCH+XDG_CONFIG_HOME="$SET_XCH"} \
        python3 "$PY" expand "$1" 2>/dev/null
}

# The environment matrix. Each row is "<label>|<HOME>|<XDG_CONFIG_HOME>"; the literal token
# UNSET means the variable is not exported at all (which is different from empty).
MATRIX=(
    "plain home|$tmp/home|UNSET"
    "empty xch|$tmp/home|"
    "absolute xch|$tmp/home|$tmp/xdg"
    "absolute xch, trailing slash|$tmp/home|$tmp/xdg/"
    "absolute xch, many slashes|$tmp/home|$tmp/xdg///"
    "RELATIVE xch (invalid, must be ignored)|$tmp/home|relative/cfg"
    "relative xch, dotted|$tmp/home|./cfg"
    "home with trailing slash|$tmp/home/|UNSET"
    "home is root|/|UNSET"
    "no home, absolute xch|UNSET|$tmp/xdg"
    "no home, relative xch (refusal)|UNSET|rel"
    "no home, no xch (refusal)|UNSET|UNSET"
    "empty home, empty xch (refusal)|UNSET|"
)

for row in "${MATRIX[@]}"; do
    label="${row%%|*}"; rest="${row#*|}"
    h="${rest%%|*}"; x="${rest#*|}"
    unset SET_HOME SET_XCH
    [ "$h" != "UNSET" ] && SET_HOME="$h"
    [ "$x" != "UNSET" ] && SET_XCH="$x"

    # X-1 / X-2  the base, via an empty surface name.
    b_out="$(bash_path "" "")"; b_rc=$?
    p_out="$(py_path "" "")"; p_rc=$?
    assert_eq "$b_out" "$p_out" "X-1: base agrees [$label]"
    assert_eq "$b_rc" "$p_rc" "X-2: base exit status agrees [$label]"

    # X-3  a real surface, and an override that must win outright.
    assert_eq "$(bash_path hypr "")" "$(py_path hypr "")" "X-3: hypr agrees [$label]"
    assert_eq "$(bash_path hypr-rice "")" "$(py_path hypr-rice "")" "X-3: hypr-rice agrees [$label]"
    assert_eq "$(bash_path hypr "$tmp/override")" "$(py_path hypr "$tmp/override")" \
        "X-3: an override wins in both [$label]"

    # X-4  `~` expansion, including the config-aware case that must follow the base.
    for p in '~' '~/' '~/.config' '~/.config/waybar/colors.css' '~/.cache/hypr-rice/x.png' \
             '~/Pictures/wallpapers' '/absolute/unchanged' 'relative/unchanged'; do
        assert_eq "$(bash_expand "$p")" "$(py_expand "$p")" "X-4: expand '$p' agrees [$label]"
    done
done

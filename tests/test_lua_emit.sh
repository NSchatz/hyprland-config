#!/usr/bin/env bash
# LUA-4 / S0018 - the emitter pair and the language decision.
#
# Grades:
#   AC-2  a lua-language version yields a lua configuration
#   AC-3  every generated configuration records the language it emitted and the
#         Hyprland version range that language is valid for
#   AC-5  an undetected version reports what it can emit and requires an explicit
#         choice rather than assuming one
#   AC-6  a hyprlang-language version yields a hyprlang configuration and no lua one
#   AC-12 the plugin states the hyprlang support window the project published
#
# Version selection is driven through HYPR_VERSION / HYPR_CONFIG_LANG so the whole
# file is deterministic and never depends on a Hyprland being installed on the runner.

RS="$PLUGIN_ROOT/skills/rice/scripts"
emit="$RS/emit-config.sh"
langsh="$RS/config-language.sh"

assert_file_exists "$emit" "emit-config.sh ships"
assert_file_exists "$langsh" "config-language.sh ships"

tmp="$(mktemp_test_dir hypr-lua-emit)"

# --------------------------------------------------------------------------------------------
# AC-2 - a lua-language version (0.55 or higher) yields a lua configuration
# --------------------------------------------------------------------------------------------
for v in 0.55.0 0.55 0.56.2 1.0.0; do
    d="$tmp/emit-lua-$v"
    out="$(HYPR_VERSION="$v" bash "$emit" "$d" 2>&1)"; rc=$?
    assert_eq "0" "$rc" "AC-2: $v emits cleanly"
    assert_eq "lua" "$(printf '%s\n' "$out" | sed -n 's/^CONFIG_LANGUAGE=//p' | head -n1)" \
        "AC-2: $v selects the lua language"
    assert_file_exists "$d/hyprland.lua" "AC-2: $v writes hyprland.lua"
    if [ -e "$d/hyprland.conf" ]; then
        fail "AC-2: $v writes no hyprlang .conf" "found $d/hyprland.conf"
    else
        pass "AC-2: $v writes no hyprlang .conf"
    fi
done

luadir="$tmp/emit-lua-0.56.2"
assert_file_contains "$luadir/hyprland.lua" "hl.config({" "AC-2: the lua config uses the lua config API"
assert_file_contains "$luadir/hyprland.lua" "hl.bind(" "AC-2: the lua config binds keys through the lua API"
if grep -qE '^[[:space:]]*bind[[:space:]]*=' "$luadir/hyprland.lua"; then
    fail "AC-2: no hyprlang assignment syntax leaked into the lua config" "found a 'bind =' line"
else
    pass "AC-2: no hyprlang assignment syntax leaked into the lua config"
fi

# --------------------------------------------------------------------------------------------
# AC-6 - a hyprlang-language version (below 0.55) yields hyprlang and NOT lua
# --------------------------------------------------------------------------------------------
for v in 0.54.3 0.50.0 0.42; do
    d="$tmp/emit-conf-$v"
    out="$(HYPR_VERSION="$v" bash "$emit" "$d" 2>&1)"; rc=$?
    assert_eq "0" "$rc" "AC-6: $v emits cleanly"
    assert_eq "hyprlang" "$(printf '%s\n' "$out" | sed -n 's/^CONFIG_LANGUAGE=//p' | head -n1)" \
        "AC-6: $v selects the hyprlang language"
    assert_file_exists "$d/hyprland.conf" "AC-6: $v writes hyprland.conf"
    if [ -e "$d/hyprland.lua" ]; then
        fail "AC-6: $v emits NO lua config" "found $d/hyprland.lua"
    else
        pass "AC-6: $v emits NO lua config"
    fi
done

confdir="$tmp/emit-conf-0.54.3"
assert_grep '^bind = \$mainMod, Return, exec, \$terminal$' "$confdir/hyprland.conf" \
    "AC-6: the hyprlang config keeps the hyprlang bind syntax"

# --------------------------------------------------------------------------------------------
# AC-3 - the generated output says which language it is and what versions it is good for
# --------------------------------------------------------------------------------------------
assert_grep '^-- CONFIG_LANGUAGE=lua$' "$luadir/hyprland.lua" \
    "AC-3: the lua config records the language it was emitted in"
assert_grep '^-- CONFIG_LANGUAGE_RANGE=Hyprland 0\.55 and newer' "$luadir/hyprland.lua" \
    "AC-3: the lua config records the Hyprland range that language is valid for"
assert_file_contains "$confdir/hyprland.conf" "# CONFIG_LANGUAGE=hyprlang" \
    "AC-3: the hyprlang config records the language it was emitted in"
assert_grep '^# CONFIG_LANGUAGE_RANGE=.*deprecated since 0\.55' "$confdir/hyprland.conf" \
    "AC-3: the hyprlang config records the Hyprland range that language is valid for"

lua_out="$(HYPR_VERSION=0.56.2 bash "$emit" "$tmp/emit-ac3" 2>&1)"
if printf '%s\n' "$lua_out" | grep -q '^CONFIG_LANGUAGE_RANGE=Hyprland 0.55 and newer'; then
    pass "AC-3: the emitter also reports the range on stdout for the caller to relay"
else
    fail "AC-3: the emitter also reports the range on stdout for the caller to relay" "$lua_out"
fi

# --------------------------------------------------------------------------------------------
# AC-5 - an undetected version reports the emittable languages and requires a choice
# --------------------------------------------------------------------------------------------
undec="$tmp/emit-undecided"
out="$(HYPR_VERSION=unknown bash "$emit" "$undec" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
    pass "AC-5: an undetected version does not report success"
else
    fail "AC-5: an undetected version does not report success" "exit 0
$out"
fi
assert_eq "undecided" "$(printf '%s\n' "$out" | sed -n 's/^CONFIG_LANGUAGE=//p' | head -n1)" \
    "AC-5: it does not assume a language"
assert_eq "lua hyprlang" "$(printf '%s\n' "$out" | sed -n 's/^EMITTABLE_LANGUAGES=//p' | head -n1)" \
    "AC-5: it reports which languages it can emit"
if printf '%s\n' "$out" | grep -q '^LANGUAGE_OPTION=lua Hyprland 0.55 and newer'; then
    pass "AC-5: it reports the lua option with its version range"
else
    fail "AC-5: it reports the lua option with its version range" "$out"
fi
if printf '%s\n' "$out" | grep -q '^LANGUAGE_OPTION=hyprlang '; then
    pass "AC-5: it reports the hyprlang option with its version range"
else
    fail "AC-5: it reports the hyprlang option with its version range" "$out"
fi
if printf '%s\n' "$out" | grep -qi 'requires an explicit choice'; then
    pass "AC-5: it says an explicit choice is required"
else
    fail "AC-5: it says an explicit choice is required" "$out"
fi
if [ -d "$undec" ] && [ -n "$(ls -A "$undec" 2>/dev/null)" ]; then
    fail "AC-5: it wrote no configuration while undecided" "$(ls -A "$undec")"
else
    pass "AC-5: it wrote no configuration while undecided"
fi

# ...and the explicit choice unblocks it, for either language.
for choice in lua hyprlang; do
    d="$tmp/emit-explicit-$choice"
    out="$(HYPR_VERSION=unknown HYPR_CONFIG_LANG="$choice" bash "$emit" "$d" 2>&1)"; rc=$?
    assert_eq "0" "$rc" "AC-5: an explicit '$choice' choice unblocks the emit"
    assert_eq "$choice" "$(printf '%s\n' "$out" | sed -n 's/^CONFIG_LANGUAGE=//p' | head -n1)" \
        "AC-5: the explicit '$choice' choice is what gets emitted"
    assert_eq "explicit" "$(printf '%s\n' "$out" | sed -n 's/^CONFIG_LANGUAGE_SOURCE=//p' | head -n1)" \
        "AC-5: the '$choice' emit records that the choice was explicit, not detected"
done

# An unknown language name is rejected rather than silently defaulted.
out="$(HYPR_VERSION=unknown HYPR_CONFIG_LANG=perl bash "$emit" "$tmp/emit-bogus" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
    pass "AC-5: a bogus explicit language is rejected"
else
    fail "AC-5: a bogus explicit language is rejected" "exit 0
$out"
fi

# The detection script no longer tells the reader to assume a syntax (task 3).
if grep -q 'assume latest stable syntax' "$RS/detect-version.sh"; then
    fail "AC-5: detect-version.sh no longer says to assume a syntax" "the 'assume latest stable syntax' text is still there"
else
    pass "AC-5: detect-version.sh no longer says to assume a syntax"
fi

# --------------------------------------------------------------------------------------------
# AC-12 - the stated hyprlang support window is the one the project published
# --------------------------------------------------------------------------------------------
# <https://hypr.land/news/26_lua/>: "supported for 1 - 2 releases starting from
# 0.55. After that, hyprlang will be dropped."
mapfile -t shipped < <(
    find "$PLUGIN_ROOT" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.tmpl' \) \
        -not -path '*/.git/*' \
        -not -path '*/tests/*' \
        -not -path '*/.research/*' \
        -not -path '*/CHANGELOG.md' \
    | sort
)
stale=()
for f in "${shipped[@]}"; do
    if grep -qiE 'remains? functional for several releases' "$f"; then
        stale+=("${f#"$PLUGIN_ROOT"/}")
    fi
done
if [ "${#stale[@]}" -eq 0 ]; then
    pass "AC-12: nothing in the shipped tree claims the unsourced 'several releases' window"
else
    detail=""
    for s in "${stale[@]}"; do detail+="$s"$'\n'; done
    fail "AC-12: ${#stale[@]} file(s) still claim 'several releases'" "$detail"
fi

# Every place that states the window states the published one.
window_files=()
for f in "${shipped[@]}"; do
    if grep -qiE 'hyprlang.*(1 - 2|one to two) releases|(1 - 2|one to two) releases.*0\.55' "$f"; then
        window_files+=("$f")
    fi
done
if [ "${#window_files[@]}" -ge 3 ]; then
    pass "AC-12: ${#window_files[@]} places state the published 1 - 2 release window"
else
    fail "AC-12: the published window is stated in too few places" "found ${#window_files[@]}, expected at least 3"
fi

assert_grep '1 - 2 releases starting from' "$langsh" \
    "AC-12: the language resolver carries the published window"
range_out="$(bash "$langsh" --range hyprlang 2>&1)"
case "$range_out" in
    *"1 - 2 releases starting from 0.55"*)
        pass "AC-12: the hyprlang range the plugin prints is the published window" ;;
    *)
        fail "AC-12: the hyprlang range the plugin prints is the published window" "$range_out" ;;
esac
case "$range_out" in
    *"hyprlang is dropped"*)
        pass "AC-12: the range says hyprlang is dropped after that window" ;;
    *)
        fail "AC-12: the range says hyprlang is dropped after that window" "$range_out" ;;
esac

vm="$PLUGIN_ROOT/skills/rice/references/_shared/version-matrix.md"
if grep -qE 'rice still emits `\.conf` on 0\.55\+' "$vm"; then
    fail "AC-12: the version matrix no longer claims rice emits .conf on 0.55+" \
        "the stale row is still there"
else
    pass "AC-12: the version matrix no longer claims rice emits .conf on 0.55+"
fi
assert_grep 'config-language\.sh' "$vm" "AC-12: the version matrix points at the language resolver"

# Boundary (task 8 / phase CURRENCY-8): only the support-window statement is
# corrected here. The reference layer still TEACHES hyprlang syntax.
cs="$PLUGIN_ROOT/skills/hyprland-reference/references/config-syntax.md"
assert_file_contains "$cs" "exec-once = waybar &" \
    "AC-12 boundary: the reference layer's hyprlang syntax teaching is left intact"

rm -rf "$tmp"

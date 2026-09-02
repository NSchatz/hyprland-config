#!/usr/bin/env bash
# LUA-4 / S0018 - the install path's fail-safes.
#
# Grades:
#   AC-1  a target that already holds a hyprland.lua does NOT get a hyprlang .conf
#         installed into it, and the refusal says the lua config takes precedence
#   AC-7  a target that exists but cannot be written to is reported by path with the
#         permission failure, is left completely unmodified, and exits non-zero
#   AC-8  an absent or empty target installs without claiming a backup it did not
#         take, and still records the emitted language and its version range
#
# Everything runs against a temporary HYPR_DIR; no real ~/.config/hypr is touched.

RS="$PLUGIN_ROOT/skills/rice/scripts"
install_sh="$RS/install-config.sh"
emit="$RS/emit-config.sh"

assert_file_exists "$install_sh" "install-config.sh ships"

tmp="$(mktemp_test_dir hypr-lua-install)"

# Staging dirs in each language, produced by the plugin's own emitter.
stage_conf="$tmp/stage-conf"
stage_lua="$tmp/stage-lua"
HYPR_CONFIG_LANG=hyprlang HYPR_VERSION=0.54.3 bash "$emit" "$stage_conf" >/dev/null 2>&1
HYPR_CONFIG_LANG=lua HYPR_VERSION=0.56.2 bash "$emit" "$stage_lua" >/dev/null 2>&1
assert_file_exists "$stage_conf/hyprland.conf" "staged a hyprlang config to install"
assert_file_exists "$stage_lua/hyprland.lua" "staged a lua config to install"

# --------------------------------------------------------------------------------------------
# AC-1 - the shadow check. The phase's own grading: put a hyprland.lua in the
# target and assert the install refuses.
# --------------------------------------------------------------------------------------------
shadowed="$tmp/shadowed"
mkdir -p "$shadowed"
printf -- '-- the user (or Hyprland 0.56.0+) already put a lua config here\nhl.config({})\n' \
    > "$shadowed/hyprland.lua"
lua_before="$(cat "$shadowed/hyprland.lua")"

out="$(HYPR_DIR="$shadowed" bash "$install_sh" "$stage_conf" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
    pass "AC-1: installing a hyprlang .conf into a lua-shadowed target exits non-zero"
else
    fail "AC-1: installing a hyprlang .conf into a lua-shadowed target exits non-zero" "exit 0
$out"
fi
if [ -e "$shadowed/hyprland.conf" ]; then
    fail "AC-1: no hyprlang .conf was installed" "found $shadowed/hyprland.conf"
else
    pass "AC-1: no hyprlang .conf was installed"
fi
assert_eq "$lua_before" "$(cat "$shadowed/hyprland.lua")" \
    "AC-1: the existing hyprland.lua is untouched"
if printf '%s\n' "$out" | grep -q "SHADOWED_BY=$shadowed/hyprland.lua"; then
    pass "AC-1: the refusal names the file that shadows the install"
else
    fail "AC-1: the refusal names the file that shadows the install" "$out"
fi
if printf '%s\n' "$out" | grep -qi 'takes precedence over hyprland.conf'; then
    pass "AC-1: the refusal reports that the lua config takes precedence"
else
    fail "AC-1: the refusal reports that the lua config takes precedence" "$out"
fi
if printf '%s\n' "$out" | grep -q '^DONE=ok'; then
    fail "AC-1: the refusal does not report success" "$out"
else
    pass "AC-1: the refusal does not report success"
fi
shopt -s nullglob
shadow_backups=("$tmp"/shadowed.bak.*)
shopt -u nullglob
assert_eq "0" "${#shadow_backups[@]}" "AC-1: the refusal took no backup either (nothing was changed)"

# A LUA config may of course replace a lua config - the refusal is language-specific.
out="$(HYPR_DIR="$shadowed" bash "$install_sh" "$stage_lua" 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-1: installing a lua config into that same target is allowed"
assert_file_contains "$shadowed/hyprland.lua" "hl.bind(" \
    "AC-1: the lua install did land"

# --------------------------------------------------------------------------------------------
# AC-7 - an unwritable target is reported, not half-written
# --------------------------------------------------------------------------------------------
locked="$tmp/locked"
mkdir -p "$locked"
printf 'general {\n    gaps_in = 1\n}\n' > "$locked/hyprland.conf"
printf 'keep me\n' > "$locked/other.conf"
locked_main_before="$(cat "$locked/hyprland.conf")"
locked_other_before="$(cat "$locked/other.conf")"
chmod 500 "$locked"

if [ "$(id -u)" = "0" ]; then
    skip "AC-7: unwritable target" "running as root; permission bits are not enforced"
    chmod 700 "$locked"
else
    out="$(HYPR_DIR="$locked" bash "$install_sh" "$stage_conf" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        pass "AC-7: an unwritable target exits non-zero"
    else
        fail "AC-7: an unwritable target exits non-zero" "exit 0
$out"
    fi
    if printf '%s\n' "$out" | grep -q '^DONE=ok'; then
        fail "AC-7: an unwritable target is not reported as success" "$out"
    else
        pass "AC-7: an unwritable target is not reported as success"
    fi
    if printf '%s\n' "$out" | grep -q "TARGET=$locked"; then
        pass "AC-7: the refusal reports the target path"
    else
        fail "AC-7: the refusal reports the target path" "$out"
    fi
    if printf '%s\n' "$out" | grep -qiE 'cannot be written to|permission denied'; then
        pass "AC-7: the refusal reports the permission failure"
    else
        fail "AC-7: the refusal reports the permission failure" "$out"
    fi
    chmod 700 "$locked"
    assert_eq "$locked_main_before" "$(cat "$locked/hyprland.conf")" \
        "AC-7: the file already in the target is unmodified"
    assert_eq "$locked_other_before" "$(cat "$locked/other.conf")" \
        "AC-7: every other file in the target is unmodified"
    files_now="$(cd "$locked" && ls -A | sort | tr '\n' ' ')"
    assert_eq "hyprland.conf other.conf " "$files_now" \
        "AC-7: no new file was added to the target"
fi

# A target path that exists but is not a directory is refused the same way.
notdir="$tmp/not-a-dir"
printf 'i am a file\n' > "$notdir"
out="$(HYPR_DIR="$notdir" bash "$install_sh" "$stage_conf" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
    pass "AC-7: a target that is not a directory exits non-zero"
else
    fail "AC-7: a target that is not a directory exits non-zero" "exit 0
$out"
fi
assert_eq "i am a file" "$(cat "$notdir")" "AC-7: that path is left exactly as it was"

# --------------------------------------------------------------------------------------------
# AC-8 - absent or empty target: install, claim no backup, still record the language
# --------------------------------------------------------------------------------------------
for case_name in absent empty; do
    fresh="$tmp/fresh-$case_name"
    if [ "$case_name" = "empty" ]; then mkdir -p "$fresh"; fi
    out="$(HYPR_DIR="$fresh" bash "$install_sh" "$stage_conf" 2>&1)"; rc=$?
    assert_eq "0" "$rc" "AC-8: an $case_name target installs cleanly"
    assert_file_exists "$fresh/hyprland.conf" "AC-8: an $case_name target receives the config"
    if printf '%s\n' "$out" | grep -qE '^BACKUP=/'; then
        fail "AC-8: an $case_name target reports no backup path it did not take" "$out"
    else
        pass "AC-8: an $case_name target reports no backup path it did not take"
    fi
    if printf '%s\n' "$out" | grep -q '^BACKUP=none'; then
        pass "AC-8: an $case_name target says plainly that there was no backup"
    else
        fail "AC-8: an $case_name target says plainly that there was no backup" "$out"
    fi
    shopt -s nullglob
    made=("$tmp/fresh-$case_name.bak."*)
    shopt -u nullglob
    assert_eq "0" "${#made[@]}" "AC-8: an $case_name target leaves no .bak directory behind"

    if printf '%s\n' "$out" | grep -q '^CONFIG_LANGUAGE=hyprlang'; then
        pass "AC-8: the $case_name install records the emitted language"
    else
        fail "AC-8: the $case_name install records the emitted language" "$out"
    fi
    if printf '%s\n' "$out" | grep -qE '^CONFIG_LANGUAGE_RANGE=.+'; then
        pass "AC-8: the $case_name install records the valid version range"
    else
        fail "AC-8: the $case_name install records the valid version range" "$out"
    fi
    assert_file_contains "$fresh/hyprland.conf" "# CONFIG_LANGUAGE=hyprlang" \
        "AC-8: the file it wrote records the language too"
    assert_grep '^# CONFIG_LANGUAGE_RANGE=' "$fresh/hyprland.conf" \
        "AC-8: the file it wrote records the version range too"
done

# A NON-empty target still gets its backup - the AC-8 rule is about not claiming
# one that was never taken, not about dropping backups.
populated="$tmp/populated"
mkdir -p "$populated"
printf 'old config\n' > "$populated/hyprland.conf"
out="$(HYPR_DIR="$populated" bash "$install_sh" "$stage_conf" 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-8: a populated target still installs"
backup_path="$(printf '%s\n' "$out" | sed -n 's/^BACKUP=//p' | head -n1)"
case "$backup_path" in
    /*) assert_file_exists "$backup_path/hyprland.conf" "AC-8: a populated target IS backed up first" ;;
    *)  fail "AC-8: a populated target IS backed up first" "BACKUP=$backup_path" ;;
esac

# --------------------------------------------------------------------------------------------
# Staging that holds both languages is refused rather than installed as a shadowing pair.
# --------------------------------------------------------------------------------------------
both="$tmp/stage-both"
mkdir -p "$both"
cp "$stage_conf/hyprland.conf" "$both/"
cp "$stage_lua/hyprland.lua" "$both/"
dest="$tmp/dest-both"
out="$(HYPR_DIR="$dest" bash "$install_sh" "$both" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
    pass "AC-1: staging both languages at once is refused"
else
    fail "AC-1: staging both languages at once is refused" "exit 0
$out"
fi
if [ -d "$dest" ]; then
    fail "AC-1: the ambiguous refusal wrote nothing" "$(ls -A "$dest")"
else
    pass "AC-1: the ambiguous refusal wrote nothing"
fi

# --------------------------------------------------------------------------------------------
# Impl-gate loop 1, finding F5: the file list is picked by language (*.lua XOR *.conf), so a
# companion in the other language would be left behind with no INSTALLED= line and no warning.
# A silent partial install is exactly the class this script refuses everywhere else.
# --------------------------------------------------------------------------------------------
mixed="$tmp/stage-mixed"
mkdir -p "$mixed"
cp "$stage_lua/hyprland.lua" "$mixed/"
printf '# a hyprlang companion nobody would be told about\n' > "$mixed/colors.conf"
dest="$tmp/dest-mixed"
out="$(HYPR_DIR="$dest" bash "$install_sh" "$mixed" 2>&1)"; rc=$?
assert_eq "3" "$rc" "F5: a lua staging set with a .conf companion is refused"
if printf '%s\n' "$out" | grep -q '^REFUSED=mixed-staging'; then
    pass "F5: the refusal says the staging dir mixes the two languages"
else
    fail "F5: the refusal says the staging dir mixes the two languages" "$out"
fi
if printf '%s\n' "$out" | grep -q '^STRAY=colors.conf'; then
    pass "F5: the refusal names the companion that would have been dropped"
else
    fail "F5: the refusal names the companion that would have been dropped" "$out"
fi
if [ -d "$dest" ]; then
    fail "F5: the mixed refusal wrote nothing" "$(ls -A "$dest")"
else
    pass "F5: the mixed refusal wrote nothing"
fi

# The mirror case: a hyprlang staging set with a stray .lua companion.
mixed2="$tmp/stage-mixed2"
mkdir -p "$mixed2"
cp "$stage_conf/hyprland.conf" "$mixed2/"
printf -- '-- a lua companion nobody would be told about\n' > "$mixed2/extra.lua"
out="$(HYPR_DIR="$tmp/dest-mixed2" bash "$install_sh" "$mixed2" 2>&1)"; rc=$?
assert_eq "3" "$rc" "F5: a hyprlang staging set with a .lua companion is refused too"

# --------------------------------------------------------------------------------------------
# Impl-gate loop 1, finding F6: AC-3 asks that any generated configuration record its language
# and range IN THE OUTPUT. A config staged by something other than emit-config.sh - the rice
# interview's staging dir - carries none, so install-config.sh adds it.
# --------------------------------------------------------------------------------------------
bare_stage="$tmp/stage-no-provenance"
mkdir -p "$bare_stage"
printf '# a config with no provenance of its own\nmonitor = , preferred, auto, auto\n' \
    > "$bare_stage/hyprland.conf"
dest="$tmp/dest-provenance"
out="$(HYPR_DIR="$dest" bash "$install_sh" "$bare_stage" 2>&1)"; rc=$?
assert_eq "0" "$rc" "F6: a config with no provenance header still installs"
if printf '%s\n' "$out" | grep -q '^PROVENANCE=added to hyprland.conf'; then
    pass "F6: the run says it added the provenance the staged file lacked"
else
    fail "F6: the run says it added the provenance the staged file lacked" "$out"
fi
assert_grep '^# CONFIG_LANGUAGE=hyprlang$' "$dest/hyprland.conf" \
    "F6/AC-3: the installed file records the language it is"
assert_grep '^# CONFIG_LANGUAGE_RANGE=Hyprland up to 0\.54' "$dest/hyprland.conf" \
    "F6/AC-3: the installed file records the range that language is valid for"
assert_file_contains "$dest/hyprland.conf" 'monitor = , preferred, auto, auto' \
    "F6: the staged content itself is untouched"

# A config that already carries provenance is not given a second copy.
dest2="$tmp/dest-provenance2"
out="$(HYPR_DIR="$dest2" bash "$install_sh" "$stage_conf" 2>&1)"; rc=$?
assert_eq "0" "$rc" "F6: an emitter-written config installs unchanged"
if printf '%s\n' "$out" | grep -q '^PROVENANCE='; then
    fail "F6: no second provenance header is added to a config that has one" "$out"
else
    pass "F6: no second provenance header is added to a config that has one"
fi
assert_eq "1" "$(grep -c '^# CONFIG_LANGUAGE=' "$dest2/hyprland.conf")" \
    "F6: exactly one CONFIG_LANGUAGE= header in the installed file"

rm -rf "$tmp"

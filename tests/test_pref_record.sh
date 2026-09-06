#!/usr/bin/env bash
# S0037-hyprland-config-install-7 - the preferences a restore cannot undo, recorded and removable.
#
# Firefox re-applies every line of `<profile>/user.js` at each start and shows none of them as
# changed in its own UI, so a config restore does not undo what this plugin merged there. These
# assertions are that the plugin says which preferences it set, in which profile, and ships a way
# to take exactly those back off without touching anything else in the file.
#
# Grades:
#   AC-4   the plugin records which preferences it set and ships a documented way to remove them
#   AC-15  the record carries the absolute profile path and every key actually added, and never a
#          key that was already present and left untouched
#   AC-16  removal removes only the recorded lines; every other line stays byte-identical
#   AC-17  the file is copied to a restorable backup BEFORE it is edited
#   AC-18  a preference changed by hand since is left alone and reported as changed
#   AC-19  a second removal reports nothing left to remove and leaves the file unchanged
#   AC-20  a profile file that is gone is reported by path, not created, and does not stop the
#          removal for other profiles
#   AC-21  the browser-theming documentation names every preference, the supported way to remove
#          them, and what stops working once they are gone
#
# No Firefox here: `firefox` is a stub whose only job is to exist, and every profile is a
# directory inside this test's own tempdir.

PS="$PLUGIN_ROOT/scripts"
FP="$PS/firefox-prefs.sh"
FFBOOT="$PLUGIN_ROOT/skills/rice/assets/scripts/firefox-bootstrap.sh"
BROWSER="$PLUGIN_ROOT/skills/rice/references/components/browser"
PREF_STYLESHEETS='toolkit.legacyUserProfileCustomizations.stylesheets'
PREF_STARTUP='browser.startup.page'

tmp="$(mktemp_test_dir pref-record)"
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

unset XDG_CONFIG_HOME XDG_STATE_HOME RICE_APPLY_ID RICE_PREF_RECORD
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
export FIREFOX_ASSETS_DIR="$BROWSER"
BIN_PATH="/usr/bin:/bin"

stub="$tmp/stubs"; mkdir -p "$stub"
printf '#!/usr/bin/env bash\nexit 0\n' > "$stub/firefox"
chmod +x "$stub/firefox"
PATH_WITH_FF="$stub:$BIN_PATH"

assert_file_exists "$FP" "scripts/firefox-prefs.sh ships"

field() { printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -n1; }
assert_out_has() {
    if printf '%s\n' "$2" | grep -qF -- "$1"; then pass "$3"; else
        fail "$3" "missing: $1
--- output ---
$2"
    fi
}

# `mk_profile <home> <name> <seed-user.js|"">` - a Firefox profile the bootstrap will resolve.
mk_profile() {
    local h="$1" name="$2" seed="${3:-}"
    mkdir -p "$h/.mozilla/firefox/$name"
    if [ ! -f "$h/.mozilla/firefox/profiles.ini" ]; then
        {
            printf '[Profile0]\n'
            printf 'Name=default\n'
            printf 'IsRelative=1\n'
            printf 'Path=%s\n' "$name"
            printf 'Default=1\n'
        } > "$h/.mozilla/firefox/profiles.ini"
    fi
    [ -n "$seed" ] && printf '%s' "$seed" > "$h/.mozilla/firefox/$name/user.js"
    printf '%s\n' "$h/.mozilla/firefox/$name"
}

# The two preferences the shipped asset carries. Read from the asset, never assumed: the record
# has to reflect what was actually merged.
assert_file_contains "$BROWSER/user.js" "user_pref(\"$PREF_STYLESHEETS\"" "the shipped asset sets $PREF_STYLESHEETS"
assert_file_contains "$BROWSER/user.js" "user_pref(\"$PREF_STARTUP\"" "the shipped asset sets $PREF_STARTUP"
asset_prefs="$(grep -c '^user_pref(' "$BROWSER/user.js")"
assert_eq "2" "$asset_prefs" "the shipped asset carries exactly two preferences"

# =============================================================================================
# AC-15  the record names the absolute profile path and every key actually added - and never a
#        key that was already there
# =============================================================================================
a="$tmp/a"; export HOME="$a/home"; mkdir -p "$HOME"
export RICE_DIR="$HOME/.config/hypr-rice"
export RICE_RESTORE_DIR="$a/state/restore"
seed='// my own settings, written by hand
user_pref("'"$PREF_STARTUP"'", 1);
user_pref("privacy.donottrackheader.enabled", true);
'
prof="$(mk_profile "$HOME" "abc.default-release" "$seed")"

out="$(PATH="$PATH_WITH_FF" bash "$FFBOOT" 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-15: the bootstrap runs against a stubbed profile"
assert_eq "$prof" "$(field FIREFOX_PROFILE "$out")" "AC-15: the bootstrap resolved the profile"

record="$HOME/.local/state/hypr-rice/browser-prefs.tsv"
assert_file_exists "$record" "AC-15: the merge left a preference record in the plugin's state area"
rbody="$(cat "$record" 2>/dev/null)"
if printf '%s\n' "$rbody" | grep -q "^$prof	$PREF_STYLESHEETS	"; then
    pass "AC-15: the record carries the absolute profile path and the key that was added"
else
    fail "AC-15: the record carries the absolute profile path and the key that was added" "$rbody"
fi
if printf '%s\n' "$rbody" | grep -q "	$PREF_STARTUP	"; then
    fail "AC-15: a key that was already present is not recorded" "$rbody"
else
    pass "AC-15: a key that was already present is not recorded"
fi
assert_eq "1" "$(grep -c . "$record")" "AC-15: exactly the keys actually added are recorded"
assert_file_contains "$prof/user.js" "user_pref(\"$PREF_STARTUP\", 1);" \
    "AC-15: the pre-existing preference kept the user's own value"

# The record is readable without knowing where it is.
lst="$(PATH="$BIN_PATH" bash "$FP" list 2>&1)"
assert_out_has "$PREF_STYLESHEETS" "$lst" "AC-4: the record can be listed back"
assert_out_has "still set" "$lst" "AC-4: the listing says whether the preference is still set"

# =============================================================================================
# AC-16 / AC-17  removal takes off only the recorded lines, after backing the file up
# =============================================================================================
b="$tmp/b"; export HOME="$b/home"; mkdir -p "$HOME"
export RICE_DIR="$HOME/.config/hypr-rice"
export RICE_RESTORE_DIR="$b/state/restore"
seed='// hand-written, keep me
user_pref("privacy.donottrackheader.enabled", true);
// and this comment too
'
prof="$(mk_profile "$HOME" "xyz.default-release" "$seed")"
out="$(PATH="$PATH_WITH_FF" bash "$FFBOOT" 2>&1)"
record="$HOME/.local/state/hypr-rice/browser-prefs.tsv"
assert_eq "2" "$(grep -c . "$record")" "AC-15: both shipped preferences were recorded for a fresh profile"

cp "$prof/user.js" "$b/before-removal"
# What the file must look like afterwards: exactly the seed, byte for byte.
printf '%s' "$seed" > "$b/expected"

out="$(PATH="$BIN_PATH" bash "$FP" remove 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-16: the removal path runs"
assert_out_has "PREF_REMOVED=$prof/user.js $PREF_STYLESHEETS" "$out" "AC-16: it reports the key it removed"
assert_out_has "PREF_REMOVED=$prof/user.js $PREF_STARTUP" "$out" "AC-16: it reports every key it removed"
if cmp -s "$prof/user.js" "$b/expected"; then
    pass "AC-16: every other line of the file is byte-identical to what it was"
else
    fail "AC-16: every other line of the file is byte-identical" "$(diff "$b/expected" "$prof/user.js" 2>&1)"
fi

apply_id="$(field RESTORE_POINT "$out")"
if [ -n "$apply_id" ]; then
    pass "AC-17: the removal names the restore point it can be undone with ($apply_id)"
else
    fail "AC-17: the removal names the restore point it can be undone with" "$out"
fi
bak="$prof/user.js.bak.$apply_id"
if [ -f "$bak" ] && cmp -s "$bak" "$b/before-removal"; then
    pass "AC-17: the file was copied to a restorable backup BEFORE it was edited"
else
    fail "AC-17: the file was copied to a restorable backup before it was edited" "expected $bak to hold the pre-removal content"
fi
if [ -s "$RICE_RESTORE_DIR/$apply_id/entries.tsv" ] && \
   grep -q "	$prof/user.js	" "$RICE_RESTORE_DIR/$apply_id/entries.tsv"; then
    pass "AC-17: the edit is enrolled in a restore point, so 'rice restore' puts it back"
else
    fail "AC-17: the edit is enrolled in a restore point" "$(cat "$RICE_RESTORE_DIR/$apply_id/entries.tsv" 2>/dev/null)"
fi

# =============================================================================================
# AC-19  a second removal: nothing left to remove, and the file is not touched
# =============================================================================================
cp "$prof/user.js" "$b/after-first"
out="$(PATH="$BIN_PATH" bash "$FP" remove 2>&1)"; rc=$?
assert_out_has "nothing-to-remove" "$out" "AC-19: a second removal says there is nothing left to remove"
assert_eq "3" "$rc" "AC-19: it is not reported as a removal that did something"
if cmp -s "$prof/user.js" "$b/after-first"; then
    pass "AC-19: the second removal left the file unchanged"
else
    fail "AC-19: the second removal left the file unchanged" "$(diff "$b/after-first" "$prof/user.js" 2>&1)"
fi

# =============================================================================================
# AC-18  a preference changed by hand since is left alone and reported
# =============================================================================================
c="$tmp/c"; export HOME="$c/home"; mkdir -p "$HOME"
export RICE_DIR="$HOME/.config/hypr-rice"
export RICE_RESTORE_DIR="$c/state/restore"
prof="$(mk_profile "$HOME" "hand.default-release" '// mine
')"
PATH="$PATH_WITH_FF" bash "$FFBOOT" >/dev/null 2>&1
# The user thought better of session restore and set it to 1 by hand.
sed -i "s/user_pref(\"$PREF_STARTUP\", 3);/user_pref(\"$PREF_STARTUP\", 1);/" "$prof/user.js"
cp "$prof/user.js" "$c/before"

out="$(PATH="$BIN_PATH" bash "$FP" remove 2>&1)"; rc=$?
assert_out_has "PREF_CHANGED=$prof/user.js $PREF_STARTUP" "$out" \
    "AC-18: the hand-changed preference is reported as changed"
assert_file_contains "$prof/user.js" "user_pref(\"$PREF_STARTUP\", 1);" \
    "AC-18: the value the user chose is still there"
if grep -q "user_pref(\"$PREF_STYLESHEETS\"" "$prof/user.js"; then
    fail "AC-18: the untouched preference was still removed" "$(cat "$prof/user.js")"
else
    pass "AC-18: the preference that was NOT changed by hand was still removed"
fi
assert_out_has "changed:1" "$out" "AC-18: the summary counts what it left alone"
# Re-running keeps leaving it alone rather than deleting it on a second pass.
out="$(PATH="$BIN_PATH" bash "$FP" remove 2>&1)"
assert_out_has "PREF_CHANGED=$prof/user.js $PREF_STARTUP" "$out" \
    "AC-18: a re-run still refuses to delete the user's value"
assert_file_contains "$prof/user.js" "user_pref(\"$PREF_STARTUP\", 1);" \
    "AC-18: the user's value survives a second removal too"

# =============================================================================================
# AC-20  a profile file that is gone: reported by path, not created, and the other profile is
#        still cleaned up
# =============================================================================================
d="$tmp/d"; export HOME="$d/home"; mkdir -p "$HOME"
export RICE_DIR="$HOME/.config/hypr-rice"
export RICE_RESTORE_DIR="$d/state/restore"
prof1="$(mk_profile "$HOME" "one.default-release" '// one
')"
mkdir -p "$HOME/.mozilla/firefox/two.other"
prof2="$HOME/.mozilla/firefox/two.other"
PATH="$PATH_WITH_FF" bash "$FFBOOT" >/dev/null 2>&1
PATH="$PATH_WITH_FF" bash "$FFBOOT" --profile "$prof2" >/dev/null 2>&1
record="$HOME/.local/state/hypr-rice/browser-prefs.tsv"
assert_eq "4" "$(grep -c . "$record")" "AC-20: both profiles were recorded"

rm -f "$prof2/user.js"
out="$(PATH="$BIN_PATH" bash "$FP" remove 2>&1)"; rc=$?
assert_out_has "PREFS_MISSING=$prof2/user.js" "$out" "AC-20: the missing profile file is reported by path"
if [ -e "$prof2/user.js" ]; then
    fail "AC-20: the missing file was not created" "$prof2/user.js exists again"
else
    pass "AC-20: the missing file was not created"
fi
if grep -q "user_pref(\"$PREF_STYLESHEETS\"" "$prof1/user.js"; then
    fail "AC-20: the other profile was still cleaned up" "$(cat "$prof1/user.js")"
else
    pass "AC-20: the other profile was still cleaned up"
fi
assert_eq "0" "$rc" "AC-20: a missing profile file does not fail the rest of the removal"

# =============================================================================================
# Backup before write, or do not write: a file that cannot be backed up is NOT edited.
# (A regular file where the restore store's parent belongs blocks the enrolment for any user,
# root included - a permission bit would not bind as root, and CI may be root.)
# =============================================================================================
e="$tmp/e"; export HOME="$e/home"; mkdir -p "$HOME"
export RICE_DIR="$HOME/.config/hypr-rice"
export RICE_RESTORE_DIR="$e/state/restore"
prof="$(mk_profile "$HOME" "guard.default-release" '// mine
')"
PATH="$PATH_WITH_FF" bash "$FFBOOT" >/dev/null 2>&1
cp "$prof/user.js" "$e/before"
printf 'not a directory\n' > "$e/blocked"

out="$(RICE_RESTORE_DIR="$e/blocked/restore" PATH="$BIN_PATH" bash "$FP" remove 2>&1)"; rc=$?
assert_out_has "PREFS_SKIPPED=$prof/user.js" "$out" "backup fail-safe: the file it could not back up is named"
assert_eq "1" "$rc" "backup fail-safe: the run reports that it could not finish"
if cmp -s "$prof/user.js" "$e/before"; then
    pass "backup fail-safe: the file was NOT edited"
else
    fail "backup fail-safe: the file was NOT edited" "$(diff "$e/before" "$prof/user.js" 2>&1)"
fi
# It is still set, so it is still recorded: the record did not lose track of it.
assert_file_contains "$HOME/.local/state/hypr-rice/browser-prefs.tsv" "$PREF_STYLESHEETS" \
    "backup fail-safe: a preference that could not be removed stays in the record"

# =============================================================================================
# A user.js whose last line carries no terminating newline - a plain hand-edited file, nothing
# exotic. `>>` CONTINUES that line, so a merge that does not terminate it first writes this
# plugin's preference onto the end of a line the user wrote: the line the record names would
# then exist nowhere in the file, the removal path would find nothing to take off, and it would
# report the plugin's own write as one the user changed by hand. AC-4 (a documented way to
# remove them), AC-16 (every other line byte-identical) and AC-18 (only a hand-changed line is
# reported as changed) all fail together on that one byte.
# =============================================================================================
f="$tmp/f"; export HOME="$f/home"; mkdir -p "$HOME"
export RICE_DIR="$HOME/.config/hypr-rice"
export RICE_RESTORE_DIR="$f/state/restore"
users_line='user_pref("privacy.donottrackheader.enabled", true);'
prof="$(mk_profile "$HOME" "nonl.default-release" "$users_line")"   # no trailing newline
PATH="$PATH_WITH_FF" bash "$FFBOOT" >/dev/null 2>&1

if grep -q "^user_pref(\"$PREF_STYLESHEETS\"" "$prof/user.js"; then
    pass "AC-4: a preference is written on a line of its own, not glued onto an unterminated last line"
else
    fail "AC-4: a preference is written on a line of its own" "$(cat "$prof/user.js")"
fi
if grep -Fxq -- "$users_line" "$prof/user.js"; then
    pass "AC-16: the user's own last line is still a whole line of its own"
else
    fail "AC-16: the user's own last line is still a whole line of its own" "$(cat "$prof/user.js")"
fi
record="$HOME/.local/state/hypr-rice/browser-prefs.tsv"
absent=""
while IFS=$'\t' read -r _rprof rkey rline _when; do
    [ -n "${rline:-}" ] || continue
    grep -Fxq -- "$rline" "$prof/user.js" || absent+="$rkey"$'\n'
done < "$record"
if [ -z "$absent" ]; then
    pass "AC-15: every line the record names exists as a whole line of the file it names"
else
    fail "AC-15: every line the record names exists as a whole line of the file it names" \
        "recorded but not present as a line:
$absent"
fi

out="$(PATH="$BIN_PATH" bash "$FP" remove 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-4: the removal path runs against a file that had no trailing newline"
assert_out_has "PREF_REMOVED=$prof/user.js $PREF_STYLESHEETS" "$out" \
    "AC-4: the theming preference this plugin set is removable, not stuck on the machine"
assert_out_has "PREF_REMOVED=$prof/user.js $PREF_STARTUP" "$out" \
    "AC-4: the second preference is removable too"
if printf '%s\n' "$out" | grep -q 'PREF_CHANGED='; then
    fail "AC-18: nothing this plugin wrote is reported as changed by hand" "$out"
else
    pass "AC-18: nothing this plugin wrote is reported as changed by hand"
fi
if grep -q "$PREF_STYLESHEETS" "$prof/user.js"; then
    fail "AC-4: the preference is gone from the file" "$(cat "$prof/user.js")"
else
    pass "AC-4: the preference is gone from the file, so Firefox stops re-applying it"
fi
# What is left: the user's line, byte for byte, with the terminator the merge had to add before
# it could write a line of its own beneath it.
printf '%s\n' "$users_line" > "$f/expected"
if cmp -s "$prof/user.js" "$f/expected"; then
    pass "AC-16: the user's line survives the removal byte-identical"
else
    fail "AC-16: the user's line survives the removal byte-identical" "$(diff "$f/expected" "$prof/user.js" 2>&1)"
fi

# The other half of that rule: a merge that ADDS nothing changes nothing, terminator included.
g="$tmp/g"; export HOME="$g/home"; mkdir -p "$HOME"
export RICE_DIR="$HOME/.config/hypr-rice"
export RICE_RESTORE_DIR="$g/state/restore"
prof="$(mk_profile "$HOME" "already.default-release" \
        "$(printf 'user_pref("%s", true);\nuser_pref("%s", 3);' "$PREF_STYLESHEETS" "$PREF_STARTUP")")"
cp "$prof/user.js" "$g/before"
PATH="$PATH_WITH_FF" bash "$FFBOOT" >/dev/null 2>&1
if cmp -s "$prof/user.js" "$g/before"; then
    pass "AC-15: a merge that adds nothing leaves the file byte-identical, missing terminator and all"
else
    fail "AC-15: a merge that adds nothing leaves the file byte-identical" "$(diff "$g/before" "$prof/user.js" 2>&1)"
fi
assert_eq "0" "$(grep -c . "$HOME/.local/state/hypr-rice/browser-prefs.tsv" 2>/dev/null || echo 0)" \
    "AC-15: preferences that were already there are not recorded as set by this plugin"

# =============================================================================================
# AC-21  the documentation names every preference, the way to remove them, and what stops working
# =============================================================================================
doc="$BROWSER/template.md"
assert_file_contains "$doc" "$PREF_STYLESHEETS" "AC-21: the component doc names the stylesheets preference"
assert_file_contains "$doc" "$PREF_STARTUP"     "AC-21: the component doc names the startup-page preference"
assert_file_contains "$doc" "rice prefs remove" "AC-21: the component doc names the supported way to remove them"
if grep -qiE 'chrome theming (stops|is off)|theming stops|no longer themed|stops working' "$doc"; then
    pass "AC-21: the component doc says what stops working once they are removed"
else
    fail "AC-21: the component doc says what stops working once they are removed" \
        "no statement of the consequence found in $doc"
fi
# The plugin's own README is where a user looks first.
assert_file_contains "$PLUGIN_ROOT/README.md" "rice prefs remove" \
    "AC-21: the README names the removal command too"

unset RICE_DIR RICE_RESTORE_DIR FIREFOX_ASSETS_DIR
export HOME="$tmp"

#!/usr/bin/env bash
# S0037-hyprland-config-install-7 - regression guard: nothing in a browser profile is replaced
# without a restorable copy of it first.
#
# This behaviour already holds (RESTORE-3 closed it). Nothing here changes it; these assertions
# exist so it cannot regress quietly, which is the whole of this file's brief.
#
# Grades:
#   AC-3   every file the plugin replaces in a browser profile is backed up first, INCLUDING a
#          userChrome.css this plugin has written before
#   AC-22  the "already refers to rice-colors.css" branch takes a restorable backup before the
#          replacement, exactly as the branch for a file the plugin did not write does
#   AC-23  a file that cannot be backed up is NOT written, and the skip is reported by path
#
# No Firefox: `firefox` is a stub that only has to exist, and every profile is a directory inside
# this test's own tempdir.

FFBOOT="$PLUGIN_ROOT/skills/rice/assets/scripts/firefox-bootstrap.sh"
BROWSER="$PLUGIN_ROOT/skills/rice/references/components/browser"

tmp="$(mktemp_test_dir firefox-backup)"
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

unset XDG_CONFIG_HOME XDG_STATE_HOME RICE_APPLY_ID RICE_PREF_RECORD
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
export FIREFOX_ASSETS_DIR="$BROWSER"
BIN_PATH="/usr/bin:/bin"

stub="$tmp/stubs"; mkdir -p "$stub"
printf '#!/usr/bin/env bash\nexit 0\n' > "$stub/firefox"
chmod +x "$stub/firefox"

field() { printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -n1; }
assert_out_has() {
    if printf '%s\n' "$2" | grep -qF -- "$1"; then pass "$3"; else
        fail "$3" "missing: $1
--- output ---
$2"
    fi
}

mk_profile() {   # <home> <name>
    local h="$1" name="$2"
    mkdir -p "$h/.mozilla/firefox/$name"
    {
        printf '[Profile0]\nName=default\nIsRelative=1\nPath=%s\nDefault=1\n' "$name"
    } > "$h/.mozilla/firefox/profiles.ini"
    printf '%s\n' "$h/.mozilla/firefox/$name"
}

# =============================================================================================
# AC-3 / AC-22  a userChrome.css THIS PLUGIN WROTE BEFORE is replaced wholesale - and is backed
#               up before the replacement, exactly like one it did not write
# =============================================================================================
a="$tmp/a"; export HOME="$a/home"; mkdir -p "$HOME"
export RICE_DIR="$HOME/.config/hypr-rice"
export RICE_RESTORE_DIR="$a/state/restore"
prof="$(mk_profile "$HOME" "prev.default-release")"
mkdir -p "$prof/chrome"
# The shape a previous run of this plugin leaves: an @import of its own rendered colors file,
# plus whatever the user has added under it since.
prior='@import "rice-colors.css";
/* my own tweak, added after the plugin wrote this file */
#TabsToolbar { visibility: collapse !important; }
'
printf '%s' "$prior" > "$prof/chrome/userChrome.css"
printf 'user_pref("privacy.donottrackheader.enabled", true);\n' > "$prof/user.js"
cp "$prof/chrome/userChrome.css" "$a/userChrome.before"
cp "$prof/user.js" "$a/userjs.before"

out="$(PATH="$stub:$BIN_PATH" bash "$FFBOOT" 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-22: the bootstrap runs over a profile this plugin has written before"
apply_id="$(field RESTORE_POINT "$out")"
if [ -n "$apply_id" ]; then
    pass "AC-22: the run reports the restore point it enrolled in ($apply_id)"
else
    fail "AC-22: the run reports the restore point it enrolled in" "$out"
fi

bak="$prof/chrome/userChrome.css.bak.$apply_id"
if [ -f "$bak" ] && cmp -s "$bak" "$a/userChrome.before"; then
    pass "AC-3/AC-22: the previously-written userChrome.css was copied to a backup before the replacement"
else
    fail "AC-3/AC-22: the previously-written userChrome.css was backed up before the replacement" \
        "expected $bak to hold the prior content"
fi
if cmp -s "$prof/chrome/userChrome.css" "$BROWSER/userChrome.css"; then
    pass "AC-22: that branch really does replace the file (so the backup is what makes it safe)"
else
    fail "AC-22: that branch really does replace the file" "$(diff "$BROWSER/userChrome.css" "$prof/chrome/userChrome.css" | head -20)"
fi
if grep -q "	$prof/chrome/userChrome.css	" "$RICE_RESTORE_DIR/$apply_id/entries.tsv" 2>/dev/null; then
    pass "AC-22: the replacement is enrolled in the restore point, so 'rice restore' puts it back"
else
    fail "AC-22: the replacement is enrolled in the restore point" \
        "$(cat "$RICE_RESTORE_DIR/$apply_id/entries.tsv" 2>/dev/null)"
fi

ubak="$prof/user.js.bak.$apply_id"
if [ -f "$ubak" ] && cmp -s "$ubak" "$a/userjs.before"; then
    pass "AC-3: user.js was copied to a backup before the preference merge"
else
    fail "AC-3: user.js was copied to a backup before the preference merge" "expected $ubak to hold the prior content"
fi
assert_file_contains "$prof/user.js" "privacy.donottrackheader.enabled" \
    "AC-3: the merge left the user's own preference alone"

# =============================================================================================
# AC-3  the same for a userChrome.css this plugin did NOT write: backed up before the @import
#       is appended
# =============================================================================================
b="$tmp/b"; export HOME="$b/home"; mkdir -p "$HOME"
export RICE_DIR="$HOME/.config/hypr-rice"
export RICE_RESTORE_DIR="$b/state/restore"
prof="$(mk_profile "$HOME" "mine.default-release")"
mkdir -p "$prof/chrome"
printf '/* entirely my own file, no rice anywhere in it */\n' > "$prof/chrome/userChrome.css"
cp "$prof/chrome/userChrome.css" "$b/before"

out="$(PATH="$stub:$BIN_PATH" bash "$FFBOOT" 2>&1)"
apply_id="$(field RESTORE_POINT "$out")"
bak="$prof/chrome/userChrome.css.bak.$apply_id"
if [ -f "$bak" ] && cmp -s "$bak" "$b/before"; then
    pass "AC-3: a userChrome.css the plugin did not write is backed up before it is touched"
else
    fail "AC-3: a userChrome.css the plugin did not write is backed up before it is touched" "expected $bak"
fi
assert_file_contains "$prof/chrome/userChrome.css" "entirely my own file" \
    "AC-3: that branch appends rather than replacing, and the user's content survives"
assert_file_contains "$prof/chrome/userChrome.css" '@import "rice-colors.css";' \
    "AC-3: the @import was appended"

# A chrome/ directory this step creates is enrolled too, so a restore removes it again.
c="$tmp/c"; export HOME="$c/home"; mkdir -p "$HOME"
export RICE_DIR="$HOME/.config/hypr-rice"
export RICE_RESTORE_DIR="$c/state/restore"
prof="$(mk_profile "$HOME" "fresh.default-release")"
out="$(PATH="$stub:$BIN_PATH" bash "$FFBOOT" 2>&1)"
apply_id="$(field RESTORE_POINT "$out")"
if grep -q "^new	$prof/chrome	" "$RICE_RESTORE_DIR/$apply_id/entries.tsv" 2>/dev/null; then
    pass "AC-3: a chrome/ directory this step creates is enrolled as created, not left orphaned"
else
    fail "AC-3: a chrome/ directory this step creates is enrolled as created" \
        "$(cat "$RICE_RESTORE_DIR/$apply_id/entries.tsv" 2>/dev/null)"
fi

# =============================================================================================
# AC-23  a file that cannot be backed up is NOT written, and the skip names the path
#        (a regular file where the restore store's parent belongs blocks enrolment for any user,
#        root included - a permission bit would not bind as root, and CI may be root)
# =============================================================================================
d="$tmp/d"; export HOME="$d/home"; mkdir -p "$HOME"
export RICE_DIR="$HOME/.config/hypr-rice"
prof="$(mk_profile "$HOME" "guard.default-release")"
mkdir -p "$prof/chrome"
printf '@import "rice-colors.css";\n/* mine */\n' > "$prof/chrome/userChrome.css"
printf 'user_pref("privacy.donottrackheader.enabled", true);\n' > "$prof/user.js"
cp "$prof/chrome/userChrome.css" "$d/uc.before"
cp "$prof/user.js" "$d/uj.before"
printf 'not a directory\n' > "$d/blocked"

out="$(RICE_RESTORE_DIR="$d/blocked/restore" PATH="$stub:$BIN_PATH" bash "$FFBOOT" 2>&1)"
assert_out_has "FIREFOX_SKIPPED $prof/chrome/userChrome.css" "$out" \
    "AC-23: the userChrome.css that could not be backed up is reported by path"
assert_out_has "FIREFOX_SKIPPED $prof/user.js" "$out" \
    "AC-23: the user.js that could not be backed up is reported by path"
if cmp -s "$prof/chrome/userChrome.css" "$d/uc.before"; then
    pass "AC-23: the userChrome.css it could not back up was not written"
else
    fail "AC-23: the userChrome.css it could not back up was not written" "$(diff "$d/uc.before" "$prof/chrome/userChrome.css" | head)"
fi
if cmp -s "$prof/user.js" "$d/uj.before"; then
    pass "AC-23: the user.js it could not back up was not written"
else
    fail "AC-23: the user.js it could not back up was not written" "$(diff "$d/uj.before" "$prof/user.js" | head)"
fi
if [ -e "$HOME/.local/state/hypr-rice/browser-prefs.tsv" ]; then
    fail "AC-23: a preference that was never set is not recorded as set" "the record exists after a skipped merge"
else
    pass "AC-23: a preference that was never set is not recorded as set"
fi

unset RICE_DIR RICE_RESTORE_DIR FIREFOX_ASSETS_DIR
export HOME="$tmp"

#!/usr/bin/env bash
# regress_0037_F2 - S0037-hyprland-config-install-7, impl gate ordinal 1, finding F2.
#
# RUN AGAINST A CHECKOUT OF `sdd/S0037-hyprland-config-install-7`; it exits 2 (inconclusive) on a
# tree that has no scripts/firefox-prefs.sh.
#
# Acceptance criteria under test (work/specs/S0037-hyprland-config-install-7/spec.md):
#   "WHEN the plugin sets a preference that the browser re-applies on every start THE SYSTEM SHALL
#    record which preferences it set and SHALL ship a documented way to remove them"
#   "WHEN the documented removal path runs THE SYSTEM SHALL remove only the preference lines the
#    record names for that profile ..."
#   "IF a preference the record names has been changed by hand since the plugin set it THEN THE
#    SYSTEM SHALL leave that line alone and SHALL report it as changed rather than deleting the
#    user's value"
#
# Scenario: a hand-written <profile>/user.js whose last line has no terminating newline (a plain
# file, nothing exotic). firefox-bootstrap.sh appends its preference with
# `printf '%s\n' "$line" >> user.js`, so the plugin's own pref line is glued onto the END of the
# user's last line instead of onto a line of its own. fp_record still records the asset's line, so
# the record names a line that does not exist in the file, and `firefox-prefs.sh remove`:
#   * removes nothing for that key, and
#   * reports PREF_CHANGED - "changed by hand since this plugin set it" - about a line the USER
#     never touched and the PLUGIN itself wrote.
# The preference is therefore unremovable by the documented path, on that run and every later one.
#
# Standalone: no test harness needed.  bash tests/regress_0037_F2.sh   (exit 0 = criteria hold)

set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$here/.." && pwd)"
FFBOOT="$ROOT/skills/rice/assets/scripts/firefox-bootstrap.sh"
FP="$ROOT/scripts/firefox-prefs.sh"
BROWSER="$ROOT/skills/rice/references/components/browser"
KEY='toolkit.legacyUserProfileCustomizations.stylesheets'

if [ ! -f "$FP" ]; then
    echo "INCONCLUSIVE: $FP does not exist - run this against the S0037 branch tree" >&2
    exit 2
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/regress0037F2.XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

unset XDG_CONFIG_HOME XDG_STATE_HOME RICE_APPLY_ID RICE_PREF_RECORD 2>/dev/null || true
export HOME="$tmp/home"; mkdir -p "$HOME"
export CLAUDE_PLUGIN_ROOT="$ROOT"
export FIREFOX_ASSETS_DIR="$BROWSER"
export RICE_DIR="$HOME/.config/hypr-rice"
export RICE_RESTORE_DIR="$tmp/state/restore"

stub="$tmp/stubs"; mkdir -p "$stub"
printf '#!/usr/bin/env bash\nexit 0\n' > "$stub/firefox"
chmod +x "$stub/firefox"
PATH="$stub:/usr/bin:/bin"; export PATH

prof="$HOME/.mozilla/firefox/nonl.default-release"
mkdir -p "$prof"
printf '[Profile0]\nName=default\nIsRelative=1\nPath=nonl.default-release\nDefault=1\n' \
    > "$HOME/.mozilla/firefox/profiles.ini"
# A user.js the user wrote, whose last line carries no terminating newline.
printf 'user_pref("privacy.donottrackheader.enabled", true);' > "$prof/user.js"

bash "$FFBOOT" >/dev/null 2>&1

echo "--- <profile>/user.js after the merge ---"
cat "$prof/user.js"
echo "-----------------------------------------"

rc=0
if grep -q "^user_pref(\"$KEY\"" "$prof/user.js"; then
    echo "OK: the plugin's preference was written on a line of its own"
else
    echo "FAIL: the plugin's preference is not on a line of its own - it was glued onto the"
    echo "      user's last line, so the line the record names does not exist in the file:"
    grep -n "$KEY" "$prof/user.js" | sed 's/^/      /'
    rc=1
fi

out="$(bash "$FP" remove 2>&1)"
echo "--- firefox-prefs.sh remove ---"
printf '%s\n' "$out"
echo "-------------------------------"

if printf '%s\n' "$out" | grep -q "PREF_CHANGED=$prof/user.js $KEY"; then
    echo "FAIL: the removal path reports a line the PLUGIN wrote as 'changed by hand' by the user"
    rc=1
fi
if grep -q "$KEY" "$prof/user.js"; then
    echo "FAIL: the documented removal path did not remove the preference this plugin set;"
    echo "      it is still in $prof/user.js and Firefox re-applies it at every start"
    rc=1
fi

if [ "$rc" -eq 0 ]; then
    echo "PASS: the preference this plugin set was removable by the documented path"
fi
exit "$rc"

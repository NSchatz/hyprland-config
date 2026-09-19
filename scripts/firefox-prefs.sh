#!/usr/bin/env bash
# The browser-preference record, and the supported way to take those preferences back off.
#
# A preference merged into `<profile>/user.js` is not like the rest of what this plugin writes:
# Firefox re-applies it at EVERY start, and the browser's own UI will not show it as changed, so
# a config restore does not undo it and there is nothing in the interface to undo it with. The
# only way back is to edit that file. This records exactly which lines this plugin put there, in
# which profile, and removes exactly those lines again on request.
#
# Usage:
#   firefox-prefs.sh list                what this plugin set, and where; whether it is still set
#   firefox-prefs.sh record <profile> <user_pref line>
#                                        record one preference line as set (the bootstrap's call)
#   firefox-prefs.sh remove [<profile>]  remove the recorded preferences again, all profiles or one
#   firefox-prefs.sh where               print the record's path
#
# What `remove` guarantees, because the file it edits may be one the user has since made their
# own:
#   * it copies the file to a restorable backup BEFORE editing it, enrolled in a restore point,
#     so the edit itself goes back with `rice restore <apply-id>`; a file it cannot back up is
#     not edited at all;
#   * it removes ONLY the lines the record names for that profile, byte-for-byte; every other
#     line of that file is left exactly as it was;
#   * a recorded preference whose line has been changed by hand since is LEFT ALONE and reported
#     as changed - deleting a value the user chose is not this script's to do;
#   * a profile file that is no longer there is reported by path, never created, and never stops
#     the other profiles from being handled.
#
# Removing `toolkit.legacyUserProfileCustomizations.stylesheets` turns off Firefox's processing
# of userChrome.css, which is the whole of this plugin's browser theming: the chrome goes back to
# the browser's default look. That is why removal is a documented command and not something the
# plugin does on its own.
#
# Output (stdout, this repo's KEY=value convention):
#   PREF_REMOVED=<file> <key>          that line was removed
#   PREF_CHANGED=<file> <key>          changed by hand since; left alone
#   PREFS_MISSING=<file>               recorded, but the file is not there; nothing was created
#   PREFS_NOTHING=<file>               nothing recorded is still set there; the file was untouched
#   PREFS_SKIPPED=<file> (<why>)       could not be backed up, so it was NOT edited
#   RESTORE_POINT=<apply-id>           undo the removal itself: rice restore <apply-id>
#   PREFS=removed:<n> changed:<n> missing:<n> untouched:<n>
#
# Exit codes:
#   0  the run completed (including reported skips)
#   1  a profile file could not be backed up, so it was not edited
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/firefoxprefs.py).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
libdir=""
for c in "$here" "$here/../../../../scripts" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -f "$c/ricelib/firefoxprefs.py" ]; then libdir="$(cd "$c" && pwd)"; break; fi
done
if [ -z "$libdir" ]; then
    echo "ERROR: the ricelib package was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in \$RICE_DIR." >&2
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required and is not installed (sudo pacman -S --needed python)." >&2
    echo "ERROR: no profile file was edited." >&2
    exit 2
fi
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.firefoxprefs "$@"

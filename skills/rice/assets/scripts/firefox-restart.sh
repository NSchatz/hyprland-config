#!/usr/bin/env bash
# Reload hook for Firefox userChrome theming (Issue 15.2).
#
# Firefox reads userChrome.css and rice-colors.css only at process startup,
# so a `rice apply` while Firefox is open leaves the chrome on the old
# palette. This hook closes Firefox cleanly (relies on
# `browser.startup.page = 3` from user.js so tabs restore) and relaunches
# detached.
#
# Manifest line in templates.list:
#   firefox  TAB  <tmpl>/firefox.tmpl  TAB  <profile>/chrome/rice-colors.css  TAB  bash ~/.config/hypr-rice/firefox-restart.sh
#
# Behavior:
#   - Firefox not running              -> no-op, exit 0  (FIREFOX_RESTART=skipped)
#   - Running -> pkill + poll for lock release (~5s) + relaunch detached
#   - Profile lock never released      -> exit 0 with a warning (FIREFOX_RESTART=stuck)
#
# Brief-flash + session-restore caveat: the user sees a ~1s blank window
# while the browser restarts. Session restore brings every tab back; private
# windows (which Firefox does NOT include in session restore) are dropped.
# Document this in the interview when the user opts in.

set -uo pipefail

# 1. Bail fast if not running.
if ! pgrep -x firefox >/dev/null 2>&1; then
    echo "FIREFOX_RESTART=skipped (not running)"
    exit 0
fi

# 2. Send the close signal. Firefox saves session on clean exit.
pkill -x firefox 2>/dev/null || true

# 3. Wait for the profile lock to release (up to ~5s). Without this the
#    relaunch will pop a "Firefox is already running" dialog.
profile_dir=""
profiles_ini="$HOME/.mozilla/firefox/profiles.ini"
if [ -f "$profiles_ini" ]; then
    # Resolve the default profile path (Default=1 → use that profile's Path=).
    profile_dir="$(awk -F= '
        /^\[Profile/ { in_p=1; def=0; path="" }
        in_p && $1=="Default" && $2=="1" { def=1 }
        in_p && $1=="Path" { path=$2 }
        /^\[/ && !/^\[Profile/ { if (def && path) { print path; exit }; in_p=0 }
        END { if (def && path) print path }
    ' "$profiles_ini")"
    case "$profile_dir" in
        /*) ;;
        *)  profile_dir="$HOME/.mozilla/firefox/$profile_dir" ;;
    esac
fi

for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! pgrep -x firefox >/dev/null 2>&1; then
        if [ -n "$profile_dir" ] && [ -e "$profile_dir/.parentlock" ]; then
            sleep 0.5
            continue
        fi
        break
    fi
    sleep 0.5
done

if pgrep -x firefox >/dev/null 2>&1; then
    echo "FIREFOX_RESTART=stuck (Firefox still running after 5s; restart manually)" >&2
    exit 0
fi

# 4. Relaunch detached so this script doesn't tail the new process.
setsid firefox >/dev/null 2>&1 &
disown 2>/dev/null || true

echo "FIREFOX_RESTART=ok"

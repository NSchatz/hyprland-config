#!/usr/bin/env bash
# One-time bootstrap for Firefox userChrome theming (Issue 15.1).
# Run by install.sh (or invoked manually after the user runs Firefox once).
#
# Resolves the default Firefox profile from ~/.mozilla/firefox/profiles.ini
# (the profile dir name is dynamic — `xxxxxxxx.default-release` etc.),
# creates <profile>/chrome/ if missing, copies the static userChrome.css +
# user.js into place, and prints the resolved path so install.sh can write
# the templates.list manifest line.
#
# Usage:
#   firefox-bootstrap.sh                     # bootstrap default profile
#   firefox-bootstrap.sh --profile <dir>     # bootstrap a specific profile
#   firefox-bootstrap.sh --no-create-profile # don't auto-create if missing
#
# Output (stdout):
#   FIREFOX_PROFILE=<absolute-path>          # resolved profile directory
#   FIREFOX_CHROME=<absolute-path>           # the chrome/ subdir we wrote
#   FIREFOX_RICE_COLORS=<absolute-path>      # rice-colors.css render target
#   RESTORE_POINT=<apply-id>                 # undo it: rice restore <apply-id>
#
# Every profile file this touches is backed up first and enrolled in the apply's restore point,
# under the SAME apply id as every other surface of that apply when RICE_APPLY_ID is exported by
# the caller. A file whose backup cannot be written is not written at all (FIREFOX_SKIPPED).
#
# Exit codes:
#   0  bootstrap succeeded
#   1  no profile + --no-create-profile (user must launch Firefox first)
#   2  bad arguments / no Firefox installed

set -uo pipefail

# Config-path library: next to this script when installed into $RICE_DIR, else in the plugin.
# It is the one place this plugin decides where configuration lives.
_xdg_lib=""
for _c in "$(cd "$(dirname "$0")" && pwd)/xdg-config.sh" \
          "$(cd "$(dirname "$0")" && pwd)/../../../../scripts/xdg-config.sh" \
          "${CLAUDE_PLUGIN_ROOT:-}/scripts/xdg-config.sh"; do
    if [ -n "$_c" ] && [ -f "$_c" ]; then _xdg_lib="$_c"; break; fi
done
if [ -z "$_xdg_lib" ]; then
    echo "ERROR: the config-path library (xdg-config.sh) was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in the plugin - re-run rice-init.sh." >&2
    exit 2
fi
# shellcheck source=../../../../scripts/xdg-config.sh
. "$_xdg_lib"
if ! xdg_config_target hypr-rice "${RICE_DIR:-}"; then
    echo "FIREFOX=refused-no-config-dir" >&2
    exit 2
fi
RICE_DIR="$XDG_CONFIG_TARGET"
ASSETS="${FIREFOX_ASSETS_DIR:-$RICE_DIR/browser}"
auto_create=1
profile_override=""

# Restore-point library: next to this script when installed into $RICE_DIR, else in the plugin.
_rp_lib=""
for _c in "$(cd "$(dirname "$0")" && pwd)/restore-point.sh" \
          "$(cd "$(dirname "$0")" && pwd)/../../../../scripts/restore-point.sh" \
          "${CLAUDE_PLUGIN_ROOT:-}/scripts/restore-point.sh" \
          "$RICE_DIR/restore-point.sh"; do
    if [ -n "$_c" ] && [ -f "$_c" ]; then _rp_lib="$_c"; break; fi
done
if [ -z "$_rp_lib" ]; then
    echo "ERROR: restore-point library not found (looked next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, and in $RICE_DIR). Refusing to touch a Firefox profile without a way back - re-run rice-init.sh." >&2
    exit 2
fi
# shellcheck source=../../../../scripts/restore-point.sh
. "$_rp_lib"

# Preference-record library: the prefs merged below are re-applied by Firefox at every start and
# are not visible as changed in the browser's own UI, so a config restore does not undo them.
# Recording which ones this profile received is what makes the documented removal path
# (firefox-prefs.sh remove) possible at all - so a missing library is a refusal, exactly like a
# missing restore-point library, rather than a merge nobody can take back.
_fp_lib=""
for _c in "$(cd "$(dirname "$0")" && pwd)/firefox-prefs.sh" \
          "$(cd "$(dirname "$0")" && pwd)/../../../../scripts/firefox-prefs.sh" \
          "${CLAUDE_PLUGIN_ROOT:-}/scripts/firefox-prefs.sh" \
          "$RICE_DIR/firefox-prefs.sh"; do
    if [ -n "$_c" ] && [ -f "$_c" ]; then _fp_lib="$_c"; break; fi
done
if [ -z "$_fp_lib" ]; then
    echo "ERROR: preference-record library not found (looked next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, and in $RICE_DIR). Refusing to set preferences it cannot record or remove - re-run rice-init.sh." >&2
    exit 2
fi
# shellcheck source=../../../../scripts/firefox-prefs.sh
. "$_fp_lib"

while [ $# -gt 0 ]; do
    case "$1" in
        --profile)            shift; profile_override="${1:-}";;
        --no-create-profile)  auto_create=0;;
        -h|--help)            sed -n '2,18p' "$0"; exit 0;;
        *)                    echo "ERROR: unknown arg: $1" >&2; exit 2;;
    esac
    shift
done

command -v firefox >/dev/null 2>&1 || { echo "ERROR: firefox not installed" >&2; exit 2; }

ff_dir="$HOME/.mozilla/firefox"
profiles_ini="$ff_dir/profiles.ini"

resolve_default_profile() {
    [ -f "$profiles_ini" ] || return 1
    # Parse profiles.ini for the Default=1 profile, or fall back to the
    # first [Profile…] block. Path= may be relative ("xxxx.default-release")
    # or absolute ("/home/u/.mozilla/firefox/xxxx.default-release").
    awk -F= '
        BEGIN { in_p=0; def=0; path=""; first=""; first_set=0 }
        /^\[Profile/ {
            if (def && path) { print path; exit }
            in_p=1; def=0; path=""
            next
        }
        /^\[/ {
            if (def && path) { print path; exit }
            in_p=0; def=0; path=""
            next
        }
        in_p && $1=="Default" && $2=="1" { def=1 }
        in_p && $1=="Path" {
            path=$2
            if (!first_set) { first=path; first_set=1 }
        }
        END {
            if (def && path) print path
            else if (first_set) print first
        }
    ' "$profiles_ini"
}

if [ -n "$profile_override" ]; then
    profile_dir="$profile_override"
else
    profile_dir="$(resolve_default_profile || true)"
fi

if [ -z "$profile_dir" ]; then
    if [ "$auto_create" -eq 0 ]; then
        echo "ERROR: no Firefox profile found and --no-create-profile set" >&2
        echo "       launch Firefox once, then re-run this script" >&2
        exit 1
    fi
    # Use Firefox's documented headless CreateProfile flow. This writes
    # profiles.ini AND creates the profile directory with a random prefix
    # (e.g. xxxxxxxx.default-release).
    firefox --headless --no-remote --CreateProfile "default-release" >/dev/null 2>&1 || true
    profile_dir="$(resolve_default_profile || true)"
    if [ -z "$profile_dir" ]; then
        echo "ERROR: --CreateProfile didn't produce a usable profile" >&2
        exit 1
    fi
fi

# Absolutize.
case "$profile_dir" in
    /*) ;;
    *)  profile_dir="$ff_dir/$profile_dir" ;;
esac

if [ ! -d "$profile_dir" ]; then
    echo "ERROR: resolved profile dir does not exist: $profile_dir" >&2
    exit 1
fi

chrome_dir="$profile_dir/chrome"
# A chrome/ dir this step CREATES is a surface this apply wrote too: enrol it so the restore
# removes it again instead of leaving an empty orphan in the profile. An existing one is left to
# the per-file enrolments below - it was not created here, and folding its files into a
# directory-wide backup would drop the per-file sidecars the profile step has always written.
if [ ! -d "$chrome_dir" ]; then
    if ! rp_protect "$chrome_dir"; then
        echo "FIREFOX_SKIPPED $chrome_dir ($RP_LAST_ERROR)" >&2
        exit 2
    fi
fi
mkdir -p "$chrome_dir"

# Copy the static files. Don't clobber a user-modified userChrome.css
# without a backup — leave it intact and append an @import line if missing.
# The backup + restore-point enrolment happens BEFORE either write, under this apply's id, so
# `rice restore <apply-id>` puts the profile back with the rest of the apply.
if [ -f "$ASSETS/userChrome.css" ]; then
    if rp_protect "$chrome_dir/userChrome.css"; then
        if [ -e "$chrome_dir/userChrome.css" ] && \
           ! grep -q 'rice-colors.css' "$chrome_dir/userChrome.css"; then
            printf '\n/* hypr-rice: pull in rice-colors.css */\n@import "rice-colors.css";\n' \
                >> "$chrome_dir/userChrome.css"
        else
            cp "$ASSETS/userChrome.css" "$chrome_dir/userChrome.css"
        fi
    else
        echo "FIREFOX_SKIPPED $chrome_dir/userChrome.css ($RP_LAST_ERROR)" >&2
    fi
fi

# user.js — merge prefs idempotently (don't clobber user settings).
# Firefox re-applies every line here at each start and shows none of them as changed in its own
# UI, so these are the writes a config restore cannot undo. Each one this step ACTUALLY adds is
# recorded against this profile's absolute path before it is written, so `firefox-prefs.sh
# remove` can take exactly those lines back off later. A pref already in the file is left alone
# and is NOT recorded: this plugin did not set it and must not offer to remove it.

# `ff_line_terminated <file>` - true when the file is empty or its last byte is a newline.
# A `>>` append CONTINUES the last line of a file that does not end in one, which would glue a
# preference this plugin sets onto the end of a line the user wrote: the line the record names
# would then exist nowhere in the file, so the documented removal path could never take it back
# off, and it would report the plugin's own write as one the user changed by hand. Command
# substitution strips trailing newlines, so an unterminated last byte is the only thing that
# comes back non-empty.
ff_line_terminated() {
    [ -s "$1" ] || return 0
    [ -z "$(tail -c 1 "$1")" ]
}

if [ -f "$ASSETS/user.js" ]; then
    if rp_protect "$profile_dir/user.js"; then
        touch "$profile_dir/user.js"
        pref_record_failed=""
        while IFS= read -r line; do
            case "$line" in
                'user_pref('*)
                    key="$(printf '%s' "$line" | sed -n 's/^user_pref("\([^"]*\)".*$/\1/p')"
                    [ -n "$key" ] || continue
                    if ! grep -qF "user_pref(\"$key\"" "$profile_dir/user.js"; then
                        if ! fp_record "$profile_dir" "$line"; then
                            pref_record_failed="$FP_LAST_ERROR"
                            break
                        fi
                        # Terminate the user's last line first, and only when there is something
                        # to append: a file this step adds nothing to is left byte-identical.
                        ff_line_terminated "$profile_dir/user.js" || printf '\n' >> "$profile_dir/user.js"
                        printf '%s\n' "$line" >> "$profile_dir/user.js"
                        echo "FIREFOX_PREF_SET=$key"
                    fi
                    ;;
                *) : ;;
            esac
        done < "$ASSETS/user.js"
        if [ -n "$pref_record_failed" ]; then
            # A preference that cannot be recorded is a preference nothing documents a way back
            # from. Stop merging rather than set one: what was already recorded and written is
            # still removable, and `rice restore <apply-id>` still covers the file.
            echo "FIREFOX_PREFS_UNRECORDED $profile_dir/user.js ($pref_record_failed)" >&2
        fi
        echo "FIREFOX_PREF_RECORD=$(fp_record_file)"
    else
        echo "FIREFOX_SKIPPED $profile_dir/user.js ($RP_LAST_ERROR)" >&2
    fi
fi

# Emit the paths so install.sh can wire the manifest line + render the
# initial rice-colors.css.
echo "FIREFOX_PROFILE=$profile_dir"
echo "FIREFOX_CHROME=$chrome_dir"
echo "FIREFOX_RICE_COLORS=$chrome_dir/rice-colors.css"
if [ -n "${RICE_APPLY_ID:-}" ]; then
    echo "RESTORE_POINT=$RICE_APPLY_ID"
fi

#!/usr/bin/env bash
# WHERE THIS PLUGIN'S CONFIGURATION LIVES - the one decision, made once.
#
# Hyprland reads its config from `$XDG_CONFIG_HOME/hypr/hyprland.lua`; `~/.config/hypr`
# is only the common case (<https://wiki.hypr.land/Configuring/Start/>). A user who
# moved `XDG_CONFIG_HOME` moved their whole desktop's configuration, and every script
# here has to follow them there - otherwise the plugin backs up, installs, live-tests
# and reports success against a directory the compositor never reads.
#
# It is ONE decision on purpose. Five scripts each resolving their own target is how a
# backup gets taken from directory A while the reset wipes directory B, and that wipe
# has no inverse: the backup is of the wrong tree. Source this file; never re-spell the
# rule inline.
#
# The rule, in order:
#   1. an explicit override (HYPR_DIR, RICE_DIR, ...) wins outright, whatever
#      XDG_CONFIG_HOME holds - it is what the tests and power users set;
#   2. else $XDG_CONFIG_HOME, when it is an ABSOLUTE path;
#   3. else $HOME/.config, which is what the XDG base directory specification names as
#      the default when XDG_CONFIG_HOME "is either not set or empty";
#   4. else nothing: refuse, say so, and write nothing. Resolving `/.config` from an
#      unset HOME, or `.config` from the working directory, are both worse than stopping.
#
# A RELATIVE XDG_CONFIG_HOME is invalid, not merely unusual: "All paths set in these
# environment variables must be absolute. If an implementation encounters a relative
# path in any of these variables it should consider the path invalid and ignore it"
# (<https://specifications.freedesktop.org/basedir/latest/>). It is ignored, the default
# is used instead, and `xdg_config_notice` says both out loud - a silent fallback is how
# a user ends up with a config they cannot find.
#
# Only XDG_CONFIG_HOME. XDG_DATA_HOME, XDG_STATE_HOME, XDG_CACHE_HOME and
# XDG_RUNTIME_DIR are separate base directories with separate defaults; nothing here
# touches how a cache or runtime path resolves.
#
# Usage (sourced; never executed):
#     for _c in "$(cd "$(dirname "$0")" && pwd)/xdg-config.sh" \
#               "$(cd "$(dirname "$0")" && pwd)/../../../scripts/xdg-config.sh" \
#               "${CLAUDE_PLUGIN_ROOT:-}/scripts/xdg-config.sh"; do
#         [ -f "$_c" ] && { . "$_c"; break; }
#     done
#
# No `set` here on purpose: this file is sourced, and changing the caller's shell
# options behind its back (e.g. dropping its `set -e`) would be a bug in every caller
# at once.

# Resolution state, refreshed by every xdg_config_base_resolve call.
XDG_CONFIG_BASE=""          # the resolved absolute base dir (empty when unresolved)
XDG_CONFIG_BASE_SOURCE=""   # XDG_CONFIG_HOME | HOME
XDG_CONFIG_BASE_IGNORED=""  # the XDG_CONFIG_HOME value that was rejected as invalid
XDG_CONFIG_BASE_ERROR=""    # why no base could be determined
XDG_CONFIG_TARGET=""        # the directory the last xdg_config_target resolved
: "${XDG_CONFIG_NOTICE_DONE:=0}"   # the invalid-value notice is printed once per process

# Strip trailing slashes so `/tmp/cfg/` and `/tmp/cfg` are one path; `/` stays `/`.
xdg_trim_slashes() {
    local p="${1:-}"
    while [ "${#p}" -gt 1 ] && [ "${p%/}" != "$p" ]; do p="${p%/}"; done
    printf '%s\n' "$p"
}

# `xdg_config_base_resolve` - apply rules 2 to 4 above and leave the answer in
# XDG_CONFIG_BASE. Prints NOTHING (callers capture it in command substitutions);
# `xdg_config_notice` is what speaks. Returns 1 when no base can be determined.
xdg_config_base_resolve() {
    local v h
    XDG_CONFIG_BASE=""
    XDG_CONFIG_BASE_SOURCE=""
    XDG_CONFIG_BASE_IGNORED=""
    XDG_CONFIG_BASE_ERROR=""

    v="${XDG_CONFIG_HOME:-}"
    if [ -n "$v" ]; then
        case "$v" in
            /*)
                XDG_CONFIG_BASE="$(xdg_trim_slashes "$v")"
                XDG_CONFIG_BASE_SOURCE="XDG_CONFIG_HOME"
                return 0
                ;;
            *)
                # Relative: invalid per the specification. Remembered so the fallback
                # can be reported rather than taken silently.
                XDG_CONFIG_BASE_IGNORED="$v"
                ;;
        esac
    fi

    v="${HOME:-}"
    case "$v" in
        /*)
            h="$(xdg_trim_slashes "$v")"
            [ "$h" = "/" ] && h=""
            XDG_CONFIG_BASE="${h}/.config"
            XDG_CONFIG_BASE_SOURCE="HOME"
            return 0
            ;;
    esac

    XDG_CONFIG_BASE_ERROR="cannot determine a config directory: XDG_CONFIG_HOME=[${XDG_CONFIG_HOME-<unset>}] is not an absolute path and HOME=[${HOME-<unset>}] is not one either"
    return 1
}

# `xdg_config_notice` - the report a rejected XDG_CONFIG_HOME is owed: the value that
# was refused AND the absolute path used instead. Printed at most once per process, on
# stdout, in this repo's KEY=value convention. Silent when nothing was rejected.
xdg_config_notice() {
    if [ "${XDG_CONFIG_NOTICE_DONE:-0}" = "1" ]; then
        return 0
    fi
    if [ -z "${XDG_CONFIG_BASE_IGNORED:-}" ]; then
        return 0
    fi
    XDG_CONFIG_NOTICE_DONE=1
    printf 'XDG_CONFIG_HOME_IGNORED=%s\n' "$XDG_CONFIG_BASE_IGNORED"
    printf 'CONFIG_BASE=%s (XDG_CONFIG_HOME=%s is a relative path, which the XDG base directory specification says is invalid and must be ignored; the default was used instead)\n' \
        "$XDG_CONFIG_BASE" "$XDG_CONFIG_BASE_IGNORED"
    return 0
}

# `xdg_config_report_refusal` - what a caller prints when there is no config directory
# to write to. The caller adds its own terminal marker and exit code.
xdg_config_report_refusal() {
    printf 'ERROR: %s\n' "${XDG_CONFIG_BASE_ERROR:-cannot determine a config directory}" >&2
    printf 'ERROR: nothing was written. Set XDG_CONFIG_HOME to an absolute path, or set HOME.\n' >&2
    printf 'CONFIG_DIR=unresolved\n'
    return 0
}

# `xdg_config_path <name> [override]` - print the absolute directory for a config
# surface (`hypr`, `hypr-rice`, `waybar`, ...). Pure: no diagnostics, safe inside a
# command substitution. An empty <name> prints the base itself. Prints nothing and
# returns 1 when no base can be determined.
xdg_config_path() {
    local name="${1:-}" override="${2:-}"
    if [ -n "$override" ]; then
        printf '%s\n' "$override"
        return 0
    fi
    xdg_config_base_resolve || return 1
    if [ -z "$name" ]; then
        printf '%s\n' "$XDG_CONFIG_BASE"
    else
        printf '%s/%s\n' "$XDG_CONFIG_BASE" "$name"
    fi
    return 0
}

# `xdg_config_target <name> [override]` - the same answer, left in XDG_CONFIG_TARGET,
# with the diagnostics a user-facing run owes: the invalid-value notice on success, the
# refusal report on failure. Returns 1 when the caller must not write.
#
#     if ! xdg_config_target hypr "${HYPR_DIR:-}"; then
#         echo "RESET=refused-no-config-dir"; exit 4
#     fi
#     target="$XDG_CONFIG_TARGET"
xdg_config_target() {
    local name="${1:-}" override="${2:-}"
    XDG_CONFIG_TARGET=""
    if [ -n "$override" ]; then
        XDG_CONFIG_TARGET="$override"
        return 0
    fi
    if ! xdg_config_base_resolve; then
        xdg_config_report_refusal
        return 1
    fi
    xdg_config_notice
    if [ -z "$name" ]; then
        XDG_CONFIG_TARGET="$XDG_CONFIG_BASE"
    else
        XDG_CONFIG_TARGET="$XDG_CONFIG_BASE/$name"
    fi
    return 0
}

# `xdg_expand_path <path>` - expand a leading `~` the way this engine always has, with
# one difference: `~/.config/<rest>` names a CONFIG SURFACE, so it resolves under the
# base above rather than blindly under $HOME. That is what makes a render manifest row
# reading `~/.config/waybar/colors.css` land where the user's config actually lives.
#
# Every other `~/...` path - `~/.cache/...`, `~/.local/share/...`, `~/Pictures/...` -
# keeps expanding under $HOME exactly as before. Those are other base directories with
# their own variables, and this phase is the config one only.
#
# Returns 1 when a `~/.config` path had to fall back to a bare $HOME expansion because
# no base could be determined; the legacy value is still printed, since this helper is
# also used on read paths where refusing outright would be worse. Callers that WRITE
# resolve their target through xdg_config_target first and refuse there.
xdg_expand_path() {
    local p="${1:-}" rest
    case "$p" in
        '~/.config')
            if xdg_config_base_resolve; then
                printf '%s\n' "$XDG_CONFIG_BASE"
                return 0
            fi
            printf '%s/.config\n' "${HOME:-}"
            return 1
            ;;
        '~/.config/'*)
            rest="${p#\~/.config/}"
            if xdg_config_base_resolve; then
                printf '%s/%s\n' "$XDG_CONFIG_BASE" "$rest"
                return 0
            fi
            printf '%s/.config/%s\n' "${HOME:-}" "$rest"
            return 1
            ;;
        '~'|'~/'*)
            printf '%s\n' "${HOME:-}${p#\~}"
            return 0
            ;;
    esac
    printf '%s\n' "$p"
    return 0
}

# Sourcing defines the helpers. Executing it reports the resolution, which is the
# quickest way for a user to see where this plugin thinks their config lives.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if xdg_config_base_resolve; then
        xdg_config_notice
        printf 'CONFIG_BASE=%s\n' "$XDG_CONFIG_BASE"
        printf 'CONFIG_BASE_SOURCE=%s\n' "$XDG_CONFIG_BASE_SOURCE"
        printf 'HYPR_DIR=%s\n' "$(xdg_config_path hypr "${HYPR_DIR:-}")"
        printf 'RICE_DIR=%s\n' "$(xdg_config_path hypr-rice "${RICE_DIR:-}")"
        exit 0
    fi
    xdg_config_report_refusal
    exit 4
fi

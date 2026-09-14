#!/usr/bin/env bash
# Test that the live Hyprland config actually loads, by reloading and reading
# `hyprctl configerrors`. This is the real "does it work" check — static analysis
# cannot catch everything.
#
# Usage:
#   verify-config.sh              reload, then report parse errors
#   verify-config.sh --no-reload  do NOT reload; just read current errors (read-only)
#   verify-config.sh --expect <file>
#                                 additionally require the compositor to CONFIRM
#                                 that <file> is the config it loaded. Without a
#                                 positive match there is no `ok`.
#
# Output (machine-parseable first line):
#   VERIFY=ok           config is loaded with no parse errors
#   VERIFY=errors       parse errors present (printed below the status line)
#   VERIFY=skipped      no running Hyprland instance / hyprctl missing (cannot live-test)
#   VERIFY=unconfirmed  --expect was given and the compositor did NOT confirm it
#                       loaded that file: either it named a different one (printed
#                       as LOADED_CONFIG=) or it named none at all
#
# Example:
#   verify-config.sh --expect ~/.config/hypr/hyprland.conf
#
# Options: -h, --help, help, --no-reload, --expect <file>
# Subcommands: none
#
# Exit codes:
#   0  ok: the config is loaded with no parse errors
#   1  verdict: the loaded config has parse errors
#   2  usage: an unknown argument, or --expect with no file after it
#   3  capability: no running Hyprland instance to ask, or the running one would not name the
#      config it loaded, so the check could not be made. Never a verdict about the config
#
# Note: `hyprctl configerrors` always exits 0 and prints nothing when clean, so the
# verdict comes from whether its (non-blank) output is empty, not from its exit code.
#
# WHY --expect exists: an empty `configerrors` is ALSO exactly what a config that
# was never parsed produces: a `hyprland.lua` shadowing the `hyprland.conf` this
# plugin just wrote, or an instance started with `-c` somewhere else. Reading that
# silence as success is how a no-op reports `ok`. Any caller that goes on to tell
# a user their config is LIVE must pass --expect; `loaded-config.sh` is the thing
# that makes the compositor name the file.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

reload=1
expect=""
while [ "$#" -gt 0 ]; do
    case "$1" in   # [cli-parser]
        -h|--help|help)
            sed -n '2,${/^#/!q;s/^#\{1,2\} \{0,1\}//p}' "$0"
            exit 0 ;;   # rc=ok
        --no-reload) reload=0; shift ;;
        --expect)
            [ "$#" -ge 2 ] || { echo "ERROR: --expect needs a file" >&2; exit 2; }   # rc=usage
            expect="$2"; shift 2 ;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;   # rc=usage
    esac
done

if ! command -v hyprctl >/dev/null 2>&1 || ! hyprctl version >/dev/null 2>&1; then
    # No compositor to ask: the live check could not RUN. Reporting this as a verdict would
    # let a caller read "never tested" as "tested and fine".
    echo "VERIFY=skipped (no running Hyprland instance; rely on static validation)"
    exit 3   # rc=capability
fi

if [ "$reload" -eq 1 ]; then
    # Reload picks up on-disk changes. Does NOT re-run exec-once entries. It also
    # makes the compositor re-log the config files it reads, which is what
    # loaded-config.sh reads back below.
    hyprctl reload >/dev/null 2>&1 || true
fi

# Clean output is blank line(s); strip them. Anything left is a real error.
errs="$(hyprctl configerrors 2>/dev/null | sed '/^[[:space:]]*$/d')"

if [ -n "$errs" ]; then
    echo "VERIFY=errors"
    printf '%s\n' "$errs"
    exit 1   # rc=verdict
fi

if [ -z "$expect" ]; then
    echo "VERIFY=ok (config loaded, no parse errors)"
    exit 0   # rc=ok
fi

# --- The identity check: an empty error list is not evidence on its own ----------------------
loaded_out="$(bash "$here/loaded-config.sh" 2>/dev/null)"
printf '%s\n' "$loaded_out"

canon() { readlink -f -- "$1" 2>/dev/null || printf '%s\n' "$1"; }
want="$(canon "$expect")"

matched=0
while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ "$p" = "unknown" ] && continue
    if [ "$(canon "$p")" = "$want" ]; then matched=1; break; fi
done < <(printf '%s\n' "$loaded_out" | sed -n 's/^LOADED_CONFIG=//p')

if [ "$matched" -eq 1 ]; then
    echo "CONFIRMED_CONFIG=${expect}"
    echo "VERIFY=ok (the compositor confirms it loaded ${expect}, with no parse errors)"
    exit 0   # rc=ok
fi

echo "EXPECTED_CONFIG=${expect}"
echo "VERIFY=unconfirmed (no parse errors, but the compositor did not confirm it loaded ${expect}; an empty error list is also what a config that was never parsed produces)"
# The identity check could not be MADE: the running compositor did not name a config. That is a
# missing capability, not a verdict about ${expect} - the install is left standing.
exit 3   # rc=capability

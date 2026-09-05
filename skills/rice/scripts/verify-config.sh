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
# Exit codes: 0 = ok, 1 = errors, 2 = skipped (could not test), 3 = unconfirmed.
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
    case "$1" in
        --no-reload) reload=0; shift ;;
        --expect)
            [ "$#" -ge 2 ] || { echo "ERROR: --expect needs a file" >&2; exit 2; }
            expect="$2"; shift 2 ;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
    esac
done

if ! command -v hyprctl >/dev/null 2>&1 || ! hyprctl version >/dev/null 2>&1; then
    echo "VERIFY=skipped (no running Hyprland instance; rely on static validation)"
    exit 2
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
    exit 1
fi

if [ -z "$expect" ]; then
    echo "VERIFY=ok (config loaded, no parse errors)"
    exit 0
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
    exit 0
fi

echo "EXPECTED_CONFIG=${expect}"
echo "VERIFY=unconfirmed (no parse errors, but the compositor did not confirm it loaded ${expect}; an empty error list is also what a config that was never parsed produces)"
exit 3

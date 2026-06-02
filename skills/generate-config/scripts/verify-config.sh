#!/usr/bin/env bash
# Test that the live Hyprland config actually loads, by reloading and reading
# `hyprctl configerrors`. This is the real "does it work" check — static analysis
# cannot catch everything.
#
# Usage:
#   verify-config.sh              reload, then report parse errors
#   verify-config.sh --no-reload  do NOT reload; just read current errors (read-only)
#
# Output (machine-parseable first line):
#   VERIFY=ok           config is loaded with no parse errors
#   VERIFY=errors       parse errors present (printed below the status line)
#   VERIFY=skipped      no running Hyprland instance / hyprctl missing (cannot live-test)
#
# Exit codes: 0 = ok, 1 = errors, 2 = skipped (could not test).
#
# Note: `hyprctl configerrors` always exits 0 and prints nothing when clean, so the
# verdict comes from whether its (non-blank) output is empty, not from its exit code.
set -uo pipefail

reload=1
if [ "${1:-}" = "--no-reload" ]; then
    reload=0
fi

if ! command -v hyprctl >/dev/null 2>&1 || ! hyprctl version >/dev/null 2>&1; then
    echo "VERIFY=skipped (no running Hyprland instance; rely on static validation)"
    exit 2
fi

if [ "$reload" -eq 1 ]; then
    # Reload picks up on-disk changes. Does NOT re-run exec-once entries.
    hyprctl reload >/dev/null 2>&1 || true
fi

# Clean output is blank line(s); strip them. Anything left is a real error.
errs="$(hyprctl configerrors 2>/dev/null | sed '/^[[:space:]]*$/d')"

if [ -z "$errs" ]; then
    echo "VERIFY=ok (config loaded, no parse errors)"
    exit 0
fi

echo "VERIFY=errors"
printf '%s\n' "$errs"
exit 1

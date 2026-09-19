#!/usr/bin/env bash
# Is the reference layer's version-cliff ledger CITED, and how far has it fallen
# behind upstream?
#
# The plugin's reference layer is a pile of claims about someone else's software.
# This check gives those claims two properties they otherwise cannot have:
#   1. every version-cliff record NAMES the upstream that decided it, and
#   2. the repo can say which records have not been confirmed against the newest
#      Hyprland release.
#
# It is OFFLINE and deterministic. It never fetches anything: the newest release
# is an INPUT, supplied on the command line or read from the ledger's own
# metadata row. It needs no Hyprland binary and no running compositor.
#
# Usage:
#   currency-check.sh [--root DIR] [--ledger FILE] [--newest-release VER]
#
#   --root DIR             plugin root to scan (default: this script's plugin)
#   --ledger FILE          the version-cliff ledger (default: <root>'s matrix)
#   --newest-release VER   the newest upstream Hyprland release, e.g. 0.56.2.
#                          Overrides the ledger's `newest-release` metadata row.
#
# Env: HYPR_NEWEST_RELEASE  same as --newest-release.
#
# Output (KEY=value lines, the convention every script here follows):
#   CURRENCY_LEDGER=<path>
#   CURRENCY_ROOT=<path>
#   CURRENCY_SCANNED=<n>                files read from the reference layer
#   CURRENCY_RECORDS=<n>                version-cliff records found in the ledger
#   CURRENCY_REMOVED_KEY_RECORDS=<n>    rows of the derived removed-key table
#   CURRENCY_NEWEST_RELEASE=<x.y.z|unknown>
#   CURRENCY_NEWEST_RELEASE_SOURCE=<supplied|ledger|none>
#   UNREADABLE=<path>                   one per file/dir named but not readable
#   UNCITED=<file> | <record> | <claim>
#   UNRESOLVABLE=<file> | <record> | <claim> | <reason>
#   UNLEDGERED_CLIFF=<file>:<line> | <version>+ | <text>
#   STALE=<file> | <record> | <claim> | last confirmed against <v> | newest is <v>
#   STALE_CLAIM=<file>:<line> | names <v> | newest is <v> | <text>
#   CURRENCY_UNCITED=<n>  CURRENCY_UNRESOLVABLE=<n>  CURRENCY_UNLEDGERED=<n>
#   CURRENCY_STALE=<n>
#   CURRENCY=<ok|defects|undetermined-newest-release|no-records|unreadable>
#
# Exit codes, in precedence order (the first that applies wins):
#   5  a file or directory the check is CONFIGURED to scan is missing/unreadable
#   4  the ledger matched ZERO version-cliff records - a check that has stopped
#      matching anything must never read as a clean pass
#   3  the newest release was neither supplied nor readable from the repo
#   2  bad usage
#   1  repo-owned defects: an uncited record, an unresolvable citation, or a
#      cliff asserted outside the ledger that the ledger does not record
#   0  clean. STALENESS ALONE NEVER FAILS: it is reported and the build goes on,
#      because upstream shipping a release is not a defect in this repo.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/currencycheck.py). This file locates
# the package and hands off; the name is the interface every caller, doc and test uses.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
libdir=""
for c in "$here" "$here/../../../scripts" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -f "$c/ricelib/__init__.py" ]; then libdir="$(cd "$c" && pwd)"; break; fi
done
if [ -z "$libdir" ]; then
    echo "ERROR: the ricelib package was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in \$RICE_DIR." >&2
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required and is not installed (sudo pacman -S --needed python)." >&2
    exit 2
fi
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.currencycheck "$@"

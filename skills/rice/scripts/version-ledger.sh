#!/usr/bin/env bash
# Read the VERSION-CLIFF LEDGER - `references/_shared/version-matrix.md` - offline.
#
# One parser, shared by the two programs that enforce the ledger's contract:
#   scripts/currency-check.sh        citations, out-of-ledger cliffs, staleness
#   scripts/validate-removed-keys.sh the removed-key set a generated config is
#                                    checked against
#
# Sourcing this file defines the helpers WITHOUT running anything, so both
# programs share ONE definition of what a record is, what a citation must
# resolve to, and where the ledger lives. Nothing here touches the network and
# nothing here needs a Hyprland binary or a running compositor.
#
# The format these helpers parse is declared, in prose, in the ledger itself
# under "Version-cliff record format". That section is the contract; this file
# is only its reader.

# Field separator for every multi-column line these helpers emit. NOT a tab:
# bash's `read` treats tab as IFS whitespace and COLLAPSES a run of them, so an
# empty cell in the middle of a row - exactly the shape of an uncited record -
# would silently shift every field after it. US (0x1f) is not IFS whitespace and
# cannot appear in a markdown table cell.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/ledger.py). This file locates
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.ledger "$@"

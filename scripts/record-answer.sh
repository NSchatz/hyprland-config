#!/usr/bin/env bash
# Record one interview answer into a JSON file, creating it if absent.
#
# This is a thin wrapper around `record-answer.py`. The actual implementation lives
# in Python so generation-time tooling has no `jq` dependency (jq is one of the
# packages the rice itself installs; the interview runs *before* that batch lands).
# Runtime scripts (keybind-cheatsheet.sh, etc.) keep using jq because they execute
# after install.
#
# Usage:
#   record-answer.sh <answers-file> <key.path> <value>            # string value
#   record-answer.sh <answers-file> <key.path> --json <jsonval>   # array/object/number/bool/null
#
# Exit codes match record-answer.py:
#   0  ok
#   1  missing arguments
#   2  invalid JSON / corrupt target / IO error
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$here/record-answer.py" "$@"

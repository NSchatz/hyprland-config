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
# Example:
#   record-answer.sh /tmp/hypr-gen-abc/answers.json palette.scheme catppuccin-mocha
#
# Options: -h, --help, help, --json
# Subcommands: none
#
# Exit codes:
#   0  ok: the answer is recorded
#   2  usage: a missing argument, an invalid key path, or a --json value that is not JSON
#   3  capability: python3 is not on PATH, and this wrapper needs it to record anything
#   5  input: the answers file it was given is unreadable, is not valid JSON, does not hold a
#      JSON object at the top level, or could not be written
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:-}" in   # [cli-parser]
    -h|--help|help)
        sed -n '2,${/^#/!q;s/^#\{1,2\} \{0,1\}//p}' "$0"
        exit 0 ;;   # rc=ok
esac

command -v python3 >/dev/null 2>&1 || {
    echo "ERROR: python3 is not on PATH; record-answer.sh needs it to record an answer." >&2
    exit 3   # rc=capability
}

# record-answer.py speaks the same table, so this is a pass-through with an explicit vocabulary
# rather than an `exec` that hands back whatever the interpreter felt like.
_ra_rc=0
python3 "$here/record-answer.py" "$@" || _ra_rc=$?
case "$_ra_rc" in
    0) exit 0 ;;   # rc=ok
    2) exit 2 ;;   # rc=usage
    # The interpreter can only fail over the file or the value it was handed, and the write is a
    # temp file plus a rename, so the answers file is untouched when it does.
    *) exit 5 ;;   # rc=input
esac

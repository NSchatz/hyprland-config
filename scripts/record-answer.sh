#!/usr/bin/env bash
# Record one interview answer into a JSON file, creating it if absent.
# The interviewer agent (rice Mode A1) calls this after each AskUserQuestion, so downstream
# steps (A3 file gen, A3d packages, A4 palette, the component-writer agents) read picks
# deterministically from disk instead of recalling them from a long chat history.
#
# Usage:
#   record-answer.sh <answers-file> <key.path> <value>            # string value
#   record-answer.sh <answers-file> <key.path> --json <jsonval>   # array / object / number / bool
#
# Examples:
#   record-answer.sh /tmp/hypr-gen-abc/answers.json palette.scheme catppuccin-mocha
#   record-answer.sh /tmp/hypr-gen-abc/answers.json bar.modules --json '["workspaces","clock","tray"]'
#   record-answer.sh /tmp/hypr-gen-abc/answers.json laptop.enabled --json true
#   record-answer.sh /tmp/hypr-gen-abc/answers.json notifications.timeout --json 5
#
# Prints the final value back so the caller can confirm it landed (and the agent's response
# stays self-documenting in the conversation).
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required (install jq)" >&2
    exit 2
fi

f="${1:?usage: record-answer.sh <file> <key.path> <value> | <key.path> --json <jsonval>}"
k="${2:?missing key.path}"
shift 2

case "$f" in "~"*) f="${HOME}${f#\~}";; esac
mkdir -p "$(dirname "$f")"
[ -f "$f" ] || echo '{}' > "$f"

# Validate the existing file parses — a corrupt answers.json is a clear failure mode.
if ! jq -e . "$f" >/dev/null 2>&1; then
    echo "ERROR: $f is not valid JSON (delete it to start over, or fix by hand)" >&2
    exit 2
fi

tmp="$(mktemp)"
if [ "${1:-}" = "--json" ]; then
    jval="${2:?missing JSON value after --json}"
    # Validate the JSON value parses before merging. Use plain `jq .` (not `-e`) so a literal
    # `false` or `null` doesn't get misclassified as a parse failure.
    if ! printf '%s' "$jval" | jq . >/dev/null 2>&1; then
        echo "ERROR: --json value is not valid JSON: $jval" >&2
        rm -f "$tmp"; exit 2
    fi
    jq --arg p "$k" --argjson v "$jval" 'setpath($p / "."; $v)' "$f" > "$tmp"
else
    sval="${1:?missing value}"
    jq --arg p "$k" --arg v "$sval" 'setpath($p / "."; $v)' "$f" > "$tmp"
fi
mv "$tmp" "$f"

# Echo the final stored value so the agent can confirm it.
final="$(jq -r --arg p "$k" 'getpath($p / ".")' "$f")"
echo "RECORDED ${k}=${final}"

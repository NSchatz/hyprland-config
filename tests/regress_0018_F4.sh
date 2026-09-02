#!/usr/bin/env bash
# S0018 impl-gate loop 2 - exploratory probe.
# Converts the plugin's own sample-config set with migrate-config.sh and dumps
# the produced lua so it can be inspected, plus reports which interpreters are
# available for a syntax check.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIG="$ROOT/skills/rice/scripts/migrate-config.sh"
SAMPLE="$ROOT/skills/rice/examples/sample-config"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/regress0018F4.XXXXXX")"
dir="$tmp/hypr"
mkdir -p "$dir"
cp -a "$SAMPLE"/. "$dir"/

echo "== interpreters =="
for c in lua lua5.4 lua5.3 luajit luac luac5.4 python3 node; do
    if command -v "$c" >/dev/null 2>&1; then echo "HAVE $c -> $(command -v "$c")"; else echo "MISS $c"; fi
done

echo
echo "== convert =="
out="$(HYPR_DIR="$dir" bash "$MIG" --convert 2>&1)"; rc=$?
echo "rc=$rc"
printf '%s\n' "$out" | grep -E '^(MIGRATE|WROTE|KEPT|NOT_APPLIED_COUNT|BACKED_UP)=' | head -40

for f in "$dir"/*.lua; do
    echo
    echo "===== FILE $(basename "$f") ====="
    cat -A /dev/null >/dev/null 2>&1
    cat "$f"
done

rm -rf "$tmp"

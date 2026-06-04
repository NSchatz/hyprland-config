#!/usr/bin/env bash
# Entry point for the plugin test suite.
# Usage:  bash tests/run.sh            # run every test_*.sh in this dir
#         bash tests/run.sh syntax     # run only tests matching "syntax"
# Exit:   0 if all tests passed (skipped is fine), 1 if any failed.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$TESTS_DIR/lib.sh"

filter="${1:-}"

# Collect test files in stable order.
mapfile -t test_files < <(find "$TESTS_DIR" -maxdepth 1 -name 'test_*.sh' -print | sort)
if [ "${#test_files[@]}" -eq 0 ]; then
    echo "No test files found in $TESTS_DIR" >&2
    exit 2
fi

total_pass=0
total_fail=0
total_skip=0
failed_files=()

start_ts="$(date +%s)"
echo "hyprland-config test suite"
echo "  plugin root: $PLUGIN_ROOT"
echo "  tests:       ${#test_files[@]}"
echo

for tf in "${test_files[@]}"; do
    tname="$(basename "$tf" .sh)"
    if [ -n "$filter" ] && [[ "$tname" != *"$filter"* ]]; then
        continue
    fi
    section "$tname"
    # Run in a subshell so cd/env can't leak. The test file uses pass/fail/skip from lib.sh and
    # writes counters as the final line for run.sh to parse.
    output="$(
        set +u
        # shellcheck source=lib.sh
        source "$TESTS_DIR/lib.sh"
        # shellcheck source=/dev/null
        source "$tf"
        printf 'COUNTERS %d %d %d\n' "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    )"
    # Print everything except the counter line.
    printf '%s\n' "$output" | sed '/^COUNTERS /d'
    # Parse the counter line.
    counters="$(printf '%s\n' "$output" | grep '^COUNTERS ' | tail -n1)"
    if [ -n "$counters" ]; then
        # shellcheck disable=SC2086
        set -- $counters
        # shift "COUNTERS" off
        shift
        total_pass=$((total_pass + ${1:-0}))
        total_fail=$((total_fail + ${2:-0}))
        total_skip=$((total_skip + ${3:-0}))
        if [ "${2:-0}" -gt 0 ]; then
            failed_files+=("$tname")
        fi
    fi
done

elapsed=$(( $(date +%s) - start_ts ))

printf '\n%s─── Summary ───%s\n' "$C_DIM" "$C_RESET"
printf '  %s%d passed%s' "$C_GREEN" "$total_pass" "$C_RESET"
if [ "$total_skip" -gt 0 ]; then printf ', %s%d skipped%s' "$C_YELLOW" "$total_skip" "$C_RESET"; fi
if [ "$total_fail" -gt 0 ]; then printf ', %s%d failed%s' "$C_RED" "$total_fail" "$C_RESET"; fi
printf '  %s(%ss)%s\n' "$C_DIM" "$elapsed" "$C_RESET"

if [ "$total_fail" -gt 0 ]; then
    printf '\n%sFailed in:%s\n' "$C_RED" "$C_RESET"
    for f in "${failed_files[@]}"; do printf '  - %s\n' "$f"; done
    exit 1
fi
exit 0

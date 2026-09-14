#!/usr/bin/env bash
# Entry point for the plugin test suite.
# Usage:  bash tests/run.sh            # run every test_*.sh in this dir
#         bash tests/run.sh syntax     # run only tests matching "syntax"
#
# Example:
#   RUN_INTEGRATION=1 bash tests/run.sh integration
#
# Options: -h, --help
#   The single positional argument is a FILTER, a substring of a test file's name, and is
#   deliberately not an option: `help` is a filter like any other, and a filter that matches
#   nothing exits 2 rather than reporting a clean pass.
#
# Exit codes:
#   0  ok: every test that ran passed (skipped is fine)
#   1  verdict: at least one test failed
#   2  usage: the filter matched no test file. Running nothing is not a pass
#   5  input: the tests directory holds no test file at all
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$TESTS_DIR/lib.sh"

case "${1:-}" in   # [cli-parser]
    -h|--help)
        sed -n '2,${/^#/!q;s/^#\{1,2\} \{0,1\}//p}' "$0"
        exit 0 ;;   # rc=ok
esac

filter="${1:-}"

# Collect test files in stable order.
mapfile -t test_files < <(find "$TESTS_DIR" -maxdepth 1 -name 'test_*.sh' -print | sort)
if [ "${#test_files[@]}" -eq 0 ]; then
    echo "No test files found in $TESTS_DIR" >&2
    exit 5   # rc=input
fi

total_pass=0
total_fail=0
total_skip=0
failed_files=()

matched=0
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
    matched=$((matched + 1))
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

# A filter that selected nothing ran no test at all, and "no test ran" must never read as
# "every test passed": that green is the one this harness cannot afford to print.
if [ "$matched" -eq 0 ]; then
    printf '\n%sNo test file matches the filter %s; nothing ran.%s\n' "$C_RED" "'$filter'" "$C_RESET" >&2
    printf 'Available: %s\n' "$(for tf in "${test_files[@]}"; do printf '%s ' "$(basename "$tf" .sh)"; done)" >&2
    exit 2   # rc=usage
fi

elapsed=$(( $(date +%s) - start_ts ))

printf '\n%s─── Summary ───%s\n' "$C_DIM" "$C_RESET"
printf '  %s%d passed%s' "$C_GREEN" "$total_pass" "$C_RESET"
if [ "$total_skip" -gt 0 ]; then printf ', %s%d skipped%s' "$C_YELLOW" "$total_skip" "$C_RESET"; fi
if [ "$total_fail" -gt 0 ]; then printf ', %s%d failed%s' "$C_RED" "$total_fail" "$C_RESET"; fi
printf '  %s(%ss)%s\n' "$C_DIM" "$elapsed" "$C_RESET"

if [ "$total_fail" -gt 0 ]; then
    printf '\n%sFailed in:%s\n' "$C_RED" "$C_RESET"
    for f in "${failed_files[@]}"; do printf '  - %s\n' "$f"; done
    exit 1   # rc=verdict
fi
exit 0   # rc=ok

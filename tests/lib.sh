#!/usr/bin/env bash
# Shared assertion + helper library for the plugin's test suite.
# Sourced by tests/run.sh and every tests/test_*.sh file. No execution on its own.

# Plugin root (resolved relative to this file so tests work from any cwd).
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

# Colors only when stdout is a tty.
if [ -t 1 ]; then
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
else
    C_RED=; C_GREEN=; C_YELLOW=; C_DIM=; C_RESET=
fi

# Per-file counters (run.sh aggregates).
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
FAILED_NAMES=()
SKIPPED_NAMES=()

# `pass <name>` / `fail <name> [<detail>]` / `skip <name> <reason>` print one line each.
pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$1"
}
fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_NAMES+=("$1")
    printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$1"
    if [ -n "${2:-}" ]; then
        # Indent the detail lines.
        printf '%s' "$2" | sed 's/^/      /'
        printf '\n'
    fi
}
skip() {
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    SKIPPED_NAMES+=("$1")
    printf '  %s○%s %s %s(%s)%s\n' "$C_YELLOW" "$C_RESET" "$1" "$C_DIM" "${2:-skipped}" "$C_RESET"
}

# `assert_eq <expected> <actual> <test-name>` — equality.
assert_eq() {
    local expected="$1" actual="$2" name="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$name"
    else
        fail "$name" "expected: $expected
  actual: $actual"
    fi
}

# `assert_ok <command...>` — command must exit 0.
assert_ok() {
    local name="$1"; shift
    local out rc
    out="$("$@" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        pass "$name"
    else
        fail "$name" "exit $rc
  output: $out"
    fi
}

# `assert_fail <expected-rc> <name> <command...>` — command must exit with the given non-zero rc.
assert_fail() {
    local expected_rc="$1" name="$2"; shift 2
    local out rc
    out="$("$@" 2>&1)"; rc=$?
    if [ "$rc" -eq "$expected_rc" ]; then
        pass "$name"
    else
        fail "$name" "expected exit $expected_rc, got $rc
  output: $out"
    fi
}

# `assert_file_exists <path> <name>` / `assert_file_contains <path> <substring> <name>`.
assert_file_exists() {
    if [ -e "$1" ]; then pass "$2"; else fail "$2" "missing: $1"; fi
}
assert_file_contains() {
    local path="$1" needle="$2" name="$3"
    if [ ! -f "$path" ]; then
        fail "$name" "file missing: $path"
        return
    fi
    if grep -qF "$needle" "$path"; then
        pass "$name"
    else
        fail "$name" "needle not found in $path: $needle"
    fi
}

# `assert_grep <pattern> <file> <name>` — same as assert_file_contains but lets the caller pass a regex.
assert_grep() {
    local pattern="$1" path="$2" name="$3"
    if [ ! -f "$path" ]; then
        fail "$name" "file missing: $path"
        return
    fi
    if grep -qE "$pattern" "$path"; then
        pass "$name"
    else
        fail "$name" "pattern not matched in $path: $pattern"
    fi
}

# Make a temp dir that's wiped on exit. Each test file gets its own scoped dir.
mktemp_test_dir() {
    local prefix="${1:-hypr-test}"
    local d
    d="$(mktemp -d "/tmp/${prefix}.XXXXXX")"
    # Don't trap globally — the run.sh entry point traps; tests just rm -rf at the end.
    echo "$d"
}

# Run a single test file in a subshell so its trap/cd/env can't leak.
# Counters are read back via the file's stdout, which run.sh parses.
section() {
    printf '\n%s── %s%s\n' "$C_DIM" "$1" "$C_RESET"
}

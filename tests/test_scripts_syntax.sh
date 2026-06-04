#!/usr/bin/env bash
# Parse-check every shell script the plugin ships. Catches the boring typo class — missing `fi`,
# unbalanced quote, stray here-doc — before it reaches a user. `bash -n` does not execute the
# script; it just parses it.
#
# Also runs shellcheck if installed (warns but does not fail on style — only on hard issues).

# Collect every .sh under the plugin root, excluding tests/ (those have their own coverage).
mapfile -t scripts < <(
    find "$PLUGIN_ROOT" -type f \( -name '*.sh' -o -name 'rice' \) \
        -not -path '*/tests/*' \
        -not -path '*/.git/*' \
    | sort
)

# The generated rice CLI ships under assets/rice without a .sh suffix — include it.
# (find above already picks it up via the `-name 'rice'` clause; this is the documentation.)

if [ "${#scripts[@]}" -eq 0 ]; then
    fail "scripts:found" "no .sh files discovered under $PLUGIN_ROOT"
    return 0
fi

# bash -n syntax check on every script.
syntax_failures=()
for s in "${scripts[@]}"; do
    if ! err="$(bash -n "$s" 2>&1)"; then
        syntax_failures+=("$s:$err")
    fi
done

if [ "${#syntax_failures[@]}" -eq 0 ]; then
    pass "bash -n: ${#scripts[@]} scripts parse cleanly"
else
    detail=""
    for sf in "${syntax_failures[@]}"; do detail+="$sf"$'\n'; done
    fail "bash -n: ${#syntax_failures[@]} scripts have syntax errors" "$detail"
fi

# Optional shellcheck pass. Only fails on `error` severity to keep the suite useful in CI
# without forcing a `set -e`-style cleanup of every existing script.
if command -v shellcheck >/dev/null 2>&1; then
    sc_failures=()
    for s in "${scripts[@]}"; do
        # -S error caps severity at error (not warning/info). Disable a few rules that fire
        # widely on this codebase's intentional patterns:
        #   SC1091 — sourced file not found (we source via $CLAUDE_PLUGIN_ROOT at runtime)
        #   SC2034 — unused vars (the CLI scripts expose env defaults)
        if ! out="$(shellcheck -S error -e SC1091,SC2034 "$s" 2>&1)"; then
            sc_failures+=("$s"$'\n'"$out")
        fi
    done
    if [ "${#sc_failures[@]}" -eq 0 ]; then
        pass "shellcheck (errors only): ${#scripts[@]} scripts clean"
    else
        detail=""
        for sf in "${sc_failures[@]}"; do detail+="$sf"$'\n'; done
        fail "shellcheck: ${#sc_failures[@]} scripts have errors" "$detail"
    fi
else
    skip "shellcheck" "not installed"
fi

# Every script under scripts/ should be marked executable — they're invoked via `bash` so it
# isn't strictly required, but it's a useful convention. SKILL-shipped assets (assets/scripts/*)
# also need +x because the user copies them and binds them.
non_exec=()
for s in "${scripts[@]}"; do
    case "$s" in
        # The rice CLI ships with +x.
        */assets/rice)        [ -x "$s" ] || non_exec+=("$s") ;;
        */scripts/*.sh)       [ -x "$s" ] || non_exec+=("$s") ;;
        */assets/scripts/*.sh) [ -x "$s" ] || non_exec+=("$s") ;;
    esac
done
if [ "${#non_exec[@]}" -eq 0 ]; then
    pass "scripts have +x bit set"
else
    detail=""
    for ne in "${non_exec[@]}"; do detail+="$ne"$'\n'; done
    fail "${#non_exec[@]} scripts missing +x" "$detail"
fi

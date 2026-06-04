#!/usr/bin/env bash
# skills/rice/scripts/verify-shell.sh — parse-only shell rc check. The "test after every edit"
# step for the shell-rc surface of the edit-config skill. Critical that it NEVER sources / runs
# the file (sourcing user rc has surprising side effects).

script="$PLUGIN_ROOT/skills/rice/scripts/verify-shell.sh"
assert_file_exists "$script" "verify-shell.sh present"

tmp="$(mktemp_test_dir verify-shell)"
trap 'rm -rf "$tmp"' EXIT

# Bash: clean parse → VERIFY_SHELL=ok.
cat > "$tmp/good.bashrc" <<'EOF'
# user rc
alias ll='ls -la'
export PATH="$HOME/bin:$PATH"
if [ -n "$BASH_VERSION" ]; then
    : "$PS1"
fi
EOF
out="$(bash "$script" "$tmp/good.bashrc" 2>&1)"
if [[ "$out" == "VERIFY_SHELL=ok (bash)" ]]; then
    pass "clean bashrc → VERIFY_SHELL=ok"
else
    fail "clean bashrc → VERIFY_SHELL=ok" "output: $out"
fi

# Bash: syntax error → VERIFY_SHELL=errors with parser output. Use an unclosed function block —
# `[ -n "$X"` looks broken but `bash -n` treats `[` as a command and doesn't flag the missing `]`;
# only structural errors (unbalanced braces, missing `fi`) are caught.
cat > "$tmp/bad.bashrc" <<'EOF'
broken_func() {
    echo "this function never closes
EOF
out="$(bash "$script" "$tmp/bad.bashrc" 2>&1)"; rc=$?
assert_eq "1" "$rc" "broken bashrc → exit 1"
# Look for a VERIFY_SHELL=errors line followed by the parser's complaint (the wording shifts
# across bash releases — match on either "syntax error" or "unexpected EOF").
if [[ "$out" == "VERIFY_SHELL=errors"* ]] && [[ "$out" == *"unexpected"* || "$out" == *"syntax"* ]]; then
    pass "broken bashrc → VERIFY_SHELL=errors + parser output"
else
    fail "broken bashrc → VERIFY_SHELL=errors + parser output" "output: $out"
fi

# Critical safety property: the test must NOT execute the file. Drop a side-effect file write
# into a "good" rc and confirm it does NOT appear after verification.
canary="$tmp/canary-did-NOT-run"
cat > "$tmp/sideeffect.bashrc" <<EOF
touch "$canary"
EOF
out="$(bash "$script" "$tmp/sideeffect.bashrc" 2>&1)"
assert_eq "VERIFY_SHELL=ok (bash)" "$out" "side-effect rc parses ok"
if [ -e "$canary" ]; then
    fail "rc is NOT sourced (side effect didn't run)" "the rc was executed — this is the critical safety property"
else
    pass "rc is NOT sourced (side effect didn't run)"
fi

# Shell inference from filename: *.zshrc → zsh, *.fish → fish.
cat > "$tmp/x.zshrc" <<'EOF'
alias ll='ls -la'
EOF
out="$(bash "$script" "$tmp/x.zshrc" 2>&1)"
if [[ "$out" == "VERIFY_SHELL=ok (zsh)" ]] || [[ "$out" == "VERIFY_SHELL=skipped (zsh not installed)" ]]; then
    pass "shell inferred as zsh from .zshrc"
else
    fail "shell inferred as zsh from .zshrc" "output: $out"
fi

cat > "$tmp/x.fish" <<'EOF'
alias ll 'ls -la'
EOF
out="$(bash "$script" "$tmp/x.fish" 2>&1)"
if [[ "$out" == "VERIFY_SHELL=ok (fish)" ]] || [[ "$out" == "VERIFY_SHELL=skipped (fish not installed)" ]]; then
    pass "shell inferred as fish from .fish"
else
    fail "shell inferred as fish from .fish" "output: $out"
fi

# Missing file → VERIFY_SHELL=error.
out="$(bash "$script" "$tmp/does-not-exist" 2>&1)"; rc=$?
assert_eq "2" "$rc" "missing file → exit 2"
if [[ "$out" == "VERIFY_SHELL=error"* ]]; then
    pass "missing file → VERIFY_SHELL=error"
else
    fail "missing file → VERIFY_SHELL=error" "output: $out"
fi

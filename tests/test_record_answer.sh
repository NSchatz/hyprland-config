#!/usr/bin/env bash
# Behavior tests for scripts/record-answer.{sh,py} — the interview's "persist every answer to
# disk as it's chosen" helper that fixes the post-interview hallucination problem.
#
# As of v0.19, the actual implementation is record-answer.py (Python stdlib only) — the .sh
# is a thin wrapper. The interview runs *before* the install batch lands jq on disk, so
# generation-time tooling must depend on Python stdlib only.

script="$PLUGIN_ROOT/scripts/record-answer.sh"
py_script="$PLUGIN_ROOT/scripts/record-answer.py"
assert_file_exists "$script" "record-answer.sh present"
assert_file_exists "$py_script" "record-answer.py present (Python implementation)"

# Assertions in this file use jq to read back values, but the *script under test* must not
# need jq. We verify that separately at the bottom.
jq_present() { command -v jq >/dev/null 2>&1; }
if ! jq_present; then
    skip "record-answer: jq missing for assertions" "behavioral tests need jq to read back values"
    have_jq=0
else
    have_jq=1
fi

# --- jq-independent check: the script itself must not require jq. ---
# Stage a sandbox PATH that has python3 and bash but explicitly no jq, by symlinking
# the runtimes we need into a temp dir.
no_jq_tmp="$(mktemp -d)"
mkdir "$no_jq_tmp/bin"
for tool in python3 bash sh env; do
    p="$(command -v "$tool" || true)"
    [ -n "$p" ] && ln -s "$p" "$no_jq_tmp/bin/$tool"
done
if PATH="$no_jq_tmp/bin" "$no_jq_tmp/bin/python3" "$py_script" "$no_jq_tmp/x.json" probe.value worked >/dev/null 2>&1 \
   && [ "$(cat "$no_jq_tmp/x.json" | grep -c '"worked"')" -ge 1 ]; then
    pass "record-answer.py runs without jq on PATH"
else
    fail "record-answer.py runs without jq on PATH" "the python implementation must depend only on python stdlib"
fi
rm -rf "$no_jq_tmp"

if [ "$have_jq" -eq 0 ]; then return 0; fi


tmp="$(mktemp_test_dir record-answer)"
trap 'rm -rf "$tmp"' EXIT
f="$tmp/answers.json"

# Creates the file from scratch when absent.
bash "$script" "$f" palette.scheme catppuccin-mocha >/dev/null
assert_file_exists "$f" "file is created on first call"
assert_eq "catppuccin-mocha" "$(jq -r '.palette.scheme' "$f")" "string value persisted"

# Nested key path → nested object.
bash "$script" "$f" palette.accent mauve >/dev/null
assert_eq "mauve" "$(jq -r '.palette.accent' "$f")" "second key under same group"
assert_eq "catppuccin-mocha" "$(jq -r '.palette.scheme' "$f")" "earlier key preserved"

# --json arrays / numbers / booleans / null.
bash "$script" "$f" bar.modules --json '["workspaces","clock","tray"]' >/dev/null
assert_eq "3"          "$(jq '.bar.modules | length' "$f")"        "--json array landed"
assert_eq "workspaces" "$(jq -r '.bar.modules[0]'    "$f")"        "--json array element"

bash "$script" "$f" notifications.timeout --json 5 >/dev/null
assert_eq "5" "$(jq -r '.notifications.timeout' "$f")" "--json number"

bash "$script" "$f" laptop.enabled --json false >/dev/null
assert_eq "false" "$(jq -r '.laptop.enabled' "$f")" "--json false (regression for the jq -e bug)"

bash "$script" "$f" wallpaper.path --json null >/dev/null
assert_eq "null" "$(jq -r '.wallpaper.path' "$f")" "--json null"

# Object value.
bash "$script" "$f" palette.manual --json '{"bg":"1e1e2e","fg":"cdd6f4"}' >/dev/null
assert_eq "1e1e2e" "$(jq -r '.palette.manual.bg' "$f")" "--json object"

# Idempotent overwrite (re-asking a question replaces the value, no duplication).
bash "$script" "$f" palette.scheme nord >/dev/null
assert_eq "nord" "$(jq -r '.palette.scheme' "$f")" "string overwrite"
bash "$script" "$f" palette.scheme catppuccin-mocha >/dev/null
assert_eq "catppuccin-mocha" "$(jq -r '.palette.scheme' "$f")" "overwrite is reversible"

# Echo line — the agent uses it to confirm in chat.
out="$(bash "$script" "$f" terminal.emulator kitty 2>&1)"
assert_eq "RECORDED terminal.emulator=kitty" "$out" "echo confirms write"

# Bad JSON value is rejected (exit 2) — the file must not be corrupted by it.
before="$(cat "$f")"
out="$(bash "$script" "$f" bar.modules --json '[invalid' 2>&1)"; rc=$?
assert_eq "2" "$rc" "invalid --json value exits 2"
assert_eq "$before" "$(cat "$f")" "invalid --json leaves file unchanged"

# Missing arguments fail.
assert_fail 1 "no args" bash "$script"
assert_fail 1 "only file given" bash "$script" "$tmp/x.json"
assert_fail 1 "only file + key" bash "$script" "$tmp/x.json" palette.scheme

# Corrupted target file is reported, not silently overwritten.
echo 'not-json' > "$tmp/corrupt.json"
assert_fail 2 "corrupt target rejected" bash "$script" "$tmp/corrupt.json" palette.scheme x

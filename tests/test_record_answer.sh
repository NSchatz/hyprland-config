#!/usr/bin/env bash
# Behavior tests for scripts/record-answer.sh — the interview's "persist every answer to disk
# as it's chosen" helper that fixes the post-interview hallucination problem.

if ! command -v jq >/dev/null 2>&1; then
    skip "record-answer: jq missing" "jq required"
    return 0
fi

script="$PLUGIN_ROOT/scripts/record-answer.sh"
assert_file_exists "$script" "record-answer.sh present"

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

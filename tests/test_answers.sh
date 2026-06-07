#!/usr/bin/env bash
# Behavior tests for scripts/answers.py — the jq-free read helper that downstream generation
# steps (A3 file gen, A3b shell configs, A3c shell-prompt, A3d install.sh assembly, A4 palette)
# use to read picks out of <staging>/answers.json without depending on jq (which isn't on disk
# yet at generation time).

py_script="$PLUGIN_ROOT/scripts/answers.py"
assert_file_exists "$py_script" "answers.py present"

tmp="$(mktemp_test_dir answers)"
trap 'rm -rf "$tmp"' EXIT
f="$tmp/answers.json"

# Seed a realistic answers.json shape using record-answer.py.
python3 "$PLUGIN_ROOT/scripts/record-answer.py" "$f" palette.scheme catppuccin-mocha >/dev/null
python3 "$PLUGIN_ROOT/scripts/record-answer.py" "$f" palette.accent mauve >/dev/null
python3 "$PLUGIN_ROOT/scripts/record-answer.py" "$f" bar.modules --json '["workspaces","clock","tray"]' >/dev/null
python3 "$PLUGIN_ROOT/scripts/record-answer.py" "$f" notifications.timeout --json 5 >/dev/null
python3 "$PLUGIN_ROOT/scripts/record-answer.py" "$f" laptop.enabled --json true >/dev/null
python3 "$PLUGIN_ROOT/scripts/record-answer.py" "$f" widgets.system eww >/dev/null
python3 "$PLUGIN_ROOT/scripts/record-answer.py" "$f" widgets.enabled --json '["dashboard","music"]' >/dev/null

# --- get: scalar values ---
assert_eq "catppuccin-mocha" "$(python3 "$py_script" get "$f" palette.scheme)" "get string"
assert_eq "5"                "$(python3 "$py_script" get "$f" notifications.timeout)" "get number"
assert_eq "true"             "$(python3 "$py_script" get "$f" laptop.enabled)" "get bool"
assert_eq '["workspaces","clock","tray"]' "$(python3 "$py_script" get "$f" bar.modules)" "get array (compact)"

# --- get: default fallback when key missing ---
assert_eq "fallback"  "$(python3 "$py_script" get "$f" missing.thing fallback)" "default returned for missing key"
out="$(python3 "$py_script" get "$f" missing.thing 2>&1)"; rc=$?
assert_eq "1" "$rc" "missing key without default exits 1"

# --- slice: equivalent to jq '{a, b, c}' ---
out="$(python3 "$py_script" slice "$f" palette bar)"
# slice output is JSON; parse with python and check the shape.
got_scheme="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["palette"]["scheme"])' "$out")"
got_modules_len="$(python3 -c 'import json,sys; print(len(json.loads(sys.argv[1])["bar"]["modules"]))' "$out")"
assert_eq "catppuccin-mocha" "$got_scheme" "slice preserves nested palette.scheme"
assert_eq "3" "$got_modules_len" "slice preserves bar.modules array length"

# Missing top-level slice key should yield null (mirrors jq behavior).
out="$(python3 "$py_script" slice "$f" nonexistent palette)"
got_nul="$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print("null" if d["nonexistent"] is None else "other")' "$out")"
assert_eq "null" "$got_nul" "missing slice key → null"

# --- list: equivalent to jq -r '.a.b[]' ---
out="$(python3 "$py_script" list "$f" bar.modules)"
expected=$'workspaces\nclock\ntray'
assert_eq "$expected" "$out" "list emits one element per line"

# Missing list path → empty output, rc 0 (mirrors jq's behavior on null).
out="$(python3 "$py_script" list "$f" missing.list 2>&1)"; rc=$?
assert_eq "0"  "$rc" "list on missing path exits 0"
assert_eq ""   "$out" "list on missing path emits nothing"

# List on a non-array → exit 2.
out="$(python3 "$py_script" list "$f" palette.scheme 2>&1)"; rc=$?
assert_eq "2" "$rc" "list on non-array exits 2"

# --- has: jq -e equivalent ---
assert_ok "has on existing scalar"     python3 "$py_script" has "$f" palette.scheme
assert_ok "has on existing array"      python3 "$py_script" has "$f" bar.modules
assert_fail 1 "has on missing key"     python3 "$py_script" has "$f" missing.thing
# false / null are falsy in jq -e — verify the same.
python3 "$PLUGIN_ROOT/scripts/record-answer.py" "$f" widgets.compiled --json false >/dev/null
assert_fail 1 "has on false → exit 1"  python3 "$py_script" has "$f" widgets.compiled
python3 "$PLUGIN_ROOT/scripts/record-answer.py" "$f" widgets.last_run --json null >/dev/null
assert_fail 1 "has on null → exit 1"   python3 "$py_script" has "$f" widgets.last_run

# --- jq-independence: answers.py must not need jq on PATH ---
sandbox="$(mktemp -d)"
mkdir "$sandbox/bin"
for tool in python3 bash sh env; do
    p="$(command -v "$tool" || true)"
    [ -n "$p" ] && ln -s "$p" "$sandbox/bin/$tool"
done
out="$(PATH="$sandbox/bin" "$sandbox/bin/python3" "$py_script" get "$f" palette.scheme 2>&1)"
assert_eq "catppuccin-mocha" "$out" "answers.py runs without jq on PATH"
rm -rf "$sandbox"

# --- file-error paths ---
assert_fail 2 "missing file errors"  python3 "$py_script" get "$tmp/no-such-file.json" any.key
echo 'not-json' > "$tmp/corrupt.json"
assert_fail 2 "corrupt JSON errors"  python3 "$py_script" get "$tmp/corrupt.json" any.key

# --- usage ---
assert_fail 1 "no args"              python3 "$py_script"
assert_fail 1 "unknown command"      python3 "$py_script" wat

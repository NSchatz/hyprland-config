#!/usr/bin/env bash
# scripts/backup-path.sh — timestamped backup of arbitrary paths. Used by rice and edit-config
# whenever a file/dir outside ~/.config/hypr is about to be touched.

script="$PLUGIN_ROOT/scripts/backup-path.sh"
assert_file_exists "$script" "backup-path.sh present"

tmp="$(mktemp_test_dir backup-path)"
trap 'rm -rf "$tmp"' EXIT

# Existing file is copied to <path>.bak.<ts>.
echo "original" > "$tmp/file"
out="$(bash "$script" "$tmp/file" 2>&1)"
backup_path="$(printf '%s\n' "$out" | grep -oE "${tmp}/file\.bak\.[0-9]+-[0-9]+" | head -n1)"
if [ -n "$backup_path" ] && [ -f "$backup_path" ]; then
    pass "existing file is copied to .bak.<timestamp>"
else
    fail "existing file is copied to .bak.<timestamp>" "output: $out"
fi
assert_eq "original" "$(cat "$backup_path" 2>/dev/null)" "backup preserves content"
assert_eq "original" "$(cat "$tmp/file")"               "original is not moved"

# Missing path is reported, not an error.
out="$(bash "$script" "$tmp/missing" 2>&1)"; rc=$?
assert_eq "0" "$rc" "missing path: rc 0"
if [[ "$out" == *"did not exist"* ]]; then
    pass "missing path: 'did not exist' line"
else
    fail "missing path: 'did not exist' line" "output: $out"
fi

# Directory backup (cp -a, recursive).
mkdir -p "$tmp/dir/sub"
echo "deep" > "$tmp/dir/sub/file.txt"
out="$(bash "$script" "$tmp/dir" 2>&1)"
dir_bak="$(printf '%s\n' "$out" | grep -oE "${tmp}/dir\.bak\.[0-9]+-[0-9]+" | head -n1)"
if [ -n "$dir_bak" ] && [ -d "$dir_bak" ]; then
    pass "directory backup is recursive"
else
    fail "directory backup is recursive" "output: $out"
fi
assert_eq "deep" "$(cat "$dir_bak/sub/file.txt" 2>/dev/null)" "directory contents preserved"

# Multiple paths in one invocation share a timestamp (so a whole change set restores together).
echo "a" > "$tmp/a"; echo "b" > "$tmp/b"
out="$(bash "$script" "$tmp/a" "$tmp/b" 2>&1)"
ts_a="$(printf '%s\n' "$out" | grep -oE "${tmp}/a\.bak\.[0-9]+-[0-9]+" | sed 's/.*\.bak\.//')"
ts_b="$(printf '%s\n' "$out" | grep -oE "${tmp}/b\.bak\.[0-9]+-[0-9]+" | sed 's/.*\.bak\.//')"
assert_eq "$ts_a" "$ts_b" "multi-path invocation shares a timestamp"

# ~ in the path is expanded.
home_save="$HOME"
HOME="$tmp" bash "$script" '~/file' >/dev/null 2>&1
# Use a fresh file because the earlier ~/file backups may already exist.
HOME="$tmp"
echo "tilde" > "$HOME/tilde-test"
out="$(bash "$script" '~/tilde-test' 2>&1)"
HOME="$home_save"
if [[ "$out" == *"tilde-test.bak."* ]]; then
    pass "leading ~ is expanded"
else
    fail "leading ~ is expanded" "output: $out"
fi

# Bad usage (no args) exits with non-zero.
assert_fail 2 "no args exits non-zero" bash "$script"

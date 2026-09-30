#!/usr/bin/env bash
# scripts/dotfiles.sh — git versioning helper. Tests the bare-repo path (the recommended default);
# stow and chezmoi paths need their tools installed, so test only the bare flow end-to-end and
# the "tool missing" error path for the others.

if ! command -v git >/dev/null 2>&1; then
    skip "dotfiles: git missing" "git required"
    return 0
fi

script="$PLUGIN_ROOT/scripts/dotfiles.sh"
assert_file_exists "$script" "dotfiles.sh present"

tmp="$(mktemp_test_dir dotfiles)"
trap 'rm -rf "$tmp"' EXIT

# Sandbox: override HOME + state file + bare/stow dirs to land inside the tempdir, so the test
# never touches the user's real ~/.dotfiles.
unset XDG_CONFIG_HOME
export HOME="$tmp"
export DOTFILES_STATE="$tmp/state.conf"
export DOTFILES_BARE_DIR="$tmp/.dotfiles"
export DOTFILES_STOW_DIR="$tmp/dotfiles"

# `init bare` creates a bare repo and writes the state file.
out="$(bash "$script" init bare 2>&1)"; rc=$?
assert_eq "0" "$rc" "init bare: rc 0"
assert_file_exists "$DOTFILES_BARE_DIR/HEAD"  "bare repo created"
assert_file_contains "$DOTFILES_STATE" "method=bare" "state file records method"
if [[ "$out" == *"DOTFILES_INIT=ok"* ]]; then
    pass "init bare prints DOTFILES_INIT=ok"
else
    fail "init bare prints DOTFILES_INIT=ok" "output: $out"
fi

# Idempotency: re-running init bare doesn't crash.
assert_ok "init bare is idempotent" bash "$script" init bare

# `method` reads the state back.
assert_eq "bare" "$(bash "$script" method 2>/dev/null)" "method reads from state"

# `add` tracks a file. Need a git identity for the commit; set one in the bare repo's config.
git --git-dir="$DOTFILES_BARE_DIR" --work-tree="$HOME" config user.email "test@example.com"
git --git-dir="$DOTFILES_BARE_DIR" --work-tree="$HOME" config user.name  "Tester"

mkdir -p "$HOME/.config/waybar"
echo '{}' > "$HOME/.config/waybar/config.jsonc"
out="$(bash "$script" add "$HOME/.config/waybar/config.jsonc" 2>&1)"
if git --git-dir="$DOTFILES_BARE_DIR" --work-tree="$HOME" ls-files | grep -q 'waybar/config.jsonc'; then
    pass "add tracks the given file"
else
    fail "add tracks the given file" "ls-files did not list the file. output: $out"
fi

# `commit` makes a commit on the bare repo.
out="$(bash "$script" commit "initial test commit" 2>&1)"
if git --git-dir="$DOTFILES_BARE_DIR" --work-tree="$HOME" log --oneline 2>/dev/null | grep -q 'initial test commit'; then
    pass "commit creates a commit"
else
    fail "commit creates a commit" "git log empty or wrong subject. output: $out"
fi

# --- D-EXCL: `add` of a directory must not stage the plugin's own backups ----------------------
# Every writer here leaves <path>.bak.<id> (and <dir>.bak.<id>/ trees) beside what it protects.
# `add` used to run `git add -f`, which forced all of them - and __pycache__ - into the repo.
G=(git --git-dir="$DOTFILES_BARE_DIR" --work-tree="$HOME")
d="$HOME/.config/hypr-rice"
mkdir -p "$d/templates" "$d/profiles.bak.20260101-000000" "$d/ricelib/__pycache__" "$HOME/Pictures"
echo 'scheme=nord'  > "$d/palette.conf"
echo 'scheme=old'   > "$d/palette.conf.bak.20260101-000000"
echo 'old'          > "$d/profiles.bak.20260101-000000/nord.conf"
echo 'x'            > "$d/templates/hyprland.tmpl"
echo 'x'            > "$d/templates/hyprland.tmpl.bak"
printf 'pyc'        > "$d/ricelib/__pycache__/xdg.cpython-314.pyc"
echo 'img'          > "$HOME/Pictures/wall.png"
ln -s "$HOME/Pictures/wall.png" "$d/current-wallpaper"

out="$(bash "$script" add "$d" 2>&1)"
tracked="$("${G[@]}" ls-files -- .config/hypr-rice)"
assert_eq ".config/hypr-rice/palette.conf
.config/hypr-rice/templates/hyprland.tmpl" "$tracked" \
    "D-EXCL: add of a directory tracks the config and none of its backups, caches or wallpaper link"

# An explicitly named backup is reported, not silently forced in and not silently dropped.
out="$(bash "$script" add "$d/palette.conf.bak.20260101-000000" 2>&1)"
if [[ "$out" == *"SKIP (ignored by an exclude rule)"* ]] \
   && ! "${G[@]}" ls-files | grep -q 'palette.conf.bak'; then
    pass "D-EXCL: an explicitly named backup is SKIPPED as ignored"
else
    fail "D-EXCL: an explicitly named backup is SKIPPED as ignored" "output: $out"
fi

# The managed block is written once, survives re-runs, and never eats the user's own lines.
ex="$DOTFILES_BARE_DIR/info/exclude"
echo 'my-own-rule' >> "$ex"
bash "$script" init bare >/dev/null 2>&1
bash "$script" add "$d" >/dev/null 2>&1
assert_eq "1" "$(grep -c '>>> hyprland-config dotfiles excludes >>>' "$ex")" \
    "D-EXCL: the exclude block is written exactly once across init + add re-runs"
assert_file_contains "$ex" "my-own-rule" "D-EXCL: the user's own exclude lines are kept"

# A repo initialised BEFORE the excludes existed gets them on its next add.
rm -f "$ex"
mkdir -p "$HOME/.config/kitty"
echo 'x' > "$HOME/.config/kitty/kitty.conf"
echo 'x' > "$HOME/.config/kitty/kitty.conf.bak.20260101-000000"
bash "$script" add "$HOME/.config/kitty" >/dev/null 2>&1
if "${G[@]}" ls-files | grep -q 'kitty.conf.bak'; then
    fail "D-EXCL: a pre-fix repo gets the excludes on its next add" "$("${G[@]}" ls-files -- .config/kitty)"
else
    pass "D-EXCL: a pre-fix repo gets the excludes on its next add"
fi

# stow path errors clearly when stow isn't installed (don't probe the working stow flow — it
# would need stow on CI). We only test the missing-tool branch.
if ! command -v stow >/dev/null 2>&1; then
    assert_fail 3 "stow init exits 3 when stow is missing" bash "$script" init stow
else
    skip "stow missing-tool path" "stow installed; skipping the missing-tool branch"
fi

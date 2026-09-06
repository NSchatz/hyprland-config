#!/usr/bin/env bash
# End-to-end test for the rice engine: scaffold a fresh hypr-rice into a tempdir, render the
# default manifest from the seeded Catppuccin Mocha palette, and confirm every output file lands
# with the expected hex substitutions. Highest-leverage test in the suite — exercises rice-init,
# render-templates, the template files themselves, the manifest format, and palette loading.

tmp="$(mktemp_test_dir render-templates)"
trap 'rm -rf "$tmp"' EXIT

# Sandbox HOME + the engine dir so nothing touches the user's real config dir. XDG_CONFIG_HOME
# goes with HOME: a `~/.config/...` manifest row now resolves under the config base, so leaving
# an inherited XDG_CONFIG_HOME in place would send this test's writes outside its sandbox.
unset XDG_CONFIG_HOME
export HOME="$tmp"
export RICE_DIR="$HOME/.config/hypr-rice"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Step 1 — scaffold.
out="$(bash "$PLUGIN_ROOT/skills/rice/scripts/rice-init.sh" 2>&1)"; rc=$?
assert_eq "0" "$rc" "rice-init: rc 0"
assert_file_exists "$RICE_DIR/templates.list"        "manifest written"
assert_file_exists "$RICE_DIR/palette.conf"          "palette seeded"
assert_file_exists "$RICE_DIR/render-templates.sh"   "engine installed"
assert_file_exists "$RICE_DIR/rice"                  "CLI installed"
assert_file_exists "$RICE_DIR/templates/hyprland.tmpl" "hyprland template copied"
assert_file_exists "$RICE_DIR/templates/waybar.tmpl"   "waybar template copied"

# Idempotency: a second init must not blow away the (now potentially-edited) palette.
echo "# user edit" >> "$RICE_DIR/palette.conf"
assert_ok "rice-init is idempotent (rc 0 on re-run)" bash "$PLUGIN_ROOT/skills/rice/scripts/rice-init.sh"
assert_file_contains "$RICE_DIR/palette.conf" "# user edit" "re-run preserves user edits to palette.conf"

# Step 2 — render. Use --no-reload so the test doesn't try to signal real bars / kitty / etc.
out="$(bash "$RICE_DIR/render-templates.sh" --no-reload 2>&1)"; rc=$?
assert_eq "0" "$rc" "render: rc 0"
if [[ "$out" == *"RENDER=done"* ]]; then
    pass "render prints RENDER=done"
else
    fail "render prints RENDER=done" "output: $out"
fi

# Step 3 — outputs landed where the manifest said.
assert_file_exists "$HOME/.config/hypr/colors.conf"   "hyprland colors.conf written"
assert_file_exists "$HOME/.config/kitty/colors.conf"  "kitty colors.conf written"
assert_file_exists "$HOME/.config/waybar/colors.css"  "waybar colors.css written"
assert_file_exists "$HOME/.config/wofi/colors.css"    "wofi colors.css written"
assert_file_exists "$HOME/.config/rofi/colors.rasi"   "rofi colors.rasi written"
assert_file_exists "$HOME/.config/gtk-4.0/gtk.css"    "gtk4 gtk.css written"

# Step 4 — the substitutions actually happened. Catppuccin Mocha accent is `cba6f7`; bg is
# `1e1e2e`. If a render mangled `{{accent}}` or skipped a key, this catches it.
assert_grep 'cba6f7' "$HOME/.config/waybar/colors.css" "waybar contains accent hex (cba6f7)"
assert_grep '1e1e2e' "$HOME/.config/waybar/colors.css" "waybar contains bg hex (1e1e2e)"
assert_grep 'cba6f7' "$HOME/.config/hypr/colors.conf"  "hyprland contains accent hex"
assert_grep 'cba6f7' "$HOME/.config/kitty/colors.conf" "kitty contains accent hex"

# Step 5 — no stray placeholders left behind in the rendered outputs (a missed key in the palette
# leaves a literal `{{key}}` in the output, which downstream apps choke on).
left_over=()
for out in "$HOME/.config/hypr/colors.conf" "$HOME/.config/kitty/colors.conf" \
           "$HOME/.config/waybar/colors.css" "$HOME/.config/wofi/colors.css" \
           "$HOME/.config/rofi/colors.rasi"  "$HOME/.config/gtk-4.0/gtk.css"; do
    if grep -q '{{[A-Za-z_][A-Za-z0-9_]*}}' "$out" 2>/dev/null; then
        left_over+=("$out")
    fi
done
if [ "${#left_over[@]}" -eq 0 ]; then
    pass "no unsubstituted {{placeholders}} in rendered outputs"
else
    detail=""
    for f in "${left_over[@]}"; do detail+="$f"$'\n'; done
    fail "unsubstituted {{placeholders}} found" "$detail"
fi

# Step 6 — user override cascade. palette.user.conf wins over palette.conf.
echo "accent=ff0000" > "$RICE_DIR/palette.user.conf"
bash "$RICE_DIR/render-templates.sh" --no-reload >/dev/null 2>&1
assert_grep 'ff0000' "$HOME/.config/waybar/colors.css" "user-override accent (ff0000) wins"
# And the non-overridden keys still come from palette.conf.
assert_grep '1e1e2e' "$HOME/.config/waybar/colors.css" "non-overridden keys keep palette.conf values"
rm -f "$RICE_DIR/palette.user.conf"

# Step 7 — missing palette is reported, not silently rendered with empty values.
mv "$RICE_DIR/palette.conf" "$RICE_DIR/palette.conf.away"
assert_fail 2 "missing palette exits 2" bash "$RICE_DIR/render-templates.sh" --no-reload
mv "$RICE_DIR/palette.conf.away" "$RICE_DIR/palette.conf"

# Step 8 — symlinked output path is replaced with a regular file (the gtk-4.0/gtk.css gotcha).
# Most users hit this when a system GTK theme symlinks the whole gtk-4.0 dir; rendering through
# the symlink would touch a root-owned file.
gtk_out="$HOME/.config/gtk-4.0/gtk.css"
target="$(mktemp -p "$tmp")"
echo "/* original theme */" > "$target"
rm -f "$gtk_out"
ln -s "$target" "$gtk_out"
bash "$RICE_DIR/render-templates.sh" --no-reload >/dev/null 2>&1
if [ ! -L "$gtk_out" ] && [ -f "$gtk_out" ]; then
    pass "symlinked output is replaced with a regular file"
else
    fail "symlinked output is replaced with a regular file" "$gtk_out is still a symlink (or missing)"
fi
# And the original target was not touched.
assert_eq "/* original theme */" "$(cat "$target")" "symlink target is left untouched"

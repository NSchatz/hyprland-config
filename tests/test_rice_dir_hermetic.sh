#!/usr/bin/env bash
# A DETACHED rice engine - RICE_DIR pointed away from <config base>/hypr-rice - must stay inside
# its own directory. RICE_DIR only ever moved the engine; a manifest row reading `~/.config/...`
# still resolved against the real config base, so scaffolding a scratch engine and running
# `rice scheme nord` in it wrote Nord over a live desktop's hypr/kitty/waybar/rofi/gtk colours,
# left a restore point in the real state dir, and signalled the running apps.
#
# The canary is a full fake home (HOME + XDG_CONFIG_HOME + XDG_STATE_HOME) standing in for the
# user's real one; the detached engine lives beside it, not under it. Every tool that could touch
# a running desktop is a spy that logs its argv, so "nothing was reloaded" is observed, not hoped.

tmp="$(mktemp_test_dir rice-dir-hermetic)"
trap 'rm -rf "$tmp"' EXIT

canary="$tmp/home"
mkdir -p "$canary"
export HOME="$canary"
export XDG_CONFIG_HOME="$canary/.config"
export XDG_STATE_HOME="$canary/.local/state"
unset XDG_DATA_HOME XDG_CACHE_HOME RICE_RESTORE_DIR RICE_THEMING_ENGINE RICE_LOCK_BLUR
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

spylog="$tmp/spy.log"
: > "$spylog"
bin="$(hermetic_bin_path "$tmp/bin")"
for t in hyprctl pkill killall swaync-client eww makoctl dunstctl awww awww-daemon swww \
         swww-daemon hyprpaper swaybg firefox; do
    printf '#!/usr/bin/env bash\necho "%s $*" >> "%s"\nexit 0\n' "$t" "$spylog" > "$bin/$t"
    chmod +x "$bin/$t"
done
export PATH="$bin"

section "detached engine: rice-init + rice scheme nord"
detached="$tmp/scratch-engine"
export RICE_DIR="$detached"

out="$(bash "$PLUGIN_ROOT/skills/rice/scripts/rice-init.sh" 2>&1)"; rc=$?
assert_eq "0" "$rc" "rice-init into a detached RICE_DIR: rc 0"
if grep -q $'\t~/.config/' "$detached/templates.list" 2>/dev/null; then
    fail "detached manifest never targets ~/.config" "$(grep $'\t~/.config/' "$detached/templates.list")"
else
    pass "detached manifest never targets ~/.config"
fi

out="$(bash "$detached/rice" scheme nord 2>&1)"; rc=$?
assert_eq "0" "$rc" "rice scheme nord in the detached engine: rc 0"
assert_grep '^scheme=nord' "$detached/palette.conf" "the detached palette switched to nord"

leaked=()
for p in hypr kitty waybar wofi rofi gtk-4.0 gtk-3.0 swaync; do
    [ -e "$XDG_CONFIG_HOME/$p" ] && leaked+=("$XDG_CONFIG_HOME/$p")
done
[ -e "$XDG_STATE_HOME/hypr-rice/restore" ] && leaked+=("$XDG_STATE_HOME/hypr-rice/restore")
if [ "${#leaked[@]}" -eq 0 ]; then
    pass "nothing rendered into the canary home or its state dir"
else
    fail "nothing rendered into the canary home or its state dir" \
         "$(printf '  %s\n' "${leaked[@]}")
render output: $out"
fi

assert_file_exists "$detached/out/hypr/colors.conf" "the detached render landed in its own out/ tree"
if [ -d "$detached/restore" ]; then
    pass "the detached restore point lives beside the engine"
else
    fail "the detached restore point lives beside the engine" "no $detached/restore"
fi

section "detached engine: a hand-written manifest row pointing at ~/.config is refused"
printf 'hyprland\t%s/templates/hyprland.tmpl\t~/.config/hypr/colors.conf\thyprctl reload\n' \
    "$detached" > "$tmp/escaping.list"
out="$(bash "$detached/render-templates.sh" "$detached/palette.conf" "$tmp/escaping.list" 2>&1)"
if [[ "$out" == *"RENDER_SKIPPED hyprland"*"outside the detached engine dir"* ]]; then
    pass "an escaping row is reported RENDER_SKIPPED"
else
    fail "an escaping row is reported RENDER_SKIPPED" "output: $out"
fi
if [ -e "$XDG_CONFIG_HOME/hypr/colors.conf" ]; then
    fail "the escaping row wrote nothing" "$XDG_CONFIG_HOME/hypr/colors.conf exists"
else
    pass "the escaping row wrote nothing"
fi

section "detached engine: set-wallpaper leaves the running desktop alone"
img="$tmp/wall.png"
printf 'not really a png' > "$img"
out="$(bash "$detached/set-wallpaper.sh" "$img" 2>&1)"; rc=$?
assert_eq "0" "$rc" "detached set-wallpaper: rc 0"
assert_eq "$img" "$(readlink "$detached/current-wallpaper")" "detached wallpaper linked beside the engine"

if [ -s "$spylog" ]; then
    fail "no running app was reloaded or repainted by a detached engine" "$(cat "$spylog")"
else
    pass "no running app was reloaded or repainted by a detached engine"
fi

section "control: the engine at <config base>/hypr-rice still themes the desktop"
export RICE_DIR="$XDG_CONFIG_HOME/hypr-rice"
out="$(bash "$PLUGIN_ROOT/skills/rice/scripts/rice-init.sh" 2>&1)"; rc=$?
assert_eq "0" "$rc" "rice-init at the default location: rc 0"
out="$(bash "$RICE_DIR/render-templates.sh" --no-reload 2>&1)"; rc=$?
assert_eq "0" "$rc" "render at the default location: rc 0"
assert_file_exists "$XDG_CONFIG_HOME/hypr/colors.conf" "an attached engine still renders into the config base"
if [[ "$out" == *"RENDER_DETACHED"* ]]; then
    fail "an attached engine is not treated as detached" "output: $out"
else
    pass "an attached engine is not treated as detached"
fi

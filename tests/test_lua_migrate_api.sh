#!/usr/bin/env bash
# migrate-config.sh writes the lua API Hyprland actually loads - not a transliteration of the
# hyprlang it was given.
#
# Hyprland 0.57 removed hyprlang: it loads `hyprland.lua` and nothing else. The converter was
# run on a real config for that upgrade and its output did not load. Each block below is one
# of the defects that run exposed, pinned against `tests/fixtures/migrate-hyprlang/`, a config
# set written to contain every construct involved:
#
#   D1  dispatchers   `hl.dsp.killactive()` and every other legacy name is nil in the lua API
#   D2  key chords    `"SUPER SHIFT + Q"` is rejected; modifiers are joined with ` + `
#   D3  gradients     `rgb(a) rgb(b) 45deg` is `{ colors = {...}, angle = 45 }`, not a string
#   D4  css gaps      a gap is an integer or a `{ top, right, bottom, left }` table
#   D5  autostart     `exec-once` belongs inside hl.on("hyprland.start"). A top-level
#                     hl.exec_cmd() runs on every evaluation, INCLUDING `--verify-config`
#   D6  envd          the `d` (export to systemd / D-Bus) is hl.env's third argument
#   D7  statements    bezier, animation, workspace rules and submaps all have a lua form
#   D8  palette       a file of `$variables` becomes a module; nothing inlines its colours
#
# Three layers, so the file is useful on a machine with no Hyprland and decisive on one with:
#   - the converted text is asserted line by line            (always)
#   - the converted config is EXECUTED against a mock `hl`   (needs a standalone lua)
#   - the compositor's own offline check accepts it          (needs Hyprland 0.55 or newer)
#
# Everything runs against a temporary HYPR_DIR; no real config dir is read or written.

RS="$PLUGIN_ROOT/skills/rice/scripts"
migrate="$RS/migrate-config.sh"
fixture="$PLUGIN_ROOT/tests/fixtures/migrate-hyprlang"
mock="$PLUGIN_ROOT/tests/fixtures/hl-mock.lua"

tmp="$(mktemp_test_dir hypr-lua-api)"
dir="$tmp/hypr"
mkdir -p "$dir"
cp "$fixture"/*.conf "$dir"/

# `has_line <file> <exact line> <name>` - the file holds this line, byte for byte.
has_line() {
    if grep -qxF -- "$2" "$1" 2>/dev/null; then
        pass "$3"
    else
        fail "$3" "no such line in $1:
$2"
    fi
}
# `lacks <ERE> <name> <file...>` - no line of any of the files matches.
lacks() {
    local pattern="$1" name="$2" hits
    shift 2
    hits="$(grep -nE -- "$pattern" "$@" 2>/dev/null)"
    if [ -z "$hits" ]; then pass "$name"; else fail "$name" "$hits"; fi
}

# HYPR_VERSION is pinned so "which keys are removed" never depends on the host.
out="$(HYPR_VERSION=0.57.2 HYPR_DIR="$dir" bash "$migrate" --convert 2>&1)"; rc=$?
assert_eq "0" "$rc" "the fixture set converts"
for m in hyprland env colors looknfeel rules binds autostart; do
    assert_file_exists "$dir/$m.lua" "$m.conf was converted"
done
luas=("$dir"/*.lua)

# --------------------------------------------------------------------------------------------
# D1 - every dispatcher is the lua call, in the shape Hyprland documents
# --------------------------------------------------------------------------------------------
b="$dir/binds.lua"
has_line "$b" 'hl.bind("SUPER + Q", hl.dsp.window.close())' \
    "D1: killactive -> hl.dsp.window.close()"
has_line "$b" 'hl.bind("SUPER + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))' \
    "D1: togglefloating -> hl.dsp.window.float({ action = \"toggle\" })"
has_line "$b" 'hl.bind("SUPER + F", hl.dsp.window.fullscreen())' \
    "D1: fullscreen -> hl.dsp.window.fullscreen()"
has_line "$b" 'hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))' \
    "D1: fullscreen, 1 -> the maximized mode"
has_line "$b" 'hl.bind("SUPER + P", hl.dsp.window.pseudo())' "D1: pseudo -> hl.dsp.window.pseudo()"
has_line "$b" 'hl.bind("SUPER + ALT + P", hl.dsp.window.pin())' "D1: pin -> hl.dsp.window.pin()"
has_line "$b" 'hl.bind("SUPER + ALT + C", hl.dsp.window.center())' \
    "D1: centerwindow -> hl.dsp.window.center()"
has_line "$b" 'hl.bind("SUPER + T", hl.dsp.layout("togglesplit"))' \
    "D1: layoutmsg -> hl.dsp.layout(message)"
has_line "$b" 'hl.bind("ALT + Tab", hl.dsp.focus({ last = true }))' \
    "D1: focuscurrentorlast -> hl.dsp.focus({ last = true })"
has_line "$b" 'hl.bind("SUPER + CTRL + O", hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" }))' \
    "D1: setprop -> hl.dsp.window.set_prop({ prop, value })"
has_line "$b" 'hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" }))' \
    "D1: movefocus, l -> hl.dsp.focus({ direction = \"left\" })"
has_line "$b" 'hl.bind("SUPER + K", hl.dsp.focus({ direction = "up" }))' \
    "D1: movefocus, u -> direction up"
has_line "$b" 'hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "right" }))' \
    "D1: movewindow, r -> hl.dsp.window.move({ direction })"
has_line "$b" 'hl.bind("SUPER + G", hl.dsp.group.toggle())' "D1: togglegroup -> hl.dsp.group.toggle()"
has_line "$b" 'hl.bind("SUPER + ALT + G", hl.dsp.window.move({ out_of_group = true }))' \
    "D1: moveoutofgroup -> hl.dsp.window.move({ out_of_group = true })"
has_line "$b" 'hl.bind("SUPER + ALT + Tab", hl.dsp.group.next())' \
    "D1: changegroupactive, f -> hl.dsp.group.next()"
has_line "$b" 'hl.bind("SUPER + ALT + SHIFT + Tab", hl.dsp.group.prev())' \
    "D1: changegroupactive, b -> hl.dsp.group.prev()"
has_line "$b" 'hl.bind("SUPER + ALT + H", hl.dsp.window.move({ into_or_create_group = "left" }))' \
    "D1: moveintoorcreategroup -> hl.dsp.window.move({ into_or_create_group })"
has_line "$b" 'hl.bind("SUPER + 1", hl.dsp.focus({ workspace = 1 }))' \
    "D1: workspace, 1 -> hl.dsp.focus({ workspace = 1 })"
has_line "$b" 'hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))' \
    "D1: a relative workspace stays a selector string"
has_line "$b" 'hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))' \
    "D1: movetoworkspace -> hl.dsp.window.move({ workspace })"
has_line "$b" 'hl.bind("SUPER + CTRL + 1", hl.dsp.window.move({ workspace = 1, follow = false }))' \
    "D1: movetoworkspacesilent -> the same call with follow = false"
has_line "$b" 'hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("magic"))' \
    "D1: togglespecialworkspace -> hl.dsp.workspace.toggle_special(name)"
has_line "$b" 'hl.bind("SUPER + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }))' \
    "D1: moving a window to a special workspace keeps the special: prefix"
has_line "$b" 'hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })' \
    "D1: bindm movewindow -> hl.dsp.window.drag() with the mouse flag"
has_line "$b" 'hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })' \
    "D1: bindm resizewindow -> hl.dsp.window.resize() with the mouse flag"
has_line "$b" 'hl.bind("SUPER + R", hl.dsp.submap("resize"))' "D1: submap -> hl.dsp.submap(name)"
has_line "$b" '    hl.bind("right", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })' \
    "D1: resizeactive -> hl.dsp.window.resize({ x, y, relative = true })"
has_line "$b" 'hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"), { description = "Open terminal" })' \
    "D1: exec keeps its lua form, with the bindd description as an option"
has_line "$b" 'hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true, locked = true })' \
    "D1: bindel flags become repeating + locked"

# The same rule as an invariant: every hl.dsp.* name anywhere in the output exists in the lua
# API. A call to a name outside this list is "attempt to call a nil value" at load, and it
# aborts the rest of the file. (The list is HL.DspNamespace and friends from the 0.57 stubs.)
dsp_api=" dpms event exec_cmd exec_raw exit focus force_idle force_renderer_reload global layout
 no_op pass release_input_capture reload_config send_key_state send_shortcut submap
 cursor.move cursor.move_to_corner
 group.active group.lock group.lock_active group.move_window group.next group.prev group.toggle
 window.alter_zorder window.bring_to_top window.center window.clear_tags window.close
 window.cycle_next window.deny_from_group window.drag window.float window.fullscreen
 window.fullscreen_state window.kill window.move window.pin window.pseudo window.resize
 window.set_prop window.signal window.swap window.tag window.toggle_swallow
 workspace.change_id workspace.move workspace.rename workspace.swap_monitors
 workspace.toggle_special "
unknown_calls=""
called=0
while IFS= read -r name; do
    [ -n "$name" ] || continue
    called=$((called + 1))
    case "$dsp_api" in
        *[[:space:]]"$name"[[:space:]]*) ;;
        *) unknown_calls="$unknown_calls $name" ;;
    esac
done < <(grep -ohE 'hl\.dsp\.[A-Za-z_.]+\(' "${luas[@]}" \
            | sed -e 's/^hl\.dsp\.//' -e 's/($//' | sort -u)
if [ "$called" -ge 15 ]; then
    pass "D1: the output calls $called distinct hl.dsp.* dispatchers"
else
    fail "D1: the output calls $called distinct hl.dsp.* dispatchers" "expected at least 15"
fi
assert_eq "" "$unknown_calls" "D1: every hl.dsp.* name in the output exists in the lua API"

# A dispatcher with no known lua form stays a reported comment. It is never a call.
has_line "$b" "-- NOT APPLIED (dispatcher 'nosuchdispatcher' has no lua form this converter knows): bind = \$mainMod, X, nosuchdispatcher, 1" \
    "D1: an unknown dispatcher is carried across as a NOT APPLIED comment"
lacks 'hl\.dsp\.nosuchdispatcher' "D1: an unknown dispatcher is never emitted as a call" "${luas[@]}"
if printf '%s\n' "$out" | grep -q "^NOT_APPLIED=.*binds\.conf:.*dispatcher 'nosuchdispatcher'"; then
    pass "D1: ...and the run reports it by file and line"
else
    fail "D1: ...and the run reports it by file and line" "$out"
fi
assert_grep '^-- NOT APPLIED \(dispatcher .exec.: an exec with a \[rules\] prefix' "$b" \
    "D1: an exec with a [rules] prefix is not silently run without its rules"

# --------------------------------------------------------------------------------------------
# D2 - key chords: every modifier and the key joined with " + "
# --------------------------------------------------------------------------------------------
bad_chords="$(grep -ohE '^ *hl\.bind\("[^"]*"' "${luas[@]}" | sed -e 's/^ *hl\.bind("//' -e 's/"$//' \
    | grep -vE '^([^ +]+ \+ )*[^ +]+$')"
assert_eq "" "$bad_chords" "D2: no chord has two words that are not joined by ' + '"
lacks '"SUPER (SHIFT|ALT|CTRL)' "D2: 'SUPER SHIFT + key' (rejected by Hyprland) is never written" "${luas[@]}"
assert_eq "39" "$(grep -cE '^ *hl\.bind\(' "$b")" "D2: all 39 convertible binds are bound"

# --------------------------------------------------------------------------------------------
# D3 - gradients
# --------------------------------------------------------------------------------------------
l="$dir/looknfeel.lua"
has_line "$l" '            active_border = { colors = { c.accent, c.accent2, c.accent }, angle = 45 },' \
    "D3: a three-stop gradient is a colors/angle table"
has_line "$l" '            border_active = { colors = { c.accent, c.accent2 }, angle = 90 },' \
    "D3: the group border gradient too"
has_line "$l" '            inactive_border = c.surface,' "D3: a single colour stays a single value"
lacks 'deg"' "D3: no gradient is emitted as one 'rgb(..) rgb(..) 45deg' string" "${luas[@]}"

# --------------------------------------------------------------------------------------------
# D4 - css gaps
# --------------------------------------------------------------------------------------------
has_line "$l" '        gaps_out = 6,' \
    "D4: a space-separated gap list is the integer hyprlang read it as"
has_line "$l" '        float_gaps = { top = 4, right = 8, bottom = 12, left = 16 },' \
    "D4: a comma-separated gap list is a top/right/bottom/left table"
lacks 'gaps_[a-z]+ = "' "D4: no gap is emitted as a string (css_gap rejects one)" "${luas[@]}"
if printf '%s\n' "$out" | grep -q '^REVIEW=.*looknfeel\.conf:.*6 16 16 16.*space-separated'; then
    pass "D4: the run flags the gap list it had to reinterpret"
else
    fail "D4: the run flags the gap list it had to reinterpret" "$out"
fi
assert_grep '^        -- REVIEW: `6 16 16 16` is space-separated' "$l" \
    "D4: ...and the lua says so next to the value"

# --------------------------------------------------------------------------------------------
# D5 - autostart runs from events, never at the top level
# --------------------------------------------------------------------------------------------
a="$dir/autostart.lua"
lacks '^hl\.exec_cmd' "D5: no file has a top-level hl.exec_cmd()" "${luas[@]}"
has_line "$a" 'hl.on("hyprland.start", function()' "D5: exec-once is inside hl.on(\"hyprland.start\")"
has_line "$a" '    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")' \
    "D5: the command is in the handler body"
has_line "$a" 'hl.on("hyprland.shutdown", function()' \
    "D5: exec-shutdown is inside hl.on(\"hyprland.shutdown\")"
has_line "$a" '    hl.exec_cmd("systemctl --user stop waybar.service")' \
    "D5: the shutdown command is in ITS handler body"
assert_eq "2" "$(grep -c '^end)$' "$a")" "D5: both handlers are closed"
has_line "$a" '-- Trailing notes stay outside the handlers.' \
    "D5: a comment after the last command is not swallowed into a handler"

# --------------------------------------------------------------------------------------------
# D6 - envd
# --------------------------------------------------------------------------------------------
e="$dir/env.lua"
has_line "$e" 'hl.env("XDG_CURRENT_DESKTOP", "Hyprland", true)' \
    "D6: envd passes true as hl.env's third argument"
has_line "$e" 'hl.env("XCURSOR_SIZE", "24")' "D6: a plain env does not"
has_line "$e" 'hl.env("GDK_BACKEND", "wayland,x11,*")  -- the value keeps its commas' \
    "D6: an env value keeps its commas, and the trailing comment survives"

# --------------------------------------------------------------------------------------------
# D7 - bezier, animation, workspace rules, submaps
# --------------------------------------------------------------------------------------------
has_line "$l" 'hl.curve("overshoot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })' \
    "D7: bezier -> hl.curve(name, { type = \"bezier\", points })"
has_line "$l" 'hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "overshoot", style = "popin 87%" })' \
    "D7: animation -> hl.animation({ leaf, enabled, speed, bezier, style })"
has_line "$l" 'hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })' \
    "D7: an animation with no style has no style field"
has_line "$l" 'hl.animation({ leaf = "fadeDim", enabled = false })' \
    "D7: a disabled animation is just leaf + enabled"
lacks '^ +(bezier|animation) = ' "D7: no bezier/animation leaked into hl.config as a table key" "$l"
r="$dir/rules.lua"
has_line "$r" 'hl.workspace_rule({ workspace = "special:term", on_created_empty = "[workspace special:term] kitty --class dropterm" })' \
    "D7: workspace on-created-empty -> hl.workspace_rule, with the workspace hyprlang implied"
has_line "$r" 'hl.workspace_rule({ workspace = "2", monitor = "DP-1", default = true, gaps_out = 0, no_border = true })' \
    "D7: workspace rule fields take their lua names (border:false is no_border = true)"
has_line "$b" 'hl.define_submap("resize", function()' "D7: a submap block -> hl.define_submap"
has_line "$b" '    hl.bind("escape", hl.dsp.submap("reset"))' "D7: its binds are inside the function"
has_line "$b" 'end)' "D7: 'submap = reset' closes it"
has_line "$l" 'hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })' \
    "D7: gesture -> hl.gesture"
lacks 'NOT APPLIED.*(bezier|animation|workspace =|submap|gesture)' \
    "D7: none of them is reported as having no lua form" "${luas[@]}"

# --------------------------------------------------------------------------------------------
# D8 - the palette is a module, and no other file holds a colour from it
# --------------------------------------------------------------------------------------------
c="$dir/colors.lua"
has_line "$c" 'return {' "D8: a file of \$variables becomes a module that returns a table"
has_line "$c" '    accent = "rgb(cba6f7)",' "D8: each variable is a field of it"
has_line "$l" 'local c = require("colors")' "D8: a file that uses the palette requires the module"
has_line "$l" '        background_color = c.bg,' "D8: ...and reads the value through it"
others=()
for f in "${luas[@]}"; do [ "$f" = "$c" ] || others+=("$f"); done
lacks 'cba6f7|89b4fa|1e1e2e|313244' \
    "D8: no palette colour is inlined anywhere else (a re-theme rewrites colors.lua only)" \
    "${others[@]}"
lacks '^require\("colors"\)' "D8: the main file does not load the module for side effects" \
    "$dir/hyprland.lua"
lacks '^local c = ' "D8: a file that uses no palette value requires nothing" "$b" "$e" "$a"
has_line "$dir/hyprland.lua" 'require("looknfeel")' "D8: ordinary modules are still required"
# Variables defined in the MAIN file are not a module: they are expanded where they are used.
has_line "$b" 'hl.bind("SUPER + D", hl.dsp.exec_cmd("rofi -show drun"))' \
    "D8: \$mainMod / \$menu from the main file are still expanded inline"

# --------------------------------------------------------------------------------------------
# Option values take the type the lua option has, not the type the text looks like
# --------------------------------------------------------------------------------------------
has_line "$l" '        kb_layout = "no",  -- Norwegian: a layout name, not a boolean' \
    "types: a string option stays a string (kb_layout = no is not false)"
has_line "$l" '        kb_variant = "",' "types: an empty value is an empty string"
has_line "$l" '            tap_to_click = true,' "types: tap-to-click takes its lua name"
has_line "$l" '            natural_scroll = false,' "types: no -> false"
has_line "$l" '        resize_on_border = true,' "types: on -> true"
has_line "$l" '            enabled = true,' "types: yes -> true"
has_line "$l" '            offset = { 0, 4 },' "types: a vec2 is a two-element table"
has_line "$l" '        swallow_regex = "^(kitty)$",' "types: a regex is a string"
has_line "$r" '    float = true,' "types: a rule's yes -> true"
has_line "$r" '    workspace = "4 silent",' "types: a rule value with words stays a string"
has_line "$r" '    opacity = "0.9 override 0.9 override",  -- fixed, not multiplied' \
    "types: a trailing comment on a rule field survives"
m="$dir/hyprland.lua"
has_line "$m" 'hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "2560x0", scale = 1.5, transform = 1 })' \
    "monitor: trailing key/value pairs become fields"
has_line "$m" 'hl.monitor({ output = "DP-3", disabled = true })' "monitor: 'disable' -> disabled = true"

# A key removed at or before the first release that reads lua has no lua form at all.
assert_grep "^        -- NOT APPLIED \('dwindle:pseudotile' was removed in Hyprland 0\.55" "$l" \
    "removed key: dwindle:pseudotile is carried across as a comment"
lacks '^ +pseudotile = ' "removed key: ...and is not emitted as a live option" "$l"
if printf '%s\n' "$out" | grep -q '^NOT_APPLIED_COUNT=3$'; then
    pass "exactly the 3 lines with no lua form are NOT APPLIED (removed key, unknown dispatcher, exec with rules)"
else
    fail "exactly the 3 lines with no lua form are NOT APPLIED (removed key, unknown dispatcher, exec with rules)" \
        "$(printf '%s\n' "$out" | grep '^NOT_APPLIED')"
fi

# --------------------------------------------------------------------------------------------
# A shell command that calls hyprctl the legacy way would load and then do nothing
# --------------------------------------------------------------------------------------------
has_line "$b" "hl.bind(\"SUPER + M\", hl.dsp.exec_cmd(\"hyprctl dispatch 'hl.dsp.exit()'\"))" \
    "hyprctl: 'hyprctl dispatch exit' is rewritten to the lua dispatcher"
assert_file_contains "$b" \
    "hyprctl eval \\\"hl.config({ cursor = { zoom_factor = \$(hyprctl getoption cursor.zoom_factor -j | jq '.float*1.25') } })\\\"" \
    "hyprctl: 'hyprctl keyword a:b \$(..)' is rewritten to hyprctl eval, with the dotted option name"
has_line "$b" 'hl.bind("SUPER + Z", hl.dsp.exec_cmd("pkill foo && hyprctl keyword general:gaps_in 0"))' \
    "hyprctl: a command it cannot safely rewrite is left exactly as written"
if printf '%s\n' "$out" | grep -q '^REVIEW=.*binds\.conf:.*calls `hyprctl keyword`'; then
    pass "hyprctl: ...and flagged for review instead of passing as converted"
else
    fail "hyprctl: ...and flagged for review instead of passing as converted" "$out"
fi
if printf '%s\n' "$out" | grep -q '^REVIEW_COUNT=5$'; then
    pass "the run counts the 5 lines it converted with a caveat"
else
    fail "the run counts the 5 lines it converted with a caveat" \
        "$(printf '%s\n' "$out" | grep '^REVIEW')"
fi

# The offer reports the same two lists before anything is written.
odir="$tmp/offer"
mkdir -p "$odir"
cp "$fixture"/*.conf "$odir"/
oout="$(HYPR_VERSION=0.57.2 HYPR_DIR="$odir" bash "$migrate" 2>&1)"; rc=$?
assert_eq "0" "$rc" "the offer for the fixture set succeeds"
if printf '%s\n' "$oout" | grep -q '^WOULD_NOT_APPLY_COUNT=3$' \
        && printf '%s\n' "$oout" | grep -q '^WOULD_REVIEW_COUNT=5$'; then
    pass "the offer names what would not apply and what would need review"
else
    fail "the offer names what would not apply and what would need review" "$oout"
fi
assert_eq "" "$(cd "$odir" && ls | grep '\.lua$')" "the offer wrote no lua"

# --------------------------------------------------------------------------------------------
# A hyprlang comment that starts with `[` must not open a lua block comment
# --------------------------------------------------------------------------------------------
bdir="$tmp/block-comment"
mkdir -p "$bdir"
printf '#[[ a note ]] and more\nbind = SUPER, Q, killactive,\n' > "$bdir/hyprland.conf"
HYPR_VERSION=0.57.2 HYPR_DIR="$bdir" bash "$migrate" --convert >/dev/null 2>&1
has_line "$bdir/hyprland.lua" '-- [[ a note ]] and more' \
    "a '#[[' comment is not turned into a lua '--[[' block comment"
has_line "$bdir/hyprland.lua" 'hl.bind("SUPER + Q", hl.dsp.window.close())' \
    "...so the bind after it is still code"

# --------------------------------------------------------------------------------------------
# hyprlang reads a sourced file AT the source line: a palette sourced by a single-file config
# is visible to the lines after it, in the same file.
# --------------------------------------------------------------------------------------------
sdir="$tmp/single-file"
mkdir -p "$sdir"
printf '$accent = rgb(ff0000)\n$accent2 = rgb(00ff00)\n' > "$sdir/theme.conf"
printf 'source = %s/theme.conf\ngeneral {\n    col.active_border = $accent $accent2 45deg\n}\n' \
    "$sdir" > "$sdir/hyprland.conf"
HYPR_VERSION=0.57.2 HYPR_DIR="$sdir" bash "$migrate" --convert >/dev/null 2>&1
has_line "$sdir/hyprland.lua" 'local t = require("theme")' \
    "a palette sourced by the main file is required by the main file"
has_line "$sdir/hyprland.lua" '            active_border = { colors = { t.accent, t.accent2 }, angle = 45 },' \
    "...and used after the source line, as hyprlang would have expanded it"

# --------------------------------------------------------------------------------------------
# Constructs the fixture set does not carry
# --------------------------------------------------------------------------------------------
xdir="$tmp/extras"
mkdir -p "$xdir"
cat > "$xdir/hyprland.conf" <<'CONF'
source = ./palette.conf
general {
    col.inactive_border = rgba($dimee)
    border_size = $gap
}
windowrule = float on, match:class ^(kitty)$
windowrule = float, class:^(kitty)$
device {
    name = epic-mouse
    sensitivity = -0.5
}
plugin {
    hyprbars {
        bar_height = 20
        hyprbars-button = rgb(ff4040), 10, x, hyprctl dispatch killactive
    }
}
exec = pkill waybar; waybar
CONF
printf '$dim = 000000\n$gap = 4\n' > "$xdir/palette.conf"
xout="$(HYPR_VERSION=0.57.2 HYPR_DIR="$xdir" bash "$migrate" --convert 2>&1)"; rc=$?
assert_eq "0" "$rc" "extras: the set converts"
x="$xdir/hyprland.lua"
has_line "$xdir/palette.lua" '    dim = "000000",' \
    "extras: a palette value of digits stays text (000000 is a colour, not zero)"
has_line "$xdir/palette.lua" '    gap = 4,' "extras: a palette value that IS a number is one"
has_line "$x" 'local p = require("palette")' \
    "extras: a relative 'source = ./palette.conf' is required by its plain name"
has_line "$x" '            inactive_border = "rgba(" .. p.dim .. "ee)",' \
    "extras: a variable spliced into a value becomes a concatenation, not an inlined colour"
has_line "$x" '        border_size = p.gap,' "extras: a numeric option reads the palette number"
has_line "$x" '        class = "^(kitty)$",' "extras: the 0.53 one-line windowrule converts (match)"
has_line "$x" '    float = true,' "extras: the 0.53 one-line windowrule converts (effect)"
assert_grep '^-- NOT APPLIED \(only the 0\.53 one-line form .*: windowrule = float, class:' "$x" \
    "extras: a pre-0.53 one-line windowrule is not guessed at"
has_line "$x" 'hl.device({' "extras: a device block -> hl.device"
has_line "$x" '    name = "epic-mouse",' "extras: ...with its name"
has_line "$x" 'if hl.plugin.hyprbars ~= nil then' \
    "extras: plugin options are guarded on the plugin being loaded"
assert_grep "^ +-- NOT APPLIED \('hyprbars-button' looks like a plugin keyword" "$x" \
    "extras: a plugin keyword is not turned into an option"
assert_grep "^-- NOT APPLIED \('exec' ran on every reload" "$x" \
    "extras: the reload-time 'exec' keyword is not turned into a top-level command"
lacks 'hl\.exec_cmd\("pkill' "extras: ...and its command appears in no call" "$x"
if lua_bin="$(lua_interpreter)"; then
    assert_eq "ok" "$("$lua_bin" "$mock" "$xdir" 2>&1 | sed -n 's/^LOAD=//p')" \
        "extras: the converted set runs against the lua API"
fi

# A `source =` that climbs out of the config dir is refused - and nothing is written there.
odir2="$tmp/outside/hypr"
mkdir -p "$odir2"
printf 'env = A,1\n' > "$tmp/outside/elsewhere.conf"
printf 'source = ../elsewhere.conf\n' > "$odir2/hyprland.conf"
oout2="$(HYPR_VERSION=0.57.2 HYPR_DIR="$odir2" bash "$migrate" --convert 2>&1)"; rc=$?
assert_eq "3" "$rc" "a source that climbs out of the config dir is refused"
if printf '%s\n' "$oout2" | grep -q '^UNRESOLVED_SOURCE=.*lives outside'; then
    pass "...and named as living outside it"
else
    fail "...and named as living outside it" "$oout2"
fi
if [ -e "$tmp/outside/elsewhere.lua" ] || [ -e "$odir2/hyprland.lua" ]; then
    fail "...and no lua is written, inside the dir or out"
else
    pass "...and no lua is written, inside the dir or out"
fi

# --------------------------------------------------------------------------------------------
# The dispatcher table itself: every legacy name it knows, not just the ones a fixture uses
# --------------------------------------------------------------------------------------------
samples="$PLUGIN_ROOT/tests/fixtures/dispatcher-samples.py"
table="$(PYTHONPATH="$PLUGIN_ROOT/scripts" python3 "$samples" 2>&1)"; rc=$?
assert_eq "0" "$rc" "table: every dispatcher the converter knows has a sample, and each sample translates"
tab="$(printf '\t')"
bad_names=""
while IFS="$tab" read -r legacy lua; do
    [ -n "$legacy" ] || continue
    name="${lua#hl.dsp.}"; name="${name%%(*}"
    case "$dsp_api" in
        *[[:space:]]"$name"[[:space:]]*) ;;
        *) bad_names="$bad_names $legacy->$name" ;;
    esac
done <<< "$table"
assert_eq "" "$bad_names" "table: no legacy dispatcher maps to a name outside the lua API"
table_has() {
    if printf '%s\n' "$table" | grep -qxF -- "$1$tab$2"; then pass "$3"; else fail "$3" "$table"; fi
}
table_has dpms 'hl.dsp.dpms({ action = "disable", monitor = "DP-1" })' \
    "table: dpms off -> action disable (the lua action words are toggle/enable/disable)"
table_has settiled 'hl.dsp.window.float({ action = "disable" })' "table: settiled -> float disable"
table_has movewindow 'hl.dsp.window.move({ monitor = "DP-1", follow = false })' \
    "table: movewindow mon:NAME silent -> move to the monitor without following"
table_has moveactive 'hl.dsp.window.move({ x = 100, y = 100 })' \
    "table: 'exact' coordinates are absolute (no relative flag)"
table_has exit 'hl.dsp.exit()' "table: exit -> hl.dsp.exit()"

# `py <expr>` - evaluate one expression against the module.
py() {
    PYTHONPATH="$PLUGIN_ROOT/scripts" python3 -c \
        "from ricelib.hypr.luadispatch import *; print($1)" 2>&1
}
assert_eq "(None, \"dispatcher 'resizeactive': x and y must be plain numbers (a percentage has no lua form)\")" \
    "$(py 'translate("resizeactive", "10% 0")')" \
    "table: an argument with no lua form is a reason, not a guess"
assert_eq "None" "$(py 'translate("fullscreen", "2")[0]')" "table: an unknown fullscreen mode is refused"
assert_eq "None" "$(py 'translate("changegroupactive", "3")[0]')" \
    "table: a tab index is refused rather than guessed (0- or 1-based is unknown)"
assert_eq 'hl.dsp.focus({ workspace = "-1" })' "$(py 'translate("workspace", "-1")[0]')" \
    "table: a relative workspace (-1) is a selector string, never the id -1"
assert_eq "hl.dsp.window.drag()" "$(py 'translate("movewindow", "", True)[0]')" \
    "table: under bindm, movewindow is the drag"
assert_eq "SUPER + SHIFT + Q" "$(py 'chord("SUPER_SHIFT", "Q")[0]')" "chord: SUPER_SHIFT is two modifiers"
assert_eq "SUPER + SHIFT + Q" "$(py 'chord("SUPERSHIFT", "Q")[0]')" "chord: so is SUPERSHIFT"
assert_eq "XF86AudioMute" "$(py 'chord("", "XF86AudioMute")[0]')" "chord: no modifier is just the key"
assert_eq "None" "$(py 'chord("HYPER", "Q")[0]')" "chord: an unknown modifier is refused, not passed through"
assert_eq "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'" \
    "$(py 'modernize_command("hyprctl dispatch dpms off")[0]')" \
    "hyprctl: a hypridle-style 'hyprctl dispatch dpms off' is rewritten"
assert_eq 'hyprctl eval "hl.config({ general = { gaps_in = 0 } })"' \
    "$(py 'modernize_command("hyprctl keyword general:gaps_in 0")[0]')" \
    "hyprctl: a literal 'hyprctl keyword' is rewritten to hyprctl eval"
assert_eq "hyprctl dispatch 'hl.dsp.exit()'" \
    "$(py "modernize_command(\"hyprctl dispatch 'hl.dsp.exit()'\")[0]")" \
    "hyprctl: a command that is already lua is left alone"
assert_eq "None" "$(py "modernize_command(\"hyprctl dispatch 'hl.dsp.exit()'\")[1]")" \
    "hyprctl: ...and not flagged"
assert_eq "hyprctl keyword general:col.active_border \"rgb(ff0000)\"" \
    "$(py 'modernize_command("hyprctl keyword general:col.active_border \"rgb(ff0000)\"")[0]')" \
    "hyprctl: a quoted value is not rewritten (the quoting cannot be carried safely)"

# --------------------------------------------------------------------------------------------
# Layer 2 - execute the converted config against a mock of the lua API
# --------------------------------------------------------------------------------------------
if lua_bin="$(lua_interpreter)"; then
    mout="$("$lua_bin" "$mock" "$dir" 2>&1)"; rc=$?
    assert_eq "0" "$rc" "mock: the converted config runs to the end (no call to a nil function)"
    mval() { printf '%s\n' "$mout" | sed -n "s/^$1=//p" | head -n1; }
    if [ "$rc" -ne 0 ]; then
        fail "mock: no load error" "$mout"
    fi
    assert_eq "0" "$(mval EXEC_AT_LOAD)" \
        "mock: EVALUATING the config runs no command (what --verify-config does)"
    assert_eq "3" "$(mval EXEC_ON_START)" "mock: the hyprland.start event runs the 3 exec-once commands"
    assert_eq "1" "$(mval EXEC_ON_SHUTDOWN)" "mock: the hyprland.shutdown event runs the exec-shutdown command"
    assert_eq "39" "$(mval BINDS)" "mock: 39 binds register, each with a chord Hyprland can parse"
    assert_eq "3" "$(mval SUBMAP_BINDS)" "mock: 3 of them inside the resize submap"
    assert_eq "1" "$(mval ENV_DBUS)" "mock: one env is exported to D-Bus (the envd)"
    assert_eq "2 4" "$(mval CURVES) $(mval ANIMATIONS)" "mock: 2 curves and 4 animations are declared"
    assert_eq "2 1 2" "$(mval WINDOW_RULES) $(mval LAYER_RULES) $(mval WORKSPACE_RULES)" \
        "mock: 2 window rules, 1 layer rule, 2 workspace rules are declared"

    # The mock is only evidence if it rejects what Hyprland rejects.
    ndir="$tmp/negative"
    mkdir -p "$ndir"
    printf 'hl.bind("SUPER + Q", hl.dsp.killactive())\n' > "$ndir/hyprland.lua"
    nout="$("$lua_bin" "$mock" "$ndir" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ] && printf '%s\n' "$nout" | grep -q "^ERROR=.*nil value (field 'killactive')"; then
        pass "mock control: a legacy dispatcher name fails the way it does in Hyprland"
    else
        fail "mock control: a legacy dispatcher name fails the way it does in Hyprland" "$nout"
    fi
    printf 'hl.bind("SUPER SHIFT + Q", hl.dsp.window.close())\n' > "$ndir/hyprland.lua"
    nout="$("$lua_bin" "$mock" "$ndir" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ] && printf '%s\n' "$nout" | grep -q 'Unknown key: SUPER SHIFT'; then
        pass "mock control: 'SUPER SHIFT + Q' fails the way it does in Hyprland"
    else
        fail "mock control: 'SUPER SHIFT + Q' fails the way it does in Hyprland" "$nout"
    fi
    printf 'hl.exec_cmd("true")\n' > "$ndir/hyprland.lua"
    nout="$("$lua_bin" "$mock" "$ndir" 2>&1)"
    assert_eq "1" "$(printf '%s\n' "$nout" | sed -n 's/^EXEC_AT_LOAD=//p')" \
        "mock control: a top-level hl.exec_cmd() is counted as run at load"
else
    skip "mock: the converted config runs to the end" "no standalone lua interpreter installed"
fi

# --------------------------------------------------------------------------------------------
# Layer 3 - the compositor's own offline check
# --------------------------------------------------------------------------------------------
# Guarded: `--verify-config` evaluates top-level code, so a config that (wrongly) has a
# top-level command is never handed to it, not even isolated. The assertions above already
# failed in that case; running the commands would add nothing.
if ! hyprland_reads_lua; then
    skip "hyprland: the offline check accepts the converted config" \
        "no Hyprland 0.55 or newer on this host"
elif grep -qE '^hl\.exec_cmd' "${luas[@]}"; then
    fail "hyprland: the offline check accepts the converted config" \
        "not run: the converted config has a top-level hl.exec_cmd()"
else
    vout="$(verify_config_isolated "$dir/hyprland.lua")"
    if printf '%s\n' "$vout" | grep -qx 'config ok'; then
        pass "hyprland: the offline check accepts the converted config (config ok)"
    else
        fail "hyprland: the offline check accepts the converted config (config ok)" \
            "$(printf '%s\n' "$vout" | sed -n '/Config parsing result/,$p')"
    fi

    # Every dispatcher the table knows, bound once: Hyprland validates a dispatcher's arguments
    # when it is constructed, so `config ok` means it accepts every shape the converter writes.
    tdir="$tmp/table"
    mkdir -p "$tdir"
    PYTHONPATH="$PLUGIN_ROOT/scripts" python3 "$samples" --binds > "$tdir/hyprland.lua" 2>&1
    vout="$(verify_config_isolated "$tdir/hyprland.lua")"
    if printf '%s\n' "$vout" | grep -qx 'config ok'; then
        pass "hyprland: it accepts every dispatcher shape in the converter's table"
    else
        fail "hyprland: it accepts every dispatcher shape in the converter's table" \
            "$(printf '%s\n' "$vout" | sed -n '/Config parsing result/,$p')"
    fi

    # The check itself must not run the autostart. An exec-once that leaves a marker proves it.
    vdir="$tmp/verify-marker"
    mkdir -p "$vdir"
    marker="$tmp/autostart-ran"
    printf 'exec-once = touch %s\nbind = SUPER, Q, killactive,\n' "$marker" > "$vdir/hyprland.conf"
    HYPR_VERSION=0.57.2 HYPR_DIR="$vdir" bash "$migrate" --convert >/dev/null 2>&1
    if grep -qE '^hl\.exec_cmd' "$vdir/hyprland.lua"; then
        fail "hyprland: checking a config does not run its exec-once" \
            "not run: the converted config has a top-level hl.exec_cmd()"
    else
        vout="$(verify_config_isolated "$vdir/hyprland.lua")"
        # A command spawned by the check would be asynchronous; give it a moment to land.
        for _ in 1 2 3 4 5; do [ -e "$marker" ] && break; sleep 0.1; done
        if printf '%s\n' "$vout" | grep -qx 'config ok' && [ ! -e "$marker" ]; then
            pass "hyprland: checking a config does not run its exec-once"
        else
            fail "hyprland: checking a config does not run its exec-once" \
                "marker present: $([ -e "$marker" ] && echo yes || echo no)
$(printf '%s\n' "$vout" | sed -n '/Config parsing result/,$p')"
        fi
    fi
fi

rm -rf "$tmp"

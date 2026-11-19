#!/usr/bin/env bash
# The theme engine under a LUA config.
#
# Hyprland's own colours exist in two languages: a hyprlang config sources a file of
# `$accent = rgb(...)` variables, a lua config `require`s a module that returns them. The
# engine only knew the first. On a lua config (the only kind Hyprland 0.57 loads) it kept
# re-rendering a colors.conf that nothing reads, so a theme switch recoloured every app
# except the compositor - and the cursor theme it persisted went into an env.conf that
# Hyprland had stopped loading.
#
# Covered here:
#   - rice-init writes the Hyprland colours row in the language of the config that exists,
#     or of the detected version when there is none yet
#   - the lua template renders a module the config can `require`
#   - a manifest written before the config was converted still themes it: the lua palette
#     beside the hyprlang one is refreshed from the same values
#   - a converted config follows a theme switch end to end, with only colors.lua changing
#   - the palette's cursor theme is persisted into env.lua (env.conf when there is no lua),
#     behind a verified backup, changing nothing else in the file
#
# Every run has its own HOME; nothing outside the temp dir is read or written.

tmp="$(mktemp_test_dir render-lua)"
RS="$PLUGIN_ROOT/skills/rice/scripts"

# `sandbox <name>` - a fresh HOME. Echoes it; RICE_DIR and the hypr dir hang off it.
sandbox() { mkdir -p "$tmp/$1/.config/hypr"; printf '%s' "$tmp/$1"; }
# `rice <home> <cmd...>` - run an engine script inside that HOME, with no real session env.
rice() {
    local home="$1"; shift
    env -u XDG_CONFIG_HOME -u HYPR_DIR HOME="$home" RICE_DIR="$home/.config/hypr-rice" \
        CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$@"
}
row_of() { grep '^hyprland'"$(printf '\t')" "$1/.config/hypr-rice/templates.list"; }

# --------------------------------------------------------------------------------------------
# rice-init: the colours row follows the config language
# --------------------------------------------------------------------------------------------
h="$(sandbox init-lua)"
rice "$h" HYPR_VERSION=0.57.2 bash "$RS/rice-init.sh" >/dev/null 2>&1
assert_file_exists "$h/.config/hypr-rice/templates/hyprland-lua.tmpl" "init: the lua colour template is installed"
case "$(row_of "$h")" in
    *"/hyprland-lua.tmpl"*"~/.config/hypr/colors.lua"*) pass "init: on a version that reads lua, the row renders colors.lua" ;;
    *) fail "init: on a version that reads lua, the row renders colors.lua" "$(row_of "$h")" ;;
esac

h="$(sandbox init-conf)"
rice "$h" HYPR_VERSION=0.54.3 bash "$RS/rice-init.sh" >/dev/null 2>&1
case "$(row_of "$h")" in
    *"/hyprland.tmpl"*"~/.config/hypr/colors.conf"*) pass "init: on a hyprlang version, the row renders colors.conf" ;;
    *) fail "init: on a hyprlang version, the row renders colors.conf" "$(row_of "$h")" ;;
esac

# The config that is THERE outranks the version: it is what Hyprland will load.
h="$(sandbox init-existing-lua)"
printf -- '-- a lua config\n' > "$h/.config/hypr/hyprland.lua"
rice "$h" HYPR_VERSION=0.54.3 bash "$RS/rice-init.sh" >/dev/null 2>&1
case "$(row_of "$h")" in
    *colors.lua*) pass "init: an existing hyprland.lua decides for lua" ;;
    *) fail "init: an existing hyprland.lua decides for lua" "$(row_of "$h")" ;;
esac
h="$(sandbox init-existing-conf)"
printf '# a hyprlang config\n' > "$h/.config/hypr/hyprland.conf"
rice "$h" HYPR_VERSION=0.56.2 bash "$RS/rice-init.sh" >/dev/null 2>&1
case "$(row_of "$h")" in
    *colors.conf*) pass "init: an existing hyprland.conf (and no lua) decides for hyprlang" ;;
    *) fail "init: an existing hyprland.conf (and no lua) decides for hyprlang" "$(row_of "$h")" ;;
esac

# --------------------------------------------------------------------------------------------
# The lua template renders a module
# --------------------------------------------------------------------------------------------
h="$(sandbox render-lua)"
rice "$h" HYPR_VERSION=0.57.2 bash "$RS/rice-init.sh" >/dev/null 2>&1
out="$(rice "$h" bash "$h/.config/hypr-rice/render-templates.sh" --no-reload 2>&1)"; rc=$?
assert_eq "0" "$rc" "lua row: the render pass succeeds"
c="$h/.config/hypr/colors.lua"
assert_file_exists "$c" "lua row: colors.lua is written"
assert_grep '^return \{$' "$c" "lua row: it is a module that returns a table"
assert_grep '^    accent  = "rgb\(cba6f7\)",$' "$c" "lua row: with the palette's accent"
if grep -q '{{' "$c"; then fail "lua row: no placeholder is left unrendered"; else pass "lua row: no placeholder is left unrendered"; fi
if [ -e "$h/.config/hypr/colors.conf" ]; then
    fail "lua row: no hyprlang colors.conf is written beside it"
else
    pass "lua row: no hyprlang colors.conf is written beside it"
fi
if lua_bin="$(lua_interpreter)"; then
    got="$(PALETTE="$c" "$lua_bin" -e 'local c = dofile(os.getenv("PALETTE")); io.write(c.accent, " ", c.bg, " ", c.muted)' 2>&1)"
    assert_eq "rgb(cba6f7) rgb(1e1e2e) rgb(6c7086)" "$got" "lua row: lua loads it and reads the colours back"
else
    skip "lua row: lua loads it and reads the colours back" "no standalone lua interpreter installed"
fi

# --------------------------------------------------------------------------------------------
# A manifest from before the conversion: the lua palette beside the .conf is kept in step
# --------------------------------------------------------------------------------------------
h="$(sandbox stale)"
rice "$h" HYPR_VERSION=0.54.3 bash "$RS/rice-init.sh" >/dev/null 2>&1
case "$(row_of "$h")" in *colors.conf*) ;; *) fail "stale: precondition - the manifest has the hyprlang row" ;; esac
printf -- '-- converted\n' > "$h/.config/hypr/hyprland.lua"
printf -- '-- what migrate-config.sh left\nreturn {\n    accent = "rgb(000000)",\n}\n' > "$h/.config/hypr/colors.lua"
out="$(rice "$h" bash "$h/.config/hypr-rice/render-templates.sh" --no-reload 2>&1)"
c="$h/.config/hypr/colors.lua"
assert_grep '^    accent = "rgb\(cba6f7\)",$' "$c" \
    "stale: the lua palette is refreshed from the palette, though the manifest only names the .conf"
assert_grep '^    muted = "rgb\(6c7086\)",$' "$c" "stale: every variable of the hyprlang palette is in it"
assert_file_exists "$h/.config/hypr/colors.conf" "stale: the .conf the manifest names is still written"
if printf '%s\n' "$out" | grep -q "^RENDERED hyprland -> $c (lua palette"; then
    pass "stale: the pass reports the lua palette it refreshed"
else
    fail "stale: the pass reports the lua palette it refreshed" "$out"
fi
if lua_bin="$(lua_interpreter)"; then
    assert_eq "rgb(cba6f7)" "$(PALETTE="$c" "$lua_bin" -e 'io.write(dofile(os.getenv("PALETTE")).accent)' 2>&1)" \
        "stale: the refreshed module is valid lua"
fi

# With no lua palette to refresh, none is invented - and the dead .conf is called out.
h="$(sandbox stale-no-module)"
rice "$h" HYPR_VERSION=0.54.3 bash "$RS/rice-init.sh" >/dev/null 2>&1
printf -- '-- a hand-written lua config\n' > "$h/.config/hypr/hyprland.lua"
out="$(rice "$h" bash "$h/.config/hypr-rice/render-templates.sh" --no-reload 2>&1)"
if [ -e "$h/.config/hypr/colors.lua" ]; then
    fail "stale: a lua palette nothing requires is not invented"
else
    pass "stale: a lua palette nothing requires is not invented"
fi
if printf '%s\n' "$out" | grep -q '^NOTE hyprland: .*colors\.conf is a hyprlang palette'; then
    pass "stale: ...and the pass says the .conf it rendered is not loaded by the lua config"
else
    fail "stale: ...and the pass says the .conf it rendered is not loaded by the lua config" "$out"
fi

# Only a file of $variables is a palette. hyprlock.conf lives in the same dir, is hyprlang on
# every Hyprland version, and must never be mistaken for one.
h="$(sandbox not-a-palette)"
rice "$h" HYPR_VERSION=0.54.3 bash "$RS/rice-init.sh" >/dev/null 2>&1
printf -- '-- lua\n' > "$h/.config/hypr/hyprland.lua"
printf 'general {\n    color = rgb({{accent}})\n}\n' > "$h/.config/hypr-rice/templates/lockish.tmpl"
printf 'lockish\t%s\t~/.config/hypr/lockish.conf\t\n' "$h/.config/hypr-rice/templates/lockish.tmpl" \
    >> "$h/.config/hypr-rice/templates.list"
printf 'SENTINEL\n' > "$h/.config/hypr/lockish.lua"
rice "$h" bash "$h/.config/hypr-rice/render-templates.sh" --no-reload >/dev/null 2>&1
assert_eq "SENTINEL" "$(cat "$h/.config/hypr/lockish.lua")" \
    "a hyprlang file that is not a palette never overwrites the .lua beside it"
assert_grep 'rgb\(cba6f7\)' "$h/.config/hypr/lockish.conf" "...and is itself rendered as before"

# --------------------------------------------------------------------------------------------
# End to end: convert a config, switch the theme, and only colors.lua changes
# --------------------------------------------------------------------------------------------
h="$(sandbox e2e)"
cp "$PLUGIN_ROOT/tests/fixtures/migrate-hyprlang"/*.conf "$h/.config/hypr"/
rice "$h" HYPR_VERSION=0.54.3 bash "$RS/rice-init.sh" >/dev/null 2>&1
rice "$h" HYPR_VERSION=0.57.2 bash "$RS/migrate-config.sh" --convert >/dev/null 2>&1
assert_file_exists "$h/.config/hypr/colors.lua" "e2e: the conversion produced the palette module"
before="$(cd "$h/.config/hypr" && cat hyprland.lua looknfeel.lua binds.lua rules.lua | cksum)"
# A new theme: gruvbox's accent.
sed -i 's/^accent=.*/accent=fabd2f/' "$h/.config/hypr-rice/palette.conf"
rice "$h" bash "$h/.config/hypr-rice/render-templates.sh" --no-reload >/dev/null 2>&1
assert_grep '^    accent = "rgb\(fabd2f\)",$' "$h/.config/hypr/colors.lua" \
    "e2e: after the theme switch colors.lua holds the new accent"
assert_eq "$before" "$(cd "$h/.config/hypr" && cat hyprland.lua looknfeel.lua binds.lua rules.lua | cksum)" \
    "e2e: no other converted file changed"
if grep -q 'cba6f7' "$h/.config/hypr"/*.lua; then
    fail "e2e: the old accent survives nowhere in the lua config" "$(grep -l 'cba6f7' "$h/.config/hypr"/*.lua)"
else
    pass "e2e: the old accent survives nowhere in the lua config"
fi
if lua_bin="$(lua_interpreter)"; then
    assert_eq "ok" "$("$lua_bin" "$PLUGIN_ROOT/tests/fixtures/hl-mock.lua" "$h/.config/hypr" 2>&1 | sed -n 's/^LOAD=//p')" \
        "e2e: the re-themed config still runs against the lua API"
fi
if hyprland_reads_lua && ! grep -qE '^hl\.exec_cmd' "$h/.config/hypr"/*.lua; then
    if verify_config_isolated "$h/.config/hypr/hyprland.lua" | grep -qx 'config ok'; then
        pass "e2e: Hyprland's offline check accepts the re-themed config"
    else
        fail "e2e: Hyprland's offline check accepts the re-themed config"
    fi
else
    skip "e2e: Hyprland's offline check accepts the re-themed config" "no Hyprland 0.55 or newer on this host"
fi

# --------------------------------------------------------------------------------------------
# The cursor theme is persisted into the env file Hyprland actually loads
# --------------------------------------------------------------------------------------------
h="$(sandbox cursor-lua)"
rice "$h" HYPR_VERSION=0.57.2 bash "$RS/rice-init.sh" >/dev/null 2>&1
printf 'cursor_theme=Bibata-Modern-Ice\ncursor_size=32\n' >> "$h/.config/hypr-rice/palette.conf"
e="$h/.config/hypr/env.lua"
cat > "$e" <<'LUA'
-- Environment
hl.env("XDG_CURRENT_DESKTOP", "Hyprland", true)
hl.env("XCURSOR_THEME", "Old-Theme")
hl.env("XCURSOR_SIZE", "24")  -- kept comment
hl.env("GDK_BACKEND", "wayland,x11,*")
LUA
printf 'env = XCURSOR_THEME,Old-Theme\n' > "$h/.config/hypr/env.conf"
cp "$e" "$tmp/env.lua.orig"
out="$(rice "$h" RICE_STAMP_OVERRIDE=20260101-000000 bash "$h/.config/hypr-rice/render-templates.sh" --no-reload 2>&1)"
assert_grep '^hl\.env\("XCURSOR_THEME", "Bibata-Modern-Ice"\)$' "$e" "cursor: env.lua gets the theme"
assert_grep '^hl\.env\("XCURSOR_SIZE", "32"\)  -- kept comment$' "$e" \
    "cursor: only the VALUE changes - the trailing comment stays"
assert_grep '^hl\.env\("HYPRCURSOR_THEME", "Bibata-Modern-Ice"\)$' "$e" "cursor: a missing variable is appended"
assert_grep '^hl\.env\("HYPRCURSOR_SIZE", "32"\)$' "$e" "cursor: ...the size too"
assert_grep '^hl\.env\("XDG_CURRENT_DESKTOP", "Hyprland", true\)$' "$e" "cursor: unrelated lines are untouched"
assert_eq "7" "$(grep -c '' "$e")" "cursor: nothing else was added or removed"
assert_eq "env = XCURSOR_THEME,Old-Theme" "$(cat "$h/.config/hypr/env.conf")" \
    "cursor: env.conf is left alone when env.lua is the loaded file"
bak="$e.bak.20260101-000000"
if [ -f "$bak" ] && cmp -s "$bak" "$tmp/env.lua.orig"; then
    pass "cursor: the previous env.lua is kept, byte for byte, beside it"
else
    fail "cursor: the previous env.lua is kept, byte for byte, beside it" "$(ls "$h/.config/hypr")"
fi
if printf '%s\n' "$out" | grep -q "^CURSOR_ENV=$e (Bibata-Modern-Ice, size 32; the previous version is $bak)"; then
    pass "cursor: the pass reports the file and where its previous version went"
else
    fail "cursor: the pass reports the file and where its previous version went" "$out"
fi
# Idempotent: a second render changes nothing and takes no second backup.
after_first="$(cat "$e")"
out="$(rice "$h" RICE_STAMP_OVERRIDE=20260101-000001 bash "$h/.config/hypr-rice/render-templates.sh" --no-reload 2>&1)"
assert_eq "$after_first" "$(cat "$e")" "cursor: a second render leaves env.lua identical"
assert_eq "1" "$(find "$h/.config/hypr" -name 'env.lua.bak.*' | wc -l | tr -d ' ')" \
    "cursor: ...and takes no backup for a write it did not make"

# A value set by an expression is not ours to rewrite.
h="$(sandbox cursor-expr)"
rice "$h" HYPR_VERSION=0.57.2 bash "$RS/rice-init.sh" >/dev/null 2>&1
printf 'cursor_theme=Bibata-Modern-Ice\n' >> "$h/.config/hypr-rice/palette.conf"
e="$h/.config/hypr/env.lua"
printf 'local theme = "Mine"\nhl.env("XCURSOR_THEME", theme)\n' > "$e"
out="$(rice "$h" bash "$h/.config/hypr-rice/render-templates.sh" --no-reload 2>&1)"
assert_grep '^hl\.env\("XCURSOR_THEME", theme\)$' "$e" "cursor: a value set by an expression is left as written"
if printf '%s\n' "$out" | grep -q '^CURSOR_ENV_NOTE .*XCURSOR_THEME is set by an expression'; then
    pass "cursor: ...and the pass says so"
else
    fail "cursor: ...and the pass says so" "$out"
fi

# hyprlang: with no env.lua, env.conf is the file.
h="$(sandbox cursor-conf)"
rice "$h" HYPR_VERSION=0.54.3 bash "$RS/rice-init.sh" >/dev/null 2>&1
printf 'cursor_theme=Bibata-Modern-Ice\n' >> "$h/.config/hypr-rice/palette.conf"
e="$h/.config/hypr/env.conf"
printf 'env = XCURSOR_THEME,Old-Theme\nenv = XCURSOR_SIZE,20   # hidpi\n' > "$e"
rice "$h" bash "$h/.config/hypr-rice/render-templates.sh" --no-reload >/dev/null 2>&1
assert_grep '^env = XCURSOR_THEME,Bibata-Modern-Ice$' "$e" "cursor: with no env.lua, env.conf gets the theme"
assert_grep '^env = XCURSOR_SIZE,24   # hidpi$' "$e" "cursor: the size defaults to 24, comment kept"
assert_grep '^env = HYPRCURSOR_THEME,Bibata-Modern-Ice$' "$e" "cursor: a missing hyprlang line is appended"

# No cursor_theme in the palette: the engine has no opinion, and the file is not opened.
h="$(sandbox cursor-none)"
rice "$h" HYPR_VERSION=0.57.2 bash "$RS/rice-init.sh" >/dev/null 2>&1
printf 'hl.env("XCURSOR_THEME", "Mine")\n' > "$h/.config/hypr/env.lua"
out="$(rice "$h" bash "$h/.config/hypr-rice/render-templates.sh" --no-reload 2>&1)"
assert_eq 'hl.env("XCURSOR_THEME", "Mine")' "$(cat "$h/.config/hypr/env.lua")" \
    "cursor: a palette with no cursor_theme changes nothing"
if printf '%s\n' "$out" | grep -q '^CURSOR_ENV'; then
    fail "cursor: ...and reports nothing about the cursor" "$out"
else
    pass "cursor: ...and reports nothing about the cursor"
fi

# The backup cannot be written: the file is NOT edited. (Never overwrite what you could not
# first make recoverable.)
if [ "$(id -u)" = "0" ]; then
    skip "cursor: an unwritable backup skips the edit" "running as root; permission bits are not enforced"
else
    h="$(sandbox cursor-nobackup)"
    rice "$h" HYPR_VERSION=0.57.2 bash "$RS/rice-init.sh" >/dev/null 2>&1
    printf 'cursor_theme=Bibata-Modern-Ice\n' >> "$h/.config/hypr-rice/palette.conf"
    # The lua row would write colors.lua into the same dir; drop it so the dir can be read-only.
    sed -i '/^hyprland\t/d' "$h/.config/hypr-rice/templates.list"
    e="$h/.config/hypr/env.lua"
    printf 'hl.env("XCURSOR_THEME", "Old-Theme")\n' > "$e"
    chmod 555 "$h/.config/hypr"
    out="$(rice "$h" bash "$h/.config/hypr-rice/render-templates.sh" --no-reload 2>&1)"
    chmod 755 "$h/.config/hypr"
    assert_eq 'hl.env("XCURSOR_THEME", "Old-Theme")' "$(cat "$e")" \
        "cursor: when the backup cannot be written, env.lua is not edited"
    if printf '%s\n' "$out" | grep -q '^CURSOR_ENV_SKIPPED .*backup .* could not be written'; then
        pass "cursor: ...and the skip names the backup that failed"
    else
        fail "cursor: ...and the skip names the backup that failed" "$out"
    fi
fi

rm -rf "$tmp"

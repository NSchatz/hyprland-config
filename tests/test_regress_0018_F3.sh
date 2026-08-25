#!/usr/bin/env bash
# S0018-hyprland-config-lua-4 - impl-gate loop 1 regression artifact F3 (advisory).
#
# Written by the refuter; kept verbatim in substance and moved into the suite
# (`regress_0018_F3.sh` -> `test_regress_0018_F3.sh`) so `tests/run.sh` discovers
# it. The assertion is the refuter's; only the reporting was rewired onto
# tests/lib.sh.
#
# migrate-config.sh resolved a `source = ~/...` line against $HOME
# (convert_source: `'~/'*) p="$HOME/${p#\~/}"`) but resolved the config set
# against $HYPR_DIR. Every writing script in this repo honours HYPR_DIR - it is
# how README.md, the card's command table and every test in tests/ exercise them
# without touching a real desktop. With HYPR_DIR set anywhere but
# $HOME/.config/hypr, the two disagreed and a config whose `source =` lines use
# the `~` form (which is the form this plugin's own generator writes) could not be
# converted at all. That coverage hole is how F1 went unnoticed.

MIGRATE="$PLUGIN_ROOT/skills/rice/scripts/migrate-config.sh"

tmp="$(mktemp_test_dir regress0018F3)"
dir="$tmp/hypr"          # a scratch HYPR_DIR, exactly as tests/README.md does it
mkdir -p "$dir"

# Two files: a main config that sources a module in the `~` form the plugin
# writes (see skills/rice/examples/sample-config/hyprland.conf lines 16-23),
# and that module. Both are valid hyprlang; both are convertible constructs.
printf '$mainMod = SUPER\nsource = ~/.config/hypr/env.conf\n' > "$dir/hyprland.conf"
printf 'env = XCURSOR_SIZE,24\n'                              > "$dir/env.conf"

out="$(HYPR_DIR="$dir" bash "$MIGRATE" 2>&1)"; rc=$?
if printf '%s\n' "$out" | grep -q '^MIGRATE_OFFER='; then
    pass "F3: the offer is made against a scratch HYPR_DIR"
else
    fail "F3: a HYPR_DIR override makes the ~ form unresolvable, so no offer is made" \
        "rc=$rc
$(printf '%s\n' "$out" | grep -E '^(UNRESOLVED_SOURCE|UNPARSEABLE|MIGRATE)=')"
fi

# ... and accepting it actually converts the sourced module, rather than writing a
# main lua that requires a file that was never produced.
out="$(HYPR_DIR="$dir" bash "$MIGRATE" --convert 2>&1)"; rc=$?
assert_eq "0" "$rc" "F3: the ~ form converts under a HYPR_DIR override"
assert_file_exists "$dir/env.lua" "F3: the ~-sourced module was converted"
assert_file_contains "$dir/hyprland.lua" 'require("env")' \
    "F3: the main lua requires the module it produced"

rm -rf "$tmp"

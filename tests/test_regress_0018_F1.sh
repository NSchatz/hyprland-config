#!/usr/bin/env bash
# S0018-hyprland-config-lua-4 - impl-gate loop 1 regression artifact F1 (BLOCKING).
#
# Written by the refuter; kept verbatim in substance and moved into the suite
# (`regress_0018_F1.sh` -> `test_regress_0018_F1.sh`) so `tests/run.sh` discovers
# it and the hole cannot reopen unnoticed. The assertions are the refuter's; only
# the reporting was rewired onto tests/lib.sh (pass/fail instead of echo + exit).
#
# Spec clause under test (AC-4, verbatim):
#   "WHEN a user carries a .conf written by an earlier release of this plugin
#    THE SYSTEM SHALL offer to convert it to lua and SHALL keep the .conf as a
#    backup rather than deleting it"
#
# The population AC-4 names is "a .conf written by an earlier release of this
# plugin". This repo ships its own canonical example of exactly that at
# skills/rice/examples/sample-config/ - the multi-file, `source =`-wired set the
# rice interview produces. This artifact drives migrate-config.sh against that
# set, with HOME pointed at the scratch root so `source = ~/.config/hypr/...`
# resolves inside the scratch config dir exactly as it does on a real machine.
#
# Expected if AC-4 holds: a default run prints MIGRATE_OFFER= ... and --convert
# writes a hyprland.lua while keeping the .conf.

MIGRATE="$PLUGIN_ROOT/skills/rice/scripts/migrate-config.sh"
SAMPLE="$PLUGIN_ROOT/skills/rice/examples/sample-config"

tmp="$(mktemp_test_dir regress0018F1)"
dir="$tmp/.config/hypr"
mkdir -p "$dir"
cp -a "$SAMPLE"/. "$dir"/

# 1. THE OFFER (default invocation, no --convert)
out="$(HOME="$tmp" HYPR_DIR="$dir" bash "$MIGRATE" 2>&1)"; rc=$?
if printf '%s\n' "$out" | grep -q '^MIGRATE_OFFER='; then
    pass "F1/AC-4: the plugin offers to convert a .conf it wrote itself"
else
    fail "F1/AC-4: NO offer was made for a .conf this plugin itself wrote" \
        "rc=$rc
$(printf '%s\n' "$out" | grep '^MIGRATE=' || echo '<no MIGRATE= line>')"
fi

# 2. ACCEPTING the offer (--convert)
out2="$(HOME="$tmp" HYPR_DIR="$dir" bash "$MIGRATE" --convert 2>&1)"; rc2=$?
if [ "$rc2" -eq 0 ] && [ -f "$dir/hyprland.lua" ]; then
    pass "F1/AC-4: the conversion produced a lua config"
else
    fail "F1/AC-4: the conversion produced NO lua config for a plugin-written .conf" \
        "rc=$rc2
$out2"
fi
if [ -f "$dir/hyprland.conf" ]; then
    pass "F1/AC-4: the .conf was kept (nothing was deleted)"
else
    fail "F1/AC-4: the .conf was deleted"
fi

# 3. control: the SAME config parses as hyprlang - it is not malformed.
# (AC-9 only sanctions refusing input that "is not parseable as the language it
# claims to be".) So nothing here may be reported as unparseable.
if printf '%s\n' "$out2" | grep -q '^UNPARSEABLE='; then
    fail "F1/AC-9: a well-formed plugin-written config is not called unparseable" \
        "$(printf '%s\n' "$out2" | grep '^UNPARSEABLE=')"
else
    pass "F1/AC-9: a well-formed plugin-written config is not called unparseable"
fi

# 4. and the lines that genuinely have no documented lua mapping are named, not
# dropped in silence: reported on stdout AND present in the file as comments.
not_applied="$(printf '%s\n' "$out2" | grep -c '^NOT_APPLIED=' || true)"
if [ "$not_applied" -gt 0 ]; then
    pass "F1: every unmappable line is reported by file and line ($not_applied of them)"
else
    fail "F1: every unmappable line is reported by file and line" "$out2"
fi
if grep -rq -- '-- NOT APPLIED (' "$dir"/*.lua; then
    pass "F1: the unmappable lines are carried into the lua as marked comments"
else
    fail "F1: the unmappable lines are carried into the lua as marked comments"
fi

rm -rf "$tmp"

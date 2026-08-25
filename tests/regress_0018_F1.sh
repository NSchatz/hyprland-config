#!/usr/bin/env bash
# S0018-hyprland-config-lua-4 - refuter regression artifact F1.
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
#
# Run: bash tests/regress_0018_F1.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
MIGRATE="$ROOT/skills/rice/scripts/migrate-config.sh"
SAMPLE="$ROOT/skills/rice/examples/sample-config"

tmp="$(mktemp -d /tmp/regress0018F1.XXXXXX)"
dir="$tmp/.config/hypr"
mkdir -p "$dir"
cp -a "$SAMPLE"/. "$dir"/

echo "### the plugin's own generated config, in a scratch \$HOME:"
echo "    HOME=$tmp   HYPR_DIR=$dir"
ls -1 "$dir"
echo

fails=0

echo "### 1. THE OFFER (default invocation, no --convert)"
out="$(HOME="$tmp" HYPR_DIR="$dir" bash "$MIGRATE" 2>&1)"; rc=$?
printf '%s\n' "$out"
echo "rc=$rc"
echo
if printf '%s\n' "$out" | grep -q '^MIGRATE_OFFER='; then
    echo "PASS  AC-4: the plugin offers to convert a .conf it wrote itself"
else
    echo "FAIL  AC-4: NO offer was made for a .conf this plugin itself wrote"
    echo "      it reported: $(printf '%s\n' "$out" | grep '^MIGRATE=' || echo '<no MIGRATE= line>')"
    fails=$((fails + 1))
fi

echo
echo "### 2. ACCEPTING the offer (--convert)"
out2="$(HOME="$tmp" HYPR_DIR="$dir" bash "$MIGRATE" --convert 2>&1)"; rc2=$?
printf '%s\n' "$out2"
echo "rc=$rc2"
echo
if [ "$rc2" -eq 0 ] && [ -f "$dir/hyprland.lua" ]; then
    echo "PASS  AC-4: the conversion produced a lua config"
else
    echo "FAIL  AC-4: the conversion produced NO lua config for a plugin-written .conf"
    fails=$((fails + 1))
fi
if [ -f "$dir/hyprland.conf" ]; then
    echo "PASS  AC-4: the .conf was kept (nothing was deleted)"
else
    echo "FAIL  AC-4: the .conf was deleted"
    fails=$((fails + 1))
fi

echo
echo "### 3. control: the SAME config parses as hyprlang - it is not malformed."
echo "    (AC-9 only sanctions refusing input that 'is not parseable as the"
echo "     language it claims to be'.) Lines the converter called unconvertible:"
printf '%s\n' "$out2" | grep '^UNCONVERTIBLE=' | sed 's/^/      /'

rm -rf "$tmp"
echo
if [ "$fails" -gt 0 ]; then
    echo "REGRESS_0018_F1=fail ($fails assertion(s) failed)"
    exit 1
fi
echo "REGRESS_0018_F1=pass"
exit 0

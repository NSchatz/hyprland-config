#!/usr/bin/env bash
# S0018-hyprland-config-lua-4 - refuter probe F3.
#
# migrate-config.sh resolves a `source = ~/...` line against $HOME
# (convert_source: `'~/'*) p="$HOME/${p#\~/}"`) but resolves the config set
# against $HYPR_DIR. Every writing script in this repo honours HYPR_DIR - it is
# how README.md, the card's command table and every test in tests/ exercise them
# without touching a real desktop. With HYPR_DIR set anywhere but
# $HOME/.config/hypr, the two disagree and a config whose `source =` lines use
# the `~` form (which is the form this plugin's own generator writes) cannot be
# converted at all.
#
# Run: bash tests/regress_0018_F3.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
MIGRATE="$ROOT/skills/rice/scripts/migrate-config.sh"

tmp="$(mktemp -d /tmp/regress0018F3.XXXXXX)"
dir="$tmp/hypr"          # a scratch HYPR_DIR, exactly as tests/README.md does it
mkdir -p "$dir"

# Two files: a main config that sources a module in the `~` form the plugin
# writes (see skills/rice/examples/sample-config/hyprland.conf lines 16-23),
# and that module. Both are valid hyprlang; both are convertible constructs.
printf '$mainMod = SUPER\nsource = ~/.config/hypr/env.conf\n' > "$dir/hyprland.conf"
printf 'env = XCURSOR_SIZE,24\n'                              > "$dir/env.conf"

echo "### HYPR_DIR=$dir  (a scratch dir, as every other script here supports)"
out="$(HYPR_DIR="$dir" bash "$MIGRATE" 2>&1)"; rc=$?
printf '%s\n' "$out" | sed 's/^/    /'
echo "    rc=$rc"
echo

fails=0
if printf '%s\n' "$out" | grep -q '^MIGRATE_OFFER='; then
    echo "PASS  the offer is made against a scratch HYPR_DIR"
else
    echo "FAIL  a HYPR_DIR override makes the ~ form unresolvable, so no offer is made"
    printf '%s\n' "$out" | grep '^UNCONVERTIBLE=' | sed 's/^/      /'
    fails=$((fails + 1))
fi

rm -rf "$tmp"
if [ "$fails" -gt 0 ]; then
    echo "REGRESS_0018_F3=fail"
    exit 1
fi
echo "REGRESS_0018_F3=pass"
exit 0

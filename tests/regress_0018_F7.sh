#!/usr/bin/env bash
# S0018 impl-gate loop 2 - offer-mode and dotfiles-shape probes.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RS="$ROOT/skills/rice/scripts"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/regress0018F7.XXXXXX")"

hr() { echo; echo "================ $* ================"; }

hr "1. OFFER mode with a sourced module that exists but cannot be read"
d="$tmp/1/hypr"; mkdir -p "$d"
printf 'bind = SUPER, Q, killactive,\nsource = %s/secret.conf\n' "$d" > "$d/hyprland.conf"
printf 'general {\n    gaps_in = 42\n}\n' > "$d/secret.conf"
chmod 000 "$d/secret.conf"
out="$(HYPR_DIR="$d" bash "$RS/migrate-config.sh" 2>&1)"; rc=$?
chmod 644 "$d/secret.conf"
echo "rc=$rc"
printf '%s\n' "$out"

hr "2. CONVERT where hyprland.conf is a symlink into a dotfiles tree"
d="$tmp/2/hypr"; mkdir -p "$d" "$tmp/2/dots"
printf 'general {\n    gaps_in = 4\n}\nbind = SUPER, Q, killactive,\n' > "$tmp/2/dots/hyprland.conf"
ln -s "$tmp/2/dots/hyprland.conf" "$d/hyprland.conf"
out="$(HYPR_DIR="$d" bash "$RS/migrate-config.sh" --convert 2>&1)"; rc=$?
echo "rc=$rc"
printf '%s\n' "$out" | grep -E '^(MIGRATE|WROTE|KEPT|BACKED_UP)=' || printf '%s\n' "$out"
echo "--- config dir now:"; ls -A "$d"
echo "--- is the symlink still a symlink pointing at the dotfiles copy?"
[ -L "$d/hyprland.conf" ] && echo "yes -> $(readlink "$d/hyprland.conf")" || echo "NO"

hr "3. The dispatcher pass-through the reference layer contradicts"
d="$tmp/3/hypr"; mkdir -p "$d"
printf 'bind = SUPER, J, layoutmsg, togglesplit\nbind = SUPER, K, movefocus, u\n' > "$d/hyprland.conf"
HYPR_DIR="$d" bash "$RS/migrate-config.sh" --convert >/dev/null 2>&1
echo "--- produced lua:"
grep -n 'hl\.' "$d/hyprland.lua"
echo "--- what the shipped reference layer says the lua form is:"
grep -n 'hl\.dsp\.layout(' "$ROOT/skills/rice/references/components/keybinds/gotchas.md"

echo
echo "scratch=$tmp"

#!/usr/bin/env bash
# S0018 impl-gate loop 2 - adversarial probe of paths the shipped suite does not cover.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RS="$ROOT/skills/rice/scripts"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/regress0018F5.XXXXXX")"
echo "scratch=$tmp"

hr() { echo; echo "================ $* ================"; }

# ---------------------------------------------------------------- A
hr "A. lua staging with NO provenance header, installed into an absent target"
st="$tmp/A-stage"; mkdir -p "$st"
printf 'hl.config({ general = { gaps_in = 3 } })\n' > "$st/hyprland.lua"
dest="$tmp/A-dest"
out="$(HYPR_DIR="$dest" bash "$RS/install-config.sh" "$st" 2>&1)"; rc=$?
echo "rc=$rc"
printf '%s\n' "$out"
echo "--- installed file:"
cat "$dest/hyprland.lua"

# ---------------------------------------------------------------- B
hr "B. migrate: a sourced module .conf that exists but CANNOT BE READ"
d="$tmp/B/hypr"; mkdir -p "$d"
printf '\$mainMod = SUPER\nsource = %s/secret.conf\nbind = \$mainMod, Q, killactive,\n' "$d" > "$d/hyprland.conf"
printf 'general {\n    gaps_in = 42\n    border_size = 9\n}\n' > "$d/secret.conf"
chmod 000 "$d/secret.conf"
out="$(HYPR_DIR="$d" bash "$RS/migrate-config.sh" --convert 2>&1)"; rc=$?
chmod 644 "$d/secret.conf"
echo "rc=$rc"
printf '%s\n' "$out"
echo "--- produced secret.lua (if any):"
if [ -f "$d/secret.lua" ]; then cat "$d/secret.lua"; else echo "<no secret.lua>"; fi
echo "--- does secret.lua carry gaps_in/border_size?"
grep -c 'gaps_in\|border_size' "$d/secret.lua" 2>/dev/null || echo 0

# ---------------------------------------------------------------- C
hr "C. migrate: the MAIN hyprland.conf exists but CANNOT BE READ"
d="$tmp/C/hypr"; mkdir -p "$d"
printf 'general {\n    gaps_in = 5\n}\nbind = SUPER, Q, killactive,\n' > "$d/hyprland.conf"
chmod 000 "$d/hyprland.conf"
out="$(HYPR_DIR="$d" bash "$RS/migrate-config.sh" --convert 2>&1)"; rc=$?
chmod 644 "$d/hyprland.conf"
echo "rc=$rc"
printf '%s\n' "$out"
echo "--- produced hyprland.lua (if any):"
if [ -f "$d/hyprland.lua" ]; then cat "$d/hyprland.lua"; else echo "<no hyprland.lua>"; fi

# ---------------------------------------------------------------- D
hr "D. migrate: source = with a .. traversal out of the config dir"
d="$tmp/D/hypr"; mkdir -p "$d" "$tmp/D/outside"
printf 'env = A,1\n' > "$tmp/D/outside/evil.conf"
printf '\$mainMod = SUPER\nsource = %s/../outside/evil.conf\n' "$d" > "$d/hyprland.conf"
out="$(HYPR_DIR="$d" bash "$RS/migrate-config.sh" --convert 2>&1)"; rc=$?
echo "rc=$rc"
printf '%s\n' "$out"
echo "--- files outside the config dir now:"
ls -A "$tmp/D/outside"

# ---------------------------------------------------------------- E
hr "E. install: target holds a DIRECTORY named hyprland.lua, staging is hyprlang"
st="$tmp/E-stage"; mkdir -p "$st"
HYPR_CONFIG_LANG=hyprlang HYPR_VERSION=0.54.3 bash "$RS/emit-config.sh" "$st" >/dev/null 2>&1
d="$tmp/E-dest"; mkdir -p "$d/hyprland.lua"
out="$(HYPR_DIR="$d" bash "$RS/install-config.sh" "$st" 2>&1)"; rc=$?
echo "rc=$rc"
printf '%s\n' "$out" | grep -E '^(REFUSED|DONE|SHADOWED_BY)=' || printf '%s\n' "$out"

# ---------------------------------------------------------------- F
hr "F. install: LUA staging into a target that already holds a hyprlang .conf set"
d="$tmp/F-dest"; mkdir -p "$d"
printf '# the user config this plugin wrote earlier\nbind = SUPER, Q, killactive,\n' > "$d/hyprland.conf"
printf 'env = XCURSOR_SIZE,24\n' > "$d/env.conf"
stl="$tmp/F-stage"; mkdir -p "$stl"
HYPR_CONFIG_LANG=lua HYPR_VERSION=0.56.2 bash "$RS/emit-config.sh" "$stl" >/dev/null 2>&1
out="$(HYPR_DIR="$d" bash "$RS/install-config.sh" "$stl" 2>&1)"; rc=$?
echo "rc=$rc"
printf '%s\n' "$out"
echo "--- target now holds:"
ls -A "$d"

# ---------------------------------------------------------------- G
hr "G. reset-config.sh: hyprlang chosen explicitly while the target holds a hyprland.lua"
d="$tmp/G-dest"; mkdir -p "$d"
printf -- '-- the user lua config Hyprland actually loads\nhl.config({ general = { gaps_in = 7 } })\n' > "$d/hyprland.lua"
out="$(HYPR_DIR="$d" HYPR_CONFIG_LANG=hyprlang PATH=/usr/bin:/bin bash "$RS/reset-config.sh" 2>&1)"; rc=$?
echo "rc=$rc"
printf '%s\n' "$out" | grep -E '^(RESET|WROTE|BACKUP|TARGET|CONFIG_LANGUAGE)=' || printf '%s\n' "$out"
echo "--- target now holds:"
ls -A "$d"

echo
echo "scratch left at $tmp"

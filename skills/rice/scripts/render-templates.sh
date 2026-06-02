#!/usr/bin/env bash
# Rice render engine: read the central palette, substitute {{key}} placeholders in each
# registered template, write the output file, and run the app's reload hook.
#
# This is the heart of the rice engine and is also installed into ~/.config/hypr-rice/ so the
# `rice` CLI can run it with no dependency on the plugin.
#
# Usage: render-templates.sh [--no-reload] [palette-file] [manifest-file]
#   palette  default: $RICE_DIR/palette.conf   (KEY=hex lines, no leading #)
#   manifest default: $RICE_DIR/templates.list (TAB-separated: name <tab> template <tab> output <tab> reload-cmd)
#
# Placeholders in templates: {{accent}}, {{bg}}, {{color0}}… → the bare hex from the palette.
# Templates add their own '#' / 'rgb(...)' wrappers (e.g. `#{{accent}}`, `rgb({{bg}})`).
#
# Output: RENDERED <name> -> <output> / RELOADED <name> / RELOAD_SKIPPED <name> / RENDER=done
set -uo pipefail

RICE_DIR="${RICE_DIR:-$HOME/.config/hypr-rice}"
reload=1
if [ "${1:-}" = "--no-reload" ]; then reload=0; shift; fi
palette="${1:-$RICE_DIR/palette.conf}"
manifest="${2:-$RICE_DIR/templates.list}"

[ -f "$palette" ]  || { echo "ERROR: palette not found: $palette" >&2; exit 2; }
[ -f "$manifest" ] || { echo "ERROR: manifest not found: $manifest" >&2; exit 2; }

# Load palette into an associative array (skip comments/blank lines).
declare -A P
load_kv() {
    local f="$1" k v
    while IFS='=' read -r k v; do
        case "$k" in ''|\#*) continue ;; esac
        k="${k//[[:space:]]/}"
        P["$k"]="$v"
    done < "$f"
}
load_kv "$palette"

# User-override layer (cascade: generated -> user). Keys in palette.user.conf win, so personal
# tweaks survive every re-theme. Edit ~/.config/hypr-rice/palette.user.conf to pin colors.
user_override="$RICE_DIR/palette.user.conf"
[ -f "$user_override" ] && load_kv "$user_override"

render_one() {
    local tmpl="$1" out="$2" content k
    content="$(cat "$tmpl")"
    for k in "${!P[@]}"; do
        content="${content//\{\{$k\}\}/${P[$k]}}"
    done
    mkdir -p "$(dirname "$out")"
    printf '%s' "$content" > "$out"
}

while IFS=$'\t' read -r name tmpl out rcmd; do
    case "$name" in ''|\#*) continue ;; esac
    tmpl="${tmpl/#\~/$HOME}"; out="${out/#\~/$HOME}"
    if [ ! -f "$tmpl" ]; then echo "SKIP $name (no template: $tmpl)"; continue; fi
    render_one "$tmpl" "$out"
    echo "RENDERED $name -> $out"
    if [ "$reload" -eq 1 ] && [ -n "${rcmd:-}" ]; then
        if eval "$rcmd" >/dev/null 2>&1; then echo "RELOADED $name"; else echo "RELOAD_SKIPPED $name"; fi
    fi
done < "$manifest"

echo "RENDER=done"

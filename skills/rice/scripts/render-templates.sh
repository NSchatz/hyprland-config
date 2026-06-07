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
# When the manifest's optional 5th column declares a "next-X" hint for entries
# that can't hot-reload (next-launch, next-lock, server-restart, restart),
# the script groups them and prints a footer like:
#     "3 surfaces apply on next launch: gtk3, qt6ct, hyprlock"
# so a `rice apply` against a fresh palette doesn't look half-applied.
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
    # If the output is a symlink (e.g. ~/.config/gtk-4.0/gtk.css pointing at a system GTK theme),
    # writing through it can fail with "Permission denied" (root-owned target) or clobber the theme.
    # Replace the symlink with a real, rice-owned file instead.
    [ -L "$out" ] && rm -f "$out"
    printf '%s' "$content" > "$out"
}

# Track surfaces whose effect lands on the NEXT-X event, not now. Keys are the
# hint values from the manifest's 5th column (next-launch, next-lock,
# server-restart, restart, ...); values are space-separated surface names.
declare -A NEXT_GROUPS

while IFS=$'\t' read -r name tmpl out rcmd next_hint; do
    case "$name" in ''|\#*) continue ;; esac
    tmpl="${tmpl/#\~/$HOME}"; out="${out/#\~/$HOME}"
    if [ ! -f "$tmpl" ]; then echo "SKIP $name (no template: $tmpl)"; continue; fi
    render_one "$tmpl" "$out"
    echo "RENDERED $name -> $out"
    if [ "$reload" -eq 1 ] && [ -n "${rcmd:-}" ]; then
        if eval "$rcmd" >/dev/null 2>&1; then echo "RELOADED $name"; else echo "RELOAD_SKIPPED $name"; fi
    fi
    # If the line declares a "next-X" hint (5th column), record it for the
    # post-render footer. Empty hint = either live-reload or no concept of
    # "next" (e.g. wofi/rofi pick up on file save).
    if [ -n "${next_hint:-}" ]; then
        NEXT_GROUPS["$next_hint"]+="$name "
    fi
done < "$manifest"

# Footer: one line per "next-X" group, friendlier wording per hint value.
hint_label() {
    case "$1" in
        next-launch)      echo "next launch" ;;
        next-lock)        echo "next lock" ;;
        server-restart)   echo "server restart" ;;
        restart)          echo "restart" ;;
        *)                echo "$1" ;;
    esac
}
for hint in "${!NEXT_GROUPS[@]}"; do
    names="${NEXT_GROUPS[$hint]% }"
    # shellcheck disable=SC2086
    set -- $names
    label="$(hint_label "$hint")"
    n=$#
    if [ "$n" -eq 1 ]; then
        echo "$n surface applies on $label: $names"
    else
        joined="$(echo "$names" | tr ' ' ',' | sed 's/,/, /g')"
        echo "$n surfaces apply on $label: $joined"
    fi
done

# Theme-restore-on-login script. The body is engine-specific so it can't be a static
# autostart line — it has to be regenerated whenever the wallpaper or engine choice
# changes. Caller passes RICE_THEMING_ENGINE=matugen|wallust|wallbash|none in env
# (autostart's exec-once is gated on the same value — see theming/engine.md and
# components/autostart/template.md). On 'none' or unset, skip emission.
write_restore_script() {
    local engine="${RICE_THEMING_ENGINE:-}" out reapply
    out="$HOME/.config/hypr/scripts/restore-theme.sh"
    case "$engine" in
        matugen)  reapply='matugen --prefer image image "$wp"' ;;
        wallust)  reapply='wallust run -s "$wp"' ;;
        wallbash) reapply="$HOME/.local/share/bin/swwwallpaper.sh -s \"\$wp\"" ;;
        ''|none)  return 0 ;;
        *) echo "RESTORE_SCRIPT_SKIPPED unknown engine: $engine" >&2; return 0 ;;
    esac
    mkdir -p "$(dirname "$out")"
    # Backslash-escape every $var we want literal in the output; ${reapply} expands.
    cat > "$out" <<EOF
#!/usr/bin/env bash
# Generated by hypr-rice. Re-applies the wallpaper and re-runs the theming engine on
# login so the desktop comes up matching the last rice state, not a stale palette.
set -e
wp=\$(awk -F= '\$1=="wallpaper"{print \$2}' "\$HOME/.config/hypr-rice/palette.conf")
[ -n "\$wp" ] && [ -f "\$wp" ] || exit 0
swww_bin=\$(command -v awww-daemon >/dev/null && echo awww || echo swww)
# Wait up to ~2s for the wallpaper daemon (autostart starts it on the line before
# this script): swww img against a not-yet-listening daemon errors out.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -x "\${swww_bin}-daemon" >/dev/null && break
  sleep 0.2
done
"\$swww_bin" img "\$wp" || true
${reapply}
EOF
    chmod 0755 "$out"
    echo "RESTORE_SCRIPT=$out (engine=$engine)"
}
write_restore_script

# Pre-baked lock-screen blur (ML4W pattern). When the user picked
# `lock_screen.background == "pre-baked-blur"` and RICE_LOCK_BLUR=pre-baked is set, we
# pre-blur the current wallpaper to ~/.cache/hypr-rice/lock-blur.png so hyprlock can
# render with blur_passes=0 (GPU cost paid once per wallpaper-pick, not every unlock).
# Soft-fails if ImageMagick isn't installed — caller can fall back to blurred-screenshot.
write_lock_blur() {
    [ "${RICE_LOCK_BLUR:-}" = "pre-baked" ] || return 0
    local wp out im
    wp="$(awk -F= '$1=="wallpaper"{print $2; exit}' "$palette" 2>/dev/null)"
    [ -n "$wp" ] && [ -f "$wp" ] || { echo "LOCK_BLUR_SKIPPED no wallpaper in $palette"; return 0; }
    out="$HOME/.cache/hypr-rice/lock-blur.png"
    if command -v magick >/dev/null 2>&1;   then im=magick
    elif command -v convert >/dev/null 2>&1; then im=convert
    else echo "LOCK_BLUR_SKIPPED ImageMagick not installed (install 'imagemagick'); hyprlock will see a missing file" >&2; return 0; fi
    mkdir -p "$(dirname "$out")"
    # 0x12 sigma matches hyprlock blur_passes=3,blur_size=7 perceptually. -resize caps work to
    # the largest panel width we expect; hyprlock renders to monitor anyway.
    if "$im" "$wp" -resize '2560x>' -blur 0x12 "$out" 2>/dev/null; then
        echo "LOCK_BLUR=$out ($im)"
    else
        echo "LOCK_BLUR_FAILED $im exited non-zero — keep the previous cache" >&2
    fi
}
write_lock_blur

echo "RENDER=done"

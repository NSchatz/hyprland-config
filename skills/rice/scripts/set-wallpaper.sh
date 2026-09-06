#!/usr/bin/env bash
# Set the desktop wallpaper via the available backend: swww > hyprpaper > swaybg.
# Usage: set-wallpaper.sh <image> [--dry-run]
# Persists hyprpaper.conf when hyprpaper is the backend. Does not touch the palette
# (the `rice wallpaper` flow records the wallpaper path in palette.conf).
#
# Maintains <config base>/hypr-rice/current-wallpaper as a symlink to the active image —
# the base being $XDG_CONFIG_HOME when it is absolute and $HOME/.config otherwise; see
# scripts/xdg-config.sh. $RICE_DIR and $HYPR_DIR still override outright —
# the stable pointer every wallpaper consumer (autostart wallpaper-daemon exec-once,
# hyprlock background, hypridle, widgets, dynamic-theme restore) references instead of
# a literal path captured at generation time. Re-theme / re-pick changes one symlink,
# every consumer follows.
set -uo pipefail

img="${1:-}"
[ -n "$img" ] || { echo "ERROR: usage: set-wallpaper.sh <image> [--dry-run]" >&2; exit 2; }
dry=0; [ "${2:-}" = "--dry-run" ] && dry=1
case "$img" in "~"*) img="${HOME}${img#\~}";; esac
[ -f "$img" ] || { echo "ERROR: no such image: $img" >&2; exit 2; }

# Resolve to an absolute path so the symlink survives a `cd` later.
case "$img" in /*) ;; *) img="$(cd "$(dirname "$img")" && pwd)/$(basename "$img")" ;; esac

run() { if [ "$dry" -eq 1 ]; then echo "DRY: $*"; else eval "$*"; fi; }

# Config-path library: next to this script when installed into $RICE_DIR, else in the plugin.
_xdg_lib=""
for _c in "$(cd "$(dirname "$0")" && pwd)/xdg-config.sh" \
          "$(cd "$(dirname "$0")" && pwd)/../../../scripts/xdg-config.sh" \
          "${CLAUDE_PLUGIN_ROOT:-}/scripts/xdg-config.sh"; do
    if [ -n "$_c" ] && [ -f "$_c" ]; then _xdg_lib="$_c"; break; fi
done
if [ -z "$_xdg_lib" ]; then
    echo "ERROR: the config-path library (xdg-config.sh) was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in the plugin - re-run rice-init.sh." >&2
    exit 2
fi
# shellcheck source=../../../scripts/xdg-config.sh
. "$_xdg_lib"

if ! xdg_config_target hypr-rice "${RICE_DIR:-}"; then
    echo "SET_WALLPAPER=refused-no-config-dir" >&2
    exit 2
fi
RICE_DIR="$XDG_CONFIG_TARGET"
hypr_dir="$(xdg_config_path hypr "${HYPR_DIR:-}")" || hypr_dir=""
link_current() {
    [ "$dry" -eq 1 ] && { echo "DRY: ln -sfn '$img' '$RICE_DIR/current-wallpaper'"; return; }
    mkdir -p "$RICE_DIR"
    ln -sfn "$img" "$RICE_DIR/current-wallpaper"
}

# swww, or its maintained fork awww (ships awww/awww-daemon binaries instead).
swww_bin=""; swww_daemon_bin=""
if command -v swww >/dev/null 2>&1; then swww_bin="swww"; swww_daemon_bin="swww-daemon"
elif command -v awww >/dev/null 2>&1; then swww_bin="awww"; swww_daemon_bin="awww-daemon"; fi
if [ -n "$swww_bin" ]; then
    if [ "$dry" -eq 0 ] && ! "$swww_bin" query >/dev/null 2>&1; then
        setsid "$swww_daemon_bin" >/dev/null 2>&1 &
        # poll for the daemon socket instead of a flat sleep (slow first start would race `img`)
        for _ in 1 2 3 4 5 6; do "$swww_bin" query >/dev/null 2>&1 && break; sleep 0.5; done
    fi
    run "$swww_bin img '$img' --transition-type any --transition-fps 60"
    link_current
    echo "SET_WALLPAPER=ok ($swww_bin)"
elif command -v hyprpaper >/dev/null 2>&1; then
    if [ "$dry" -eq 0 ]; then
        hyprctl hyprpaper preload "$img" >/dev/null 2>&1 || true
        hyprctl hyprpaper wallpaper ",$img" >/dev/null 2>&1 || true
        # No config dir, no persisted config: the live wallpaper is already set above, and a
        # write to an unknown location is worse than none.
        if [ -n "$hypr_dir" ]; then
            mkdir -p "$hypr_dir"
            printf 'preload = %s\nwallpaper = , %s\nsplash = false\n' "$img" "$img" > "$hypr_dir/hyprpaper.conf"
        else
            echo "HYPRPAPER_CONF_SKIPPED no config directory could be determined" >&2
        fi
    else
        echo "DRY: hyprctl hyprpaper preload '$img' && wallpaper ',$img' && write hyprpaper.conf"
    fi
    link_current
    echo "SET_WALLPAPER=ok (hyprpaper)"
elif command -v swaybg >/dev/null 2>&1; then
    run "pkill -x swaybg 2>/dev/null; setsid swaybg -i '$img' -m fill >/dev/null 2>&1 &"
    link_current
    echo "SET_WALLPAPER=ok (swaybg)"
else
    echo "SET_WALLPAPER=none (install swww or hyprpaper)" >&2
    exit 3
fi

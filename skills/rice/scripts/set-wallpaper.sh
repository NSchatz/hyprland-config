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
#
# Example:
#   set-wallpaper.sh ~/Pictures/wallpapers/forest.jpg
#
# Options: -h, --help, help, --dry-run
# Subcommands: none
#
# Exit codes:
#   0  ok: the wallpaper is set and current-wallpaper points at it
#   2  usage: no <image> argument was given
#   3  capability: no wallpaper backend is installed (swww, hyprpaper or swaybg), or the
#      config-path library is not beside this script
#   4  refusal: no config directory it will resolve, so the stable pointer every consumer
#      reads could not be written and nothing was set
#   5  input: the image it was given is not there
set -uo pipefail

case "${1:-}" in   # [cli-parser]
    -h|--help|help)
        sed -n '2,${/^#/!q;s/^#\{1,2\} \{0,1\}//p}' "$0"
        exit 0 ;;   # rc=ok
    -*)
        echo "ERROR: unknown option '$1' (usage: set-wallpaper.sh <image> [--dry-run])" >&2
        exit 2 ;;   # rc=usage
esac

img="${1:-}"
[ -n "$img" ] || { echo "ERROR: usage: set-wallpaper.sh <image> [--dry-run]" >&2; exit 2; }   # rc=usage
dry=0
case "${2:-}" in   # [cli-parser]
    --dry-run) dry=1 ;;
    -*)
        echo "ERROR: unknown option '$2' (usage: set-wallpaper.sh <image> [--dry-run])" >&2
        exit 2 ;;   # rc=usage
esac
case "$img" in "~"*) img="${HOME}${img#\~}";; esac
[ -f "$img" ] || { echo "ERROR: no such image: $img" >&2; exit 5; }   # rc=input

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
    exit 3   # rc=capability
fi
# shellcheck source=../../../scripts/xdg-config.sh
. "$_xdg_lib"

if ! xdg_config_target hypr-rice "${RICE_DIR:-}"; then
    echo "SET_WALLPAPER=refused-no-config-dir" >&2
    exit 4   # rc=refusal
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
    exit 3   # rc=capability
fi
exit 0   # rc=ok

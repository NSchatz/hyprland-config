#!/usr/bin/env bash
# Apply the staged config into the guest's home, and optionally reload what is already running.
#
# This runs in TWO situations and must behave identically in both, which is why it is one file
# rather than two copies: at boot, before the compositor exists, and on every `rice preview
# reload` while you iterate. If the boot path and the reload path copied different things, you
# would be looking at one config and applying another.
#
# THE STAGING CONTRACT
#   <staging>/*.conf, *.lua   -> ~/.config/hypr/     the compositor's own files
#   <staging>/_shell/<app>/   -> ~/.config/<app>/    app configs
#   <staging>/_home/**        -> ~/**                anything else, by relative path
#
# `_home/` is the general case and is applied LAST so it wins. It is what lets `~/.gtkrc-2.0`,
# `~/.zshrc`, `~/.config/hypr/scripts/*` and the rice engine's own files travel without needing
# a new special case here for each one.
#
# Usage: guest-apply.sh [--reload]
set -uo pipefail

STAGING="${PREVIEW_STAGING:-/mnt/staging}"
RELOAD=0
[ "${1:-}" = "--reload" ] && RELOAD=1

if ! mountpoint -q "$STAGING"; then
    echo "APPLY=failed-no-staging"
    exit 2
fi

# ---------------------------------------------------------------------------------------
# Copy, in contract order.
# ---------------------------------------------------------------------------------------
mkdir -p "$HOME/.config/hypr"
n=0
for f in "$STAGING"/*.conf "$STAGING"/*.lua; do
    [ -e "$f" ] || continue
    cp -f "$f" "$HOME/.config/hypr/" && n=$((n + 1))
done
echo "APPLIED_hypr=$n"

n=0
for d in "$STAGING"/_shell/*/; do
    [ -d "$d" ] || continue
    app="$(basename "$d")"
    mkdir -p "$HOME/.config/$app"
    cp -rf "$d". "$HOME/.config/$app/" && n=$((n + 1))
done
echo "APPLIED_shell=$n"

if [ -d "$STAGING/_home" ]; then
    cp -a "$STAGING/_home/." "$HOME/" 2>/dev/null
    # The source is a read-only share; the guest owns its home and must be able to edit what
    # it was handed, or the next reload cannot overwrite it.
    chmod -R u+w "$HOME" 2>/dev/null
    echo "APPLIED_home=$(find "$STAGING/_home" -type f 2>/dev/null | wc -l)"
else
    echo "APPLIED_home=0"
fi

[ "$RELOAD" = 1 ] || { echo "APPLY=ok"; exit 0; }

# ---------------------------------------------------------------------------------------
# Reload what is running. Per-surface, because Hyprland's own reload does not reach the
# companion daemons: `hyprctl reload` never re-reads hyprlock, hypridle or hyprpaper, and a
# bar or a notification daemon each need their own signal.
# ---------------------------------------------------------------------------------------
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)}"

if hyprctl reload >/dev/null 2>&1; then
    errs="$(hyprctl configerrors 2>/dev/null | sed '/^[[:space:]]*$/d' | grep -v '^no errors$')"
    if [ -n "$errs" ]; then
        echo "RELOAD_hyprland=errors"
        printf 'CONFIG_ERROR=%s\n' "$errs"
    else
        echo "RELOAD_hyprland=ok"
    fi
else
    echo "RELOAD_hyprland=skipped"
fi

# Bars. SIGUSR2 re-reads the config; structural keys (position, layer, a dual-bar array) need a
# restart, which is why the marker distinguishes them.
if pgrep -x waybar >/dev/null 2>&1; then
    pkill -SIGUSR2 -x waybar && echo "RELOAD_waybar=ok" || echo "RELOAD_waybar=failed"
fi
for bar in ironbar hyprpanel; do
    pgrep -x "$bar" >/dev/null 2>&1 && { pkill -x "$bar"; (setsid "$bar" >/dev/null 2>&1 &); echo "RELOAD_$bar=restarted"; }
done

# Notification daemons.
if pgrep -x mako >/dev/null 2>&1; then
    makoctl reload >/dev/null 2>&1 && echo "RELOAD_mako=ok" || echo "RELOAD_mako=failed"
fi
if pgrep -x dunst >/dev/null 2>&1; then
    dunstctl reload >/dev/null 2>&1 && echo "RELOAD_dunst=ok" \
        || { pkill -x dunst; (setsid dunst >/dev/null 2>&1 &); echo "RELOAD_dunst=restarted"; }
fi
if pgrep -x swaync >/dev/null 2>&1; then
    swaync-client -rs >/dev/null 2>&1 && echo "RELOAD_swaync=ok" || echo "RELOAD_swaync=failed"
fi

# Terminals. kitty re-reads on SIGUSR1; alacritty and wezterm watch their own file; foot has no
# config reload at all and needs a restart, so it is reported rather than silently missed.
pgrep -x kitty >/dev/null 2>&1 && { pkill -SIGUSR1 -x kitty; echo "RELOAD_kitty=ok"; }
pgrep -x foot  >/dev/null 2>&1 && echo "RELOAD_foot=needs-restart"

# Wallpaper.
if pgrep -x hyprpaper >/dev/null 2>&1; then
    hyprctl hyprpaper reload >/dev/null 2>&1 && echo "RELOAD_hyprpaper=ok" \
        || echo "RELOAD_hyprpaper=failed"
fi

# Launchers have no reload mechanism of any kind: no daemon, no signal, no IPC. Saying so is
# better than pretending, because the next launch is when a change actually appears.
for l in wofi rofi fuzzel tofi walker; do
    [ -e "$HOME/.config/$l" ] && { echo "RELOAD_$l=next-launch"; break; }
done

# The theme engine, if the config installed one: this is what repaints GTK, Qt, the cursor and
# the icon theme from the palette.
if [ -x "$HOME/.config/hypr-rice/rice" ]; then
    bash "$HOME/.config/hypr-rice/rice" apply >/dev/null 2>&1 \
        && echo "RELOAD_rice_engine=ok" || echo "RELOAD_rice_engine=failed"
fi

echo "APPLY=ok"

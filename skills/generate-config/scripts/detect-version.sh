#!/usr/bin/env bash
# Detect the installed Hyprland version.
# Prints: HYPR_VERSION=<x.y.z>  (or HYPR_VERSION=unknown)
# Also prints HYPR_SOURCE=<how it was detected> for context.
set -uo pipefail

version=""
source=""

# Preferred: query a running instance.
if command -v hyprctl >/dev/null 2>&1; then
    # `hyprctl version` output contains e.g. "Hyprland 0.45.2 built from branch ..."
    raw="$(hyprctl version 2>/dev/null | head -n 20)"
    version="$(printf '%s\n' "$raw" | grep -oiE 'v?[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 | sed 's/^v//')"
    [ -n "$version" ] && source="hyprctl"
fi

# Fallback: the binary itself (works without a running session).
if [ -z "$version" ] && command -v Hyprland >/dev/null 2>&1; then
    raw="$(Hyprland --version 2>/dev/null | head -n 20)"
    version="$(printf '%s\n' "$raw" | grep -oiE 'v?[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 | sed 's/^v//')"
    [ -n "$version" ] && source="Hyprland --version"
fi

if [ -n "$version" ]; then
    echo "HYPR_VERSION=${version}"
    echo "HYPR_SOURCE=${source}"
else
    echo "HYPR_VERSION=unknown"
    echo "HYPR_SOURCE=none (hyprctl/Hyprland not found — assume latest stable syntax)"
fi

# Probe common ecosystem packages so the interview can bias toward what's installed.
# Reports HAVE_<tool>=1 (present) or MISSING_<tool>=1 (absent). Maps package name -> a
# representative binary where they differ. Detection only — installs nothing.
have_pkg() {
    # $1 = label, $2 = binary to look for (defaults to $1), $3 = pacman pkg (optional)
    local label="$1" bin="${2:-$1}" pkg="${3:-}"
    if command -v "$bin" >/dev/null 2>&1; then
        echo "HAVE_${label}=1"; return
    fi
    if [ -n "$pkg" ] && command -v pacman >/dev/null 2>&1 && pacman -Qq "$pkg" >/dev/null 2>&1; then
        echo "HAVE_${label}=1"; return
    fi
    echo "MISSING_${label}=1"
}

# label                binary                  pacman-pkg (if different / no binary)
have_pkg hyprpaper      hyprpaper
have_pkg hyprlock       hyprlock
have_pkg hypridle       hypridle
have_pkg hyprpicker     hyprpicker
have_pkg hyprshot       hyprshot
have_pkg hyprsunset     hyprsunset
have_pkg hyprpolkitagent ""                    hyprpolkitagent
have_pkg portal_hyprland ""                    xdg-desktop-portal-hyprland
have_pkg portal_gtk     ""                     xdg-desktop-portal-gtk
have_pkg waybar         waybar
have_pkg hyprpanel      hyprpanel
have_pkg wofi           wofi
have_pkg rofi           rofi
have_pkg fuzzel         fuzzel
have_pkg mako           mako
have_pkg dunst          dunst
have_pkg swaync         swaync
have_pkg swww           swww-daemon             swww
have_pkg grimblast      grimblast
have_pkg grim           grim
have_pkg slurp          slurp
have_pkg satty          satty
have_pkg cliphist       cliphist
have_pkg wl_clipboard   wl-copy                 wl-clipboard
have_pkg wlogout        wlogout
have_pkg swayosd        swayosd-server          swayosd
have_pkg brightnessctl  brightnessctl
have_pkg playerctl      playerctl
have_pkg nm_applet      nm-applet               network-manager-applet
have_pkg blueman        blueman-applet          blueman
have_pkg qt6ct          qt6ct
have_pkg nwg_look       nwg-look

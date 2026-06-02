#!/usr/bin/env bash
# Probe theming/shell tooling and the current desktop appearance so the rice /
# shell-config skills can bias toward what's installed and read the current state.
# Detection only — changes nothing.
#
# Prints HAVE_<tool>=1 / MISSING_<tool>=1 lines, then CURRENT_* lines for gsettings values.
set -uo pipefail

have() { # $1 label, $2 binary (default label), $3 pacman pkg fallback
    local label="$1" bin="${2:-$1}" pkg="${3:-}"
    if command -v "$bin" >/dev/null 2>&1; then echo "HAVE_${label}=1"; return; fi
    if [ -n "$pkg" ] && command -v pacman >/dev/null 2>&1 && pacman -Qq "$pkg" >/dev/null 2>&1; then
        echo "HAVE_${label}=1"; return
    fi
    echo "MISSING_${label}=1"
}

# Palette generators
have matugen
have wallust
have pywal     wal      python-pywal16
# Shells + prompt + CLI niceties
have bash
have zsh
have fish
have starship
have eza
have bat
have zoxide
have fzf
have atuin
# Theming surfaces / tools
have nwg_look  nwg-look
have gsettings
have qt6ct
have qt5ct
have kvantum   kvantummanager  kvantum
have kitty
have alacritty
have foot
# Bars / launchers / notifiers (for desktop-shell)
have waybar
have hyprpanel
have wofi
have rofi
have mako
have dunst
have swaync
# System-info fetch tools (for shell-config startup greeting)
have fastfetch
have neofetch

# Current login shell
echo "CURRENT_SHELL=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)"

# Current GTK/cursor/icon/font appearance (read-only)
if command -v gsettings >/dev/null 2>&1; then
    for key in gtk-theme color-scheme icon-theme cursor-theme cursor-size font-name monospace-font-name; do
        val="$(gsettings get org.gnome.desktop.interface "$key" 2>/dev/null)"
        [ -n "$val" ] && echo "CURRENT_$(printf '%s' "$key" | tr 'a-z-' 'A-Z_')=${val}"
    done
fi

# Installed fonts — for presenting font choices. Reports whether a Nerd Font exists (needed for
# bar/fetch/prompt glyphs) and lists base monospace/Nerd and sans families actually installed.
if command -v fc-list >/dev/null 2>&1; then
    fams="$(fc-list : family 2>/dev/null | tr ',' '\n' | sed 's/^[ \t]*//;s/[ \t]*$//' | sort -u)"
    # grep -c consumes all input (no early exit) so pipefail can't trip on SIGPIPE
    if [ "$(printf '%s\n' "$fams" | grep -ic 'nerd font')" -gt 0 ]; then
        echo "HAVE_NERD_FONT=1"
    else
        echo "MISSING_NERD_FONT=1"
    fi
    # Base mono/Nerd families only — drop weight/abbrev variants (NF/NFM/Bold/Light/…)
    printf '%s\n' "$fams" \
        | grep -iE '(nerd font|nerd font mono|nerd font propo)$|^(jetbrains mono|fira code|firacode|cascadia code|caskaydia cove|hack|iosevka|terminus|adwaita mono|dejavu sans mono)$' \
        | grep -ivE 'NF$|NFM|NFP|extrabold|extralight|semibold|bold|light|medium|thin|black|italic|condensed' \
        | sort -u | sed 's/^/FONT_MONO=/' | head -15
    printf '%s\n' "$fams" \
        | grep -iE '^(Inter|Cantarell|Noto Sans|Roboto|Adwaita Sans|Ubuntu|DejaVu Sans|Fira Sans|Open Sans)$' \
        | sort -u | sed 's/^/FONT_SANS=/' | head -10
fi

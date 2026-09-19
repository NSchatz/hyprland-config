#!/usr/bin/env bash
# Searchable theme switcher — lists the saved rice profiles in a menu and applies the pick.
# Leans entirely on the rice engine: `rice themes` to list, `rice theme <name>` to apply
# (so the whole desktop re-themes coherently). No hardcoded theme names.
# Deps: the rice CLI (<config base>/hypr-rice/rice); one of rofi/wofi/fuzzel.
# This script is dropped into the user's own hypr config dir by the component writer, not
# installed beside the engine, so it cannot source scripts/xdg-config.sh. It restates that
# file's rule - and only that rule - inline: an explicit override wins, else an ABSOLUTE
# XDG_CONFIG_HOME, else $HOME/.config. Keep the two in step.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/desktop/helpers.py, action: theme-switch). Installed
# beside the engine by rice-init.sh, so it keeps working with the plugin removed.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
libdir=""
for c in "$here" "$here/../../../../scripts" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -f "$c/ricelib/__init__.py" ]; then libdir="$(cd "$c" && pwd)"; break; fi
done
if [ -z "$libdir" ]; then
    command -v notify-send >/dev/null 2>&1 && notify-send "rice" "ricelib not found - re-run rice-init.sh"
    echo "ERROR: the ricelib package was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in \$RICE_DIR." >&2
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    command -v notify-send >/dev/null 2>&1 && notify-send "rice" "python3 is not installed"
    echo "ERROR: python3 is required and is not installed (sudo pacman -S --needed python)." >&2
    exit 2
fi
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.desktop.helpers theme-switch "$@"

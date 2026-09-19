#!/usr/bin/env bash
# Make a timestamped backup of the Hyprland config dir before editing it.
# Prints: TARGET=<dir> and BACKUP=<path>  (or BACKUP=none if there's nothing to back up).
#
# Env:
#   HYPR_DIR  the config dir  (explicit override; wins over XDG_CONFIG_HOME)
# Otherwise the dir is $XDG_CONFIG_HOME/hypr when XDG_CONFIG_HOME is an absolute path,
# and $HOME/.config/hypr when it is unset, empty or relative - see scripts/xdg-config.sh,
# which is the one place that decision is made.
#
# Exit: 0 backed up (or nothing to back up), 2 no config directory could be determined,
#       4 the backup could not be written; nothing was changed.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/backupconfig.py).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
libdir=""
for c in "$here" "$here/../../../scripts" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -f "$c/ricelib/__init__.py" ]; then libdir="$(cd "$c" && pwd)"; break; fi
done
if [ -z "$libdir" ]; then
    echo "ERROR: the ricelib package was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in \$RICE_DIR." >&2
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required and is not installed (sudo pacman -S --needed python)." >&2
    exit 2
fi
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.backupconfig "$@"

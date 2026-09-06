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
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
_xdg_lib=""
for _c in "$here/xdg-config.sh" \
          "$here/../../../scripts/xdg-config.sh" \
          "${CLAUDE_PLUGIN_ROOT:-}/scripts/xdg-config.sh"; do
    if [ -n "$_c" ] && [ -f "$_c" ]; then _xdg_lib="$_c"; break; fi
done
if [ -z "$_xdg_lib" ]; then
    echo "ERROR: the config-path library (scripts/xdg-config.sh) was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in the plugin. Refusing to guess where your config lives." >&2
    exit 2
fi
# shellcheck source=../../../scripts/xdg-config.sh
. "$_xdg_lib"

if ! xdg_config_target hypr "${HYPR_DIR:-}"; then
    echo "BACKUP=none (no config directory could be determined)"
    exit 2
fi
target="$XDG_CONFIG_TARGET"

echo "TARGET=${target}"

if [ -d "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="${target}.bak.${ts}"
    # Report the failure against the resolved path instead of dying with a bare `cp`
    # error - and never fall back to some other directory.
    if ! cp -a "$target" "$backup" 2>/dev/null; then
        echo "ERROR: could not back up '$target' to '$backup'; nothing was changed." >&2
        echo "BACKUP=failed (${backup} could not be written)"
        exit 4
    fi
    echo "BACKUP=${backup}"
else
    echo "BACKUP=none (no existing config to back up)"
fi

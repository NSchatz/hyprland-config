#!/usr/bin/env bash
# Back up any existing Hyprland config, then install a freshly generated one.
#
# Usage:   install-config.sh <staging-dir>
#   <staging-dir>  Directory containing the generated config files: either a
#                  hyprlang set (a main `hyprland.conf` plus other `*.conf`) or a
#                  lua set (a main `hyprland.lua` plus other `*.lua`).
#
# Behavior:
#   - Target dir is $HYPR_DIR when it is set; otherwise $XDG_CONFIG_HOME/hypr when
#     XDG_CONFIG_HOME is an absolute path, otherwise $HOME/.config/hypr. A relative
#     XDG_CONFIG_HOME is invalid and is ignored, loudly. See scripts/xdg-config.sh -
#     that is the one place this plugin decides where configuration lives.
#   - REFUSES to install a hyprlang `.conf` into a target that already holds a
#     `hyprland.lua`. Since Hyprland 0.55 the lua file is loaded INSTEAD of the
#     `.conf`, so that install would report success for a change the compositor
#     never reads. This check runs FIRST and nothing is touched when it fires.
#   - REFUSES a staging dir that mixes the two languages - a `hyprland.lua` beside
#     a `hyprland.conf`, or either main config beside companions in the other
#     language. Only one language's files would be installed; the rest would be
#     dropped without a word.
#   - REFUSES, before taking a backup or writing anything, when the target exists
#     but cannot be written to; the target is left exactly as it was.
#   - If the target exists and is non-empty, it is copied to
#     <target>.bak.<YYYYmmdd-HHMMSS> before anything is changed. An absent or
#     empty target gets no backup, and none is claimed.
#   - The generated config files are then copied into the target.
#
# Prints a summary the caller parses:
#   BACKUP=<path> | BACKUP=none (no existing config to back up)
#   CONFIG_LANGUAGE=<lua|hyprlang>
#   CONFIG_LANGUAGE_RANGE=<the Hyprland versions that language is valid for>
#   INSTALLED=<file>          (one line per installed file)
#   PROVENANCE=added to <file> (only when the staged config carried none)
#   TARGET=<dir>
#   DONE=ok
#
# Exit: 0 installed, 2 bad usage / unusable staging dir / no config directory could be
#         determined,
#       3 refused (the target is shadowed by a hyprland.lua, or staging is
#         ambiguous/mixed because it holds both languages),
#       4 refused (the target exists but cannot be written to).
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/installconfig.py). This file locates
# the package and hands off; the name is the interface every caller, doc and test uses.
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.installconfig "$@"

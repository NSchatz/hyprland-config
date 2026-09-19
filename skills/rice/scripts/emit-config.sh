#!/usr/bin/env bash
# Emit a baseline Hyprland configuration IN THE LANGUAGE THE COMPOSITOR READS.
#
# Since Hyprland 0.55 the documented config language is lua, and a `hyprland.lua`
# is loaded INSTEAD of `hyprland.conf`. This script is the emitter pair: one
# hyprlang writer (what the plugin always had) and one lua writer, picked by
# `config-language.sh` from the detected version rather than assumed.
#
# Usage: emit-config.sh <staging-dir>
#   <staging-dir>  Created if absent. The main config is written into it.
#
# Env:
#   HYPR_VERSION       skip detection and resolve the language from this version
#   HYPR_CONFIG_LANG   explicit language choice (lua|hyprlang)
#   BARE_TERMINAL      $terminal value (default: kitty)
#   BARE_MENU          $menu value     (default: wofi --show drun)
#
# Output:
#   HYPR_VERSION=<x.y.z|unknown>
#   CONFIG_LANGUAGE=<lua|hyprlang>
#   CONFIG_LANGUAGE_SOURCE=<detected|explicit>
#   CONFIG_LANGUAGE_RANGE=<versions that language is valid for>
#   EMITTED=<path of the file written>
#   DONE=ok
#
# Exit: 0 emitted, 2 bad usage, 3 the version could not be detected and no
#       explicit language choice was supplied (nothing is written).
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/emitconfig.py). This file locates
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.emitconfig "$@"

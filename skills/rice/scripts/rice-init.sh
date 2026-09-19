#!/usr/bin/env bash
# Scaffold a self-contained rice engine into the rice state directory ($RICE_DIR, default
# <config base>/hypr-rice - see Env: below):
#   - templates/        : the .tmpl color templates (copied from the plugin; user-editable)
#   - templates.list    : the render manifest (name <tab> template <tab> output <tab> reload)
#   - render-templates.sh + rice : the engine + CLI (so it runs without the plugin)
#   - palette.conf      : seeded with Catppuccin Mocha if absent (change via rice)
#   - profiles/         : saved theme profiles (used by rice)
# Idempotent: never clobbers an existing palette.conf, templates.list, or user-edited templates
# unless --force is passed.
#
# Usage: rice-init.sh [--force]
#
# Env:
#   RICE_DIR  where the engine is scaffolded (explicit override; wins over XDG_CONFIG_HOME).
#             Otherwise <config base>/hypr-rice, where the base is $XDG_CONFIG_HOME when it
#             is an absolute path and $HOME/.config otherwise. scripts/xdg-config.sh makes
#             that decision for the whole plugin - scaffolding into one directory while the
#             render engine reads another is exactly the split it exists to prevent.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/riceinit.py). This file locates
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.riceinit "$@"

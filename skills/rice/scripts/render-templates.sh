#!/usr/bin/env bash
# Rice render engine: read the central palette, substitute {{key}} placeholders in each
# registered template, write the output file, and run the app's reload hook.
#
# This is the heart of the rice engine and is also installed into $RICE_DIR (the rice state
# directory) so the `rice` CLI can run it with no dependency on the plugin.
#
# Usage: render-templates.sh [--no-reload] [palette-file] [manifest-file]
#   palette  default: $RICE_DIR/palette.conf   (KEY=hex lines, no leading #)
#   manifest default: $RICE_DIR/templates.list (TAB-separated: name <tab> template <tab> output <tab> reload-cmd)
#
# Placeholders in templates: {{accent}}, {{bg}}, {{color0}}… → the bare hex from the palette.
# Templates add their own '#' / 'rgb(...)' wrappers (e.g. `#{{accent}}`, `rgb({{bg}})`).
#
# Output: RENDERED <name> -> <output> / RELOADED <name> / RELOAD_SKIPPED <name> / RENDER=done
# When the manifest's optional 5th column declares a "next-X" hint for entries
# that can't hot-reload (next-launch, next-lock, server-restart, restart),
# the script groups them and prints a footer like:
#     "3 surfaces apply on next launch: gtk3, qt6ct, hyprlock"
# so a `rice apply` against a fresh palette doesn't look half-applied.
#
# Every output this pass writes is backed up first and enrolled in ONE restore point (one apply
# id shared by every file of the apply), so `rice restore <apply-id>` puts the whole set back -
# including the files this apply created, which it removes again. A surface whose backup cannot
# be written is NOT rendered: it is skipped with RENDER_SKIPPED and the rest of the manifest
# carries on. Set RICE_APPLY_ID in the environment to share one restore point across every stage
# of one apply (render pass, browser theming, shell-rc edit); leave it unset and this pass mints
# its own and prints it as RESTORE_POINT=.
#
# Where things land: $RICE_DIR when it is set, else <config base>/hypr-rice; and a manifest
# output column reading `~/.config/<app>/...` resolves under that same <config base>. The base
# is $XDG_CONFIG_HOME when it is an absolute path and $HOME/.config otherwise - one decision,
# made in scripts/xdg-config.sh. The lock-screen blur cache stays under $HOME/.cache: that is
# XDG_CACHE_HOME's base directory, not this one's.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/rendertemplates.py). This file locates
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.rendertemplates "$@"

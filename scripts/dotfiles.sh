#!/usr/bin/env bash
# Version-control the user's Hyprland / desktop configs in git. Three methods:
#   bare    : bare git repo tracking files in place in $HOME (no symlinks)  [recommended]
#   stow     : GNU Stow symlink farm from a ~/dotfiles repo
#   chezmoi  : chezmoi-managed source repo
#
# Usage:
#   dotfiles.sh init <bare|stow|chezmoi> [remote-url]
#   dotfiles.sh add <path> [path...]      # start tracking path(s)
#   dotfiles.sh add-defaults              # track the common Hyprland/desktop config paths that exist
#   dotfiles.sh commit "<message>"        # stage tracked changes + commit
#   dotfiles.sh push                      # push to origin
#   dotfiles.sh status                    # short status
#   dotfiles.sh method                    # print the configured method
#
# Method + repo location recorded in <config base>/hypr-rice/dotfiles.conf, the base being
# $XDG_CONFIG_HOME when it is an absolute path and $HOME/.config otherwise - the same one
# decision every other script here makes (scripts/xdg-config.sh).
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/dotfiles.py).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
libdir=""
for c in "$here" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -f "$c/ricelib/dotfiles.py" ]; then libdir="$c"; break; fi
done
if [ -z "$libdir" ]; then
    echo "ERROR: the ricelib package was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in \$RICE_DIR." >&2
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required and is not installed (sudo pacman -S --needed python)." >&2
    exit 2
fi
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.dotfiles "$@"

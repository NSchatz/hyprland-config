#!/usr/bin/env bash
# Reset the Hyprland config dir to a minimal, working "bare bones" config. That dir is
# $HYPR_DIR when set, else $XDG_CONFIG_HOME/hypr when XDG_CONFIG_HOME is an absolute path,
# else $HOME/.config/hypr (scripts/xdg-config.sh).
#
# Backs up the ENTIRE existing config (timestamped), WIPES the directory, writes a
# single minimal config IN THE LANGUAGE THIS HYPRLAND READS (hyprland.lua on 0.55+,
# hyprland.conf below that - see `config-language.sh`), live-tests it (hyprctl
# reload + configerrors), and AUTO-ROLLS-BACK to the backup if it somehow fails to
# load.
#
# Usage: reset-config.sh
# Env:
#   HYPR_DIR         target dir          (explicit override; wins over XDG_CONFIG_HOME)
#                    With no HYPR_DIR the target is $XDG_CONFIG_HOME/hypr when
#                    XDG_CONFIG_HOME is an absolute path and $HOME/.config/hypr when it
#                    is unset, empty or relative. That decision is made once, in
#                    scripts/xdg-config.sh, and shared with every script here - this
#                    script WIPES its target, so it must never resolve a different
#                    directory from the one backup-config.sh copied.
#   HYPR_VERSION     skip detection and resolve the language from this version
#   HYPR_CONFIG_LANG explicit language choice (lua|hyprlang)
#   BARE_TERMINAL    $terminal value     (default: kitty)
#   BARE_MENU        $menu value         (default: wofi --show drun)
#
# Unlike install-config.sh (additive per-file), this is a CLEAN WIPE - after it runs
# the target contains only the bare config. The full backup preserves prior state.
# The config is generated BEFORE the wipe, so a run that cannot pick a language
# leaves the existing config completely untouched.
#
# Output ends with one of:
#   RESET=ok                  wiped, wrote the bare config, verified clean
#   RESET=installed-untested  wrote the bare config, but no running Hyprland to test against
#   RESET=rolled-back         bare config errored (unexpected); previous config restored
#   RESET=errors-no-backup    bare config errored and there was no backup to restore
#   RESET=refused-undecided   the Hyprland version could not be detected and no
#                             language was chosen; NOTHING was changed
#   RESET=refused-no-config-dir      no config directory could be determined (no HYPR_DIR,
#                             no absolute XDG_CONFIG_HOME, no HOME); NOTHING was changed
#   RESET=refused-target-not-writable  the resolved config dir exists but cannot be
#                             written by this user; NOTHING was changed and no other
#                             directory was tried
#
# Exit: 0 ok / untested, 1 errors, 2 could not generate, 3 no language chosen,
#       4 refused (no config directory, or the resolved one cannot be written).
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/resetconfig.py). This file locates
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.resetconfig "$@"

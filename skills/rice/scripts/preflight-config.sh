#!/usr/bin/env bash
# Verify a STAGED Hyprland config with the compositor's own offline parser, BEFORE
# a byte of it reaches the user's machine.
#
# Usage: preflight-config.sh <staging-dir>
#   <staging-dir>  Directory of generated config files: a hyprlang set (a main
#                  `hyprland.conf` plus other `*.conf`) or a lua set (a main
#                  `hyprland.lua` plus other `*.lua`). Same input as
#                  install-config.sh.
#
# This NEVER reads, and never depends on, the install target. The staged set is
# copied into a throwaway sandbox whose HOME is the sandbox, so the
# `source = ~/.config/hypr/<file>` lines the generator writes resolve to the
# STAGED companions rather than to whatever is installed on the machine. The
# verdict is therefore about the files in <staging-dir> and nothing else.
#
# Output (KEY=value lines, the convention every script here follows):
#   PREFLIGHT_BIN=<path of the compositor binary used>
#   PREFLIGHT_MAIN=<staged main config>
#   STAGED=<file>                 (one line per staged file that was checked)
#   PREFLIGHT_ERROR=<message>     (one line per parse error, naming STAGED paths)
#   PREFLIGHT_REASON=<slug>       (why it could not check / could not verify)
#   PREFLIGHT=<ok|errors|unverified|uncheckable>
#
# The four verdicts, and what each one means for the caller:
#   ok           the compositor parsed the staged set and found no errors.
#   errors       the compositor parsed the staged set and REPORTED ERRORS.
#                Do not install.
#   unverified   no compositor binary offering the offline check is on this host,
#                so nothing was proven either way. NOT the same as `ok`: the
#                caller carries on to install + live-test + rollback.
#   uncheckable  the check could not be run against the staged files at all - the
#                staged main config is missing/unreadable/ambiguous, or the
#                compositor rejected the invocation before parsing anything.
#                Refuse: a config nobody could check is not a config anyone
#                should install.
#
# Exit: 0 ok, 1 errors, 2 unverified, 3 uncheckable, 4 bad usage.
#
# The contract this relies on is MEASURED, not assumed - see
# `tests/integration/offline-check-contract.md` for the exact invocations, exit
# codes and output shapes, recorded against Hyprland 0.56.2 in the repo's own
# integration container.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/preflightconfig.py). This file locates
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.preflightconfig "$@"

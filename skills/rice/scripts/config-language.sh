#!/usr/bin/env bash
# Resolve WHICH CONFIG LANGUAGE this machine's Hyprland actually reads, and the
# Hyprland version range that language is valid for.
#
# Since Hyprland 0.55 hyprlang is deprecated in favour of lua, and a
# `hyprland.lua` sitting in the config dir is loaded INSTEAD of `hyprland.conf`.
# So "which language do we emit" is a version cliff like every other cliff in
# `references/_shared/version-matrix.md` - and it is NOT guessable. When the
# version cannot be detected this script refuses to pick one and asks the caller.
#
# Usage:
#   config-language.sh                    resolve from $HYPR_VERSION or detect-version.sh
#   config-language.sh --language lua     force the language (the explicit choice)
#   config-language.sh --version 0.56.2   resolve from a version, skipping detection
#   config-language.sh --range <lang>     print only that language's version range
#
# Env:
#   HYPR_VERSION       use this version instead of running detect-version.sh
#                      (x.y[.z], or the literal `unknown`)
#   HYPR_CONFIG_LANG   the explicit choice (lua|hyprlang); same as --language
#
# Output (KEY=value lines, the convention every script here follows):
#   HYPR_VERSION=<x.y.z|unknown>
#   CONFIG_LANGUAGE=<lua|hyprlang>
#   CONFIG_LANGUAGE_SOURCE=<detected|explicit>
#   CONFIG_FILE=<hyprland.lua|hyprland.conf>
#   CONFIG_LANGUAGE_RANGE=<the Hyprland versions that language is valid for>
#
# When the version cannot be detected AND no explicit choice was supplied, it
# reports what it can emit and stops instead of assuming:
#   CONFIG_LANGUAGE=undecided
#   EMITTABLE_LANGUAGES=lua hyprlang
#   LANGUAGE_OPTION=lua <range>
#   LANGUAGE_OPTION=hyprlang <range>
#   ERROR: ... requires an explicit choice ...
#
# Exit: 0 resolved, 2 bad usage, 3 undetected version and no explicit choice.
#
# Sourcing this file defines the helpers WITHOUT running the CLI, so the other
# scripts share one definition of the cliff, the file names and the ranges.

# The cliff: 0.55 is where the documented config language becomes lua.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/configlang.py). This file locates
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.configlang "$@"

#!/usr/bin/env bash
# Does this GENERATED config carry a key the reference layer documents as
# REMOVED at the target version?
#
# A key removed upstream is not a warning on the machine it lands on: it is a
# hard parse error that fails the whole reload. This check is static, offline,
# and reads the same version-cliff ledger the currency check reads - the
# `Removed keys` table of `references/_shared/version-matrix.md`. It needs NO
# Hyprland binary and NO running compositor, so it reaches a verdict on hosts
# where `preflight-config.sh` can only say `unverified` and `verify-config.sh`
# can only say `skipped`. It sits BESIDE those, never instead of them.
#
# Usage:
#   validate-removed-keys.sh <staging-dir> [--version VER] [--ledger FILE] [--root DIR]
#   validate-removed-keys.sh --supported-targets [--ledger FILE] [--root DIR]
#
#   <staging-dir>        the generated set (same input as install-config.sh)
#   --version VER        the TARGET Hyprland version. Overrides detection.
#   --supported-targets  print every version the plugin claims to support, one
#                        per line, enumerated from the ledger.
#
# Env: HYPR_VERSION  same as --version (and what detect-version.sh emits).
#
# Output (KEY=value lines, the convention every script here follows):
#   REMOVED_KEYS_LEDGER=<path>
#   REMOVED_KEYS_TARGET=<x.y.z|unknown>
#   REMOVED_KEYS_TARGET_SOURCE=<supplied|detected|none>
#   REMOVED_KEYS_RULES=<n>            removed-key rows read from the ledger
#   REMOVED_KEYS_CHECKED=<file>       one per staged file actually scanned
#   REMOVED_KEY=<key> | <file>:<line> | removed at <ver> | use <replacement>
#   REMOVED_KEYS=<ok|found|unknown-target-version|uncheckable>
#
# The four verdicts:
#   ok                      every staged file was scanned and no key removed at
#                           or before the target appears in any of them.
#   found                   at least one does. The REMOVED_KEY= lines name the
#                           key, the file and line, and the release that removed
#                           it. Do not install.
#   unknown-target-version  the target version could not be determined. NOTHING
#                           was validated and this is NOT a pass: the check
#                           refuses to invent a target, exactly as
#                           config-language.sh refuses to invent a language.
#   uncheckable             the staged set or the ledger could not be read, so
#                           no verdict was reached about anything.
#
# Exit: 0 ok, 1 removed keys found, 2 bad usage / uncheckable,
#       3 the target version is unknown.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/removedkeys.py). This file locates
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.removedkeys "$@"

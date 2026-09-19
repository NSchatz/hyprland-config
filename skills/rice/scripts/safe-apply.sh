#!/usr/bin/env bash
# Prove a staged Hyprland config parses, THEN install it, live-test it, and
# AUTO-ROLLBACK if it fails to load.
#
# Usage: safe-apply.sh <staging-dir>
#   <staging-dir>  Directory of generated *.conf files (same input as install-config.sh).
#
# Flow:
#   0. validate-removed-keys.sh -> STATIC check of the staged files against the
#                             version-cliff ledger's removed-key table. Runs FIRST,
#                             before the compositor is consulted at all, because it
#                             needs neither a binary nor a session: its verdict is
#                             reached on hosts where the offline check can only say
#                             `unverified`. Nothing is backed up or written behind it.
#   0b. preflight-config.sh -> the compositor's own OFFLINE check, against the staged
#                             files, in a sandbox. Runs before any backup and any
#                             write, so a bad config is refused with the user's
#                             the resolved config dir never touched.
#   1. install-config.sh   -> timestamped backup of the resolved config dir, then install
#                             the staged files into it
#   2. verify-config.sh    -> hyprctl reload + configerrors + "is the file I wrote the
#                             one you loaded?"
#   3. on parse errors     -> restore the backup, reload again, report ROLLED_BACK
#
# Step 0 is a FIRST net, not a replacement for steps 1-3: a config can parse offline
# and still fail against a live compositor, so install / live-test / rollback stays
# exactly as it was behind it.
#
# Honors HYPR_DIR (passed through to install-config.sh). With no HYPR_DIR the target is
# $XDG_CONFIG_HOME/hypr when XDG_CONFIG_HOME is an absolute path and $HOME/.config/hypr
# otherwise - one decision, made in scripts/xdg-config.sh and shared with every script in
# this directory so a backup and a rollback can never name different directories.
# Output ends with one of:
#   SAFE_APPLY=ok                     installed, verified clean, and the compositor
#                                     confirms it loaded the file we wrote
#   SAFE_APPLY=installed-untested     installed, but no running Hyprland to test against
#   SAFE_APPLY=unconfirmed            installed with no parse errors, but the running
#                                     compositor did not confirm it loaded the file we
#                                     wrote. NOT live. The LOADED_CONFIG= line above
#                                     names what it did load
#   SAFE_APPLY=rolled-back            new config errored; previous config restored
#   SAFE_APPLY=errors-no-backup       new config errored and there was no backup to restore
#   SAFE_APPLY=install-failed         install step failed; nothing changed
#   SAFE_APPLY=preflight-failed       the OFFLINE check reported errors in the STAGED
#                                     files; nothing was backed up, nothing was written,
#                                     the target is untouched. The PREFLIGHT_ERROR= lines
#                                     above name the staged file and line
#   SAFE_APPLY=preflight-uncheckable  the offline check could not be run against the
#                                     staged files at all (missing/unreadable/ambiguous
#                                     main config, or the compositor rejected the
#                                     invocation). Nothing was changed. Distinct from
#                                     preflight-failed on purpose: nothing was checked,
#                                     so nothing was found wrong
#   SAFE_APPLY=removed-keys-failed    the staged config sets a key the reference layer
#                                     documents as REMOVED at the target version, where
#                                     it is a hard parse error. Nothing was checked by
#                                     the compositor, nothing was backed up, nothing was
#                                     written; the target is untouched. The REMOVED_KEY=
#                                     lines above name the key, the staged file and line,
#                                     and the release that removed it
#   SAFE_APPLY=refused                install-config.sh REFUSED and changed nothing: the
#                                     target already holds a hyprland.lua that would shadow
#                                     a hyprlang .conf, the target is unwritable, or the
#                                     staging dir holds both languages. The refusal lines
#                                     above (SHADOWED_BY=/REFUSED=/TARGET=) say which.
#   SAFE_APPLY=no-config-dir          no config directory could be determined at all: no
#                                     HYPR_DIR, no absolute XDG_CONFIG_HOME, no HOME.
#                                     CONFIG_DIR=unresolved is printed and nothing is
#                                     checked, backed up or written.
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/safeapply.py). This file locates
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
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.safeapply "$@"

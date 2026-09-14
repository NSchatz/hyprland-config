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
# Example:
#   safe-apply.sh /tmp/hypr-gen-abc/staging
#
# Options: -h, --help, help
# Subcommands: none
#
# Exit codes:
#   0  ok: installed and verified, or installed with no compositor to live-test against
#   1  verdict: the answer about the staged config came back negative - the offline check
#      found errors, a removed key is set, the installed config would not parse and the
#      previous one was restored, or the compositor will not confirm it loaded what we wrote
#   2  usage: no <staging-dir> argument was given
#   3  capability: the config-path library is not beside this script, or install-config.sh
#      could not reach one. Nothing was checked, backed up or written
#   4  refusal: it declined and wrote nothing - install-config.sh refused, or there is no
#      config directory it will resolve. Every target path is byte-identical to before
#   5  input: the staged set could not be checked or used at all - a missing, unreadable or
#      ambiguous staged main config. Nothing was backed up or written
#   6  partial: the staged config was INSTALLED, it does not parse, and there was no backup
#      to restore it from. State is mixed and a re-run is not automatically safe until the
#      target is fixed by hand
set -uo pipefail

case "${1:-}" in   # [cli-parser]
    -h|--help|help)
        sed -n '2,/^[^#]/p' "$0" | sed -e '/^[^#]/d' -e 's/^#\{1,2\} \{0,1\}//'
        exit 0 ;;   # rc=ok
esac

staging="${1:-}"
if [ -z "$staging" ]; then
    echo "ERROR: usage: safe-apply.sh <staging-dir>" >&2
    exit 2   # rc=usage
fi

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=config-language.sh
source "$here/config-language.sh"
_xdg_lib=""
for _c in "$here/xdg-config.sh" \
          "$here/../../../scripts/xdg-config.sh" \
          "${CLAUDE_PLUGIN_ROOT:-}/scripts/xdg-config.sh"; do
    if [ -n "$_c" ] && [ -f "$_c" ]; then _xdg_lib="$_c"; break; fi
done
if [ -z "$_xdg_lib" ]; then
    echo "ERROR: the config-path library (scripts/xdg-config.sh) was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in the plugin. Refusing to guess where your config lives." >&2
    exit 3   # rc=capability
fi
# shellcheck source=../../../scripts/xdg-config.sh
. "$_xdg_lib"

# The SAME resolution install-config.sh, backup-config.sh and reset-config.sh use. This is
# the file where a split would be lethal: a rollback that restores into a different
# directory from the one the backup came out of has no inverse.
if ! xdg_config_target hypr "${HYPR_DIR:-}"; then
    echo "SAFE_APPLY=no-config-dir (nothing was checked, backed up or written)"
    exit 4   # rc=refusal
fi
target="$XDG_CONFIG_TARGET"

# 0. Removed keys: a STATIC read of the staged files against the version-cliff
#    ledger. First, and deliberately independent of everything below it - it needs
#    no compositor, so a host that can only report `preflight-unverified` still gets
#    a real verdict here. An unknown target version is NOT a refusal: whether a key
#    is removed depends entirely on the target, so with no target the check reports
#    that it reached no verdict and the apply carries on to the nets that do not
#    need one. Refusing there would lock a user out of applying their own config.
rk_out="$(bash "$here/validate-removed-keys.sh" "$staging" 2>&1)"
rkrc=$?
printf '%s\n' "$rk_out"
if [ "$rkrc" -eq 1 ]; then
    echo "Nothing was installed and nothing was backed up; ${target} is untouched."
    echo "SAFE_APPLY=removed-keys-failed (the staged config sets a key removed at the target version)"
    exit 1   # rc=verdict
fi
if [ "$rkrc" -eq 3 ]; then
    echo "The removed-key check reached NO verdict (the target version is unknown); the checks below do not depend on one."
fi

# 0b. Preflight: the compositor's own offline check, against the STAGED files.
#    Nothing below this point runs until it says the config is worth installing.
#    A host with no offline check available reports `unverified` and falls through
#    to the install/live-test/rollback path with its behaviour unchanged - that is
#    the pre-existing net, not a new one.
preflight_out="$(bash "$here/preflight-config.sh" "$staging" 2>&1)"
prc=$?
printf '%s\n' "$preflight_out"
# 0 = checked clean, 3 = `unverified`, which means NOTHING was proven and the caller carries
# on to install + live-test + rollback. 1 is the parser's negative verdict and 5 is
# `uncheckable`, which is a refusal to install a config nobody could check.
case "$prc" in
    0|3) ;;
    1)
        echo "Nothing was installed and nothing was backed up; ${target} is untouched."
        echo "SAFE_APPLY=preflight-failed (the offline check found errors in the staged config)"
        exit 1 ;;   # rc=verdict
    *)
        echo "Nothing was installed and nothing was backed up; ${target} is untouched."
        echo "SAFE_APPLY=preflight-uncheckable (the offline check could not be run against the staged config)"
        exit 5 ;;   # rc=input
esac

# 1. Install (also prints BACKUP=, TARGET=, CONFIG_LANGUAGE=, INSTALLED=...).
install_out="$(bash "$here/install-config.sh" "$staging" 2>&1)"
irc=$?
if [ "$irc" -ne 0 ]; then
    printf '%s\n' "$install_out"
    # 4 is install-config.sh's REFUSAL and 5 its defective staged set: either way it declined
    # before changing anything. Never let that read as an ordinary failure, and never as ok.
    case "$irc" in
        4|5)
            echo "SAFE_APPLY=refused (install-config.sh declined; nothing was changed)"
            exit 4 ;;   # rc=refusal
        3)
            echo "SAFE_APPLY=install-failed"
            exit 3 ;;   # rc=capability
        *)
            echo "SAFE_APPLY=install-failed"
            exit 5 ;;   # rc=input
    esac
fi
printf '%s\n' "$install_out"

backup="$(printf '%s\n' "$install_out" | sed -n 's/^BACKUP=//p' | head -n1)"

# The file we just wrote, which is the file the compositor now has to prove it read.
installed_lang="$(printf '%s\n' "$install_out" | sed -n 's/^CONFIG_LANGUAGE=//p' | head -n1)"
installed_target="$(printf '%s\n' "$install_out" | sed -n 's/^TARGET=//p' | head -n1)"
[ -n "$installed_target" ] || installed_target="$target"
installed_main=""
if [ -n "$installed_lang" ] && main_name="$(config_lang_file "$installed_lang")"; then
    installed_main="${installed_target}/${main_name}"
fi

# 2. Live-test. Capture the exit code explicitly (don't rely on $? after `if`).
#    --expect makes `ok` mean "the compositor says it loaded THIS file", not
#    "the compositor declined to complain".
if [ -n "$installed_main" ]; then
    verify_out="$(bash "$here/verify-config.sh" --expect "$installed_main")"
else
    verify_out="$(bash "$here/verify-config.sh")"
fi
vrc=$?
printf '%s\n' "$verify_out"

if [ "$vrc" -eq 0 ]; then
    echo "SAFE_APPLY=ok"
    exit 0   # rc=ok
fi
# verify-config.sh returns 3 for BOTH of its "the live check could not be made" cases: no
# compositor to ask, and a compositor that would not name the config it loaded. The caller acts
# differently on those two, and the VERIFY= narration is what tells them apart - the exit status
# says only that no live verdict was reached, which is the thing a caller must never read as ok.
verify_verdict="$(printf '%s\n' "$verify_out" | sed -n 's/^VERIFY=\([a-z-]*\).*/\1/p' | tail -n1)"
if [ "$vrc" -eq 3 ] && [ "$verify_verdict" = "skipped" ]; then
    # No running instance => cannot live-test; leave installed.
    echo "SAFE_APPLY=installed-untested (no running Hyprland; relied on static validation)"
    exit 0   # rc=ok
fi
if [ "$vrc" -eq 3 ]; then
    # Installed cleanly, but the running compositor is not reading it. Rolling back
    # would be wrong - the config is not the thing that is broken - and reporting ok
    # would be a success message for a change that never reached the compositor.
    echo "The file above is what the compositor loaded; ${installed_main} is on disk but is not what is running."
    echo "SAFE_APPLY=unconfirmed (installed with no parse errors, but the compositor did not confirm it loaded it)"
    exit 1   # rc=verdict
fi

# 3. vrc == 1 => parse errors => roll back to the backup if we have a real one.
case "$backup" in
    /*)
        if [ -d "$backup" ]; then
            # Restore WITHOUT emptying the target dir. A running Hyprland regenerates a STUB
            # hyprland.conf the instant the config dir goes empty, which races `rm -rf` (causing a
            # "Directory not empty" failure) and leaves a nested-backup / stub mess. Instead:
            # overwrite every backup file back over the target, then prune only the files the failed
            # config ADDED (present in target, absent in backup). The dir is never empty.
            cp -a "$backup/." "$target/"
            ( cd "$target" && find . \( -type f -o -type l \) -print ) | while IFS= read -r f; do
                [ -e "$backup/$f" ] || rm -f "$target/$f"
            done
            bash "$here/verify-config.sh" >/dev/null 2>&1 || true   # reload the restored config
            echo "SAFE_APPLY=rolled-back (new config had errors; restored $backup)"
            exit 1   # rc=verdict
        fi
        ;;
esac

echo "SAFE_APPLY=errors-no-backup (new config has parse errors; no backup existed to restore)"
echo "Inspect $target and fix, or remove the generated files."
# The one outcome of this script under which state is MIXED: the staged config WAS installed
# into the target, it does NOT parse, and there was no previous config to put back. Say both
# halves on stderr so a caller reading nothing but stderr knows a re-run is not enough.
echo "PARTIAL: the staged config WAS installed into ${target}; the previous config was NOT restored, because there was no backup to restore. Re-running this command is not automatically safe until ${target} is fixed by hand." >&2
exit 6   # rc=partial

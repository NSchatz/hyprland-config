#!/usr/bin/env bash
# Prove a staged Hyprland config parses, THEN install it, live-test it, and
# AUTO-ROLLBACK if it fails to load.
#
# Usage: safe-apply.sh <staging-dir>
#   <staging-dir>  Directory of generated *.conf files (same input as install-config.sh).
#
# Flow:
#   0. preflight-config.sh -> the compositor's own OFFLINE check, against the staged
#                             files, in a sandbox. Runs before any backup and any
#                             write, so a bad config is refused with the user's
#                             ~/.config/hypr never touched.
#   1. install-config.sh   -> timestamped backup of ~/.config/hypr, then install staged files
#   2. verify-config.sh    -> hyprctl reload + configerrors + "is the file I wrote the
#                             one you loaded?"
#   3. on parse errors     -> restore the backup, reload again, report ROLLED_BACK
#
# Step 0 is a FIRST net, not a replacement for steps 1-3: a config can parse offline
# and still fail against a live compositor, so install / live-test / rollback stays
# exactly as it was behind it.
#
# Honors HYPR_DIR (passed through to install-config.sh; default ~/.config/hypr).
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
#   SAFE_APPLY=refused                install-config.sh REFUSED and changed nothing: the
#                                     target already holds a hyprland.lua that would shadow
#                                     a hyprlang .conf, the target is unwritable, or the
#                                     staging dir holds both languages. The refusal lines
#                                     above (SHADOWED_BY=/REFUSED=/TARGET=) say which.
set -uo pipefail

staging="${1:-}"
if [ -z "$staging" ]; then
    echo "ERROR: usage: safe-apply.sh <staging-dir>" >&2
    exit 2
fi

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=config-language.sh
source "$here/config-language.sh"
target="${HYPR_DIR:-$HOME/.config/hypr}"

# 0. Preflight: the compositor's own offline check, against the STAGED files.
#    Nothing below this point runs until it says the config is worth installing.
#    A host with no offline check available reports `unverified` and falls through
#    to the install/live-test/rollback path with its behaviour unchanged - that is
#    the pre-existing net, not a new one.
preflight_out="$(bash "$here/preflight-config.sh" "$staging" 2>&1)"
prc=$?
printf '%s\n' "$preflight_out"
case "$prc" in
    0|2) ;;
    1)
        echo "Nothing was installed and nothing was backed up; ${target} is untouched."
        echo "SAFE_APPLY=preflight-failed (the offline check found errors in the staged config)"
        exit 2 ;;
    *)
        echo "Nothing was installed and nothing was backed up; ${target} is untouched."
        echo "SAFE_APPLY=preflight-uncheckable (the offline check could not be run against the staged config)"
        exit 2 ;;
esac

# 1. Install (also prints BACKUP=, TARGET=, CONFIG_LANGUAGE=, INSTALLED=...).
install_out="$(bash "$here/install-config.sh" "$staging" 2>&1)"
irc=$?
if [ "$irc" -ne 0 ]; then
    printf '%s\n' "$install_out"
    # 3 and 4 are install-config.sh's REFUSALS: it declined before changing
    # anything. Never let that read as an ordinary failure, and never as ok.
    if [ "$irc" -eq 3 ] || [ "$irc" -eq 4 ]; then
        echo "SAFE_APPLY=refused (install-config.sh declined; nothing was changed)"
        exit 2
    fi
    echo "SAFE_APPLY=install-failed"
    exit 2
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
    exit 0
fi
if [ "$vrc" -eq 2 ]; then
    # No running instance => cannot live-test; leave installed.
    echo "SAFE_APPLY=installed-untested (no running Hyprland; relied on static validation)"
    exit 0
fi
if [ "$vrc" -eq 3 ]; then
    # Installed cleanly, but the running compositor is not reading it. Rolling back
    # would be wrong - the config is not the thing that is broken - and reporting ok
    # would be a success message for a change that never reached the compositor.
    echo "The file above is what the compositor loaded; ${installed_main} is on disk but is not what is running."
    echo "SAFE_APPLY=unconfirmed (installed with no parse errors, but the compositor did not confirm it loaded it)"
    exit 1
fi

# 3. vrc == 1 => parse errors => roll back to the backup if we have a real one.
case "$backup" in
    /*)
        if [ -d "$backup" ]; then
            # Restore WITHOUT emptying the target dir. A running Hyprland regenerates a STUB
            # hyprland.conf the instant ~/.config/hypr goes empty, which races `rm -rf` (causing a
            # "Directory not empty" failure) and leaves a nested-backup / stub mess. Instead:
            # overwrite every backup file back over the target, then prune only the files the failed
            # config ADDED (present in target, absent in backup). The dir is never empty.
            cp -a "$backup/." "$target/"
            ( cd "$target" && find . \( -type f -o -type l \) -print ) | while IFS= read -r f; do
                [ -e "$backup/$f" ] || rm -f "$target/$f"
            done
            bash "$here/verify-config.sh" >/dev/null 2>&1 || true   # reload the restored config
            echo "SAFE_APPLY=rolled-back (new config had errors; restored $backup)"
            exit 1
        fi
        ;;
esac

echo "SAFE_APPLY=errors-no-backup (new config has parse errors; no backup existed to restore)"
echo "Inspect $target and fix, or remove the generated files."
exit 1

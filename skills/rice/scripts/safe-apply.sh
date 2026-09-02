#!/usr/bin/env bash
# Install a staged Hyprland config, live-test it, and AUTO-ROLLBACK if it fails to load.
#
# Usage: safe-apply.sh <staging-dir>
#   <staging-dir>  Directory of generated *.conf files (same input as install-config.sh).
#
# Flow:
#   1. install-config.sh   -> timestamped backup of ~/.config/hypr, then install staged files
#   2. verify-config.sh    -> hyprctl reload + configerrors
#   3. on parse errors     -> restore the backup, reload again, report ROLLED_BACK
#
# Honors HYPR_DIR (passed through to install-config.sh; default ~/.config/hypr).
# Output ends with one of:
#   SAFE_APPLY=ok                  installed and verified clean
#   SAFE_APPLY=installed-untested  installed, but no running Hyprland to test against
#   SAFE_APPLY=rolled-back         new config errored; previous config restored
#   SAFE_APPLY=errors-no-backup    new config errored and there was no backup to restore
#   SAFE_APPLY=install-failed      install step failed; nothing changed
#   SAFE_APPLY=refused             install-config.sh REFUSED and changed nothing: the
#                                  target already holds a hyprland.lua that would shadow
#                                  a hyprlang .conf, the target is unwritable, or the
#                                  staging dir holds both languages. The refusal lines
#                                  above (SHADOWED_BY=/REFUSED=/TARGET=) say which.
set -uo pipefail

staging="${1:-}"
if [ -z "$staging" ]; then
    echo "ERROR: usage: safe-apply.sh <staging-dir>" >&2
    exit 2
fi

here="$(cd "$(dirname "$0")" && pwd)"
target="${HYPR_DIR:-$HOME/.config/hypr}"

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

# 2. Live-test. Capture the exit code explicitly (don't rely on $? after `if`).
verify_out="$(bash "$here/verify-config.sh")"
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

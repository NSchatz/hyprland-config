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
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
_xdg_lib=""
for _c in "$here/xdg-config.sh" \
          "$here/../../../scripts/xdg-config.sh" \
          "${CLAUDE_PLUGIN_ROOT:-}/scripts/xdg-config.sh"; do
    if [ -n "$_c" ] && [ -f "$_c" ]; then _xdg_lib="$_c"; break; fi
done
if [ -z "$_xdg_lib" ]; then
    echo "ERROR: the config-path library (scripts/xdg-config.sh) was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in the plugin. Refusing to guess which directory to wipe." >&2
    exit 4
fi
# shellcheck source=../../../scripts/xdg-config.sh
. "$_xdg_lib"

if ! xdg_config_target hypr "${HYPR_DIR:-}"; then
    echo "RESET=refused-no-config-dir"
    exit 4
fi
target="$XDG_CONFIG_TARGET"

# 0. This script WIPES the target. Prove it is writable before anything else runs, so a
#    permission problem is reported against the resolved path instead of half-emptying a
#    directory - and never by silently reaching for another one.
if [ -e "$target" ] && [ ! -d "$target" ]; then
    echo "ERROR: reset target '$target' exists but is not a directory." >&2
    echo "TARGET=${target}"
    echo "RESET=refused-target-not-writable"
    exit 4
fi
if [ -d "$target" ] && [ ! -w "$target" ]; then
    echo "ERROR: reset target '$target' exists but cannot be written to (permission denied)." >&2
    echo "       Nothing was changed. Fix the permissions on that directory and re-run." >&2
    echo "TARGET=${target}"
    echo "RESET=refused-target-not-writable"
    exit 4
fi

# 1. Generate the bare config BEFORE touching anything. If the config language
#    cannot be resolved, this refuses and the user's config is still there.
staging="$(mktemp -d "${TMPDIR:-/tmp}/hypr-reset.XXXXXX")" || {
    echo "ERROR: could not create a staging directory" >&2
    exit 2
}
cleanup() { rm -rf "$staging"; }
trap cleanup EXIT

emit_out="$(bash "$here/emit-config.sh" "$staging")"
erc=$?
printf '%s\n' "$emit_out"
if [ "$erc" -eq 3 ]; then
    echo "Nothing was changed; ${target} is untouched."
    echo "TARGET=${target}"
    echo "RESET=refused-undecided"
    exit 3
fi
if [ "$erc" -ne 0 ]; then
    echo "TARGET=${target}"
    echo "RESET=refused-undecided"
    exit 2
fi
emitted="$(printf '%s\n' "$emit_out" | sed -n 's/^EMITTED=//p' | head -n1)"
if [ -z "$emitted" ] || [ ! -f "$emitted" ]; then
    echo "ERROR: the emitter produced no config file" >&2
    exit 2
fi

# 2. Back up the entire existing config (same convention as install-config.sh).
backup=""
if [ -d "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="${target}.bak.${ts}"
    cp -a "$target" "$backup"
    echo "BACKUP=${backup}"
else
    echo "BACKUP=none (no existing config to back up)"
fi

# 3. Wipe the target clean (contents only; keep the dir) and drop the bare config in.
mkdir -p "$target"
find "$target" -mindepth 1 -delete 2>/dev/null || true
cp -f "$emitted" "$target/"

echo "WROTE=${target}/$(basename "$emitted")"
echo "TARGET=${target}"

# 4. Live-test (reload + configerrors). Reuse the shared verifier.
verify_out="$(bash "$here/verify-config.sh")"
vrc=$?
printf '%s\n' "$verify_out"

if [ "$vrc" -eq 0 ]; then
    echo "RESET=ok"
    exit 0
fi
if [ "$vrc" -eq 2 ]; then
    echo "RESET=installed-untested (no running Hyprland; test on next login)"
    exit 0
fi

# 5. Parse errors (unexpected for a minimal config) -> roll back to the backup.
case "$backup" in
    /*)
        if [ -d "$backup" ]; then
            rm -rf "${target:?}"
            cp -a "$backup" "$target"
            bash "$here/verify-config.sh" >/dev/null 2>&1 || true
            echo "RESET=rolled-back (bare config errored; restored $backup)"
            exit 1
        fi
        ;;
esac

echo "RESET=errors-no-backup (bare config has parse errors; no backup existed to restore)"
exit 1

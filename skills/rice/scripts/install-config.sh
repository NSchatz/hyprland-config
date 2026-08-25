#!/usr/bin/env bash
# Back up any existing Hyprland config, then install a freshly generated one.
#
# Usage:   install-config.sh <staging-dir>
#   <staging-dir>  Directory containing the generated config files: either a
#                  hyprlang set (a main `hyprland.conf` plus other `*.conf`) or a
#                  lua set (a main `hyprland.lua` plus other `*.lua`).
#
# Behavior:
#   - Target dir is $HYPR_DIR (default: ~/.config/hypr).
#   - REFUSES to install a hyprlang `.conf` into a target that already holds a
#     `hyprland.lua`. Since Hyprland 0.55 the lua file is loaded INSTEAD of the
#     `.conf`, so that install would report success for a change the compositor
#     never reads. This check runs FIRST and nothing is touched when it fires.
#   - REFUSES, before taking a backup or writing anything, when the target exists
#     but cannot be written to; the target is left exactly as it was.
#   - If the target exists and is non-empty, it is copied to
#     <target>.bak.<YYYYmmdd-HHMMSS> before anything is changed. An absent or
#     empty target gets no backup, and none is claimed.
#   - The generated config files are then copied into the target.
#
# Prints a summary the caller parses:
#   BACKUP=<path> | BACKUP=none (no existing config to back up)
#   CONFIG_LANGUAGE=<lua|hyprlang>
#   CONFIG_LANGUAGE_RANGE=<the Hyprland versions that language is valid for>
#   INSTALLED=<file>          (one line per installed file)
#   TARGET=<dir>
#   DONE=ok
#
# Exit: 0 installed, 2 bad usage / unusable staging dir,
#       3 refused (the target is shadowed by a hyprland.lua, or staging is
#         ambiguous because it holds both languages),
#       4 refused (the target exists but cannot be written to).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=config-language.sh
source "$here/config-language.sh"

staging="${1:-}"
if [ -z "$staging" ]; then
    echo "ERROR: missing <staging-dir> argument" >&2
    exit 2
fi
if [ ! -d "$staging" ]; then
    echo "ERROR: staging dir '$staging' does not exist" >&2
    exit 2
fi

shopt -s nullglob

# --- Which language did the generator stage? ------------------------------------------------
has_conf=0; has_lua=0
if [ -e "$staging/hyprland.conf" ]; then has_conf=1; fi
if [ -e "$staging/hyprland.lua" ]; then has_lua=1; fi

if [ "$has_conf" -eq 1 ] && [ "$has_lua" -eq 1 ]; then
    # Installing both would put a shadowing pair on the user's machine: the lua
    # wins and the .conf becomes dead weight nobody is told about. Refuse.
    echo "ERROR: staging dir '$staging' holds BOTH a hyprland.lua and a hyprland.conf." >&2
    echo "       Hyprland loads hyprland.lua and IGNORES hyprland.conf, so installing both" >&2
    echo "       would quietly make the .conf dead. Stage exactly one config language." >&2
    echo "REFUSED=ambiguous-staging"
    exit 3
fi
if [ "$has_lua" -eq 1 ]; then
    language="lua"
    config_files=("$staging"/*.lua)
elif [ "$has_conf" -eq 1 ]; then
    language="hyprlang"
    config_files=("$staging"/*.conf)
else
    echo "ERROR: staging dir is missing a main config (no hyprland.lua and no hyprland.conf)" >&2
    exit 2
fi
if [ ${#config_files[@]} -eq 0 ]; then
    echo "ERROR: no config files found in '$staging'" >&2
    exit 2
fi

target="${HYPR_DIR:-$HOME/.config/hypr}"

# --- Fail-safe 1: never install a hyprlang .conf into a lua-shadowed directory ---------------
# The failure this closes is not a crash. It is a success message for a change
# the compositor never read.
if [ "$language" = "hyprlang" ] && [ -e "$target/hyprland.lua" ]; then
    echo "ERROR: '$target/hyprland.lua' already exists." >&2
    echo "       Since Hyprland 0.55 a hyprland.lua TAKES PRECEDENCE over hyprland.conf:" >&2
    echo "       the lua config is loaded and the .conf is ignored. Installing a hyprlang" >&2
    echo "       .conf here would report success for a change the compositor never reads." >&2
    echo "       Emit a lua config instead, or move '$target/hyprland.lua' aside first." >&2
    echo "SHADOWED_BY=${target}/hyprland.lua"
    echo "PRECEDENCE=hyprland.lua takes precedence over hyprland.conf"
    echo "TARGET=${target}"
    echo "REFUSED=lua-config-takes-precedence"
    exit 3
fi

# --- Fail-safe 2: an unwritable target is reported, not half-written -------------------------
# Checked BEFORE the backup so a refusal leaves every file in the target, and the
# target itself, exactly as it was.
if [ -e "$target" ] && [ ! -d "$target" ]; then
    echo "ERROR: install target '$target' exists but is not a directory." >&2
    echo "TARGET=${target}"
    echo "REFUSED=target-not-a-directory"
    exit 4
fi
if [ -d "$target" ] && [ ! -w "$target" ]; then
    echo "ERROR: install target '$target' exists but cannot be written to (permission denied)." >&2
    echo "       Nothing was changed. Fix the permissions on that directory and re-run." >&2
    echo "TARGET=${target}"
    echo "REFUSED=target-not-writable"
    exit 4
fi

# --- Backup (only when there is something to back up) ----------------------------------------
backup=""
if [ -d "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="${target}.bak.${ts}"
    if ! cp -a "$target" "$backup"; then
        echo "ERROR: could not back up '$target' to '$backup'; nothing was changed." >&2
        echo "TARGET=${target}"
        echo "REFUSED=backup-failed"
        exit 4
    fi
    echo "BACKUP=${backup}"
else
    echo "BACKUP=none (no existing config to back up)"
fi

# --- Provenance: say which language is going in, and what it is good for ---------------------
# Prefer the header the emitter wrote into the staged config; fall back to the
# language the staged file names imply.
staged_main="$staging/$(config_lang_file "$language")"
range="$(sed -n 's/^[#-][#-]* *CONFIG_LANGUAGE_RANGE=//p' "$staged_main" 2>/dev/null | head -n1 || true)"
[ -n "$range" ] || range="$(config_lang_range "$language")"
echo "CONFIG_LANGUAGE=${language}"
echo "CONFIG_LANGUAGE_RANGE=${range}"

mkdir -p "$target"
for f in "${config_files[@]}"; do
    cp -f "$f" "$target/"
    echo "INSTALLED=$(basename "$f")"
done

echo "TARGET=${target}"
echo "DONE=ok"

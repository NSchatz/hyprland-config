#!/usr/bin/env bash
# Ask the RUNNING compositor which configuration file it actually loaded.
#
# Usage: loaded-config.sh
#
# Why this exists: `hyprctl configerrors` printing nothing is NOT proof that the
# config this plugin wrote is the one Hyprland is running. An empty error list is
# exactly what a config that was never parsed produces - which is the state a
# shadowed (`hyprland.lua` over `hyprland.conf`) or simply-ignored file leaves
# behind. "Live" has to mean the compositor names the file.
#
# Hyprland has no hyprctl command that reports its config path (checked against
# 0.56.2's own `hyprctl --help`; see `tests/integration/offline-check-contract.md`).
# It does, however, LOG the path, once per config file it reads, as
#   Using config: <absolute path>
# and that log is reachable through hyprctl itself. Those log lines are re-emitted
# on every `hyprctl reload`, so a caller that reloads first gets a fresh answer.
#
# Output (KEY=value lines):
#   LOADED_CONFIG=<absolute path>   one line per config file the compositor names
#   LOADED_CONFIG=unknown           when no route could establish it
#   LOADED_CONFIG_SOURCE=<rollinglog|instance-log|systeminfo|none>
#
# Exit: 0 identified, 2 no running instance (nothing to ask), 3 running but the
#       loaded config could not be established.
set -uo pipefail

if ! command -v hyprctl >/dev/null 2>&1 || ! hyprctl version >/dev/null 2>&1; then
    echo "LOADED_CONFIG=unknown"
    echo "LOADED_CONFIG_SOURCE=none (no running Hyprland instance)"
    exit 2
fi

# `paths_from <text>` - the config paths a chunk of Hyprland log names, deduped,
# first-seen order preserved.
paths_from() {
    grep -oE 'Using config: .+' 2>/dev/null \
        | sed -e 's/^Using config: *//' -e 's/[[:space:]]*$//' \
        | awk 'NF && !seen[$0]++'
}

found=""
source_used="none"

# Route 1: the compositor's own rolling log, straight out of hyprctl.
found="$(hyprctl rollinglog 2>/dev/null | paths_from)"
[ -n "$found" ] && source_used="rollinglog"

# Route 2: the instance log on disk. Same logger, survives a rolled-over tail.
if [ -z "$found" ]; then
    log_dir="${XDG_RUNTIME_DIR:-}/hypr"
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -f "$log_dir/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log" ]; then
        found="$(paths_from < "$log_dir/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log")"
    elif [ -d "$log_dir" ]; then
        newest="$(find "$log_dir" -name 'hyprland.log' -printf '%T@ %p\n' 2>/dev/null \
                  | sort -nr | head -n1 | cut -d' ' -f2-)"
        [ -n "$newest" ] && [ -f "$newest" ] && found="$(paths_from < "$newest")"
    fi
    [ -n "$found" ] && source_used="instance-log"
fi

# Route 3: systeminfo, for builds that fold the config into it.
if [ -z "$found" ]; then
    found="$(hyprctl systeminfo 2>/dev/null | paths_from)"
    [ -n "$found" ] && source_used="systeminfo"
fi

if [ -z "$found" ]; then
    echo "LOADED_CONFIG=unknown"
    echo "LOADED_CONFIG_SOURCE=none (the running instance did not name the config it loaded)"
    exit 3
fi

while IFS= read -r p; do
    [ -n "$p" ] && echo "LOADED_CONFIG=${p}"
done <<< "$found"
echo "LOADED_CONFIG_SOURCE=${source_used}"
exit 0

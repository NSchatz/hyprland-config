#!/usr/bin/env bash
# Reset ~/.config/hypr to a minimal, working "bare bones" Hyprland config.
#
# Backs up the ENTIRE existing config (timestamped), WIPES the directory, writes a
# single minimal hyprland.conf, live-tests it (hyprctl reload + configerrors), and
# AUTO-ROLLS-BACK to the backup if it somehow fails to load.
#
# Usage: reset-config.sh
# Env:
#   HYPR_DIR        target dir          (default: ~/.config/hypr)
#   BARE_TERMINAL   $terminal value     (default: kitty)
#   BARE_MENU       $menu value         (default: wofi --show drun)
#
# Unlike install-config.sh (additive per-file), this is a CLEAN WIPE — after it runs
# the target contains only the bare hyprland.conf. The full backup preserves prior state.
#
# Output ends with one of:
#   RESET=ok                  wiped, wrote the bare config, verified clean
#   RESET=installed-untested  wrote the bare config, but no running Hyprland to test against
#   RESET=rolled-back         bare config errored (unexpected); previous config restored
#   RESET=errors-no-backup    bare config errored and there was no backup to restore
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
target="${HYPR_DIR:-$HOME/.config/hypr}"
terminal="${BARE_TERMINAL:-kitty}"
menu="${BARE_MENU:-wofi --show drun}"

# 1. Back up the entire existing config (same convention as install-config.sh).
backup=""
if [ -d "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="${target}.bak.${ts}"
    cp -a "$target" "$backup"
    echo "BACKUP=${backup}"
else
    echo "BACKUP=none (no existing config to back up)"
fi

# 2. Wipe the target clean (contents only; keep the dir) and write the bare config.
mkdir -p "$target"
find "$target" -mindepth 1 -delete 2>/dev/null || true

{
    echo "# ----------------------------------------------------------------------------"
    echo "# Bare-bones Hyprland config — reset by the hyprland-config plugin."
    echo "# A minimal, working baseline. Rebuild with /hyprland-config:generate-config"
    echo "# (full interview) or extend piecemeal with /hyprland-config:edit-config."
    echo "# ----------------------------------------------------------------------------"
    echo ""
    echo "\$terminal = ${terminal}"
    echo "\$menu     = ${menu}"
    cat <<'BARE'
$mainMod  = SUPER

# Monitors — auto-detect everything (adjust with `hyprctl monitors`).
monitor = , preferred, auto, auto

# Minimal look — small gaps, a visible border, dwindle tiling.
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    layout = dwindle
}

input {
    kb_layout = us
    follow_mouse = 1
}

# Essential keybinds — enough to open a terminal, launch apps, and exit.
bind = $mainMod, Return, exec, $terminal
bind = $mainMod, Q, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, D, exec, $menu
bind = $mainMod, Space, togglefloating,

# Move focus
bind = $mainMod, left,  movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up,    movefocus, u
bind = $mainMod, down,  movefocus, d

# Workspaces 1-5
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5

# Mouse move/resize
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow
BARE
} > "$target/hyprland.conf"

echo "WROTE=${target}/hyprland.conf"
echo "TARGET=${target}"

# 3. Live-test (reload + configerrors). Reuse the shared verifier.
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

# 4. Parse errors (unexpected for a minimal config) -> roll back to the backup.
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

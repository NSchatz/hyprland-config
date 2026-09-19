#!/usr/bin/env bash
# The preview guest's entire tty1 session: mount the shares, apply the staged config, set up
# the rice engine, run the generated install.sh, install plugins, then become the compositor.
#
# The copy itself lives in guest-apply.sh, which is also what `rice preview reload` runs. One
# implementation, used at boot and on every iteration, so what you boot and what you reload
# into are never two different things.
#
# Everything is logged to ~/preview-boot.log and summarised in ~/preview-boot.status, which the
# host reads. A guest that fails at this stage otherwise shows a black screen and no reason.
set -uo pipefail

LOG="$HOME/preview-boot.log"
STATUS="$HOME/preview-boot.status"
: > "$STATUS"
exec >>"$LOG" 2>&1

note() { echo "$1"; echo "$1" >> "$STATUS"; }

echo "=== preview session $(date -Is) ==="

# ---------------------------------------------------------------------------------------
# 0. Options from the host, over QEMU's fw_cfg: no guest agent and no extra package, the
#    values simply arrive as a file in sysfs.
# ---------------------------------------------------------------------------------------
sudo modprobe qemu_fw_cfg 2>/dev/null || true
FW="/sys/firmware/qemu_fw_cfg/by_name/opt/com.hyprland-config.preview/raw"
OPTS=""
[ -r "$FW" ] && OPTS="$(tr -d '\0' < "$FW")"
opt() { printf '%s' "$OPTS" | tr ',' '\n' | sed -n "s/^$1=//p" | tail -n1; }
RUN_INSTALL="$(opt install)";   RUN_INSTALL="${RUN_INSTALL:-1}"
RUN_RICE_INIT="$(opt riceinit)"; RUN_RICE_INIT="${RUN_RICE_INIT:-1}"
note "OPTS=${OPTS:-none}"

# ---------------------------------------------------------------------------------------
# 1. The shares. `staging` is the config under test. `plugin` is this repo, and it is not
#    optional: the generated install.sh hands off to install-packages.sh, which refuses to
#    install anything at all when it cannot find install-record.sh.
# ---------------------------------------------------------------------------------------
mount_share() {
    mountpoint -q "$2" && return 0
    sudo mount -t 9p -o "trans=virtio,version=9p2000.L,ro,msize=262144" "$1" "$2" 2>/dev/null
}
mount_share staging /mnt/staging && note "MOUNT_staging=ok" || note "MOUNT_staging=failed"
mount_share plugin  /mnt/plugin  && note "MOUNT_plugin=ok"  || note "MOUNT_plugin=absent"

if ! mountpoint -q /mnt/staging; then
    note "SESSION=failed-no-staging"
    exec Hyprland
fi

# ---------------------------------------------------------------------------------------
# 2. Apply the staged config. No --reload: nothing is running yet to signal.
# ---------------------------------------------------------------------------------------
"$HOME/.local/bin/guest-apply.sh" | while read -r line; do note "$line"; done

# ---------------------------------------------------------------------------------------
# 3. The rice engine. Without it ~/.config/hypr-rice does not exist, and the palette,
#    templates, profiles, wallpaper theming and the `rice` CLI are all untestable.
# ---------------------------------------------------------------------------------------
export CLAUDE_PLUGIN_ROOT=/mnt/plugin
if [ "$RUN_RICE_INIT" = 1 ] && [ -f /mnt/plugin/skills/rice/scripts/rice-init.sh ]; then
    bash /mnt/plugin/skills/rice/scripts/rice-init.sh && note "RICE_INIT=ok" || note "RICE_INIT=failed"
else
    note "RICE_INIT=skipped"
fi

# ---------------------------------------------------------------------------------------
# 4. The generated install.sh, really run. This is what makes "the preview exercises the
#    install path" true rather than aspirational: a config that references a package it
#    forgot to install fails HERE instead of on your real machine.
# ---------------------------------------------------------------------------------------
if [ "$RUN_INSTALL" = 1 ] && [ -f /mnt/staging/install.sh ]; then
    note "INSTALL=running"
    bash /mnt/staging/install.sh && note "INSTALL=ok" || note "INSTALL=failed"
else
    note "INSTALL=skipped"
fi

# ---------------------------------------------------------------------------------------
# 5. Hyprland plugins. hyprpm builds each one from source against the running Hyprland's
#    headers, which is why the image carries a toolchain rather than just a compositor.
# ---------------------------------------------------------------------------------------
if [ -f "$HOME/.config/hypr/plugins.list" ] && command -v hyprpm >/dev/null 2>&1; then
    while read -r repo; do
        case "$repo" in ''|\#*) continue ;; esac
        hyprpm add "$repo" >/dev/null 2>&1 \
            && hyprpm enable "$(basename "$repo" .git)" >/dev/null 2>&1
    done < "$HOME/.config/hypr/plugins.list"
    hyprpm update >/dev/null 2>&1
    note "PLUGINS=$(wc -l < "$HOME/.config/hypr/plugins.list")"
else
    note "PLUGINS=none"
fi

note "SESSION=starting-compositor"
sync
exec Hyprland

#!/usr/bin/env bash
# Runs INSIDE the guest, once, to turn the stock Arch cloud image into a preview guest.
# Driven over ssh by `guestimage.provision`; the result is snapshotted as the cached base, so
# this cost is paid once per image rather than once per preview.
#
# WHAT GOES IN HERE, AND WHAT DOES NOT. Only what EVERY preview needs regardless of what the
# user picked: the compositor, the toolchain that lets a plugin or an AUR package build at all,
# and one terminal so a guest that installs nothing is still usable. Everything a rice actually
# chose - the bar, the launcher, the notification daemon, the fonts, the theme tooling - comes
# from the generated install.sh at boot. That is deliberate: it means the install path is
# exercised on every preview instead of being quietly replaced by a fat image that hides a
# package the config forgot to ask for.
set -uo pipefail

echo "PROVISION_PHASE=packages"

# base-devel + git + the build systems are the difference between "plugins are untestable" and
# "hyprpm can compile one": hyprpm builds every plugin from source against Hyprland's headers.
sudo pacman -Syu --noconfirm --needed \
        hyprland \
        kitty \
        base-devel \
        git \
        cmake \
        meson \
        ninja \
        pkgconf \
        jq \
        grim \
        wl-clipboard \
        mesa \
        python \
        sudo \
        which \
        ttf-jetbrains-mono-nerd \
        noto-fonts \
    || { echo "PROVISION=failed-packages"; exit 2; }

# ---------------------------------------------------------------------------------------
# An AUR helper. Without one, every AUR package in a generated install.sh fails, and a great
# deal of what people rice with lives only in the AUR.
# ---------------------------------------------------------------------------------------
echo "PROVISION_PHASE=aur-helper"
if ! command -v paru >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    if git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin" >/dev/null 2>&1 \
       && (cd "$tmp/paru-bin" && makepkg -si --noconfirm >/dev/null 2>&1); then
        echo "AUR_HELPER=paru-bin"
    else
        # Not fatal: a rice with no AUR packages still previews fine, and saying so beats
        # failing the whole image build.
        echo "AUR_HELPER=unavailable"
    fi
    rm -rf "$tmp"
else
    echo "AUR_HELPER=present"
fi

# ---------------------------------------------------------------------------------------
# The session. Autologin on tty1 is what gives Hyprland a real logind seat - an ssh session
# has none, and Hyprland will not start without one.
# ---------------------------------------------------------------------------------------
echo "PROVISION_PHASE=session"
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin preview --noclear %I $TERM
EOF

sudo mkdir -p /mnt/staging /mnt/plugin
sudo chown preview:preview /mnt/staging /mnt/plugin

# The session script itself is copied in beside this one, so it is reviewable in the repo
# rather than buried in a heredoc here.
install -Dm755 /tmp/guest-session.sh "$HOME/.local/bin/guest-session.sh"
cat > "$HOME/.bash_profile" <<'EOF'
# On tty1 the whole login session IS the preview. Everywhere else (ssh, a second tty) this
# file does nothing, so the control channel keeps working while the compositor runs.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "${XDG_VTNR:-}" = 1 ]; then
    exec "$HOME/.local/bin/guest-session.sh"
fi
EOF

sudo systemctl daemon-reload
sync
echo "PROVISION=ok"

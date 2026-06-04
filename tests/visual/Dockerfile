# Visual test image. Host compositor is **sway** (wlroots-based) running headlessly so the test
# does NOT need /dev/dri or a GPU on the CI runner. The components the rice flow styles —
# waybar, wofi, mako, kitty — render inside sway and are screenshotted with grim.
#
# Hyprland itself can't run headlessly on stock GitHub Actions runners (its Aquamarine backend
# needs a real DRM device), so the COMPOSITOR's own decoration (gaps, rounding, blur) is only
# previewed on a developer machine. The screenshots here exercise everything else.

FROM archlinux:base

RUN pacman -Syu --noconfirm --needed \
        sway \
        swaybg \
        waybar \
        kitty \
        mako \
        wofi \
        grim \
        slurp \
        jq \
        python \
        bash \
        coreutils \
        findutils \
        grep \
        sed \
        gawk \
        procps-ng \
        libcap \
        xorg-xwayland \
        ttf-jetbrains-mono-nerd \
        ttf-nerd-fonts-symbols \
        noto-fonts \
        noto-fonts-emoji \
        inter-font \
        otf-font-awesome \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/* \
    # Strip file capabilities from sway. Docker's default no-new-privileges flag turns binaries
    # with fcaps into EPERM on exec — even for root — so just remove them. We don't need
    # cap_sys_nice for headless rendering.
    && setcap -r /usr/bin/sway 2>/dev/null || true

# Run as root in this image. Sway's binary on Arch has file capabilities (cap_sys_nice+ep) that
# Docker's default security profile strips during a non-root exec — that exec then fails with
# "Operation not permitted". Running as root inside an ephemeral container avoids the entire
# problem; sway accepts root for headless test sessions. This image is test-only.
WORKDIR /root

ENV WLR_BACKENDS=headless \
    WLR_LIBINPUT_NO_DEVICES=1 \
    WLR_RENDERER=pixman \
    WLR_HEADLESS_OUTPUTS=1 \
    LIBSEAT_BACKEND=noop \
    XDG_RUNTIME_DIR=/tmp/runtime-root \
    XDG_CACHE_HOME=/root/.cache \
    HOME=/root \
    XDG_CURRENT_DESKTOP=sway

CMD ["bash"]

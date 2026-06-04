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
        xorg-xwayland \
        ttf-jetbrains-mono-nerd \
        ttf-nerd-fonts-symbols \
        noto-fonts \
        noto-fonts-emoji \
        inter-font \
        otf-font-awesome \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN useradd -m -s /bin/bash tester
USER tester
WORKDIR /home/tester

ENV WLR_BACKENDS=headless \
    WLR_LIBINPUT_NO_DEVICES=1 \
    WLR_RENDERER=pixman \
    WLR_HEADLESS_OUTPUTS=1 \
    XDG_RUNTIME_DIR=/tmp/runtime-tester \
    XDG_CACHE_HOME=/home/tester/.cache \
    XDG_CURRENT_DESKTOP=sway

CMD ["bash"]

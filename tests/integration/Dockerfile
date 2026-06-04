# Arch base with Hyprland + the companions the rice flow installs.
# Used by tests/test_integration_docker.sh — runs Hyprland headlessly so the live
# `hyprctl reload` + `configerrors` checks can actually execute (the heart of safe-apply.sh).
#
# Build:  docker build -t hyprland-config-test tests/integration
# Run:    handled by tests/test_integration_docker.sh

FROM archlinux:base

# Refresh keyring + install everything. wlroots' headless backend lets Hyprland start with no
# GPU/DRM available, which is what makes this image runnable on CI without --privileged.
RUN pacman -Syu --noconfirm --needed \
        hyprland \
        waybar \
        kitty \
        mako \
        wofi \
        jq \
        python \
        bash \
        coreutils \
        findutils \
        grep \
        sed \
        gawk \
        procps-ng \
        git \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

# Non-root user (Hyprland refuses to launch as root in some builds, and matches user use case).
RUN useradd -m -s /bin/bash tester
USER tester
WORKDIR /home/tester

# Headless wlroots backend + a runtime dir Hyprland can write its socket+log into.
# WLR_HEADLESS_OUTPUTS=1 — without at least one virtual output the compositor backend fails to
# create (the symptom is "CBackend::create() failed!" on startup).
ENV WLR_BACKENDS=headless \
    WLR_LIBINPUT_NO_DEVICES=1 \
    WLR_RENDERER=pixman \
    WLR_HEADLESS_OUTPUTS=1 \
    XDG_RUNTIME_DIR=/tmp/runtime-tester \
    XDG_CACHE_HOME=/home/tester/.cache \
    HYPRLAND_NO_RT=1 \
    HYPRLAND_NO_SD_NOTIFY=1 \
    XDG_CURRENT_DESKTOP=Hyprland

# The orchestrator mounts the plugin at /plugin and the in-container test script at
# /home/tester/run.sh. The container's CMD is overridden by `docker run` to call the script.
CMD ["bash"]

# Sources - skills/rice/references/components/env/styling.md

Research provenance for `skills/rice/references/components/env/styling.md`.

Extracted from the load path: these citations are why the recommendations in that
file are what they are, and are read by a human reviewing them - never by an agent
authoring a config.

## Sources

- Hyprland env-vars wiki: <https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/>
- Hyprland 0.54 Keywords wiki (envd flag): <https://wiki.hypr.land/0.54.0/Configuring/Keywords/>
- Hyprland NVIDIA wiki (slim 4 vars + ELECTRON_OZONE_PLATFORM_HINT + NVD_BACKEND gating): <https://wiki.hypr.land/Nvidia/>
- Hyprland upstream `example/hyprland.lua` (XCURSOR_SIZE / HYPRCURSOR_SIZE = 24 default): <https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua>
- uwsm readme §4 Environments and Shell Profile: <https://github.com/Vladimir-csp/uwsm#4-environments-and-shell-profile>
- hyprqt6engine: <https://wiki.hypr.land/Hypr-Ecosystem/hyprqt6engine/>
- hyprcursor: <https://wiki.hypr.land/Hypr-Ecosystem/hyprcursor/>
- elFarto/nvidia-vaapi-driver (MOZ_DISABLE_RDD_SANDBOX + NVD_BACKEND): <https://github.com/elFarto/nvidia-vaapi-driver>

**Config corpus read for the patterns catalog:**
- Matt-FTW/dotfiles `.config/hypr/configs/env.conf` (envd= for XDG; full toolkit block; hard-coded GTK_THEME + matched XCURSOR/HYPRCURSOR): <https://github.com/Matt-FTW/dotfiles>
- caelestia-dots/caelestia `hypr/hyprland/env.conf` (sectioned env.conf; `$cursorTheme`/`$cursorSize` variable indirection; hyprqt6engine; SDL fallback chain): <https://github.com/caelestia-dots/caelestia>
- linuxmobile/hyprland-dots `.config/hypr/env.conf` (legacy WLR_NO_HARDWARE_CURSORS / OZONE_PLATFORM examples + MOZ_DISABLE_RDD_SANDBOX): <https://github.com/linuxmobile/hyprland-dots>
- dusklinux/dusky `.config/uwsm/{env,env-hyprland}` and `.config/hypr/source/environment_variables.lua` (canonical uwsm split; only XDG_CURRENT_DESKTOP in hyprland.lua): <https://github.com/dusklinux/dusky>
- JaKooLit/Hyprland-Dots `config/hypr/UserConfigs/ENVariables.conf` (commented-out menu pattern; GSK_RENDERER,ngl for NVIDIA GTK4; MOZ_DISABLE_RDD_SANDBOX for Firefox VA-API; aquamarine env vars list): <https://github.com/JaKooLit/Hyprland-Dots>
- end-4/dots-hyprland `dots/.config/hypr/hyprland/env.lua` + `execs.lua` (Quickshell-flavored env: ELECTRON_OZONE_PLATFORM_HINT + XDG_DATA_DIRS flatpak fix + dbus-update-activation-environment --all): <https://github.com/end-4/dots-hyprland>
- mylinuxforwork/dotfiles `dotfiles/.config/hypr/conf/environments/{default,nvidia}.lua` (per-GPU env profile pattern): <https://github.com/mylinuxforwork/dotfiles>
- koeqaife/hyprland-material-you `hypryou-assets/greeter/hyprland.conf` (XDG + GDK_SCALE + XCURSOR_SIZE + bare-name dbus-update-activation-environment): <https://github.com/koeqaife/hyprland-material-you>

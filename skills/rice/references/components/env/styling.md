# env — styling

env is a structural component, but the **cursor / GTK / Qt** entries it owns are *the*
toolkit-coherence floor for the rice — getting them wrong is what makes a desktop "look alien"
on Electron apps, blank on Java apps, or stutter on Qt apps. This file is the corpus-derived
catalog of the patterns popular rices use so the rice's `env.conf` ships with the same shape
as the community baseline.

## How the community ships env.conf — five real rices side by side

Five top corpus rices that have a *dedicated* env file (not just inline `env =` lines), in order
of population.

**Matt-FTW/dotfiles** — `.config/hypr/configs/env.conf` (a single sourced file):

```ini
# XDG
envd = XDG_CURRENT_DESKTOP, Hyprland
envd = XDG_SESSION_TYPE, wayland
envd = XDG_SESSION_DESKTOP, Hyprland

# QT
env = QT_QPA_PLATFORM, wayland
env = QT_QPA_PLATFORMTHEME, qt5ct
env = QT_WAYLAND_DISABLE_WINDOWDECORATION, 1
env = QT_AUTO_SCREEN_SCALE_FACTOR, 1
env = QT_STYLE_OVERRIDE, kvantum

# Force Wayland
env = GDK_BACKEND,wayland,x11,*
env = QT_QPA_PLATFORM,wayland;xcb
env = SDL_VIDEODRIVER,wayland
env = CLUTTER_BACKEND,wayland
env = ELECTRON_OZONE_PLATFORM_HINT,auto

# Themes
env = GTK_THEME, catppuccin-macchiato-lavender-standard+default
env = XCURSOR_THEME, catppuccin-macchiato-dark-cursors
env = XCURSOR_SIZE, 24
env = HYPRCURSOR_THEME, catppuccin-macchiato-dark-cursors
env = HYPRCURSOR_SIZE, 24
```

Note three things: (a) **`envd =` for XDG** vars (pushes into DBus activation env), (b) **both**
XCURSOR_THEME *and* HYPRCURSOR_THEME set to the same value, (c) the `# Themes` block hard-codes
catppuccin theme names — works because Matt-FTW is a single hand-curated theme. For a
palette-driven engine, the theme block stays in `gsettings`/`gtk.css`, not env. Source:
<https://github.com/Matt-FTW/dotfiles/blob/HEAD/.config/hypr/configs/env.conf>.

**caelestia-dots/caelestia** — `hypr/hyprland/env.conf`:

```ini
# ############# Themes #############
env = QT_QPA_PLATFORMTHEME, qtengine
env = QT_WAYLAND_DISABLE_WINDOWDECORATION, 1
env = QT_AUTO_SCREEN_SCALE_FACTOR, 1
env = XCURSOR_THEME, $cursorTheme
env = XCURSOR_SIZE, $cursorSize

# ######## Toolkit backends ########
env = GDK_BACKEND, wayland,x11
env = QT_QPA_PLATFORM, wayland;xcb
env = SDL_VIDEODRIVER, wayland,x11,windows
env = CLUTTER_BACKEND, wayland
env = ELECTRON_OZONE_PLATFORM_HINT, auto

# ####### XDG specifications #######
env = XDG_CURRENT_DESKTOP, Hyprland
env = XDG_SESSION_TYPE, wayland
env = XDG_SESSION_DESKTOP, Hyprland

# ############# Others #############
env = _JAVA_AWT_WM_NONREPARENTING, 1
```

caelestia uses `$cursorTheme` / `$cursorSize` Hyprland variables defined in
`hypr/variables.conf` — the rice indirection that lets one variable file drive the env. The
`SDL_VIDEODRIVER, wayland,x11,windows` fallback chain is unusual but useful (covers Steam Proton
games). The `QT_QPA_PLATFORMTHEME, qtengine` value points at
[`hyprqt6engine`](https://wiki.hypr.land/Hypr-Ecosystem/hyprqt6engine/) — a Hyprland-native Qt
platform engine that's an alternative to qt6ct. Source:
<https://github.com/caelestia-dots/caelestia/blob/HEAD/hypr/hyprland/env.conf>.

**linuxmobile/hyprland-dots (kenos)** — `.config/hypr/env.conf`:

```ini
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland

env = GDK_BACKEND,wayland
env = QT_QPA_PLATFORM,wayland
env = QT_QPA_PLATFORMTHEME,qt5ct
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = QT_AUTO_SCREEN_SCALE_FACTOR,1

env = SDL_VIDEODRIVER,wayland
env = _JAVA_AWT_WM_NONREPARENTING,1
env = WLR_NO_HARDWARE_CURSORS,1                   # legacy — see gotchas
env = MOZ_DISABLE_RDD_SANDBOX,1                   # for nvidia + firefox VA-API
env = MOZ_ENABLE_WAYLAND,1
env = OZONE_PLATFORM,wayland                      # legacy — wiki uses ELECTRON_OZONE_PLATFORM_HINT
env = wallpaper_path,$HOME/.wallpapers
```

A "stale community config" — ships `WLR_NO_HARDWARE_CURSORS,1` (Hyprland is on aquamarine now,
no-op) and `OZONE_PLATFORM,wayland` (older form; `ELECTRON_OZONE_PLATFORM_HINT,auto` is the
2025+ recommendation per the NVIDIA wiki). Worth citing as evidence the validator should warn
on these. Source: <https://github.com/linuxmobile/hyprland-dots/blob/HEAD/.config/hypr/env.conf>.

**dusklinux/dusky** — uses uwsm exclusively; its `~/.config/uwsm/env` is the source of truth and
its `hyprland.lua` only sets `XDG_CURRENT_DESKTOP` (the wiki says uwsm sets it but a single
warning needed pinning):

```lua
-- hyprland.lua
hl.config({
    -- this one environment variable is set here to fix a warning caused by hyprland on boot.
    env = {
        [[XDG_CURRENT_DESKTOP,Hyprland]]
    }
})
```

```sh
# ~/.config/uwsm/env (excerpts)
export QT_QPA_PLATFORM="wayland;xcb"
export QT_QPA_PLATFORMTHEME=qt6ct
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export QT_AUTO_SCREEN_SCALE_FACTOR=1
export GDK_BACKEND="wayland,x11"
export QT_QUICK_CONTROLS_STYLE=Fusion
export _JAVA_AWT_WM_NONREPARENTING=1
export XCURSOR_THEME=Bibata-Modern-Classic
export XCURSOR_SIZE=18
export SDL_VIDEODRIVER="wayland,x11"
export CLUTTER_BACKEND=wayland
```

```sh
# ~/.config/uwsm/env-hyprland (excerpts)
export DESKTOP_SESSION=hyprland-uwsm
export HYPRCURSOR_SIZE=18
```

Two things to copy: (a) the *quotes are critical* around values with `;` (`"wayland;xcb"`) —
the shell would interpret the `;` as a command separator otherwise. (b) **The uwsm split is
real** — `env` for compositor-agnostic vars, `env-hyprland` for `HYPR*` and `AQ_*` vars per the
wiki. Source: <https://github.com/dusklinux/dusky/blob/HEAD/.config/uwsm/env> +
`.config/uwsm/env-hyprland`.

**JaKooLit/Hyprland-Dots** — `config/hypr/UserConfigs/ENVariables.conf` (the *defaults* are
all commented out; the file is a menu, not a config):

```ini
### QT Variables ###
# env = QT_AUTO_SCREEN_SCALE_FACTOR,1
# env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
# env = QT_QPA_PLATFORMTHEME,qt5ct
# env = QT_QPA_PLATFORMTHEME,qt6ct

### xwayland apps scale fix ###
# env = GDK_SCALE,1
# env = QT_SCALE_FACTOR,1

### NVIDIA ###
#env = LIBVA_DRIVER_NAME,nvidia
#env = __GLX_VENDOR_LIBRARY_NAME,nvidia
#env = NVD_BACKEND,direct
#env = GSK_RENDERER,ngl                       # <-- THE GTK4 NVIDIA fix
…
### nvidia firefox ###
#env = MOZ_DISABLE_RDD_SANDBOX,1
#env = EGL_PLATFORM,wayland

### Aquamarine Environment Variables (Hyprland > 0.45) ###
# env = AQ_TRACE,1
# env = AQ_DRM_DEVICES,/dev/dri/card1:/dev/dri/card0
# env = AQ_MGPU_NO_EXPLICIT,1
# env = AQ_NO_MODIFIERS,1
```

JaKooLit's whole pattern is "the defaults are in `configs/ENVariables.conf` (sourced first), the
overrides are in `UserConfigs/ENVariables.conf`" — and the latter ships entirely commented.
**`GSK_RENDERER,ngl`** in the NVIDIA block is the next-gen GTK4 Vulkan renderer that fixes
GTK4 crashes on the proprietary NVIDIA driver — not in the slim 4 the wiki recommends but
worth flagging for `NVIDIA_PROPRIETARY=1` + GTK4 crash reports. Source:
<https://github.com/JaKooLit/Hyprland-Dots/blob/HEAD/config/hypr/UserConfigs/ENVariables.conf>.

## Battle-tested techniques (from real rices)

**Cross-toolkit cursor coherence: set XCURSOR + HYPRCURSOR to the same theme+size.**
(caelestia, Matt-FTW, hyprdots) — the **XCURSOR_THEME**/**XCURSOR_SIZE** pair drives XWayland
and GTK fallback cursors; **HYPRCURSOR_THEME**/**HYPRCURSOR_SIZE** drives the native
[hyprcursor](https://wiki.hypr.land/Hypr-Ecosystem/hyprcursor/) cursor plane. **Sizes must
match**: a mismatched pair causes a "jumping cursor" the moment focus crosses an XWayland
window. Pin both, and run `hyprctl setcursor <theme> <size>` from `exec-once` (handled by
`companion-daemons`) so the running session catches up before the first app launches. The
upstream `example/hyprland.lua` ships `XCURSOR_SIZE,24` + `HYPRCURSOR_SIZE,24` — that's the
corpus consensus default we adopt.

**`envd =` for portal-handshake vars.** (Matt-FTW) — `XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE`,
`XDG_SESSION_DESKTOP` *all* use `envd =` (D-Bus push), not `env =`. The pre-0.55 hyprlang
wiki: *"You can also add a `d` flag if you want the env var to be exported to D-Bus (systemd
only)."* This is what makes `xdg-desktop-portal-hyprland` pick the right backend on first
launch without a separate `dbus-update-activation-environment`. On 0.55+ Lua, `hl.env()`
already does this — see `gotchas.md`.

**The seven-line "Wayland-everywhere" toolkit block.** (caelestia, dusky, linuxmobile) — at
minimum:

```ini
env = GDK_BACKEND,wayland,x11,*
env = QT_QPA_PLATFORM,wayland;xcb
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = QT_AUTO_SCREEN_SCALE_FACTOR,1
env = SDL_VIDEODRIVER,wayland
env = CLUTTER_BACKEND,wayland
env = _JAVA_AWT_WM_NONREPARENTING,1
```

The first four are wiki-recommended in the Toolkit Backend Variables + Qt Variables sections.
SDL2 and Clutter are application-runtime hints (games / GNOME-stack apps). `_JAVA_AWT_WM_NONREPARENTING`
is the long-standing JDK fix for blank Java AWT windows on tiling Wayland compositors. Our
`toolkit` interview gate now emits this whole block as a unit so the user picks one box and
gets the whole "Wayland-everywhere" set.

**`ELECTRON_OZONE_PLATFORM_HINT,auto` is GPU-agnostic.** (Hyprland NVIDIA wiki, caelestia,
dusky, linuxmobile) — the older guidance bundled it with NVIDIA, but the wiki is clear it's
safe on any GPU and fixes flicker on Vesktop, VSCodium, Obsidian. Pre-Electron-35 this is the
fix; Electron 35+ apps prefer the per-app `--enable-features=WaylandLinuxDrmSyncobj` flag
(out of env scope; document under default-apps).

**Quote env values with semicolons in shell-sourced files.** (dusky `~/.config/uwsm/env`) —
`export QT_QPA_PLATFORM="wayland;xcb"` not `export QT_QPA_PLATFORM=wayland;xcb`. The unquoted
form makes the shell interpret `;` as a command separator and silently run an empty `xcb`. In
the `env.conf` hyprlang form there are no shell quotes (everything after the first comma is
the literal value), so this only bites when mirroring vars into `~/.config/uwsm/env`.

**uwsm splits compositor-agnostic vars (`env`) from compositor-specific ones (`env-hyprland`).**
(dusky, ml4w via comment, wiki) — `~/.config/uwsm/env` holds GTK/Qt/SDL/Java/`XCURSOR_*` (apps
that run under any compositor); `~/.config/uwsm/env-hyprland` holds `HYPR*` and `AQ_*` (only
makes sense under Hyprland). This split is important because uwsm exports them at *different*
stages — the `env` file before the compositor starts (so DBus activation sees them), the
`env-hyprland` file alongside Hyprland's own startup.

**`hyprctl setcursor` from `exec-once` to backfill the live session.** (end-4, Matt-FTW,
koeqaife) — env vars set in `env.conf` only reach processes *spawned by Hyprland after env.conf
is read*. The compositor's own cursor pipeline doesn't re-read env on `hyprctl reload`. So:
`exec-once = hyprctl setcursor <theme> <size>` ensures the visible cursor matches the new env
without a relog. (Owned by `companion-daemons`, called out here because it's coupled with
`XCURSOR_THEME` / `HYPRCURSOR_THEME`.)

**Wallpaper-tool path-stash anti-pattern.** (linuxmobile) —
`env = wallpaper_path,$HOME/.wallpapers` is *not* an env var in the Wayland sense, it's a
Hyprland config variable hyprlang resolves with `$wallpaper_path` later. It still ends up
exported to child processes' env, polluting their namespace. Use `$wallpaper_path =
$HOME/.wallpapers` (the variable keyword) instead of `env =`. Worth a validator warning on any
`env = wallpaper_*` or `env = *_path` line.

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

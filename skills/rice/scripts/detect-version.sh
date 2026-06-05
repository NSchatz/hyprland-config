#!/usr/bin/env bash
# Detect the installed Hyprland version.
# Prints: HYPR_VERSION=<x.y.z>  (or HYPR_VERSION=unknown)
# Also prints HYPR_SOURCE=<how it was detected> for context.
set -uo pipefail

version=""
source=""

# Preferred: query a running instance.
if command -v hyprctl >/dev/null 2>&1; then
    # `hyprctl version` output contains e.g. "Hyprland 0.45.2 built from branch ..."
    raw="$(hyprctl version 2>/dev/null | head -n 20)"
    version="$(printf '%s\n' "$raw" | grep -oiE 'v?[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 | sed 's/^v//')"
    [ -n "$version" ] && source="hyprctl"
fi

# Fallback: the binary itself (works without a running session).
if [ -z "$version" ] && command -v Hyprland >/dev/null 2>&1; then
    raw="$(Hyprland --version 2>/dev/null | head -n 20)"
    version="$(printf '%s\n' "$raw" | grep -oiE 'v?[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 | sed 's/^v//')"
    [ -n "$version" ] && source="Hyprland --version"
fi

if [ -n "$version" ]; then
    echo "HYPR_VERSION=${version}"
    echo "HYPR_SOURCE=${source}"
else
    echo "HYPR_VERSION=unknown"
    echo "HYPR_SOURCE=none (hyprctl/Hyprland not found — assume latest stable syntax)"
fi

# Protocol-capability flags downstream branches on (better than parsing the version string
# again per-consumer). Currently emitted: HYPR_HAS_EXT_BG_EFFECT_V1 — true at the May-2026
# implementation of ext-background-effect-v1 (commit 7d1e481, ~v0.50+). Walker uses this
# protocol for `ext_background_effect_blur`; on older Hyprland the flag silently no-ops,
# leaving a `layerrule = blur, walker` line as the only path. See
# `references/theming/engine.md` → "walker blur via ext-background-effect-v1".
emit_capabilities() {
    local v="$1" major minor
    [ -z "$v" ] || [ "$v" = "unknown" ] && { echo "HYPR_HAS_EXT_BG_EFFECT_V1=unknown"; return; }
    # v is x.y.z; treat anything ≥ 0.50.x OR ≥ 1.0 as supporting the protocol.
    major="${v%%.*}"; minor="${v#*.}"; minor="${minor%%.*}"
    if [ "${major:-0}" -ge 1 ] 2>/dev/null || \
       { [ "${major:-0}" -eq 0 ] 2>/dev/null && [ "${minor:-0}" -ge 50 ] 2>/dev/null; }; then
        echo "HYPR_HAS_EXT_BG_EFFECT_V1=1"
    else
        echo "HYPR_HAS_EXT_BG_EFFECT_V1=0"
    fi
}
emit_capabilities "$version"

# Probe common ecosystem packages so the install batch (A3d) can annotate already-present packages
# with `# installed` and the safe-apply step can skip work that's already done. The interview does
# NOT use these flags to filter options — every user sees the same menu.
# Reports HAVE_<tool>=1 (present) or MISSING_<tool>=1 (absent). Maps package name -> a
# representative binary where they differ. Detection only — installs nothing.
have_pkg() {
    # $1 = label, $2 = binary to look for (defaults to $1), $3 = pacman pkg (optional)
    local label="$1" bin="${2:-$1}" pkg="${3:-}"
    if command -v "$bin" >/dev/null 2>&1; then
        echo "HAVE_${label}=1"; return
    fi
    if [ -n "$pkg" ] && command -v pacman >/dev/null 2>&1 && pacman -Qq "$pkg" >/dev/null 2>&1; then
        echo "HAVE_${label}=1"; return
    fi
    echo "MISSING_${label}=1"
}

# label                binary                  pacman-pkg (if different / no binary)
have_pkg hyprpaper      hyprpaper
have_pkg hyprlock       hyprlock
have_pkg hypridle       hypridle
have_pkg hyprpicker     hyprpicker
have_pkg hyprshot       hyprshot
have_pkg hyprsunset     hyprsunset
have_pkg hyprpolkitagent ""                    hyprpolkitagent
have_pkg portal_hyprland ""                    xdg-desktop-portal-hyprland
have_pkg portal_gtk     ""                     xdg-desktop-portal-gtk
have_pkg waybar         waybar
have_pkg hyprpanel      hyprpanel
have_pkg wofi           wofi
have_pkg rofi           rofi
have_pkg fuzzel         fuzzel
have_pkg mako           mako
have_pkg dunst          dunst
have_pkg swaync         swaync
# Wallpaper daemon: upstream `swww`, or its maintained fork `awww` (declares
# `provides=swww`, so `pacman -Qq swww` succeeds — but it ships `awww`/`awww-daemon`
# binaries, NOT `swww`/`swww-daemon`). Detect the real binary so autostart emits a
# command that actually exists, and report it via SWWW_DAEMON_BIN/SWWW_CLIENT_BIN.
if command -v swww-daemon >/dev/null 2>&1; then
    echo "HAVE_swww=1"; echo "SWWW_DAEMON_BIN=swww-daemon"; echo "SWWW_CLIENT_BIN=swww"
elif command -v awww-daemon >/dev/null 2>&1; then
    echo "HAVE_swww=1"; echo "SWWW_DAEMON_BIN=awww-daemon"; echo "SWWW_CLIENT_BIN=awww"
else
    echo "MISSING_swww=1"
fi
have_pkg grimblast      grimblast
have_pkg grim           grim
have_pkg slurp          slurp
have_pkg satty          satty
have_pkg cliphist       cliphist
have_pkg wl_clipboard   wl-copy                 wl-clipboard
have_pkg wlogout        wlogout
have_pkg swayosd        swayosd-server          swayosd
have_pkg brightnessctl  brightnessctl
have_pkg playerctl      playerctl
have_pkg nm_applet      nm-applet               network-manager-applet
have_pkg blueman        blueman-applet          blueman
have_pkg qt6ct          qt6ct
have_pkg nwg_look       nwg-look
# Utility-menu / screenshot-menu tooling (Group 18 "Utilities & menus")
have_pkg tesseract      tesseract               tesseract        # OCR (grab on-screen text)
have_pkg bemoji         bemoji                                   # emoji picker
have_pkg wf_recorder    wf-recorder                              # screen recorder (CLI)
have_pkg wl_screenrec   wl-screenrec                             # HW-accelerated recorder
have_pkg swappy         swappy                                   # screenshot annotation (alt to satty)
have_pkg kanshi         kanshi                                   # auto monitor profiles (dock/undock)
have_pkg shikane        shikane                                  # kanshi successor

# --- Session env manager: uwsm (Universal Wayland Session Manager) ---
# When Hyprland is launched via uwsm, ~/.config/uwsm/env (+ env-hyprland) is the AUTHORITATIVE
# session-environment source: it is exported before the compositor starts and OVERRIDES hypr
# `env.conf` for app launches — notably GTK_THEME, XCURSOR_THEME/HYPRCURSOR_THEME, and QT_*.
# So any cursor/GTK/toolkit env change must edit THOSE files too, not just env.conf/gsettings,
# or GTK apps keep the old theme. Report the env files so the rice skill knows to update them.
if command -v uwsm >/dev/null 2>&1; then echo "HAVE_uwsm=1"; else echo "MISSING_uwsm=1"; fi
[ -f "$HOME/.config/uwsm/env" ]          && echo "UWSM_ENV=$HOME/.config/uwsm/env"
[ -f "$HOME/.config/uwsm/env-hyprland" ] && echo "UWSM_ENV_HYPRLAND=$HOME/.config/uwsm/env-hyprland"
# Active uwsm-managed session? (the systemd user unit is named wayland-wm@<compositor>.service)
if systemctl --user list-units --type=service --state=active 2>/dev/null | grep -q 'wayland-wm@'; then
    echo "UWSM_SESSION=1"
fi

# --- Active GPU driver (decides whether the proprietary NVIDIA env block is appropriate) ---
# An NVIDIA *card* does NOT imply the proprietary driver. Many systems run the open `nouveau`
# driver, under which `LIBVA_DRIVER_NAME=nvidia` / `__GLX_VENDOR_LIBRARY_NAME=nvidia` /
# `NVD_BACKEND=direct` BREAK GLX and VA-API. So the rice interview must key the NVIDIA
# env block on the *loaded driver*, not on lspci's vendor string. Emit:
#   NVIDIA_PROPRIETARY=1  -> only when the proprietary `nvidia` kmod is actually loaded
#   GPU_DRIVER=<name>     -> nvidia | nouveau | amdgpu | radeon | i915 | unknown
have_mod() { lsmod 2>/dev/null | grep -q "^$1[[:space:]]"; }
gpu_bound=""   # kernel driver bound to the first display controller, per lspci
if command -v lspci >/dev/null 2>&1; then
    gpu_bound="$(lspci -k 2>/dev/null | awk '
        /VGA compatible controller|3D controller|Display controller/{f=1}
        f && /Kernel driver in use:/{print $NF; exit}')"
    vga="$(lspci 2>/dev/null | grep -iE 'vga compatible controller|3d controller' \
            | head -n1 | sed 's/^[0-9a-f:.]* //')"
    [ -n "$vga" ] && echo "GPU_DEVICE=${vga}"
fi
if have_mod nvidia || command -v nvidia-smi >/dev/null 2>&1; then
    echo "GPU_DRIVER=nvidia"
    echo "NVIDIA_PROPRIETARY=1"
    # NVIDIA (proprietary) and nouveau both have flaky hardware-cursor planes — the cursor can
    # vanish/flicker when the screen is idle. Recommend software cursors (cursor:no_hardware_cursors).
    echo "CURSOR_NO_HARDWARE_RECOMMENDED=1"
elif have_mod nouveau || [ "$gpu_bound" = "nouveau" ]; then
    echo "GPU_DRIVER=nouveau"
    echo "NVIDIA_PROPRIETARY=0"   # NVIDIA card but OPEN driver — do NOT set proprietary env
    echo "CURSOR_NO_HARDWARE_RECOMMENDED=1"   # nouveau blanks the HW cursor when idle
elif [ -n "$gpu_bound" ]; then
    echo "GPU_DRIVER=${gpu_bound}"   # amdgpu / radeon / i915 / etc.
    echo "NVIDIA_PROPRIETARY=0"
else
    echo "GPU_DRIVER=unknown"
fi

# --- Chassis / power shape (the laptop-only interview group self-skips on desktops) ---
# DMI chassis_type: 8 Portable, 9 Laptop, 10 Notebook, 14 Sub-Notebook, 31 Convertible,
# 32 Detachable. Fall back to a battery node when DMI is missing/unreliable (VMs, OEM quirks).
chassis="$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)"
case " 8 9 10 14 31 32 " in
    *" ${chassis} "*) echo "IS_LAPTOP=1" ;;
    *) if ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then echo "IS_LAPTOP=1"; else echo "IS_LAPTOP=0"; fi ;;
esac
# Battery present (gates the optional charge-threshold offer)
ls /sys/class/power_supply/BAT* >/dev/null 2>&1 && echo "HAVE_BATTERY=1"
# Lid switch present (gates the lid-close action question)
[ -d /proc/acpi/button/lid ] && echo "HAVE_LID=1"

# --- Monitor count (the Monitors group expands to dock/per-monitor questions when >1) ---
if command -v hyprctl >/dev/null 2>&1; then
    mc="$(hyprctl monitors -j 2>/dev/null | grep -c '"name":')"
    [ "${mc:-0}" -gt 0 ] 2>/dev/null && echo "MONITOR_COUNT=${mc}"
fi

# --- Power-profile tool (laptop power group; the three are mutually exclusive — report which) ---
if command -v powerprofilesctl >/dev/null 2>&1; then echo "POWER_TOOL=power-profiles-daemon"
elif command -v tlp >/dev/null 2>&1;            then echo "POWER_TOOL=tlp"
elif command -v auto-cpufreq >/dev/null 2>&1;   then echo "POWER_TOOL=auto-cpufreq"
else echo "POWER_TOOL=none"; fi

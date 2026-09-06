#!/usr/bin/env bash
# Detect the installed Hyprland version.
# Prints: HYPR_VERSION=<x.y.z>  (or HYPR_VERSION=unknown)
# Also prints HYPR_SOURCE=<how it was detected> for context.
set -uo pipefail

# Config-path library, for the uwsm session-env files reported further down. Optional here:
# this script only READS, so a missing library degrades to the historical $HOME/.config path
# rather than stopping a version detection that has nothing to do with it.
_xdg_lib=""
for _c in "$(cd "$(dirname "$0")" && pwd)/xdg-config.sh" \
          "$(cd "$(dirname "$0")" && pwd)/../../../scripts/xdg-config.sh" \
          "${CLAUDE_PLUGIN_ROOT:-}/scripts/xdg-config.sh"; do
    if [ -n "$_c" ] && [ -f "$_c" ]; then _xdg_lib="$_c"; break; fi
done
if [ -n "$_xdg_lib" ]; then
    # shellcheck source=../../../scripts/xdg-config.sh
    . "$_xdg_lib"
fi

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
    # Do NOT assume a syntax here. Since 0.55 the config LANGUAGE is a version
    # cliff (hyprlang .conf vs hyprland.lua), and guessing it wrong produces a
    # config the compositor never reads. `config-language.sh` turns an unknown
    # version into an explicit choice instead of a guess.
    echo "HYPR_VERSION=unknown"
    echo "HYPR_SOURCE=none (hyprctl/Hyprland not found; the config language cannot be assumed - see config-language.sh)"
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
# When Hyprland is launched via uwsm, <config base>/uwsm/env (+ env-hyprland) is the AUTHORITATIVE
# session-environment source: it is exported before the compositor starts and OVERRIDES hypr
# `env.conf` for app launches — notably GTK_THEME, XCURSOR_THEME/HYPRCURSOR_THEME, and QT_*.
# So any cursor/GTK/toolkit env change must edit THOSE files too, not just env.conf/gsettings,
# or GTK apps keep the old theme. Report the env files so the rice skill knows to update them.
if command -v uwsm >/dev/null 2>&1; then echo "HAVE_uwsm=1"; else echo "MISSING_uwsm=1"; fi
# uwsm reads these from the XDG config base like every other XDG-aware program, so this
# reports them from the base the rest of the plugin resolves (scripts/xdg-config.sh).
if ! _uwsm_dir="$(xdg_config_path uwsm 2>/dev/null)" || [ -z "$_uwsm_dir" ]; then
    _uwsm_dir="${HOME:-}/.config/uwsm"   # XDG-OK: last-resort fallback when the library is absent
fi
[ -f "$_uwsm_dir/env" ]          && echo "UWSM_ENV=$_uwsm_dir/env"
[ -f "$_uwsm_dir/env-hyprland" ] && echo "UWSM_ENV_HYPRLAND=$_uwsm_dir/env-hyprland"
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
nvidia_gen_for_device() {
    # $1 = lower-cased hex device id (no `0x`, no spaces). Returns one of:
    #   blackwell|ada|ampere|turing|volta|pascal|maxwell|kepler|fermi|tesla|unknown
    local d="$1"
    case "$d" in
        # Blackwell  GB20x — 5xxx series (and some workstation parts)
        29[0-9a-f][0-9a-f]|2a[0-9a-f][0-9a-f]|2b[0-9a-f][0-9a-f]) echo blackwell ;;
        # Ada Lovelace AD10x — 4xxx series
        26[0-9a-f][0-9a-f]|27[0-9a-f][0-9a-f]|28[0-9a-f][0-9a-f]) echo ada ;;
        # Ampere    GA10x — 3xxx series (+ A100/A40 workstation)
        20[0-9a-f][0-9a-f]|21[0-9a-f][0-9a-f]|22[0-9a-f][0-9a-f]|23[0-9a-f][0-9a-f]|24[0-9a-f][0-9a-f]|25[0-9a-f][0-9a-f]) echo ampere ;;
        # Turing    TU10x — 1660 / 2xxx series, T4
        1e[0-9a-f][0-9a-f]|1f[0-9a-f][0-9a-f]) echo turing ;;
        # Volta     GV100 — Titan V / V100
        1d[0-9a-f][0-9a-f]) echo volta ;;
        # Pascal    GP10x — 1xxx series (1050/1060/1070/1080/Titan Xp)
        1b[0-9a-f][0-9a-f]|1c[0-9a-f][0-9a-f]) echo pascal ;;
        # Maxwell   GM10x/GM20x — 750 / 9xx series / Titan X
        13[0-9a-f][0-9a-f]|14[0-9a-f][0-9a-f]) echo maxwell ;;
        # Kepler    GK10x — 6xx / 7xx series
        0f[0-9a-f][0-9a-f]|10[0-9a-f][0-9a-f]|11[0-9a-f][0-9a-f]|12[0-9a-f][0-9a-f]) echo kepler ;;
        # Fermi     GF10x — 4xx / 5xx / Quadro 4000-6000
        06[0-9a-f][0-9a-f]|0d[0-9a-f][0-9a-f]|0e[0-9a-f][0-9a-f]) echo fermi ;;
        *) echo unknown ;;
    esac
}
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

# NVIDIA generation → driver branch (defect #15). Repos now ship only `nvidia-open` /
# `nvidia-open-dkms` (Turing+, capability ≥ 7.5); Maxwell / Pascal / Volta land on the AUR
# `nvidia-580xx-*` legacy branch (DKMS, needs `linux-headers`); Kepler and older need older
# branches. The `nvidia` package no longer exists for non-Turing+ GPUs. Map by PCI device-id
# range so the rice picks the right package — `components/env/gotchas.md` documents each
# branch. Always emit when an NVIDIA card is *present* (regardless of which driver is loaded),
# so the env writer can warn an nvidia-driver user on a Pascal box that they need the legacy
# branch, not the missing `nvidia` package.
if command -v lspci >/dev/null 2>&1; then
    nvidia_dev="$(lspci -nn 2>/dev/null | awk -F'[][]' '
        /VGA compatible controller|3D controller|Display controller/ && /10de:/ {
            for (i=1;i<=NF;i++) if ($i ~ /^10de:[0-9a-fA-F]+$/) { split($i,a,":"); print tolower(a[2]); exit }
        }')"
    if [ -n "${nvidia_dev:-}" ]; then
        echo "NVIDIA_PCI_ID=${nvidia_dev}"
        gen="$(nvidia_gen_for_device "$nvidia_dev")"
        echo "NVIDIA_GENERATION=${gen}"
        case "$gen" in
            blackwell|ada|ampere|turing) echo "NVIDIA_DRIVER_BRANCH=nvidia-open" ;;
            volta|pascal|maxwell)        echo "NVIDIA_DRIVER_BRANCH=nvidia-580xx" ;;
            kepler)                      echo "NVIDIA_DRIVER_BRANCH=nvidia-470xx" ;;
            fermi)                       echo "NVIDIA_DRIVER_BRANCH=nvidia-390xx" ;;
            *)                           echo "NVIDIA_DRIVER_BRANCH=unknown" ;;
        esac
    fi
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

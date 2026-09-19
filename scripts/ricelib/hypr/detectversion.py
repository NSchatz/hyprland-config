#!/usr/bin/env python3
"""Detect the facts that drive CORRECTNESS: Hyprland's version, the GPU driver, the session, the
chassis, and which ecosystem tools are present.

These are facts, not preferences. They decide which syntax is emitted (see version-matrix.md),
whether the NVIDIA env block is gated on, whether the hardware cursor has to be turned off, and
which wallpaper binary exists. They must NEVER be used to filter the menu the user is offered -
every user sees the same options and the install step adds whatever is missing.

`HAVE_<tool>=1` / `MISSING_<tool>=1` lines exist to ANNOTATE the install batch, nothing else.

Output: KEY=value lines. Exit 0 always - an undetectable fact is reported as `unknown`, which is
a fact in itself, and never guessed.
"""
import os
import re
import sys

from .. import xdg
from ..proc import have, ok, out

VERSION_RE = re.compile(r"v?(\d+\.\d+(?:\.\d+)?)", re.I)

# label, binary (None = package-only), pacman package to fall back on
TOOLS = [
    ("hyprpaper", "hyprpaper", None), ("hyprlock", "hyprlock", None),
    ("hypridle", "hypridle", None), ("hyprpicker", "hyprpicker", None),
    ("hyprshot", "hyprshot", None),  ("hyprsunset", "hyprsunset", None),
    ("hyprpolkitagent", None, "hyprpolkitagent"),
    ("portal_hyprland", None, "xdg-desktop-portal-hyprland"),
    ("portal_gtk", None, "xdg-desktop-portal-gtk"),
    ("waybar", "waybar", None), ("hyprpanel", "hyprpanel", None),
    ("wofi", "wofi", None), ("rofi", "rofi", None), ("fuzzel", "fuzzel", None),
    ("mako", "mako", None), ("dunst", "dunst", None), ("swaync", "swaync", None),
    ("grimblast", "grimblast", None), ("grim", "grim", None), ("slurp", "slurp", None),
    ("satty", "satty", None), ("cliphist", "cliphist", None),
    ("wl_clipboard", "wl-copy", "wl-clipboard"), ("wlogout", "wlogout", None),
    ("swayosd", "swayosd-server", "swayosd"), ("brightnessctl", "brightnessctl", None),
    ("playerctl", "playerctl", None), ("nm_applet", "nm-applet", "network-manager-applet"),
    ("blueman", "blueman-applet", "blueman"), ("qt6ct", "qt6ct", None),
    ("nwg_look", "nwg-look", None), ("tesseract", "tesseract", "tesseract"),
    ("bemoji", "bemoji", None), ("wf_recorder", "wf-recorder", None),
    ("wl_screenrec", "wl-screenrec", None), ("swappy", "swappy", None),
    ("kanshi", "kanshi", None), ("shikane", "shikane", None),
]

# NVIDIA PCI device-id prefixes -> architecture, which decides the driver branch.
NVIDIA_GENS = [
    (("29", "2a", "2b"), "blackwell"),
    (("26", "27", "28"), "ada"),
    (("20", "21", "22", "23", "24", "25"), "ampere"),
    (("1e", "1f"), "turing"),
    (("1d",), "volta"),
    (("1b", "1c"), "pascal"),
    (("13", "14"), "maxwell"),
    (("0f", "10", "11", "12"), "kepler"),
    (("06", "0d", "0e"), "fermi"),
]
DRIVER_BRANCH = {
    "blackwell": "nvidia-open", "ada": "nvidia-open",
    "ampere": "nvidia-open", "turing": "nvidia-open",
    "volta": "nvidia-580xx", "pascal": "nvidia-580xx", "maxwell": "nvidia-580xx",
    "kepler": "nvidia-470xx", "fermi": "nvidia-390xx",
}
# DMI chassis types that mean "portable".
LAPTOP_CHASSIS = {"8", "9", "10", "14", "31", "32"}


def hypr_version():
    """The installed version, or "" when nothing can say."""
    for cmd in (["hyprctl", "version"], ["Hyprland", "--version"]):
        if not have(cmd[0]):
            continue
        m = VERSION_RE.search("\n".join(out(cmd).splitlines()[:20]))
        if m:
            return m.group(1)
    return ""


def _version_source():
    if have("hyprctl") and VERSION_RE.search("\n".join(out(["hyprctl", "version"]).splitlines()[:20]) or ""):
        return "hyprctl"
    if have("Hyprland"):
        return "Hyprland --version"
    return ""


def have_pkg(label, binary, pkg):
    if binary and have(binary):
        return f"HAVE_{label}=1"
    if pkg and have("pacman") and ok(["pacman", "-Qq", pkg]):
        return f"HAVE_{label}=1"
    return f"MISSING_{label}=1"


def _read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read().strip()
    except OSError:
        return ""


def _module_loaded(name):
    return any(line.split()[:1] == [name] for line in out(["lsmod"]).splitlines())


def nvidia_gen(dev_id):
    for prefixes, gen in NVIDIA_GENS:
        if dev_id[:2] in prefixes:
            return gen
    return "unknown"


def main(argv):
    version = hypr_version()
    if version:
        print(f"HYPR_VERSION={version}")
        print(f"HYPR_SOURCE={_version_source()}")
    else:
        print("HYPR_VERSION=unknown")
        print("HYPR_SOURCE=none (hyprctl/Hyprland not found; the config language cannot be "
              "assumed - see config-language.sh)")

    # ext-background-effect-v1: the capability a walker/layer blur rule is gated on.
    if not version:
        print("HYPR_HAS_EXT_BG_EFFECT_V1=unknown")
    else:
        parts = version.split(".")
        major = int(parts[0]) if parts[0].isdigit() else 0
        minor = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 0
        print(f"HYPR_HAS_EXT_BG_EFFECT_V1={1 if (major >= 1 or minor >= 50) else 0}")

    for label, binary, pkg in TOOLS[:17]:
        print(have_pkg(label, binary, pkg))

    # The wallpaper daemon's binary name differs between swww and the awww fork; emitting the
    # WRONG one is a wallpaper that silently never appears.
    if have("swww-daemon"):
        print("HAVE_swww=1"); print("SWWW_DAEMON_BIN=swww-daemon"); print("SWWW_CLIENT_BIN=swww")
    elif have("awww-daemon"):
        print("HAVE_swww=1"); print("SWWW_DAEMON_BIN=awww-daemon"); print("SWWW_CLIENT_BIN=awww")
    else:
        print("MISSING_swww=1")

    for label, binary, pkg in TOOLS[17:]:
        print(have_pkg(label, binary, pkg))

    print("HAVE_uwsm=1" if have("uwsm") else "MISSING_uwsm=1")
    try:
        uwsm_dir = xdg.config_path("uwsm")
    except xdg.NoConfigDirError:
        uwsm_dir = f"{os.environ.get('HOME', '')}/.config/uwsm"  # XDG-OK: last-resort fallback
    if os.path.isfile(f"{uwsm_dir}/env"):
        print(f"UWSM_ENV={uwsm_dir}/env")
    if os.path.isfile(f"{uwsm_dir}/env-hyprland"):
        print(f"UWSM_ENV_HYPRLAND={uwsm_dir}/env-hyprland")
    if "wayland-wm@" in out(["systemctl", "--user", "list-units", "--type=service",
                             "--state=active"]):
        print("UWSM_SESSION=1")

    # --- GPU -------------------------------------------------------------------------------
    gpu_bound = ""
    if have("lspci"):
        seen_gpu = False
        for line in out(["lspci", "-k"]).splitlines():
            if re.search(r"VGA compatible controller|3D controller|Display controller", line):
                seen_gpu = True
            elif seen_gpu and "Kernel driver in use:" in line:
                gpu_bound = line.split()[-1]
                break
        for line in out(["lspci"]).splitlines():
            if re.search(r"vga compatible controller|3d controller", line, re.I):
                print(f"GPU_DEVICE={re.sub(r'^[0-9a-f:.]+ ', '', line)}")
                break

    if _module_loaded("nvidia") or have("nvidia-smi"):
        print("GPU_DRIVER=nvidia")
        print("NVIDIA_PROPRIETARY=1")
        print("CURSOR_NO_HARDWARE_RECOMMENDED=1")
    elif _module_loaded("nouveau") or gpu_bound == "nouveau":
        print("GPU_DRIVER=nouveau")
        print("NVIDIA_PROPRIETARY=0")          # NVIDIA card, OPEN driver: no proprietary env
        print("CURSOR_NO_HARDWARE_RECOMMENDED=1")   # nouveau blanks the HW cursor when idle
    elif gpu_bound:
        print(f"GPU_DRIVER={gpu_bound}")
        print("NVIDIA_PROPRIETARY=0")
    else:
        print("GPU_DRIVER=unknown")

    if have("lspci"):
        for line in out(["lspci", "-nn"]).splitlines():
            if not re.search(r"VGA compatible controller|3D controller|Display controller", line):
                continue
            m = re.search(r"\[10de:([0-9a-fA-F]+)\]", line)
            if m:
                dev = m.group(1).lower()
                print(f"NVIDIA_PCI_ID={dev}")
                gen = nvidia_gen(dev)
                print(f"NVIDIA_GENERATION={gen}")
                print(f"NVIDIA_DRIVER_BRANCH={DRIVER_BRANCH.get(gen, 'unknown')}")
                break

    # --- chassis ----------------------------------------------------------------------------
    chassis = _read("/sys/class/dmi/id/chassis_type")
    has_battery = any(n.startswith("BAT") for n in _listdir("/sys/class/power_supply"))
    if chassis in LAPTOP_CHASSIS:
        print("IS_LAPTOP=1")
    else:
        print(f"IS_LAPTOP={1 if has_battery else 0}")
    if has_battery:
        print("HAVE_BATTERY=1")
    if os.path.isdir("/proc/acpi/button/lid"):
        print("HAVE_LID=1")

    if have("hyprctl"):
        n = out(["hyprctl", "monitors", "-j"]).count('"name":')
        if n > 0:
            print(f"MONITOR_COUNT={n}")

    for tool, name in (("powerprofilesctl", "power-profiles-daemon"),
                       ("tlp", "tlp"), ("auto-cpufreq", "auto-cpufreq")):
        if have(tool):
            print(f"POWER_TOOL={name}")
            break
    else:
        print("POWER_TOOL=none")
    return 0


def _listdir(p):
    try:
        return os.listdir(p)
    except OSError:
        return []


if __name__ == "__main__":
    sys.exit(main(sys.argv))

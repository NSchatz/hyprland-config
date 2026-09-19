#!/usr/bin/env python3
"""What theming tools, shells, fonts and current GTK settings this machine has.

Reported to ANNOTATE choices, never to filter them: every user is offered the same menu and the
install step adds whatever is missing. `CURRENT_*` rows are what gsettings says right now, so a
re-theme can be compared against where the desktop already is.

Output: HAVE_<tool>=1 / MISSING_<tool>=1, CURRENT_<key>=<value>, FONT_MONO=/FONT_SANS= rows.
"""
import os
import re
import sys

from ..proc import have, ok, out

TOOLS = [
    ("matugen", "matugen", None), ("wallust", "wallust", None),
    ("pywal", "wal", "python-pywal16"),
    ("bash", "bash", None), ("zsh", "zsh", None), ("fish", "fish", None),
    ("starship", "starship", None), ("oh_my_posh", "oh-my-posh", None),
    ("kitty", "kitty", None), ("alacritty", "alacritty", None), ("foot", "foot", None),
    ("waybar", "waybar", None), ("hyprpanel", "hyprpanel", None),
    ("wofi", "wofi", None), ("rofi", "rofi", None),
    ("mako", "mako", None), ("dunst", "dunst", None), ("swaync", "swaync", None),
    ("fastfetch", "fastfetch", None), ("neofetch", "neofetch", None),
]

GSETTINGS_KEYS = ["gtk-theme", "color-scheme", "icon-theme", "cursor-theme", "cursor-size",
                  "font-name", "monospace-font-name"]

MONO_RE = re.compile(
    r"(nerd font|nerd font mono|nerd font propo)$|"
    r"^(jetbrains mono|fira code|firacode|cascadia code|caskaydia cove|hack|iosevka|terminus|"
    r"adwaita mono|dejavu sans mono)$", re.I)
MONO_EXCLUDE = re.compile(
    r"NF$|NFM|NFP|extrabold|extralight|semibold|bold|light|medium|thin|black|italic|condensed",
    re.I)
SANS_RE = re.compile(
    r"^(Inter|Cantarell|Noto Sans|Roboto|Adwaita Sans|Ubuntu|DejaVu Sans|Fira Sans|Open Sans)$",
    re.I)


def main(argv):
    for label, binary, pkg in TOOLS:
        if have(binary):
            print(f"HAVE_{label}=1")
        elif pkg and have("pacman") and ok(["pacman", "-Qq", pkg]):
            print(f"HAVE_{label}=1")
        else:
            print(f"MISSING_{label}=1")

    user = os.environ.get("USER", "")
    shell = ""
    if user:
        line = out(["getent", "passwd", user]).strip()
        if line:
            shell = line.split(":")[-1]
    print(f"CURRENT_SHELL={shell}")

    if have("gsettings"):
        for key in GSETTINGS_KEYS:
            val = out(["gsettings", "get", "org.gnome.desktop.interface", key]).strip()
            if val:
                print(f"CURRENT_{key.upper().replace('-', '_')}={val}")

    if have("fc-list"):
        fams = set()
        for line in out(["fc-list", ":", "family"]).splitlines():
            for fam in line.split(","):
                fam = fam.strip()
                if fam:
                    fams.add(fam)
        families = sorted(fams)
        print("HAVE_NERD_FONT=1" if any("nerd font" in f.lower() for f in families)
              else "MISSING_NERD_FONT=1")
        mono = [f for f in families if MONO_RE.search(f) and not MONO_EXCLUDE.search(f)]
        for f in mono[:15]:
            print(f"FONT_MONO={f}")
        for f in [f for f in families if SANS_RE.match(f)][:10]:
            print(f"FONT_SANS={f}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

#!/usr/bin/env python3
"""Scaffold the self-contained rice engine at `<config>/hypr-rice/`.

The engine is deliberately STANDALONE: once scaffolded it keeps working with the plugin
uninstalled, because everything it needs is copied beside it - the `rice` CLI, the templates,
the preset profiles, the restore/record components, and the `ricelib` package the ported
implementations live in. A user who tries this plugin once and removes it still has a working
theme engine and a working way back.

Idempotent by design: an existing palette, manifest or customised profile is never clobbered.
`--force` re-copies the shipped assets over the installed ones.

Usage: rice-init.sh [--force]
Exit:  0 scaffolded, 2 no config dir / the plugin's assets could not be found.
"""
import os
import shutil
import sys

from .. import xdg

# Shipped components copied beside the engine, and whether they need the executable bit.
PLUGIN_SCRIPTS = [
    ("restore-point.sh", True), ("rice-restore.sh", True), ("backup-path.sh", True),
    ("install-record.sh", True), ("install-packages.sh", True), ("firefox-prefs.sh", True),
    ("xdg-config.sh", True), ("ensure-python.sh", True),
]
RICE_SCRIPTS = [
    ("render-templates.sh", True), ("set-wallpaper.sh", True),
    ("palette-from-wallpaper.sh", True),
]
RICE_ASSETS = [("rice", True), ("wallpapers.tsv", False), ("accents.tsv", False)]

DEFAULT_PALETTE = """scheme=catppuccin-mocha
bg=1e1e2e
fg=cdd6f4
surface=313244
muted=6c7086
cursor=f5e0dc
accent=cba6f7
accent2=89b4fa
red=f38ba8
green=a6e3a1
yellow=f9e2af
blue=89b4fa
magenta=f5c2e7
cyan=94e2d5
color0=45475a
color1=f38ba8
color2=a6e3a1
color3=f9e2af
color4=89b4fa
color5=f5c2e7
color6=94e2d5
color7=bac2de
color8=585b70
color9=f38ba8
color10=a6e3a1
color11=f9e2af
color12=89b4fa
color13=f5c2e7
color14=94e2d5
color15=a6adc8
font_ui=Inter 11
font_mono=JetBrainsMono Nerd Font 11
"""


def _copy(src, dest, executable=False, force=True):
    if not os.path.isfile(src):
        return False
    if os.path.exists(dest) and not force:
        return False
    try:
        shutil.copyfile(src, dest)
        if executable:
            os.chmod(dest, 0o755)
    except OSError:
        return False
    return True


def main(argv):
    force = "--force" in argv[1:]
    env = os.environ

    rice_dir = xdg.config_target("hypr-rice", env.get("RICE_DIR", ""))
    if rice_dir is None:
        print("RICE_INIT=refused-no-config-dir")
        return 2

    plugin_root = env.get("CLAUDE_PLUGIN_ROOT", "")
    if plugin_root and os.path.isdir(f"{plugin_root}/skills/rice/references/theming"):
        src = f"{plugin_root}/skills/rice"
    else:
        here = os.path.dirname(os.path.abspath(__file__))
        src = os.path.abspath(os.path.join(here, "..", "..", "..", "skills", "rice"))

    if not os.path.isdir(f"{src}/references/theming"):
        print(f"ERROR: cannot find the plugin's rice templates (looked in {src}). "
              "Set CLAUDE_PLUGIN_ROOT.", file=sys.stderr)
        return 2

    plugin_scripts = os.path.abspath(os.path.join(src, "..", "..", "scripts"))

    os.makedirs(f"{rice_dir}/templates", exist_ok=True)
    os.makedirs(f"{rice_dir}/profiles", exist_ok=True)

    # Preset profiles: never clobber one the user has customised, unless --force.
    prof_src = f"{src}/assets/profiles"
    if os.path.isdir(prof_src):
        for n in sorted(os.listdir(prof_src)):
            if n.endswith(".conf"):
                _copy(f"{prof_src}/{n}", f"{rice_dir}/profiles/{n}", force=force)

    # Colour templates, from every component folder plus the theming set.
    for base in (f"{src}/references/components", f"{src}/references/theming"):
        if not os.path.isdir(base):
            continue
        for dirpath, _dirs, files in os.walk(base):
            for n in sorted(files):
                if n.endswith(".tmpl"):
                    _copy(f"{dirpath}/{n}", f"{rice_dir}/templates/{n}", force=force)

    # THE PACKAGE. Every component copied below is a dispatcher over ricelib, so without this
    # the installed engine would be a set of scripts pointing at an implementation that is not
    # there. Always refreshed: a stale copy beside a newer CLI is worse than no copy.
    lib_src = f"{plugin_scripts}/ricelib"
    if os.path.isdir(lib_src):
        lib_dest = f"{rice_dir}/ricelib"
        shutil.rmtree(lib_dest, ignore_errors=True)
        try:
            shutil.copytree(lib_src, lib_dest,
                            ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
            print(f"RICE_LIB={lib_dest}")
        except (OSError, shutil.Error):
            print(f"ERROR: the ricelib package could not be copied to {lib_dest}; the installed "
                  "engine would have no implementation behind it.", file=sys.stderr)
            return 2
    else:
        print(f"ERROR: the ricelib package was not found at {lib_src}.", file=sys.stderr)
        return 2

    for name, ex in PLUGIN_SCRIPTS:
        _copy(f"{plugin_scripts}/{name}", f"{rice_dir}/{name}", executable=ex)
    for name, ex in RICE_SCRIPTS:
        _copy(f"{src}/scripts/{name}", f"{rice_dir}/{name}", executable=ex)
    for name, ex in RICE_ASSETS:
        _copy(f"{src}/assets/{name}", f"{rice_dir}/{name}", executable=ex)

    os.makedirs(f"{rice_dir}/browser", exist_ok=True)
    _copy(f"{src}/assets/scripts/firefox-bootstrap.sh", f"{rice_dir}/firefox-bootstrap.sh",
          executable=True)
    _copy(f"{src}/assets/scripts/firefox-restart.sh", f"{rice_dir}/firefox-restart.sh",
          executable=True)
    _copy(f"{src}/references/components/browser/userChrome.css",
          f"{rice_dir}/browser/userChrome.css")
    _copy(f"{src}/references/components/browser/user.js", f"{rice_dir}/browser/user.js")

    mf = f"{rice_dir}/templates.list"
    if not os.path.isfile(mf) or force:
        T = f"{rice_dir}/templates"
        rows = [
            "# name\ttemplate\toutput\treload-cmd",
            f"hyprland\t{T}/hyprland.tmpl\t~/.config/hypr/colors.conf\thyprctl reload",
            f"kitty\t{T}/kitty.tmpl\t~/.config/kitty/colors.conf\tpkill -SIGUSR1 -x kitty",
            f"waybar\t{T}/waybar.tmpl\t~/.config/waybar/colors.css\tkillall -SIGUSR2 waybar",
            f"wofi\t{T}/wofi.tmpl\t~/.config/wofi/colors.css\t",
            f"rofi\t{T}/rofi.tmpl\t~/.config/rofi/colors.rasi\t",
            f"gtk4\t{T}/gtk4.tmpl\t~/.config/gtk-4.0/gtk.css\t",
        ]
        try:
            with open(mf, "w", encoding="utf-8") as fh:
                fh.write("\n".join(rows) + "\n")
        except OSError:
            print(f"ERROR: the render manifest could not be written to {mf}", file=sys.stderr)
            return 2

    pal = f"{rice_dir}/palette.conf"
    if not os.path.isfile(pal):
        try:
            with open(pal, "w", encoding="utf-8") as fh:
                fh.write(DEFAULT_PALETTE)
        except OSError:
            print(f"ERROR: the default palette could not be written to {pal}", file=sys.stderr)
            return 2

    print(f"RICE_DIR={rice_dir}")
    print("RICE_INIT=done")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

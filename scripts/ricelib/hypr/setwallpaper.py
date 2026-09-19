#!/usr/bin/env python3
"""Set the wallpaper, through whichever backend this machine actually has.

swww (or the `awww` fork) is preferred, then hyprpaper, then swaybg. The DAEMON BINARY NAME
matters and is not guessable: the awww fork ships `awww-daemon`, and hard-coding `swww-daemon`
is a wallpaper that silently never appears. The detected name is used.

A stable `current-wallpaper` symlink is kept beside the engine so other surfaces (hyprlock,
a lock-blur cache, a fetch tool) can point at ONE path rather than re-reading the palette.

Usage: set-wallpaper.sh <image> [--dry-run]
Exit:  0 set, 2 bad usage / no config dir, 3 no backend installed.
"""
import os
import subprocess
import sys
import time

from .. import xdg
from ..proc import expand_user, have, ok


def main(argv):
    env = os.environ
    img = argv[1] if len(argv) > 1 else ""
    if not img:
        print("ERROR: usage: set-wallpaper.sh <image> [--dry-run]", file=sys.stderr)
        return 2
    dry = len(argv) > 2 and argv[2] == "--dry-run"

    img = expand_user(img, env)
    if not os.path.isfile(img):
        print(f"ERROR: no such image: {img}", file=sys.stderr)
        return 2
    img = os.path.abspath(img)

    rice_dir = xdg.config_target("hypr-rice", env.get("RICE_DIR", ""))
    if rice_dir is None:
        print("SET_WALLPAPER=refused-no-config-dir", file=sys.stderr)
        return 2
    try:
        hypr_dir = xdg.config_path("hypr", env.get("HYPR_DIR", ""), env)
    except xdg.NoConfigDirError:
        hypr_dir = ""

    def link_current():
        link = f"{rice_dir}/current-wallpaper"
        if dry:
            print(f"DRY: ln -sfn '{img}' '{link}'")
            return
        os.makedirs(rice_dir, exist_ok=True)
        try:
            if os.path.islink(link) or os.path.exists(link):
                os.remove(link)
            os.symlink(img, link)
        except OSError:
            pass

    # --- swww / awww --------------------------------------------------------------------------
    client = daemon = ""
    if have("swww"):
        client, daemon = "swww", "swww-daemon"
    elif have("awww"):
        client, daemon = "awww", "awww-daemon"

    if client:
        if not dry and not ok([client, "query"]):
            try:
                subprocess.Popen([daemon], start_new_session=True,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except OSError:
                pass
            for _ in range(6):
                if ok([client, "query"]):
                    break
                time.sleep(0.5)
        cmd = [client, "img", img, "--transition-type",
               env.get("SWWW_TRANSITION_TYPE", "any"),
               "--transition-fps", env.get("SWWW_TRANSITION_FPS", "60")]
        if dry:
            print("DRY: " + " ".join(cmd))
        else:
            ok(cmd)
        link_current()
        print(f"SET_WALLPAPER=ok ({client})")
        return 0

    # --- hyprpaper -----------------------------------------------------------------------------
    if have("hyprpaper"):
        if dry:
            print(f"DRY: hyprctl hyprpaper preload '{img}' && wallpaper ',{img}' && write "
                  "hyprpaper.conf")
        else:
            ok(["hyprctl", "hyprpaper", "preload", img])
            ok(["hyprctl", "hyprpaper", "wallpaper", f",{img}"])
            if hypr_dir:
                os.makedirs(hypr_dir, exist_ok=True)
                try:
                    with open(f"{hypr_dir}/hyprpaper.conf", "w", encoding="utf-8") as fh:
                        fh.write(f"preload = {img}\nwallpaper = , {img}\nsplash = false\n")
                except OSError:
                    pass
            else:
                print("HYPRPAPER_CONF_SKIPPED no config directory could be determined",
                      file=sys.stderr)
        link_current()
        print("SET_WALLPAPER=ok (hyprpaper)")
        return 0

    # --- swaybg ---------------------------------------------------------------------------------
    if have("swaybg"):
        if dry:
            print(f"DRY: pkill -x swaybg; swaybg -i '{img}' -m fill &")
        else:
            ok(["pkill", "-x", "swaybg"])
            try:
                subprocess.Popen(["swaybg", "-i", img, "-m", "fill"], start_new_session=True,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except OSError:
                pass
        link_current()
        print("SET_WALLPAPER=ok (swaybg)")
        return 0

    print("SET_WALLPAPER=none (install swww or hyprpaper)", file=sys.stderr)
    return 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))

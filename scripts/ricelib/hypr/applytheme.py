#!/usr/bin/env python3
"""Reload the apps a theme change affects - only the ones actually running.

Reloading beats restarting: a restart loses the app's state and flashes the desktop. Every
surface reports its own line so a caller can see which ones took the new palette and which were
not up to take it.

Usage: apply-theme.sh [--cursor <theme> [<size>]]
Output: RELOAD_<app>=ok|failed|skipped (not running), then APPLY_THEME=done
"""
import signal
import subprocess
import sys

from ..proc import have, ok, out, running, signal_named


def hypr_live():
    return have("hyprctl") and ok(["hyprctl", "version"])


def main(argv):
    cursor_theme = ""
    cursor_size = "24"
    if len(argv) > 1 and argv[1] == "--cursor":
        cursor_theme = argv[2] if len(argv) > 2 else ""
        cursor_size = argv[3] if len(argv) > 3 else "24"

    if hypr_live():
        print("RELOAD_hyprland=" + ("ok" if ok(["hyprctl", "reload"]) else "failed"))
    else:
        print("RELOAD_hyprland=skipped (not running)")

    if running("waybar"):
        print("RELOAD_waybar=" + ("ok" if signal_named("waybar", signal.SIGUSR2) else "failed"))
    else:
        print("RELOAD_waybar=skipped (not running)")

    if running("mako") and have("makoctl"):
        print("RELOAD_mako=" + ("ok" if ok(["makoctl", "reload"]) else "failed"))
    else:
        print("RELOAD_mako=skipped (not running)")

    if running("dunst"):
        if have("dunstctl") and ok(["dunstctl", "reload"]):
            print("RELOAD_dunst=ok")
        else:
            # dunst before 1.9 has no reload: a restart is the only way to pick up a new config.
            signal_named("dunst", signal.SIGTERM)
            try:
                subprocess.Popen(["dunst"], start_new_session=True,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                print("RELOAD_dunst=restarted")
            except OSError:
                print("RELOAD_dunst=failed")
    else:
        print("RELOAD_dunst=skipped (not running)")

    if running("kitty"):
        print("RELOAD_kitty=" + ("ok" if signal_named("kitty", signal.SIGUSR1) else "failed"))
    else:
        print("RELOAD_kitty=skipped (not running)")

    if cursor_theme and hypr_live():
        if ok(["hyprctl", "setcursor", cursor_theme, cursor_size]):
            print(f"RELOAD_cursor=ok ({cursor_theme} {cursor_size})")
        else:
            print("RELOAD_cursor=failed")

    print("APPLY_THEME=done")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

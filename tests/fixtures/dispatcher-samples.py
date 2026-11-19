#!/usr/bin/env python3
"""One sample argument for EVERY legacy dispatcher the converter translates.

Used by tests/test_lua_migrate_api.sh. Prints `<legacy name> TAB <lua call>` per dispatcher, or
with `--binds` a lua file that binds each call to its own key, so a real Hyprland can be asked
whether it accepts the shape. Exits 1 when the sample table and the converter's table no longer
cover the same names: a dispatcher added to one and not the other is a mapping nothing tests.

Usage: PYTHONPATH=<plugin>/scripts python3 dispatcher-samples.py [--binds]
"""
import sys

from ricelib.hypr import luadispatch

SAMPLES = {
    "exec": "kitty", "execr": "kitty", "exit": "", "killactive": "", "forcekillactive": "",
    "closewindow": "class:kitty", "killwindow": "class:kitty", "signal": "9",
    "signalwindow": "class:kitty,9", "togglefloating": "", "setfloating": "", "settiled": "",
    "fullscreen": "1", "fullscreenstate": "2 0", "pseudo": "", "pin": "", "centerwindow": "",
    "toggleswallow": "", "bringactivetotop": "", "alterzorder": "top", "tagwindow": "+code",
    "setprop": "active opaque toggle", "layoutmsg": "togglesplit", "movefocus": "l",
    "focuswindow": "class:kitty", "focusmonitor": "DP-1", "focuscurrentorlast": "",
    "focusurgentorlast": "", "cyclenext": "prev", "swapnext": "",
    "movewindow": "mon:DP-1 silent", "swapwindow": "r", "resizeactive": "10 -10",
    "moveactive": "exact 100 100", "resizewindowpixel": "10 0,class:kitty",
    "movewindowpixel": "10 0,class:kitty", "workspace": "3",
    "focusworkspaceoncurrentmonitor": "3", "movetoworkspace": "3",
    "movetoworkspacesilent": "3,class:kitty", "togglespecialworkspace": "",
    "renameworkspace": "3 web", "movecurrentworkspacetomonitor": "DP-1",
    "moveworkspacetomonitor": "3 DP-1", "swapactiveworkspaces": "DP-1 DP-2",
    "togglegroup": "", "changegroupactive": "f", "movegroupwindow": "b", "lockgroups": "lock",
    "lockactivegroup": "toggle", "denywindowfromgroup": "on", "moveintogroup": "l",
    "moveintoorcreategroup": "d", "moveoutofgroup": "", "movewindoworgroup": "u",
    "movecursortocorner": "2", "movecursor": "10 20", "submap": "reset",
    "global": "app:toggle", "event": "hello", "pass": "class:obs",
    "sendshortcut": "CTRL, V, class:kitty", "sendkeystate": "CTRL, V, down, class:kitty",
    "dpms": "off DP-1", "forceidle": "5", "forcerendererreload": "",
}


def main(argv):
    missing = sorted(set(luadispatch.DISPATCHERS) - set(SAMPLES))
    extra = sorted(set(SAMPLES) - set(luadispatch.DISPATCHERS))
    if missing or extra:
        print(f"ERROR: no sample for {missing}; sample for unknown {extra}", file=sys.stderr)
        return 1
    binds = "--binds" in argv[1:]
    for n, (name, arg) in enumerate(sorted(SAMPLES.items())):
        lua, why = luadispatch.translate(name, arg)
        if lua is None:
            print(f"ERROR: {name}: {why}", file=sys.stderr)
            return 1
        if binds:
            print(f'hl.bind("SUPER + CTRL + ALT + code:{10 + n}", {lua})')
        else:
            print(f"{name}\t{lua}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

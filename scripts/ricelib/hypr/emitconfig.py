#!/usr/bin/env python3
"""Emit a minimal, WORKING bare-bones Hyprland config, in the language this Hyprland reads.

"Minimal" here means a desktop someone can actually use to fix the desktop: a terminal, a
launcher, close, exit, focus movement, five workspaces and mouse move/resize. A config that
parses but cannot open a terminal is not a recovery point.

The language is not assumed - see configlang. On an undecidable version this refuses and emits
nothing rather than writing a file the compositor may never read.

Usage: emit-config.sh <staging-dir>
Env:   BARE_TERMINAL (default kitty), BARE_MENU (default `wofi --show drun`)
Exit:  0 emitted, 2 bad usage, 3 the config language is undecided.
"""
import os
import sys

from . import configlang

HYPRLANG_BODY = '$mainMod  = SUPER\n\nmonitor = , preferred, auto, auto\n\ngeneral {\n    gaps_in = 5\n    gaps_out = 10\n    border_size = 2\n    layout = dwindle\n}\n\ninput {\n    kb_layout = us\n    follow_mouse = 1\n}\n\nbind = $mainMod, Return, exec, $terminal\nbind = $mainMod, Q, killactive,\nbind = $mainMod, M, exit,\nbind = $mainMod, D, exec, $menu\nbind = $mainMod, Space, togglefloating,\nbind = $mainMod, left,  movefocus, l\nbind = $mainMod, right, movefocus, r\nbind = $mainMod, up,    movefocus, u\nbind = $mainMod, down,  movefocus, d\nbind = $mainMod, 1, workspace, 1\nbind = $mainMod, 2, workspace, 2\nbind = $mainMod, 3, workspace, 3\nbind = $mainMod, 4, workspace, 4\nbind = $mainMod, 5, workspace, 5\nbind = $mainMod SHIFT, 1, movetoworkspace, 1\nbind = $mainMod SHIFT, 2, movetoworkspace, 2\nbind = $mainMod SHIFT, 3, movetoworkspace, 3\nbind = $mainMod SHIFT, 4, movetoworkspace, 4\nbind = $mainMod SHIFT, 5, movetoworkspace, 5\nbindm = $mainMod, mouse:272, movewindow\nbindm = $mainMod, mouse:273, resizewindow\n'

LUA_BODY = 'local mainMod  = "SUPER"\n\n-- Minimal look - small gaps, a visible border, dwindle tiling.\nhl.config({\n    general = {\n        gaps_in = 5,\n        gaps_out = 10,\n        border_size = 2,\n        layout = "dwindle",\n    },\n    input = {\n        kb_layout = "us",\n        follow_mouse = 1,\n    },\n})\n\n-- Monitors - auto-detect everything (adjust with `hyprctl monitors`).\n-- An empty output matches every monitor, like `monitor = , ...` in hyprlang.\nhl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })\n\n-- Essential keybinds - enough to open a terminal, launch apps, and exit.\nhl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))\nhl.bind(mainMod .. " + Q", hl.dsp.killactive())\nhl.bind(mainMod .. " + M", hl.dsp.exit())\nhl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))\nhl.bind(mainMod .. " + Space", hl.dsp.togglefloating())\n\n-- Move focus\nhl.bind(mainMod .. " + left",  hl.dsp.movefocus("l"))\nhl.bind(mainMod .. " + right", hl.dsp.movefocus("r"))\nhl.bind(mainMod .. " + up",    hl.dsp.movefocus("u"))\nhl.bind(mainMod .. " + down",  hl.dsp.movefocus("d"))\n\n-- Workspaces 1-5\nfor i = 1, 5 do\n    hl.bind(mainMod .. " + " .. i, hl.dsp.workspace(i))\n    hl.bind(mainMod .. " SHIFT + " .. i, hl.dsp.movetoworkspace(i))\nend\n\n-- Mouse move/resize\nhl.bind(mainMod .. " + mouse:272", hl.dsp.movewindow(), { mouse = true })\nhl.bind(mainMod .. " + mouse:273", hl.dsp.resizewindow(), { mouse = true })\n'

LUA_HEADER = """-- A minimal, working baseline. Rebuild with /hyprland-config:rice
-- (full interview) or extend piecemeal with /hyprland-config:edit-config.
-- Config surface: hl.config / hl.monitor / hl.bind + hl.dsp.<dispatcher>().
-- See <https://wiki.hypr.land/Configuring/Start/> for the full lua API.
local terminal = "{terminal}"
local menu     = "{menu}"
"""


def main(argv):
    staging = argv[1] if len(argv) > 1 else ""
    if not staging:
        print("ERROR: usage: emit-config.sh <staging-dir>", file=sys.stderr)
        return 2

    terminal = os.environ.get("BARE_TERMINAL", "kitty")
    menu = os.environ.get("BARE_MENU", "wofi --show drun")

    res = configlang.resolve()
    if res.rc != 0:
        return res.rc
    language = res.language

    try:
        os.makedirs(staging, exist_ok=True)
    except OSError:
        print(f"ERROR: cannot create staging dir '{staging}'", file=sys.stderr)
        return 2

    out = f"{staging}/{configlang.lang_file(language)}"
    prov = configlang.provenance(language)

    if language == "hyprlang":
        body = prov + f"$terminal = {terminal}\n$menu     = {menu}\n\n" + HYPRLANG_BODY
    elif language == "lua":
        body = prov + LUA_HEADER.format(terminal=terminal, menu=menu) + "\n" + LUA_BODY
    else:
        print(f"ERROR: unsupported config language: {language}", file=sys.stderr)
        return 2

    try:
        with open(out, "w", encoding="utf-8") as fh:
            fh.write(body)
    except OSError:
        print(f"ERROR: could not write '{out}'", file=sys.stderr)
        return 2

    print(f"EMITTED={out}")
    print("DONE=ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

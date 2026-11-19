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

LUA_BODY = """local mainMod  = "SUPER"

-- Minimal look - small gaps, a visible border, dwindle tiling.
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        layout = "dwindle",
    },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
    },
})

-- Monitors - auto-detect everything (adjust with `hyprctl monitors`).
-- An empty output matches every monitor, like `monitor = , ...` in hyprlang.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Essential keybinds - enough to open a terminal, launch apps, and exit.
-- The lua dispatchers are NOT the hyprlang names: hl.dsp.killactive is nil, and one call to a
-- nil function aborts the file, taking every bind after it along. A key chord joins every
-- modifier and the key with " + "; "SUPER SHIFT + 1" is rejected.
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + Space", hl.dsp.window.float({ action = "toggle" }))

-- Move focus
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspaces 1-5
for i = 1, 5 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Mouse move/resize
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
"""

LUA_HEADER = """-- A minimal, working baseline. Rebuild with /hyprland-config:rice
-- (full interview) or extend piecemeal with /hyprland-config:edit-config.
-- Config surface: hl.config / hl.monitor / hl.bind + the hl.dsp.* dispatchers.
-- See <https://wiki.hypr.land/configuring/> for the full lua API.
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

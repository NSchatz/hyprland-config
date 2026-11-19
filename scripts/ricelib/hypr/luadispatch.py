#!/usr/bin/env python3
"""The hyprlang bind vocabulary, translated to the lua API: dispatchers, key chords, bind flags.

A lua config does not have the legacy dispatcher names. `hl.dsp.killactive` is nil, so a bind
written against it aborts the file at load: "attempt to call a nil value". Every name here maps
to a call that EXISTS in the lua API, in the shape Hyprland documents for it:

    killactive                 -> hl.dsp.window.close()
    movefocus, l               -> hl.dsp.focus({ direction = "left" })
    workspace, 3               -> hl.dsp.focus({ workspace = 3 })
    movetoworkspacesilent, 3   -> hl.dsp.window.move({ workspace = 3, follow = false })
    togglespecialworkspace, x  -> hl.dsp.workspace.toggle_special("x")

A name with no entry, or an argument this module cannot place, is NOT guessed at. `translate`
returns the reason instead, and the caller carries the line across as a `-- NOT APPLIED`
comment. A missing bind that says so is recoverable; a call to a function that does not exist
takes the rest of the file down with it.

Sources: the dispatcher table of the Hyprland wiki for 0.57 (Configuring > Core > Dispatchers),
the config Hyprland ships (`/usr/share/hypr/hyprland.lua`) and its lua stubs
(`/usr/share/hypr/stubs/hl.meta.lua`).

`modernize_command` is the same translation for a SHELL command: `hyprctl keyword` does not
exist under a lua config and `hyprctl dispatch` takes a lua dispatcher there, so an `exec` line
that calls either one loads fine and then does nothing when the key is pressed.
"""
import re

INT_RE = re.compile(r"^-?\d+$")
NUM_RE = re.compile(r"^-?(?:\d+\.?\d*|\.\d+)$")
WS_ID_RE = re.compile(r"^[1-9]\d*$")

# hyprlang `bind<flags>` letters -> the lua bind option. `d` (a description field follows the
# key) is handled by the caller. `s` (separate keysyms) and `k` (per-device) have no entry: the
# lua forms take structured arguments this module cannot derive from a letter.
BIND_FLAGS = {
    "e": "repeating", "l": "locked", "r": "release", "m": "mouse", "n": "non_consuming",
    "t": "transparent", "i": "ignore_mods", "c": "click", "g": "drag", "o": "long_press",
    "p": "dont_inhibit", "u": "submap_universal",
}

# The modifier names Hyprland accepts, longest first so CONTROL is not read as CTRL + "OL".
MODIFIERS = ("CONTROL", "SHIFT", "SUPER", "CAPS", "CTRL", "LOGO", "META", "MOD1", "MOD2", "MOD3",
             "MOD4", "MOD5", "ALT", "WIN")

DIRECTIONS = {
    "l": "left", "left": "left", "r": "right", "right": "right",
    "u": "up", "up": "up", "t": "up", "top": "up",
    "d": "down", "down": "down", "b": "down", "bottom": "down",
}

# hyprlang's on/off/toggle words -> the lua `action` values.
ACTIONS = {"on": "enable", "off": "disable", "toggle": "toggle",
           "lock": "enable", "unlock": "disable", "enable": "enable", "disable": "disable"}

ACTIVE_WINDOW = ("", "active", "activewindow")


def lua_string(s):
    return '"' + (s or "").replace("\\", "\\\\").replace('"', '\\"') + '"'


def _table(*fields):
    """`{ a = 1, b = 2 }` from already-rendered `name = value` strings; None entries drop out."""
    kept = [f for f in fields if f]
    return "{ " + ", ".join(kept) + " }" if kept else ""


def _call(fn, *fields):
    return f"hl.dsp.{fn}({_table(*fields)})"


def _window(sel):
    sel = (sel or "").strip()
    return None if sel in ACTIVE_WINDOW else f"window = {lua_string(sel)}"


def workspace_value(s):
    """A plain positive id is a lua integer. Everything else (`e+1`, `previous`, `special:x`,
    `name:web`, `+1`, `-1`) is a selector STRING: `-1` as a bare number would read as an id."""
    s = s.strip()
    return s if WS_ID_RE.match(s) else lua_string(s)


def chord(mods, key):
    """`SUPER SHIFT` + `Q` -> `SUPER + SHIFT + Q`.

    hyprlang reads a modifier field by looking for modifier names anywhere in it, so
    `SUPER SHIFT`, `SUPER_SHIFT`, `SUPER+SHIFT` and `SUPERSHIFT` are all the same chord there.
    The lua key string is strict: every modifier and the key are joined with ` + `, and
    `SUPER SHIFT + Q` is "Unknown key: SUPER SHIFT". Returns (chord, None) or (None, reason).
    """
    names = []
    for token in re.split(r"[\s+&|_]+", (mods or "").strip()):
        rest = token
        if names and token.upper() in ("L", "R"):
            continue                    # `Super_L` in a modifier field still means SUPER
        while rest:
            hit = next((m for m in MODIFIERS if rest.upper().startswith(m)), None)
            if not hit:
                return None, f"'{token}' is not a modifier name this converter knows"
            names.append(rest[:len(hit)])
            rest = rest[len(hit):]
    key = (key or "").strip()
    if not key:
        return None, "the bind has no key"
    return " + ".join(names + [key]), None


def _direction(arg):
    return DIRECTIONS.get(arg.strip().lower())


def _numbers(text, count):
    parts = text.split()
    if len(parts) != count or not all(NUM_RE.match(p) for p in parts):
        return None
    return parts


def _no_arg(fn):
    def handler(arg):
        if arg:
            return None, "this converter only knows the form with no argument"
        return f"hl.dsp.{fn}()", None
    return handler


def _optional_window(fn):
    def handler(arg):
        return _call(fn, _window(arg)), None
    return handler


def _string_arg(fn, what):
    def handler(arg):
        if not arg:
            return None, f"it needs {what}"
        return f"hl.dsp.{fn}({lua_string(arg)})", None
    return handler


def _directional(fn, field, *extra):
    def handler(arg):
        d = _direction(arg)
        if not d:
            return None, f"'{arg}' is not a direction (l, r, u, d)"
        return _call(fn, f"{field} = {lua_string(d)}", *extra), None
    return handler


def _toggle(fn, *extra):
    def handler(arg):
        action = ACTIONS.get(arg.strip().lower() or "toggle")
        if not action:
            return None, f"'{arg}' is not on, off or toggle"
        return _call(fn, *extra, f"action = {lua_string(action)}"), None
    return handler


def _exec(arg):
    if not arg:
        return None, "exec needs a command"
    if arg.startswith("["):
        return None, ("an exec with a [rules] prefix becomes hl.dsp.exec_cmd(cmd, { rules }); "
                      "the rules need porting by hand")
    return f"hl.dsp.exec_cmd({lua_string(arg)})", None


def _float(action):
    def handler(arg):
        return _call("window.float", _window(arg), f"action = {lua_string(action)}"), None
    return handler


def _fullscreen(arg):
    parts = arg.split()
    mode = {"": None, "0": "fullscreen", "1": "maximized"}.get(parts[0] if parts else "", "?")
    if mode == "?" or len(parts) > 2:
        return None, "only mode 0 (fullscreen) and 1 (maximized) have a lua form"
    action = parts[1] if len(parts) > 1 else None
    if action and action not in ("toggle", "set", "unset"):
        return None, f"'{action}' is not toggle, set or unset"
    return _call("window.fullscreen",
                 f"mode = {lua_string(mode)}" if mode else None,
                 f"action = {lua_string(action)}" if action else None), None


def _fullscreen_state(arg):
    parts = arg.split()
    if len(parts) not in (2, 3) or not all(INT_RE.match(p) for p in parts[:2]):
        return None, "it needs INTERNAL CLIENT as two integers"
    action = parts[2] if len(parts) == 3 else None
    if action and action not in ("toggle", "set", "unset"):
        return None, f"'{action}' is not toggle, set or unset"
    return _call("window.fullscreen_state", f"internal = {parts[0]}", f"client = {parts[1]}",
                 f"action = {lua_string(action)}" if action else None), None


def _dpms(arg):
    parts = arg.split(None, 1)
    action = ACTIONS.get(parts[0].lower()) if parts else "toggle"
    if not action:
        return None, f"'{arg}' is not on, off or toggle"
    monitor = f"monitor = {lua_string(parts[1].strip())}" if len(parts) > 1 else None
    return _call("dpms", f"action = {lua_string(action)}", monitor), None


def _workspace(arg):
    if not arg:
        return None, "it needs a workspace"
    return _call("focus", f"workspace = {workspace_value(arg)}"), None


def _move_to_workspace(follow):
    def handler(arg):
        ws, _, window = arg.partition(",")
        if not ws.strip():
            return None, "it needs a workspace"
        return _call("window.move", f"workspace = {workspace_value(ws)}",
                     None if follow else "follow = false", _window(window)), None
    return handler


def _move_window(arg):
    parts = arg.split()
    if parts and parts[0].startswith("mon:"):
        silent = parts[1:] == ["silent"]
        if len(parts) > 1 and not silent:
            return None, f"'{arg}' is not `mon:NAME` or `mon:NAME silent`"
        return _call("window.move", f"monitor = {lua_string(parts[0][4:])}",
                     "follow = false" if silent else None), None
    d = _direction(arg)
    if not d:
        return None, f"'{arg}' is not a direction (l, r, u, d) or mon:NAME"
    return _call("window.move", f"direction = {lua_string(d)}"), None


def _swap_window(arg):
    d = _direction(arg)
    if d:
        return _call("window.swap", f"direction = {lua_string(d)}"), None
    if not arg:
        return None, "it needs a direction or a window"
    return _call("window.swap", f"target = {lua_string(arg)}"), None


def _geometry(fn):
    """resizeactive / moveactive / resizewindowpixel / movewindowpixel: `X Y` is relative,
    `exact X Y` is absolute. A percentage has no lua form: x and y must be numbers."""
    def handler(arg):
        params, _, window = arg.partition(",")
        parts = params.split()
        exact = bool(parts) and parts[0] == "exact"
        nums = _numbers(" ".join(parts[1:] if exact else parts), 2)
        if not nums:
            return None, "x and y must be plain numbers (a percentage has no lua form)"
        return _call(fn, f"x = {nums[0]}", f"y = {nums[1]}",
                     None if exact else "relative = true", _window(window)), None
    return handler


def _cycle_next(arg):
    fields = []
    for word in arg.split():
        if word == "prev":
            fields.append("next = false")
        elif word in ("tiled", "floating"):
            fields.append(f"{word} = true")
        else:
            return None, f"'{word}' has no lua form here"
    return _call("window.cycle_next", *fields), None


def _swap_next(arg):
    if arg not in ("", "prev"):
        return None, f"'{arg}' is not empty or prev"
    return _call("window.swap", "prev = true" if arg else "next = true"), None


def _tag_window(arg):
    tag, _, window = arg.partition(" ")
    if not tag:
        return None, "it needs a tag"
    return _call("window.tag", f"tag = {lua_string(tag)}", _window(window)), None


def _signal(with_window):
    def handler(arg):
        window, sig = "", arg
        if with_window:
            window, _, sig = arg.rpartition(",")
        if not INT_RE.match(sig.strip()):
            return None, "the signal must be a number"
        return _call("window.signal", _window(window), f"signal = {sig.strip()}"), None
    return handler


def _send_shortcut(with_state):
    def handler(arg):
        parts = [p.strip() for p in arg.split(",")]
        want = 4 if with_state else 3
        if len(parts) < 2 or len(parts) > want:
            return None, "it needs MODS, KEY" + (", STATE" if with_state else "") + "[, WINDOW]"
        fields = [f"mods = {lua_string(parts[0])}", f"key = {lua_string(parts[1])}"]
        if with_state:
            if len(parts) < 3 or parts[2] not in ("down", "up"):
                return None, "the state must be down or up"
            fields.append(f"state = {lua_string(parts[2])}")
        window = parts[want - 1] if len(parts) == want else ""
        return _call("send_key_state" if with_state else "send_shortcut",
                     *fields, _window(window)), None
    return handler


def _cursor_corner(arg):
    if arg not in ("0", "1", "2", "3"):
        return None, "the corner must be 0 to 3"
    return _call("cursor.move_to_corner", f"corner = {arg}"), None


def _cursor_move(arg):
    nums = _numbers(arg, 2)
    if not nums:
        return None, "it needs X Y as two numbers"
    return _call("cursor.move", f"x = {nums[0]}", f"y = {nums[1]}"), None


def _rename_workspace(arg):
    ws, _, name = arg.partition(" ")
    if not ws:
        return None, "it needs a workspace"
    return _call("workspace.rename", f"workspace = {workspace_value(ws)}",
                 f"name = {lua_string(name.strip())}" if name.strip() else None), None


def _workspace_to_monitor(current):
    def handler(arg):
        parts = arg.split()
        if len(parts) != (1 if current else 2):
            return None, "it needs " + ("MONITOR" if current else "WORKSPACE MONITOR")
        return _call("workspace.move",
                     None if current else f"workspace = {workspace_value(parts[0])}",
                     f"monitor = {lua_string(parts[-1])}"), None
    return handler


def _focus_on_current_monitor(arg):
    if not arg:
        return None, "it needs a workspace"
    return _call("focus", f"workspace = {workspace_value(arg)}", "on_current_monitor = true"), None


def _swap_active_workspaces(arg):
    parts = arg.split()
    if len(parts) != 2:
        return None, "it needs MONITOR MONITOR"
    return _call("workspace.swap_monitors", f"monitor1 = {lua_string(parts[0])}",
                 f"monitor2 = {lua_string(parts[1])}"), None


def _alter_zorder(arg):
    mode, _, window = arg.partition(",")
    if mode.strip() not in ("top", "bottom"):
        return None, "the mode must be top or bottom"
    return _call("window.alter_zorder", f"mode = {lua_string(mode.strip())}", _window(window)), None


def _toggle_special(arg):
    return f"hl.dsp.workspace.toggle_special({lua_string(arg) if arg else ''})", None


def _change_group_active(arg):
    if arg in ("f", "forward", ""):
        return "hl.dsp.group.next()", None
    if arg in ("b", "back", "backward"):
        return "hl.dsp.group.prev()", None
    # A tab index would be hl.dsp.group.active({ index = N }), but whether lua counts tabs from
    # 0 or 1 is not something this converter can show, and guessing lands on the wrong tab.
    return None, f"'{arg}' is not f or b (a tab index needs porting by hand: group.active)"


def _move_out_of_group(arg):
    return _call("window.move", "out_of_group = true", _window(arg)), None


def _move_group_window(arg):
    return _call("group.move_window", f"forward = {'false' if arg == 'b' else 'true'}"), None


def _set_prop(arg):
    parts = arg.split(None, 2)
    if len(parts) != 3:
        return None, "it needs WINDOW PROP VALUE"
    return _call("window.set_prop", _window(parts[0]), f"prop = {lua_string(parts[1])}",
                 f"value = {lua_string(parts[2])}"), None


def _force_idle(arg):
    if not NUM_RE.match(arg):
        return None, "it needs a number of seconds"
    return f"hl.dsp.force_idle({arg})", None


def _focus_field(field, what):
    def handler(arg):
        if not arg:
            return None, f"it needs {what}"
        return _call("focus", f"{field} = {lua_string(arg)}"), None
    return handler


DISPATCHERS = {
    "exec": _exec,
    "execr": _string_arg("exec_raw", "a command"),
    "exit": _no_arg("exit"),
    "killactive": _no_arg("window.close"),
    "forcekillactive": _no_arg("window.kill"),
    "closewindow": _optional_window("window.close"),
    "killwindow": _optional_window("window.kill"),
    "signal": _signal(False),
    "signalwindow": _signal(True),
    "togglefloating": _float("toggle"),
    "setfloating": _float("enable"),
    "settiled": _float("disable"),
    "fullscreen": _fullscreen,
    "fullscreenstate": _fullscreen_state,
    "pseudo": _optional_window("window.pseudo"),
    "pin": _optional_window("window.pin"),
    "centerwindow": _no_arg("window.center"),
    "toggleswallow": _no_arg("window.toggle_swallow"),
    "bringactivetotop": lambda arg: (_call("window.alter_zorder", 'mode = "top"'), None),
    "alterzorder": _alter_zorder,
    "tagwindow": _tag_window,
    "setprop": _set_prop,
    "layoutmsg": _string_arg("layout", "a layout message"),
    "movefocus": _directional("focus", "direction"),
    "focuswindow": _focus_field("window", "a window"),
    "focusmonitor": _focus_field("monitor", "a monitor"),
    "focuscurrentorlast": lambda arg: (_call("focus", "last = true"), None),
    "focusurgentorlast": lambda arg: (_call("focus", "urgent_or_last = true"), None),
    "cyclenext": _cycle_next,
    "swapnext": _swap_next,
    "movewindow": _move_window,
    "swapwindow": _swap_window,
    "resizeactive": _geometry("window.resize"),
    "moveactive": _geometry("window.move"),
    "resizewindowpixel": _geometry("window.resize"),
    "movewindowpixel": _geometry("window.move"),
    "workspace": _workspace,
    "focusworkspaceoncurrentmonitor": _focus_on_current_monitor,
    "movetoworkspace": _move_to_workspace(True),
    "movetoworkspacesilent": _move_to_workspace(False),
    "togglespecialworkspace": _toggle_special,
    "renameworkspace": _rename_workspace,
    "movecurrentworkspacetomonitor": _workspace_to_monitor(True),
    "moveworkspacetomonitor": _workspace_to_monitor(False),
    "swapactiveworkspaces": _swap_active_workspaces,
    "togglegroup": _no_arg("group.toggle"),
    "changegroupactive": _change_group_active,
    "movegroupwindow": _move_group_window,
    "lockgroups": _toggle("group.lock", "all = true"),
    "lockactivegroup": _toggle("group.lock"),
    "denywindowfromgroup": _toggle("window.deny_from_group"),
    "moveintogroup": _directional("window.move", "into_group"),
    "moveintoorcreategroup": _directional("window.move", "into_or_create_group"),
    "moveoutofgroup": _move_out_of_group,
    "movewindoworgroup": _directional("window.move", "direction", "group_aware = true"),
    "movecursortocorner": _cursor_corner,
    "movecursor": _cursor_move,
    "submap": _string_arg("submap", "a submap name"),
    "global": _string_arg("global", "a shortcut name"),
    "event": _string_arg("event", "the event data"),
    "pass": lambda arg: (_call("pass", _window(arg)), None),
    "sendshortcut": _send_shortcut(False),
    "sendkeystate": _send_shortcut(True),
    "dpms": _dpms,
    "forceidle": _force_idle,
    "forcerendererreload": _no_arg("force_renderer_reload"),
}


def _mouse(name, arg):
    """A `bindm` line names what a held button does, not a dispatcher call: `movewindow` drags
    the window under the pointer, `resizewindow` resizes it (1 keeps the aspect ratio, 2 does
    not)."""
    if name == "movewindow" and not arg:
        return "hl.dsp.window.drag()", None
    if name == "resizewindow" and arg in ("", "1", "2"):
        keep = {"": None, "1": "keep_aspect_ratio = true", "2": "keep_aspect_ratio = false"}[arg]
        return _call("window.resize", keep), None
    return None, "a mouse bind takes movewindow or resizewindow"


def translate(name, arg="", mouse=False):
    """(lua, None) for a dispatcher this module can place, (None, reason) for one it cannot."""
    name = (name or "").strip()
    arg = (arg or "").strip()
    if mouse:
        return _mouse(name, arg)
    handler = DISPATCHERS.get(name)
    if not handler:
        return None, f"dispatcher '{name}' has no lua form this converter knows"
    lua, why = handler(arg)
    if lua is None:
        return None, f"dispatcher '{name}': {why}"
    return lua, None


# --- shell commands that call hyprctl ---------------------------------------------------------

SHELL_META = set("$`\"'\\;&|<>()")
KEYWORD_CMD = re.compile(r"^hyprctl\s+keyword\s+([A-Za-z_][\w.:-]*)\s+(.+)$")
DISPATCH_CMD = re.compile(r"^hyprctl\s+dispatch\s+([A-Za-z_]\w*)(?:\s+(.*))?$")
GETOPTION = re.compile(r"(hyprctl\s+getoption\s+)([\w.:-]+)")
# Loose on purpose: these only decide whether a command gets a REVIEW note, and `--batch`
# strings put the legacy words inside quotes where a strict pattern would miss them.
LEGACY_KEYWORD = re.compile(r"\bhyprctl\b.*\bkeyword\s")
LEGACY_DISPATCH = re.compile(r"\bhyprctl\b.*\bdispatch\s+(?!['\"]?hl\.)")


def _option_path(path):
    parts = [p.replace("-", "_") for p in re.split(r"[:.]", path) if p]
    return parts if len(parts) >= 2 and all(re.match(r"^[A-Za-z_]\w*$", p) for p in parts) else None


def _substitution(text):
    """True when the text is exactly one `$( ... )` with balanced parentheses."""
    if not text.startswith("$(") or not text.endswith(")"):
        return False
    depth = 0
    for i, ch in enumerate(text[1:], 1):
        depth += ch == "("
        depth -= ch == ")"
        if depth == 0 and i != len(text) - 1:
            return False
    return depth == 0


def modernize_command(cmd):
    """Rewrite a shell command's legacy hyprctl call for a lua config. Returns (cmd, note).

    `hyprctl keyword` is gone under a lua config and `hyprctl dispatch` wants a lua dispatcher,
    so a command using either loads without complaint and then silently does nothing. Two shapes
    are rewritten, both only when the whole command is the hyprctl call:

        hyprctl keyword a:b VALUE   -> hyprctl eval "hl.config({ a = { b = VALUE } })"
        hyprctl dispatch NAME ARGS  -> hyprctl dispatch 'hl.dsp....'

    VALUE has to be a number, a boolean or one `$(...)` substitution, which is the shape of a
    zoom or gap toggle. Anything else is left exactly as written and the note says why, so the
    caller can flag it instead of shipping a bind that looks converted and is not.
    """
    text = (cmd or "").strip()
    m = KEYWORD_CMD.match(text)
    if m:
        parts, value = _option_path(m.group(1)), m.group(2).strip()
        literal = bool(NUM_RE.match(value)) or value in ("true", "false")
        if parts and '"' not in value and "`" not in value and "\\" not in value \
                and (literal or _substitution(value)):
            value = GETOPTION.sub(lambda g: g.group(1) + g.group(2).replace(":", "."), value)
            body = " = { ".join(parts[:-1]) + f" = {{ {parts[-1]} = {value}" + " }" * len(parts[:-1])
            return (f'hyprctl eval "hl.config({{ {body} }})"',
                    "`hyprctl keyword` does not exist under a lua config; rewritten as "
                    "`hyprctl eval`")
    m = DISPATCH_CMD.match(text)
    if m and not (SHELL_META & set(m.group(2) or "")):
        lua, _why = translate(m.group(1), m.group(2) or "")
        if lua and "'" not in lua:
            return (f"hyprctl dispatch '{lua}'",
                    "`hyprctl dispatch` takes a lua dispatcher under a lua config; rewritten")
    for pattern, what in ((LEGACY_KEYWORD, "hyprctl keyword"),
                          (LEGACY_DISPATCH, "hyprctl dispatch <name>")):
        if pattern.search(text):
            return cmd, (f"this command calls `{what}`, which does nothing under a lua config; "
                         "use `hyprctl eval '<lua>'` or `hyprctl dispatch 'hl.dsp....'`")
    return cmd, None

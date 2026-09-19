#!/usr/bin/env python3
"""The desktop helper scripts bound to the user's keybinds.

These run on a live desktop, in response to a keypress, and every one of them is a thin wrapper
over a Wayland tool (`grim`, `slurp`, `hyprctl`, `hyprpicker`, `wf-recorder`, `tesseract`). Each
picks the best available backend and tells the user what happened via `notify-send`, because a
keybind that silently does nothing is indistinguishable from a keybind that is not bound.

Nothing here writes config. Nothing here needs a backup: the screenshot/recording outputs are
new files in the user's Pictures/Videos, and the `hyprctl keyword` toggles are reverted by the
next `hyprctl reload`.

    helpers.py screenshot [region|window|output] [edit]
    helpers.py screenrecord [region|output] [audio]      (a second call STOPS a running one)
    helpers.py ocr [lang]
    helpers.py colorpicker
    helpers.py powermenu
    helpers.py blur-toggle
    helpers.py gamemode
    helpers.py theme-switch
    helpers.py keybind-cheatsheet
"""
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime

from ..proc import have, ok, out, running


def notify(title, body=""):
    """Best effort. A missing notification daemon is not a reason to fail the action."""
    if have("notify-send"):
        ok(["notify-send", title, body])


def _stamp():
    return datetime.now().strftime("%Y-%m-%d_%H-%M-%S")


def _xdg_user_dir(name, default):
    """`XDG_PICTURES_DIR` / `XDG_VIDEOS_DIR` when exported, else the conventional default.

    These are USER dirs, a different base-directory family from XDG_CONFIG_HOME, so they are
    read directly rather than through ricelib.xdg."""
    return os.environ.get(name) or f"{os.environ.get('HOME', '')}/{default}"


def _hypr_int_option(name, default=1):
    """One integer option out of `hyprctl getoption -j`. Used by the toggles to read the CURRENT
    state rather than keeping their own, which would drift the moment the config is reloaded."""
    try:
        data = json.loads(out(["hyprctl", "getoption", name, "-j"]) or "{}")
    except ValueError:
        return default
    v = data.get("int", data.get("value", default))
    try:
        return int(v)
    except (TypeError, ValueError):
        return default


def _dmenu(prompt, lines, width=""):
    """Ask through whichever launcher is installed, in the community's order of preference."""
    payload = "\n".join(lines)
    for cmd in (
        ["rofi", "-dmenu", "-i", "-p", prompt] + (["-theme-str", width] if width else []),
        ["wofi", "--dmenu", "-i", "-p", prompt],
        ["fuzzel", "--dmenu"],
    ):
        if not have(cmd[0]):
            continue
        try:
            p = subprocess.run(cmd, input=payload, stdout=subprocess.PIPE, text=True)
            return (p.stdout or "").strip()
        except (OSError, subprocess.SubprocessError):
            return ""
    notify("rice", "Install rofi, wofi, or fuzzel")
    return ""


# --- actions ------------------------------------------------------------------------------------

def screenshot(argv):
    mode = argv[0] if argv else "region"
    annotate = argv[1] if len(argv) > 1 else ""
    d = f"{_xdg_user_dir('XDG_PICTURES_DIR', 'Pictures')}/Screenshots"
    os.makedirs(d, exist_ok=True)
    path = f"{d}/{_stamp()}.png"

    if have("grimblast"):
        target = {"window": "active", "output": "output"}.get(mode, "area")
        ok(["grimblast", "save", target, path])
    elif have("hyprshot"):
        m = {"window": "window", "output": "output"}.get(mode, "region")
        ok(["hyprshot", "-m", m, "-o", d, "-f", os.path.basename(path), "-s"])
    else:
        if mode == "window":
            try:
                w = json.loads(out(["hyprctl", "activewindow", "-j"]) or "{}")
                geom = f"{w['at'][0]},{w['at'][1]} {w['size'][0]}x{w['size'][1]}"
                ok(["grim", "-g", geom, path])
            except (ValueError, KeyError, IndexError):
                ok(["grim", path])
        elif mode == "output":
            ok(["grim", path])
        else:
            region = out(["slurp"]).strip()
            if not region:
                return 0        # the user cancelled the selection; that is not a failure
            ok(["grim", "-g", region, path])

    if annotate == "edit":
        if have("satty"):
            ok(["satty", "--filename", path, "--output-filename", path])
        elif have("swappy"):
            ok(["swappy", "-f", path, "-o", path])

    if os.path.isfile(path) and have("wl-copy"):
        try:
            with open(path, "rb") as fh:
                subprocess.run(["wl-copy"], stdin=fh, check=False)
        except (OSError, subprocess.SubprocessError):
            pass

    notify("Screenshot", f"Saved & copied - {os.path.basename(path)}")
    return 0


def screenrecord(argv):
    # A second invocation STOPS the running recorder: one keybind, both directions.
    for rec in ("wf-recorder", "wl-screenrec"):
        if running(rec):
            ok(["pkill", "-INT", "-x", rec])
            notify("Recording", "Stopped")
            return 0

    mode = argv[0] if argv else "region"
    audio = argv[1] if len(argv) > 1 else ""
    d = f"{_xdg_user_dir('XDG_VIDEOS_DIR', 'Videos')}/Recordings"
    os.makedirs(d, exist_ok=True)
    path = f"{d}/{_stamp()}.mp4"

    tool = "wf-recorder" if have("wf-recorder") else ("wl-screenrec" if have("wl-screenrec") else "")
    if not tool:
        notify("Recording", "Install wf-recorder (or wl-screenrec)")
        return 1

    args = [tool, "-f", path]
    if mode == "region":
        region = out(["slurp"]).strip()
        if not region:
            return 0
        args += ["-g", region]
    if audio == "audio":
        args.append("--audio")

    try:
        subprocess.Popen(args, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        notify("Recording", f"{tool} could not be started")
        return 1
    notify("Recording", f"Started -> {os.path.basename(path)}")
    return 0


def ocr(argv):
    lang = argv[0] if argv else "eng"
    region = out(["slurp"]).strip()
    if not region:
        return 0
    fd, img = tempfile.mkstemp(suffix=".png")
    os.close(fd)
    try:
        if not ok(["grim", "-g", region, img]):
            notify("OCR", "The screen region could not be captured")
            return 1
        text = out(["tesseract", img, "-", "-l", lang])
    finally:
        try:
            os.remove(img)
        except OSError:
            pass
    if not text.strip():
        notify("OCR", "No text detected")
        return 0
    try:
        subprocess.run(["wl-copy"], input=text, text=True, check=False)
    except (OSError, subprocess.SubprocessError):
        pass
    notify("OCR", f"Copied {len(text.split())} words to clipboard")
    return 0


def colorpicker(argv):
    color = out(["hyprpicker", "-a", "-f", "hex"]).strip()
    if color:
        notify("Color picker", f"Copied {color}")
    return 0


def powermenu(argv):
    chosen = _dmenu("Power", ["Lock", "Logout", "Suspend", "Reboot", "Shutdown"],
                    "window {width: 14em;} listview {lines: 5;}")
    if chosen == "Lock":
        if have("hyprlock"):
            ok(["hyprlock"])
        else:
            ok(["loginctl", "lock-session"])
    elif chosen == "Logout":
        ok(["hyprctl", "dispatch", "exit"])
    elif chosen == "Suspend":
        ok(["systemctl", "suspend"])
    elif chosen == "Reboot":
        ok(["systemctl", "reboot"])
    elif chosen == "Shutdown":
        ok(["systemctl", "poweroff"])
    return 0


def blur_toggle(argv):
    on = _hypr_int_option("decoration:blur:enabled") == 1
    ok(["hyprctl", "keyword", "decoration:blur:enabled", "0" if on else "1"])
    notify("Blur", "Off" if on else "On")
    return 0


def gamemode(argv):
    """Strip every effect while gaming, and restore by RELOADING rather than by remembering.

    A reload puts the user's real config back, which is correct even if the config changed while
    game mode was on - a remembered set of previous values would not be."""
    on = _hypr_int_option("animations:enabled") == 1
    if on:
        ok(["hyprctl", "--batch",
            "keyword animations:enabled 0;"
            "keyword decoration:shadow:enabled 0;"
            "keyword decoration:blur:enabled 0;"
            "keyword general:gaps_in 0;"
            "keyword general:gaps_out 0;"
            "keyword general:border_size 1;"
            "keyword decoration:rounding 0"])
        notify("Game mode", "ON - effects disabled")
    else:
        ok(["hyprctl", "reload"])
        notify("Game mode", "OFF - effects restored")
    return 0


def _rice_bin():
    from .. import xdg
    override = os.environ.get("RICE_BIN")
    if override:
        return override
    try:
        return f"{xdg.config_path('hypr-rice')}/rice"
    except xdg.NoConfigDirError:
        return ""


def theme_switch(argv):
    rice = _rice_bin()
    if not rice or not os.path.isfile(rice):
        notify("rice", f"engine not found ({rice or 'no config dir'})")
        return 1
    names = [l for l in out(["bash", rice, "themes"]).splitlines()
             if l.strip() and not l.startswith("(")]
    if not names:
        notify("rice", "no saved themes yet")
        return 0
    chosen = _dmenu("Theme", names, "window {width: 20em;}")
    if chosen:
        ok(["bash", rice, "theme", chosen])
    return 0


def keybind_cheatsheet(argv):
    """The binds the COMPOSITOR actually has, read from it - not a hand-kept list that drifts."""
    try:
        binds = json.loads(out(["hyprctl", "binds", "-j"]) or "[]")
    except ValueError:
        binds = []
    lines = []
    for b in binds:
        mods = b.get("modmask", 0)
        names = []
        for bit, name in ((64, "SUPER"), (8, "ALT"), (4, "CTRL"), (1, "SHIFT")):
            if mods & bit:
                names.append(name)
        chord = " + ".join(names + [b.get("key") or str(b.get("keycode", ""))])
        desc = b.get("description") or f"{b.get('dispatcher', '')} {b.get('arg', '')}".strip()
        lines.append(f"{chord:<28} {desc}")
    if not lines:
        notify("Keybinds", "no running Hyprland to read binds from")
        return 0
    _dmenu("Keybinds", sorted(lines), "window {width: 50%;}")
    return 0


ACTIONS = {
    "screenshot": screenshot, "screenrecord": screenrecord, "ocr": ocr,
    "colorpicker": colorpicker, "powermenu": powermenu, "blur-toggle": blur_toggle,
    "gamemode": gamemode, "theme-switch": theme_switch,
    "keybind-cheatsheet": keybind_cheatsheet,
}


def main(argv):
    action = argv[1] if len(argv) > 1 else ""
    fn = ACTIONS.get(action)
    if not fn:
        print(__doc__.strip())
        return 2
    return fn(argv[2:])


if __name__ == "__main__":
    sys.exit(main(sys.argv))

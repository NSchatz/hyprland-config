#!/usr/bin/env python3
"""Make the RUNNING compositor name the config it actually loaded.

"`hyprctl configerrors` is empty" is not the same as "my config is live": an empty error list is
also what a config that was never parsed produces. This asks the instance which file it read, so
a caller can compare that against the file it just wrote.

Three sources, in order of directness: the rolling log, the instance log file, then systeminfo.

Output: one LOADED_CONFIG=<path> per file named, then LOADED_CONFIG_SOURCE=<where it came from>
Exit:   0 named, 2 no running instance, 3 running but it did not say.
"""
import os
import re
import sys

from ..proc import have, ok, out

USING = re.compile(r"Using config:\s*(.+?)\s*$")


def paths_from(text):
    seen, found = set(), []
    for line in (text or "").splitlines():
        m = USING.search(line)
        if not m:
            continue
        p = m.group(1).strip()
        if p and p not in seen:
            seen.add(p)
            found.append(p)
    return found


def _read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


def main(argv):
    if not have("hyprctl") or not ok(["hyprctl", "version"]):
        print("LOADED_CONFIG=unknown")
        print("LOADED_CONFIG_SOURCE=none (no running Hyprland instance)")
        return 2

    found = paths_from(out(["hyprctl", "rollinglog"]))
    source = "rollinglog" if found else "none"

    if not found:
        log_dir = f"{os.environ.get('XDG_RUNTIME_DIR', '')}/hypr"
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
        inst = f"{log_dir}/{sig}/hyprland.log"
        if sig and os.path.isfile(inst):
            found = paths_from(_read(inst))
        elif os.path.isdir(log_dir):
            newest, newest_t = "", -1.0
            for root, _dirs, files in os.walk(log_dir):
                for name in files:
                    if name != "hyprland.log":
                        continue
                    p = os.path.join(root, name)
                    try:
                        t = os.path.getmtime(p)
                    except OSError:
                        continue
                    if t > newest_t:
                        newest, newest_t = p, t
            if newest:
                found = paths_from(_read(newest))
        if found:
            source = "instance-log"

    if not found:
        found = paths_from(out(["hyprctl", "systeminfo"]))
        if found:
            source = "systeminfo"

    if not found:
        print("LOADED_CONFIG=unknown")
        print("LOADED_CONFIG_SOURCE=none (the running instance did not name the config it loaded)")
        return 3

    for p in found:
        print(f"LOADED_CONFIG={p}")
    print(f"LOADED_CONFIG_SOURCE={source}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

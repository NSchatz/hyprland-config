#!/usr/bin/env python3
"""Live-test a Hyprland config: reload it, read the parse errors, and - with --expect - make the
compositor CONFIRM it loaded the file we wrote.

`configerrors` being empty is not proof the config is live. An empty error list is also what a
config that was never parsed produces, so `ok` without --expect means only "the compositor
declined to complain". With --expect it means "the compositor says it loaded THIS file".

Usage: verify-config.sh [--no-reload] [--expect <file>]
Exit:  0 ok, 1 parse errors, 2 no running instance, 3 clean but unconfirmed.
"""
import os
import sys

from ..proc import have, ok, out
from . import loadedconfig


def canon(p):
    try:
        return os.path.realpath(p)
    except OSError:
        return p


def main(argv):
    reload_first = True
    expect = ""
    args = argv[1:]
    i = 0
    while i < len(args):
        a = args[i]; i += 1
        if a == "--no-reload":
            reload_first = False
        elif a == "--expect":
            if i >= len(args):
                print("ERROR: --expect needs a file", file=sys.stderr)
                return 2
            expect = args[i]; i += 1
        else:
            print(f"ERROR: unknown argument: {a}", file=sys.stderr)
            return 2

    if not have("hyprctl") or not ok(["hyprctl", "version"]):
        print("VERIFY=skipped (no running Hyprland instance; rely on static validation)")
        return 2

    if reload_first:
        ok(["hyprctl", "reload"])

    errs = "\n".join(l for l in out(["hyprctl", "configerrors"]).splitlines() if l.strip())
    if errs:
        print("VERIFY=errors")
        print(errs)
        return 1

    if not expect:
        print("VERIFY=ok (config loaded, no parse errors)")
        return 0

    import io
    from contextlib import redirect_stdout
    buf = io.StringIO()
    with redirect_stdout(buf):
        loadedconfig.main(["loaded-config"])
    loaded_out = buf.getvalue()
    print(loaded_out, end="" if loaded_out.endswith("\n") or not loaded_out else "\n")

    want = canon(expect)
    for line in loaded_out.splitlines():
        if not line.startswith("LOADED_CONFIG="):
            continue
        p = line[len("LOADED_CONFIG="):]
        if not p or p == "unknown":
            continue
        if canon(p) == want:
            print(f"CONFIRMED_CONFIG={expect}")
            print(f"VERIFY=ok (the compositor confirms it loaded {expect}, with no parse errors)")
            return 0

    print(f"EXPECTED_CONFIG={expect}")
    print(f"VERIFY=unconfirmed (no parse errors, but the compositor did not confirm it loaded "
          f"{expect}; an empty error list is also what a config that was never parsed produces)")
    return 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))

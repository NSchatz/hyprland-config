#!/usr/bin/env python3
"""Wipe the hypr config directory back to a minimal, working baseline - behind a full backup,
a live test, and an automatic rollback.

The order is the whole safety story: refuse an unusable target, emit the bare config into a
scratch dir FIRST (so an undecidable config language costs nothing), back up, replace,
live-test, and roll back if the compositor will not take it.

Exit: 0 reset (or installed-untested), 1 rolled back / no backup to restore, 2 internal failure,
      3 the config language is undecided, 4 the target is unusable.
"""
import os
import shutil
import sys
import tempfile

from .. import xdg
from ..clock import unique_backup
from . import emitconfig, verifyconfig


def _capture(fn, *args):
    import io
    from contextlib import redirect_stdout
    buf = io.StringIO()
    with redirect_stdout(buf):
        rc = fn(*args)
    return rc, buf.getvalue()


def main(argv):
    target = xdg.config_target("hypr", os.environ.get("HYPR_DIR", ""))
    if target is None:
        print("RESET=refused-no-config-dir")
        return 4

    if os.path.lexists(target) and not os.path.isdir(target):
        print(f"ERROR: reset target '{target}' exists but is not a directory.", file=sys.stderr)
        print(f"TARGET={target}")
        print("RESET=refused-target-not-writable")
        return 4

    if os.path.isdir(target) and not os.access(target, os.W_OK):
        print(f"ERROR: reset target '{target}' exists but cannot be written to "
              "(permission denied).", file=sys.stderr)
        print("       Nothing was changed. Fix the permissions on that directory and re-run.",
              file=sys.stderr)
        print(f"TARGET={target}")
        print("RESET=refused-target-not-writable")
        return 4

    try:
        staging = tempfile.mkdtemp(prefix="hypr-reset.")
    except OSError:
        print("ERROR: could not create a staging directory", file=sys.stderr)
        return 2

    try:
        erc, emit_out = _capture(emitconfig.main, ["emit-config", staging])
        print(emit_out, end="" if emit_out.endswith("\n") or not emit_out else "\n")

        if erc == 3:
            print(f"Nothing was changed; {target} is untouched.")
            print(f"TARGET={target}")
            print("RESET=refused-undecided")
            return 3
        if erc != 0:
            print(f"TARGET={target}")
            print("RESET=refused-undecided")
            return 2

        emitted = ""
        for line in emit_out.splitlines():
            if line.startswith("EMITTED="):
                emitted = line[len("EMITTED="):]
                break
        if not emitted or not os.path.isfile(emitted):
            print("ERROR: the emitter produced no config file", file=sys.stderr)
            return 2

        backup = ""
        try:
            has_content = os.path.isdir(target) and bool(os.listdir(target))
        except OSError:
            has_content = False
        if has_content:
            backup = unique_backup(target)
            try:
                shutil.copytree(target, backup, symlinks=True, dirs_exist_ok=False)
            except (OSError, shutil.Error):
                print(f"ERROR: could not back up '{target}'; nothing was changed.",
                      file=sys.stderr)
                print("RESET=refused-backup-failed")
                return 4
            print(f"BACKUP={backup}")
        else:
            print("BACKUP=none (no existing config to back up)")

        # Replace, rather than merge: a reset that leaves the old topic files behind is not one.
        shutil.rmtree(target, ignore_errors=True)
        os.makedirs(target, exist_ok=True)
        shutil.copyfile(emitted, f"{target}/{os.path.basename(emitted)}")
        print(f"INSTALLED={os.path.basename(emitted)}")
        print(f"TARGET={target}")

        vrc, vout = _capture(verifyconfig.main, ["verify-config"])
        print(vout, end="" if vout.endswith("\n") or not vout else "\n")

        if vrc == 0:
            print("RESET=ok")
            return 0
        if vrc == 2:
            print("RESET=installed-untested (no running Hyprland; test on next login)")
            return 0

        if backup and os.path.isdir(backup):
            shutil.rmtree(target, ignore_errors=True)
            shutil.copytree(backup, target, symlinks=True, dirs_exist_ok=True)
            _capture(verifyconfig.main, ["verify-config"])
            print(f"RESET=rolled-back (bare config errored; restored {backup})")
            return 1

        print("RESET=errors-no-backup (bare config has parse errors; no backup existed to restore)")
        return 1
    finally:
        shutil.rmtree(staging, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main(sys.argv))

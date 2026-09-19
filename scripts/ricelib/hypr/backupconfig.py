#!/usr/bin/env python3
"""Timestamped backup of the whole hypr config directory, before anything writes into it.

This directory's backup is a SEPARATE contract from the restore-point mechanism: it is taken
wholesale here and put back wholesale by safe-apply.sh's rollback, which is why restore points
refuse to enrol it or anything containing it.

Output: TARGET=<dir>, then BACKUP=<path> | BACKUP=none (...) | BACKUP=failed (...)
Exit:   0 backed up or nothing to back up, 2 no config dir, 4 the copy failed.
"""
import os
import shutil
import sys

from .. import xdg
from ..clock import stamp


def main(argv):
    # config_target, not config_path: this is a user-facing run, so it owes the notice when a
    # relative XDG_CONFIG_HOME was rejected and the refusal report when nothing resolved.
    target = xdg.config_target("hypr", os.environ.get("HYPR_DIR", ""))
    if target is None:
        print("BACKUP=none (no config directory could be determined)")
        return 2

    print(f"TARGET={target}")

    try:
        has_content = os.path.isdir(target) and bool(os.listdir(target))
    except OSError:
        has_content = False

    if not has_content:
        print("BACKUP=none (no existing config to back up)")
        return 0

    backup = f"{target}.bak.{stamp()}"
    try:
        shutil.copytree(target, backup, symlinks=True, dirs_exist_ok=False)
    except (OSError, shutil.Error):
        print(f"ERROR: could not back up '{target}' to '{backup}'; nothing was changed.",
              file=sys.stderr)
        print(f"BACKUP=failed ({backup} could not be written)")
        return 4

    print(f"BACKUP={backup}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

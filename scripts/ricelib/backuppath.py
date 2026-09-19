#!/usr/bin/env python3
"""Timestamped backup of arbitrary config files/dirs before editing them.

Used by the rice and edit-config skills for everything OUTSIDE the hypr config dir (that
directory has its own backup contract in `backup-config.sh` / `safe-apply.sh`).

Prints one line per path:
    BACKUP <original> -> <backup>            copied
    BACKUP <original> -> none (did not exist)
    BACKUP <original> -> FAILED (<why>)      could not be backed up: DO NOT edit that path
    NOT_ENROLLED <original>                  copied, but left OUT of the restore point: it
                                             contains a surface with its own separate restore,
                                             so `rice restore` must never put it back
and one trailing line:
    RESTORE_POINT=<apply-id>                 undo the whole set: rice restore <apply-id>

Every path in one invocation shares an apply id, so a whole change set restores together. Set
RICE_APPLY_ID to join an apply already in progress - that is how a shell-rc edit made as part of
a theming apply shares that apply's restore point; leave it unset and this invocation gets its
own, restorable on its own.

Exit: 0 when every path is backed up (or did not exist), 1 when at least one could not be - the
caller must not edit a path whose backup failed - 2 on bad usage.
"""
import os
import shutil
import sys

from . import restorepoint as rp


def _copy(src, dst):
    try:
        if os.path.islink(src) or not os.path.isdir(src):
            shutil.copy2(src, dst, follow_symlinks=False)
        else:
            shutil.copytree(src, dst, symlinks=True, dirs_exist_ok=False)
        return True
    except (OSError, shutil.Error):
        return False


def main(argv):
    paths = argv[1:]
    if not paths:
        print("ERROR: usage: backup-path.sh <path> [<path> ...]", file=sys.stderr)
        return 2

    apply_id = rp.ensure_apply_id()
    if not apply_id:
        print(
            f"ERROR: unusable RICE_APPLY_ID '{os.environ.get('RICE_APPLY_ID', '')}' "
            "(no '/', no whitespace, no leading dot)",
            file=sys.stderr,
        )
        return 2

    rc = 0
    for raw in paths:
        p = rp.expand(raw)
        excluded = rp.excluded(p)
        contains = rp.contains_excluded(p)

        if excluded or contains:
            # Out of the restore point's scope, in BOTH directions: that directory's restore is a
            # separate contract, and a path that CONTAINS it could only be put back by replacing
            # it wholesale, which would take that directory with it. Either way, back it up
            # exactly as this has always done - a copy touches nothing - but do not enrol it, so
            # no restore here ever writes over that contract.
            if os.path.lexists(p):
                b = f"{p.rstrip('/')}.bak.{apply_id}"
                if _copy(p, b):
                    print(f"BACKUP {p} -> {b}")
                else:
                    print(f"BACKUP {p} -> FAILED (could not write {b})")
                    rc = 1
            else:
                print(f"BACKUP {p} -> none (did not exist)")
            if contains:
                print(
                    f"NOT_ENROLLED {p} (it contains a surface with its own separate restore; "
                    "put this backup back by hand, not with rice restore)"
                )
            continue

        res = rp.protect(p)
        if not res.ok:
            print(f"BACKUP {p} -> FAILED ({res.error})")
            rc = 1
            continue

        state = res.state
        if state in ("file", "already-file"):
            print(f"BACKUP {p} -> {res.backup}")
        elif state == "new":
            print(f"BACKUP {p} -> none (did not exist)")
        elif state == "already-new":
            print(f"BACKUP {p} -> none (created by this apply; restoring removes it)")
        elif state in ("covered", "already-covered"):
            # Inside a surface this same apply already enrolled: that surface's backup holds this
            # path's prior content and puts it back. A second copy here would sit inside the
            # surface the restore replaces wholesale, so it is deliberately not taken.
            print(f"BACKUP {p} -> covered by {res.cover} (restore point {apply_id} puts it back)")
        else:
            print(f"BACKUP {p} -> none (did not exist)")

    print(f"RESTORE_POINT={apply_id}")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))

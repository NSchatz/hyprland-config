#!/usr/bin/env python3
"""The undo: put every path one apply wrote back the way it was, as one set.

    rice-restore.sh <apply-id>   undo that apply
    rice-restore.sh --list       what can be undone (newest first)

A restore point clears ONLY when every file in it is back, so re-running after a partial failure
is always safe and always picks up where it stopped. Entries already put back are skipped rather
than redone, which is what makes an interrupted restore resumable.

Replay order matters and is not enrolment order: a surface is always replayed BEFORE anything
enrolled inside it, because a directory goes back wholesale and would otherwise overwrite a child
that had just been restored. `restorepoint.replay_order` sorts by path depth to guarantee that.

What this never touches: the hypr config dir, which has its own backup contract, in both
directions - a path inside it is skipped, and a path that CONTAINS it is refused by name rather
than quietly passed over.

Exit: 0 restored (point cleared), 1 partial (point kept, re-runnable), 2 usage, 3 no such point.
"""
import os
import shutil
import sys

from . import restorepoint as rp


def _restore_file(dirpath, target, backup, counts):
    if not os.path.lexists(backup):
        print(f"RESTORE_FAILED {target} (backup missing: {backup})")
        counts["failed"] += 1
        return
    if not os.access(backup, os.R_OK):
        print(f"RESTORE_FAILED {target} (backup unreadable: {backup})")
        counts["failed"] += 1
        return

    parent = os.path.dirname(target)
    if parent:
        try:
            os.makedirs(parent, exist_ok=True)
        except OSError:
            pass

    is_dir = os.path.isdir(backup) and not os.path.islink(backup)
    if is_dir:
        # Directory surface: replace wholesale from the backup, so files the apply ADDED inside
        # it go away too. A merge would leave them behind and the restore would be incomplete.
        shutil.rmtree(target, ignore_errors=True)
        if os.path.lexists(target):
            try:
                os.remove(target)
            except OSError:
                pass

    try:
        if is_dir:
            shutil.copytree(backup, target, symlinks=True, dirs_exist_ok=True)
        else:
            if os.path.lexists(target):
                try:
                    os.remove(target)
                except OSError:
                    pass
            shutil.copy2(backup, target, follow_symlinks=False)
    except (OSError, shutil.Error) as exc:
        print(f"RESTORE_FAILED {target} (cannot write target: {exc})")
        counts["failed"] += 1
        return

    print(f"RESTORED {target}")
    counts["restored"] += 1
    if is_dir:
        # Wholesale replacement overwrote everything inside it, including anything an earlier
        # attempt had already put back. Those entries replay after this one (container first),
        # so their done-marks have to go.
        rp.unmark_below(dirpath, target)
    rp.mark_done(dirpath, target)


def _restore_new(dirpath, target, counts):
    """`new` means the apply CREATED this path, so putting things back means removing it."""
    was_dir = os.path.isdir(target) and not os.path.islink(target)
    if not os.path.lexists(target):
        print(f"REMOVED {target} (already gone)")
        counts["removed"] += 1
        rp.mark_done(dirpath, target)
        return
    try:
        if was_dir:
            shutil.rmtree(target)
        else:
            os.remove(target)
    except OSError as exc:
        print(f"RESTORE_FAILED {target} (cannot remove the file this apply created: {exc})")
        counts["failed"] += 1
        return
    print(f"REMOVED {target}")
    counts["removed"] += 1
    if was_dir:
        rp.unmark_below(dirpath, target)
    rp.mark_done(dirpath, target)


def _restore_covered(dirpath, target, cover, counts):
    """Folded into an enclosing surface at enrolment: that surface holds this path's prior
    content and was replayed just above. Nothing to copy - a nested backup would have been
    destroyed by the wholesale replacement, which is exactly why none was taken."""
    if cover and rp.is_done(dirpath, cover):
        if os.path.lexists(target):
            print(f"RESTORED {target} (with {cover})")
            counts["restored"] += 1
        else:
            print(f"REMOVED {target} (with {cover})")
            counts["removed"] += 1
        rp.mark_done(dirpath, target)
    else:
        print(
            f"RESTORE_FAILED {target} (the surface that holds it was not restored: "
            f"{cover or 'unknown'})"
        )
        counts["failed"] += 1


def main(argv):
    arg = argv[1] if len(argv) > 1 else ""

    if arg in ("", "-h", "--help"):
        print(__doc__.strip())
        return 2

    if arg in ("--list", "list"):
        points = rp.list_points()
        if not points:
            print(f"(no restore points under {rp.state_dir()})")
            return 0
        for pid, n in points:
            print(f"{pid}\t{n} file(s)")
        return 0

    if arg.startswith("-"):
        print(f"ERROR: unknown option '{arg}' (usage: rice-restore.sh <apply-id> | --list)",
              file=sys.stderr)
        return 2

    apply_id = arg
    dirpath = rp.point_dir(apply_id)
    entries = f"{dirpath}/entries.tsv"
    try:
        empty = os.path.getsize(entries) == 0
    except OSError:
        empty = True
    if empty:
        print(
            f"RESTORE=nothing-to-restore {apply_id} (no restore point under {rp.state_dir()}: "
            "nothing was applied under that identifier, or it was already restored and the point "
            "cleared)"
        )
        return 3

    counts = {"restored": 0, "removed": 0, "already": 0, "failed": 0}

    for kind, target, backup in rp.replay_order(entries):
        if not kind or kind.startswith("#") or not target:
            continue

        # Defence in depth. The recorder never enrols an out-of-scope path; these two guards act
        # only if a ledger is ever hand-edited to hold one.
        if rp.excluded(target):
            continue
        if rp.contains_excluded(target):
            # A directory goes back wholesale, so putting back a path that CONTAINS an
            # out-of-scope surface would take that surface with it. Say so by path rather than
            # skipping quietly - this one is worth the user seeing.
            print(f"RESTORE_FAILED {target} (refusing: it contains a surface this command must never touch)")
            counts["failed"] += 1
            continue
        if not rp.safe_target(target):
            print(f"RESTORE_FAILED {target} (refusing to touch that path)")
            counts["failed"] += 1
            continue

        if rp.is_done(dirpath, target):
            print(f"ALREADY_RESTORED {target}")
            counts["already"] += 1
            continue

        if kind == "file":
            _restore_file(dirpath, target, backup, counts)
        elif kind == "new":
            _restore_new(dirpath, target, counts)
        elif kind == "covered":
            _restore_covered(dirpath, target, backup, counts)
        else:
            print(f"RESTORE_FAILED {target} (unknown restore-point entry kind '{kind}')")
            counts["failed"] += 1

    if counts["failed"] == 0:
        rp.clear(apply_id)
        print(
            f"RESTORE=done {apply_id} ({counts['restored']} restored, {counts['removed']} removed, "
            f"{counts['already']} already restored; restore point cleared)"
        )
        return 0

    print(
        f"RESTORE=partial {apply_id} ({counts['restored']} restored, {counts['removed']} removed, "
        f"{counts['failed']} failed; restore point kept at {dirpath} - fix the paths reported "
        f"above and re-run: rice restore {apply_id})"
    )
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))

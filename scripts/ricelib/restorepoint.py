#!/usr/bin/env python3
"""Back a path up and enrol it in an apply's restore point, so the caller may overwrite it.

This is the mechanism behind the invariant this plugin is built on: every write outside
`~/.config/hypr` is reversible, and reversibility is PROVEN BEFORE the write, not after. A
caller asks `protect()` for permission; a False answer means it must not write, and the reason
says why. Nothing here ever installs, renders or overwrites - it only makes a write undoable.

Two directories are deliberately out of scope. The hypr config dir has its own separate backup
contract (`backup-config.sh` / `safe-apply.sh`), so it is never enrolled here - and neither is
any path that CONTAINS it, because a directory is restored wholesale and putting an ancestor
back would take the config dir with it.

The ledger for one apply lives at `<state>/restore/<apply-id>/`:
    entries.tsv   <kind> <TAB> <target> <TAB> <backup>
                  kind is `file` (a backup sidecar holds the prior content),
                  `new` (nothing was there; the restore removes what the apply created), or
                  `covered` (an enrolled ancestor's backup already holds it)
    done.tsv      targets already put back, so an interrupted restore resumes instead of redoing

`scripts/restore-point.sh` is a thin shim over this module for the bash callers that only need
`rp_protect` and friends; `xdg-config.sh` deliberately stays pure bash because it is sourced by
scripts that run before python exists (see tests/test_xdg_parity.sh).
"""
import os
import shutil
import subprocess
import sys

from . import xdg
from .clock import stamp

__all__ = [
    "state_root", "state_dir", "expand", "canon", "excluded", "contains_excluded",
    "new_id", "point_dir", "protect", "Protected", "mark_done", "is_done", "clear",
    "list_points", "replay_order", "safe_target", "unmark_below",
]


# --- where state lives ------------------------------------------------------------------------

def state_root(env=None):
    """The base every durable state surface hangs off - restore points, the install record, the
    browser-preference record. One answer in one place, for the same reason xdg is: a second
    spelling of `$HOME/.local/state` is how a record gets written where nothing later reads it.
    $XDG_STATE_HOME is the XDG base directory for state; `$HOME/.local/state` is its default."""
    env = os.environ if env is None else env
    base = env.get("XDG_STATE_HOME") or f"{env.get('HOME', '')}/.local/state"
    return f"{base}/hypr-rice"


def state_dir(env=None):
    env = os.environ if env is None else env
    override = env.get("RICE_RESTORE_DIR")
    if override:
        return override.rstrip("/") or "/"
    return f"{state_root(env)}/restore"


def point_dir(apply_id, env=None):
    return f"{state_dir(env)}/{apply_id}"


# --- paths ------------------------------------------------------------------------------------

def canon(p):
    """Strip trailing slashes so `~/.config/waybar/` and `~/.config/waybar` are one path.
    Containment is decided by string prefix, so the ledger must be canonical about this."""
    while len(p) > 1 and p.endswith("/"):
        p = p[:-1]
    return p


def expand(p, env=None):
    """`~` expansion routed through the shared config base, so the path enrolled here is
    byte-for-byte the path the render pass writes."""
    return xdg.expand_path(p, env)[0]


def excluded_dir(env=None):
    """The one directory this mechanism must never enrol, restore or report on. It has to be the
    SAME directory install-config.sh / reset-config.sh write to; resolving it any other way would
    quietly re-open the boundary for a user who moved XDG_CONFIG_HOME."""
    env = os.environ if env is None else env
    try:
        d = xdg.config_path("hypr", env.get("HYPR_DIR", ""), env)
    except xdg.NoConfigDirError:
        d = env.get("HYPR_DIR") or f"{env.get('HOME', '')}/.config/hypr"
    return canon(d)


def excluded(path, env=None):
    """True for any path inside the excluded dir."""
    p = canon(expand(path, env))
    d = excluded_dir(env)
    return p == d or p.startswith(d + "/")


def contains_excluded(path, env=None):
    """True when the excluded dir sits INSIDE this path. Containment cuts both ways and the guard
    has to answer both questions. A directory is restored wholesale, so putting an ancestor of the
    excluded dir back would revert that directory too - the one thing no restore here may do. The
    test is lexical, so it holds whether or not the directory exists yet."""
    p = canon(expand(path, env))
    if not p:
        return False
    d = excluded_dir(env)
    if p == "/":
        return len(d) > 1 and d.startswith("/")
    return d.startswith(p + "/")


def safe_target(p, env=None):
    """A target this mechanism may write to or remove during a restore. Guards against a
    hand-edited ledger turning a restore into `rm -rf $HOME`."""
    env = os.environ if env is None else env
    if not p or p == "/" or not p.startswith("/"):
        return False
    home = env.get("HOME", "").rstrip("/")
    return not (home and p == home)


# --- apply ids --------------------------------------------------------------------------------

def _id_usable(apply_id):
    if not apply_id or apply_id.startswith("."):
        return False
    return not any(c == "/" or c.isspace() for c in apply_id)


def new_id(env=None):
    """A fresh apply id: the timestamp every file of one apply shares. Suffixed when a point with
    that second already exists, so two applies in the same second stay separate restore points."""
    env = os.environ if env is None else env
    base = stamp(env)
    store = state_dir(env)
    cand, n = base, 1
    while os.path.exists(f"{store}/{cand}") and n < 100:
        cand = f"{base}-{n}"
        n += 1
    return cand


def ensure_apply_id(env=None):
    """Settle the id this process enrols under. The caller's own value when it set one - that is
    how the three write stages of a single apply share one restore point - otherwise a fresh one,
    put back into the environment so every later surface joins the same point."""
    env = os.environ if env is None else env
    cur = env.get("RICE_APPLY_ID", "")
    if cur:
        if not _id_usable(cur):
            return None
        return cur
    fresh = new_id(env)
    env["RICE_APPLY_ID"] = fresh
    return fresh


# --- the ledger -------------------------------------------------------------------------------

def _entries(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.rstrip("\n")
                if not line:
                    continue
                parts = line.split("\t")
                while len(parts) < 3:
                    parts.append("")
                yield parts[0], parts[1], parts[2]
    except OSError:
        return


def entry_kind(entries_file, target):
    for kind, tgt, _ in _entries(entries_file):
        if tgt == target:
            return kind
    return None


def entry_cover(entries_file, target):
    for kind, tgt, cover in _entries(entries_file):
        if kind == "covered" and tgt == target:
            return cover
    return None


def enrolled_ancestor(entries_file, target):
    """The deepest already-enrolled surface that strictly CONTAINS target, if any.

    `covered` entries are never answers: they hold no backup of their own, so folding into one
    would fold into nothing. The deepest real container is the one whose backup is closest in
    time to this write, and it is the one the restore replays immediately before this path."""
    best = ""
    for kind, tgt, _ in _entries(entries_file):
        if kind == "covered":
            continue
        a = tgt.rstrip("/")
        if a and target.startswith(a + "/") and len(a) > len(best):
            best = a
    return best or None


def replay_order(entries_file):
    """Replay order for one entries file: a surface always comes BEFORE anything enrolled inside
    it. Depth (the number of '/' in the target) decides that on its own - a container always has
    fewer path components than what it contains - and entries at equal depth keep their enrolment
    order, so an apply's own write order is otherwise untouched."""
    rows = list(_entries(entries_file))
    return [r for _, r in sorted(
        ((( row[1].count("/"), i), row) for i, row in enumerate(rows)),
        key=lambda pair: pair[0],
    )]


def _append(dirpath, kind, target, backup):
    try:
        with open(f"{dirpath}/entries.tsv", "a", encoding="utf-8") as fh:
            fh.write(f"{kind}\t{target}\t{backup}\n")
        return True
    except OSError:
        return False


# --- the write path ---------------------------------------------------------------------------

class Protected:
    """The verdict. `ok` False means the caller MUST NOT write; `error` says why."""

    def __init__(self, ok, state="", backup="", apply_id="", cover="", error=""):
        self.ok = ok
        self.state = state          # excluded|already-<kind>|covered|file|new|contains-excluded
        self.backup = backup
        self.apply_id = apply_id
        self.cover = cover
        self.error = error

    def __bool__(self):
        return self.ok


def protect(path, env=None):
    """Back the path up and enrol it, so the caller may overwrite it.

    A path with no prior content is enrolled too: the "this apply created it" record is what lets
    a later restore remove the file again, so failing to persist THAT is exactly as fatal as
    failing to copy a backup - the caller skips the surface either way, rather than writing a
    file nothing can take back."""
    env = os.environ if env is None else env

    target = canon(expand(path or "", env))
    if not target:
        return Protected(False, error="empty path")

    if excluded(target, env):
        return Protected(True, state="excluded")

    if contains_excluded(target, env):
        # The excluded dir sits inside this path, so restoring it would replace that directory
        # wholesale along with everything else - the one thing this mechanism never does. There
        # is no way back from this write that respects that boundary, so there is no write. (A
        # plain COPY of such a path is still fine and backup-path.sh still takes one; what is
        # refused is making this mechanism responsible for putting it back.)
        return Protected(
            False, state="contains-excluded",
            error="refusing to enrol a path that contains a surface with its own separate restore",
        )

    apply_id = ensure_apply_id(env)
    if not apply_id:
        return Protected(
            False,
            error=f"unusable apply id '{env.get('RICE_APPLY_ID', '')}' "
                  "(no '/', no whitespace, no leading dot)",
        )

    dirpath = point_dir(apply_id, env)
    try:
        os.makedirs(dirpath, exist_ok=True)
    except OSError:
        return Protected(False, apply_id=apply_id,
                         error=f"restore point is not writable: {dirpath}")

    entries_file = f"{dirpath}/entries.tsv"

    kind = entry_kind(entries_file, target)
    if kind:
        # Already enrolled earlier in this same apply. The first enrolment holds the prior state;
        # re-copying now would capture this apply's own output as "what was there before".
        res = Protected(True, state=f"already-{kind}", apply_id=apply_id)
        if kind == "file":
            res.backup = f"{target.rstrip('/')}.bak.{apply_id}"
        elif kind == "covered":
            res.cover = entry_cover(entries_file, target) or ""
        return res

    ancestor = enrolled_ancestor(entries_file, target)
    if ancestor:
        # This path sits inside a surface already enrolled in this apply. That surface was copied
        # before this apply wrote anything under it, so its backup already holds this path's prior
        # content - and a sidecar written here would live INSIDE the surface a restore replaces
        # wholesale, which is exactly how it would be destroyed. Fold into the surface instead.
        if not _append(dirpath, "covered", target, ancestor):
            return Protected(False, apply_id=apply_id,
                             error=f"restore point entry could not be written: {entries_file}")
        return Protected(True, state="covered", cover=ancestor, apply_id=apply_id)

    if os.path.lexists(target):
        backup = f"{target.rstrip('/')}.bak.{apply_id}"
        try:
            if os.path.islink(target) or not os.path.isdir(target):
                shutil.copy2(target, backup, follow_symlinks=False)
            else:
                shutil.copytree(target, backup, symlinks=True, dirs_exist_ok=False)
        except (OSError, shutil.Error):
            return Protected(False, apply_id=apply_id,
                             error=f"backup could not be written: {backup}")
        if not _append(dirpath, "file", target, backup):
            return Protected(False, apply_id=apply_id,
                             error=f"restore point entry could not be written: {entries_file}")
        return Protected(True, state="file", backup=backup, apply_id=apply_id)

    if not _append(dirpath, "new", target, "-"):
        return Protected(False, apply_id=apply_id,
                         error=f"restore point entry could not be written: {entries_file}")
    return Protected(True, state="new", apply_id=apply_id)


# --- restore-side bookkeeping -------------------------------------------------------------------

def mark_done(dirpath, target):
    try:
        with open(f"{dirpath}/done.tsv", "a", encoding="utf-8") as fh:
            fh.write(f"{target}\n")
        return True
    except OSError:
        return False


def is_done(dirpath, target):
    try:
        with open(f"{dirpath}/done.tsv", encoding="utf-8", errors="replace") as fh:
            return any(line.rstrip("\n") == target for line in fh)
    except OSError:
        return False


def unmark_below(dirpath, parent):
    """Drop the done-marks of everything nested inside parent. A surface restored wholesale
    replaces its whole content, so anything inside it that an earlier (interrupted or partial)
    attempt had already put back has just been overwritten and must be replayed."""
    done = f"{dirpath}/done.tsv"
    if not os.path.isfile(done):
        return True
    prefix = canon(parent) + "/"
    try:
        with open(done, encoding="utf-8", errors="replace") as fh:
            kept = [l for l in fh if not l.startswith(prefix)]
        tmp = f"{done}.{os.getpid()}"
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.writelines(kept)
        os.replace(tmp, done)
        return True
    except OSError:
        return False


def clear(apply_id, env=None):
    """Drop a restore point. Only ever called once every file in it is back the way it was. The
    .bak.<apply-id> sidecars are deliberately left on disk: they are the user's own copies, and
    clearing the ledger is what makes a second restore report "nothing to restore"."""
    if not apply_id or "/" in apply_id or apply_id.startswith("."):
        return False
    shutil.rmtree(point_dir(apply_id, env), ignore_errors=True)
    return True


def list_points(env=None):
    """(id, entry-count) newest first. Empty list when there is nothing to restore."""
    store = state_dir(env)
    out = []
    try:
        names = sorted(os.listdir(store), reverse=True)
    except OSError:
        return out
    for name in names:
        d = f"{store}/{name}"
        entries = f"{d}/entries.tsv"
        if not os.path.isdir(d):
            continue
        try:
            if os.path.getsize(entries) == 0:
                continue
        except OSError:
            continue
        n = sum(1 for _ in _entries(entries))
        out.append((name, n))
    return out


# --- CLI ----------------------------------------------------------------------------------------

def main(argv):
    cmd = argv[1] if len(argv) > 1 else "help"
    args = argv[2:]

    if cmd == "new-id":
        print(new_id())
        return 0

    if cmd == "state-root":
        print(state_root())
        return 0

    if cmd == "state-dir":
        print(state_dir())
        return 0

    if cmd == "point-dir":
        print(point_dir(args[0] if args else ""))
        return 0

    if cmd == "expand":
        print(expand(args[0] if args else ""))
        return 0

    if cmd == "canon":
        print(canon(args[0] if args else ""))
        return 0

    if cmd == "excluded":
        return 0 if excluded(args[0] if args else "") else 1

    if cmd == "contains-excluded":
        return 0 if contains_excluded(args[0] if args else "") else 1

    if cmd == "safe-target":
        return 0 if safe_target(args[0] if args else "") else 1

    if cmd == "list":
        points = list_points()
        if not points:
            print(f"(no restore points under {state_dir()})")
            return 0
        for pid, n in points:
            print(f"{pid}\t{n} file(s)")
        return 0

    if cmd == "show":
        pid = args[0] if args else ""
        entries = f"{point_dir(pid)}/entries.tsv"
        rows = list(_entries(entries))
        if not rows:
            print(f"(no restore point '{pid}' under {state_dir()})", file=sys.stderr)
            return 3
        for kind, tgt, backup in rows:
            print(f"{kind}\t{tgt}\t{backup}")
        return 0

    if cmd == "protect":
        # One path per invocation; prints the KEY=value fields the bash shim re-exports.
        if not args:
            print("ERROR: usage: restorepoint.py protect <path>", file=sys.stderr)
            return 2
        res = protect(args[0])
        print(f"RP_STATE={res.state}")
        print(f"RP_BACKUP={res.backup}")
        print(f"RP_ID={res.apply_id}")
        print(f"RP_COVER={res.cover}")
        print(f"RP_ERROR={res.error}")
        # The id this process settled on has to reach the caller's environment too.
        if res.apply_id:
            print(f"RICE_APPLY_ID={res.apply_id}")
        return 0 if res.ok else 1

    if cmd == "record":
        if not args:
            print("ERROR: usage: restorepoint.py record <path> [<path> ...]", file=sys.stderr)
            return 2
        rc = 0
        last_id = ""
        for p in args:
            res = protect(p)
            if res.apply_id:
                last_id = res.apply_id
            if res.ok:
                print(f"PROTECTED {expand(p)} ({res.state})")
            else:
                print(f"PROTECT_FAILED {expand(p)} ({res.error})", file=sys.stderr)
                rc = 1
        if last_id:
            print(f"RESTORE_POINT={last_id}")
        return rc

    if cmd in ("help", "-h", "--help"):
        print(__doc__.strip())
        return 0

    print(f"unknown command: {cmd} (try: restorepoint.py help)", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

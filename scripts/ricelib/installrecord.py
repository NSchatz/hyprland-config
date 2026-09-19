#!/usr/bin/env python3
"""The install record: what this plugin put on the machine, left ON the machine.

A package install is the one thing this plugin does that a config restore cannot undo - the
packages stay. Without this, the only account of a transaction was a verdict line in a chat
transcript, gone the moment the session is. Every transaction leaves a record naming every
package installed, every one already present, every one that failed (with the one-line reason
the install reported) and every AUR helper built from source, and the user reads it back with
`rice installs` without knowing where it is stored.

It RECORDS. It never installs and never removes anything: what to do about what is in the record
is the user's call.

Commands:
    record [--route N] [--helper N] [--label T]   read a transaction on stdin and persist it
    list                                          recorded transactions, newest first
    show <id>                                     one transaction in full
    where                                         the directory records live in

`record` reads TAB-separated lines on stdin:
    <status> <TAB> <package> [<TAB> <origin> [<TAB> <note>]]
status is installed | present | failed | built-from-source. Unknown statuses are reported and
dropped rather than silently kept.

Output (this repo's KEY=value convention): the whole transaction, one line per package, ALWAYS -
whether or not it could be persisted - plus INSTALL_RECORD=<path> and INSTALL_RECORD_ID=<id> when
it really was written, INSTALL_RECORD=unwritten when it could not be (and then the install is NOT
reported as recorded), or INSTALL_RECORD=empty when there was no transaction to record.

Exit: 0 recorded (or nothing to record), 2 usage, 3 `show` with no such record, 5 there was a
transaction and it could not be written where it belongs.
"""
import os
import sys
from . import restorepoint as rp
from .clock import iso_utc, stamp

STATUSES = ("installed", "present", "failed", "built-from-source")


def state_dir(env=None):
    env = os.environ if env is None else env
    override = env.get("RICE_INSTALL_RECORD_DIR")
    if override:
        return override.rstrip("/") or "/"
    # The one answer to "where does durable per-machine state live?" - shared with restore points
    # so a record cannot land where nothing later reads it.
    return f"{rp.state_root(env)}/installs"


def new_id(env=None):
    """The timestamp, plus an ordinal when a record already exists for that second.

    The ordinal is ZERO-PADDED because the identifier is also the sort key `list` reads back:
    "<base>-02" must sort after "<base>-01" as text, which "-2" and "-10" would not. Two records
    in one second are ordinary - a re-run of an idempotent install.sh where everything is already
    present finishes well inside a second - so this is the common path, not a corner."""
    store = state_dir(env)
    base = stamp(env)
    cand, n = base, 1
    while os.path.exists(f"{store}/{cand}.tsv") and n < 100:
        cand = f"{base}-{n:02d}"
        n += 1
    return cand


def _rows(path_or_lines):
    if isinstance(path_or_lines, str):
        try:
            with open(path_or_lines, encoding="utf-8", errors="replace") as fh:
                lines = fh.readlines()
        except OSError:
            return
    else:
        lines = path_or_lines
    for line in lines:
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        while len(parts) < 4:
            parts.append("")
        yield parts[0], parts[1], parts[2], parts[3]


def human(status, pkg, origin, note):
    """One transaction line, for a person."""
    tail = ""
    if status == "built-from-source":
        tail = " (built from source"
        if origin:
            tail += f" from {origin}"
        tail += ")"
    elif origin and origin != "-":
        tail = f" ({origin})"
    if note and note != "-" and status != "built-from-source":
        tail += f": {note}"
    return f"  {status:<18} {pkg}{tail}"


def summary_line(rows):
    rows = list(rows)
    n = len(rows)
    c = {s: sum(1 for r in rows if r[0] == s) for s in STATUSES}
    return (f"{n} package(s): {c['installed']} installed, {c['present']} already present, "
            f"{c['failed']} failed, {c['built-from-source']} built from source")


def print_transaction(rows, route, helper, out=sys.stdout):
    """The whole transaction, for a person. Printed whether or not the record could be
    persisted: a transaction the user cannot read anywhere is the failure this file exists
    to end."""
    rows = list(rows)
    print(f"=== install transaction (route: {route or 'unknown'}, helper: {helper or 'none'}) ===",
          file=out)
    for status, pkg, origin, note in rows:
        print(human(status, pkg, origin, note), file=out)
    print(f"=== {summary_line(rows)} ===", file=out)


class WriteResult:
    def __init__(self, ok, path="", record_id="", error=""):
        self.ok, self.path, self.record_id, self.error = ok, path, record_id, error


def write(rows, route, helper, label, env=None):
    store = state_dir(env)
    if not store:
        return WriteResult(False, error="cannot determine where install records live "
                                        "(no XDG_STATE_HOME and no HOME)")
    try:
        os.makedirs(store, exist_ok=True)
    except OSError:
        return WriteResult(False, path=store,
                           error="the install record directory could not be created")

    rid = new_id(env)
    dest = f"{store}/{rid}.tsv"
    tmp = f"{store}/.{rid}.{os.getpid()}.tmp"
    when = iso_utc(env)
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write("# hypr-rice install record\n")
            fh.write(f"# id\t{rid}\n")
            fh.write(f"# when\t{when}\n")
            fh.write(f"# route\t{route or 'unknown'}\n")
            fh.write(f"# helper\t{helper or 'none'}\n")
            if label:
                fh.write(f"# label\t{label}\n")
            for status, pkg, origin, note in rows:
                fh.write(f"{status}\t{pkg}\t{origin}\t{note}\n")
        os.replace(tmp, dest)
    except OSError:
        try:
            os.remove(tmp)
        except OSError:
            pass
        return WriteResult(False, path=dest, error="the record could not be written")
    return WriteResult(True, path=dest, record_id=rid)


def ids(store):
    """Identifiers in a store, newest first.

    Ordered over the IDENTIFIER, never the file name. A second record minted in the same second
    is "<base>-01", and "<base>-01.tsv" sorts BEFORE "<base>.tsv" ('-' is 0x2D, '.' is 0x2E), so a
    descending sort over file NAMES leads with the OLDER of the two - exactly what "newest first"
    must not do. Over identifiers, "<base>" is a prefix of "<base>-01" and sorts before it, and
    the padded ordinals sort among themselves."""
    try:
        names = [n[:-4] for n in os.listdir(store) if n.endswith(".tsv")]
    except OSError:
        return []
    return sorted(names, reverse=True)


def _header(path, field):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if line.startswith(f"# {field}\t"):
                    return line.split("\t", 1)[1].rstrip("\n")
    except OSError:
        pass
    return ""


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "help"
    args = argv[2:]

    if cmd == "where":
        print(state_dir())
        return 0

    if cmd == "list":
        store = state_dir()
        found = False
        for rid in ids(store):
            f = f"{store}/{rid}.tsv"
            try:
                if os.path.getsize(f) == 0:
                    continue
            except OSError:
                continue
            print(f"{rid}\t{summary_line(_rows(f))}\troute={_header(f, 'route')}")
            found = True
        if not found:
            print(f"(no install has been recorded yet, under {store})")
        return 0

    if cmd == "show":
        rid = args[0] if args else ""
        store = state_dir()
        if not rid or "/" in rid or rid.startswith("."):
            print("ERROR: usage: install-record.sh show <id>  (see: install-record.sh list)",
                  file=sys.stderr)
            return 2
        f = f"{store}/{rid}.tsv"
        try:
            empty = os.path.getsize(f) == 0
        except OSError:
            empty = True
        if empty:
            print(f"(no install record '{rid}' under {store})", file=sys.stderr)
            return 3
        print(f"INSTALL_RECORD={f}")
        print(f"INSTALL_RECORD_ID={rid}")
        print(f"WHEN={_header(f, 'when')}")
        print_transaction(_rows(f), _header(f, "route"), _header(f, "helper"))
        return 0

    if cmd == "record":
        route = helper = label = ""
        i = 0
        while i < len(args):
            opt = args[i]; i += 1
            if opt in ("--route", "--helper", "--label"):
                val = args[i] if i < len(args) else ""
                i += 1
                if opt == "--route":
                    route = val
                elif opt == "--helper":
                    helper = val
                else:
                    label = val
            else:
                print(f"ERROR: unknown option '{opt}' (usage: install-record.sh record "
                      "[--route N] [--helper N] [--label T])", file=sys.stderr)
                return 2

        rows = []
        for line in sys.stdin:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            while len(parts) < 4:
                parts.append("")
            status, pkg, origin, note = parts[0], parts[1], parts[2], parts[3]
            if status not in STATUSES:
                print(f"INSTALL_RECORD_DROPPED={status} (unknown status; expected "
                      "installed|present|failed|built-from-source)", file=sys.stderr)
                continue
            if not pkg:
                print(f"INSTALL_RECORD_DROPPED={status} (no package name)", file=sys.stderr)
                continue
            rows.append((status, pkg, origin, note))

        if not rows:
            # No package was installed, already present or failed. There was no transaction, so
            # there is no record: a record claiming one would be an invented history.
            print("INSTALL_RECORD=empty (no package was installed, already present or failed; "
                  "nothing was recorded)")
            return 0

        print_transaction(rows, route, helper)
        res = write(rows, route, helper, label)
        if res.ok:
            print(f"INSTALL_RECORD={res.path}")
            print(f"INSTALL_RECORD_ID={res.record_id}")
            return 0
        print(f"INSTALL_RECORD_FAILED={res.path or state_dir()} ({res.error})", file=sys.stderr)
        print("ERROR: the transaction above was NOT recorded - it is printed here and nowhere "
              "else.", file=sys.stderr)
        print("INSTALL_RECORD=unwritten")
        return 5

    if cmd in ("help", "-h", "--help"):
        print(__doc__.strip())
        return 0

    print(f"unknown command: {cmd} (try: install-record.sh help)", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

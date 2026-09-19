#!/usr/bin/env python3
"""Keep the reference layer honest, offline.

Two different things, deliberately graded differently:

  DEFECTS - owned by this repo, and they FAIL the build:
      UNCITED         a version-cliff record with no upstream citation at all
      UNRESOLVABLE    a citation that does not resolve to a specific artifact (a release tag, a
                      commit, a PR, a wiki page) - "upstream says so" pointing at a project's
                      front door is not something a reader can check
      UNLEDGERED      a `0.NN+` cliff asserted somewhere in the reference tree that the ledger
                      does not record, so nothing keeps the two in step

  STALENESS - REPORTED, never a failure:
      STALE           a claim last confirmed against an older release than the newest
      STALE_CLAIM     prose naming a version as "latest" that no longer is

Upstream shipping a release is not a defect in this repo, and a build that goes red the day
Hyprland tags a version teaches people to ignore it. So staleness is printed and the exit stays
zero.

Usage: currency-check.sh [--root D] [--ledger F] [--newest-release X.Y.Z]
Exit:  0 ok, 1 defects, 2 usage, 3 the newest release could not be determined,
       4 the ledger matched zero records, 5 something could not be read.
"""
import os
import re
import sys

from . import ledger as L

CLIFF_RE = re.compile(r"(?:^|[^0-9.])(0\.\d+)\+")
VER_IN_TEXT = re.compile(r"\bv?(0\.\d+(?:\.\d+)?)\b")
LATEST_RE = re.compile(r"latest stable|latest upstream|newest (?:upstream )?release|"
                       r"current(?:ly)? the newest", re.I)


def claim_text(s):
    """A cell squashed to one readable line: links flattened to their text, markup dropped."""
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s or "")
    s = re.sub(r"[*`]", "", s)
    s = re.sub(r"[ \t]+", " ", s)
    return s[:90]


def main(argv):
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.abspath(os.path.join(here, "..", "..", ".."))
    ledger_path = ""
    newest = os.environ.get("HYPR_NEWEST_RELEASE", "")
    newest_source = "supplied" if newest else "none"

    args = argv[1:]
    i = 0
    while i < len(args):
        a = args[i]; i += 1
        if a == "--root":
            if i >= len(args):
                print("ERROR: --root needs a value", file=sys.stderr); return 2
            root = args[i]; i += 1
        elif a == "--ledger":
            if i >= len(args):
                print("ERROR: --ledger needs a value", file=sys.stderr); return 2
            ledger_path = args[i]; i += 1
        elif a == "--newest-release":
            if i >= len(args):
                print("ERROR: --newest-release needs a value", file=sys.stderr); return 2
            newest, newest_source = args[i].lstrip("v"), "supplied"; i += 1
        elif a in ("-h", "--help"):
            print(__doc__.strip()); return 0
        else:
            print(f"ERROR: unknown argument: {a}", file=sys.stderr); return 2

    if not ledger_path:
        ledger_path = L.default_path(root)

    print(f"CURRENCY_ROOT={root}")
    print(f"CURRENCY_LEDGER={ledger_path}")

    unreadable = 0

    def name_unreadable(what, why):
        nonlocal unreadable
        print(f"UNREADABLE={what}")
        print(f"ERROR: {why}", file=sys.stderr)
        unreadable += 1

    if not os.path.isfile(ledger_path) or not os.access(ledger_path, os.R_OK):
        name_unreadable(ledger_path,
                        f"the version-cliff ledger '{ledger_path}' is missing or unreadable")
        print("CURRENCY=unreadable")
        return 5

    scan_files = []
    for d in L.scan_roots(root):
        if not os.path.isdir(d) or not os.access(d, os.R_OK):
            name_unreadable(d, f"the reference directory '{d}' is missing or unreadable")
            continue
        for dirpath, _dirs, files in os.walk(d):
            for n in sorted(files):
                if not n.endswith((".md", ".tmpl")):
                    continue
                f = os.path.join(dirpath, n)
                if not os.access(f, os.R_OK):
                    name_unreadable(f, f"the reference file '{f}' cannot be read")
                    continue
                scan_files.append(f)
    scan_files.sort()

    print(f"CURRENCY_SCANNED={len(scan_files)}")
    if unreadable:
        print("CURRENCY=unreadable")
        return 5

    records = L.cliff_records(ledger_path)
    removed_rows = L.removed_keys(ledger_path)
    print(f"CURRENCY_RECORDS={len(records)}")
    print(f"CURRENCY_REMOVED_KEY_RECORDS={len(removed_rows)}")

    if not records:
        print(f"ERROR: the ledger '{ledger_path}' matched ZERO version-cliff records. Either the "
              "ledger is empty or its record format changed under this check; a check that "
              "matches nothing is not a clean reference layer.", file=sys.stderr)
        print("CURRENCY=no-records")
        return 4

    if not newest:
        newest = L.newest_release(ledger_path)
        if newest:
            newest_source = "ledger"

    if not newest:
        print("CURRENCY_NEWEST_RELEASE=unknown")
        print("CURRENCY_NEWEST_RELEASE_SOURCE=none")
        print("ERROR: the newest Hyprland release was neither supplied (--newest-release / "
              "HYPR_NEWEST_RELEASE) nor readable from the ledger's 'newest-release' metadata row "
              f"in '{ledger_path}'. Staleness cannot be measured, and this check will NOT report "
              "the reference layer current on the strength of not knowing.", file=sys.stderr)
        print("CURRENCY=undetermined-newest-release")
        return 3

    print(f"CURRENCY_NEWEST_RELEASE={newest}")
    print(f"CURRENCY_NEWEST_RELEASE_SOURCE={newest_source}")

    ledger_rel = ledger_path[len(root) + 1:] if ledger_path.startswith(root + "/") else ledger_path
    uncited = unresolvable = unledgered = stale = 0

    def check_citation(rec_id, src, claim):
        nonlocal uncited, unresolvable
        problem = L.citation_problem(src)
        if not problem:
            return
        if problem == "no-citation":
            print(f"UNCITED={ledger_rel} | {rec_id} | {claim_text(claim)}")
            uncited += 1
        else:
            print(f"UNRESOLVABLE={ledger_rel} | {rec_id} | {claim_text(claim)} | {problem}")
            unresolvable += 1

    for table, cliff, src, changed in records:
        check_citation(claim_text(cliff), src, changed)
    for key, removed_at, replacement, src in removed_rows:
        check_citation(f"removed-key {key}", src, f"removed at {removed_at}; use {replacement}")

    floor = L.support_floor(ledger_path) or "0.0"
    recorded = set(L.hyprland_cliffs(ledger_path))
    projects = L.external_projects(ledger_path)

    def names_external(text):
        low = text.lower()
        return any(p and p in low for p in projects)

    for f in scan_files:
        if f == ledger_path:
            continue
        rel = f[len(root) + 1:] if f.startswith(root + "/") else f
        try:
            with open(f, encoding="utf-8", errors="replace") as fh:
                lines = fh.read().split("\n")
        except OSError:
            continue
        for lno, text in enumerate(lines, 1):
            if not CLIFF_RE.search(text) or names_external(text):
                continue
            for ver in sorted(set(CLIFF_RE.findall(text))):
                if L.vercmp(ver, floor) != 1 or ver in recorded:
                    continue
                print(f"UNLEDGERED_CLIFF={rel}:{lno} | {ver}+ | {claim_text(text)}")
                unledgered += 1

    for table, cliff, src, changed in records:
        if table != "hyprland":
            continue
        confirmed = L.record_release(src, changed)
        if not confirmed or L.vercmp(confirmed, newest) != -1:
            continue
        print(f"STALE={ledger_rel} | {claim_text(cliff)} | {claim_text(changed)} | "
              f"last confirmed against v{confirmed} | newest is v{newest}")
        stale += 1

    for f in scan_files:
        rel = f[len(root) + 1:] if f.startswith(root + "/") else f
        try:
            with open(f, encoding="utf-8", errors="replace") as fh:
                lines = fh.read().split("\n")
        except OSError:
            continue
        for lno, text in enumerate(lines, 1):
            if not LATEST_RE.search(text):
                continue
            for ver in sorted(set(VER_IN_TEXT.findall(text))):
                if L.vercmp(ver, newest) != -1:
                    continue
                print(f"STALE_CLAIM={rel}:{lno} | names v{ver} | newest is v{newest} | "
                      f"{claim_text(text)}")
                stale += 1

    print(f"CURRENCY_UNCITED={uncited}")
    print(f"CURRENCY_UNRESOLVABLE={unresolvable}")
    print(f"CURRENCY_UNLEDGERED={unledgered}")
    print(f"CURRENCY_STALE={stale}")

    if uncited + unresolvable + unledgered > 0:
        print("The defects above are owned by THIS repo: a record with no upstream behind it, a "
              "citation that does not resolve to an artifact, or a cliff asserted where nothing "
              f"records it. Fix them in {ledger_rel} or in the file named.")
        print("CURRENCY=defects")
        return 1

    print(f"CURRENCY=ok ({len(records)} version-cliff records, all cited; {stale} claim(s) not "
          f"yet confirmed against v{newest})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

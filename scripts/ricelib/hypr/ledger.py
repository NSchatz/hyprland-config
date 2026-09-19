#!/usr/bin/env python3
"""The version-cliff ledger: reading `_shared/version-matrix.md` as DATA.

That file is the single source of truth for which Hyprland release changed what, which keys were
REMOVED (and are therefore hard parse errors at or after that release), and which upstream
artifact each claim is cited from. It is markdown because humans maintain it and read it; this
module is how the tooling reads the same tables, so a claim cannot drift between what the docs
say and what the validators enforce.

Nothing here is a heuristic. A cliff with no citation, or one citing something that is not a
specific artifact, is a defect the currency check fails the build on.
"""
import os
import re

HEADING_HYPRLAND = "Version cliffs that components branch on"
HEADING_EXTERNAL = "External (non-Hyprland) version cliffs that matter"
HEADING_REMOVED = "Removed keys"
HEADING_METADATA = "Ledger metadata"

VER_RE = re.compile(r"v?(\d+\.\d+(?:\.\d+)?)")
URL_RE = re.compile(r"https?://[^ )>\"]+")


def default_path(root=None):
    if not root:
        root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    return f"{root}/skills/rice/references/_shared/version-matrix.md"


def scan_roots(root):
    return [f"{root}/skills/rice/references",
            f"{root}/skills/hyprland-reference/references"]


def _table(path, heading):
    """Every row of the markdown table under a `## <heading>` section, as lists of cells.

    The separator row (`|---|---|`) is dropped by probing: a row made only of pipes, colons,
    dashes and whitespace carries no data."""
    rows = []
    inside = False
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.rstrip("\n")
                if line.startswith("##") and (len(line) > 2 and line[2] in " \t"):
                    inside = heading in line
                    continue
                if not inside or not line.startswith("|"):
                    continue
                if not re.sub(r"[|:\-\s]", "", line):
                    continue
                body = re.sub(r"^\s*\|", "", line)
                body = re.sub(r"\|\s*$", "", body)
                rows.append([c.strip() for c in body.split("|")])
    except OSError:
        return []
    return rows


def _select(path, heading, *columns):
    """Rows of the named columns, matched case-insensitively against the header row."""
    rows = _table(path, heading)
    if not rows:
        return []
    header = [h.lower() for h in rows[0]]
    try:
        idx = [header.index(c.lower()) for c in columns]
    except ValueError:
        return []
    out = []
    for r in rows[1:]:
        if max(idx) >= len(r):
            continue
        out.append([r[i] for i in idx])
    return out


def cliff_records(path):
    """(kind, cliff, source, what-changed) for every cliff in both tables."""
    recs = [("hyprland", *r) for r in
            _select(path, HEADING_HYPRLAND, "Cliff", "Source", "What changed")]
    recs += [("external", *r) for r in
             _select(path, HEADING_EXTERNAL, "Cliff", "Source", "What changed")]
    return recs


def removed_keys(path):
    """(key, removed_at, replacement, source) - the keys that are hard parse errors."""
    return [[c.replace("`", "") for c in r]
            for r in _select(path, HEADING_REMOVED, "Key", "Removed at", "Replacement", "Source")]


def metadata(path, field, column="Value"):
    for row in _select(path, HEADING_METADATA, "Field", column):
        if row[0].replace("`", "") == field:
            return row[1].replace("`", "")
    return ""


def newest_release(path):
    m = VER_RE.search(metadata(path, "newest-release"))
    return m.group(1) if m else ""


def support_floor(path):
    m = VER_RE.search(metadata(path, "support-floor"))
    return m.group(1) if m else ""


def hyprland_cliffs(path):
    vals = set()
    for kind, cliff, _src, _what in cliff_records(path):
        if kind != "hyprland":
            continue
        for m in re.finditer(r"\d+\.\d+", cliff):
            vals.add(m.group(0))
    return sorted(vals, key=lambda v: [int(x) for x in v.split(".")])


def external_projects(path):
    names = set()
    for kind, cliff, _src, _what in cliff_records(path):
        if kind != "external":
            continue
        cleaned = cliff.replace("**", "").replace("`", "").strip()
        if cleaned:
            names.add(cleaned.split()[0].lower())
    return sorted(names)


def vercmp(a, b):
    """-1 / 0 / 1, comparing up to three numeric components. A non-numeric component is 0."""
    def parts(v):
        out = []
        for i in range(3):
            chunk = (v or "").lstrip("v").split(".")
            out.append(int(chunk[i]) if i < len(chunk) and chunk[i].isdigit() else 0)
        return out
    pa, pb = parts(a), parts(b)
    return -1 if pa < pb else (1 if pa > pb else 0)


def supported_targets(path):
    """Every release between the support floor and the newest, inclusive. Empty when the ledger
    does not declare both - the caller reports that rather than inventing a range."""
    floor, newest = support_floor(path), newest_release(path)
    if not floor or not newest:
        return []
    try:
        fmin = int(floor.split(".")[1])
        nmin = int(newest.split(".")[1])
    except (IndexError, ValueError):
        return []
    out = [f"0.{n}.0" for n in range(fmin, nmin + 1)]
    out.append(newest)
    return out


def citation_urls(cell):
    return URL_RE.findall(cell or "")


def citation_problem(cell):
    """"" when the citation is fine, else a reason.

    A citation has to resolve to a SPECIFIC artifact - a release tag, a commit, a PR, a wiki
    page - not just a project's front door. "Upstream says so" with a link to github.com/hyprwm
    is not a citation anyone can check."""
    urls = citation_urls(cell)
    if not urls:
        return "no-citation"
    for url in urls:
        if not url.startswith("https://"):
            return f"not-https:{url}"
        rest = url[len("https://"):]
        host = rest.split("/", 1)[0]
        path = rest[len(host):].strip("/")
        segs = len([s for s in path.split("/") if s])
        need = 3 if host == "github.com" else 2
        if segs < need:
            return f"not-an-artifact:{url}"
    return ""


def record_release(source_cell, what_cell):
    """The newest version this record can be pinned to, from its citation URL or its prose."""
    found = []
    for m in re.finditer(
            r"github\.com/hyprwm/Hyprland/(?:releases/tag|commit|pull)/[^ )>\"]*?"
            r"(v\d+\.\d+(?:\.\d+)?)", source_cell or ""):
        found.append(m.group(1))
    found += re.findall(r"\bv\d+\.\d+\.\d+", what_cell or "")
    vers = [v.lstrip("v") for v in found]
    if not vers:
        return ""
    return sorted(vers, key=lambda v: [int(x) if x.isdigit() else 0 for x in v.split(".")])[-1]

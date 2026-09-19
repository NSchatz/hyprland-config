#!/usr/bin/env python3
"""Give every long reference file a table of contents.

This is not tidiness. Anthropic's skill-authoring guidance is explicit that a file past roughly
100 lines may be PREVIEWED rather than read whole - an agent reaches for `head -100` and then
acts on what it saw. Without a contents block the preview hides the scope of what was skipped,
so the reader does not know it read half a recipe. That is a silent-wrong-output failure mode,
and it is independent of how many tokens the file costs.

The block is generated from the file's own `##` headings, inserted after the frontmatter, title
and intro prose, immediately before the first section. Idempotent: a file that already has one
is skipped, and re-running changes nothing.

Usage: add-contents.py <root> [--dry-run]
"""
import re
import sys
from pathlib import Path

HAS_TOC = re.compile(r"^#{1,3} *(contents|table of contents|in this file)", re.I)
FENCE = re.compile(r"^[ \t]*(```|~~~)")
MIN_LINES = 100
# Enough sections that an index earns its place; below this the headings are the index.
MIN_SECTIONS = 3


def headings(lines, prefix="## "):
    """Headings at one level, outside code fences, with their line numbers.

    Fence-aware on purpose: a shell comment inside a ```bash block (`# strip CSS keywords ...`)
    is not a heading, and counting it as one both mis-indexes the file and, once the parser
    believes it is inside a fence, hides every real heading after it."""
    out, in_fence = [], False
    for i, l in enumerate(lines):
        if FENCE.match(l):
            in_fence = not in_fence
            continue
        if not in_fence and l.startswith(prefix) and not l.startswith(prefix + "#"):
            out.append((i, l[len(prefix):].strip()))
    return out


def index_headings(lines):
    """The level that actually indexes this file. Some files carry one `##` section whose `###`
    subsections are the real table of contents (waybar/validation.md: one `## Checks` over nine
    numbered checks). Indexing by `##` there produces a one-line contents block that says
    nothing."""
    top = headings(lines, "## ")
    if len(top) >= MIN_SECTIONS:
        return top
    sub = headings(lines, "### ")
    return sub if len(sub) >= MIN_SECTIONS else top


def insertion_point(lines, first_heading_idx):
    """Immediately before the first section, but after any YAML frontmatter."""
    start = 0
    if lines and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                start = i + 1
                break
    return max(start, first_heading_idx)


def clean(title):
    """Heading text -> plain label. Strips inline code/bold/links but keeps the words."""
    t = re.sub(r"`([^`]*)`", r"\1", title)
    t = re.sub(r"\*\*([^*]*)\*\*", r"\1", t)
    t = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", t)
    return t.strip()


def main():
    root = Path(sys.argv[1])
    dry = "--dry-run" in sys.argv
    done = skipped = 0

    targets = sorted(
        list(root.glob("skills/**/*.md")) + list(root.glob("agents/*.md"))
    )
    for f in targets:
        if ".research" in f.parts:
            continue
        text = f.read_text()
        lines = text.split("\n")
        if len(lines) <= MIN_LINES:
            continue
        if any(HAS_TOC.match(l) for l in lines):
            continue
        hs = index_headings(lines)
        if len(hs) < MIN_SECTIONS:
            skipped += 1
            print(f"  SKIP {f.relative_to(root)} ({len(hs)} sections - headings are the index)")
            continue

        at = insertion_point(lines, hs[0][0])
        block = ["## Contents", ""] + [f"- {clean(h)}" for _, h in hs] + [""]
        new = lines[:at] + block + lines[at:]
        print(f"  {str(f.relative_to(root)):72s} {len(hs):2d} sections")
        done += 1
        if not dry:
            f.write_text("\n".join(new))

    print(f"--- {done} file(s) given a contents block, {skipped} skipped")


if __name__ == "__main__":
    main()

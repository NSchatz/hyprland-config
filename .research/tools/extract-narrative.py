#!/usr/bin/env python3
"""Move corpus-research narrative out of the load path, keeping the recipes.

A styling file mixes two kinds of content:

  what a writer ACTS ON      What you're styling / Design anatomy /
                             Tasteful default recipe / Pitfalls
  why it is that way         How the community styles it / Battle-tested
                             techniques (harvested from ~N configs) /
                             The landscape and where momentum is / decision matrices

The second kind is real research and stays in the repo - it is what makes the first kind
trustworthy. It just should not be re-read on every authoring run, and the "landscape in
2025-2026" flavour of it goes stale, which is worse than merely costing tokens.

Losslessness is asserted, not assumed: every line of every input lands in exactly one output,
and a file is left untouched if the counts do not reconcile.

Usage: extract-narrative.py <plugin-root> [--dry-run]
"""
import re
import sys
from pathlib import Path

# Headings whose sections are provenance rather than instruction.
NARRATIVE = re.compile(
    r"^(#{2,3}) *("
    # Deliberately NARROW. "How the community styles it" and "Battle-tested techniques" look
    # like provenance and are not: they are the archetype catalog and the attributed catalog of
    # concrete moves, i.e. the design vocabulary a writer actually emits from. Moving those out
    # would make configs MORE generic, which is the opposite of the point. Only genuinely
    # time-sensitive survey and choose-time decision content moves.
    r"The landscape\b"
    r"|Choosing a .*decision matrix"
    r")",
    re.IGNORECASE,
)
FENCE = re.compile(r"^[ \t]*(```|~~~)")
HEADING = re.compile(r"^(#+) ")


def split(lines):
    """Tag each line 'keep' or 'cut'. A section runs to the next heading of same-or-shallower
    depth. `#` inside a fenced block is a comment, not a heading - missing that silently
    truncates a section, which is how a recipe ends up half-moved."""
    tags, in_fence, cutting, cut_depth = [], False, False, 0
    for line in lines:
        if FENCE.match(line):
            in_fence = not in_fence
            tags.append("cut" if cutting else "keep")
            continue
        if not in_fence:
            m = HEADING.match(line)
            if m:
                depth = len(m.group(1))
                if cutting and depth <= cut_depth:
                    cutting = False
                if NARRATIVE.match(line):
                    cutting, cut_depth = True, depth
        tags.append("cut" if cutting else "keep")
    return tags


def main():
    root = Path(sys.argv[1])
    dry = "--dry-run" in sys.argv
    dest = root / ".research" / "styling"
    dest.mkdir(parents=True, exist_ok=True)

    moved = total_tok = 0
    for f in sorted(root.glob("skills/**/*.md")):
        if ".research" in f.parts:
            continue
        lines = f.read_text().split("\n")
        if not any(NARRATIVE.match(l) for l in lines):
            continue
        tags = split(lines)
        cut = [l for l, t in zip(lines, tags) if t == "cut"]
        keep = [l for l, t in zip(lines, tags) if t == "keep"]
        if not cut:
            continue
        if len(cut) + len(keep) != len(lines):
            print(f"REFUSED {f}: not lossless, left untouched", file=sys.stderr)
            continue

        rel = f.relative_to(root)
        flat = (
            str(rel)
            .replace("skills/rice/references/", "")
            .replace("skills/hyprland-reference/references/", "hyprland-reference-")
            .replace("/", "-")
        )
        tok = len("\n".join(cut)) // 4
        total_tok += tok
        print(f"  {str(rel):68s} -{tok:5d} tok -> .research/styling/{flat}")
        if dry:
            continue

        (dest / flat).write_text(
            f"# Styling research - {rel}\n\n"
            f"Corpus-harvest narrative for `{rel}`: how the community actually does this and\n"
            f"which real configs the recommendations were read out of.\n\n"
            f"Kept out of the load path. The recipes this backs are still in `{rel}`;\n"
            f"this is the evidence for them, read when reviewing a recommendation rather than\n"
            f"when authoring a config.\n\n" + "\n".join(cut) + "\n"
        )
        body = "\n".join(keep).rstrip()
        f.write_text(
            body
            + "\n\n## Research\n\n"
            + f"The corpus notes behind these recipes - how the community does it, the\n"
            + f"battle-tested techniques and the configs they were harvested from - are at\n"
            + f"`.research/styling/{flat}` (repo root).\n"
        )
        moved += 1

    print(f"--- {moved} file(s) trimmed, ~{total_tok} tok out of the load path")


if __name__ == "__main__":
    main()

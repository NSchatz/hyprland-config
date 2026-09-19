#!/usr/bin/env python3
"""Shard the waybar component by the answer that selects its look.

waybar cannot shard by tool - waybar IS the tool - but it has the same problem one axis over:
its styling describes SEVEN archetypes and a writer emits exactly ONE, named by `bar.archetype`.
It also carries the vertical / dual / dock material, which only matters when `bar.form` is not a
single horizontal bar. Both are content a writer pays for and does not use.

  waybar/{template,styling,...}.md   the flat set, shared by every archetype
  waybar/looks/<archetype>.md   that archetype's community entry + its style.css skeleton
                                (+ the tasteful default recipe, which is floating-island's)
  waybar/forms/vertical-dual-dock.md   read only when bar.form != a single horizontal bar

Lossless by construction: every moved block is removed from its source and asserted present in
exactly one output.

Usage: shard-waybar.py <component-dir> [--dry-run]
"""
import re
import sys


def _fences(lines):
    return sum(1 for l in lines if l.startswith('```'))
from pathlib import Path

ARCHETYPES = {
    # slug: (styling.md bold-paragraph marker, template.md `### Archetype:` heading)
    "floating-islands": ("**(a) Floating island bar**", "### Archetype: `floating-islands`"),
    "edge-to-edge":     ("**(b) Edge-to-edge solid bar**", "### Archetype: `edge-to-edge`"),
    "separated-pills":  ("**(c) Per-module separated pills**", "### Archetype: `separated-pills`"),
    "single-lozenge":   ("**(d) Single grouped pill**", "### Archetype: `single-lozenge`"),
    "minimal-mono":     ("**(e) Minimal mono**", None),
    "powerline":        ("**(f) Powerline / segmented**", None),
    "dock":             ("**(g) Dock / shelf**", None),
}


def span_of(lines, start_pred, stop_pred):
    """(start, end) index range of the block, or None. Half-open, like a slice.

    Returns INDICES, never content. An earlier version of this returned the lines themselves and
    the caller removed them from the source with `l not in moved`, which matched by CONTENT: every
    ```css fence and every closing brace that also appeared inside a moved block was deleted from
    the entire file. styling.md went from 26 fence markers to 1. Ranges cannot do that."""
    start = None
    for i, l in enumerate(lines):
        if start is None:
            if start_pred(l):
                start = i
            continue
        if stop_pred(l):
            return (start, i)
    return (start, len(lines)) if start is not None else None


def block_from(lines, start_pred, stop_pred):
    sp = span_of(lines, start_pred, stop_pred)
    return lines[sp[0]:sp[1]] if sp else []


def main():
    comp = Path(sys.argv[1])
    dry = "--dry-run" in sys.argv
    styling = (comp / "styling.md").read_text().split("\n")
    template = (comp / "template.md").read_text().split("\n")

    # --- carve the per-archetype pieces --------------------------------------------------
    def _styling_stop(marker):
        return (lambda l: (l.startswith("**(") and not l.startswith(marker))
                or l.startswith("## ")
                or l.startswith("**Project idioms"))

    def styling_entry(marker):
        # An entry ends at the next archetype, the next `## ` section, OR the shared trailing
        # block. Without that last stop the LAST archetype silently absorbs the project-idioms
        # list, which is about how real repos lay waybar out and applies to every look.
        return block_from(styling, lambda l: l.startswith(marker), _styling_stop(marker))

    def template_entry(heading):
        if heading is None:
            return []
        return block_from(
            template,
            lambda l: l.startswith(heading),
            lambda l: l.startswith("### ") and not l.startswith(heading),
        )

    # The "Tasteful default recipe" is explicitly a floating-island bar, so it belongs to that
    # archetype rather than to every writer.
    tasteful = block_from(
        styling,
        lambda l: l.startswith("## Tasteful default recipe"),
        lambda l: l.startswith("## System & ecosystem"),
    )
    # Bar form material is selected by `bar.form`, not by archetype.
    barform = block_from(
        styling,
        lambda l: l.startswith("## Bar form"),
        lambda l: l.startswith("## Battle-tested"),
    )
    otherforms = block_from(
        template,
        lambda l: l.startswith("## Vertical / dual / dock"),
        lambda l: l.startswith("## `colors.css`"),
    )

    spans = {"styling": [], "template": []}
    (comp / "looks").mkdir(exist_ok=True)
    (comp / "forms").mkdir(exist_ok=True)

    for slug, (marker, heading) in ARCHETYPES.items():
        s_e, t_e = styling_entry(marker), template_entry(heading)
        if not s_e:
            print(f"  WARN no styling entry for {slug}", file=sys.stderr)
        parts = [f"# waybar look - {slug}\n",
                 f"The `bar.archetype = {slug}` look. Read this **and** the component's shared recipe set",
                 "(`../template.md`, `../styling.md`, `../gotchas.md`, `../validation.md`,",
                 "`../reload.md`); do not read",
                 "the other files in `looks/`.\n", "## Contents\n", "- What the look is",
                 "- `style.css` skeleton" if t_e else "", "", "---\n", "## What the look is\n",
                 "\n".join(s_e).strip(), ""]
        if t_e:
            parts += ["---\n", "## `style.css` skeleton\n", "\n".join(t_e).strip(), ""]
        if slug == "floating-islands":
            parts += ["---\n", "\n".join(tasteful).strip(), ""]
        out = "\n".join(p for p in parts if p != "")
        if not dry:
            (comp / "looks" / f"{slug}.md").write_text(out + "\n")
        print(f"  looks/{slug+'.md':26s} ~{len(out)//4:5d} tok")
        sp = span_of(styling, lambda l: l.startswith(marker), _styling_stop(marker))
        if sp: spans["styling"].append(sp)
        if heading:
            tp = span_of(template, lambda l: l.startswith(heading),
                         lambda l: l.startswith('### ') and not l.startswith(heading))
            if tp: spans["template"].append(tp)

    for pred_a, pred_b, key in (
        (lambda l: l.startswith("## Tasteful default recipe"),
         lambda l: l.startswith("## System & ecosystem"), "styling"),
        (lambda l: l.startswith("## Bar form"),
         lambda l: l.startswith("## Battle-tested"), "styling"),
        (lambda l: l.startswith("## Vertical / dual / dock"),
         lambda l: l.startswith("## `colors.css`"), "template"),
    ):
        sp = span_of(styling if key == "styling" else template, pred_a, pred_b)
        if sp: spans[key].append(sp)

    form_doc = "\n".join([
        "# waybar forms - vertical, dual and dock\n",
        "Read this **only** when `bar.form` is not a single horizontal bar. A standard top or",
        "bottom bar needs none of it.\n", "## Contents\n", "- Bar form: orientation, vertical & multi-bar",
        "- Vertical / dual / dock emission\n", "---\n",
        "\n".join(barform).strip(), "", "---\n", "\n".join(otherforms).strip(), "",
    ])
    if not dry:
        (comp / "forms" / "vertical-dual-dock.md").write_text(form_doc + "\n")
    print(f"  forms/vertical-dual-dock.md    ~{len(form_doc)//4:5d} tok")

    # --- rewrite the sources with the moved blocks removed --------------------------------
    def strip(lines, name, ranges):
        drop = set()
        for a, b in ranges:
            drop.update(range(a, b))
        kept = [l for i, l in enumerate(lines) if i not in drop]
        text = re.sub(r"\n{3,}", "\n\n", "\n".join(kept))
        # A markdown file with an odd number of fence markers has had a code block cut in half.
        # Assert it here rather than discovering it later as a file that "has one section".
        before, after = _fences(lines), _fences(text.split("\n"))
        moved_f = sum(_fences(lines[a:b]) for a, b in ranges)
        if after % 2 or after + moved_f != before:
            raise SystemExit(
                f"REFUSED {name}: fences do not reconcile "
                f"({before} before, {after} kept + {moved_f} moved). Nothing written.")
        print(f"  {name:14s} ~{len(text)//4:5d} tok (was ~{len(chr(10).join(lines))//4}), "
              f"fences {before} -> {after} kept + {moved_f} moved")
        return text

    new_styling = strip(styling, "styling.md", spans["styling"])
    new_template = strip(template, "template.md", spans["template"])
    if not dry:
        (comp / "styling.md").write_text(new_styling)
        (comp / "template.md").write_text(new_template)


if __name__ == "__main__":
    main()

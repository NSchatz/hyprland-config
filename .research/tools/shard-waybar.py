#!/usr/bin/env python3
"""Shard the waybar component by the answer that selects its look.

waybar cannot shard by tool - waybar IS the tool - but it has the same problem one axis over:
its styling describes SEVEN archetypes and a writer emits exactly ONE, named by `bar.archetype`.
It also carries the vertical / dual / dock material, which only matters when `bar.form` is not a
single horizontal bar. Both are content a writer pays for and does not use.

  waybar/common.md              everything true of every bar
  waybar/looks/<archetype>.md   that archetype's community entry + its style.css skeleton
                                (+ the tasteful default recipe, which is floating-island's)
  waybar/forms/vertical-dual-dock.md   read only when bar.form != a single horizontal bar

Lossless by construction: every moved block is removed from its source and asserted present in
exactly one output.

Usage: shard-waybar.py <component-dir> [--dry-run]
"""
import re
import sys
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


def block_from(lines, start_pred, stop_pred):
    """Lines from the first line matching start_pred up to (not including) the next stop_pred."""
    out, taking = [], False
    for l in lines:
        if taking and stop_pred(l):
            break
        if not taking and start_pred(l):
            taking = True
        if taking:
            out.append(l)
    return out


def main():
    comp = Path(sys.argv[1])
    dry = "--dry-run" in sys.argv
    styling = (comp / "styling.md").read_text().split("\n")
    template = (comp / "template.md").read_text().split("\n")

    # --- carve the per-archetype pieces --------------------------------------------------
    def styling_entry(marker):
        # An entry ends at the next archetype, the next `## ` section, OR the shared trailing
        # block. Without that last stop the LAST archetype silently absorbs the project-idioms
        # list, which is about how real repos lay waybar out and applies to every look.
        return block_from(
            styling,
            lambda l: l.startswith(marker),
            lambda l: (l.startswith("**(") and not l.startswith(marker))
            or l.startswith("## ")
            or l.startswith("**Project idioms"),
        )

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

    moved = set()
    (comp / "looks").mkdir(exist_ok=True)
    (comp / "forms").mkdir(exist_ok=True)

    for slug, (marker, heading) in ARCHETYPES.items():
        s_e, t_e = styling_entry(marker), template_entry(heading)
        if not s_e:
            print(f"  WARN no styling entry for {slug}", file=sys.stderr)
        parts = [f"# waybar look - {slug}\n",
                 f"The `bar.archetype = {slug}` look. Read this **and** `../common.md`; do not read",
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
        moved.update(s_e); moved.update(t_e)

    moved.update(tasteful); moved.update(barform); moved.update(otherforms)

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
    def strip(lines, name):
        kept = [l for l in lines if l not in moved or l.strip() == ""]
        # Blank lines are shared between blocks; re-collapse runs of 3+.
        text = re.sub(r"\n{3,}", "\n\n", "\n".join(kept))
        print(f"  {name:14s} ~{len(text)//4:5d} tok (was ~{len(chr(10).join(lines))//4})")
        return text

    new_styling = strip(styling, "styling.md")
    new_template = strip(template, "template.md")
    if not dry:
        (comp / "styling.md").write_text(new_styling)
        (comp / "template.md").write_text(new_template)


if __name__ == "__main__":
    main()

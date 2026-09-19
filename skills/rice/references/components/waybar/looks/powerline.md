# waybar look - powerline

The `bar.archetype = powerline` look. Read this **and** the component's shared recipe set
(`../template.md`, `../styling.md`, `../gotchas.md`, `../validation.md`,
`../reload.md`); do not read
the other files in `looks/`.

## Contents

- What the look is
---

## What the look is

**(f) Powerline / segmented** — modules fuse into one continuous strip with angled separators. Two ways: (1) **chained-arrow modules** — interleave `custom/arrow1..N` whose `format` is a single powerline glyph (`` / ``) and whose CSS sets `color` = the next module's bg and `background` = the previous module's bg, so the triangle bridges two solid blocks (cjbassi chains 4, mxkrsv chains 10 into a full gradient; mechabar uses `custom/left_div`/`right_div` slanted divider modules). (2) **End-cap rounding** — give a row of `border-radius: 0` modules rounded caps only on the first (`6px 0 0 6px`) and last (`0 6px 6px 0`) so N differently-colored modules read as one capsule (Prateek7071, DN-debug, oscarcp's directional half-radius weld). Reads "techy/retro"; pairs with per-module solid bg.

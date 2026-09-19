# Sources - skills/rice/references/_shared/palette-schema.md

Research provenance for `skills/rice/references/_shared/palette-schema.md`.

Extracted from the load path: these citations are why the recommendations in that
file are what they are, and are read by a human reviewing them - never by an agent
authoring a config.

## Sources

- **Named scheme** → look up the hex in `theming/palettes.md`.
- **Wallpaper-generated** → run `scripts/palette-from-wallpaper.sh <image>` (matugen or wallust);
  map matugen's `primary→accent`, `secondary→accent2`, `surface→bg`, `on_surface→fg`,
  neutrals→`muted`/`surface`, and the source/extended colors → `color0..15`.
- **Manual hex** → write the user's values directly; derive `accent2` and the `color*` set from
  the chosen `accent` if not collected.


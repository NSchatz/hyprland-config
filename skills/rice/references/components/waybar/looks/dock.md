# waybar look - dock

The `bar.archetype = dock` look. Read this **and** the component's shared files (`../styling.md`, `../template.md`,
`../gotchas.md`, `../validation.md`, `../reload.md`); do not read
the other files in `looks/`.

## Contents

- What the look is
---

## What the look is

**(g) Dock / shelf** — a bottom bar that behaves like a launcher dock. ChromeOS-shelf (cxOrz): `position: bottom`, `border-radius: 24px 24px 0 0` (top corners only), a translucent system "status pill" grouping clock+audio+net+bt+battery via first/last-child rounding, and an active-workspace that morphs a bar into an accent dot. macOS-dock / Win10-taskbar (kamlendras, TheFrankyDoll): a `wlr/taskbar` with `icon-size: 36` as the actual Dock/taskbar, optionally a second top bar. See the recipes under "Bar form".

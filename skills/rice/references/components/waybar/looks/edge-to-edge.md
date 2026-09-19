# waybar look - edge-to-edge

The `bar.archetype = edge-to-edge` look. Read this **and** the component's shared recipe set
(`../template.md`, `../styling.md`, `../gotchas.md`, `../validation.md`,
`../reload.md`); do not read
the other files in `looks/`.

## Contents

- What the look is
- `style.css` skeleton
---

## What the look is

**(b) Edge-to-edge solid bar** — the classic Waybar default and many minimalist Sway rices. No margins, `exclusive: true`, a solid or lightly-translucent full-width bar, square corners. The official sample uses `background: rgba(43,48,59, 0.5); border-bottom: 3px solid rgba(100,114,125,0.5);` with `#workspaces button.focused { border-bottom: 3px solid white; }`.
---

## `style.css` skeleton

### Archetype: `edge-to-edge`

```css
window#waybar {
  background: alpha(@bg, 0.92);
  border-bottom: 1px solid alpha(@accent, 0.25);
  border-radius: 0;
}
```

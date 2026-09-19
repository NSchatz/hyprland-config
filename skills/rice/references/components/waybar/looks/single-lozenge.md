# waybar look - single-lozenge

The `bar.archetype = single-lozenge` look. Read this **and** the component's shared recipe set
(`../template.md`, `../styling.md`, `../gotchas.md`, `../validation.md`,
`../reload.md`); do not read
the other files in `looks/`.

## Contents

- What the look is
- `style.css` skeleton
---

## What the look is

**(d) Single grouped pill** — one continuous rounded capsule per side with `spacing: 0`, internal dividers via subtle `border` between modules. HyDE leans on this with its `group/pill` and `group/leaf-inverse` Waybar groups; the inner radius is computed to match Hyprland's window rounding.
---

## `style.css` skeleton

### Archetype: `single-lozenge`

```css
window#waybar {
  background: transparent;
  border: 2px solid @accent;
  border-radius: 7rem;
}
#workspaces, #window, #clock, #mpris, #cpu, #memory, #temperature,
#pulseaudio, #network, #bluetooth, #idle_inhibitor, #tray { background: transparent; }
```

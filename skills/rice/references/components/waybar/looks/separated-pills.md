# waybar look - separated-pills

The `bar.archetype = separated-pills` look. Read this **and** the component's shared recipe set
(`../template.md`, `../styling.md`, `../gotchas.md`, `../validation.md`,
`../reload.md`); do not read
the other files in `looks/`.

## Contents

- What the look is
- `style.css` skeleton
---

## What the look is

**(c) Per-module separated pills** — every module is its own floating capsule. Achieved with `margin` + `border-radius` on **individual** module IDs and a transparent bar. High visual separation; reads "techy".
```css
#clock, #battery, #network, #pulseaudio, #tray {
    background: rgba(49, 50, 68, 0.9);
    border-radius: 999px;
    padding: 2px 12px;
    margin: 6px 3px;
}
```
---

## `style.css` skeleton

### Archetype: `separated-pills`

Every module gets its own pill; the **first and last touch the screen edge** unless you add a
margin (see `gotchas.md`).

```css
window#waybar { background: transparent; color: @fg; }
#workspaces, #window, #clock, #mpris, #cpu, #memory, #temperature,
#pulseaudio, #network, #bluetooth, #idle_inhibitor, #tray {
  background: alpha(@surface, 0.85);
  border-radius: 999px;
  padding: 2px 12px;
  margin: 6px 3px;
}
#workspaces { margin-left: 8px; }   /* first module on the left */
#tray       { margin-right: 8px; }  /* last module on the right */
```

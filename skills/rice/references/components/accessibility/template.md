# accessibility — template

This component doesn't own its own `.conf` file. Every selected helper routes to one or more
sibling components' templates. The job here is the **routing map** — which lines each helper
emits, and into which file.

Empty `accessibility` array → no lines emitted, no files touched.

## Per-helper output map

### `magnifier`

Lands in `../keybinds/template.md`:

```ini
bind = $mainMod, equal, exec, hyprctl keyword cursor:zoom_factor 2
bind = $mainMod, minus, exec, hyprctl keyword cursor:zoom_factor 1
```

`equal` is the keysym for the `=` key (no shift required). The second bind resets zoom to 1.

Optionally, when the user wants the cursor to stay centred while zoomed (the "rigid" variant),
add to `../look-feel/template.md`:

```ini
cursor {
    zoom_rigid = true
}
```

Pure Hyprland — **no external magnifier tool, no plugin**. `cursor:zoom_factor` has been core
since 0.40+.

### `large-cursor`

Three landings — env, autostart, GTK theming.

`../env/template.md` (size 32 by default; 48 for the maximum-visibility variant):

```ini
env = XCURSOR_SIZE,32
env = HYPRCURSOR_SIZE,32
```

`../autostart/template.md` — apply at session start so already-running apps pick up the size:

```ini
exec-once = hyprctl setcursor {{cursor_theme}} 32
```

`{{cursor_theme}}` is read from the resolved cursor theme (e.g. `Bibata-Modern-Ice`,
`Adwaita`); see `../env/template.md` for theme detection.

`theming/` GTK template (e.g. `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini`):

```ini
[Settings]
gtk-cursor-theme-size = 32
```

### `night-light`

Lands in `../keybinds/template.md`:

```ini
bind = $mainMod SHIFT, N, exec, hyprsunset -t 4000
```

`hyprsunset` is the Hypr-ecosystem warm-temp tool (replaces `gammastep` / `redshift` /
`wlsunset` on Wayland). The `-t 4000` argument is the target Kelvin; toggling the bind a second
time runs the command again (a wrapper script for true toggle behaviour lives in
`../utilities/` — pick one home, see `gotchas.md`).

### `larger-ui`

Two landings — monitors and GTK theming.

`../monitors/template.md` — bump the picked monitor's `scale` (typical low-vision preset is
`1.25`):

```ini
monitor = {{name}}, {{mode}}, {{pos}}, 1.25
```

`monitors` already owns this line; this component just tells it to use the bumped value.

`theming/` GTK template (e.g. `~/.config/gtk-3.0/settings.ini`):

```ini
[Settings]
gtk-xft-dpi = 122880
```

(`122880 = 96 * 1024 * 1.25`; the GTK `text-scaling-factor` is `xsettingsd`-mediated and ends up
at 1.25.) `gsettings` form for libadwaita:

```bash
gsettings set org.gnome.desktop.interface text-scaling-factor 1.25
```

## What does NOT belong here

- The actual `monitor =` line itself — that's `../monitors/template.md`.
- The actual `env = XCURSOR_SIZE,…` rendering — that's `../env/template.md`.
- The colors files. Cursor **theme** is palette-driven (`palette.conf.cursor`); this component
  only touches cursor **size**.
- A second night-light bind if `../utilities/` already emits one.

## Cross-references

- Bind table → `../keybinds/template.md`
- env block → `../env/template.md`
- monitor `scale` field → `../monitors/template.md`
- `looknfeel.conf` cursor block → `../look-feel/template.md`
- GTK settings → `theming/` (the GTK template)

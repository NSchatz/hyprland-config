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

Pure Hyprland — **no external magnifier tool, no plugin**. `cursor:zoom_factor` is documented
in the current [Variables wiki § cursor](https://wiki.hypr.land/Configuring/Basics/Variables/)
as a core `float` keyword (default `1.0`, minimum `1.0`); paired with `cursor:zoom_rigid`
(`bool`, default `false`) and `cursor:zoom_detached_camera` (`bool`, default `true`).

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

**`hyprctl setcursor` since Hyprland 0.37 only accepts hyprcursor themes** (per
[hyprctl wiki § setcursor](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl/#setcursor)).
If the chosen theme is XCursor-only, the `setcursor` call will no-op for hyprcursor surfaces;
the `XCURSOR_SIZE` env var still drives GTK/Xwayland apps. The hyprcursor wiki notes that GTK
does not support server-side cursors, so it falls back to XCursor regardless — both env-var
pairs (`HYPRCURSOR_*` and `XCURSOR_*`) must be set in parallel.

`theming/` GTK template (e.g. `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini`):

```ini
[Settings]
gtk-cursor-theme-size = 32
```

Plus a runtime `gsettings` call so already-running GNOME/libadwaita apps pick up the new size
(per [ArchWiki Cursor themes § GNOME](https://wiki.archlinux.org/title/Cursor_themes#GNOME)):

```bash
gsettings set org.gnome.desktop.interface cursor-size 32
```

The gsettings key is `cursor-size` (under `org.gnome.desktop.interface`); valid theme sizes are
typically `24, 32, 48, 64`.

### `night-light`

`hyprsunset` is a **long-running daemon** (per [hyprsunset wiki](https://wiki.hypr.land/Hypr-Ecosystem/hyprsunset/),
supported since Hyprland 0.45). It is **not** a one-shot CLI — running `hyprsunset` again
does not toggle; it just starts a second instance. Control is done by IPC via `hyprctl`.

Two landings — autostart (to start the daemon) and keybinds (to toggle via IPC).

`../autostart/template.md`:

```ini
exec-once = hyprsunset
```

`../keybinds/template.md` — toggle by switching between a warm temperature and `identity`
(no filter). Use `hyprctl hyprsunset` IPC (documented in the wiki):

```ini
# Apply warm filter
bind = $mainMod SHIFT, N,     exec, hyprctl hyprsunset temperature 4000
# Disable filter (no toggle dispatcher — bind a second key, or wrap in a script)
bind = $mainMod SHIFT, M,     exec, hyprctl hyprsunset identity
```

For a true single-key toggle, ship a wrapper script in `../utilities/` that reads
`hyprctl hyprsunset profile` and flips between `temperature 4000` and `identity` — see
`gotchas.md` for the overlap rule with `../utilities/`.

Profiles live in `~/.config/hypr/hyprsunset.conf` (e.g. day/night schedule); this component
does **not** write that file, it only starts the daemon and binds the IPC toggle. If the user
wants scheduled transitions, they edit `hyprsunset.conf` themselves.

The CLI flag for a one-shot override is `--temperature` (long form is what the wiki documents;
do **not** use `-t`, which is not in the documented flag list). E.g. `hyprsunset --temperature 5000`
overrides until the next profile activation.

### `larger-ui`

Two landings — monitors and GTK theming.

`../monitors/template.md` — bump the picked monitor's `scale` (typical low-vision preset is
`1.25`):

```ini
monitor = {{name}}, {{mode}}, {{pos}}, 1.25
```

`monitors` already owns this line; this component just tells it to use the bumped value.

`theming/` — set the text-scaling factor via `gsettings` (the documented mechanism per
[ArchWiki HiDPI § GNOME](https://wiki.archlinux.org/title/HiDPI#GNOME)):

```bash
gsettings set org.gnome.desktop.interface text-scaling-factor 1.25
```

`text-scaling-factor` is a real key under `org.gnome.desktop.interface`; the ArchWiki HiDPI
page explicitly notes "the text scaling factor need not be limited to whole integers,
for example: `gsettings set org.gnome.desktop.interface text-scaling-factor 1.5`".

For non-GNOME / non-libadwaita GTK apps that ignore the xsettings bridge, you can additionally
set `~/.config/gtk-3.0/settings.ini` and `gtk-4.0/settings.ini`:

```ini
[Settings]
gtk-xft-dpi = 122880
```

(`122880 = 96 * 1024 * 1.25`; GTK reads `gtk-xft-dpi` in 1024ths of a DPI.) This key is **not
documented on ArchWiki's GTK page** — treat it as a hand-tested fallback, not the primary
mechanism. Prefer the `gsettings` call; only add the `gtk-xft-dpi` line if the user reports
non-GNOME GTK apps still rendering at the un-scaled DPI.

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

# accessibility — gotchas

## Larger-UI triggers the fractional-scaling caveat

Bumping monitor `scale` to `1.25` (or any non-integer value) is **fractional scaling**, which
is the exact case `../monitors/gotchas.md` flags. The downstream cost is real: XWayland apps
render blurry unless `xwayland:force_zero_scaling = true` is set, and `GDK_SCALE` must be set
to the integer ceiling (`1.25` → `2`) in `../env/template.md` to keep GTK windows crisp.

The rule: if `accessibility` contains `larger-ui` **and** the picked scale is non-integer, the
`monitors` and `env` writers must follow the full fractional-scaling fix block (see
`../monitors/gotchas.md` — the `monitors.scaling != 1.0` flag is the trigger). Don't ship
larger-UI with a fractional scale and the rest of the gotcha unaddressed; users will see blurry
XWayland fonts and assume the rice is broken.

If the user picks an integer scale bump (e.g. `2.0` on a 4K display), the caveat doesn't apply.

## Magnifier is built-in — no external tool

`cursor:zoom_factor` is a core Hyprland keyword (see [Variables § cursor](https://wiki.hypr.land/Configuring/Basics/Variables/)).
There is **no separate magnifier package**, no plugin, no `magnus`/`xzoom` equivalent to
install. The `packages.md` for this component deliberately doesn't list one. If the magnifier
bind silently does nothing, the diagnosis is one of:

- The dispatcher form is wrong (must be `exec, hyprctl keyword cursor:zoom_factor <N>`, not a
  bespoke dispatcher — there is no `zoom_factor` dispatcher).
- The keysym is wrong: `=` is `equal` and `-` is `minus` (the X11/XKB names, after
  `XK_`/`XKB_KEY_`); see [Binds wiki](https://wiki.hypr.land/Configuring/Basics/Binds/),
  which points at `xkbcommon-keysyms.h`.
- The Hyprland version is below the rice's 0.50.x minimum — but this is unreachable on a
  rice-installed system.

Related: `cursor:zoom_detached_camera` (`bool`, default `true`) detaches the camera from the
mouse when zoomed in, only moving the camera to keep the mouse in view at screen edges. The
rice does not surface this — defaults are fine — but document it for users who want a
"sticky-corner" magnifier feel.

## Cursor size requires BOTH `XCURSOR_SIZE` and `HYPRCURSOR_SIZE`

Hyprland reads cursor size from two env vars depending on the surface:

- **`XCURSOR_SIZE`** — used by XWayland apps, GTK (per [hyprcursor wiki](https://wiki.hypr.land/Hypr-Ecosystem/hyprcursor/):
  "some apps still don't [support server-side cursors] (e.g. GTK). Apps that do not support
  server-side cursors and hyprcursor will still fall back to XCursor"), and any other client
  that doesn't speak hyprcursor.
- **`HYPRCURSOR_SIZE`** — used by native Hyprcursor-aware apps (Qt, Chromium, Electron, Hypr
  ecosystem). Hyprcursor is the modern vector-based format, enabled by Hyprland's
  `cursor:enable_hyprcursor = true` default.

Emit **both** lines, both at the same size, or the cursor will be inconsistent across surfaces
(small on Hyprland-aware apps, large on XWayland — or vice versa). The `env` component already
emits the pair in lockstep; this component just bumps the value.

A `hyprctl setcursor <theme> <size>` call in `autostart` is also needed so already-running
sessions pick up the new size without a full restart.

## `hyprctl setcursor` only accepts hyprcursor themes (since 0.37)

Per the [hyprctl wiki § setcursor](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl/#setcursor):
"since 0.37.0, this only accepts hyprcursor themes. For legacy xcursor themes, use the
`XCURSOR_THEME` and `XCURSOR_SIZE` env vars."

If the cursor theme the rice picked is XCursor-only (no hyprcursor port), the `setcursor` call
in `autostart` will not affect the hyprcursor surface — but that's fine, because hyprcursor
will fall back to XCursor for the whole session anyway. Either way, the env vars
(`XCURSOR_SIZE`, `XCURSOR_THEME`) are the authoritative size/theme source for the fallback
path. The `setcursor` call is only effective when a hyprcursor port of the theme is installed.

## hyprsunset is a daemon, not a one-shot

A common bug: binding `bind = $mainMod SHIFT, N, exec, hyprsunset -t 4000` and expecting it to
toggle the filter on and off. It will not. `hyprsunset` is a long-running daemon (per
[hyprsunset wiki](https://wiki.hypr.land/Hypr-Ecosystem/hyprsunset/)); the documented control
surface is **`hyprctl hyprsunset <command>` IPC**:

- `hyprctl hyprsunset temperature <K>` — apply a temperature
- `hyprctl hyprsunset identity` — disable (no filter)
- `hyprctl hyprsunset gamma <pct>` — adjust gamma
- `hyprctl hyprsunset reset` — reset to current config-profile values
- `hyprctl hyprsunset profile` — print current profile

Also: the documented CLI flag is `--temperature`, not `-t`. The wiki does not list a `-t`
short form; if you ship the bind in a re-theme that happens to be backed by an older
hyprsunset that accepts `-t`, you'll see breakage on the supported version.

Start the daemon once via `exec-once = hyprsunset` in `../autostart/template.md`; bind keys
to the IPC commands above. The daemon is supported since Hyprland 0.45.0.

## Night-light overlaps `../utilities/` night-light

Both `accessibility` and `utilities` can emit a `hyprsunset` bind. **Pick one home.** The rule:

- If `utilities.selected` contains `"night-light"`, the bind is owned by `utilities` — this
  component does **not** also emit the bind even if `accessibility` contains `"night-light"`.
- If `utilities.selected` does **not** contain `"night-light"` but `accessibility` does, this
  component emits the bind.

The `keybinds` writer dedupes on bind key (`$mainMod SHIFT, N`), so a duplicate is a validator
error, not a silent override. Surface the choice to the user during the review pass if both
groups picked it.

## GTK `cursor-size` doesn't take effect on already-running apps

The GTK settings file (`gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`) is read at app launch.
Bumping `gtk-cursor-theme-size` after the fact means **already-open GTK apps keep the old
size** until restarted. Combine the settings file write with **`gsettings set
org.gnome.desktop.interface cursor-size <N>`** (per [ArchWiki Cursor themes § GNOME](https://wiki.archlinux.org/title/Cursor_themes#GNOME)),
which xsettings-mediated GTK apps will pick up live. `hyprctl setcursor` re-broadcasts the
hyprcursor surface but does **not** push GTK an update (the hyprctl help text literally says
"Will set the theme for everything except GTK, because GTK"). A full logout/login is the only
sure fix.

## Cursor theme location matters (don't put themes in `/usr/share/icons` by hand)

Per the [hyprcursor wiki](https://wiki.hypr.land/Hypr-Ecosystem/hyprcursor/): "Put your
theme(s) in `~/.local/share/icons` or `~/.icons`. It's not recommended to put cursor themes
in system-wide `/usr/share/icons` due to potential permission issues." The same advice
appears on the [ArchWiki Cursor themes](https://wiki.archlinux.org/title/Cursor_themes) page
for non-packaged themes.

This component does **not** install cursor themes — the cursor theme is selected and
installed by the palette/theming pipeline. But when the installer copies a theme into the
user's home, prefer `~/.local/share/icons/<name>/`. Themes shipped as Arch packages land in
`/usr/share/icons/<name>/` and that's fine (pacman manages them).

## No popular rice ships a high-contrast palette mode

A corpus survey (HyprPanel themes, noctalia `Assets/ColorScheme/`, HyDE themes, Matt-FTW,
caelestia, ML4W matugen templates, end-4 matugen templates, dusky theme variants) found **zero**
rices shipping a true high-contrast / WCAG-AA palette variant. Every named scheme is aesthetic
(Catppuccin/Dracula/Rose Pine/Tokyo Night/Gruvbox/Material-You-from-wallpaper). HyprPanel ships
`_vivid` variants but those bump saturation, not contrast.

This means a re-theme with the rice's matugen scheme cannot satisfy a low-vision user the way
GNOME's Adwaita-Dark high-contrast or KDE's Breeze-HighContrast can. The rice does not currently
expose a "high-contrast" palette option — see `theming/palettes.md`. **Flag for orchestrator**:
if the plugin wants to compete on accessibility, adding a `high-contrast` named palette (e.g.
pure `#000000` / `#ffffff` with desaturated semantic colors at >= 7:1 contrast) is a real
differentiator — but it has to land as a new entry in `theming/palettes.md` and a new value of
the `scheme` metadata key, NOT inside this component.

The `accessibility` interview deliberately does **not** offer a high-contrast switch today,
because the rice can't fulfil it. Don't promise what we can't deliver.

## Shared font-scale variable (now exposed: `font_ui_scale`)

The corpus survey found no rice exposed a shared font-scale variable cross-surface (waybar
font-size, rofi/fuzzel font-size, kitty `font_size`, hyprlock `font_size`, btop were all set
per-app, independently). DankMaterialShell's `fontScale` + `dankBarFontScale` and caelestia's
`FontSize.scale` were the closest prior art, both QML-only.

**Now implemented** (v0.15+): `font_ui_scale` is a `palette.conf` metadata key (default `1.0`;
options `1.0|1.15|1.3|1.5`). The interview asks once in group 13 (fonts). Every visual surface
multiplies its default font-size by it — recipe-driven CSS surfaces emit
`font-size: calc(<base>px * {{font_ui_scale}});` at write time, recipe-driven non-CSS surfaces
multiply the absolute size at generate time, and quickshell renders a real `Colors.fontScale`
property that QML files multiply by. See [`theming/fonts.md`](../../theming/fonts.md) →
"Cross-surface font-scale" for the full per-surface convention and citations.

This **complements** the `larger-ui` helper: that one scales the monitor (via `scale`) and
xsettings-mediated GTK apps; `font_ui_scale` reaches every other surface (waybar / hyprlock /
QML widgets / fuzzel / etc.) where the gsettings bridge doesn't apply.

## No popular rice ships a "vestibular" / motion-off accessibility profile

Same survey: no rice in the corpus ships a one-switch toggle that disables animations
(`animations:enabled = false`) or blur (`decoration:blur:enabled = false`) for users with
vestibular sensitivity, photophobia, or migraine. Every animation block is unconditionally
enabled. `binnewbs`, `Matt-FTW`, `caelestia`, `HyDE`, `ML4W`, `JaKooLit`, `end-4`, `dusky` all
ship animations on by default.

The `accessibility` interview does not currently surface a "motion-off" pick. **Flag for
orchestrator**: a future `motion-reduced` (or `disable-animations`) helper here would land in
`../look-feel/template.md` (set `animations:enabled = false`, `decoration:blur:enabled = false`,
zero out `gestures:*`) and would need a per-helper output map entry parallel to the four
existing ones. Today this gap is documented but not filled.

## Night-light: the community default is a wrapper script, not two IPC binds

The on-disk corpus is unanimous: both [ML4W](https://github.com/mylinuxforwork/dotfiles)
(`.config/ml4w/scripts/ml4w-toggle-hyprsunset`) and [JaKooLit](https://github.com/JaKooLit/Hyprland-Dots)
(`config/hypr/scripts/Hyprsunset.sh`) bind **one** key to a wrapper script that maintains state
(JaKooLit uses `~/.cache/.hyprsunset_state`; ML4W uses `pgrep -x hyprsunset`). The two-bind
shape (`hyprctl hyprsunset temperature 4000` on one key, `... identity` on another) appears in
no popular rice as the primary surface — only as inline documentation.

This was a real correction to the v0.13 template, which originally instructed a two-bind shape
and a note "no toggle dispatcher — bind a second key". The corpus says: ship the wrapper.

## Version note

- `cursor:zoom_factor` — core (documented at [Variables § cursor](https://wiki.hypr.land/Configuring/Basics/Variables/);
  `float`, default `1.0`, minimum `1.0`).
- `cursor:zoom_rigid` — core (`bool`, default `false`). When `true` the cursor stays centred
  while zoomed; when `false`, the cursor moves freely within the zoomed viewport.
- `cursor:enable_hyprcursor` — core (`bool`, default `true`). Disable only if you want pure
  XCursor behaviour and don't have a hyprcursor port of your theme.
- `hyprsunset` — separate package, supported since **Hyprland 0.45.0** (per
  [hyprsunset wiki](https://wiki.hypr.land/Hypr-Ecosystem/hyprsunset/)). The rice's
  0.50.x minimum clears this with margin.
- `hyprctl setcursor` — since 0.37, hyprcursor-only.
- `xwayland:force_zero_scaling` — present in all currently-supported Hyprland versions; see
  `../../_shared/version-matrix.md` for the full scaling-related cliff list.

# Theming Architecture

The cross-surface theming model: **one normalized palette → render it into every app's config →
reload each app.** This is exactly how `matugen` and `wallust` work, and it generalizes to named
schemes and manual hex. Get the palette once, then every surface stays in sync.

This file holds the per-surface mechanics, GTK/Qt/cursor gotchas, and dark/light handling — the
parts that aren't engine-internal. Engine internals (manifest format, render flow, CLI) are in
[`engine.md`](engine.md).

## Where the `.tmpl` files live (post-refactor)

After the precursor refactor, per-app `.tmpl` files are **co-located with the component that owns
them**, not pooled in a flat `skills/rice/templates/`:

| Template kind | Location in this repo |
|---|---|
| Per-app component templates | `references/components/<component>/<app>.tmpl` (e.g. `waybar/waybar.tmpl`; `launcher/{rofi,fuzzel,wofi}.tmpl`; `notifications/{mako,dunst,swaync}.tmpl`; `terminal/{kitty,btop,cava}.tmpl`; `widgets/{eww,ags,quickshell}.tmpl`; `shell-prompt/{starship,oh-my-posh,fish}.tmpl`; `look-feel/hyprland.tmpl`; `utilities/wlogout.tmpl`) |
| Engine-owned templates | `references/theming/gtk4.tmpl` (the libadwaita override file) and `references/theming/palette.matugen.tmpl` (the matugen output that produces `palette.conf` from a wallpaper) |

At runtime, `scripts/rice-init.sh` collects both sets — `references/components/*/*.tmpl` **and**
`references/theming/*.tmpl` — and copies them **flat** into `~/.config/hypr-rice/templates/`. The
manifest (`templates.list`) still references that flat directory. So the user-facing layout in
[`engine.md`](engine.md) is unchanged; only the source-of-truth in this repo moved.

When you edit a template, edit it in its owning component folder. The per-component `template.md`
documents the wiring (`@import`/`source =`/`include`) and the colors-contract row; the `.tmpl`
itself is the rendered output the engine writes.

## The palette contract (overview)

Every template consumes a normalized palette. Whatever the source (named, generated, manual),
resolve to the keys before rendering. The canonical schema (every key, every metadata field, sizing
rules, render flow) is in [`_shared/palette-schema.md`](../_shared/palette-schema.md); the per-app
exported variable names are in [`_shared/colors-contract.md`](../_shared/colors-contract.md).

Wrap formats per app (also in the colors contract):

- **Hyprland** (`hyprland.conf`, `looknfeel.conf`): `rgb({{accent}})` — no `#`, parens around hex.
- **CSS** (`@define-color`, `*` rasi blocks): `#{{accent}}` — leading `#`, semicolon-terminated.
- **kitty / btop**: `#{{accent}}` — leading `#`, space-separated.
- **fuzzel** `[colors]`: `{{accent}}ff` — bare hex with two-digit alpha suffix, no `#`.
- **fish**: bare hex `{{accent}}` on `set -g fish_color_*` lines.

Hyprlock can't read Hyprland `$vars`, and fuzzel `[colors]` is merge-time not include — both fill
literal hex from `palette.conf` at generate-time (the only two exceptions to the "components
`@import`/`include` their colors file" rule).

### Pending contract-row extensions (flagged, not yet applied)

Batches 1+2 surfaced three places where the per-component `.tmpl` has drifted ahead of
[`_shared/colors-contract.md`](../_shared/colors-contract.md). These are **orchestrator decisions**
— the architecture flags them so the contract can catch up in one pass; do not edit the contract
piecemeal from any single component:

| Component | Contract row says | `.tmpl` actually exports | Decision pending |
|---|---|---|---|
| **quickshell** | `term[16]` (array) | individual `term0..term15` properties (corpus pattern; caelestia / DankMaterialShell reference `Colors.term3` directly, an array would force `Colors.term[3]` and break drop-in copies — see `widgets/styling.md`) | Update the contract row to list `term0..term15` explicitly |
| **kitty** | `background foreground cursor selection_background selection_foreground color0..color15` | Adds semantic chrome keys: `cursor_text_color url_color active_tab_foreground active_tab_background inactive_tab_foreground inactive_tab_background tab_bar_background` (paired with `tab_bar_style powerline` in the recipe — see `terminal/kitty.tmpl` and `terminal/styling.md`) | Append the chrome keys to the row |
| **fuzzel** | 7 keys: `background text match selection selection-text selection-match border` | Grew to 11 keys: adds `prompt placeholder input counter` to support the prompt-glyph / placeholder-text / counter idioms in the recipe (see `launcher/styling.md` "Color details") | Bump the row to 11 keys |

Once the orchestrator applies these, the corresponding per-app `template.md` "Variable resolution"
table and `palette-schema.md` requirement set are also re-checked. None of these break running
configs — the keys are additive over the prior contract.

## Per-surface application

### Hyprland (compositor)

Engine writes `~/.config/hypr/colors.conf` of `$var = rgb(hex)` lines; `hyprland.conf` `source =`s
it; `looknfeel.conf` references `$accent`/`$bg`/… (see
[`components/look-feel/template.md`](../components/look-feel/template.md)). Reload: `hyprctl
reload`. Use `scripts/verify-config.sh` to confirm the colors file still parses.

### hyprlock

Edit `~/.config/hypr/hyprlock.conf` colors (`outer_color`, `inner_color`, `font_color`,
`check_color`, `fail_color`). Applied at next lock — no reload command needed. Hyprlock fills
literal hex at generate-time (it doesn't `source` Hyprland vars).

### Waybar

CSS at `~/.config/waybar/style.css`. The engine writes `~/.config/waybar/colors.css` of
`@define-color` entries and `@import`s it. Reload: `killall -SIGUSR2 waybar`. See
[`components/waybar/template.md`](../components/waybar/template.md).

### Notifications (mako / dunst / swaync)

- **mako**: `~/.config/mako/config` — `background-color`, `text-color`, `border-color`. Reload:
  `makoctl reload`.
- **dunst**: `~/.config/dunst/dunstrc` — `[urgency_*]` `background`/`foreground`/`frame_color`.
  Reload: `dunstctl reload` (falls back to `killall dunst; dunst &`).
- **swaync**: `~/.config/swaync/colors.css` (`@import` from `style.css`). Reload: `swaync-client -rs`.

See [`components/notifications/template.md`](../components/notifications/template.md).

### Launchers (wofi / rofi / fuzzel)

- **wofi**: `~/.config/wofi/style.css` (GTK CSS). Read at launch — no reload needed.
- **rofi**: `~/.config/rofi/colors.rasi` `@import`ed from the theme; read at launch.
- **fuzzel**: `[colors]` merged into `~/.config/fuzzel/fuzzel.ini` at generate-time (no include
  mechanism). Read at launch.

See [`components/launcher/template.md`](../components/launcher/template.md).

### Terminal

- **kitty**: write `~/.config/kitty/colors.conf` (`background`, `foreground`, `color0..color15`,
  `cursor`) and `include colors.conf` from `kitty.conf`. Live-reload running kitties:
  `kill -SIGUSR1 $(pidof kitty)` (or `kitty @ set-colors -a -c colors.conf` with remote control).
- **alacritty**: `~/.config/alacritty/colors.toml` imported from `alacritty.toml`; live-reloads.
- **foot**: `~/.config/foot/foot.ini` `[colors]`; foot reloads on `SIGUSR1`.

See [`components/terminal/template.md`](../components/terminal/template.md).

### GTK (3 + 4 / libadwaita)

**Live apply** with gsettings:

```bash
gsettings set org.gnome.desktop.interface gtk-theme '<Theme>'
gsettings set org.gnome.desktop.interface icon-theme '<Icons>'
gsettings set org.gnome.desktop.interface cursor-theme '<Cursor>'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface font-name '<Font> <Size>'   # e.g. 'Inter 11'
```

**libadwaita** (GTK4) leverages color overrides in `~/.config/gtk-4.0/gtk.css` with
`@define-color` (`accent_color`, `window_bg_color`, `view_bg_color`, the full libadwaita set —
contract in [`_shared/colors-contract.md`](../_shared/colors-contract.md) → `gtk4` row). It honors
`color-scheme=prefer-dark` via the xdg-desktop-portal.

For a *full* GTK4 theme (e.g. an installed Everforest/Catppuccin GTK theme), symlink its
`gtk-4.0/` into `~/.config/gtk-4.0/` (`--libadwaita` installers do this) — but then the rice
engine's `gtk4` render owns the same `gtk.css`, so **disable that manifest line** or it fights the
symlink.

## GTK gotchas (the four that matter)

These are the four GTK theming failure modes that don't show up in casual reading and reliably bite
the rice engine:

### 1. `gtk-4.0/gtk.css` may already be a root-owned symlink

If a system GTK theme (e.g. Catppuccin-GTK) has been installed via `--libadwaita`, the installer
symlinks the **whole `gtk-4.0/`** directory under `~/.config/`. Writing through the symlink fails
with **"Permission denied"** (root-owned target).

Fix: `render-templates.sh` `rm`s a symlinked output before writing, so the render replaces it with
a rice-owned file. If doing it by hand, `rm ~/.config/gtk-4.0/gtk.css` first.

If the user *wants* the full GTK theme to own the file (re-installs via `--libadwaita` after the
rice scaffold), **comment out the `gtk4` manifest line** so the theme owns that file. GTK colors
are then the theme's, not engine-driven; re-enable the line to go back to palette overrides.

### 2. Folder color = icon theme, not GTK theme

Blue folders after a re-theme means the **icon theme** didn't change. The GTK theme controls
window chrome; the icon theme controls folder colors. Use a scheme-matched icon set (Papirus +
`papirus-folders -C <accent>`, or a theme that ships its own icons like the Everforest GTK repo's
`Everforest-Dark`). Rebuild the icon cache afterwards: `gtk-update-icon-cache`.

### 3. `GTK_THEME` env var (uwsm) overrides everything

A session env var `GTK_THEME=<name>` — common with **uwsm** in `~/.config/uwsm/env` — makes GTK
apps use *that* theme regardless of gsettings / `settings.ini` / `gtk.css`. The rendered `gtk.css`
silently has no effect.

Fix: edit `~/.config/uwsm/env` (see `components/env/template.md` and `detect-version.sh` for the
`UWSM_*` lines), then live-propagate:

```bash
hyprctl keyword env GTK_THEME,<name>           # 0.55+ form; older Hyprland: hyprctl setenv
dbus-update-activation-environment --systemd GTK_THEME=<name>
```

(On 0.55+ the env component's `envd =` lines already push into the session bus on startup; the
`dbus-update-activation-environment` call is the *runtime* equivalent for live theme swaps. See
`components/env/gotchas.md` for the `hyprctl setenv` → `hyprctl keyword env` deprecation.)

nautilus and other GTK apps re-read it on next launch.

### 4. gsettings alone does NOT theme GTK3 apps on Wayland

On a Wayland/Hyprland session, gsettings alone (`gtk-theme` / `color-scheme` / `icon-theme`) does
**not** reliably theme GTK3 apps (e.g. **nm-connection-editor**) — they fall back to the default
**light** theme. Also write the per-version `settings.ini`:

```ini
# ~/.config/gtk-3.0/settings.ini  AND  ~/.config/gtk-4.0/settings.ini
[Settings]
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Inter 11
gtk-cursor-theme-name=<Cursor>
gtk-cursor-theme-size=24
```

And `~/.gtkrc-2.0` for GTK2 apps:

```ini
gtk-theme-name="Adwaita-dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Inter 11"
gtk-cursor-theme-name="<Cursor>"
```

`settings.ini` changes apply **only to newly-launched apps** — already-open apps must be relaunched
to pick them up. libadwaita apps follow `color-scheme=prefer-dark` via the xdg-desktop-portal but
still want the `settings.ini`.

### murrine note (GTK2-only dependency trap)

Several full GTK themes (`everforest-gtk-theme-git`, other Fausto-Korpsvart family themes)
`depends=gtk-engine-murrine`, which on current Arch pulls in the AUR `gtk2` (dropped from the
repos). That builds GTK2 from a giant source clone that often fails on HTTP/2, so `yay` rolls the
whole thing back. **murrine is GTK2-only** — skip the package and build the theme from SCSS with
`sassc`:

```bash
# in the theme repo
themes/build.sh
themes/install.sh -d ~/.local/share/themes -c dark -t <accent> --libadwaita
```

Copy the repo's `icons/` for matching folder colors.

## Qt

- `qt6ct` (+ `qt5ct`): pick the color scheme/style in their config; require
  `env = QT_QPA_PLATFORMTHEME,qt6ct` in `~/.config/hypr/env.conf` (the rice skill can add this).
- `kvantum`: SVG theme engine; `kvantummanager` to pick, `env = QT_STYLE_OVERRIDE,kvantum`.
- First-party `hyprland-qt-support` / `hyprqt6engine` theme the hypr tools' Qt dialogs.

## Cursor

Live cursor switch on Hyprland (gsettings sometimes doesn't apply):

```bash
hyprctl setcursor <Theme> <size>
```

Cursor *theme* is recorded in many places — keep them all in sync or relogins surface the wrong
theme:

| Location | Field |
|---|---|
| gsettings | `cursor-theme`, `cursor-size` |
| `~/.config/hypr/env.conf` | `env = XCURSOR_THEME,<name>` + `XCURSOR_SIZE,<n>` + `HYPRCURSOR_THEME,<name>` + `HYPRCURSOR_SIZE,<n>` |
| `~/.gtkrc-2.0` | `gtk-cursor-theme-name`, `gtk-cursor-theme-size` |
| `~/.config/gtk-{3,4}.0/settings.ini` | `gtk-cursor-theme-name`, `gtk-cursor-theme-size` |
| `~/.config/xsettingsd/xsettingsd.conf` | `Gtk/CursorThemeName`, `Gtk/CursorThemeSize` |
| `~/.icons/default/index.theme` | `Inherits=<theme>` (what nwg-look writes; fastfetch reads it) |
| `~/.config/uwsm/env` if present | `XCURSOR_THEME=…` / `HYPRCURSOR_THEME=…` |

Notes:

- **Bibata is xcursor-only** — leave `HYPRCURSOR_THEME` unset to fall back, or set it to Bibata
  too and Hyprland falls through to xcursor.
- **Disappearing-when-idle cursor on nouveau/NVIDIA** → not a theme issue; set
  `cursor:no_hardware_cursors = true` in `~/.config/hypr/look-feel.conf`.

## Per-surface dark/light handling

For light schemes (catppuccin-latte, solarized-light):

- gsettings: `color-scheme prefer-light`.
- `settings.ini`: `gtk-application-prefer-dark-theme=0`.
- Use the light-variant icon theme (Papirus, not Papirus-Dark).
- Hyprland looks identical (no dark-mode toggle in the compositor) — the difference lives in the
  rendered `colors.conf`.
- waybar/launcher/notifications: `colors.css` re-rendered from the palette covers it.
- kitty/foot/alacritty: same — `colors.conf` re-render.
- libadwaita: honors `color-scheme=prefer-light` via the portal automatically.

The interview asks the palette pick (component 12) before fonts/wallpaper, so the light/dark
decision propagates downstream consistently.

## Cross-surface palette coherence (one-radius, one-accent)

Two cross-component conventions emerged from the batch-1+2 corpus survey. The architecture
documents them here so per-component templates pin to the **same** values rather than each
re-deriving a local one:

- **`decoration:rounding`** (set in `look-feel/hyprland.tmpl` from
  `look_feel.rounding` — see `components/look-feel/template.md`) is the canonical pill radius
  reused by:
  - **waybar** module pill `border-radius` (`waybar/template.md`),
  - **launcher** result-row `border-radius` (rofi `element`, wofi `#entry`, fuzzel `[border]
    radius=`),
  - **notifications** card `border-radius` / `corner_radius` (`mako`, `dunst`, `swaync`),
  - **widgets** card `border-radius` (`eww/ags/quickshell`, exported as `radius`).
  This is also what `look-feel/template.md` uses for its window-group `gradient_rounding =
  {{rounding}}` so tab pills, window corners, and bar pills all share a corner language.
- **`$accent`** (the palette's primary accent — see `_shared/palette-schema.md`) is the shared
  highlight color across:
  - **waybar** active-workspace pill background (`#workspaces button.active` ⇒ `@accent`),
  - **launcher** selection-row background (`element selected.normal` / `#entry:selected` /
    `selection=`),
  - **mako** `border-color` / **dunst** `frame_color` / **swaync** `.notification.critical`
    border,
  - **hyprbars** title-bar text (`look-feel/template.md` plugins block),
  - **Hyprland** `general:col.active_border` (`look-feel/hyprland.tmpl` exports
    `$accent` for this).
  The user perceives "one accent" because every surface that draws attention uses the *same*
  hex resolved from the *same* palette key. Per-component overrides exist (`accent2` for
  secondary highlights, `red` for urgency), but the default for "the highlight" is `$accent`
  everywhere.

## New cross-component dataflows from batches 1+2

Three new wires were added by sibling components since the last architecture pass; each is
owned elsewhere but flows through the theming engine:

### 1. `restore-theme.sh` (engine writes; `autostart` schedules)

When `theming.engine ∈ {matugen, wallust, wallbash}`, the engine's wallpaper-pick / `rice apply`
flow now **generates** a `~/.config/hypr/scripts/restore-theme.sh` whose body re-applies the last
palette + wallpaper at login. The engine owns the script *body* (it knows the current wallpaper
path, the wallbash regen call, the `swww img <path>` invocation); the `autostart` component owns
the *scheduling* — it emits a single `exec-once = ~/.config/hypr/scripts/restore-theme.sh` line
**after** the wallpaper daemon's `exec-once`, so the daemon is alive when the script runs. See
`components/autostart/template.md` "Theme-restore on login" and `theming/wallpaper.md` for the
engine-side recipe (matugen post-hook, wallust template, wallbash regenerator).

Dataflow: `rice apply` → write `restore-theme.sh` (engine-owned) → autostart's `exec-once` gate
flips on (`has_restore_script = true`) → next login replays the last theme without Claude in
the loop. Cited corpus patterns: end-4 `__restore_video_wallpaper.sh`, ML4W
`ml4w-autostart`, HyDE `swwwallpaper.sh`.

### 2. `envd = XDG_CURRENT_DESKTOP,Hyprland` (env emits; portals read)

The env component now emits `envd =` (D-Bus push) for `XDG_CURRENT_DESKTOP` rather than `env =`
(in-process only). This propagates the var to the systemd / D-Bus activation environment so
xdg-desktop-portal and portal-spawned apps see `Hyprland` as the current desktop without
needing the autostart-side `dbus-update-activation-environment --systemd …` fallback. See
`components/env/template.md` and `components/env/gotchas.md` "envd= vs env=". The
GTK-themed-via-portal flow (`color-scheme prefer-dark`) depends on the portal seeing
`XDG_CURRENT_DESKTOP=Hyprland`, so this matters for libadwaita re-rendering on a dark/light
swap.

The autostart `dbus-update-activation-environment` lines are still emitted as a belt-and-suspenders
fallback (they're harmless if `envd =` already populated the bus); the `dbus_all` gate adds
the maximum-compat `--all` broadcast for HyDE/dusky-style rices.

### 3. Layerrule emission table (window-rules emits; theming surfaces blur)

`window-rules/template.md` now emits `layerrule = blur, …` blocks driven by the **chosen-tool
flags** from sibling components. The architecture documents the mapping here because every layer
surface in the rice has both a theming side (translucent backgrounds, frosted look) and a
window-rule side (the compositor blur that makes the translucency look frosted instead of just
see-through):

| Source flag | Namespace | Block |
|---|---|---|
| `waybar.enabled` | `waybar` | `blur = true; blur_popups = true; xray = true; ignore_alpha = 0.5` |
| `launcher.is_layer` + `launcher.namespace` | `rofi` / `launcher` (fuzzel — **not** `fuzzel`) / `wofi` / `anyrun` | `blur = true; ignore_alpha = 0.5` |
| `notifications.tool == "swaync"` | **TWO** namespaces: `swaync-control-center` AND `swaync-notification-window` | `blur = true; ignore_alpha = 0.0` (each) |
| `notifications.tool ∈ {mako, dunst}` | `notifications` | `blur = true; ignore_alpha = 0.0` |
| `utilities.session_picker == "wlogout"` | `logout_dialog` | `blur = true; ignore_alpha = 0.0` |

Two cross-component cliffs the architecture should call out:

- **fuzzel's layer namespace defaults to `launcher`**, not `fuzzel` — verified against
  `fuzzel.ini(5)` and end-4 `dots/.config/hypr/hyprland/rules.lua`. A `layerrule = blur,
  fuzzel` is silently a no-op (matches nothing). See `components/launcher/gotchas.md`.
- **walker uses `ext-background-effect-v1`** (the compositor-served blur protocol) rather than
  a `layerrule = blur, walker`. Hyprland implemented the server side in May 2026 (~v0.50+);
  on older Hyprland the flag silently no-ops. See `components/companion-daemons/gotchas.md`
  "walker's `ext_background_effect_blur`".

## Apply + reload (full catalog)

After writing the theme files, reload each affected running app so changes show without logout.
`apply-theme.sh` does this guarded by `pidof`/`pgrep`:

| App | Reload command |
|---|---|
| Hyprland | `hyprctl reload` |
| waybar | `killall -SIGUSR2 waybar` |
| mako | `makoctl reload` |
| dunst | `dunstctl reload` |
| swaync | `swaync-client -rs` |
| kitty | `kill -SIGUSR1 $(pidof kitty)` |
| foot | `kill -SIGUSR1 $(pidof foot)` |
| alacritty | live (file watch) |
| btop | restart (`pkill -USR2 btop` for matugen-managed; restart otherwise) |
| cava | restart |
| eww | `eww reload` |
| ags / astal | live (file monitor) |
| quickshell | live (file watch) |
| GTK / icons / cursor / font | `gsettings set …` (applies live) |
| GTK env (`GTK_THEME`) | `hyprctl keyword env GTK_THEME,…` (0.55+; `hyprctl setenv` pre-0.55) + `dbus-update-activation-environment --systemd GTK_THEME=…` |
| cursor (Hyprland) | `hyprctl setcursor <Theme> <size>` |
| theme-restore on login | engine-generated `~/.config/hypr/scripts/restore-theme.sh` (scheduled by `autostart` `exec-once`) — replays the last `rice apply` so the desktop boots into the saved palette + wallpaper. See "New cross-component dataflows" above. |

Then `scripts/verify-config.sh` confirms the Hyprland color file still parses (`VERIFY=ok`). Back
up every file first with `scripts/backup-path.sh`.

## Cross-references

- Engine architecture (manifest, render flow, CLI) → [`engine.md`](engine.md).
- Palette schema (the canonical key list) → [`_shared/palette-schema.md`](../_shared/palette-schema.md).
- Per-app exported variable names → [`_shared/colors-contract.md`](../_shared/colors-contract.md).
- Named scheme hex catalog → [`palettes.md`](palettes.md).
- Fonts → [`fonts.md`](fonts.md).
- Wallpaper + dynamic theming → [`wallpaper.md`](wallpaper.md).
- Long-tail apps via matugen → [`apps.md`](apps.md).
- Widget-shell theming → [`components/widgets/template.md`](../components/widgets/template.md).
- Shell & prompt theming → [`components/shell-prompt/template.md`](../components/shell-prompt/template.md).
- Restore-theme `exec-once` scheduling → [`components/autostart/template.md`](../components/autostart/template.md) "Theme-restore on login".
- D-Bus / session-bus env (`envd = XDG_CURRENT_DESKTOP,Hyprland`) → [`components/env/template.md`](../components/env/template.md) and [`components/env/gotchas.md`](../components/env/gotchas.md).
- Layerrule blur emission table → [`components/window-rules/template.md`](../components/window-rules/template.md) "Layer-shell blur".

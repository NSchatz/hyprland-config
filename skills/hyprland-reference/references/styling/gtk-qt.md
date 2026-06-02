# Styling GTK & Qt Apps (themes · icons · cursors · fonts)

App windows (Nautilus, GNOME Text Editor, qBittorrent, VLC, system dialogs) are themed
*differently* from CSS-styled bars: you don't hand-write their colors, you **install a theme
package and point a settings key at it**. The whole game is getting GTK3, GTK4/libadwaita, and
Qt5/Qt6 to converge on one look — same accent, same dark/light, same icons, same cursor, same
font — so nothing on screen reads as alien.

## What you're styling

| Surface | Mechanism | Where it lives |
|---|---|---|
| **GTK3** | `gtk-theme` name + `color-scheme` via `gsettings` (and a mirrored `~/.config/gtk-3.0/settings.ini`) | themes in `~/.themes` or `~/.local/share/themes`; settings exported by `nwg-look` |
| **GTK4 / libadwaita** | `color-scheme` (dark/light) via `gsettings` **+** `@define-color` overrides in `~/.config/gtk-4.0/gtk.css` (plus optional `assets/`) | libadwaita ignores legacy GTK themes — it only honors the named-color overrides + accent |
| **Icons** | `icon-theme` via `gsettings` | `~/.local/share/icons` or `/usr/share/icons` |
| **Cursor** | `cursor-theme` + `cursor-size` (gsettings), `hyprctl setcursor`, and `XCURSOR_*` / `HYPRCURSOR_*` env | `~/.icons`, `~/.local/share/icons`, `/usr/share/icons` |
| **Qt5 / Qt6** | `QT_QPA_PLATFORMTHEME=qt6ct` (or `qt5ct` / `gtk3`); qt6ct/qt5ct GUI picks style + palette; Kvantum (`kvantummanager`) for SVG themes via `QT_STYLE_OVERRIDE=kvantum` | `~/.config/qt6ct/`, `~/.config/qt5ct/`, `~/.config/Kvantum/` |
| **Fonts** | `font-name` + `monospace-font-name` via `gsettings` | system-installed font families |

Apply tools: `gsettings` (scriptable, source of truth on wlroots), `nwg-look` (GUI that writes
gsettings *and* exports `settings.ini`), `kvantummanager` + `qt6ct`/`qt5ct` for Qt.

## Design anatomy — the knobs that change the look

**The GTK theme** — the big lever for GTK3 and non-adwaita GTK4. Choose a family (adw-gtk3,
Colloid, Orchis, Catppuccin) and a *variant*: dark vs light, sometimes an accent or compact build
(e.g. `adw-gtk3-dark`, `Colloid-Dark`, `Orchis-Purple-Dark`). Set with
`gsettings set org.gnome.desktop.interface gtk-theme '<name>'`.

**`color-scheme = prefer-dark`** — the modern dark/light signal. libadwaita and GTK4 apps obey
*this*, not the theme name. Always set it alongside the theme:
`gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'`.

**The accent color** — on GNOME 47+/libadwaita the accent is a first-class setting
(`accent-color`), but stock libadwaita only exposes a fixed palette of named accents. For an
*arbitrary* hex accent you override `@define-color accent_color #...;` (and `accent_bg_color`) in
`gtk-4.0/gtk.css`, or use `adw-gtk3` + the [adw-colors](https://github.com/lassekongo83/adw-colors)
named-color sets. This is the single knob that makes apps feel "part of the rice."

**The icon theme** — Papirus is the default pick (`Papirus-Dark` / `Papirus`); its folder color is
re-tintable with `papirus-folders -C <accent> --theme Papirus-Dark` (cat, blue, teal, purple…).
Tela / Tela-circle ship per-color variants (`Tela-purple-dark`). Set via `icon-theme`.

**The cursor theme + size** — Bibata is the community default (`Bibata-Modern-Classic`,
`Bibata-Modern-Ice`). Size matters: 20–24 on 1080p, 24–32 on HiDPI. It must be set in *three*
places (gsettings, XCURSOR env, HYPRCURSOR env) or you get a mismatched/jumping cursor.

**The font + size** — `font-name 'Inter 11'` for UI, `monospace-font-name 'JetBrainsMono Nerd Font 11'`
for terminals/code views inside apps. Trailing number is the point size.

**Qt matching** — Qt apps don't read GTK settings. Either tell Qt to mimic GTK
(`QT_QPA_PLATFORMTHEME=gtk3`) or — for a real rice — run them through **Kvantum** with a matching
SVG theme (Catppuccin-Kvantum, KvGruvbox, Nordic) selected in `kvantummanager`, and set
icons/fonts in `qt6ct`. Without this, Qt apps fall back to a gray Fusion look that clashes badly.

**`~/.config/gtk-4.0/gtk.css`** — the libadwaita color override file. A handful of `@define-color`
lines (`window_bg_color`, `window_fg_color`, `view_bg_color`, `accent_color`, `headerbar_bg_color`,
`card_bg_color`, `popover_bg_color`) tint GTK4/adwaita apps to your palette. This is what dynamic
tools like matugen generate.

## How the community styles it

**Install a matching theme *set* (most common).** Pick one scheme and grab the GTK theme + icons +
cursor + Kvantum theme that all share it. Set them with `gsettings` + `kvantummanager`. Popular
per-scheme combos:

| Scheme | GTK theme | Icons | Cursor | Qt (Kvantum) |
|---|---|---|---|---|
| **Catppuccin** | adw-gtk3-dark (+ gtk.css accent) or Catppuccin-GTK (archived) | Papirus-Dark (folders `cat-mocha-*`) | Bibata-Modern-Classic | Catppuccin-Mocha-* |
| **Gruvbox** | Gruvbox-Dark / Colloid-Dark-Gruvbox | Papirus-Dark (orange folders) | Bibata-Modern-Classic | KvGruvbox / Gruvbox-Kvantum |
| **Nord** | Nordic / Orchis-Dark | Papirus-Dark (nordic folders) | Bibata-Modern-Ice | Nordic / Nord-Kvantum |
| **Tokyo Night** | Tokyonight-Dark / Colloid-Dark | Papirus-Dark (blue/purple folders) | Bibata-Modern-Classic | Tokyo-Night-Kvantum |

**Note:** the upstream `catppuccin/gtk` repo was **archived June 2024** ("GTK… can only be
described as a nightmare to consistently theme and maintain"). The community has largely moved to
**adw-gtk3-dark + a `gtk-4.0/gtk.css` accent override**, which tracks libadwaita more cleanly than a
full custom GTK theme.

**The matugen / dynamic approach.** Generate `gtk-3.0/gtk.css` and `gtk-4.0/gtk.css` (the
`@define-color` block) from the wallpaper palette so apps recolor with every wallpaper change.
matugen ships a [GTK colors template](https://github.com/InioX/matugen-themes); HyDE/ml4w-style
setups do the same with wallust/pywal. **This plugin's rice engine already renders
`~/.config/gtk-4.0/gtk.css`** from the active palette — so GTK4/adwaita apps follow the rice
without an extra tool.

**adw-gtk3 + accent (cleanest libadwaita-consistent look).** Use `adw-gtk3-dark` for GTK3 so it
matches stock libadwaita exactly, set `color-scheme prefer-dark`, then push one accent via
`gtk-4.0/gtk.css` (or GNOME 47's `accent-color`). GTK3 and GTK4 apps end up visually identical —
no per-toolkit drift.

**nwg-look workflow.** `nwg-look` is a GTK3 settings GUI for wlroots. It loads/saves **gsettings**
directly and *exports* a `~/.config/gtk-3.0/settings.ini` on apply (it doesn't read that file). Open
it, pick theme/icons/cursor/font, hit Apply — good for one-shot setup; `gsettings` is better for
scripting. (It doesn't touch GTK4 `gtk.css` or Qt.)

Big dotfile projects ship all of this preconfigured: **HyDE** sets a default Kvantum theme
(`catppuccin-mocha-*`) on first boot and regenerates GTK/Qt colors from the wallpaper; **JaKooLit**
and **ml4w** apply default GTK/icon/cursor via `gsettings` and route Qt through qt5ct/qt6ct +
Kvantum.

## Tasteful default recipe

Worked example: **Catppuccin Mocha** (bg `1e1e2e`, fg `cdd6f4`, surface `313244`, accent `cba6f7`).
Packages are *suggested* — never auto-installed: `adw-gtk3`, `papirus-icon-theme`,
`papirus-folders`, `bibata-cursor-theme`, `kvantum`, `qt6ct`.

**1. Set the GTK/icon/cursor/font knobs via `gsettings`** (use the rice palette: `font_ui`,
`font_mono`):

```sh
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
gsettings set org.gnome.desktop.interface cursor-size 24
gsettings set org.gnome.desktop.interface font-name '{{font_ui}} 11'
gsettings set org.gnome.desktop.interface monospace-font-name '{{font_mono}} 11'
# accent folders (optional): papirus-folders -C cat-mocha-lavender --theme Papirus-Dark
```

**2. `~/.config/gtk-3.0/settings.ini`** (mirror so non-gsettings GTK3 apps agree):

```ini
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-font-name={{font_ui}} 11
gtk-application-prefer-dark-theme=true
```

**3. `~/.config/gtk-4.0/gtk.css`** — tint GTK4/libadwaita with the rice palette via `@define-color`
(keys are hex *without* `#`; example shows Catppuccin Mocha values):

```css
/* rice palette -> libadwaita named colors */
@define-color accent_color        #{{accent}};   /* cba6f7 */
@define-color accent_bg_color     #{{accent}};
@define-color accent_fg_color     #{{bg}};        /* 1e1e2e */
@define-color window_bg_color     #{{bg}};        /* 1e1e2e */
@define-color window_fg_color     #{{fg}};        /* cdd6f4 */
@define-color view_bg_color       #{{bg}};
@define-color view_fg_color       #{{fg}};
@define-color headerbar_bg_color  #{{surface}};   /* 313244 */
@define-color headerbar_fg_color  #{{fg}};
@define-color card_bg_color       #{{surface}};
@define-color popover_bg_color    #{{surface}};
@define-color popover_fg_color    #{{fg}};
```

**4. Cursor in env** (Hyprland config) so it's consistent everywhere, not just GTK:

```ini
env = XCURSOR_THEME,Bibata-Modern-Classic
env = XCURSOR_SIZE,24
env = HYPRCURSOR_THEME,Bibata-Modern-Classic
env = HYPRCURSOR_SIZE,24
exec-once = hyprctl setcursor Bibata-Modern-Classic 24
```

**5. Qt** — point Qt at qt6ct and Kvantum (Hyprland env), then pick the matching SVG theme:

```ini
env = QT_QPA_PLATFORMTHEME,qt6ct
env = QT_STYLE_OVERRIDE,kvantum
```

Then `kvantummanager` → install/select **Catppuccin-Mocha-Lavender** (or your scheme's Kvantum
theme), and in **qt6ct** set Icon Theme = `Papirus-Dark` and the fonts to match. qt5ct mirrors the
same for legacy Qt5 apps.

**Coherent Catppuccin Mocha set:** `adw-gtk3-dark` (+ the `gtk.css` accent above) · `Papirus-Dark`
(lavender folders) · `Bibata-Modern-Classic` @ 24 · `Catppuccin-Mocha-Lavender` Kvantum theme.

## Pitfalls

- **libadwaita ignores legacy GTK themes.** Setting `gtk-theme` to a custom GTK4 theme does *almost
  nothing* for adwaita apps — they only follow `color-scheme`, the `accent-color`, and your
  `gtk-4.0/gtk.css` `@define-color` overrides. Use adw-gtk3 (GTK3) + gtk.css (GTK4), not a full
  custom GTK4 theme, for consistency.
- **GTK4 needs BOTH gsettings AND gtk.css.** `color-scheme prefer-dark` alone gives you stock
  Adwaita dark, not your palette. The `@define-color` file is what supplies the actual colors.
- **Qt apps look alien without qt6ct/Kvantum + the env var.** If `QT_QPA_PLATFORMTHEME` isn't
  exported (in the Hyprland env, before the apps launch), Qt falls back to gray Fusion and ignores
  everything. Set the env, install qt6ct/Kvantum, *and* select a theme inside them.
- **Cursor size mismatch / disappearing cursor.** Set the cursor in all three: `gsettings`
  (`cursor-theme` + `cursor-size`), `XCURSOR_THEME`/`XCURSOR_SIZE` (XWayland + GTK fallback), and
  `HYPRCURSOR_THEME`/`HYPRCURSOR_SIZE` (native Hyprland). Mismatched sizes cause a jumping cursor;
  run `hyprctl setcursor <theme> <size>` to fix it live.
- **Theme installed but not selected.** Dropping a theme in `~/.themes` does nothing until a setting
  points at it. Verify with `gsettings get org.gnome.desktop.interface gtk-theme`.
- **Wrong install dir.** GTK3 themes go in `~/.themes` *or* `~/.local/share/themes`; GTK4
  `gtk.css`/`assets` go in `~/.config/gtk-4.0/`. Icons go in `~/.local/share/icons` / `~/.icons`.
- **Flatpak apps are sandboxed** and can't see `~/.themes` by default — they look out of place. Grant
  access: `flatpak override --user --filesystem=$HOME/.themes` (and `--filesystem=$HOME/.icons`),
  then `flatpak override --user --env=GTK_THEME=adw-gtk3-dark`, or use Flatseal. (They do honor
  `color-scheme` via the portal.)
- **`nwg-look` doesn't read your `settings.ini`** — it reads gsettings and *overwrites*
  `settings.ini` on apply. Don't expect hand edits to settings.ini to show up in it.

## Sources

- Hyprland wiki — App Themes / cursors: <https://wiki.hypr.land/> · hyprcursor: <https://wiki.hypr.land/Hypr-Ecosystem/hyprcursor/>
- adw-gtk3: <https://github.com/lassekongo83/adw-gtk3> · adw-colors: <https://github.com/lassekongo83/adw-colors>
- libadwaita named colors / CSS variables: <https://gnome.pages.gitlab.gnome.org/libadwaita/doc/latest/css-variables.html>
- Catppuccin GTK (archived June 2024): <https://github.com/catppuccin/gtk>
- Catppuccin Papirus folders: <https://github.com/catppuccin/papirus-folders> · papirus-folders: <https://github.com/PapirusDevelopmentTeam/papirus-folders>
- Papirus icon theme: <https://github.com/PapirusDevelopmentTeam/papirus-icon-theme>
- Bibata hyprcursor: <https://github.com/PythonTryHard/Bibata-Cursor-hyprcursor>
- matugen GTK template: <https://github.com/InioX/matugen-themes>
- nwg-look: <https://github.com/nwg-piotr/nwg-look> · <https://nwg-piotr.github.io/nwg-shell/nwg-look.html>
- ArchWiki — Uniform look for Qt and GTK applications: <https://wiki.archlinux.org/title/Uniform_look_for_Qt_and_GTK_applications>
- HyDE application theming: <https://deepwiki.com/JaKooLit/Hyprland-Dots/4.4-application-theming> · hyprqt6engine: <https://wiki.hypr.land/Hypr-Ecosystem/hyprqt6engine/>
- Flatpak desktop integration / theme access: <https://docs.flatpak.org/en/latest/desktop-integration.html>

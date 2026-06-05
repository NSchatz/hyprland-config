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
| **Qt5 / Qt6** | `QT_QPA_PLATFORMTHEME=qt6ct` (or `qt5ct` / `gtk3` / `hyprqt6engine`); qt6ct/qt5ct GUI picks style + palette; Kvantum (`kvantummanager`) for SVG themes via `QT_STYLE_OVERRIDE=kvantum` | `~/.config/qt6ct/`, `~/.config/qt5ct/`, `~/.config/Kvantum/`, `~/.config/hypr/hyprqt6engine.conf` |
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

## Battle-tested techniques (from real rices)

Concrete, attributed moves harvested from real dotfiles and the theme installers. Grouped by layer.

**libadwaita / GTK4.**
- *Symlink a theme's `gtk-4.0/` into `~/.config` — the universal libadwaita recolor* (catppuccin/gtk, vinceliuice): when you want a full theme (not just a `@define-color` override), `ln -sf <theme>/gtk-4.0/{gtk.css,gtk-dark.css,assets} ~/.config/gtk-4.0/`. Ship **both** `gtk.css` and `gtk-dark.css` so `color-scheme` light/dark switching works. (Caveat: the symlink method breaks *live* theme-switching — you relog or restart apps. The plugin's own per-palette `gtk-4.0/gtk.css` `@define-color` route avoids this.)
- *vinceliuice installers automate it* (Graphite, Colloid): `./install.sh -l` (`--libadwaita`) does exactly that symlink. Pick the accent at install time with `-t <color>`, match Hyprland's rounding with `--round <2–16px>`, and use `--tweaks` for variants — Colloid's `--tweaks` even carry **named palettes** (`catppuccin|gruvbox|nord|everforest|dracula`), and `-l`'s default ColorScheme follows the system light/dark switch.
- *Flatpaks need extra grants* (catppuccin/gtk): `flatpak override --filesystem=$HOME/.local/share/themes` + `--env=GTK_THEME=<name>` to reach sandboxed apps (they honor `color-scheme` via the portal regardless).
- *murrine-dependent GTK themes can be un-`yay`-installable — build from SCSS instead* (Fausto-Korpsvart Everforest/Catppuccin, and most full GTK themes): their AUR package `depends=gtk-engine-murrine`, but on current Arch **`gtk2` + `gtk-engine-murrine` were dropped from the official repos** (GTK2 is EOL) and are AUR-only — and the AUR `gtk2` compiles GTK2 from source via a huge GNOME git clone that **reliably fails on HTTP/2** (`curl 92 … PROTOCOL_ERROR`), so the whole dependency layer rolls back. murrine is **GTK2-only** (it only themes legacy GTK2 apps you probably don't have), so skip the package: clone the theme repo and run its own `themes/build.sh` + `themes/install.sh -d ~/.local/share/themes -c dark -t <accent> -s standard --libadwaita`, which need **only `sassc`** (official repo). The repo's `icons/` dir holds a matching icon theme — copy it to `~/.local/share/icons/` for green/scheme-colored folders (the icon theme is separate from the GTK theme; that's why folders stay blue otherwise). If a git clone hits the HTTP/2 error, `git -c http.version=HTTP/1.1 clone …`.

**GTK settings under Wayland.**
- *Set gsettings at startup, every key* (JaKooLit `initial-boot.sh`): there's no XSettings daemon on wlroots, so push the full quartet from an `exec-once` — `gsettings set org.gnome.desktop.interface {color-scheme,gtk-theme,icon-theme,cursor-theme}` + `cursor-size`. A Dark/Light toggle just rewrites `color-scheme` + `gtk-theme` and caches the mode in a flag file.
- *Let `nwg-look` write both layers* (ml4w): nwg-look saves **gsettings** directly (the live channel) and *exports* `~/.config/gtk-3.0/settings.ini` (the legacy fallback) in one Apply — including `gtk-application-prefer-dark-theme=1`, the settings.ini mirror of `color-scheme prefer-dark`. ml4w wraps this in a "Refresh GTK" action to re-push after a theme change.

**Icons.**
- *Re-tint Papirus folders to the accent* (papirus-folders): `papirus-folders -C <accent> --theme Papirus-Dark` (31 colors incl. `nordic`, `cat-*`); run `papirus-folders -Ru` to **restore the accent after a package update** wipes it — a common "my folders went blue again" fix. The matugen/wallust recolor hook lives here.
- *Tela-circle bakes the accent at install* — `./install.sh <color>` then select `Tela-circle-dark` via `icon-theme`. Keep the qt5ct/qt6ct `icon_theme` **identical** to the GTK `icon-theme` for cross-toolkit parity (hyprdots ships `Tela-circle-dracula` in all three).

**Qt.**
- *One env.conf as the single toolkit source of truth* (Matt-FTW): GTK theme, both cursor systems, and Qt forced to Kvantum, all Catppuccin-Macchiato, in one file — `env = QT_STYLE_OVERRIDE,kvantum` forces Kvantum regardless of qt*ct, and `XCURSOR_*` + `HYPRCURSOR_*` are set to the **same** name+size.
- *Install both qt5ct and qt6ct* (JaKooLit, hyprdots): legacy Qt5 and modern Qt6 apps each need their platform theme; hyprdots sets `style=kvantum` + identical `icon_theme`/`[Fonts]` in **both** `qt5ct.conf` and `qt6ct.conf`, with `color_scheme_path` pointing at a generated `colors.conf`.
- *The two Qt routes* — **Kvantum** (`style=kvantum` in qt*ct, or `QT_STYLE_OVERRIDE=kvantum`; theme set with `kvantummanager --set <theme>`, which writes `theme=` into `~/.config/Kvantum/kvantum.kvconfig`; folder name must equal the `.kvconfig`/`.svg` name or it won't load) vs **KDE-native** (`QT_QPA_PLATFORMTHEME=kde` + a Kvantum/Breeze theme — end-4; or ml4w's `style=Breeze` + `breeze-dark` icons for a stock-KDE look without Kvantum).
- *QtQuick + XWayland scaling env* (JaKooLit): `env = QT_QUICK_CONTROLS_STYLE,org.hyprland.style` for native QtQuick controls, and `GDK_SCALE,1` / `QT_SCALE_FACTOR,1` to stop XWayland apps double-scaling.

**Cursor.**
- *Set both cursor systems + push at runtime* (end-4, Matt-FTW): `XCURSOR_THEME`/`XCURSOR_SIZE` (XWayland/GTK fallback) **and** `HYPRCURSOR_THEME`/`HYPRCURSOR_SIZE` (native) to the same theme+size, plus `hyprctl setcursor <theme> <size>` + `gsettings … cursor-theme` at runtime to cover the running session and GTK. Bibata-Modern-Ice/Classic and catppuccin-cursors are the common picks.

## Cursor coherence: the three-place rule

There's one cursor theme name, but **four** surfaces want to be told about it. Drift across them is the most common visual incoherence bug in a rice — the cursor "jumps" between sizes (different cache?), or flicks back to `Adwaita` over XWayland apps, or vanishes during an idle frame on NVIDIA. The companion-daemons component owns the single source-of-truth pick (`companion-daemons.cursor_theme` in `answers.json`), and the rice engine cross-sets it into every consumer at generate-time:

| Surface | Where it's set | What goes wrong without it |
|---|---|---|
| **Hyprland (native hyprcursor)** | `env = HYPRCURSOR_THEME,<name>` + `env = HYPRCURSOR_SIZE,<n>` in `env.conf`; runtime `hyprctl setcursor <name> <n>` | Hyprland falls back to the libwayland default — typically `Adwaita` 24, doesn't match GTK |
| **XWayland + GTK fallback** | `env = XCURSOR_THEME,<name>` + `env = XCURSOR_SIZE,<n>` in `env.conf` | XWayland apps (Steam, Discord-X11, Java AWT) show the wrong cursor over their window region |
| **GTK live channel** | `gsettings set org.gnome.desktop.interface cursor-theme '<name>'` + `cursor-size <n>` | Native GTK apps re-read at runtime — without this they keep the previous theme until the next session |
| **`settings.ini` mirror** | `gtk-cursor-theme-name=<name>` + `gtk-cursor-theme-size=<n>` in `~/.config/gtk-3.0/settings.ini` | The handful of GTK3 apps that don't poll gsettings (e.g. legacy GIMP 2.10 builds) miss the change |

`nwg-look` does the gsettings + settings.ini half automatically when you Apply; the `env =` half lives in `components/env/template.md` and is cross-set from `companion-daemons.cursor_theme` — you do **not** answer the cursor question again in the env interview. The Hyprcursor package family for the common themes is named `<theme>-hyprcursor` (e.g. `bibata-cursor-theme-bin` ships both X cursors and Hyprcursor metadata; `catppuccin-cursors` ships per-flavor `-hyprcursor` AUR packages). When the Hyprcursor variant isn't installed, Hyprland falls back to `XCURSOR_*` automatically — slightly blurrier on HiDPI but functional.

The vanishing-cursor-when-idle bug on **NVIDIA / nouveau** is *not* an env problem — it's the hardware-cursor plane blanking. Fix in `look-feel`: `cursor { no_hardware_cursors = true }`. See pitfalls below.

## Toolkit footguns the GTK/Qt doc should know about

These don't belong in this file's primary theming flow but they break the *look* of major toolkit-rendered apps on Hyprland and the env component cross-sets them by default. Each is documented in depth at `components/env/gotchas.md`.

- **`_JAVA_AWT_WM_NONREPARENTING,1`** — Java AWT apps (IntelliJ, Android Studio, older Swing tools) render as **blank gray windows** on tiling Wayland compositors until this is set. Long-standing JDK bug (`JDK-8211608` and family). Lives in the env's `toolkit` gate alongside `QT_QPA_PLATFORM`/`GDK_BACKEND` — single flip pulls in the bundle.
- **`MOZ_DISABLE_RDD_SANDBOX,1`** — Firefox VA-API through the `libva-nvidia-driver` (the NVDEC bridge) requires this because Firefox's RDD sandbox blocks the NVDEC ioctls. Only emit when `firefox_wayland=1` AND `have_libva_nvidia_driver=1`. JaKooLit and linuxmobile ship it commented in their env so users can flip it themselves.
- **`GSK_RENDERER,ngl`** — GTK4's default `gl` renderer crashes/glitches on the NVIDIA proprietary driver. The *next-gen* (`ngl`) Vulkan-aware renderer fixes it but is still experimental in GTK 4.16/4.18. JaKooLit surfaces it commented in their NVIDIA env block — flag in the validator as a hint when `NVIDIA_PROPRIETARY=1` AND the user reports GTK4 app crashes, do **not** auto-emit.
- **`ELECTRON_OZONE_PLATFORM_HINT,auto`** — fixes Electron/CEF flicker (Vesktop, VSCodium, Obsidian) on **any** GPU. Pre-v0.14 of this plugin gated it under NVIDIA; the Hyprland NVIDIA wiki explicitly recommends it as a generic fix — caelestia, dusky, and linuxmobile all set it unconditionally. The env interview now exposes it as its own line. Note: Electron 35 / Chromium 134+ use the syncobj protocol (`--enable-features=WaylandLinuxDrmSyncobj`) as the *proper* fix — that's an app-launch flag, not an env var.

## Default-app pick ↔ theming-engine pairing

The default-apps component's file-manager / image-viewer / archive-manager pick can silently undo the theming work — the GTK/Qt mismatch shows up *here* if a Qt file manager isn't given a Qt theming route, and the cursor/GTK setup spawns a desktop-search indexer if a GNOME pick is made:

- **Dolphin (Qt)** without Kvantum/qt6ct wired is **coherence-dead** — it renders in stock Fusion gray regardless of how perfectly GTK is themed. Picking Dolphin in `default-apps.file-manager` MUST pair with the Qt route: `QT_QPA_PLATFORMTHEME,qt6ct` (or `hyprqt6engine`) in env, `style=kvantum` in `qt6ct.conf`, and a Kvantum theme that matches the rice scheme in `kvantummanager`. Without the pairing, the Catppuccin/Gruvbox/Nord rice has a gray hole in it the moment the user opens a file picker.
- **Nautilus (GTK)** is themed by the libadwaita route this doc covers, *and* it autostarts the **`localsearch`** desktop-search indexer (formerly `tracker-miners`) on first launch — visible CPU + I/O for ~30s after login. Not a theming bug per se but the `companion-daemons` agent suppresses it by default (`systemctl --user mask localsearch-3.service localsearch-extract-3.service`) because rice users typically run `fzf`/`fd` from a terminal. Re-enable only on demand.
- **Loupe / Image Viewer / GNOME Files** — all libadwaita 1.4+ apps; honor the `sidebar_bg_color` / `sidebar_fg_color` pair the .tmpl now exports.

The rice interview pairs the file-manager pick with the matching toolkit route automatically — see `components/default-apps/interview.md`.

## hyprqt6engine — the Hyprland-native Qt6 route

[`hyprqt6engine`](https://wiki.hypr.land/Hypr-Ecosystem/hyprqt6engine/) is a Qt6 platform theme — a **replacement for qt6ct** built for Hyprland with KColorScheme compatibility. Set `env = QT_QPA_PLATFORMTHEME,hyprqt6engine` instead of `qt6ct` to get colour-scheme-aware Qt6 apps without the qt6ct GUI/config layer; config lives at `~/.config/hypr/hyprqt6engine.conf`. Use when the rice already has a KColorScheme rendered (DMS, end-4) and you want Qt6 apps to follow the same palette without round-tripping through qt6ct's `colors.conf`. Pairs cleanly with `QT_STYLE_OVERRIDE=kvantum` for SVG styling or alone for a flat KDE-Plasma-style look. qt5ct is still the right pick for legacy Qt5 apps.

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
(keys are hex *without* `#`; example shows Catppuccin Mocha values). The shape below is the
engine's `gtk4.tmpl` exactly — the contract row in `_shared/colors-contract.md` lists every
key, and the corpus (end-4, ml4w, DMS, dusky, binnewbs) ships the same superset. The
`headerbar_backdrop_color`, `dialog_*`, and `sidebar_*` pairs come from the DMS finding that
without them GTK4 windows **flash to stock Adwaita** when they lose focus.

```css
/* rice palette -> libadwaita named colors */
@define-color accent_color            #{{accent}};   /* cba6f7 */
@define-color accent_bg_color         #{{accent}};
@define-color accent_fg_color         #{{bg}};        /* 1e1e2e */
@define-color window_bg_color         #{{bg}};        /* 1e1e2e */
@define-color window_fg_color         #{{fg}};        /* cdd6f4 */
@define-color view_bg_color           #{{bg}};
@define-color view_fg_color           #{{fg}};
@define-color headerbar_bg_color      #{{surface}};   /* 313244 */
@define-color headerbar_fg_color      #{{fg}};
@define-color headerbar_backdrop_color #{{surface}};  /* prevent unfocus white-flash */
@define-color card_bg_color           #{{surface}};
@define-color card_fg_color           #{{fg}};
@define-color popover_bg_color        #{{surface}};
@define-color popover_fg_color        #{{fg}};
@define-color dialog_bg_color         #{{surface}};
@define-color dialog_fg_color         #{{fg}};
@define-color sidebar_bg_color        #{{bg}};        /* Nautilus / Files / Loupe */
@define-color sidebar_fg_color        #{{fg}};
@define-color destructive_color       #{{red}};
@define-color error_color             #{{red}};
@define-color success_color           #{{green}};
@define-color warning_color           #{{yellow}};
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
  run `hyprctl setcursor <theme> <size>` to fix it live. A cursor that **vanishes when it sits
  still** (not on movement) is a *different* bug: the **hardware-cursor plane on nouveau/NVIDIA**
  blanks when the screen is idle. Fix with `cursor { no_hardware_cursors = true }` in the Hyprland
  config (`hyprctl keyword cursor:no_hardware_cursors true` live) — software cursors keep it visible.
- **`GTK_THEME` env silently overrides your GTK theme.** If a session env exports `GTK_THEME=<name>`
  (the default with **uwsm** — it's in `~/.config/uwsm/env`, and many install scripts add it), GTK
  apps use that theme and **ignore gsettings / `settings.ini` / `gtk.css` entirely** — so a re-theme
  appears to "not take" on GTK apps. Find it (`env | grep GTK_THEME`, check `~/.config/uwsm/env`,
  `~/.config/environment.d/`, `~/.profile`), update it to the new theme, then live-propagate:
  `hyprctl keyword env GTK_THEME,<name>` + `dbus-update-activation-environment --systemd GTK_THEME=<name>`.
  Explicit `VAR=value` is the safe form (bare names re-read the calling shell's stale value);
  the Hyprland XDPH wiki gives the `--systemd --all` form as the catch-all and `--systemd
  QT_QPA_PLATFORMTHEME` (bare name) as a single-var form — end-4 and koeqaife both ship the
  bare-name form successfully under uwsm. All three work; explicit pairs are the safest.
  `hyprctl setenv` was the pre-0.55 spelling; modern Hyprland exposes only `hyprctl keyword env`
  — see `components/env/gotchas.md`. Apps pick it up on next launch. Likewise
  `XCURSOR_THEME`/`HYPRCURSOR_THEME` live in that env file. On Hyprland 0.55+ Lua,
  `hl.env("NAME", "value")` already pushes into systemd/DBus by default (the wiki notes
  `HYPRLAND_NO_SD_VARS=1` as the opt-out); the `envd =` form is only meaningful for 0.54-era
  `.conf` writers — Matt-FTW's `XDG_CURRENT_DESKTOP,Hyprland` as `envd =` is the canonical
  pattern there.
- **`~/.config/gtk-4.0/gtk.css` is sometimes a symlink** to a system theme (Catppuccin-GTK and other
  full-theme packages link the whole `gtk-4.0/` dir). Writing your own `@define-color` overrides
  through it fails with **"Permission denied"** (root-owned target under `/usr/share/themes`). Delete
  the symlink and write a real file (or, if you want the full theme, keep the symlink and skip the
  override). Same applies to `assets`/`gtk-dark.css` links.
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

## Pending: high-contrast / AAA accessibility branch

No corpus rice ships a high-contrast GTK/Qt variant — the accessibility component's research pass
confirmed this. libadwaita honors the **high-contrast color scheme** via the settings portal
(`org.gnome.desktop.a11y.interface high-contrast`), and the `AdwStyleManager:high-contrast`
property is read by every GTK4 app at runtime, but **no `@define-color` block currently runs in
a forced AAA-contrast branch in this rice's `gtk4.tmpl`** — the file emits a single palette
mapping that may or may not pass WCAG AAA (7:1) depending on the user's accent vs `bg`.

If/when a high-contrast scheme lands, the GTK4 template needs a second branch — `@media
(prefers-contrast: more)` is the libadwaita-supported form — that re-defines `accent_color`,
`accent_bg_color`, `window_fg_color`, etc. with values verified to pass AAA against
`window_bg_color`. The shape would be a conditional block inside the same `gtk.css` file rather
than a second file (libadwaita honors the media query). The contract row in
`_shared/colors-contract.md` would need a `_hc_*` mirror set, OR the engine would inject the
high-contrast block from a separate palette derivation. This is an orchestrator-level decision
— flagged for the accessibility component's batch.

## Sources

- Hyprland wiki — App Themes / cursors: <https://wiki.hypr.land/> · hyprcursor: <https://wiki.hypr.land/Hypr-Ecosystem/hyprcursor/>
- adw-gtk3: <https://github.com/lassekongo83/adw-gtk3> · adw-colors: <https://github.com/lassekongo83/adw-colors>
- libadwaita named colors / CSS variables: <https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/css-variables.html> (verified June 2026 — main 1.7+ adds `overview_*` + `active_toggle_*`; `sidebar_*` + `secondary_sidebar_*` since 1.4; `dialog_*` since 1.2; `popover_shade_color` + `thumbnail_*` since 1.3/1.4)
- hyprqt6engine (Qt6 platform theme, replacement for qt6ct, KColorScheme-compatible): <https://wiki.hypr.land/Hypr-Ecosystem/hyprqt6engine/>
- xdg-desktop-portal-hyprland (the `dbus-update-activation-environment --systemd --all` form the wiki recommends, plus the KDE-file-picker `~/.config/xdg-desktop-portal/hyprland-portals.conf` recipe): <https://wiki.hypr.land/Hypr-Ecosystem/xdg-desktop-portal-hyprland/>
- Catppuccin GTK (archived June 2024): <https://github.com/catppuccin/gtk>
- Catppuccin Papirus folders: <https://github.com/catppuccin/papirus-folders> · papirus-folders: <https://github.com/PapirusDevelopmentTeam/papirus-folders>
- Papirus icon theme: <https://github.com/PapirusDevelopmentTeam/papirus-icon-theme>
- Bibata hyprcursor: <https://github.com/PythonTryHard/Bibata-Cursor-hyprcursor>
- matugen GTK template: <https://github.com/InioX/matugen-themes>
- nwg-look: <https://github.com/nwg-piotr/nwg-look> · <https://nwg-piotr.github.io/nwg-shell/nwg-look.html>
- ArchWiki — Uniform look for Qt and GTK applications: <https://wiki.archlinux.org/title/Uniform_look_for_Qt_and_GTK_applications>
- HyDE application theming: <https://deepwiki.com/JaKooLit/Hyprland-Dots/4.4-application-theming> · hyprqt6engine: <https://wiki.hypr.land/Hypr-Ecosystem/hyprqt6engine/>
- Flatpak desktop integration / theme access: <https://docs.flatpak.org/en/latest/desktop-integration.html>

**Config corpus read for the techniques catalog:**
- catppuccin/gtk `docs/USAGE.md` (libadwaita symlink + Flatpak override) and catppuccin/Kvantum README (`kvantummanager --set`, folder==name rule): <https://github.com/catppuccin/gtk> · <https://github.com/catppuccin/Kvantum>
- vinceliuice Graphite-/Colloid-gtk-theme `install.sh` (`-l/--libadwaita`, `-t` accent, `--round`, `--tweaks` named palettes): <https://github.com/vinceliuice/Graphite-gtk-theme> · <https://github.com/vinceliuice/Colloid-gtk-theme>
- JaKooLit/Hyprland-Dots `initial-boot.sh` + `DarkLight.sh` + `configs/ENVariables.conf` (gsettings quartet, dual qt5ct/qt6ct, QtQuick + scale env): <https://github.com/JaKooLit/Hyprland-Dots>
- prasanthrangan/hyprdots `Configs/.config/qt5ct,qt6ct/*.conf` (style=kvantum + Tela-circle + Cantarell/Nerd-mono fonts): <https://github.com/prasanthrangan/hyprdots>
- Matt-FTW/dotfiles `.config/hypr/configs/env.conf` (single env source of truth, QT_STYLE_OVERRIDE=kvantum, matched XCURSOR/HYPRCURSOR): <https://github.com/Matt-FTW/dotfiles>
- end-4/dots-hyprland (KDE platform theme route, in-repo Kvantum themes, runtime `hyprctl setcursor`) and mylinuxforwork/dotfiles (nwg-look workflow, Breeze qt6ct): <https://github.com/end-4/dots-hyprland> · <https://github.com/mylinuxforwork/dotfiles>
- papirus-folders (`-C <accent>`, `-Ru` after update) and vinceliuice Tela-circle-icon-theme: <https://github.com/PapirusDevelopmentTeam/papirus-folders> · <https://github.com/vinceliuice/Tela-circle-icon-theme>
- matugen `gtk-colors.css` templates (for the libadwaita named-color superset audit — `popover_fg_color`, `card_fg_color`, `sidebar_*`, `headerbar_backdrop_color`, `error_*`): end-4 `dots/.config/matugen/templates/gtk-4.0/gtk.css`, ml4w `dotfiles/.config/matugen/templates/gtk-colors.css`, AvengeMedia/DankMaterialShell `quickshell/matugen/templates/gtk-colors.css` (annotates `headerbar_backdrop_color` as "prevents white flash on window unfocus"), dusklinux/dusky and binnewbs/arch-hyprland `.config/matugen/templates/gtk-colors.css` (ml4w-derived).

# Sources - skills/rice/references/components/widgets/styling.md

Research provenance for `skills/rice/references/components/widgets/styling.md`.

Extracted from the load path: these citations are why the recommendations in that
file are what they are, and are read by a human reviewing them - never by an agent
authoring a config.

### Sources

- Hyprland Wiki — Status Bars (the framework comparison): https://wiki.hypr.land/Useful-Utilities/Status-Bars/
- GitHub topics (the live indexes): https://github.com/topics/hyprland · https://github.com/topics/quickshell
- eww: https://github.com/elkowar/eww · docs https://elkowar.github.io/eww/
- AGS / Astal: https://github.com/Aylur/ags · https://github.com/Aylur/astal
- Quickshell: https://quickshell.org/ · mirror https://github.com/quickshell-mirror/quickshell
- HyprPanel (archived): https://github.com/Jas-SinghFSU/HyprPanel · docs https://hyprpanel.com/
- nwg-shell: https://github.com/nwg-piotr/nwg-shell · https://github.com/nwg-piotr/nwg-panel
- fabric (+ Ax-Shell archived): https://github.com/Fabric-Development/fabric · https://github.com/Axenide/Ax-Shell
- High-momentum QML rices: https://github.com/end-4/dots-hyprland · https://github.com/caelestia-dots/shell · https://github.com/noctalia-dev/noctalia-shell · https://github.com/AvengeMedia/DankMaterialShell
- matugen (the common Material You theming bridge): https://github.com/InioX/matugen

**Canonical widget rices** (verified mid-2026; star counts drift):

| Repo | ★ | Toolkit | Distinctive trait |
|---|---:|---|---|
| end-4/dots-hyprland | ~14.7k | Quickshell (ex-AGS) | The Material You reference; AI sidebar, overview w/ live previews. Drove the AGS→QS wave. |
| caelestia-dots/shell | ~9.8k | Quickshell | "No waybar here" — full QML shell; C++ beat-detector visualizer. |
| HyDE-Project/HyDE | ~9.2k | waybar + custom | Turnkey; **wallbash** recolors the whole UI per wallpaper. Successor to hyprdots. |
| noctalia-dev/noctalia-shell | ~7.3k | Quickshell | "Quiet by design"; plugin ecosystem; multi-compositor. |
| AvengeMedia/DankMaterialShell | ~6.6k | Quickshell + Go | Replaces waybar+swaylock+mako+fuzzel in one shell; greetd greeter. |
| JaKooLit/Hyprland-Dots | ~3.4k | waybar (+some AGS/QML) | Turnkey; **wallust** wallpaper theming; multi-distro installers. |
| Aylur/dotfiles | ~3.1k | AGS / Astal | The AGS author's own "Marble Shell" — reference AGS implementation. |
| mylinuxforwork/dotfiles (ML4W) | ~4.8k | waybar (+eww) | GUI installer app; adaptive Material color from wallpaper. |
| Jas-SinghFSU/HyprPanel | ~2.2k | Astal/AGS v2 | GUI-configured turnkey panel; `.json` theme import. **Archived → Wayle.** |
| Axenide/Ax-Shell | ~1.6k | fabric (Python) | Widest widget roster (kanban, OCR, calculator…). **Archived → Ambxst.** |
| koeqaife/hyprland-material-you | ~1.5k | GTK4 custom | Fluid Material 3 animations; settings-driven; custom greeter. |
| sejjy/mechabar | ~0.8k | waybar | "Mecha" modular waybar; Catppuccin variants as swappable CSS. |
| adi1090x/widgets | ~0.8k | eww | The classic eww widget pack (dashboard/music/weather). |

*Flags:* gh0stzk/dotfiles (~4.6k, an influential **eww** reference) is **BSPWM, not Hyprland**; prasanthrangan/hyprdots, HyprPanel, and Ax-Shell are **deprecated/archived** — cite their successors (HyDE, Wayle, Ambxst) for "alive" status.

---

### Sources (eww)

- eww configuration docs (yuck, defwindow geometry/stacking/namespace, defvar/defpoll/deflisten, daemon/open): https://elkowar.github.io/eww/configuration.html
- eww widget reference (box, scale, circular-progress, graph, revealer transitions, eventbox `:hover`, overlay, literal): https://elkowar.github.io/eww/widgets.html
- eww landing / overview (GTK CSS subset, SCSS): https://elkowar.github.io/eww/
- Hyprland — blur a layer surface / per-element blur limitation (eww is one surface): https://github.com/hyprwm/Hyprland/discussions/748
- Hyprland Status Bars wiki (widget systems incl. eww): https://wiki.hypr.land/Useful-Utilities/Status-Bars/
- FieldofClay/hyprland-workspaces (deflisten + `for` + class output for active/occupied/empty): https://github.com/FieldofClay/hyprland-workspaces

**Community-config corpus** — read for the techniques above; grouped by what they best demonstrate:

- **adi1090x/widgets** — *the* eww widget gallery. Dashboards, music, system gauges; `.genwin` card class, `border-radius:16px`/`100%`, scale `trough/highlight` bars, big-glyph buttons, cron weather script. The most-copied eww layouts. https://github.com/adi1090x/widgets
- **gh0stzk/dotfiles** (~4.6k★, BSPWM but eww is portable) — profile card, music player, calendar, cheatsheet widgets that re-skin on theme switch *without restarting eww*; the canonical theme-selector + eww integration. https://github.com/gh0stzk/dotfiles
- **dharmx (eww-powermenu)** — power-menu archetype; SCSS `$variables`, nested `:hover` transitions, fullscreen overlay window. https://dharmx.is-a.dev/eww-powermenu/
- **dwt1/dotfiles** (`.config/eww/bar/`) — a straightforward horizontal eww bar with `scale`-based CPU/mem bars (`trough/highlight`); a clean starting point. https://gitlab.com/dwt1/dotfiles
- **husseinhareb/hyprland-eww**, **Vagahbond/eww-dotfiles** — additional Hyprland+eww widget sets to mine. https://github.com/husseinhareb/hyprland-eww · https://github.com/Vagahbond/eww-dotfiles

**Flagged / could not fully verify.**
- **end-4/dots-hyprland** is sometimes associated with eww in *older* references but migrated to AGS, then Quickshell — it is *not* an eww config today; don't cite it for eww `.scss` technique (see `## Quickshell` below).
- The `circular-progress` detail (font-size → inner radius; `color` → ring) is synthesized from the widget docs (`:thickness`, the color-property convention) plus community usage — worth a quick confirm against a live config.
- Star counts read on the research date drift over time.

---

### Sources (AGS / Astal)

- AGS CLI (Astal+Gnim scaffolder): https://github.com/Aylur/ags and docs https://aylur.github.io/ags/
- Astal libraries (Hyprland, Notifd, Mpris, Battery, WirePlumber, Bluetooth, Network, Tray, Apps, Brightness, PowerProfiles, Cava, Greet, River): https://github.com/Aylur/astal and https://aylur.github.io/astal/
- AGS v1→v2/v3 migration guide (Service removal, `app.start`, `createState`, **`className → class`**): https://aylur.github.io/ags/guide/migration-guide.html
- AGS v1 theming API (`App.config({style})`, `App.applyCss`/`resetCss`, inline `css`, `sassc`, `Utils.monitorFile`): https://aylur.github.io/ags-docs/config/theming/
- AGS v2.0.0 release notes (initial rewrite — Vala/C Astal core, dart-sass, GTK4 import path): https://github.com/Aylur/ags/releases/tag/v2.0.0
- AGS v3 release notes (Gnim JSX runtime replaces `astalify`; `Accessor`, lifecycle hooks): https://github.com/Aylur/ags/releases (current line v3.1.x, mid-2026)
- matugen (Material You / base16 color generation, SCSS + `@define-color` templates): https://github.com/InioX/matugen
- GTK3 CSS overview (the styleable subset): https://docs.gtk.org/gtk3/css-overview.html · GTK4 `Gtk.Overlay` (blurred-art layering): https://docs.gtk.org/gtk4/class.Overlay.html

**Community config corpus** — AGS/Astal shells worth reading, grouped by what they best demonstrate (state verified June 2026):

- *Aylur/dotfiles* (~3.1k★, Nix/Lua, current) — the author's own configs; reference implementation for the bar/dashboard/notification archetypes. https://github.com/Aylur/dotfiles
- *Neurarian/matshell* (~70★, TS, GTK4 Astal, actively maintained) — **the cleanest current reference**: 7-1 SCSS, mixin library (elevation/cards/toggles/sliders), matugen Material You template, blurred-cover music player with CAVA, control-center, OSD, launcher. https://github.com/Neurarian/matshell
- *kotontrion/dotfiles* (~180★, JS, AGS v1; author moved newer work to Astal) — advanced custom GObject widgets; the **GTK4 CAVA Catmull-Rom spline** visualizer reused across the ecosystem. https://github.com/kotontrion/dotfiles
- *Jas-SinghFSU/HyprPanel* (~2.2k★, TS/SCSS, Astal, **archived Apr 2026 → Wayle**) — the GUI-configured, JSON-themed bar/dashboard; demonstrates the "no hand-SCSS" theming model. https://github.com/Jas-SinghFSU/HyprPanel · migration note https://hyprpanel.com/getting_started/astal.html
- *tokyob0t/dotfiles* (`astal-hyprland` branch, ~100★, **Lua**) — Astal driven from Lua rather than TS; proof the styling/widget model is language-agnostic. https://github.com/tokyob0t/dotfiles/tree/astal-hyprland
- *matt1432/nixos-configs* (`modules/ags/astal`, Nix+Astal) — Astal packaged the NixOS/home-manager way. https://git.nelim.org/matt1432/nixos-configs
- *end-4/dots-hyprland* `ii-ags` branch (~14.7k★ overall, **AGS version deprecated**) — the famous illogical-impulse Material You rice *as it was* under AGS (bar, sidebars/dashboard, overview, OSD, cheatsheet, blurred-art media). The `main` branch is now **Quickshell**, not AGS. https://github.com/end-4/dots-hyprland/tree/ii-ags

**Flagged / unverified.**
- **Soramane** is associated with **caelestia** (`soramanew/caelestia*`), which is **Quickshell-based, not AGS/Astal** — out of scope for this section; included only to correct the attribution.
- The GTK4 slider sub-node names (`trough`/`block`/`filled`) are confirmed from matshell's SCSS; GTK3's (`trough`/`highlight`/`slider`) from the Waybar/AGS-v1 era. Confirm the exact node for *your* toolkit version with the GTK Inspector (`GTK_DEBUG=interactive ags run`).
- Blur on the album-art layer: matshell sets the art via `background-image` + low opacity; the actual Gaussian blur is applied in-widget (GTK4 effect / pre-blurred image), not via a plain CSS `filter: blur()` (GTK3 has no `filter`). Verify the mechanism against the toolkit you target.

---

### Sources (Quickshell)

- Quickshell homepage (what it is, QtQuick, hot-reload, integrations): https://quickshell.org/
- Quickshell docs — types index, `PanelWindow`, `WlrLayershell` (namespace/layer/exclusionMode/keyboardFocus): https://quickshell.org/docs/v0.2.0/types/Quickshell.Wayland/WlrLayershell/ and https://quickshell.org/docs/v0.1.0/types/Quickshell/PanelWindow/
- Quickshell FAQ (rounded windows = transparent + rounded Rect, RectangularShadow vs MultiEffect, Loader/LazyLoader, transparency/border bugs): https://quickshell.org/docs/v0.2.0/guide/faq/
- "Build Your Own Bar" tutorial (PanelWindow, RowLayout, root-property theming, `qs -p`, MouseArea, Process/Timer): https://www.tonybtw.com/tutorial/quickshell/
- Qt `RectangularShadow`: https://doc.qt.io/qt-6/qml-qtquick-effects-rectangularshadow.html
- Qt `MultiEffect` (blur/shadow/colorize, perf notes): https://doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html
- Qt `Behavior` (implicit property animation): https://doc.qt.io/qt-6/qml-qtquick-behavior.html
- matugen + `matugen-themes` (Material You generation, JSON/SCSS targets, quickshell template): https://github.com/InioX/matugen and https://github.com/InioX/matugen-themes
- snowarch/quickshell-ii-niri theming deepwiki (Colors singleton, JsonAdapter, FileView, m3colors, matugen pipeline): https://deepwiki.com/snowarch/quickshell-ii-niri/8.1-matugen-and-color-generation
- end-4 Hyprland↔Quickshell integration (qs IPC, GlobalShortcut via `dispatcher, global`, exclusion modes): https://deepwiki.com/end-4/dots-hyprland/4.4-hyprland-quickshell-integration
- Hyprland layer rules for quickshell namespaces (`match:namespace quickshell:*`, blur/ignore_alpha): https://github.com/tripathiji1312/quickshell/blob/main/hyprland-layer-config.conf and https://github.com/hyprwm/Hyprland/discussions/12798

**Canonical / corpus repos** (verified live, June 2026):

- *end-4/dots-hyprland* — "illogical-impulse"; **~14.7k stars**, 76.7% QML; migrated AGS→Quickshell; Material 3 via matugen, bar + sidebars + dashboard + overview (live previews) + AI widgets. The reference implementation. https://github.com/end-4/dots-hyprland
- *caelestia-dots/shell* — "‼️ No waybar here ‼️"; **~9.8k stars**, 74% QML + 19% C++ (beat-detector visualizer); bar/dashboard/launcher/notifications/OSD/sidebar/lockscreen, Colors singleton, wallpaper-adaptive M3, `caelestia shell -d` / `qs -c caelestia`. https://github.com/caelestia-dots/shell (configs: https://github.com/caelestia-dots/caelestia)
- *noctalia-dev/noctalia-shell* — "quiet by design"; minimal Wayland shell (bar/panels/notifications/dock/widgets), Hyprland+Niri+Sway+others, warm-lavender default, heavy `Behavior` animation. https://github.com/noctalia-dev/noctalia-shell
- *AvengeMedia/DankMaterialShell* — Quickshell + Go backend; replaces waybar/swaylock/swayidle/mako/fuzzel; Material theming, control center, dock, lock screen, greetd greeter; `dms run`. https://github.com/AvengeMedia/DankMaterialShell
- *quickshell-mirror/quickshell* (GitHub mirror of `git.outfoxxed.me/quickshell/quickshell`) — the toolkit + examples. https://github.com/quickshell-mirror/quickshell
- *Smaller configs worth reading*: `tripathiji1312/quickshell` (modular, ships a `hyprland-layer-config.conf`), `doannc2212/quickshell-config` (bar/launcher/notify/OSD/wallpaper + 206-theme switcher), `Shanu-Kumawat/quickshell-overview` (standalone overview w/ live previews + Super+Tab), `rdnamil/rdnashell` (waybar-inspired minimal), `josecriane/quickshell-config` (Nix flake), `bgibson72/yahr-quickshell` (glassmorphism). The GitHub `quickshell` topic is the live index: https://github.com/topics/quickshell

**Unverified / flagged:** exact star counts are from page snapshots and drift. The matugen output path and JSON shape vary per config (`~/.local/state/quickshell/...` vs `~/.config/...`); confirm against the specific config's `Colors.qml`/`config.toml`. The `Colors.qml`/`FileView`/`JsonAdapter` snippet above is a representative composite of the snowarch/end-4 pattern, not a verbatim copy — verify API names (`Singleton`, `JsonAdapter`, `FileView.watchChanges`) against the installed Quickshell version's docs, as the type API is still pre-1.0 and changes between releases.

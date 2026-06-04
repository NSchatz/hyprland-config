# Styling Quickshell

Quickshell (by **outfoxxed**, `quickshell.org`, repo at `git.outfoxxed.me/quickshell/quickshell`, GitHub mirror `quickshell-mirror/quickshell`) is a QtQuick/QML toolkit for building Wayland desktop shells — bars, dashboards, notification centers, OSDs, launchers, lock screens, wallpaper daemons. It is the modern successor many Hyprland ricers are migrating to from **AGS** (the JS/GJS framework): `end-4/dots-hyprland` (illogical-impulse) rewrote its whole shell from AGS to Quickshell, and the 2026 ricing scene has largely shifted onto it (`caelestia`, `Noctalia`, `DankMaterialShell`, dozens of personal configs). This page is about making a Quickshell shell *look* good — but the styling model is fundamentally different from waybar/eww/AGS, so read the next section first.

## What you're styling — QML, not a CSS stylesheet

This is the crucial difference and the thing that trips up everyone coming from waybar. **There is no stylesheet.** Waybar splits layout (`config.jsonc`) from appearance (`style.css`, a GTK-CSS subset). Quickshell has neither. You write `.qml` files that *are* the UI — a declarative tree of objects — and "styling" means **setting properties on those objects**. Color, shape, shadow, blur, and animation are all just properties (or child objects) on the same elements that define the widget, in the same file.

```qml
// A rounded translucent pill — this IS the widget AND its style.
Rectangle {
    implicitWidth: 120
    implicitHeight: 32
    radius: 16                      // rounded corners  (CSS border-radius)
    color: Qt.rgba(0.12, 0.12, 0.18, 0.85)   // translucent bg (CSS rgba)
    border.width: 1
    border.color: Qt.alpha(Theme.accent, 0.45)
    Text {
        anchors.centerIn: parent
        text: "12:30"
        color: Theme.fg
        font.family: Theme.fontUi
        font.pixelSize: 14
    }
}
```

Mental-model translation for people coming from CSS:

| CSS / waybar concept | QML equivalent |
|---|---|
| `border-radius: 16px` | `radius: 16` on a `Rectangle` |
| `background: rgba(...)` | `color: Qt.rgba(r,g,b,a)` (0–1 floats) or `"#aarrggbb"` |
| `border: 1px solid` | `border.width: 1; border.color: …` |
| `padding` / `margin` | `anchors.margins`, `Layout.margins`, or explicit `x/y/width` |
| flex row/column | `RowLayout` / `ColumnLayout` (from `QtQuick.Layouts`) |
| `box-shadow` | a `RectangularShadow` or `MultiEffect` child object |
| `transition` | a `Behavior on <prop> { NumberAnimation { … } }` block |
| `@keyframes` | `SequentialAnimation` / `NumberAnimation` with `loops` |
| `:hover` | `MouseArea { hoverEnabled: true }` + bind to `containsMouse` |
| `backdrop-filter: blur` | **not in QML** — done by Hyprland via a `layerrule` on the window's layer namespace (see below) |
| a shared palette (`@define-color`) | a **QML singleton** (`Theme.qml` / `Colors.qml`) with `property color …` |

Two consequences: (1) you get the entire Qt animation/effects engine — real eased motion, shaders, particle effects, per-pixel opacity — which is *far* beyond GTK CSS; (2) there's no separation of concerns handed to you, so disciplined configs build their own: a `Theme`/`Appearance` singleton for the palette, reusable component files (`StyledRect.qml`, `StyledText.qml`) for consistent defaults, and `services/` for data. Quickshell hot-reloads on save — "loads changes as soon as they're saved" — so iteration is as fast as waybar's `SIGUSR2`, with no reload command to run.

## How it's launched on Hyprland

The binary is `quickshell`, aliased `qs`. A config is a directory of `.qml` files with a `shell.qml` entry point.

- **Config location:** `~/.config/quickshell/<name>/shell.qml`. Run a named config with `qs -c <name>`, or point at an explicit file with `qs -p ~/.config/quickshell/foo/shell.qml`.
- **Autostart:** in `hyprland.conf`, `exec-once = qs -c caelestia` (or whatever the project ships — `caelestia shell -d`, `dms run` for DankMaterialShell, `noctalia-shell`).
- **Entry point:** `shell.qml`'s root is typically a `ShellRoot` containing one or more windows. Multi-monitor is handled with `Variants` over `Quickshell.screens`, instantiating one window per monitor.
- **Windows are layer-shell surfaces.** Use `PanelWindow` (from `Quickshell`) as a bar/panel root — it docks to a screen edge via `anchors { top: true; left: true; right: true }`, sizes with `implicitHeight`, and reserves space (exclusive zone) so tiled windows don't overlap. Under Wayland it's backed by `WlrLayershell`, exposed as an attached property: `WlrLayershell.layer: WlrLayer.Top` (also `Background`/`Bottom`/`Overlay`), `WlrLayershell.namespace: "quickshell:bar"`, `WlrLayershell.keyboardFocus`, and `exclusionMode`/`exclusiveZone` (set `ExclusionMode.Ignore` / `exclusiveZone: 0` for overlays like an OSD or launcher that should float over windows, not push them).

**Blur is the compositor's job, not QML's.** A translucent `PanelWindow` over a busy wallpaper looks muddy unless Hyprland blurs what's behind it. Quickshell sets a layer **namespace** (convention `quickshell:<moduleName>`), and you match it with a Hyprland `layerrule`. On Hyprland 0.54.x use the block form (the single-line `layerrule = blur, …` is rejected — see `../window-rules.md` and the waybar page):

```conf
layerrule {
    name = blur-quickshell
    match:namespace = quickshell:bar
    blur = true
    ignore_alpha = 0.79   # don't blur the near-transparent gaps; per-module value
}
```

Confirm the namespace with `hyprctl layers`. Projects often swap the namespace to toggle effects: end-4's overview uses `quickshell:overview-blur` so a dedicated layerrule blurs only that surface; matching `match:namespace = quickshell:*` with `blur = true` covers every Quickshell window at once. Set the window itself transparent (`PanelWindow { color: "transparent" }`) and put a rounded `Rectangle` inside — see Pitfalls for the transparency gotcha.

## Widget archetypes

Quickshell's pitch is that one shell owns *everything* — "no waybar here" (caelestia's tagline) — so the same palette singleton and animation language flow through every surface. The common archetypes, all seen across `caelestia`, `end-4`, `Noctalia`, `DankMaterialShell`:

- **Bar / status panel** — `PanelWindow` anchored top (or left for vertical), `RowLayout`/`ColumnLayout` of modules: workspaces (driven by `Quickshell.Hyprland` IPC), active-window title, clock, system tray (`Quickshell.Services.SystemTray`), audio/network/battery, a notification bell.
- **Dashboard / sidebar / control center** — a large `PanelWindow` overlay (often `ExclusionMode.Ignore`) with media player, calendar, performance graphs, weather, quick toggles. caelestia's bar+dashboard+notifications are "all part of the same brain."
- **Notification center** — `Quickshell.Services.Notifications` feeds a stack of cards; expandable, with action buttons.
- **OSD** — transient brightness/volume/mic overlay that fades in on change and auto-hides on a `Timer`.
- **Launcher** — fuzzy app/action search (`DesktopEntries`), a `TextField` + filtered `ListView`.
- **Lock screen** — Quickshell can be the locker via `Quickshell.Wayland.SessionLock` (caelestia supports fingerprint auth) — a genuine advantage over waybar, which can't lock.
- **Wallpaper / background** — a `WlrLayer.Background` `PanelWindow` drawing the wallpaper (sometimes animated/shader-driven).
- **Overview** — workspace grid with **live window previews** (end-4, `Shanu-Kumawat/quickshell-overview`), drag-and-drop, bound to `Super+Tab`.
- **Greeter / display manager** — DankMaterialShell ships a `greetd` integration.

Strengths to lean into (the reason people migrate here): rich eased animations, true GPU layering/blur, ShaderEffect glow/visualizers (caelestia has a C++ beat-detector driving an audio visualizer), and clean per-monitor instancing via `Variants`.

## Styling techniques in QML (attributed)

Concrete, reusable moves harvested from the canonical configs. Swap literal colors for `Theme.*` singleton properties (next section). Grouped by what they buy you.

**Shape & surface.**
- *Rounded panel = transparent window + rounded Rectangle* (Quickshell FAQ, every config): a layer-shell window can't itself be rounded, so `PanelWindow { color: "transparent" }` with an inner `Rectangle { radius: … ; color: surface }` is *the* idiom. Pill = `radius: height/2`.
- *Reusable styled primitives* (caelestia `components/`, end-4): wrap `Rectangle`/`Text` in `StyledRect.qml` / `StyledText.qml` that preset `radius`, `color: Theme.surface`, `font.family: Theme.fontUi`, antialiasing — every widget composes these instead of re-specifying defaults. This is QML's answer to a shared stylesheet.
- *Clip for hard rounded masks* (general QML): `Rectangle { radius: r; clip: true }` clips children (e.g. album art, previews) to the rounded shape; `layer.enabled: true` makes the clip antialias cleanly.

**Color & transparency.**
- *Translucent surfaces* (`Noctalia`, caelestia): `color: Qt.rgba(0.1,0.1,0.14,0.85)` or, palette-driven, `Qt.alpha(Theme.surface, 0.85)`. `Qt.alpha(c, a)` / `Qt.darker(c, f)` / `Qt.lighter(c, f)` are QML's `alpha()`/`shade()` equivalents — build a whole tonal hierarchy from one accent.
- *Gradients* (`MBestKing`-style brand fills, splashes): a `gradient: Gradient { GradientStop { position: 0; color: Theme.accent } GradientStop { position: 1; color: Theme.accent2 } }` on a `Rectangle` — diagonal/animated stops for a brand bar or progress fill.
- *Per-module accent hues* (same discipline as waybar): network = blue, battery = green, etc., each read off `Theme.blue`/`Theme.green` so a re-theme carries them.

**Depth & glow.**
- *Drop shadow, rectangular* (Quickshell FAQ, caelestia): `RectangularShadow { anchors.fill: rect; radius: rect.radius; blur: 24; color: Qt.rgba(0,0,0,0.45) }` behind a rounded `Rectangle` — the cheap, GPU-fast elevation shadow (Qt recommends it over MultiEffect for rect/rounded/circular shapes).
- *Shadow/glow on arbitrary shapes* (Qt `MultiEffect`): for non-rectangular items, `MultiEffect { source: item; shadowEnabled: true; shadowBlur: 1.0; shadowColor: … }` — can also do `blurEnabled`, colorization, brightness in one pass. Heavier; prefer raising `blurMultiplier` over `blurMax`, and don't feed it an animating source.
- *Inner-glow / frosted depth*: stack a low-alpha bg + a 1px light border (`border.color: Qt.rgba(1,1,1,0.08)`) + a `RectangularShadow` — the QML glassmorphism stack (mirrors waybar's zen0x00 recipe), and it actually frosts only once the Hyprland blur layerrule is on.

**Motion (Quickshell's headline advantage).**
- *Implicit transitions via `Behavior`* (caelestia, end-4, Noctalia — pervasive): attach an animation to any property so it eases whenever the value changes — no keyframes, no state machine.
  ```qml
  Rectangle {
      color: hovered ? Theme.accent : Theme.surface
      Behavior on color  { ColorAnimation  { duration: 150 } }
      Behavior on width  { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
  }
  ```
  This single pattern is responsible for most of the "fluid, mobile-OS feel" people praise in these shells.
- *Shared easing/duration constants* (caelestia `Appearance`/`Anim` singleton): hoist `duration` and `easing.type`/`easing.bezierCurve` into the theme singleton so every `Behavior` animates with one identity (e.g. a Material `Easing.OutCubic` at 200ms, or a custom `easing.bezierCurve` for an iOS-y overshoot).
- *Keyframed / looping* (`@keyframes` equivalent): `SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { to: 0.4; duration: 1200 } NumberAnimation { to: 1; duration: 1200 } }` for a pulsing urgent/now-playing indicator. `NumberAnimation` with `easing.type: Easing.OutBack` gives the springy overshoot.
- *Enter/exit transitions*: `PropertyAnimation` on `opacity`/`y` driven by a `states` change, so an OSD or launcher slides+fades in rather than popping.

**Performance discipline.**
- *Lazy instantiation* (Quickshell FAQ, every serious config): wrap costly surfaces in `Loader` (Item-based) / `LazyLoader` so a dashboard or launcher is only built when shown — the main lever for keeping memory down.

## Theming flow — the Colors singleton + matugen

The palette lives in a **QML singleton**, the direct analog of waybar's `@define-color` block, and the single most important structural choice. Every widget references `Theme.accent` / `Colors.md3.primary` instead of a literal, so a re-theme is one file changing and the bindings repaint live.

A minimal hand-written singleton (`Theme.qml`, registered `singleton Theme` in a `qmldir`, or `pragma Singleton`):

```qml
pragma Singleton
import QtQuick
QtObject {
    readonly property color bg:      "#1e1e2e"
    readonly property color fg:      "#cdd6f4"
    readonly property color surface: "#313244"
    readonly property color accent:  "#cba6f7"
    readonly property color accent2: "#89b4fa"
    readonly property string fontUi:   "Inter"
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property int    radius:   16
    readonly property int    animDuration: 200
}
```

**Generated palettes (the popular path): matugen → JSON → singleton.** matugen (`InioX/matugen`, with `InioX/matugen-themes`) extracts Material You colors from the wallpaper and writes a `colors.json` (Material 3 roles, tonal palette, base16) into e.g. `~/.local/state/quickshell/.../generated/colors.json`. A `Colors.qml` singleton reads it via `JsonAdapter` over a `FileView` and exposes it; because `FileView` watches the file, a wallpaper change repaints the entire shell with no restart:

```qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id: root
    property alias md3:     adapter.md3
    property alias base16:  adapter.base16
    property alias palette: adapter.palette
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/generated/colors.json"
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter { id: adapter
            property var md3; property var base16; property var palette
        }
    }
}
// usage:  color: Colors.md3.surface   /   color: Colors.md3.primary
```

This is how `end-4/dots-hyprland` (Material 3 — "choose your wallpaper, done, enjoy material themes"), `caelestia` (wallpaper-adaptive, light/dark, per-monitor overrides), `snowarch/quickshell-ii-niri`, and `DankMaterialShell` all theme. caelestia layers a `shell.json` of base tokens multiplied by an appearance scale on top. For this plugin's rice engine, the cleanest contract is to emit a flat `colors.json` (or render `Theme.qml` directly) with the palette keys below; either way the shell consumes it through the singleton.

**Palette contract** (rice keys → singleton properties; map Material roles when the config is M3-native): `bg fg surface muted cursor accent accent2 red green yellow blue magenta cyan color0..color15`, plus `font_ui` → `Theme.fontUi`, `font_mono` → `Theme.fontMono`. Material-3 configs map roughly `bg→background/surface`, `fg→onSurface`, `accent→primary`, `accent2→secondary/tertiary`, `surface→surfaceContainer`.

## Pitfalls

- **You must know QML/JS, not CSS.** This is the steepest curve of any Hyprland shell. Layouts, property bindings, signals, `Behavior`/animation types, and Qt's effects are a real toolkit, not a stylesheet. There is no `style.css` to copy-paste into.
- **Heavy dependencies.** Pulls in Qt 6 (QtQuick, Qt Quick Effects/Shapes, often QtMultimedia/PipeWire). Build from source or AUR; effects like `MultiEffect`/`RectangularShadow` need the Qt Quick Effects module installed or they silently fail to load.
- **Blur is not a QML property.** No `backdrop-filter`. Translucency only frosts via a Hyprland `layerrule` on the window's layer namespace — forget it and you get a muddy panel (same failure mode as waybar without the blur rule).
- **Transparent-window gotchas.** A layer-shell window can't be rounded — round an inner `Rectangle` over a `color: "transparent"` window. Toggling a window between opaque and transparent at runtime can break GPU rendering unless you set `surfaceFormat`/`opaque: false` up front. And a Qt bug (QTBUG-137166) makes a transparent `Rectangle` *with a border* render invisible — add `border.width: 0` or set border props explicitly as the workaround.
- **No shared stylesheet unless you build one.** Without a `Theme` singleton + reusable styled components, color/font/radius defaults scatter across every file and a re-theme becomes a find-and-replace. Build the singleton first.
- **Exclusive zone vs. overlays.** A bar should reserve space (default exclusive zone); an OSD/launcher/dashboard should *not* — set `WlrLayershell.exclusionMode: ExclusionMode.Ignore` (or `exclusiveZone: 0`) or it shoves your tiled windows around.
- **Don't move/symlink the repo after install** for `caelestia` (and similar) — the installer symlinks configs into place and Hyprland will fail to start if the source folder moves.
- **Memory.** A do-everything shell with many always-built windows is heavy; wrap rarely-shown surfaces in `Loader`/`LazyLoader`.

## Sources

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

# widgets — styling

The widgets component spans **four toolkits** (eww, AGS / Astal, Quickshell, plus the cross-cutting
design vocabulary), so this file is a concatenation of the four matching design references. Read
the first section (**design**) to pick a system; then jump to the section for the toolkit the
interview landed on. The per-toolkit sections are the verbatim references for *that* toolkit only —
there's no harm reading just yours.

Sections (in order):

1. `## design (cross-cutting)` — the system-choice + archetype catalog. Read this first.
2. `## eww` — yuck + SCSS. Floating widgets next to waybar.
3. `## AGS / Astal` — TS/JS + GTK + SCSS. Replaces waybar.
4. `## Quickshell` — QML / Qt 6. Replaces waybar.

HyprPanel and the turnkey shells (end-4, caelestia, Noctalia, DankMaterialShell) don't get a
section — you don't style them by hand. Drive them via matugen on the wallpaper; see `gotchas.md`
→ "HyprPanel and Material-You-native shells drive via matugen".

---

## design (cross-cutting)

[`waybar.md`](../waybar/styling.md) covers the **status bar**. This page covers everything *beyond* the bar — the **desktop widget shells** that dominate the modern Hyprland / r/unixporn scene: dashboards, control centers, sidebars, on-screen displays (OSDs), music players, notification centers, app launchers, calendars, power menus, and workspace overviews with live previews. Read this section **first** to pick a system; then go deep in the per-toolkit section: `## eww`, `## AGS / Astal`, `## Quickshell`.

> **Why this is a separate decision from the bar.** Some widget systems *add* widgets next to Waybar (eww floating widgets, a swaync control center). Others *replace the bar entirely* — caelestia's tagline is literally "‼️ No waybar here ‼️", and a Quickshell/AGS shell owns the bar, OSD, notifications, lock screen and dashboard as one program. So the first question is **strategy**: keep Waybar and bolt widgets on, or commit to a full shell.

### The landscape (and where momentum is, 2025–2026)

Two tools remain the most-starred *individual* utilities — **eww** (~12.5k★) and **Waybar** (~11.4k★) — but the highest-star *rices* of 2025–2026 are now **QML/Quickshell** shells: `end-4/dots-hyprland` (~14.7k★, which famously migrated AGS→Quickshell), `caelestia-dots/shell` (~9.8k★), `noctalia-shell` (~7.3k★), `DankMaterialShell` (~6.6k★). **Astal/AGS** (TypeScript over GTK) is the established mid-ground; **fabric** (Python) and **nwg-shell** (Python + GUI) are the niche-but-maintained options. The former turnkey darlings **HyprPanel** and **Ax-Shell** were **both archived in 2026** — still usable, no longer maintained.

Three trends shape any recommendation:
1. **AGS → Quickshell is the defining migration.** AGS v1 was deprecated for Astal/AGS v2, but gravity has shifted to **Quickshell** (QtQuick/QML). Its killer feature — **live window previews / overview** — is near-impossible in GTK toolkits.
2. **matugen / Material You is the default theming engine**, displacing pywal. Named-scheme (Catppuccin/Nord) and wallbash/wallust camps coexist, but new full shells almost all ship matugen-driven Material You.
3. **"Shell as a product" is consolidating** but churning at the framework layer (HyprPanel→Wayle, Ax-Shell→Ambxst). The survivors (caelestia, noctalia, DankMaterialShell) explicitly target *multiple* compositors, so "Hyprland-specific" is fading.

### Choosing a widget system — decision matrix

| System | Type | Language you write | Effort | Flexibility | Looks ceiling | Maintenance (2026) | Styling model |
|---|---|---|---|---|---|---|---|
| **Waybar + custom modules** | Status bar | none / JSONC + GTK-CSS (+shell for `custom/*`) | **Lowest** | Bar-shaped only | High for a bar | Very active | GTK3 CSS — see [`waybar.md`](../waybar/styling.md) |
| **HyprPanel** | Turnkey panel | none (GUI) / JSON | **Lowest** (GUI) | Low–medium (preset modules) | High | **Archived 2026-04** (→Wayle) | GUI + `.json` theme import; matugen |
| **nwg-shell** | Turnkey GTK suite | none (GUI) / JSON + GTK-CSS | Low (GUI) | Medium | Medium | Active | GTK3 CSS `style.css` |
| **eww** | Widget toolkit | **yuck + SCSS** | Medium | Very high (any shape) | Very high | Active | GTK3 CSS/SCSS — `## eww` below |
| **AGS / Astal** | TS/JS framework | **TypeScript/JSX + SCSS** | Medium–high | Very high | Very high | Active | GTK3/4 CSS/SCSS — `## AGS / Astal` below |
| **fabric** (+Ax-Shell) | Python framework | **Python + GTK-CSS** | Medium–high | Very high | Very high | fabric active; **Ax-Shell archived** | GTK3 CSS |
| **Quickshell** | QML toolkit | **QML** | High | **Highest** (live previews) | **Highest** | Very active | QML properties (not CSS) — `## Quickshell` below |

**Recommendations by user type:**
- **Beginner / "I just want it to work":** **Waybar + custom modules** for a bar (zero new language; reuses styling you already know), plus **swaync** for a notification-center widget. If you want a full GUI-configured suite that is *still maintained*, **nwg-shell** (prefer it over the archived HyprPanel).
- **Tinkerer / "I'll write some config":** **eww** (yuck + SCSS — GTK-CSS knowledge transfers, no real programming) for arbitrary floating widgets; or **AGS/Astal** if you're comfortable in TypeScript and want batteries-included services (network, bluetooth, mpris, notifications).
- **Perfectionist / "pixel-perfect, animations, live previews":** **Quickshell (QML)** — where the highest-effort, best-looking rices now live (caelestia, noctalia, DankMaterialShell, end-4), with hot-reload and live previews out of the box. **fabric** (Python) is the equivalent for someone who prefers Python to QML.

**Styling-knowledge transfer.** Waybar, eww, nwg-shell, fabric, AGS/Astal, and HyprPanel are **all GTK** under the hood, so the **GTK3-CSS subset** from [`waybar.md`](../waybar/styling.md) (`@define-color`/`@import`, `alpha()`/`shade()`/`mix()`, `border-radius`, `@keyframes`; no flexbox/`transform`/`calc`) carries across all of them. **Quickshell is the exception** — Qt/QML, so none of the GTK-CSS techniques transfer; styling is QML properties. **matugen is the common theming bridge** across HyprPanel, fabric, eww, AGS, and most QML shells (it generates a color file the config imports).

### Common widget archetypes (ranked by prevalence)

What people actually build, roughly in order of how often it shows up across the corpus, with the toolkit it's usually built in. These power the rice interview's "which widgets" question.

1. **Status bar** — universal. Waybar (standalone) or rolled into a full shell (Quickshell/AGS/fabric).
2. **App launcher** — near-universal. rofi/wofi/fuzzel for Waybar rices; a built-in spotlight launcher in shell toolkits.
3. **Notification center** — swaync/mako/dunst for Waybar rices; native in Quickshell/AGS/fabric (their `Notifd`/`Notifications` service *replaces* the daemon — don't run both).
4. **OSD (volume / brightness / caps-lock)** — the most common reason people leave plain Waybar; built into every shell toolkit, or a tiny eww popup.
5. **Dashboard / control center** (quick-settings toggles + sliders + sysinfo + media) — the *signature* shell widget. Quickshell (caelestia, Dank, noctalia), AGS (HyprPanel), fabric (Ax-Shell), or an eww overlay.
6. **Music / now-playing (MPRIS)** with blurred cover art — eww historically (adi1090x, gh0stzk); now a Quickshell/AGS/fabric card.
7. **Power / session menu** — wlogout for Waybar rices; a built-in session widget in shells.
8. **Calendar / clock panel** — eww historically; Quickshell/AGS widgets now.
9. **Wallpaper picker + dynamic theming** — shell scripts around swww/matugen/wallbash/wallust (every Material You rice).
10. **Lock screen** — hyprlock for Waybar rices; a *native* Quickshell lock (`SessionLock`) in full shells (caelestia, noctalia, Dank).
11. **Overview / window switcher with live previews** — a **Quickshell** specialty (end-4's signature); GTK toolkits can't easily do it.
12. **Clipboard / emoji / color picker / sidebar** — fabric (Ax-Shell has the widest set) and Quickshell.

### Turnkey panels (the "no-code" path)

For users who want widgets without programming. These are configured through a GUI or JSON, not a stylesheet — so "styling" means picking a theme, not writing CSS.

**HyprPanel** (`Jas-SinghFSU/HyprPanel`) — an **AGSv2/Astal**-based, batteries-included bar + widget suite configured almost entirely through a **GUI settings dialog**: the closest thing to "install a panel, click options, done." Ships a configurable bar (workspaces, clock, tray, CPU/RAM/GPU/disk, battery + power-profiles, network, bluetooth, volume, media, updates, notifications), a **dashboard** (resource monitors, power menu, shortcuts, snapshot/record, color picker), **quick-settings**, **calendar**, **media**, **notifications**, and bluetooth/network/audio dropdown menus.
- **Install/run:** needs AGSv2 (Aylur's GTK Shell) first; on Arch `yay -S ags-hyprpanel-git`, then `exec-once = hyprpanel`. Config in `~/.config/hyprpanel/` as JSON.
- **Theming (its strongest feature):** a dedicated **Theming** section in the settings dialog. Themes **import/export as `.json` files** (`Theming > General Settings > Import/Export`) — how community theme catalogs are shared. **Matugen integration** (`Theming > Matugen Settings`, needs the `matugen` binary) recolors the panel to the wallpaper. Underlying styling is SCSS, but end users never touch it — the GUI writes the tokens.
- **⚠️ Archived 2026-04** (read-only). Maintainer points to a Rust successor (**Wayle**, TOML config, Pywal/Matugen/Wallust). Still installs and runs; don't expect fixes. For the rice engine, drive it via **matugen** (point matugen at the wallpaper, enable Matugen in HyprPanel's settings) rather than hand-editing its JSON.

**nwg-shell** (`nwg-piotr`) — a coordinated, **still-maintained** GTK/Python suite for sway *and* Hyprland: **nwg-panel** (the bar — Controls with brightness/volume sliders, clock+calendar, executors, taskbars, workspaces, menu-start, openweather, playerctl, tray), **nwg-drawer** (app grid), **nwg-dock**, **nwg-bar** (power menu). Configured via the `nwg-shell-config` / `nwg-panel-config` GUIs (JSON underneath); themed with a per-panel **`style.css`** (standard GTK CSS — Waybar knowledge transfers directly) plus preset styles. The maintained alternative to HyprPanel for a GUI-configured suite.

**Lower-effort still:** **Waybar `custom/*` modules** + `group/drawer` give you weather, notification bells, todo/pomodoro, and hover-out sliders without a new framework — see [`waybar.md`](../waybar/styling.md). And **swaync** is the standard drop-in **notification-center widget** for any bar (GTK CSS `~/.config/swaync/style.css`; pair via a `custom/notification` toggle).

### Theming flow (how the palette gets in)

Whatever the toolkit, the rice contract is the same: **render the palette into a colors file the widget config reads, then hot-reload.** The mechanism per toolkit:

| Toolkit | Colors file | Wired by | Reload |
|---|---|---|---|
| eww | `~/.config/eww/colors.scss` (`$key: #hex;`) | `@import "colors";` at top of `eww.scss` | `eww reload` |
| AGS / Astal | `colors.scss` (`$key: #hex;` / `@define-color`) | `@use`/`@import` in `style.scss` | file-monitor → `resetCss`/`applyCss` |
| Quickshell | `Colors.qml` singleton or `colors.json` | `import` the singleton / `FileView`+`JsonAdapter` | automatic on file save |
| HyprPanel | (its `.json` theme / matugen) | GUI / matugen | in-app |
| nwg-shell | `style.css` (GTK CSS) | per-panel style | `nwg-panel` restart |

The rice engine ships templates for the first three (`eww.tmpl`, `ags.tmpl`, `quickshell.tmpl`) and registers the chosen one in the manifest so `rice apply` re-themes the widget shell with everything else — see `theming/engine.md` → "Widget-shell theming". For Material-You-native shells (end-4, caelestia, HyprPanel), the alternative is to let **matugen** own the widget colors (mapping `primary→accent`, `surface→bg`, …) while the engine owns the core surfaces — keep one palette source per run so they stay consistent.

### Pitfalls (cross-toolkit)

- **Notification-daemon conflict.** A full shell's notification service (AGS `Notifd`, Quickshell `Notifications`, swaync) owns the `org.freedesktop.Notifications` D-Bus name — running mako/dunst alongside it means duplicate or swallowed notifications. Pick one.
- **Two bars at once.** If you adopt a full shell that includes a bar, *stop Waybar* (remove its `exec-once`) or you get two bars fighting for the top edge / exclusive zone.
- **Blur is the compositor's job.** GTK *and* QML widgets only frost a translucent surface if a Hyprland `layerrule` blurs that window's layer namespace — same failure mode as Waybar without the blur rule. Set the namespace and `match:namespace`.
- **Chasing an archived project.** HyprPanel (→Wayle) and Ax-Shell (→Ambxst) are frozen, and end-4 left AGS for Quickshell. They're great *visual* references, but don't start a new config on a dead codebase.
- **Picking the heaviest tool for one widget.** If you only want a weather readout or a notification bell, a Waybar `custom/*` module beats standing up a whole QML shell. Match effort to the goal.

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

## eww

eww (ElKowar's Wacky Widgets) is a standalone, GTK3-backed widget toolkit. Unlike Waybar (a fixed-purpose status bar), eww hands you raw GTK widget primitives and a layout language, so the community builds *anything* with it: bars, dashboards, sidebars, launchers, OSDs, music players, power menus. The cost of that freedom is that every rice is bespoke — there's no `modules-left`, only the boxes you wire yourself. This section is about making those widgets *look* good, grounded in how adi1090x, gh0stzk, dharmx, dwt1 and others actually do it. For the *cross-toolkit* picture (eww vs AGS vs Quickshell vs a turnkey panel) read the `## design (cross-cutting)` section above first.

### What you're styling

Two files, two jobs. Both live in `~/.config/eww/`.

| File | Format | Controls |
|------|--------|----------|
| `eww.yuck` | yuck (S-expression / Lisp-like) | **Structure & behavior**: the widget tree (`defwidget`), windows and their geometry/stacking/layer (`defwindow`), and all state (`defvar`, `defpoll`, `deflisten`). Declares *what exists* and *what data flows in*. |
| `eww.scss` (or `eww.css`) | GTK3 CSS / SCSS | **The visual**: backgrounds, `border-radius`, padding/margin, color, fonts, hover/active states, transitions. SCSS is compiled by eww itself, so you get nesting, `$variables`, and `@import` for free. |

**The yuck widget primitives** (the GTK building blocks you compose):
- `box` — the main layout container. `:orientation "horizontal"|"vertical"`, `:space-evenly`, `:spacing`. This is your flexbox substitute.
- `label` — text. `:text`, `:markup` (Pango markup for inline color/size/weight), `:wrap`, `:truncate`, `:angle` (rotate text for vertical bars).
- `button` — `:onclick`, `:onrightclick`, `:onmiddleclick`.
- `eventbox` — wraps exactly one child to receive events; **supports `:hover` and `:active` CSS** plus `:onhover`/`:onhoverlost`. The key to reveal-on-hover widgets.
- `revealer` — animates a child in/out. `:transition "slideright"|"slideleft"|"slideup"|"slidedown"|"crossfade"|"none"`, `:reveal {bool}`, `:duration "350ms"`. The community's main animation tool.
- `overlay` — stacks children on top of each other (sizes to the first child). Used for text-over-album-art, progress-over-icon.
- `scale` — a slider. `:value :min :max :orientation`, `:onchange`. Styled via `trough`/`highlight`/`slider` sub-nodes — this is how you build volume/brightness bars.
- `progress` — a progress bar (`:value 0–100`, `:orientation`, `:flipped`). Styled via `trough`/`progressbar`.
- `circular-progress` — a ring. `:value :start-at :thickness :clockwise`. Color comes from the CSS `color` property; the hollow inner size scales with `font-size`.
- `graph` — plots a value over time. `:value :thickness :time-range :min :max :dynamic`. Color via CSS `color`.
- `literal` — renders a *string of yuck* at runtime (`:content`). Lets a shell script emit a whole widget tree (the classic dynamic-workspaces trick).
- `image` (`:path :image-width :image-height`), `calendar`, `input`, `checkbox`, `expander`, `scroll`, `transform` (rotate/scale/translate), `systray`, `stack`.

**State binding** (yuck side, drives what CSS sees):
- `defvar` — static, updated with `eww update name=val`.
- `defpoll` — re-runs a shell script every interval (`:interval "5s"`): clock, CPU%, weather.
- `deflisten` — runs a script once and streams its stdout lines (best for event-driven data: `playerctl --follow`, a Hyprland workspace socket listener). The backbone of live widgets.

> **GTK3 CSS is not web CSS.** eww uses GTK's CSS engine, so the same subset limits as Waybar apply: **no flexbox** (use `box` orientation), **no `transform`/`calc()`/`float`/absolute positioning**, and you can't set `width`/`height` in CSS (size comes from yuck or `min-width`/`min-height`). You *do* get `background`, `color`, `border`/`border-radius`, `padding`, `margin`, `min-width`/`min-height`, `font-*`, `opacity`, `box-shadow`, `transition`, and GTK color helpers. Because eww compiles SCSS (via the **grass** engine), you also get nesting and `$vars` on top — but note grass's Sass `alpha()` takes **one argument** (reads alpha; it does not set it): use `rgba($color, a)` for a translucent color, not `alpha($color, a)` (see Pitfalls).

### How it's launched

eww is a daemon plus on-demand windows — there is no single "eww bar" process. In `hyprland.conf`:

```conf
exec-once = eww daemon
exec-once = eww open bar               # window name = the defwindow symbol
exec-once = eww open-many bar music dashboard   # several at once
```

Then keybinds toggle the rest. The dharmx/adi1090x idiom is a **toggle script** bound to a key: `eww open --toggle dashboard` (or check `eww active-windows` and `eww close`). After editing yuck or scss, hot-reload everything with `eww reload` (no daemon kill needed). `eww inspector` opens the GTK Inspector to live-debug selectors.

**Layer namespace + Hyprland blur.** Each `defwindow` becomes its own `gtk-layer-shell` layer surface. Set the namespace explicitly so you can target it:

```yuck
(defwindow bar
  :monitor 0
  :stacking "fg"
  :exclusive true                 ; reserve space (anchor must include center)
  :namespace "eww-bar"            ; <- the layer name Hyprland blurs
  :geometry (geometry :x "0%" :y "0%" :width "100%" :height "36px" :anchor "top center"))
```

Then blur that namespace (0.54.x block form — see `../window-rules/template.md`):

```conf
layerrule {
    name = blur-eww
    match:namespace = eww-bar
    blur = true
    ignore_alpha = 0.2
}
```

Confirm the name with `hyprctl layers` (look for `namespace: eww-bar`). Note the **whole-surface caveat**: eww renders one layer surface per window, so Hyprland blurs the *entire window region*, not individual cards. To blur some elements but not others, split them into separate `defwindow`s with separate namespaces ([Hyprland Discussion #748](https://github.com/hyprwm/Hyprland/discussions/748)). `:focusable "none"` keeps a bar from stealing keyboard focus; a launcher/power-menu wants `"exclusive"` or `"ondemand"`.

### Widget archetypes

This is the heart of eww ricing — because it's general-purpose, the *widget vocabulary* is the design. The recurring archetypes:

- **Horizontal bar** — a top/bottom `:exclusive` window: workspaces + clock + a system cluster. Built from `box`es; workspaces via `deflisten` + `literal`/`for` (below).
- **Vertical bar** — a narrow left/right column (`:width "44px"`, `:anchor "left center"`). Text rotated with `label :angle 90`, or stacked icon-only. eww is *popular* for vertical bars precisely because `label :angle` and vertical `scale`/`circular-progress` make it tractable.
- **Dashboard / control-center** *(the flagship eww look)* — a large centered overlay window with a profile card, music player, system gauges, calendar, quick-toggles, power buttons, weather — all rounded cards on a translucent backdrop. **adi1090x/widgets** is the canonical gallery; its layouts are the most-copied eww dashboards on r/unixporn.
- **Sidebar / quick-settings** — a `revealer`-driven panel that slides in from an edge with toggles (wifi/bt/dnd), sliders, and notifications.
- **App launcher** — a fullscreen `:stacking "fg"` window with an `input` search box filtering a `for`-generated grid of `button`s.
- **OSD popups** — tiny auto-hiding volume/brightness windows: a `circular-progress` or `scale` that `eww open`s on a key event and closes after a timeout (driven by a `deflisten` on the audio/backlight event).
- **Music / now-playing** — `deflisten "playerctl --follow metadata --format ..."` feeds title/artist/art-path; album art via `image :path`, often with text in an `overlay`; a `scale` shows track position.
- **System-info panel** — CPU/RAM/disk/temp as `circular-progress` rings or `graph`s, polled with `defpoll`.
- **Calendar / clock / greeting** — the `calendar` widget, or a big `defpoll`-driven clock with a "Good morning, {user}" greeting label.
- **Weather** — `defpoll` a `wttr.in`/OpenWeatherMap script.
- **Power menu** — a fullscreen overlay of large icon `button`s (lock/logout/reboot/shutdown) with hover reveal.
- **Workspace overlay** — a transient centered indicator on workspace switch.

### Battle-tested techniques (attributed)

Harvested by reading the yuck + scss of the canonical configs. Drop them in and swap literal colors for the rice palette vars (`$accent`, `$bg`, … after `@import "colors";`).

**Rounded cards & structure.**
- *The card class* (adi1090x/widgets): one reusable `.genwin { background-color: $surface; border-radius: 16px; }`, plus circular avatars via `border-radius: 100%` on a fixed `200px × 200px` image. The whole dashboard is cards-on-cards with a single shared radius.
- *SCSS variables + nesting* (dharmx): define `$surface-darkgrey`, `$surface-lightgrey` at top, then nest `button { &:hover { … } }`. eww compiles it, so you get real SCSS ergonomics Waybar's plain CSS can't.

**Sliders, progress & rings.**
- *trough/highlight slider styling* (adi1090x, dwt1): style the track and fill separately —
  ```scss
  .cpu_bar scale trough { background-color: $surface; border-radius: 16px; min-height: 10px; }
  .cpu_bar scale trough highlight { background-color: $red; border-radius: 16px; }
  ```
  Hide the knob with `scale slider { background-color: transparent; box-shadow: none; min-width: 0; min-height: 0; }` for a clean bar.
- *circular-progress as a gauge*: the ring is colored by the CSS `color` property; set the hollow inner size with `font-size` and the ring width with the yuck `:thickness`. Put a `label` or `image` in a centered `overlay` for "63% over a CPU glyph."

**Reveal animations & hover.**
- *eventbox → revealer hover reveal* (the dominant interaction pattern): wrap a leader icon in an `eventbox` whose `:onhover`/`:onhoverlost` set a `defvar`, and bind a sibling `revealer :reveal {that-var} :transition "slideleft"`. Slides a slider/label out on hover — the eww equivalent of Waybar's `group/drawer`.
- *transition on hover state* (dharmx): `button:hover { transition: 200ms linear background-color, border-radius; background-color: rgba($surface, 0.6); }` — a calm fade plus radius morph, driven by the `eventbox`'s `:hover`. (Use `rgba()`, not `alpha()`, for a translucent color — see Pitfalls.)

**Transparency & glass.**
- *rgba surfaces + compositor blur*: give cards `background-color: rgba($bg, 0.8)` (use `rgba()` for translucency — eww's `grass` `alpha()` takes one arg only; see Pitfalls) and let the `layerrule … blur = true` on the window's namespace frost the wallpaper behind. Because eww blurs the whole surface, keep inter-card gaps either fully transparent (so `ignore_alpha` skips them) or accept that they blur too.
- *opacity for state* (common): inactive workspace/element `opacity: 0.4`, active `opacity: 1` — cheapest possible indicator, same as Waybar rices.

**Live workspaces (the signature yuck pattern).**
- *deflisten + literal* — a script listens to the Hyprland event socket and emits a yuck string; `(literal :content workspaces)` re-renders it on every change. Or, with **FieldofClay/hyprland-workspaces** (a multi-monitor JSON helper), iterate directly:
  ```yuck
  (deflisten workspaces "hyprland-workspaces _")
  (for i in {workspaces[monitor].workspaces}
    (button :onclick "hyprctl dispatch workspace ${i.id}" :class "${i.class}" "${i.name}"))
  ```
  It emits classes `workspace-button`, `workspace-active`, `workspace-on-screen`, `w<id>`/`wa<id>` so you can color active/occupied/empty distinctly in SCSS.

**Now-playing.**
- *playerctl --follow* (gh0stzk, adi1090x): `deflisten` on `playerctl --follow metadata` for title/artist/art; a polled or listened position feeds a `scale` (or `circular-progress`) for the seek bar; album art via `image :path`. Big play/pause glyphs are just colored `button` labels (`.btn_play { color: $green; font-size: 48px; }`).

### Palette / theming flow

eww's SCSS compilation makes palette-swapping clean, and the community standard is to **generate a colors partial and `@import` it**:

1. A generator writes a colors partial — pywal (`~/.cache/wal/colors.scss`) or **matugen** (template → `~/.config/eww/colors.scss`). Many configs run both and `@import` the result.
2. `eww.scss` starts with `@import "colors";` and references `$color0..$color15`, `$background`, `$foreground` (pywal names) or the rice keys — never hardcoded hex.
3. Re-theme with `eww reload` (recompiles SCSS in place; no daemon restart). gh0stzk's theme selector swaps the colors partial and reloads so all eww widgets re-skin instantly *without* restarting eww — preserving the daemon and avoiding flicker.

**For the rice engine here**, render a `~/.config/eww/colors.scss` of `$key: #hex;` lines from the palette contract (`$bg $fg $surface $accent $accent2 $red …`), `@import` it at the top of `eww.scss`, and re-skin with `eww reload`. The engine ships an `eww.tmpl` for exactly this (registered in the manifest when eww is chosen — see `theming/engine.md` → "Widget-shell theming").

### Pitfalls (eww)

- **`width`/`height` in CSS silently do nothing** — GTK ignores them. Size via yuck geometry, or `min-width`/`min-height` in CSS. The single most common eww styling confusion.
- **No `transform`/`calc()`/flexbox** — same GTK3 subset as Waybar. Use `box` orientation/`space-evenly` for layout, the `transform` *widget* (not CSS) for rotation, and a vertical `scale`/`label :angle` for vertical bars.
- **Slider knob won't disappear** — GTK draws a default `slider` thumb; you must zero it (`min-width:0; min-height:0; background:transparent; box-shadow:none`) or it pokes out of your clean bar.
- **Blur applies to the whole window, not cards** — eww is one layer surface per `defwindow`. You can't blur one card and not another within the same window; split into multiple windows with distinct namespaces if you need that ([Hyprland #748](https://github.com/hyprwm/Hyprland/discussions/748)).
- **`:exclusive` needs a centered anchor** — it only reserves space when the `:anchor` includes `center` along the bar's long axis; otherwise windows overlap the bar.
- **Forgetting the namespace** — without `:namespace`, the layer name is autogenerated and your `layerrule match:namespace` won't match; blur silently won't apply. Always set it and verify with `hyprctl layers`.
- **GTK theme bleed-through** — inherited GTK button/scale styling can override yours; reset (`button { all: unset; }` then re-set) like the Waybar `all: unset` trick.
- **Hardcoded `@import` paths** — some shipped configs use absolute `@import "/home/USER/..."`; these break on copy. Use relative `@import "colors";`.
- **Reload vs restart** — `eww reload` covers yuck + scss edits. Only a daemon change or a stuck state needs `eww kill; eww daemon`.
- **`alpha($color, 0.8)` errors — eww's SCSS is `grass`, not dart-sass.** eww compiles SCSS via the **grass** engine, where Sass's `alpha()` takes **only one argument** (it *reads* a color's alpha, it doesn't set it). Writing `alpha($accent, 0.8)` fails with *"Only 1 argument allowed, but 2 were passed"* and the **whole `eww.scss` fails to compile, so the widget renders completely UNSTYLED**. For a translucent color use **`rgba($accent, 0.8)`** instead. (So the hover/glass snippets above should be `rgba($surface, 0.6)` / `rgba($bg, 0.8)`, not `alpha(...)`.)
- **`:height "auto"` (and `:width "auto"`) is invalid** — eww errors *"Failed to parse 'auto' as a length value"* on a `defwindow :geometry (geometry … :height "auto")`. There is no `auto`; use a concrete length (px or %), e.g. `:height "520px"`.
- **colors partial var-name mismatch** — the `$var` names in `colors.scss` must match exactly what `eww.scss`'s `@import "colors";` references (`$bg`/`$accent`/…). A missing/renamed `$var` is an undefined-variable compile error that also leaves the widget unstyled.

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

## AGS / Astal

AGS (Aylur's GTK Shell) and **Astal** are how the Hyprland community builds *fully custom desktop shells* — not a status bar you configure, but widgets you program: bars, dashboards/control-centers, notification popups, OSDs, launchers, music players with blurred cover art. Where Waybar is JSONC + a CSS subset, AGS/Astal is JavaScript/TypeScript (or Lua/Python) **plus GTK CSS/SCSS**. This section is about making those widgets *look* good — the SCSS architecture, the material-card / quick-settings-toggle / blurred-album-art techniques — grounded in how end-4, HyprPanel, kotontrion, matshell, and Aylur himself actually do it.

> **Scope note.** This is the *styling* surface. The widget logic (signals, bindings, GObject services) is a programming topic; here we focus on the CSS/SCSS and the visual archetypes the styling produces.

### What you're styling — AGS v1 vs Astal + Gnim (AGS v2 / v3)

The single most important thing to get right: **there are two incompatible generations** (v1
vs. v2-and-later), and most old tutorials describe v1. The CLI moved to v2 in Nov 2024 and to
**v3 (Gnim JSX runtime, `Accessor` / `createState` / lifecycle hooks)** in 2025 — v3 keeps the
v2 entry-point shape (`app.start`) but renames a handful of props (`className` → `class`) and
replaces `astalify` with Gnim's JSX intrinsics.

| | **AGS v1** (`Aylur/ags`, ≤ v1.x) | **Astal + Gnim / AGS v3** (current — v3.1.x as of mid-2026) |
|---|---|---|
| What it is | A standalone GJS app: a runtime + builtin Services + a `Widget.*` API | `Aylur/astal` = Vala/C **libraries** (consumable via GObject introspection); `Aylur/ags` = a scaffolding/bundler **CLI** that wires Astal + Gnim (JSX-for-GJS) for a TS/JS workflow |
| Language | GJS (JavaScript), TypeScript via types | **TypeScript / JavaScript** (the AGS CLI's documented surface); the underlying Astal libs are GIR-bindable so Lua / Python / Vala work too, but the `ags` CLI itself only scaffolds TS/JS |
| Toolkit | **GTK3** only | **GTK3 or GTK4** (you pick the import: `ags/gtk3/app` or `ags/gtk4/app`) |
| Entry | `App.config({ style, windows })` | `app.start({ css, main })` — `css` is a string (the bundler inlines a `.scss` import as a string) |
| Services | Builtin (`Battery`, `Mpris`, `Audio`…) | External libs: `import Battery from "gi://AstalBattery"` |
| Status | **Deprecated.** Rewritten from scratch Nov 2024; "you will have to rewrite your projects from the ground up." | Recommended path. v3.0.0 migrated the JSX runtime to **Gnim** (replacing `astalify`), introduced `Accessor` / lifecycle hooks, `createState` / `createBinding` / `createMemo` / `createEffect`. |

The community migration: through ~2023 everyone used AGS v1 (end-4's illogical-impulse, HyprPanel, kotontrion all started here). In **November 2024** Aylur rewrote the core into Astal (Vala/C libs) and demoted `ags` to a CLI that scaffolds + bundles TS projects. The `astal` namespace was then folded back into `ags`. Two notable post-migration moves: **HyprPanel** ported v1→Astal (its `getting_started/astal.html` guide), and **end-4 left the GTK ecosystem entirely** — illogical-impulse is now **Quickshell** (QML/Qt6), not AGS. The old AGS version survives only on end-4's `ii-ags` branch and is unmaintained.

**The styling itself is GTK CSS either way** — the same subset caveats as Waybar (`../waybar/styling.md`): no flexbox/`gap`/`calc()`, limited `box-shadow`, color helpers `alpha()`/`shade()`/`mix()`/`lighter()`/`darker()`. The win over Waybar is that AGS/Astal **compile SCSS** (nesting, `$variables`, `@mixin`, `@use`, `color.adjust()`), so configs are organized like a real frontend codebase. **GTK4 differs from GTK3**: some node names and properties change (the underlying `GtkWidget` GTK3 → GTK4 prop is `style-class`/`class-names` → `css-classes`), and GTK4 drops a few CSS features while adding others — test, don't assume. In **AGS v3's Gnim JSX** the attribute name is just **`class`** for both `gtk3` and `gtk4` imports (the v1 attribute name was `className`; the migration guide is explicit: "className -> class").

### How it's launched (and how SCSS gets compiled)

**AGS v1** — `App.config` points at a stylesheet; SCSS is compiled with `sassc` at startup, hot-reloaded via `Utils.monitorFile`:
```js
// AGS v1 (deprecated, but this is what most existing rices run)
const scss = `${App.configDir}/style.scss`
const css  = `/tmp/style.css`
Utils.exec(`sassc ${scss} ${css}`)            // compile
App.config({ style: css, windows: [Bar()] })

Utils.monitorFile(`${App.configDir}/scss`, () => {  // hot reload
    Utils.exec(`sassc ${scss} ${css}`)
    App.resetCss()                            // clear old sheet
    App.applyCss(css)                         // apply new (stacks on top)
})
```
Runtime CSS knobs: `App.applyCss('/path.css')` or `App.applyCss('window{background:transparent;}')`, `App.resetCss()`, and a per-widget inline `css:` prop (`Widget.Label({ css: 'color: blue; padding: 1em;' })`).

**Astal + Gnim / AGS v3** — `ags init` scaffolds a TS project (with `style.scss`, `tsconfig`, types); the `css` field of `app.start({ css, main })` is the **string contents** of a stylesheet (the AGS docs are explicit: *"You can import any css or scss file which will be inlined as a string"*). The dart-sass step is the bundler's import-time `.scss`-to-string transform, **not** an on-disk hot-recompile loop. CLI: `ags init`, `ags run`, `ags bundle`, `ags types` — **there is no `ags inspect` subcommand in v3**; open the GTK inspector with `GTK_DEBUG=interactive ags run` (or the GtkInspector keybind). Per-widget styling uses the **`class`** prop (Gnim renamed v1's `className`) and an inline `css` prop; runtime CSS is applied with `app.apply_css(cssString)` / `app.reset_css()` (lowercase methods, not v1's `App.applyCss`).

**Reload loop in practice:** edit SCSS → `ags run` re-bundles + re-applies on every restart. There is no built-in file-watch in v3's app surface — running configs that auto-reload on save wire their own `monitorFile` watcher and call `app.apply_css()` themselves (the v1 `Utils.monitorFile` pattern). There is no `SIGUSR2`; reload is in-process or via `ags request` / `ags quit`.

### Widget archetypes (what the community actually builds)

These are the recognizable AGS/Astal looks. The bar is the least interesting part — the **dashboard/control-center is the signature AGS aesthetic** (it's what you can't get from Waybar).

- **Top bar.** Workspaces + clock + a system cluster, same logical content as Waybar but styled as one SCSS component (`_bar.scss`). Usually a translucent pill or floating island; often hosts a Hyprland workspace widget with per-monitor coloring.
- **Dashboard / control-center** *(the signature look)*. A large popover panel of **material cards**: a grid of round **quick-settings toggle buttons** (wifi/bt/dnd/airplane — accent-filled when on, surface when off), **sliders** (volume/brightness with a filled trough), a **media card**, a clock/calendar, power-profile selector, and a logout/power row. HyprPanel, matshell (`_system-menu.scss`), and Aylur's own dotfiles all center on this.
- **Notification popups + notification center.** Transient toast stacks (slide-in via revealers) plus a persistent scrollable history panel with a clear-all + DND toggle. Astal's `Notifd` library backs both — *stop mako/dunst/swaync first* or daemons conflict.
- **OSD.** A small centered/edge pill that fades in on volume/brightness/caps-lock change, with an icon + a slider/level bar. (`_osd.scss`.)
- **App launcher.** Fuzzy-search entry over `AstalApps`, results as a vertical list of icon+label rows, often with frecency ranking. Styled like a single rounded search card.
- **Music player with blurred cover-art background** *(the showpiece)*. A card whose background is the album art, **blurred and dimmed**, with crisp controls/title on top via a `Gtk.Overlay`. See the technique below.
- **Calendar / date panel, power menu, bluetooth/wifi/network applets, system tray, workspace/Hyprland overview, on-screen keyboard, dock.** All appear across the corpus; the network/bt applets are nested menus inside the control-center.

### Battle-tested techniques (attributed)

Harvested by reading the SCSS/TSX of the canonical repos. Drop them in and swap literal colors for the rice palette vars. The palette contract is the same as elsewhere: `{{bg}} {{fg}} {{surface}} {{muted}} {{cursor}} {{accent}} {{accent2}} {{red}} {{green}} {{yellow}} {{blue}} {{magenta}} {{cyan}} {{color0}}..{{color15}} {{font_ui}} {{font_mono}}`.

**SCSS architecture / structure.**
- *7-1 SCSS layout — the maintainable standard* (Neurarian/matshell): split styling into `abstracts/` (`_variables.scss`, mixins), `base/_reset.scss`, `components/` (`_bar.scss`, `_music.scss`, `_osd.scss`, `_notifications.scss`, `_system-menu.scss`, `sidebar/…`), `layouts/`, with one `main.scss` `@use`-ing them. Each widget = one partial. Far cleaner than Waybar's single `style.css`.
- *`@use "../abstracts" as *;` then drive everything from variables* (matshell): `$spacing-xs/-sm/-md`, `$round`/`$round2`, `$font`, `$darkmode` boolean — components reference these, never literals, so a re-theme touches one file.
- *Mixin library for reuse* (matshell `mixins/_components.scss`, `_effects.scss`): define `@mixin window`, `@mixin border`, `@mixin rounding`, `@mixin button`, `@mixin animate` once; every card `@include`s them. This is the AGS equivalent of Waybar's "style the three wrappers, not every module."

**Material cards & elevation.**
- *Elevation tiers as a shadow mixin* (matshell `_effects.scss`): `@mixin light-mode-shadow($type)` → `"subtle"` `box-shadow: 0 1px 3px rgba(0,0,0,0.08)`, `"elevated"` `0 2px 8px rgba(0,0,0,0.15)`, `"strong"` `0 1px 3px rgba(0,0,0,0.18)`; plus `@mixin window-shadow { box-shadow: 0 3px 5px 1px <bg @ low alpha>; }` and an `@mixin inset-shadow`. Material Design 3 elevation, one knob.
- *Option-row card* (matshell `@mixin option-row`): `@include rounding; background: <barBg lightened 2%>; border: 1px solid alpha($fg, 0.1); padding: 0 $spacing-md; margin: $spacing-xs 0;` + subtle shadow in light mode. The repeating "setting row" inside a control-center.
- *Rounded everything via a radius scale* (matshell, HyprPanel): one `$round`/`$round2` (or `border-radius` token) reused on windows, cards, buttons, sliders so the whole shell shares a corner radius — the cohesive "soft UI" look.

**Quick-settings toggle buttons.**
- *Accent-filled toggle* (HyprPanel, matshell `@mixin toggle-switch`, `.system-menu .toggle button`): a round/pill button that is `background: $accent; color: $bg` when **active** and `background: $surface; color: $fg` when **inactive**, with `@include animate` for the transition. The defining control-center gesture. Give the toggle group a `min-width` (matshell uses `20rem`) so the grid doesn't reflow.

**Sliders (volume/brightness).** GTK `scale` widgets expose styleable sub-nodes — names differ by toolkit, find them with the GTK Inspector (`GTK_DEBUG=interactive ags run`):
- *GTK4 slider* (matshell `.system-menu .sliders`): style `trough` (the track) and `block`/`filled` (the fill) — `filled { border-radius: 1.5rem; background-color: $fg; }`, `block { min-height: $spacing-sm; }`. Hide/shrink the knob via the `slider`/`highlight` node.
- *GTK3 slider* (AGS v1 era, same idea as Waybar's `pulseaudio/slider`): node names are `trough`, `highlight` (fill), `slider` (knob) — `trough { min-height: 8px; border-radius: 8px; background: alpha($bg,0.6); }`, `highlight { background: $accent; }`, `slider { background: transparent; box-shadow: none; }`.

**Blurred album-art background** *(the music-player showpiece)* (matshell `_music.scss` + `Cover.tsx`): two stacked layers in a `Gtk.Overlay`. The bottom layer is the cover art set as a CSS `background-image` (the path bound from `Mpris.Player.coverArt`), with `background-size: cover; background-position: center;` and a **blur** + low opacity:
```scss
.music.window .blurred-cover {
    border-radius: $round;
    opacity: 0.8;            /* dim so foreground text reads */
    /* art set via background-image (bound from coverArt) + Gtk blur */
}
.music.window .cover {       /* the crisp foreground thumbnail */
    background-size: cover; background-position: center;
    border-radius: $round2;
    box-shadow: 0 1px 2px -1px $bg;
    min-height: 13rem; min-width: 13rem; opacity: 0.9;
}
```
The TSX uses an `<image class="cover" contentFit={Gtk.ContentFit.COVER} file={…coverArt…}/>` (AGS v3 Gnim JSX — `class` not `cssClasses`; matshell uses GTK4 underneath but the AGS attribute is `class` for both `gtk3` and `gtk4` imports). Key tactic (matshell, verbatim comment): **force light text on the player** regardless of theme — `label, .title, image { color: $background; }` (in light mode) — "Dark almost never works on top of most cover arts." A CAVA visualizer is layered behind at `opacity: 0.2`.

**Workspaces & per-monitor accent** (matshell `@mixin hypr-workspace-style`): `background: $bg-color; box-shadow: inset -2px -2px 2px <bg darkened 25%>;` with a `:hover` variant — an inset bevel instead of a flat fill. Each monitor gets its own hue mixed from Material You containers (`color.mix($primary_container, $on_primary_container, 70%)`).

**Circular progress (CPU/RAM gauges)** (matshell `@mixin hw-circular-progress`): style the `circularprogress` node's `progress` (the arc, `color: $accent; min-width: 2.3rem;`) and `radius` (the track, `color: alpha($procBg,0.5)`) with a Material Symbols glyph centered. A ring meter you can't build in Waybar.

**Transitions / revealers.** Popups slide/fade via GTK `revealer` (`transition_type`, `transition_duration` on the widget) — the motion is a *widget prop*, not CSS — while CSS handles the easing of color/size via `@mixin animate` (a shared `transition`). Arrow indicators rotate with `transform: rotate(90deg)` (matshell `.arrow-down`) — note `transform` **works** here (GTK4), unlike Waybar's GTK3.

### Theming flow (matugen / Material You)

The dominant AGS/Astal theming model is **Material You via matugen** (`InioX/matugen`), which extracts a palette from the wallpaper and renders templates. The flow:

1. **A matugen template targets the shell's SCSS** (matshell `matugen/templates/ags.scss`). matugen loops its color map into SCSS vars:
   ```scss
   <* for name, value in colors *>
   ${{name}}: {{value.default.rgba}};
   <* endfor *>
   ```
   producing `$primary`, `$on_surface`, `$surface_bright`, `$tertiary_container`, etc. (Material 3 color roles).
2. **Semantic aliases on top** (matshell): `$accent: $tertiary_container; $fg: $on_background; $bg: color.adjust($background, $alpha: -0.5);` — map MD3 roles → the shell's own tokens, so components stay role-agnostic.
3. **Hot reload on regenerate.** matugen writes the SCSS, the shell's file monitor recompiles + `resetCss`/`applyCss`. end-4's old AGS version did exactly this — matugen generated the Material You scss and AGS hot-reloaded; the same pattern now lives in its Quickshell rewrite.
4. **`@define-color` for GTK-CSS interop.** matugen can also emit `@define-color name #hex;` blocks (GTK CSS variables) that both the shell and host GTK apps consume — the cross-app theming bridge.
5. **GUI/JSON theming, no SCSS by hand** (HyprPanel): HyprPanel is the outlier — it ships a **config GUI** (Dashboard → gear icon) and a **JSON config** of `theme.*` keys; colors come from the GUI, an imported theme file, or optional matugen/pywal hooks. Users never touch SCSS. (Its successor **Wayle**, Rust, promises TOML + "proper Pywal/Matugen/Wallust integration.")

For this plugin's rice engine, the natural integration is a matugen (or wallust) template that renders `colors.scss` with the palette contract keys as `$bg`, `$fg`, `$accent`, … and lets the shell's existing hot-reload pick it up — exactly the matshell model.

### Pitfalls (AGS / Astal)

- **Following v1 tutorials on a v3 setup (or vice-versa).** `App.config` vs `app.start`, builtin `Service` vs `gi://Astal*` imports, `Variable` vs `createState`, **`className` (v1) vs `class` (v3 Gnim JSX)** — the APIs are mutually incompatible. Check which generation a repo targets *before* copying (the migration guide is explicit: "className -> class").
- **GTK3 vs GTK4 CSS drift.** Slider/scale node names and supported CSS properties differ (the underlying GTK prop went from `style-class` to `css-classes`, but the AGS-JSX attribute is just `class` on both). `transform`/`filter` work in GTK4 but not GTK3. Confirm a node's name with the GTK Inspector (`GTK_DEBUG=interactive ags run` — there is **no** `ags inspect` subcommand in v3) rather than guessing from web CSS.
- **GJS / GObject quirks (v1).** Memory management leaned on GTK3's cascading-destroy; this changed in GTK4 and was a major reason for the rewrite. Long-lived widgets that aren't cleaned up leak.
- **Notification daemon conflicts.** AGS/Astal's `Notifd` *is* the notification daemon — running mako/dunst/swaync alongside it means duplicate or swallowed notifications. Disable the others.
- **Unreadable text over album art.** Cover-art backgrounds vary wildly; don't rely on theme `fg`. Force a fixed light (or dark) text color on the whole player and dim the art (`opacity: 0.8`) — matshell's explicit lesson.
- **`sassc` vs `dart-sass`.** v1 rices shell out to `sassc`; v2 bundles `dart-sass`. They differ on modern features (`@use`, `color.adjust`, math). A v1 `_index.scss` written for dart-sass won't compile under `sassc` and vice-versa.
- **Chasing a dead project.** **HyprPanel was archived April 2026** (→ Wayle) and **end-4 abandoned AGS for Quickshell**. They remain excellent *visual* references, but their code is no longer the place to start a new AGS/Astal shell; prefer current repos (matshell, kotontrion, Aylur's examples, tokyob0t).

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

## Quickshell

Quickshell (by **outfoxxed**, `quickshell.org`, repo at `git.outfoxxed.me/quickshell/quickshell`, GitHub mirror `quickshell-mirror/quickshell`) is a QtQuick/QML toolkit for building Wayland desktop shells — bars, dashboards, notification centers, OSDs, launchers, lock screens, wallpaper daemons. It is the modern successor many Hyprland ricers are migrating to from **AGS** (the JS/GJS framework): `end-4/dots-hyprland` (illogical-impulse) rewrote its whole shell from AGS to Quickshell, and the 2026 ricing scene has largely shifted onto it (`caelestia`, `Noctalia`, `DankMaterialShell`, dozens of personal configs). This section is about making a Quickshell shell *look* good — but the styling model is fundamentally different from waybar/eww/AGS, so read the next subsection first.

### What you're styling — QML, not a CSS stylesheet

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

### How it's launched on Hyprland

The binary is `quickshell`, aliased `qs`. A config is a directory of `.qml` files with a `shell.qml` entry point.

- **Config location:** `~/.config/quickshell/<name>/shell.qml`. Run a named config with `qs -c <name>`, or point at an explicit file with `qs -p ~/.config/quickshell/foo/shell.qml`.
- **Autostart:** in `hyprland.conf`, `exec-once = qs -c caelestia` (or whatever the project ships — `caelestia shell -d`, `dms run` for DankMaterialShell, `noctalia-shell`).
- **Entry point:** `shell.qml`'s root is typically a `ShellRoot` containing one or more windows. Multi-monitor is handled with `Variants` over `Quickshell.screens`, instantiating one window per monitor.
- **Windows are layer-shell surfaces.** Use `PanelWindow` (from `Quickshell`) as a bar/panel root — it docks to a screen edge via `anchors { top: true; left: true; right: true }`, sizes with `implicitHeight`, and reserves space (exclusive zone) so tiled windows don't overlap. Under Wayland it's backed by `WlrLayershell`, exposed as an attached property: `WlrLayershell.layer: WlrLayer.Top` (also `Background`/`Bottom`/`Overlay`), `WlrLayershell.namespace: "quickshell:bar"`, `WlrLayershell.keyboardFocus`, and `exclusionMode`/`exclusiveZone` (set `ExclusionMode.Ignore` / `exclusiveZone: 0` for overlays like an OSD or launcher that should float over windows, not push them).

**Blur is the compositor's job, not QML's.** A translucent `PanelWindow` over a busy wallpaper looks muddy unless Hyprland blurs what's behind it. Quickshell sets a layer **namespace** (convention `quickshell:<moduleName>`), and you match it with a Hyprland `layerrule`. On Hyprland 0.54.x use the block form (the single-line `layerrule = blur, …` is rejected — see `../window-rules/template.md` and the waybar page):

```conf
layerrule {
    name = blur-quickshell
    match:namespace = quickshell:bar
    blur = true
    ignore_alpha = 0.79   # don't blur the near-transparent gaps; per-module value
}
```

Confirm the namespace with `hyprctl layers`. Projects often swap the namespace to toggle effects: end-4's overview uses `quickshell:overview-blur` so a dedicated layerrule blurs only that surface; matching `match:namespace = quickshell:*` with `blur = true` covers every Quickshell window at once. Set the window itself transparent (`PanelWindow { color: "transparent" }`) and put a rounded `Rectangle` inside — see Pitfalls for the transparency gotcha.

### Widget archetypes

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

### Styling techniques in QML (attributed)

Concrete, reusable moves harvested from the canonical configs. Swap literal colors for `Theme.*` singleton properties (next subsection). Grouped by what they buy you.

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
- *Material 3 motion vocabulary in the theme singleton* (the cross-shell standard): end-4 `modules/common/Appearance.qml` (lines 251-268 — `expressiveFastSpatial`, `expressiveDefaultSpatial`, `expressiveSlowSpatial`, `expressiveEffects`, `emphasized`/`emphasizedAccel`/`emphasizedDecel`, `standard`/`standardAccel`/`standardDecel`), DankMaterialShell `Common/Anims.qml`, and caelestia `components/Anim.qml` all expose the same M3 cubic-bezier control points as `readonly property var` lists, so every `Behavior on x { NumberAnimation { easing.bezierCurve: Theme.emphasized; duration: Theme.durations.normal } }` site shares one motion identity. The rice engine's `quickshell.tmpl` mirrors this — emits `standard`/`emphasized`/`emphasizedAccel`/`emphasizedDecel` directly on the `Colors` singleton.
- *Theme-switch color animations on the singleton itself* (noctalia `Commons/Color.qml` lines ~83-100): wrap each `property color mPrimary` in a `Behavior { ColorAnimation { duration: Style.animationSlowest; easing.type: Easing.OutCubic } }` (gated by a `skipTransition` bool to suppress on initial load), so a re-theme **animates** the whole shell from old palette to new instead of popping. A high-leverage move for matugen-driven shells where the wallpaper change drives a palette change.
- *Keyframed / looping* (`@keyframes` equivalent): `SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { to: 0.4; duration: 1200 } NumberAnimation { to: 1; duration: 1200 } }` for a pulsing urgent/now-playing indicator. `NumberAnimation` with `easing.type: Easing.OutBack` gives the springy overshoot.
- *Enter/exit transitions*: `PropertyAnimation` on `opacity`/`y` driven by a `states` change, so an OSD or launcher slides+fades in rather than popping.

**Performance discipline.**
- *Lazy instantiation* (Quickshell FAQ, every serious config): wrap costly surfaces in `Loader` (Item-based) / `LazyLoader` so a dashboard or launcher is only built when shown — the main lever for keeping memory down.

### Theming flow — the Colors singleton + matugen

The palette lives in a **QML singleton**, the direct analog of waybar's `@define-color` block, and the single most important structural choice. Every widget references `Theme.accent` / `Colors.md3.primary` instead of a literal, so a re-theme is one file changing and the bindings repaint live.

A minimal hand-written singleton (`Theme.qml`, registered `singleton Theme Theme.qml` in a `qmldir`,
*and* `pragma Singleton` in the file — Quickshell's QML-overview docs are explicit: *"To make a
type of a Singleton, put `pragma Singleton` at the top of the file. To ensure it behaves correctly
with Quickshell, you should also make the [Singleton] the root item of your type."*):

```qml
pragma Singleton
import QtQuick
import Quickshell
Singleton {
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

> **Footgun: `QtObject` as the singleton root.** A plain `QtObject` *parses* (QML accepts it), but the Quickshell core won't register it — it warns *"Tried to register singleton … which is not the root component of its file"* (`quickshell-mirror/quickshell` → `src/core/singleton.cpp`) and every `Colors.<key>` reference in sibling QML resolves to undefined. Always use the Quickshell `Singleton` type as the root. (A common workaround pattern: ML4W's `~/.config/quickshell/CustomTheme/Theme.qml` uses `QtObject` + ad-hoc `Process`/`StdioCollector` polling instead of `FileView`/`JsonAdapter`, but it loses Quickshell's reload propagation in the process. Prefer the `Singleton` + `FileView` shape used by caelestia / end-4 / DankMaterialShell / noctalia.) `pragma ComponentBehavior: Bound` next to `pragma Singleton` is the standard companion pragma in those configs — it gives `id` access from inner components and is what every modern shell ships.

**Term colors are 16 individual `property color termN`, not a `var term: [...]` array.** caelestia `services/Colours.qml` lines 246-261 and end-4 `modules/common/Appearance.qml` lines 93-108 both expose `term0` through `term15` as separate `property color` declarations — sibling QML references them as `Colors.term3` directly. A `var term: [16]` array forces `Colors.term[3]`, which works mechanically but breaks drop-in copies of widgets from the corpus.

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

### Pitfalls (Quickshell)

- **You must know QML/JS, not CSS.** This is the steepest curve of any Hyprland shell. Layouts, property bindings, signals, `Behavior`/animation types, and Qt's effects are a real toolkit, not a stylesheet. There is no `style.css` to copy-paste into.
- **Heavy dependencies.** Pulls in Qt 6 (QtQuick, Qt Quick Effects/Shapes, often QtMultimedia/PipeWire). Build from source or AUR; effects like `MultiEffect`/`RectangularShadow` need the Qt Quick Effects module installed or they silently fail to load.
- **Blur is not a QML property.** No `backdrop-filter`. Translucency only frosts via a Hyprland `layerrule` on the window's layer namespace — forget it and you get a muddy panel (same failure mode as waybar without the blur rule).
- **Transparent-window gotchas.** A layer-shell window can't be rounded — round an inner `Rectangle` over a `color: "transparent"` window. Toggling a window between opaque and transparent at runtime can break GPU rendering unless you set `surfaceFormat`/`opaque: false` up front. And a Qt bug (QTBUG-137166) makes a transparent `Rectangle` *with a border* render invisible — add `border.width: 0` or set border props explicitly as the workaround.
- **No shared stylesheet unless you build one.** Without a `Theme` singleton + reusable styled components, color/font/radius defaults scatter across every file and a re-theme becomes a find-and-replace. Build the singleton first.
- **Exclusive zone vs. overlays.** A bar should reserve space (default exclusive zone); an OSD/launcher/dashboard should *not* — set `WlrLayershell.exclusionMode: ExclusionMode.Ignore` (or `exclusiveZone: 0`) or it shoves your tiled windows around.
- **Don't move/symlink the repo after install** for `caelestia` (and similar) — the installer symlinks configs into place and Hyprland will fail to start if the source folder moves.
- **Memory.** A do-everything shell with many always-built windows is heavy; wrap rarely-shown surfaces in `Loader`/`LazyLoader`.

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

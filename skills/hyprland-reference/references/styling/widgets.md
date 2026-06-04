# Desktop Widgets — choosing & styling a widget system

[`waybar.md`](waybar.md) covers the **status bar**. This page covers everything *beyond* the bar — the **desktop widget shells** that dominate the modern Hyprland / r/unixporn scene: dashboards, control centers, sidebars, on-screen displays (OSDs), music players, notification centers, app launchers, calendars, power menus, and workspace overviews with live previews. Read this page **first** to pick a system; then go deep in the per-toolkit page: [`eww.md`](eww.md), [`ags-astal.md`](ags-astal.md), [`quickshell.md`](quickshell.md).

> **Why this is a separate decision from the bar.** Some widget systems *add* widgets next to Waybar (eww floating widgets, a swaync control center). Others *replace the bar entirely* — caelestia's tagline is literally "‼️ No waybar here ‼️", and a Quickshell/AGS shell owns the bar, OSD, notifications, lock screen and dashboard as one program. So the first question is **strategy**: keep Waybar and bolt widgets on, or commit to a full shell.

## The landscape (and where momentum is, 2025–2026)

Two tools remain the most-starred *individual* utilities — **eww** (~12.5k★) and **Waybar** (~11.4k★) — but the highest-star *rices* of 2025–2026 are now **QML/Quickshell** shells: `end-4/dots-hyprland` (~14.7k★, which famously migrated AGS→Quickshell), `caelestia-dots/shell` (~9.8k★), `noctalia-shell` (~7.3k★), `DankMaterialShell` (~6.6k★). **Astal/AGS** (TypeScript over GTK) is the established mid-ground; **fabric** (Python) and **nwg-shell** (Python + GUI) are the niche-but-maintained options. The former turnkey darlings **HyprPanel** and **Ax-Shell** were **both archived in 2026** — still usable, no longer maintained.

Three trends shape any recommendation:
1. **AGS → Quickshell is the defining migration.** AGS v1 was deprecated for Astal/AGS v2, but gravity has shifted to **Quickshell** (QtQuick/QML). Its killer feature — **live window previews / overview** — is near-impossible in GTK toolkits.
2. **matugen / Material You is the default theming engine**, displacing pywal. Named-scheme (Catppuccin/Nord) and wallbash/wallust camps coexist, but new full shells almost all ship matugen-driven Material You.
3. **"Shell as a product" is consolidating** but churning at the framework layer (HyprPanel→Wayle, Ax-Shell→Ambxst). The survivors (caelestia, noctalia, DankMaterialShell) explicitly target *multiple* compositors, so "Hyprland-specific" is fading.

## Choosing a widget system — decision matrix

| System | Type | Language you write | Effort | Flexibility | Looks ceiling | Maintenance (2026) | Styling model |
|---|---|---|---|---|---|---|---|
| **Waybar + custom modules** | Status bar | none / JSONC + GTK-CSS (+shell for `custom/*`) | **Lowest** | Bar-shaped only | High for a bar | Very active | GTK3 CSS — see [`waybar.md`](waybar.md) |
| **HyprPanel** | Turnkey panel | none (GUI) / JSON | **Lowest** (GUI) | Low–medium (preset modules) | High | **Archived 2026-04** (→Wayle) | GUI + `.json` theme import; matugen |
| **nwg-shell** | Turnkey GTK suite | none (GUI) / JSON + GTK-CSS | Low (GUI) | Medium | Medium | Active | GTK3 CSS `style.css` |
| **eww** | Widget toolkit | **yuck + SCSS** | Medium | Very high (any shape) | Very high | Active | GTK3 CSS/SCSS — [`eww.md`](eww.md) |
| **AGS / Astal** | TS/JS framework | **TypeScript/JSX + SCSS** | Medium–high | Very high | Very high | Active | GTK3/4 CSS/SCSS — [`ags-astal.md`](ags-astal.md) |
| **fabric** (+Ax-Shell) | Python framework | **Python + GTK-CSS** | Medium–high | Very high | Very high | fabric active; **Ax-Shell archived** | GTK3 CSS |
| **Quickshell** | QML toolkit | **QML** | High | **Highest** (live previews) | **Highest** | Very active | QML properties (not CSS) — [`quickshell.md`](quickshell.md) |

**Recommendations by user type:**
- **Beginner / "I just want it to work":** **Waybar + custom modules** for a bar (zero new language; reuses styling you already know), plus **swaync** for a notification-center widget. If you want a full GUI-configured suite that is *still maintained*, **nwg-shell** (prefer it over the archived HyprPanel).
- **Tinkerer / "I'll write some config":** **eww** (yuck + SCSS — GTK-CSS knowledge transfers, no real programming) for arbitrary floating widgets; or **AGS/Astal** if you're comfortable in TypeScript and want batteries-included services (network, bluetooth, mpris, notifications).
- **Perfectionist / "pixel-perfect, animations, live previews":** **Quickshell (QML)** — where the highest-effort, best-looking rices now live (caelestia, noctalia, DankMaterialShell, end-4), with hot-reload and live previews out of the box. **fabric** (Python) is the equivalent for someone who prefers Python to QML.

**Styling-knowledge transfer.** Waybar, eww, nwg-shell, fabric, AGS/Astal, and HyprPanel are **all GTK** under the hood, so the **GTK3-CSS subset** from [`waybar.md`](waybar.md) (`@define-color`/`@import`, `alpha()`/`shade()`/`mix()`, `border-radius`, `@keyframes`; no flexbox/`transform`/`calc`) carries across all of them. **Quickshell is the exception** — Qt/QML, so none of the GTK-CSS techniques transfer; styling is QML properties. **matugen is the common theming bridge** across HyprPanel, fabric, eww, AGS, and most QML shells (it generates a color file the config imports).

## Common widget archetypes (ranked by prevalence)

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

## Turnkey panels (the "no-code" path)

For users who want widgets without programming. These are configured through a GUI or JSON, not a stylesheet — so "styling" means picking a theme, not writing CSS.

**HyprPanel** (`Jas-SinghFSU/HyprPanel`) — an **AGSv2/Astal**-based, batteries-included bar + widget suite configured almost entirely through a **GUI settings dialog**: the closest thing to "install a panel, click options, done." Ships a configurable bar (workspaces, clock, tray, CPU/RAM/GPU/disk, battery + power-profiles, network, bluetooth, volume, media, updates, notifications), a **dashboard** (resource monitors, power menu, shortcuts, snapshot/record, color picker), **quick-settings**, **calendar**, **media**, **notifications**, and bluetooth/network/audio dropdown menus.
- **Install/run:** needs AGSv2 (Aylur's GTK Shell) first; on Arch `yay -S ags-hyprpanel-git`, then `exec-once = hyprpanel`. Config in `~/.config/hyprpanel/` as JSON.
- **Theming (its strongest feature):** a dedicated **Theming** section in the settings dialog. Themes **import/export as `.json` files** (`Theming > General Settings > Import/Export`) — how community theme catalogs are shared. **Matugen integration** (`Theming > Matugen Settings`, needs the `matugen` binary) recolors the panel to the wallpaper. Underlying styling is SCSS, but end users never touch it — the GUI writes the tokens.
- **⚠️ Archived 2026-04** (read-only). Maintainer points to a Rust successor (**Wayle**, TOML config, Pywal/Matugen/Wallust). Still installs and runs; don't expect fixes. For the rice engine, drive it via **matugen** (point matugen at the wallpaper, enable Matugen in HyprPanel's settings) rather than hand-editing its JSON.

**nwg-shell** (`nwg-piotr`) — a coordinated, **still-maintained** GTK/Python suite for sway *and* Hyprland: **nwg-panel** (the bar — Controls with brightness/volume sliders, clock+calendar, executors, taskbars, workspaces, menu-start, openweather, playerctl, tray), **nwg-drawer** (app grid), **nwg-dock**, **nwg-bar** (power menu). Configured via the `nwg-shell-config` / `nwg-panel-config` GUIs (JSON underneath); themed with a per-panel **`style.css`** (standard GTK CSS — Waybar knowledge transfers directly) plus preset styles. The maintained alternative to HyprPanel for a GUI-configured suite.

**Lower-effort still:** **Waybar `custom/*` modules** + `group/drawer` give you weather, notification bells, todo/pomodoro, and hover-out sliders without a new framework — see [`waybar.md`](waybar.md). And **swaync** is the standard drop-in **notification-center widget** for any bar (GTK CSS `~/.config/swaync/style.css`; pair via a `custom/notification` toggle).

## Theming flow (how the palette gets in)

Whatever the toolkit, the rice contract is the same: **render the palette into a colors file the widget config reads, then hot-reload.** The mechanism per toolkit:

| Toolkit | Colors file | Wired by | Reload |
|---|---|---|---|
| eww | `~/.config/eww/colors.scss` (`$key: #hex;`) | `@import "colors";` at top of `eww.scss` | `eww reload` |
| AGS / Astal | `colors.scss` (`$key: #hex;` / `@define-color`) | `@use`/`@import` in `style.scss` | file-monitor → `resetCss`/`applyCss` |
| Quickshell | `Colors.qml` singleton or `colors.json` | `import` the singleton / `FileView`+`JsonAdapter` | automatic on file save |
| HyprPanel | (its `.json` theme / matugen) | GUI / matugen | in-app |
| nwg-shell | `style.css` (GTK CSS) | per-panel style | `nwg-panel` restart |

The rice engine ships templates for the first three (`eww.tmpl`, `ags.tmpl`, `quickshell.tmpl`) and registers the chosen one in the manifest so `rice apply` re-themes the widget shell with everything else — see `rice/references/engine.md` → "Widget-shell theming". For Material-You-native shells (end-4, caelestia, HyprPanel), the alternative is to let **matugen** own the widget colors (mapping `primary→accent`, `surface→bg`, …) while the engine owns the core surfaces — keep one palette source per run so they stay consistent.

## Pitfalls (cross-toolkit)

- **Notification-daemon conflict.** A full shell's notification service (AGS `Notifd`, Quickshell `Notifications`, swaync) owns the `org.freedesktop.Notifications` D-Bus name — running mako/dunst alongside it means duplicate or swallowed notifications. Pick one.
- **Two bars at once.** If you adopt a full shell that includes a bar, *stop Waybar* (remove its `exec-once`) or you get two bars fighting for the top edge / exclusive zone.
- **Blur is the compositor's job.** GTK *and* QML widgets only frost a translucent surface if a Hyprland `layerrule` blurs that window's layer namespace — same failure mode as Waybar without the blur rule. Set the namespace and `match:namespace`.
- **Chasing an archived project.** HyprPanel (→Wayle) and Ax-Shell (→Ambxst) are frozen, and end-4 left AGS for Quickshell. They're great *visual* references, but don't start a new config on a dead codebase.
- **Picking the heaviest tool for one widget.** If you only want a weather readout or a notification bell, a Waybar `custom/*` module beats standing up a whole QML shell. Match effort to the goal.

## Sources

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

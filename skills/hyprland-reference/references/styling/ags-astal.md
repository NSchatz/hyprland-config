# Styling AGS / Astal

AGS (Aylur's GTK Shell) and **Astal** are how the Hyprland community builds *fully custom desktop shells* — not a status bar you configure, but widgets you program: bars, dashboards/control-centers, notification popups, OSDs, launchers, music players with blurred cover art. Where Waybar is JSONC + a CSS subset, AGS/Astal is JavaScript/TypeScript (or Lua/Python) **plus GTK CSS/SCSS**. This page is about making those widgets *look* good — the SCSS architecture, the material-card / quick-settings-toggle / blurred-album-art techniques — grounded in how end-4, HyprPanel, kotontrion, matshell, and Aylur himself actually do it.

> **Scope note.** This is the *styling* surface. The widget logic (signals, bindings, GObject services) is a programming topic; here we focus on the CSS/SCSS and the visual archetypes the styling produces.

## What you're styling — AGS v1 vs Astal/v2

The single most important thing to get right: **there are two incompatible generations**, and most old tutorials describe v1.

| | **AGS v1** (`Aylur/ags`, ≤ v1.x) | **Astal / AGS v2** (current) |
|---|---|---|
| What it is | A standalone GJS app: a runtime + builtin Services + a `Widget.*` API | `Aylur/astal` = Vala/C **libraries**; `ags` = a scaffolding/bundler **CLI** |
| Language | GJS (JavaScript), TypeScript via types | TS/JS (JSX via "Gnim"), **Lua**, **Python** — anything with GObject introspection |
| Toolkit | **GTK3** only | **GTK3 or GTK4** (you pick the import: `gtk3`/`gtk4`) |
| Entry | `App.config({ style, windows })` | `app.start({ css, main })` |
| Services | Builtin (`Battery`, `Mpris`, `Audio`…) | External libs: `import Battery from "gi://AstalBattery"` |
| Status | **Deprecated.** Rewritten from scratch Nov 2024; "you will have to rewrite your projects from the ground up." | Recommended path. `astal` ~960★, `ags` CLI ~3k★ (June 2026) |

The community migration: through ~2023 everyone used AGS v1 (end-4's illogical-impulse, HyprPanel, kotontrion all started here). In **November 2024** Aylur rewrote the core into Astal (Vala/C libs) and demoted `ags` to a CLI that scaffolds + bundles TS projects. The `astal` namespace was then folded back into `ags`. Two notable post-migration moves: **HyprPanel** ported v1→Astal (its `getting_started/astal.html` guide), and **end-4 left the GTK ecosystem entirely** — illogical-impulse is now **Quickshell** (QML/Qt6), not AGS. The old AGS version survives only on end-4's `ii-ags` branch and is unmaintained.

**The styling itself is GTK CSS either way** — the same subset caveats as Waybar (`../styling/waybar.md`): no flexbox/`gap`/`calc()`, limited `box-shadow`, color helpers `alpha()`/`shade()`/`mix()`/`lighter()`/`darker()`. The win over Waybar is that AGS/Astal **compile SCSS** (nesting, `$variables`, `@mixin`, `@use`, `color.adjust()`), so configs are organized like a real frontend codebase. **GTK4 differs from GTK3**: some node names and properties change (e.g. the CSS class prop is `class`/`className` on GTK3 widgets but **`cssClasses`** on GTK4), and GTK4 drops a few CSS features while adding others — test, don't assume.

## How it's launched (and how SCSS gets compiled)

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

**Astal / AGS v2** — `ags init` scaffolds a TS project (with `app.scss`, `tsconfig`, types); **dart-sass is built in**, so a top-level `app.start({ css: style })` where `style` is a `.scss` path just works. CLI: `ags run`, `ags bundle` (build), and crucially `ags inspect` (the **GTK inspector** — your devtools for finding the CSS node name of any widget). Per-widget styling uses the `class`/`className`/`cssClasses` prop and an inline `css` prop; `App.apply_css(css, true)` re-applies at runtime.

**Reload loop in practice:** `ags inspect` to find a node's name → edit SCSS → save (hot reload recompiles + `resetCss`/`applyCss`) → repeat. There is no `SIGUSR2`; reload is in-process.

## Widget archetypes (what the community actually builds)

These are the recognizable AGS/Astal looks. The bar is the least interesting part — the **dashboard/control-center is the signature AGS aesthetic** (it's what you can't get from Waybar).

- **Top bar.** Workspaces + clock + a system cluster, same logical content as Waybar but styled as one SCSS component (`_bar.scss`). Usually a translucent pill or floating island; often hosts a Hyprland workspace widget with per-monitor coloring.
- **Dashboard / control-center** *(the signature look)*. A large popover panel of **material cards**: a grid of round **quick-settings toggle buttons** (wifi/bt/dnd/airplane — accent-filled when on, surface when off), **sliders** (volume/brightness with a filled trough), a **media card**, a clock/calendar, power-profile selector, and a logout/power row. HyprPanel, matshell (`_system-menu.scss`), and Aylur's own dotfiles all center on this.
- **Notification popups + notification center.** Transient toast stacks (slide-in via revealers) plus a persistent scrollable history panel with a clear-all + DND toggle. Astal's `Notifd` library backs both — *stop mako/dunst/swaync first* or daemons conflict.
- **OSD.** A small centered/edge pill that fades in on volume/brightness/caps-lock change, with an icon + a slider/level bar. (`_osd.scss`.)
- **App launcher.** Fuzzy-search entry over `AstalApps`, results as a vertical list of icon+label rows, often with frecency ranking. Styled like a single rounded search card.
- **Music player with blurred cover-art background** *(the showpiece)*. A card whose background is the album art, **blurred and dimmed**, with crisp controls/title on top via a `Gtk.Overlay`. See the technique below.
- **Calendar / date panel, power menu, bluetooth/wifi/network applets, system tray, workspace/Hyprland overview, on-screen keyboard, dock.** All appear across the corpus; the network/bt applets are nested menus inside the control-center.

## Battle-tested techniques (attributed)

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

**Sliders (volume/brightness).** GTK `scale` widgets expose styleable sub-nodes — names differ by toolkit, find them with `ags inspect`:
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
The TSX uses an `<image cssClasses={["cover"]} contentFit={Gtk.ContentFit.COVER} file={…coverArt…}/>`. Key tactic (matshell, verbatim comment): **force light text on the player** regardless of theme — `label, .title, image { color: $background; }` (in light mode) — "Dark almost never works on top of most cover arts." A CAVA visualizer is layered behind at `opacity: 0.2`.

**Workspaces & per-monitor accent** (matshell `@mixin hypr-workspace-style`): `background: $bg-color; box-shadow: inset -2px -2px 2px <bg darkened 25%>;` with a `:hover` variant — an inset bevel instead of a flat fill. Each monitor gets its own hue mixed from Material You containers (`color.mix($primary_container, $on_primary_container, 70%)`).

**Circular progress (CPU/RAM gauges)** (matshell `@mixin hw-circular-progress`): style the `circularprogress` node's `progress` (the arc, `color: $accent; min-width: 2.3rem;`) and `radius` (the track, `color: alpha($procBg,0.5)`) with a Material Symbols glyph centered. A ring meter you can't build in Waybar.

**Transitions / revealers.** Popups slide/fade via GTK `revealer` (`transition_type`, `transition_duration` on the widget) — the motion is a *widget prop*, not CSS — while CSS handles the easing of color/size via `@mixin animate` (a shared `transition`). Arrow indicators rotate with `transform: rotate(90deg)` (matshell `.arrow-down`) — note `transform` **works** here (GTK4), unlike Waybar's GTK3.

## Theming flow (matugen / Material You)

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

## Pitfalls

- **Following v1 tutorials on a v2 setup (or vice-versa).** `App.config` vs `app.start`, builtin `Service` vs `gi://Astal*` imports, `Variable` vs `createState`, `className` vs `class`/`cssClasses` — the APIs are mutually incompatible. Check which generation a repo targets *before* copying.
- **GTK3 vs GTK4 CSS drift.** Slider/scale node names, the class prop name (`cssClasses` on GTK4), and supported properties differ. `transform`/`filter` work in GTK4 but not GTK3. Always confirm a node's name and styleable parts with `ags inspect` rather than guessing from web CSS.
- **GJS / GObject quirks (v1).** Memory management leaned on GTK3's cascading-destroy; this changed in GTK4 and was a major reason for the rewrite. Long-lived widgets that aren't cleaned up leak.
- **Notification daemon conflicts.** AGS/Astal's `Notifd` *is* the notification daemon — running mako/dunst/swaync alongside it means duplicate or swallowed notifications. Disable the others.
- **Unreadable text over album art.** Cover-art backgrounds vary wildly; don't rely on theme `fg`. Force a fixed light (or dark) text color on the whole player and dim the art (`opacity: 0.8`) — matshell's explicit lesson.
- **`sassc` vs `dart-sass`.** v1 rices shell out to `sassc`; v2 bundles `dart-sass`. They differ on modern features (`@use`, `color.adjust`, math). A v1 `_index.scss` written for dart-sass won't compile under `sassc` and vice-versa.
- **Chasing a dead project.** **HyprPanel was archived April 2026** (→ Wayle) and **end-4 abandoned AGS for Quickshell**. They remain excellent *visual* references, but their code is no longer the place to start a new AGS/Astal shell; prefer current repos (matshell, kotontrion, Aylur's examples, tokyob0t).

## Sources

- AGS CLI (Astal+Gnim scaffolder): https://github.com/Aylur/ags and docs https://aylur.github.io/ags/
- Astal libraries (Hyprland, Notifd, Mpris, Battery, WirePlumber, Bluetooth, Network, Tray, Apps, Brightness, PowerProfiles, Cava, Greet, River): https://github.com/Aylur/astal and https://aylur.github.io/astal/
- AGS v1→v2 migration guide (Service removal, `app.start`, `createState`, `class`): https://aylur.github.io/ags/guide/migration-guide.html
- AGS v1 theming API (`App.config({style})`, `App.applyCss`/`resetCss`, inline `css`, `sassc`, `Utils.monitorFile`): https://aylur.github.io/ags-docs/config/theming/
- AGS v2.0.0 release notes (rewrite, Vala/C core, dart-sass, GTK4): https://github.com/Aylur/ags/releases/tag/v2.0.0
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
- **Soramane** is associated with **caelestia** (`soramanew/caelestia*`), which is **Quickshell-based, not AGS/Astal** — out of scope for this page; included only to correct the attribution.
- The GTK4 slider sub-node names (`trough`/`block`/`filled`) are confirmed from matshell's SCSS; GTK3's (`trough`/`highlight`/`slider`) from the Waybar/AGS-v1 era. Confirm the exact node for *your* toolkit version with `ags inspect`.
- Blur on the album-art layer: matshell sets the art via `background-image` + low opacity; the actual Gaussian blur is applied in-widget (GTK4 effect / pre-blurred image), not via a plain CSS `filter: blur()` (GTK3 has no `filter`). Verify the mechanism against the toolkit you target.

# ags - widgets

Everything this plugin knows about authoring **ags** for the `widgets` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template
- Styling
- Validation
- Gotchas
- Reload

---

## Template


**Template:** `skills/rice/references/components/widgets/ags.tmpl` (renders to `~/.config/ags/colors.scss`).

The template emits the same `$var` set as eww plus a few **semantic aliases** (`$window-bg`,
`$on-window`, `$card-bg`, `$primary`, `$secondary`, `$radius`, `$anim-duration`) so widgets stay
role-agnostic, plus a `@define-color` block (GTK CSS interop with host GTK apps).

**One-time wiring** depends on the SCSS dialect:

- **AGS v1** (sassc): `@import "colors";` at the top of `style.scss`.
- **Astal + Gnim / AGS v3** (dart-sass — bundled into the `ags` CLI's import-time transform):
  `@use "colors" as *;` at the top of `style.scss`.

**Compile + apply:**

```js
// AGS v1 (deprecated, but matches the existing-config path)
const scss = `${App.configDir}/style.scss`
const css  = `/tmp/style.css`
Utils.exec(`sassc ${scss} ${css}`)
App.config({ style: css, windows: [Bar()] })
Utils.monitorFile(`${App.configDir}/scss`, () => {
    Utils.exec(`sassc ${scss} ${css}`)
    App.resetCss()
    App.applyCss(css)
})
```

```ts
// AGS v3 (Astal + Gnim)
import app from "ags/gtk4/app"
import style from "./style.scss"     // bundler inlines as a string
app.start({ css: style, main: () => Bar() })
// optional: a monitorFile that re-reads style.scss and calls app.apply_css()
// is user-written — there is no built-in on-disk watcher in v3's app surface.
```

The rice engine writes `colors.scss`; the v1 `Utils.monitorFile` watcher (or its v3 user-written
equivalent calling `app.apply_css()`) picks up the change and re-themes. That's why the
manifest's reload-cmd is empty — it's the shell's own watcher, not a CLI hook.

**Fonts:** same rule as eww — the family-without-size goes into `style.scss` directly (e.g.
`font-family: "Inter";`); the template is colors only.

**`hyprland.conf` autostart:**

```ini
exec-once = ags run                # AGS v3 — runs the project in $XDG_CONFIG_HOME/ags
# or for v1:
exec-once = ags
```

---

## Styling


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

**The styling itself is GTK CSS either way** — the same subset caveats as Waybar (`../../waybar/styling.md`): no flexbox/`gap`/`calc()`, limited `box-shadow`, color helpers `alpha()`/`shade()`/`mix()`/`lighter()`/`darker()`. The win over Waybar is that AGS/Astal **compile SCSS** (nesting, `$variables`, `@mixin`, `@use`, `color.adjust()`), so configs are organized like a real frontend codebase. **GTK4 differs from GTK3**: some node names and properties change (the underlying `GtkWidget` GTK3 → GTK4 prop is `style-class`/`class-names` → `css-classes`), and GTK4 drops a few CSS features while adding others — test, don't assume. In **AGS v3's Gnim JSX** the attribute name is just **`class`** for both `gtk3` and `gtk4` imports (the v1 attribute name was `className`; the migration guide is explicit: "className -> class").

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

---

## Validation


The Astal / AGS v3 CLI compiles + bundles TypeScript on `ags run` / `ags bundle`; there is
**no documented `--check` / parse-only flag** in v3 — `ags bundle` always emits a bundle (with
an optional `-o /tmp/...` output path), and a TS / SCSS error makes it exit non-zero, which is
what we use for validation. The v1 path (`Aylur/ags` ≤ v1.x) doesn't have a bundle step at all
— fall back to `node --check` on the JS entrypoint plus a `sassc style.scss /dev/null` SCSS
parse.

```bash
# AGS v3 (the plugin's installed version — aylurs-gtk-shell)
cd "$HOME/.config/ags"
ags bundle -o /tmp/ags-validate.js >"$staging/ags-validate.log" 2>&1 || {
  echo "ERROR: ags bundle failed; see $staging/ags-validate.log" >&2
  exit 1
}
rm -f /tmp/ags-validate.js
```

Validator-level checks the rice can run regardless of which generation is installed:

- **The colors-file `$var` names** in `~/.config/ags/colors.scss` are referenced by `style.scss` —
  any rename silently un-themes the shell. Diff the var-name set against
  `_shared/colors-contract.md` → `ags / astal` row.
- **AGS v1 vs v3 class-prop drift.** AGS v1 (GJS / `Widget.*`) used `className`; **AGS v3 (Gnim
  JSX) renamed it to `class`** (see Aylur/ags migration guide → "className -> class"). If a v1
  snippet is pasted into a v3 project, the warning cascades on every widget. The validator can
  grep `className=` against the `ags/gtk4` import line.

---

## Gotchas


`App.config` vs `app.start`, builtin `Service` vs `gi://Astal*` imports, `Variable` vs
`createState`, `className` (v1) vs `class` (v3 Gnim JSX), `sassc` vs dart-sass — the two
generations are **mutually incompatible**. Most existing tutorials and the older famous configs
(end-4's `ii-ags` branch, kotontrion's main config, the v1-era HyprPanel docs) describe **v1**,
which is deprecated. The plugin's `packages.md` installs **AGS v3 (Astal + Gnim)** via
`aylurs-gtk-shell` — copy v3-shape code, not v1.

Check which generation a repo targets *before* copying SCSS or TS snippets. v3's CLI is
`ags init`, `ags run`, `ags bundle`, `ags types` (no `ags inspect` subcommand — open the GTK
Inspector with the `GTK_DEBUG=interactive` env var or via GtkInspector keybind). See Aylur/ags
migration guide for the full delta.

---

## Reload


The manifest line for AGS:

```
ags  ~/.config/hypr-rice/templates/ags.tmpl  ~/.config/ags/colors.scss
```

**No reload command** — but the file-watch is **not free**; the running shell must wire it in
user code. The exact mechanism depends on which generation is installed:

- **AGS v1** — `Utils.monitorFile(\`${App.configDir}/scss\`, () => { Utils.exec("sassc style.scss /tmp/style.css"); App.resetCss(); App.applyCss("/tmp/style.css"); })`.
- **Astal + Gnim / AGS v3** — the `app.start({ css })` field takes a **string** (the AGS docs:
  *"any css or scss file ... inlined as a string"*), so the v1-shaped pattern survives:
  `monitorFile` on the SCSS dir → re-read the file (or shell out to dart-sass) → call
  `app.apply_css(cssString)` / `app.reset_css()` (lowercase v3 methods). There is no automatic
  on-disk SCSS watcher in v3's app surface; the shell config wires it.

In both cases the rice engine relies on the shell's user-written watcher — there is no AGS-side
hook to fire from `rice apply`. If the user is *not* running AGS, the file write is harmless —
`colors.scss` is just a static file until the shell starts and re-reads it.


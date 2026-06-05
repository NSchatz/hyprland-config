# widgets — template

Per-shell wiring. The rice engine doesn't own the shell's own config (`eww.yuck`, `style.scss`,
`shell.qml`) — it owns the **colors file** the shell imports, plus one render-manifest line that
re-themes it on every `rice apply`. This matches every other visual component: the user (or the
shell's installer) writes the look once, the engine re-renders the palette.

The colors-file variable names per shell are the contract — see
[`_shared/colors-contract.md`](../../_shared/colors-contract.md) → `eww` / `ags / astal` /
`quickshell` rows. Renaming a `$var` without updating the shell's stylesheet silently un-themes
that surface.

## Render-manifest lines

TAB-separated `name TAB template TAB output TAB reload-cmd`. The rice skill registers **one** of
these when 7a is one of `eww` / `ags` / `quickshell`; nothing for `hyprpanel` / `turnkey` /
`none`. (Source: `theming/engine.md` → "Widget-shell theming".)

```
eww         ~/.config/hypr-rice/templates/eww.tmpl         ~/.config/eww/colors.scss             eww reload
ags         ~/.config/hypr-rice/templates/ags.tmpl         ~/.config/ags/colors.scss
quickshell  ~/.config/hypr-rice/templates/quickshell.tmpl  ~/.config/quickshell/<name>/Colors.qml
```

Output paths vary per shell layout — an Astal project may want `style/colors.scss`, a Quickshell
config may want `theme/Colors.qml` next to its `qmldir`. Match the shell's actual layout. The
reload command is empty for AGS (the shell's own file-monitor recompiles + `resetCss`/`applyCss`)
and for Quickshell (hot-reloads on file save).

## eww — yuck + SCSS

**Template:** `skills/rice/templates/eww.tmpl` (renders to `~/.config/eww/colors.scss`).

The template emits a flat `$bg / $fg / $surface / $muted / $cursor / $accent / $accent2 / $red /
$green / $yellow / $blue / $magenta / $cyan / $color0..$color15` list of `$key: #hex;` lines.

**One-time wiring in `~/.config/eww/eww.scss`:**

```scss
@import "colors";

.bar {
  background-color: $bg;
  color: $fg;
}

.dashboard .card {
  background-color: rgba($surface, 0.85);   // rgba, NOT alpha() — see gotchas.md
  border-radius: 16px;
  color: $fg;
}

.workspace-active { color: $accent; }
.cpu_bar scale trough highlight { background-color: $accent; }
```

**Fonts:** the rice skill writes the bare font family into `eww.scss` directly (e.g.
`font-family: "Inter";`) — the `font_ui` / `font_mono` keys in `palette.conf` carry a trailing
size that a CSS `font-family` must not include. The template is colors only.

**`hyprland.conf` autostart** (added by the `autostart` component, not this one):

```ini
exec-once = eww daemon
exec-once = eww open bar          # or eww open-many bar music dashboard
```

**Toggle binds** land in `keybinds` — e.g. `bind = $mainMod, D, exec, eww open --toggle dashboard`.

## AGS / Astal — TS/JS + SCSS

**Template:** `skills/rice/templates/ags.tmpl` (renders to `~/.config/ags/colors.scss`).

The template emits the same `$var` set as eww plus a few **semantic aliases** (`$window-bg`,
`$on-window`, `$card-bg`, `$primary`, `$secondary`, `$radius`, `$anim-duration`) so widgets stay
role-agnostic, plus a `@define-color` block (GTK CSS interop with host GTK apps).

**One-time wiring** depends on the SCSS dialect:

- **AGS v1** (sassc): `@import "colors";` at the top of `style.scss`.
- **Astal / AGS v2** (dart-sass, built into the `ags` CLI): `@use "colors" as *;` at the top of
  `style.scss`.

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
// Astal / AGS v2
import app from "ags/gtk4/app"
app.start({ css: `${SRC}/style.scss`, main: () => Bar() })
```

Either way the shell's file-monitor watches the SCSS dir; the rice engine writes `colors.scss` and
the next file-system event triggers the recompile — that's why the manifest's reload-cmd is empty.

**Fonts:** same rule as eww — the family-without-size goes into `style.scss` directly (e.g.
`font-family: "Inter";`); the template is colors only.

**`hyprland.conf` autostart:**

```ini
exec-once = ags run                # Astal / v2 — runs the project in $XDG_CONFIG_HOME/ags
# or for v1:
exec-once = ags
```

## Quickshell — QML

**Template:** `skills/rice/templates/quickshell.tmpl` (renders to
`~/.config/quickshell/<name>/Colors.qml`).

The output **is** a QML singleton — `pragma Singleton`, an `import QtQuick`, and a `QtObject {}`
with `readonly property color bg: "#..."`, `... accent: "#..."`, a `term[16]` array of the
color0..color15 hex strings, `fontUi` / `fontMono` strings (bare family), and `radius` /
`animDuration` int properties.

**One-time wiring** — register the singleton in `qmldir`:

```
singleton Colors Colors.qml
```

(Or rely on the `pragma Singleton` line and `import "."` from sibling QML files.)

**Reference everywhere** as `Colors.accent`, `Colors.bg`, etc. — never literal hex:

```qml
import QtQuick
import Quickshell

PanelWindow {
    color: "transparent"
    WlrLayershell.namespace: "quickshell:bar"
    Rectangle {
        anchors.fill: parent
        color: Colors.bg
        radius: Colors.radius
        Text {
            text: "12:30"
            color: Colors.fg
            font.family: Colors.fontUi
        }
    }
}
```

**Fonts:** the rice skill writes `fontUi` / `fontMono` into the template as the bare family
(stripping the size from `font_ui` / `font_mono` in `palette.conf`) — Qt's `font.family` is the
family string, not a "family + size" composite. Size lives on `font.pixelSize`, which a Quickshell
config sets per-widget.

**Reload:** none. Quickshell loads changes as soon as the file is saved — re-rendering `Colors.qml`
repaints the whole shell.

**`hyprland.conf` autostart:**

```ini
exec-once = qs -c <name>           # or `qs -p ~/.config/quickshell/<name>/shell.qml`
```

For turnkey shells the command is the project's own: `caelestia shell -d`, `dms run`,
`noctalia-shell`.

## HyprPanel (no rice template)

HyprPanel owns its colors via a **GUI** (Dashboard → gear icon) and a JSON `theme.*` block — the
rice skill does **not** register a manifest line for it. Theming path:

- Install `hyprpanel` (AUR — see `packages.md`).
- Add `exec-once = hyprpanel` to `hyprland.conf` (autostart component).
- For Material-You-on-wallpaper: install `matugen`, point it at the wallpaper, enable
  `Theming > Matugen Settings` in the HyprPanel GUI. The rice skill writes a matugen config
  pointing at the current wallpaper; on every theme switch the wallpaper changes and HyprPanel
  re-themes.
- For a static palette: import a `.json` theme via `Theming > General Settings > Import/Export` —
  one-time, no rice-engine integration.

Same model for the other Material-You-native shells (end-4, caelestia) and for any turnkey shell:
let matugen own colors while palette.conf still owns every other app. **Keep one palette source per
run** so they stay consistent — see `gotchas.md`.

## Turnkey shells (no rice template)

The project's own installer lays out its config (typically `~/.config/quickshell/<project>/`).
Once installed, autostart is the project's command (`caelestia shell -d`, `dms run`, …) and
theming is matugen-driven per above.

The rice skill **does not** hand-theme a turnkey shell. It does:

- Add the package to the install batch (see `packages.md`).
- Add `matugen` to the install batch.
- Write a matugen config that re-runs on every `rice apply` against the current wallpaper.
- Warn the user that the plugin's per-app theming yields to the shell's own (the shell's bar,
  notifications, launcher, etc., use *its* palette, not the engine's).

## Cross-references

- Engine manifest + the broader theming pipeline → `theming/engine.md`
- Per-shell colors-file variable names → `_shared/colors-contract.md`
- Palette source of truth → `_shared/palette-schema.md`
- eww / AGS / Quickshell design techniques → `styling.md`
- The full-shell-replaces-waybar rule and the notifications conflict → `gotchas.md`
- Reload mechanics per shell → `reload.md`

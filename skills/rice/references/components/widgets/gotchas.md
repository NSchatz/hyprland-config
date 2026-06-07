# widgets — gotchas

## A full shell REPLACES waybar — drop the waybar `exec-once`

When `widgets.system` is `ags`, `quickshell`, `hyprpanel`, or `turnkey`, the shell owns its own
bar. Running waybar alongside means two bars fighting for the same exclusive zone — both reserve
space at the top edge, one wins the layer, the other floats in a half-broken state. The visible
symptom is duplicated clocks / workspace indicators and tiled windows shoved into the wrong region.

**Fix:** when `widgets.system` is anything other than `none` or `eww`, **remove** `exec-once =
waybar` from `hyprland.conf` (or never write it in the first place). The autostart component reads
`widgets.system` and gates the waybar line:

```bash
A="${CLAUDE_PLUGIN_ROOT}/scripts/answers.py"
sys="$(python3 "$A" get answers.json widgets.system)"
if [ "$sys" != "none" ] && [ "$sys" != "eww" ]; then
  # full shell owns the bar — skip waybar
  :
else
  echo "exec-once = waybar" >> hyprland.conf
fi
```

Only **eww** (the toolkit, not the panel) pairs *with* waybar — eww is for floating widgets that
sit next to a separate bar. Every other widget pick replaces the bar.

## Widget shells may own notifications — set group 9 to `none`

A full shell's notification service is the notification daemon. AGS exposes `Notifd`, Quickshell
exposes `Quickshell.Services.Notifications`, DankMaterialShell ships one out of the box, and
HyprPanel handles notifications via its own AGS-backed widget. All four claim the
`org.freedesktop.Notifications` D-Bus name — the same name mako / dunst / swaync need. Running
both means duplicate or swallowed notifications (whichever daemon wins the name-acquire race owns
them; the loser sees nothing).

**Fix:** when `widgets.enabled` includes `notification-center` **and** `widgets.system` is a full
shell, set `notifications.daemon = "none"` (the notifications component's gate). The notifications
component reads `widgets.{system,enabled}` and short-circuits its own interview:

```bash
A="${CLAUDE_PLUGIN_ROOT}/scripts/answers.py"
sys=$(python3 "$A" get answers.json widgets.system)
case "$sys" in
  ags|quickshell|hyprpanel|turnkey)
    if python3 "$A" list answers.json widgets.enabled | grep -qx notification-center; then
      bash "${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh" answers.json notifications.daemon none
    fi ;;
esac
```

The user is told *why* the daemon defaulted to `none` in the review pass.

## HyprPanel and Material-You-native shells drive via **matugen**, not the rice manifest

HyprPanel ships a **GUI theming dialog** + `.json` theme import; end-4 / caelestia / Noctalia /
DankMaterialShell ship their own Material 3 → Colors singleton pipelines. They don't read a rice
template. Trying to register one means two palette sources fighting — one from the engine
(`palette.conf`-driven), one from the shell's own (matugen / `.json` / wallpaper-extracted).

**Fix:** when `widgets.system` is `hyprpanel` / `turnkey` (or when `widgets.look == material-you`
for any shell), the engine **does not** register a widget manifest line. Instead it:

1. Adds `matugen` to the install batch (see `packages.md`).
2. Writes `~/.config/matugen/config.toml` pointing at the active wallpaper.
3. On every `rice apply` (theme switch), re-runs matugen against the new wallpaper so the shell
   re-themes itself.
4. Keeps `palette.conf` driving every other component — terminal, waybar (if still running),
   launcher, hyprlock, GTK — so the desktop stays coherent.

**Warn the user:** the shell's bar / notifications / launcher use *its* palette, which may
visibly differ from waybar / kitty / rofi if both are running. The cohesion point is the
wallpaper — pick one matugen-driven wallpaper and the shell's palette stays aligned to the
engine's named-scheme picks within rounding error.

## OSD owner: pick exactly one (defect #13)

Two of the rice's components can render volume / brightness OSDs: the widget shell
(`widgets.enabled ∋ OSD`) and `swayosd` (`utilities.osd_route == swayosd`). When the user
opts in to both, both render the same key-press, the two OSDs flicker over each other on top
of the bar, and the rice "feels broken." The interview-time check that prevents this:

```bash
A="${CLAUDE_PLUGIN_ROOT}/scripts/answers.py"
osd_widget="$(python3 "$A" list answers.json widgets.enabled | grep -qFx 'OSD (volume / brightness)' && echo 1 || echo 0)"
osd_route="$(python3 "$A" get answers.json utilities.osd_route)"
if [ "$osd_widget" = "1" ] && [ "$osd_route" = "swayosd" ]; then
    # Conflict — ask the user which one should own OSDs (in_shell:in-shell or swayosd:swayosd),
    # then drop the other:
    #   if they pick "shell OSD" → record utilities.osd_route = in-shell (route to shell IPC)
    #   if they pick "swayosd" → remove OSD from widgets.enabled
    : # (handled in the rice-skill orchestrator, not silently — see SKILL.md A1)
fi
```

The orchestrator (`SKILL.md` A1, after the review pass) runs this check. When it fires, it
asks the user — *don't* silently drop one side. Defaults if the user has no preference: prefer
the widget shell's OSD when `widgets.system` is a "full shell" (ags/quickshell/hyprpanel/turnkey,
which can't easily relinquish OSD rendering); prefer swayosd when `widgets.system` is `eww`
(eww's OSD is opt-in, not the shell's responsibility).

The notification-daemon-OSD route (`utilities.osd_route == "notification"`) doesn't conflict
with widget-shell OSDs — they fire at different points in the pipeline — so no check is
needed there.

## eww quirks — `grass`-SCSS pitfalls

eww compiles SCSS via the **grass** engine, *not* dart-sass. Two pitfalls bite every new eww
config:

- **`alpha($color, 0.8)` errors and the whole `eww.scss` fails to compile** — the widget renders
  completely **unstyled**. grass's `alpha()` takes **one argument only** (it *reads* a color's
  alpha; it doesn't set it). Use **`rgba($accent, 0.8)`** for a translucent color instead. This is
  the single most common eww styling bug. The plugin's `eww.tmpl` doesn't emit any `alpha()`
  calls; user-written `eww.scss` must follow the same rule.
- **`:height "auto"` (and `:width "auto"`) on `defwindow :geometry` is invalid** — eww errors
  *"Failed to parse 'auto' as a length value"* and the window won't open. There is no `auto`; use
  a concrete length like `:height "520px"` or `:height "60%"`.

Other eww traps worth knowing:

- **`width`/`height` in CSS silently do nothing** — GTK ignores them. Size via yuck geometry or
  `min-width` / `min-height` in CSS.
- **Blur applies to the whole `defwindow` surface, not individual cards** — eww is one
  `gtk-layer-shell` layer per window. To blur some cards and not others, split them into separate
  `defwindow`s with separate `:namespace`s.
- **`:exclusive` needs a centered anchor** — only reserves space when `:anchor` includes `center`
  along the long axis; otherwise windows overlap the bar.
- **Forgetting `:namespace`** — without it, the layer name is autogenerated and your `layerrule
  match:namespace` won't match. Set it explicitly (`:namespace "eww-bar"`) and verify with
  `hyprctl layers`.
- **Hardcoded `@import` paths** — some shipped configs use `@import "/home/USER/.config/eww/colors"`;
  these break on copy. Use relative `@import "colors";`.

See `styling.md` → `## eww` → "Pitfalls" for the full list.

## AGS / Astal — v1 vs v2 incompatibility

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

## Quickshell — heavy build, transparent-window gotchas

Quickshell pulls in Qt 6 (QtQuick, Qt Quick Effects, Qt Quick Shapes, often QtMultimedia +
PipeWire). On Arch the AUR package builds from source — that's **real build time** at install:
20–40 minutes on a modest CPU, longer on a laptop. Warn the user before the install batch starts:
that's a long single package compared to everything else in the batch.

QML / Quickshell gotchas worth surfacing:

- **The `Colors` / `Theme` singleton's root must be Quickshell's `Singleton` type**, not a plain
  `QtObject`. Quickshell registers the singleton via its core `Singleton::componentComplete()` and
  prints *"Tried to register singleton … which is not the root component of its file"* when the
  root isn't `Singleton` (`quickshell-mirror/quickshell` → `src/core/singleton.cpp`). The visible
  symptom isn't a hard error — the file *parses* (QtObject is valid QML), but Quickshell skips
  registration, so `import qs.<dir>` consumers see the singleton as undefined and every
  `Colors.<key>` reference fails silently. Verified across caelestia (`services/Colours.qml`),
  end-4 (`modules/common/Appearance.qml`), DankMaterialShell (`Common/Theme.qml`), and noctalia
  (`Commons/Color.qml`). The previous `quickshell.tmpl` used `QtObject`; fixed.
- **A layer-shell window can't be rounded** — `PanelWindow { color: "transparent" }` with an inner
  `Rectangle { radius: 16; color: Colors.surface }` is *the* idiom for a rounded panel.
- **Blur is not a QML property** — there's no `backdrop-filter`. A translucent panel only frosts
  via a Hyprland `layerrule { match:namespace = quickshell:*; blur = true; ... }`.
- **QTBUG-137166** — a transparent `Rectangle` *with* a border renders **invisible**. Add
  `border.width: 0` or set border props explicitly as the workaround.
- **Effects modules must be installed** — `MultiEffect` / `RectangularShadow` silently fail to
  load without Qt Quick Effects.
- **`Loader` / `LazyLoader` for rarely-shown surfaces** — a do-everything shell with many
  always-built windows is heavy. Wrap the dashboard / launcher / overview in `Loader` so they
  build only when shown.

See `styling.md` → `## Quickshell` → "Pitfalls" for the full list.

## Heavy shells take real build time at install — warn the user

`quickshell`, `aylurs-gtk-shell` (and any turnkey shell that builds from source) all pull in Qt /
GTK toolchains and compile out-of-band. On Arch via `yay -S quickshell-git` or `paru -S
hyprpanel`, expect tens of minutes — much longer than every other package in the install batch
combined. Surface this in the install-step preamble so the user doesn't think the installer hung.

```text
Warning: quickshell-git builds Qt 6 + Qt Quick Effects from source.
Expect 20–40 minutes on this CPU. The install continues automatically.
```

Same applies to `caelestia`, `noctalia-shell`, `dms` (DankMaterialShell), end-4's installer — they
all do a Quickshell build on first run.

## Wallpaper-driven theming needs a wallpaper tool that survives theme switches

`widgets.look == material-you` reads the *current* wallpaper. If the wallpaper is set with a
one-shot command (`swww img …` without a daemon, or a hyprpaper `preload` that never reloads), the
matugen run keys off a stale path. Make sure the `autostart` component picks a wallpaper tool with
a persistent daemon (`swww-daemon` or `hyprpaper`) so the wallpaper-set / matugen-run sequence is
deterministic on every `rice apply`.

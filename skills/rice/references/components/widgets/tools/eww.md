# eww - widgets

Everything this plugin knows about authoring **eww** for the `widgets` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template
- Validation
- Gotchas
- Reload

---

## Template


**Template:** `skills/rice/references/components/widgets/eww.tmpl` (renders to `~/.config/eww/colors.scss`).

**Data helpers (shipped):** the eww `defwidget`s reference shell scripts that emit JSON for
`(deflisten)` / `(defpoll)` blocks. These scripts ship under
`${CLAUDE_PLUGIN_ROOT}/skills/rice/assets/scripts/eww/` and the installer copies them to
`~/.config/eww/scripts/`, `chmod +x`. The contract for each script lives in
[`_shared/helper-scripts.md`](../../../../_shared/helper-scripts.md):

| Script | Path under eww | Emits | Runtime deps |
|---|---|---|---|
| `sysinfo` | `~/.config/eww/scripts/sysinfo` | `{cpu, mem, mem_used_mb, mem_total_mb, swap, temp_c, disk, uptime}` | `/proc`, `awk` (always), `sensors` (optional) |
| `audio`   | `~/.config/eww/scripts/audio`   | `{vol, mute, mic, mic_mute, brightness, source}` plus `vol+/vol-/vol-toggle/mic-toggle/bright+/bright-` actions | `wpctl` or `pactl`; `brightnessctl` optional |
| `player`  | `~/.config/eww/scripts/player`  | `{status, title, artist, album, art_url, art_local, length_us, position_us, progress, player_name}` plus `toggle/next/prev` actions | `playerctl`; `curl` (cover-art download) |
| `toggles` | `~/.config/eww/scripts/toggles` | `{wifi, bt, dnd, mic_mute}` plus `wifi/bt/dnd/mic` toggle actions | `nmcli`, `bluetoothctl`, `swaync-client`/`makoctl`/`dunstctl`, `wpctl`/`pactl` |

Wire them via `defpoll` (one-shot, low-rate) or `deflisten` (long-running with `--watch`):

```yuck
(defpoll sysinfo  :interval "2s" "~/.config/eww/scripts/sysinfo")
(deflisten audio  "~/.config/eww/scripts/audio --watch")
(deflisten player "~/.config/eww/scripts/player --watch")
(defpoll  toggles :interval "5s" "~/.config/eww/scripts/toggles")
```

The widgets writer must:

1. **Stage the eww scripts** alongside `eww.yuck` / `eww.scss` (the rice installer copies them
   into `~/.config/eww/scripts/` and `chmod +x`s them — see
   `_shared/helper-scripts.md` and `components/widgets/packages.md`).
2. **Reference the canonical paths** above in the yuck templates the writer ships. Hard-coded
   `/home/USER/.config/eww/scripts/...` paths break on first reinstall; use `~/.config/`.
3. **Declare the helper-script runtime deps** in the install batch so the scripts actually work
   on first boot (`wpctl` ships with `wireplumber`; `brightnessctl`, `playerctl`, `nmcli`, `bluetoothctl`
   are repo packages).

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

---

## Styling


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

Then blur that namespace (0.54.x block form — see `../../window-rules/template.md`):

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

---

## Validation


eww's CLI doubles as a linter — yuck and SCSS errors surface on any `eww` command (not just
`reload`). The cleanest no-side-effect check is to ask the daemon to parse the config without
opening any windows:

```bash
# Parse-only: eww logs errors to stderr and exits non-zero on parse failure.
EWW_CONFIG_DIR="$staging/eww"  eww --restart inspector --close
# or simpler — let `eww reload` do the parse and discard its output:
EWW_CONFIG_DIR="$staging/eww" eww reload 2>&1 | tee "$staging/eww-validate.log"
```

Treat a non-zero exit as a hard fail. The two recurring categories per `gotchas.md` →
"eww quirks":

- **`alpha($color, 0.8)` errors** (grass SCSS — one-arg only). Message includes "Only 1 argument
  allowed, but 2 were passed". Fix: use `rgba($color, 0.8)`.
- **`:height "auto"` errors.** Message: "Failed to parse 'auto' as a length value". Fix: use a
  concrete length.

A handy assertion the validator can run pre-reload:

```bash
if grep -RE 'alpha\([^,]+,[^)]+\)' "$staging/eww/"*.scss; then
  echo "ERROR: alpha() with two args — use rgba() (grass-SCSS pitfall)" >&2
  exit 1
fi
if grep -RE ':(height|width) +"auto"' "$staging/eww/"*.yuck; then
  echo "ERROR: :height/:width 'auto' — use a concrete length" >&2
  exit 1
fi
```

### Boolean-typed `deflisten` / `defpoll` must have a safe default

eww rejects opening a window whose `:visible` / `:reveal` / any other boolean-typed prop is
bound to an uninitialized `deflisten` / `defpoll`. Until the first stdout line arrives, the
var is `none`; binding `none` to a `bool` field surfaces as a parse error at `eww open <window>`
time. The canonical defect is the music window — a `(deflisten playing "playerctl status -F")`
that hasn't produced a line yet leaves `playing` as `none`; `defwindow music :visible playing`
refuses to open.

Two safe-default idioms; either is enough (use them together for belt-and-braces):

1. **Initialize the var to a literal at declaration time**, so the first read is always a real
   string/bool. eww accepts an inline default on the deflisten/defpoll form:

   ```yuck
   (deflisten playing :initial "false"   "~/.config/eww/scripts/player --watch | jq -r '.status==\"Playing\"'")
   (defpoll   has_net :initial "false"   :interval "5s"  "~/.config/eww/scripts/toggles | jq -r '.wifi'")
   ```

2. **Coerce at the use site** with `(playing ?: "false")` — eww's `?:` returns the right side
   if the left is `none`/empty:

   ```yuck
   (defwindow music :visible {playing ?: "false"} ...)
   ```

Both forms convert the empty-stdout window into a deterministic `false` instead of `none`. Watch
particularly for `playerctl`-driven props: the helper may exit immediately if no player is on the
bus, so the listener emits nothing on first run.

A validator grep that surfaces every unprotected boolean-typed listener:

```bash
# Flag any deflisten / defpoll without :initial whose name is used in a :visible / :reveal /
# :show / :active / :checked / :enabled / any *-toggle attribute. False positives are cheap;
# missing this defect leaves a window unopenable.
python3 - "$staging/eww/eww.yuck" <<'PY'
import re, sys
src = open(sys.argv[1]).read()
bool_attrs = r'(?::visible|:reveal|:show|:active|:checked|:enabled|:toggle)'
listeners = {}
for m in re.finditer(r'\((deflisten|defpoll)\s+(\w+)([^)]*)\)', src, re.DOTALL):
    has_initial = ':initial' in m.group(3)
    listeners[m.group(2)] = has_initial
bad = []
for m in re.finditer(rf'{bool_attrs}\s*[{{"]?\s*(\w+)', src):
    nm = m.group(1)
    if nm in listeners and not listeners[nm]:
        if f'{nm} ?:' not in src and f'{nm}?:' not in src:
            bad.append(nm)
if bad:
    print(f"ERROR: boolean-typed vars without :initial or `?:` default: {sorted(set(bad))}",
          file=sys.stderr)
    sys.exit(1)
PY
```

### Dry-run each declared window

eww doesn't surface every parse error until the specific window is opened. The validator can
ask the daemon to open and immediately close each `defwindow` against the staged config:

```bash
# Discover defwindow names and dry-run each one.
EWW_CONFIG_DIR="$staging/eww" eww --restart daemon >/dev/null 2>&1
for win in $(awk '/^\(defwindow/ {print $2}' "$staging/eww/eww.yuck"); do
  EWW_CONFIG_DIR="$staging/eww" eww open "$win"  || { echo "ERROR: eww open $win failed" >&2; exit 1; }
  EWW_CONFIG_DIR="$staging/eww" eww close "$win" >/dev/null 2>&1
done
EWW_CONFIG_DIR="$staging/eww" eww kill >/dev/null 2>&1
```

This catches the bool-default class for every window, not just the music one.

---

## Gotchas


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
- **Boolean-typed `deflisten` / `defpoll` need a safe default** — until the first stdout line
  arrives, the var is `none`, and binding `none` to `:visible` / `:reveal` / any other bool prop
  refuses to open the window with a `bool` parse error. The canonical defect is the music window
  bound to a `playerctl --follow` listener that hasn't emitted yet (no media player on the bus →
  empty stdout → `none`). Fix at declaration with `:initial "false"`, or at the use site with
  `(playing ?: "false")` — `?:` returns the right side when the left is `none`. The validator
  (`validation.md` → "Boolean-typed deflisten / defpoll must have a safe default") greps for
  unprotected bindings and a dry-run open of each defwindow surfaces the failure deterministically.

See `styling.md` → `## eww` → "Pitfalls" for the full list.

---

## Reload


The manifest line for eww:

```
eww  ~/.config/hypr-rice/templates/eww.tmpl  ~/.config/eww/colors.scss  eww reload
```

`eww reload` recompiles the SCSS and re-renders every open window. It does **not** restart the
daemon, so deflisten subscriptions and defpoll state are preserved — exactly the behavior gh0stzk
relies on for instant theme-switching.

Idempotency / guard:

```bash
if pgrep -x eww >/dev/null; then
  eww reload || true
fi
```

(`|| true` because eww returns non-zero if the daemon is in a wedged state — better to surface
that via the validator than to fail the whole `rice apply`.)

If the SCSS fails to compile (e.g. the `alpha($c, 0.8)` pitfall — see `gotchas.md`), `eww reload`
prints the grass error to stderr and the **widgets render unstyled**. The validator (`validation.md`)
greps for these patterns before the hook fires.


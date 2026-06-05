# Styling eww

eww (ElKowar's Wacky Widgets) is a standalone, GTK3-backed widget toolkit. Unlike Waybar (a fixed-purpose status bar), eww hands you raw GTK widget primitives and a layout language, so the community builds *anything* with it: bars, dashboards, sidebars, launchers, OSDs, music players, power menus. The cost of that freedom is that every rice is bespoke — there's no `modules-left`, only the boxes you wire yourself. This page is about making those widgets *look* good, grounded in how adi1090x, gh0stzk, dharmx, dwt1 and others actually do it. For the *cross-toolkit* picture (eww vs AGS vs Quickshell vs a turnkey panel) read [`widgets.md`](widgets.md) first.

## What you're styling

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

## How it's launched

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

Then blur that namespace (0.54.x block form — see `../window-rules.md`):

```conf
layerrule {
    name = blur-eww
    match:namespace = eww-bar
    blur = true
    ignore_alpha = 0.2
}
```

Confirm the name with `hyprctl layers` (look for `namespace: eww-bar`). Note the **whole-surface caveat**: eww renders one layer surface per window, so Hyprland blurs the *entire window region*, not individual cards. To blur some elements but not others, split them into separate `defwindow`s with separate namespaces ([Hyprland Discussion #748](https://github.com/hyprwm/Hyprland/discussions/748)). `:focusable "none"` keeps a bar from stealing keyboard focus; a launcher/power-menu wants `"exclusive"` or `"ondemand"`.

## Widget archetypes

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

## Battle-tested techniques (attributed)

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

## Palette / theming flow

eww's SCSS compilation makes palette-swapping clean, and the community standard is to **generate a colors partial and `@import` it**:

1. A generator writes a colors partial — pywal (`~/.cache/wal/colors.scss`) or **matugen** (template → `~/.config/eww/colors.scss`). Many configs run both and `@import` the result.
2. `eww.scss` starts with `@import "colors";` and references `$color0..$color15`, `$background`, `$foreground` (pywal names) or the rice keys — never hardcoded hex.
3. Re-theme with `eww reload` (recompiles SCSS in place; no daemon restart). gh0stzk's theme selector swaps the colors partial and reloads so all eww widgets re-skin instantly *without* restarting eww — preserving the daemon and avoiding flicker.

**For the rice engine here**, render a `~/.config/eww/colors.scss` of `$key: #hex;` lines from the palette contract (`$bg $fg $surface $accent $accent2 $red …`), `@import` it at the top of `eww.scss`, and re-skin with `eww reload`. The engine ships an `eww.tmpl` for exactly this (registered in the manifest when eww is chosen — see `rice/references/engine.md` → "Widget-shell theming").

## Pitfalls

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

## Sources

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
- **end-4/dots-hyprland** is sometimes associated with eww in *older* references but migrated to AGS, then Quickshell — it is *not* an eww config today; don't cite it for eww `.scss` technique (see [`quickshell.md`](quickshell.md)).
- The `circular-progress` detail (font-size → inner radius; `color` → ring) is synthesized from the widget docs (`:thickness`, the color-property convention) plus community usage — worth a quick confirm against a live config.
- Star counts read on the research date drift over time.

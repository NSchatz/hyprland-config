# notifications - common

Cross-tool content for the `notifications` surface: what holds no matter which tool was picked.
Read this **plus** the one `tools/<your-tool>.md` the interview selected.

## Contents

- Template
- Validation
- Gotchas
- Reload

---

## Template


Per-daemon recipes. The rice engine renders the **colors** portion from `palette.conf` via
`_shared/colors-contract.md`; the rest of the config is emitted by this component's writer from the
`notifications.*` answers. Every literal color shown below as `#{{accent}}` etc. is engine-rendered
— **never hardcode hex** in this component's output.

For the full styling library (anatomy, urgency conventions, swaync widget patterns,
battle-tested moves), see `styling.md`.

## What does NOT belong here

- The `exec-once = <daemon>` line. That's `components/autostart/`.
- The DND-toggle bind (`bind = $mainMod, N, exec, makoctl mode -t do-not-disturb` etc.). That's
  `components/keybinds/`, gated on `"dnd-bind" ∈ notifications.behavior`.
- The swaync `layerrule` blur block. That's `components/window-rules/`.
- The waybar `custom/notification` module. That's `components/waybar/`, gated on
  `notifications.daemon == "swaync"`.
- The rice-rendered colors file content. That's `theming/engine.md` + the per-daemon `.tmpl`.

---

## Styling


Notifications are the most-seen transient surface on a Wayland desktop — a toast that pops for a few
seconds dozens of times a day. Getting them to *match the rice* (same accent, same radius, same
font as the bar and launcher) is one of the highest-impact, lowest-effort styling wins. This page
covers the three daemons people actually use under Hyprland — **mako** (INI), **dunst** (INI), and
**swaync** / SwayNotificationCenter (JSON behaviour + GTK CSS) — with concrete, current
(2024-2026) values and a tasteful default recipe for each.

All three speak the freedesktop notification spec, so they are drop-in alternatives. Pick one. mako
is the minimal Wayland-native choice, dunst the maximally-tweakable veteran, swaync the one with a
full slide-out notification *center* panel (DND toggle, sliders, MPRIS) for a "shell" feel.

## What you're styling

| Daemon   | Config file(s)                                                   | Styling language                  | Reload |
|----------|------------------------------------------------------------------|-----------------------------------|--------|
| **mako**   | `~/.config/mako/config`                                          | INI-like; styling keys + `[criteria]` sections | `makoctl reload` |
| **dunst**  | `~/.config/dunst/dunstrc`                                        | INI; `[global]` + `[urgency_*]` + rule sections | `dunstctl reload` (or `killall dunst` and let D-Bus respawn) |
| **swaync** | `~/.config/swaync/config.json` **and** `~/.config/swaync/style.css` | `config.json` = behaviour/widgets; `style.css` = **GTK CSS** | `swaync-client -rs` (reload CSS), `swaync-client -R` (reload config) |

Notes:

- mako and dunst draw notifications themselves, so *all* look-and-feel lives in their one config
  file as plain keys (`background-color`, `border-radius`, …). No separate stylesheet.
- swaync is a GTK app. Its colours, radii, and shadows come from `style.css` (GTK4 CSS dialect, not
  web CSS — it supports `@define-color`, GTK named widgets, and a subset of properties). The
  default lives at `/etc/xdg/swaync/style.css`; copy it to `~/.config/swaync/style.css` to edit
  without root. `config.json` controls the **notification center panel** (its widgets, DND, MPRIS)
  and a few behaviours — the panel is styled by the *same* `style.css` via different selectors
  (`.control-center`, `.widget-dnd`, sliders).
- swaync needs its daemon running (`exec-once = swaync`) and a GTK stack present; it is not a
  self-contained binary like mako/dunst.

## Design anatomy — the knobs that change the look

**Placement.** Where toasts appear and how long they live.

| Concept            | mako                          | dunst                                 | swaync (config.json / CSS)               |
|--------------------|-------------------------------|---------------------------------------|------------------------------------------|
| Anchor / corner    | `anchor=top-right`            | `origin=top-right`                    | `positionX`/`positionY` (`right`/`top`)  |
| Offset from edge   | `margin=10`                   | `offset=(10, 50)`                     | CSS `margin` on `.notification-row`      |
| Default lifetime   | `default-timeout=5000` (ms)   | `timeout=5` per-urgency (s)           | `timeout` / `timeout-critical` (s)       |
| Max on screen      | `max-visible=5`               | (stacks until full)                   | panel scrolls                            |

**The card shape.** This is what reads as "designed."

- **Border / accent:** `border-size` (mako) / `frame_width` (dunst) — usually `2`. The frame colour
  is the cheapest place to inject your accent. swaync uses a CSS `border` on `.notification`.
- **Corner radius:** `border-radius` (mako) / `corner_radius` (dunst) / `border-radius` in CSS
  (swaync). Community norm is **8-12 px**.
- **Padding:** `padding` (mako/dunst) / CSS padding (swaync). **12-16 px** breathes; the daemon
  defaults (5-8) feel cramped.
- **Size:** `width`/`height` (mako, px) / `width`/`height` (dunst) / CSS `min-width` on the row
  (swaync). Typical width **300-380 px**; height is usually a max that grows to fit.

**Colour.** Three roles, palette-driven:

- **Background** — your `surface`, almost always with alpha for a translucent card. mako/dunst take
  an 8-digit hex `#RRGGBBAA`; `ee`≈93%, `e6`≈90%, `cc`≈80% opacity. swaync uses
  `rgba()`/`alpha()` in CSS.
- **Text** — your `fg` (`text-color` / `foreground` / CSS `color`).
- **Accent** — most rices put it on the **border** (`border-color` / `frame_color`). A second
  popular idiom is a **left urgency bar**: a thick colored left border (e.g. `border-radius` +
  asymmetric `frame_width`, or in swaync CSS a `border-left: 3px solid @accent`).

**Urgency levels** (low / normal / critical) let you recolor per priority:

| Urgency  | mako                       | dunst                  | swaync (CSS)                          |
|----------|----------------------------|------------------------|---------------------------------------|
| low      | `[urgency=low]` section    | `[urgency_low]`        | `.notification.low`                   |
| normal   | `[urgency=normal]`         | `[urgency_normal]`     | `.notification.normal`                |
| critical | `[urgency=critical]`       | `[urgency_critical]`   | `.notification.critical`              |

The near-universal convention: **critical = red border** (and often a no-timeout, so it persists
until dismissed).

**Icons & progress.** App icons sit left by default (`icon-location`/`icon_position`). Cap them —
`max-icon-size=48` (mako) / `max_icon_size=48` (dunst) — oversized icons are the #1 ugliness.
Volume/brightness OSD tools send a progress hint; style it via `progress-color` (mako),
`progress_bar_*` (dunst), or `progressbar`/`trough` selectors (swaync).

**Typography.** Set `font` to your UI font (`{{font_ui}}`). If your `format` includes glyph icons
(e.g. an app glyph in the summary), use a **Nerd Font** so they render. Pango syntax: `font=Inter
11` (mako/dunst). swaync uses CSS `font-family`/`font-size`.

**Grouping / stacking.** mako can collapse repeats: `group-by=app-name` plus a `[grouped]` section
showing a count. dunst stacks and de-dupes with `stack_duplicates=true`. swaync groups per-app in
the panel automatically.

## How the community styles it

A survey of what shows up across Catppuccin ports, HyDE, JaKooLit, ml4w, and r/unixporn:

- **Rounded accent-bordered card** (the default look, ~80% of posts): translucent `surface`
  background, `2 px` accent border, `border-radius 10` (range 8-12), `padding 14`, width ~340. The
  accent border is the single most common move — it ties the toast to the bar's accent.
- **Left colored urgency bar:** flat dark card with a thick (`3-4 px`) accent or red strip down the
  left edge; the rest of the frame is borderless. Reads as a modern "Material" toast.
- **Minimal flat:** no border at all, just a slightly elevated `surface` card with a soft shadow
  (swaync gets a real `box-shadow`; mako/dunst can't, so they lean on the border instead).
- **swaync control-center look:** the slide-out panel styled as a cohesive widget board — a DND
  toggle pill, MPRIS player card, and volume/brightness **sliders whose filled trough uses the
  accent**. This is the closest thing to a "GNOME-style" notification shade and is popular in
  fuller rices (HyDE ships one).

Concrete value bands seen in the wild: **radius 8-12**, **border 2 px accent** (urgency bars 3-4),
**padding 12-16**, **width 300-380**, background alpha **`cc`-`ee`** (80-93%). Named ports to crib
from: `catppuccin/mako`, `catppuccin/dunst`, `catppuccin/swaync`, `rose-pine/swaync`, plus the
notification configs inside HyDE, JaKooLit's dotfiles, and ml4w.

## Battle-tested techniques (from real notification configs)

Concrete, attributed moves harvested from real `config`/`dunstrc`/`style.css` files. Quoted close to
verbatim — swap literal hexes for the rice keys. Grouped by daemon.

**mako.**
- *Do-Not-Disturb as a mode section* (omarchy themes): `[mode=do-not-disturb] invisible=true` hides everything when DND is toggled via `makoctl mode -t do-not-disturb` — then **whitelist** essential alerts back in with compound criteria: `[mode=do-not-disturb app-name=notify-send] invisible=false`. (mako's analogue of dunst's pause.)
- *Mute a noisy app by name* (omarchy): `[app-name=Spotify] invisible=1` — drop a single app's toasts without touching the rest.
- *Progress fill over a muted base* (catppuccin/mako): `progress-color=over #{surface}` — the `over` keyword layers the volume/brightness fill **over** a surface tone instead of replacing the card background.
- *Per-urgency accent on one line* (catppuccin/mako): keep the base palette and override only `[urgency=critical] border-color=#{peach}` — the cheapest priority cue. (mako urgency values are `low`/`normal`/`critical` per the freedesktop spec — there is no `high`.)
- *Margin key moved.* Newer mako uses `outer-margin` (gap from the screen edge) while older mako used `margin`; emit `outer-margin` on current mako and fall back if `makoctl reload` complains. **Counter-evidence (2026 pass against mako(5) master):** `outer-margin` (outside the whole list) and `margin` (per-individual notification, default `10`) **both exist and coexist** — the two stack ("first and last notifications will use the sum of both margins" per the manpage). dusky's matugen template sets both: `outer-margin=0,0,30,0` + `margin=5`. Use both, don't substitute.
- *OSD app-name override* (dusky `matugen/templates/mako.ini`): a separate `[app-name=OSD]` criteria section gives volume/brightness OSD toasts a bottom-center anchor, smaller size, and zero border — totally distinct from regular toast styling. Pattern is `[app-name=<your-osd-sender>] anchor=… width=… padding=… default-timeout=1000`.
- *Per-app overrides for the rice's own scripts* (dusky): `[summary="Dusky Dotfiles"] on-button-left=exec <updater>` wires the toast itself into the rice's tooling. Mako criteria match by `summary=`, `app-name=`, `body=`, `category=` — all freedesktop hints.
- *Rounded icon corners* (dusky): `icon-border-radius=8` matches the toast's corner radius — gives an app-icon thumbnail a card-like feel instead of a sharp square. dunst's equivalent is `icon_corner_radius`.
- *Click-to-action bindings* (dusky): `on-button-left=invoke-default-action`, `on-button-middle=exec makoctl menu -n "$MAKO_NOTIFICATION_ID" -- rofi -dmenu -p Action:`, `on-button-right=dismiss` — left fires the notification's default action, middle pops a rofi menu of all actions, right dismisses. This is the standard pointer-binding triad.

**dunst.**
- *Canonical critical pattern* (every dunstrc): `[urgency_critical] { frame_color = "#…red…"; timeout = 0 }` — red frame, never auto-dismiss. The one rule to always ship.
- *Separator follows the frame* (upstream, hyprdots): `separator_color = frame` reuses the frame color; `separator_color = auto` lets dunst pick a contrasting tone automatically.
- *Rounded translucent card with rounded icons* (hyprdots): `corner_radius = 10` + `frame_width = 5` + `progress_bar_corner_radius = 4` + **`icon_corner_radius = 10`** (rounds the app icon independently); per-urgency backgrounds carry 8-digit-hex alpha — `background = "#3A4A6B80"` (~50%) with a near-invisible frame `"#3A4A6B03"` — for a tinted glass card.
- *Inverted critical for max contrast* (hyprdots): critical uses a **light** background (`#f5e0dc`) with dark foreground + `timeout = 0`, so an emergency reads instantly against the dark normal toasts.
- *Progress-bar block* (upstream): `progress_bar = true` + `progress_bar_height`, `progress_bar_min_width`/`max_width`, `progress_bar_frame_width` — the OSD bar for volume/brightness senders.
- *`highlight` themes the progress fill* (catppuccin/dunst `themes/*.conf`): `highlight = "#…accent…"` in `[global]` colors the progress_bar's filled portion — a `dunst` 1.9+ key that's verified in `src/settings_data.h` (`.highlight = NULL,` default; `name = "highlight"`, `rule_offset = offsetof(struct rule, highlight)`). Pairs with `progress_bar = true`.
- *`corners = all` lets you round any subset* (dunst 1.10+, hyprdots): `corners = all` (default `all`); set to `top-left,top-right` or `bottom` to round only a subset — useful for stacked-card layouts where adjacent corners stay sharp. Works with `progress_bar_corners` and `icon_corners` too.
- *Icon-theme fallback chain* (drewgrif): `icon_path = /usr/share/icons/Papirus/96x96/devices/:…/48x48/status/:…/96x96/apps/` — colon-chained dirs so dunst resolves an icon across multiple Papirus subfolders.
- *Modern geometry, not the legacy string.* Old configs use `geometry = "700x15-0+80"`; current dunst splits this into `width` / `height` / `origin` / `offset = (x, y)`. Emit the split form (the recipe below already does).
- *`notification_limit` caps the on-screen stack* (hyprdots): `notification_limit = 20` lets up to 20 toasts coexist before older ones get hidden (`indicate_hidden = yes` shows a "+N more" line). Pairs with `gap_size` to control inter-toast spacing.

**swaync (GTK CSS + config.json).**
- *Variable-override is the theming primitive* (upstream): the default theme is built on CSS custom properties — `--cc-bg`, `--noti-bg`, `--text-color`, `--border-radius` (in `pre-gtk4-variables.scss`). Modern swaync runs on GTK4, where `var(--cc-bg)` custom properties **are** supported, so the cleanest reskin is to redefine those vars rather than rewrite selectors. (Catppuccin instead swaps SCSS `$base/$surface0`; xZepyx uses GTK `@theme_bg/@accent_color` named colors — pick one layer.)
- *The widget stack is data, not CSS* (upstream, HyDE): the control-center layout lives in `config.json`'s `"widgets"` array — e.g. `["title","dnd","notifications","mpris","backlight","volume","buttons-grid"]` — with per-widget settings under `"widget-config"`. Reorder the panel by editing the array.
- *buttons-grid = real quick toggles* (HyDE, xZepyx): wire actual commands in `widget-config` (network editor, bluetooth, hyprsunset, lock, power) and style the active state — `.widget-buttons-grid flowboxchild > button.toggle:checked { background-color: @accent; color: white; }`, large/circular radius for tappable pills.
- *MPRIS media card* (upstream, catppuccin): a blurred album-art backdrop — `.mpris-background { filter: blur(10px); }` with a `.mpris-overlay` tint over it — or a small square `.widget-mpris-album-art { -gtk-icon-size: 100px; border-radius: …; }`. The signature swaync media look.
- *Real slider selector is `scale trough` / `scale trough progress`* (xZepyx, catppuccin): the accent-filled volume/backlight bar is `scale trough progress { background-color: @accent; }` — not `progressbar`. **Counter-evidence (2026 pass):** in current GTK4 swaync the volume/backlight bar fills via `trough highlight`, not `trough progress`; ml4w `themes/glass/control_center.css` scopes it to `.widget-volume trough highlight, .widget-backlight trough highlight { background: @primary; }`. The recipe below uses `trough highlight, scale highlight` for the same reason. Both forms appear in community configs; on GTK4 the `highlight` form is the one that actually paints.
- *Canonical toast selector chain is `.floating-notifications.background .notification-row .notification-background .notification`* (ml4w `themes/glass/notifications.css`, Matt-FTW `.config/swaync/style.css`): the `.notification-background` wrapper is real and is what upstream `data/style/style.scss` styles. The shorter `.notification-row .notification` cascades down but doesn't let you separate toast-only styling (`.floating-notifications.background ...`) from in-panel rows (`.control-center .notification-row .notification-background .notification`). Use the full chain when shadow/margin differs between the two.
- *Inset red shadow for critical toast* (Matt-FTW): `.notification.critical { box-shadow: inset 0 0 7px 0 @red; }` — gives an emergency toast a red inner glow even when the palette's `accent` is already warm. Read-instantly across every theme.
- *Hairline edges via inset shadow* (catppuccin): `box-shadow: inset 0 0 0 1px $surface1` gives a crisp 1px border on cards/buttons without a `border`.
- *Frosted control-center* (upstream default `--cc-bg: rgba(46,46,46,0.7)`): ship a translucent control-center background + a Hyprland **block-form** `layerrule` blur on the `swaync-control-center` namespace (and `swaync-notification-window` for the toasts). Round close button is universal: `border-radius: 100%; min-width: 24px; min-height: 24px`.
- *Sensible config.json defaults* (upstream, HyDE): `positionX: right`, `positionY: top`, `timeout: 10` / `timeout-low: 5` / `timeout-critical: 0`, `control-center-width: 400–500`.
- *Bottom-right panel + edge-to-edge full-screen layer* (Matt-FTW): `positionY: "bottom"`, `layer-shell-cover-screen: true`, `fit-to-screen: true`, `control-center-width: 500`, `control-center-height: 600` — pushes the panel to the corner and adds a screen-covering blank backdrop on open. The `layer-shell-cover-screen` key (2024+) is what creates the "click anywhere outside to dismiss" surface.
- *Buttons-only minimal control-center* (Matt-FTW): `"widgets": ["title", "notifications"]` — the whole panel is just title + scrolling notification list. The other extreme of the spectrum from HyDE/ml4w. Useful when waybar already exposes brightness/volume/network so the panel doesn't need to duplicate them.
- *Buttons-grid with real toggles + update-command* (ml4w `config.json`): each button can pair a `"command"` with an `"update-command"` that returns `"true"`/`"false"` to set `"active": true` — e.g. `update-command: sh -c '[[ $(nmcli r wifi) == "enabled" ]] && echo true || echo false'`. This is how a swaync button stays in sync with system state instead of just firing-and-forgetting.
- *Position picks that are widely shipped* (corpus): `right`/`top` (ml4w, binnewbs, hyprdots derivatives), `center`/`top` (JaKooLit), `right`/`bottom` (Matt-FTW). Bottom is rarer because `swaync` toasts grow downward — bottom-anchored toasts shove existing ones up, which feels less natural.
- *Per-urgency at the CSS level uses `.notification.<urgency>`* (ml4w glass, upstream master): the toast/row gets the class `low`/`normal`/`critical`; the full selector inside the panel is `.control-center .notification-row .notification-background .notification.critical { border: 2px solid red; }` and inside the toast it's `.floating-notifications.background ... .notification.critical`. Use the chain — `.notification.critical` alone is ambiguous between the two contexts.
- *`floating-notifications.background` is the floating-toast scope* (ml4w `themes/glass/notifications.css`, Matt-FTW): every floating-toast selector in the wild begins with `.floating-notifications.background .notification-row .notification-background ...`. Selectors written without the prefix style the toast AND the in-panel rows the same way (which is sometimes what you want — but often you want them to differ in shadow / margin / radius). The upstream class hierarchy is: floating window → `.floating-notifications` (class `.background` when the toast surface is open) → `.notification-row` → `.notification-background` (the per-notification wrapper) → `.notification` (the actual content).

## Tasteful default recipe

Palette keys (hex, **no** leading `#`): `bg fg surface muted accent red green yellow font_ui
font_mono`. Below, each `{{key}}` is substituted; mako/dunst take literal `#RRGGBB`/`#RRGGBBAA`, so
the alpha suffix (`ee`) is appended directly. swaync (GTK CSS) gets `@define-color`. A worked
**Catppuccin Mocha** example follows each (surface `313244`, fg `cdd6f4`, accent/mauve `cba6f7`,
red `f38ba8`, bg `1e1e2e`).

> This plugin (rice in Mode A3b, edit-config for later tweaks) writes mako/dunst as **whole files**
> with colours already folded in, so this recipe is the whole config, self-contained — not a
> fragment to be merged.

## Pitfalls

- **mako alpha is an appended hex pair, not a separate key.** Opacity lives in the 8th-7th hex
  digits: `background-color=#313244ee`. There is no `transparency=`/`opacity=` knob in mako.
- **dunst per-urgency overrides the global.** `frame_color` in `[global]` is the fallback; the
  `[urgency_*]` sections override it. Set the accent in `[urgency_normal]` and the red in
  `[urgency_critical]` — a global-only `frame_color` will look the same for all priorities. Don't
  mix an 8-digit `background` hex *and* a global `transparency` percentage; pick one.
- **Keep critical readable.** Whatever your aesthetic, a critical alert (low battery, screen-share
  warning) must contrast hard — red frame, full-opacity background, no fancy translucency that
  washes it out.
- **Don't blanket a timeout onto critical.** `timeout = 0` / `default-timeout=0` on critical is
  *intentional* — those notifications should persist until dismissed. Resist the urge to give
  everything the same auto-dismiss.
- **swaync needs the daemon + GTK and reloads in two halves.** Editing `style.css` requires
  `swaync-client -rs`; editing `config.json` requires `swaync-client -R`. Forgetting which is why
  "my CSS didn't apply." It also only supports the default Adwaita GTK theme — third-party GTK
  themes can fight your `style.css`. Use `GTK_DEBUG=interactive swaync` to discover live selectors.
- **Cap icon size.** An uncapped `max-icon-size`/`max_icon_size` lets a high-res app icon blow the
  card out of proportion — `48` is a safe ceiling.
- **swaync CSS ≠ web CSS.** It's the GTK dialect: use `alpha(@color, 0.9)` not `rgba()` with a
  named color, and only GTK-supported properties. Both color systems work — our recipe uses
  `@define-color`/`@name` (universally safe), while swaync's own upstream default theme uses GTK4
  CSS custom properties (`var(--cc-bg)`); on a GTK4 swaync you can override those vars directly, but
  `@define-color` is the portable choice for a config you write whole.

## Provenance

Citations for this file live at `.research/sources/components-notifications-styling.md` (repo root), kept out of
the load path on purpose. Read them when reviewing a recommendation, not when
authoring a config.

---

## Validation


Parse + sanity checks the writer (or `validate.sh`) runs on the emitted files **before** the
reload hook fires. A bad config crashes the daemon at startup, which silently drops every toast
the user sees — so catch parse errors at generate-time.

## Cross-references

- Per-daemon recipes → `template.md`
- Reload hooks (where the parse check is wedged in) → `reload.md`
- Color-var contract (the `@var` names the swaync `style.css` may reference) →
  `../../_shared/colors-contract.md`

---

## Gotchas


## Only ONE notification daemon can run

mako, dunst, and swaync all claim the `org.freedesktop.Notifications` D-Bus name. The first
process to register wins; the second to start logs a "name already in use" / "another notification
daemon is running" error and exits. Symptoms when you stack two daemons:

- One daemon shows toasts, the other shows nothing — but the user can't tell which is which from
  the toast alone.
- After a reboot or a daemon crash + restart, the "wrong" one sometimes wins.
- DND toggles only affect the daemon that actually owns the name; the other's CLI is a no-op.

**Rule:** rice writes config for exactly one daemon and the `autostart` component emits exactly
one `exec-once`. If a full **widget shell** (group 7 — eww/ags/quickshell/hyprpanel, or a turnkey
distro like end-4 / caelestia / noctalia / dankmaterial) ships its own notification daemon, set
`notifications.daemon = "none"` and let the shell own the D-Bus name. Don't co-install mako
"as a fallback" — it'll race the shell at login.

## Color keys come from the engine — never hardcode hex

The colors portion of every daemon config is rendered by the rice engine from `palette.conf` via
the per-daemon `.tmpl` (`mako.tmpl`, `dunst.tmpl`, `swaync.tmpl`). The component writer:

- For **mako** — emits the layout/behavior keys; the `mako.tmpl`-rendered color section is the
  inline `background-color` / `text-color` / `border-color` block. The two are concatenated into
  the single `~/.config/mako/config` file.
- For **dunst** — emits `[global]` and the per-urgency frames; the `dunst.tmpl`-rendered colors
  are **merged into the same `[urgency_*]` sections** at write-time. dunst has no `@import` — the
  merge is textual.
- For **swaync** — emits `style.css` with `@import "colors.css";` at the top; the engine writes
  `colors.css` separately from `swaync.tmpl`.

Hardcoding hex anywhere in this component's output silently un-themes that surface when the user
re-themes (rice Mode B). The validator flags any literal `#RRGGBB` in the writer's emitted
template that isn't a `{{var}}`.

## Waybar `custom/notification` is swaync-only

When waybar is the bar AND it includes the `custom/notification` module, the module reads
`swaync-client -swb` (subscribe-waybar) for the unread count + DND state. mako and dunst don't
expose an equivalent waybar-compatible endpoint, so:

- `notifications.daemon == "swaync"` → waybar module works.
- `notifications.daemon ∈ {mako, dunst}` AND waybar requested `custom/notification` → the writer
  **omits** the module rather than emit a broken poll. Log the omission so the user knows.
- The same D-Bus-mutex still applies: the waybar module isn't a second daemon — it just
  visualizes swaync's state. Only swaync still holds the name.

## Critical urgency never inherits the user's timeout

Whatever the user picks for 9c (`5s` / `3s` / `10s` / `Never`), the template **always overrides
critical-urgency notifications to `timeout = 0` / `default-timeout = 0`**. That's a styling-library
invariant (low-battery / screen-share / disk-full warnings must persist until acknowledged), not a
user knob. If the user picked `Never` for 9c, normal and low urgencies also go to `0`; critical is
already `0`. See `styling.md` for the full reasoning.

## DND-bind matches the daemon

When `"dnd-bind" ∈ notifications.behavior`, the `keybinds` component emits one bind, and the bind
**must match the daemon**:

| Daemon | DND-toggle command |
|---|---|
| mako   | `makoctl mode -t do-not-disturb` |
| dunst  | `dunstctl set-paused toggle` |
| swaync | `swaync-client -d` (note: `-t` toggles the panel, not DND) |

Wiring the mako command to a dunst session (or vice versa) silently no-ops — the CLI talks to
its own daemon's D-Bus interface, not the freedesktop spec's, so the wrong CLI succeeds with
nothing happening. The `keybinds` writer reads `notifications.daemon` to pick the right one.

---

## Reload


Each daemon has a one-shot CLI to reload its config in place — **only run it when the daemon is
actually running**. On a fresh install (rice Mode A first run) the daemon hasn't been started
yet; running `makoctl reload` against no daemon fails with a confusing error. Guard every reload
on a `pgrep -x <daemon>`.

The autostart `exec-once = <daemon>` lives in `components/autostart/`; rice's first-run flow is
**write config → start daemon (Hyprland reload runs `exec-once`) → no explicit reload needed**.
Subsequent edits (rice Mode B re-theme, or `edit-config`) take the reload path below.

## On the very first Mode A run

No daemon is yet running. The reload step is a **no-op** by design (every `pgrep` guard fails).
The daemon starts when Hyprland processes its `exec-once = <daemon>` line — at that point the
config is already on disk, so the daemon picks up the rice palette / position / timeout values
on first boot. **Do not** try to start the daemon from the notifications writer; that races with
Hyprland's startup and breaks Mode B's re-theme flow (which expects an already-running daemon).

## Cross-references

- Where the autostart `exec-once = <daemon>` is written → `../autostart/template.md`
- Parse checks that gate the reload → `validation.md`
- Per-daemon CLI references → `styling.md` (the "What you're styling" table at the top)


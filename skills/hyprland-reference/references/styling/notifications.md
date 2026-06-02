# Styling Notifications (mako / dunst / swaync)

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

## Tasteful default recipe

Palette keys (hex, **no** leading `#`): `bg fg surface muted accent red green yellow font_ui
font_mono`. Below, each `{{key}}` is substituted; mako/dunst take literal `#RRGGBB`/`#RRGGBBAA`, so
the alpha suffix (`ee`) is appended directly. swaync (GTK CSS) gets `@define-color`. A worked
**Catppuccin Mocha** example follows each (surface `313244`, fg `cdd6f4`, accent/mauve `cba6f7`,
red `f38ba8`, bg `1e1e2e`).

> This plugin's `desktop-shell` skill writes mako/dunst as **whole files** with colours already
> folded in, so this recipe is the whole config, self-contained — not a fragment to be merged.

### mako — `~/.config/mako/config`

```ini
# --- layout / placement ---
anchor=top-right
margin=10
padding=14
border-radius=10
border-size=2
width=340
height=120
default-timeout=5000
max-visible=5
icon-location=left
max-icon-size=48
font={{font_ui}} 11
markup=1
format=<b>%s</b>\n%b

# --- colours ---
background-color=#{{surface}}ee
text-color=#{{fg}}
border-color=#{{accent}}
progress-color=over #{{accent}}44

[urgency=low]
border-color=#{{muted}}

[urgency=critical]
border-color=#{{red}}
default-timeout=0

# group repeats from the same app
[grouped]
format=<b>%s</b>\n%b\n<small>(%g)</small>
```

Catppuccin Mocha worked values:

```ini
background-color=#313244ee
text-color=#cdd6f4
border-color=#cba6f7
progress-color=over #cba6f744
# [urgency=critical] border-color=#f38ba8
```

### dunst — `~/.config/dunst/dunstrc`

```ini
[global]
    origin = top-right
    offset = (10, 50)
    width = 340
    height = (0, 120)
    corner_radius = 10
    frame_width = 2
    padding = 14
    horizontal_padding = 14
    separator_color = frame
    gap_size = 8
    font = {{font_ui}} 11
    markup = full
    format = "<b>%s</b>\n%b"
    icon_position = left
    min_icon_size = 16
    max_icon_size = 48
    progress_bar = true
    progress_bar_height = 8
    corners = all

[urgency_low]
    background = "#{{surface}}"
    foreground = "#{{fg}}"
    frame_color = "#{{muted}}"
    timeout = 5

[urgency_normal]
    background = "#{{surface}}"
    foreground = "#{{fg}}"
    frame_color = "#{{accent}}"
    timeout = 5

[urgency_critical]
    background = "#{{surface}}"
    foreground = "#{{fg}}"
    frame_color = "#{{red}}"
    timeout = 0
```

Catppuccin Mocha worked values (per-urgency `background = "#313244"`, `foreground = "#cdd6f4"`):
normal `frame_color = "#cba6f7"`, critical `frame_color = "#f38ba8"`. dunst transparency is set via
the 8-digit hex on `background` (e.g. `"#313244ee"`) or the global `transparency` percentage — not
both.

### swaync — `~/.config/swaync/style.css`

GTK CSS. Define colours up top, then style the toast and the control-center panel. Selectors here
match current swaync (`.notification-row`, `.notification`, `.control-center`, `.widget-dnd`,
sliders).

```css
@define-color bg       #{{bg}};
@define-color surface  #{{surface}};
@define-color fg       #{{fg}};
@define-color muted    #{{muted}};
@define-color accent   #{{accent}};
@define-color red      #{{red}};

* { font-family: "{{font_ui}}", "Symbols Nerd Font"; font-size: 14px; }

/* a single toast */
.notification-row .notification {
  border-radius: 10px;
  border: 2px solid @accent;
  margin: 6px 12px;
  background: alpha(@surface, 0.93);
  box-shadow: 0 2px 8px 0 rgba(0,0,0,0.6);
}
.notification-row .notification.critical { border-color: @red; }
.notification .summary { color: @fg; font-weight: bold; }
.notification .body,
.notification .time   { color: alpha(@fg, 0.8); }
.close-button {
  background: @surface; color: @fg;
  border-radius: 100%; min-width: 24px; min-height: 24px;
  margin: 8px 8px 0 0;
}

/* the slide-out notification center panel */
.control-center {
  background: alpha(@bg, 0.95);
  border: 1px solid @muted;
  border-radius: 12px;
  padding: 14px;
  color: @fg;
}
.widget-dnd > switch:checked { background: @accent; }       /* DND toggle */
.widget-title > button { background: @surface; color: @fg; border-radius: 8px; }

/* volume / brightness sliders -> accent fill */
trough highlight, scale highlight { background: @accent; }
slider { background: @fg; border-radius: 100%; }
```

Catppuccin Mocha: `@define-color bg #1e1e2e; @define-color surface #313244; @define-color fg
#cdd6f4; @define-color accent #cba6f7; @define-color red #f38ba8;`.

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
  named color, `@define-color`/`@name` not `var(--x)`, and only GTK-supported properties.

## Sources

- mako(5) man page — <https://man.archlinux.org/man/mako.5.en>
- mako example configuration (wiki) — <https://github.com/emersion/mako/wiki/Example-configuration>
- dunst default `dunstrc` — <https://github.com/dunst-project/dunst/blob/master/dunstrc>
- dunst(5) / project wiki — <https://github.com/dunst-project/dunst/wiki>
- SwayNotificationCenter README + `swaync-client` flags — <https://github.com/ErikReider/SwayNotificationCenter>
- swaync default `style.scss` (selectors) — <https://github.com/ErikReider/SwayNotificationCenter/blob/main/data/style/style.scss>
- swaync(1)/(5) man pages — <https://man.archlinux.org/man/swaync.1.en>, <https://man.archlinux.org/man/swaync.5.en>
- Catppuccin mako — <https://github.com/catppuccin/mako>
- Catppuccin dunst — <https://github.com/catppuccin/dunst>
- Catppuccin swaync — <https://github.com/catppuccin/swaync>
- Rosé Pine swaync — <https://github.com/rose-pine/swaync>
- HyDE / JaKooLit / ml4w dotfiles (notification configs) — <https://github.com/HyDE-Project/HyDE>, <https://github.com/JaKooLit/Hyprland-Dots>, <https://github.com/mylinuxforwork/dotfiles>

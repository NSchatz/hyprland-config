# Styling hyprlock (the lock screen)

A lock screen is a small composition: a background (usually a blurred screenshot), a big clock, a
password input "pill", and optionally an avatar or info labels. hyprlock stacks a handful of
widgets onto that background; getting it to look good is mostly about restraint, alignment, and
coloring the input field with your scheme's accent.

## What you're styling

Config lives at `~/.config/hypr/hyprlock.conf`. It is read by the **hyprlock daemon**, not by
Hyprland — it does *not* go through `source = …` and it **cannot read Hyprland `$variables`** from
your `colors.conf`/`palette.conf`. Every color must be a literal (`rgb(cba6f7)` / `rgba(…)`); the
only `$vars` you get are ones you define *inside* `hyprlock.conf` itself.

Widgets (each is a repeatable block):

- `background` — `path = <image>` or `path = screenshot` (snapshot of the desktop at lock time);
  `blur_passes`, `blur_size`, `brightness`, `contrast`, `vibrancy`, `noise`, `color` (solid fill).
- `input-field` — the password pill: `size`, `rounding`, `outline_thickness`, `outer_color`,
  `inner_color`, `font_color`, `check_color`, `fail_color`, `placeholder_text`, dots options.
- `label` — any text. `text = $TIME`, `text = cmd[update:60000] date +"%A, %d %B"`; styled with
  `font_size`, `font_family`, `color`, `position`, `halign`, `valign`.
- `image` — an avatar/logo. `path`, `size`, `rounding` (`-1` = full circle), `border_size`,
  `border_color`.
- `shape` — a rectangle/rounded card you can place behind labels for contrast.

**Preview:** just run `hyprlock` in a terminal (type your password or press `Esc`/`Ctrl+U` to clear,
then unlock to exit), or `hyprctl dispatch exec hyprlock`. Edit, save, re-run — it's fast to iterate.

## Design anatomy — the knobs that change the look

**Background.** Three idioms:

- *Blurred screenshot* (most common): `path = screenshot` + `blur_passes = 2`–`4`. The defaults
  already dim and desaturate (`brightness = 0.8172`, `contrast = 0.8916`, `vibrancy = 0.1696`,
  `noise = 0.0117`), which is why a 2–3 pass blur looks clean out of the box. Lower `brightness`
  (e.g. `0.6`) to dim further so the clock/pill pop.
- *Static wallpaper*: `path = ~/.config/hypr/lock.png`, usually with a light blur or none.
- *Solid color*: `color = rgb(1e1e2e)` and no `path` — minimalist, fast, no GPU blur.

`blur_passes` is the dominant cost; `2`–`3` is plenty, `5+` is needlessly slow.

**The input-field** is the focal accent. Typical: `size = 250, 50` up to `300, 60`,
`outline_thickness = 2`–`3`, `rounding = -1` (pill) or a fixed radius like `15`. Color it with your
scheme:

- `outer_color` = the **accent** (the outline ring).
- `inner_color` = a **surface** color, or a translucent fill like `rgba(0,0,0,0.2)` over a blur.
- `font_color` = **fg**.
- `check_color` (shown while authenticating) and `fail_color` (wrong password) give real UX feedback
  — set check ≈ accent/green, fail ≈ red.
- `placeholder_text` accepts Pango markup: `placeholder_text = <i>Password…</i>`.
- `dots_center = true` centers the typed dots; `fade_on_empty` fades the pill when empty;
  `hide_input = true` shows a single indicator instead of per-character dots (swaylock style).

**Labels.** The clock is the typographic anchor: `text = $TIME`, `font_size` **60–120** (90 is the
canonical value in the shipped example), placed top-left/top-right or dead center. Add a date with
`cmd[update:60000] date +"%A, %d %B %Y"`, a greeting/user line (`$USER`), or live `cmd` labels for
battery/weather (`text = cmd[update:30000] …`). Control placement with `position = X, Y` plus
`halign`/`valign` (`left|center|right|none` / `top|center|bottom|none`); `position` is an offset
added *after* alignment. `text_align` sets multi-line justification. In `font_family` use the
family name only, with no size suffix (e.g. `font_family = Inter`, not `Inter 12`).

**Images** make the "avatar card" look: `size = 100`–`160`, `rounding = -1` for a perfect circle,
`border_size = 2`–`4`, `border_color = rgb(<accent>)`. `reload_time`/`reload_cmd` can swap the image
periodically.

**Layering / per-monitor.** Widgets draw in declaration order; place a `shape` first to make a card
behind text. Every widget takes `monitor =` — **empty means all monitors** (the usual choice); set a
name like `monitor = DP-1` to scope it.

## How the community styles it

Recognizable looks across the popular configs:

- **Blurred-screenshot minimal** (the default vibe; hyprwm `assets/example.conf`): `path =
  screenshot`, `blur_passes = 3`, a big `$TIME` at `font_size = 90` top-right, a date label under
  it, a centered pill. Clean, zero extra assets.
- **Big typographic clock + small pill** (HyDE, ml4w, JaKooLit): oversized clock (often 100–120),
  date and a greeting, the input tucked below center, accent-outlined.
- **Avatar + greeting card** (HyprFlux, many r/unixporn posts): a circular `image` (`size = 160`,
  `rounding = -1`), a "Welcome, $USER" label, and a slim pill — sometimes over a `shape` card.
- **Wallpaper + accent-outlined input**: static wallpaper, `outer_color` = scheme accent at 2–3px,
  translucent `inner_color`.

Concrete community conventions: clock `font_size` 60–120; input `size` ~250–300 × 50–60; outline
2–3px; dim the background (`brightness` ≈ 0.6–0.8). The **Catppuccin hyprlock** port is the model for
coloring with a palette: it defines color `$vars` in a sourced `mocha.conf` and sets
`outer_color = $accent`, `inner_color = $surface0`, `check_color = $accent`, `fail_color = $red`,
input `size = 300, 60`, clock `font_size = 90`, plus a `border_color = $accent` avatar. (Those `$`
vars work because they're defined *inside* hyprlock's own config, not pulled from Hyprland.)

## Tasteful default recipe

Blurred screenshot, a big `$TIME`, a date, a rounded centered pill outlined in the accent. Because
hyprlock can't read Hyprland `$vars`, the colors are **literal hex** filled from the rice palette.
This plugin generates `hyprlock.conf` by substituting these keys from `palette.conf`, so keep the
key names aligned (`accent`, `surface`, `fg`, `green`, `red`).

Template (placeholders to fill from the palette):

```ini
# ~/.config/hypr/hyprlock.conf — colors are LITERAL hex (hyprlock can't read $accent)
$font = {{font_ui}}            # e.g. Inter — UI family name only, no size

general {
    hide_cursor = true
    grace = 0                  # seconds before the lock can be dismissed without a password
}

background {
    monitor =
    path = screenshot          # blur the live desktop; or an image path
    blur_passes = 3
    blur_size = 7
    brightness = 0.70          # dim so the clock/pill pop
    vibrancy = 0.17
}

input-field {
    monitor =
    size = 280, 55
    rounding = -1              # full pill
    outline_thickness = 2
    dots_center = true
    fade_on_empty = false
    outer_color = rgb({{accent}})
    inner_color = rgb({{surface}})
    font_color  = rgb({{fg}})
    check_color = rgb({{green}})
    fail_color  = rgb({{red}})
    placeholder_text = <i>Password…</i>
    font_family = $font
    position = 0, -120
    halign = center
    valign = center
}

# clock
label {
    monitor =
    text = $TIME
    font_size = 96
    font_family = $font
    color = rgb({{fg}})
    position = 0, 160
    halign = center
    valign = center
}

# date
label {
    monitor =
    text = cmd[update:60000] date +"%A, %d %B"
    font_size = 22
    font_family = $font
    color = rgb({{fg}})
    position = 0, 90
    halign = center
    valign = center
}
```

Worked example — **Catppuccin Mocha** (accent `cba6f7` mauve, surface `313244`, fg `cdd6f4`,
green `a6e3a1`, red `f38ba8`):

```ini
$font = Inter

background {
    monitor =
    path = screenshot
    blur_passes = 3
    brightness = 0.70
}

input-field {
    monitor =
    size = 280, 55
    rounding = -1
    outline_thickness = 2
    dots_center = true
    outer_color = rgb(cba6f7)
    inner_color = rgb(313244)
    font_color  = rgb(cdd6f4)
    check_color = rgb(a6e3a1)
    fail_color  = rgb(f38ba8)
    placeholder_text = <i>Password…</i>
    font_family = $font
    position = 0, -120
    halign = center
    valign = center
}

label {                     # clock
    monitor =
    text = $TIME
    font_size = 96
    font_family = $font
    color = rgb(cdd6f4)
    position = 0, 160
    halign = center
    valign = center
}

label {                     # date
    monitor =
    text = cmd[update:60000] date +"%A, %d %B"
    font_size = 22
    font_family = $font
    color = rgb(cdd6f4)
    position = 0, 90
    halign = center
    valign = center
}
```

To add a circular avatar, drop in:

```ini
image {
    monitor =
    path = ~/.face                 # or any image
    size = 120
    rounding = -1
    border_size = 2
    border_color = rgb(cba6f7)
    position = 0, 300
    halign = center
    valign = center
}
```

## Pitfalls

- **`path = screenshot`** needs a hyprlock build with screencopy support and the right portal/perms;
  if it shows black, fall back to a static image path. (Some setups also hit a "transformed twice"
  flip on certain GPUs — switch to an image if so.)
- **No `$accent` from Hyprland.** hyprlock can't read your `colors.conf` vars — use literal hex, or
  define `$vars` *inside* hyprlock.conf (optionally `source`d from a small color file you write).
- **Missing `input-field`** = no way to type the password (you can get stuck locked out). Always
  include one when testing on a real session, or keep a TTY ready.
- **Skipping `check_color`/`fail_color`** hurts UX — without them there's no visual "wrong password"
  feedback.
- **Huge `blur_passes`** (5+) is slow to render and can stall the lock animation; `2`–`3` is enough.
- **`font_family`** must name an installed family with no size suffix; a missing font silently falls
  back and your sizing/look drift.
- **`monitor =` empty = all monitors.** Only set a name to scope a widget to one output; a typo'd
  monitor name means the widget simply doesn't appear.

## Sources

- Official hyprlock wiki: <https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/>
- Shipped reference config (`assets/example.conf`):
  <https://github.com/hyprwm/hyprlock/blob/main/assets/example.conf>
- DeepWiki — hyprlock Background / Labels-Images-Shapes / Configuration:
  <https://deepwiki.com/hyprwm/hyprlock/5.2-background>,
  <https://deepwiki.com/hyprwm/hyprlock/5.3-labels-images-and-shapes>
- Catppuccin hyprlock port: <https://github.com/catppuccin/hyprlock/blob/main/hyprlock.conf>
- HyprFlux hyprlock examples: <https://www.hyprflux.dev/features/hyprlock.html>
- Arch Wiki — Hyprlock: <https://wiki.archlinux.org/title/Hyprlock>

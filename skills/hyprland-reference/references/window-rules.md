# Window Rules, Layer Rules, Workspace Rules

> **Version note (important):** window-rule syntax changed significantly around **Hyprland
> 0.53**. The shipped 0.54 default config uses a new **block form** (`windowrule { match:... }`).
> The older single-line forms still parse, but prefer the block form on 0.53+. Popular dotfiles
> (e.g. JaKooLit) literally keep separate `WindowRules-pre-53.conf` and `-v3.conf` files for this
> reason. Detect the version and emit the matching form.

## windowrule block form (0.53+, modern)

```ini
windowrule {
    name = float-pavucontrol        # optional label
    match:class = ^(pavucontrol)$   # match:<field> = <regex>
    float = yes                     # rule properties as key = value
    size = 800 600
    center = yes
}

windowrule {
    name = suppress-maximize        # from the shipped default — generally desirable
    match:class = .*
    suppress_event = maximize
}

windowrule {
    name = pip
    match:title = ^(Picture-in-Picture)$
    float = yes
    pin = yes
}
```

- `match:<field>` lines select windows: `match:class`, `match:title`, `match:initialClass`,
  `match:initialTitle`, `match:xwayland`, `match:float`, `match:fullscreen`, `match:pin`,
  `match:workspace`, `match:focus`.
- Rule properties are `key = value`: `float`, `tile`, `size`, `move`, `center`, `pin`,
  `opacity`, `workspace`, `monitor`, `no_focus`, `no_blur`, `no_shadow`, `no_border`,
  `rounding`, `border_size`, `suppress_event`, `idle_inhibit`, `immediate`, `tag`,
  `bordercolor`, `animation`.
- `move` accepts expressions like `move = 20 monitor_h-120`.

## windowrule / windowrulev2 (single-line, legacy/compat)

Still valid; the simplest forms. Two historical variants:

- **v1 (legacy):** `windowrule = RULE, REGEX` — matches on window class regex only.
  ```ini
  windowrule = float, ^(pavucontrol)$
  windowrule = workspace 2, ^(firefox)$
  ```
- **v2:** `windowrulev2 = RULE, FIELD:REGEX, FIELD:REGEX, ...` — matches on multiple fields.
  ```ini
  windowrulev2 = float, class:^(pavucontrol)$
  windowrulev2 = opacity 0.9 0.9, class:^(kitty)$
  windowrulev2 = workspace 3 silent, class:^(Spotify)$, title:^(Spotify.*)$
  ```

On current Hyprland the v2 syntax was **merged into `windowrule`** — `windowrule` now accepts
the `FIELD:REGEX` matcher form, and `windowrulev2` remains as a deprecated alias. Prefer
`windowrule` with explicit fields on new configs; keep `windowrulev2` only when targeting older
versions. See `deprecations.md`.

### Matcher fields

`class`, `title`, `initialClass`, `initialTitle`, `tag`, `xwayland:1`, `floating:1`,
`fullscreen:1`, `pinned:1`, `focus:1`, `workspace:N`, `onworkspace:N`.

### Common rules

```ini
# Floating utility windows
windowrule = float, class:^(pavucontrol|nm-connection-editor|blueman-manager)$
# Size + center a floating window
windowrule = size 800 600, class:^(pavucontrol)$
windowrule = center, class:^(pavucontrol)$
# Send apps to workspaces (silent = don't follow)
windowrule = workspace 2 silent, class:^(Spotify)$
# Opacity (active inactive)
windowrule = opacity 0.92 0.85, class:^(kitty)$
# Picture-in-picture: float + pin + keep on top
windowrule = float, title:^(Picture-in-Picture)$
windowrule = pin, title:^(Picture-in-Picture)$
# Inhibit idle for fullscreen video/games
windowrule = idleinhibit fullscreen, class:^(.*)$
# Allow tearing for a game (needs general:allow_tearing = true)
windowrule = immediate, class:^(cs2|steam_app_.*)$
# No blur/shadow on a specific app
windowrule = noblur, class:^(firefox)$
```

Useful rule keywords: `float`, `tile`, `fullscreen`, `maximize`, `size W H`, `move X Y`,
`center`, `pin`, `opacity`, `workspace`, `monitor`, `noblur`, `noshadow`, `noborder`,
`norounding`, `nofocus`, `noinitialfocus`, `idleinhibit`, `immediate`, `suppressevent`,
`stayfocused`, `dimaround`, `bordercolor`, `animation`, `tag`.

## layerrule

Rules for layer-shell surfaces (bars, launchers, notification daemons). Match on namespace.

**0.54+ block form** (current). Like `windowrule`, `layerrule` moved to the unified block form
with `name` as the required key — and on 0.54.3 the old single-line form is **rejected** (a hard
break, not back-compat; see `deprecations.md`):

```ini
layerrule {
    name = blur-waybar
    match:namespace = waybar
    blur = true
}
layerrule {
    name = blur-rofi
    match:namespace = rofi
    blur = true
}
```

Verified 0.54.3 fields: `blur = true`, `no_anim = true`, `ignore_alpha = <0-1>`, `xray = true`,
`animation = <style>`. (There is no `ignore_zero` field — use `ignore_alpha`.)

**Older targets** use the single-line form instead:

```ini
layerrule = blur, waybar
layerrule = ignorezero, waybar
layerrule = noanim, hyprpaper
```

Find namespaces with `hyprctl layers`. Never mix the two forms for one rule — pick by version.

## Battle-tested rules (from real dotfiles)

Concrete, attributed rules harvested from the big rices. Block form shown (the modern 0.53+/0.54
recommendation); the equivalent terse single-line `match:` form and the deprecated property-first
form are noted where they differ.

- *The universal baseline* (shipped default, every rice): `suppress_event maximize, match:class .*` plus the XWayland drag-fix `no_focus` rule — `windowrule = no_focus, match:class ^$, match:title ^$, match:xwayland 1, match:float 1, match:fullscreen 0, match:pin 0`. Inherit both.
- *Tag-based grouping* (JaKooLit): assign a class to a tag once — `windowrule = tag +browser, match:class ^([Ff]irefox|…)$` — then style the whole class with `tag:browser*` (opacity/float/etc.). Restyle a category by editing one line.
- *Default-opacity opt-out tag* (omarchy): tag everything (`tag +default-opacity, match:class .*`), let specific apps opt **out** (`tag -default-opacity, match:tag pip`), then apply the opacity to the tag **last** (`opacity 0.97 0.9, match:tag default-opacity`) — global translucency with per-app exceptions.
- *Picture-in-Picture, full recipe* (universal): match `^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$` → `float + pin + keep_aspect_ratio + size + move`, anchored top-right with arithmetic — `move = (monitor_w-window_w-40) (monitor_h*0.04)`.
- *Screen-share indicator* (end-4): float + pin the Firefox/Chromium "is sharing" banner — `match:title .*is sharing (a window|your screen).*`.
- *xwaylandvideobridge invisibility hack* (Matt-FTW): make the bridge window effectively invisible so screen-share works without it stealing focus — `opacity 0.0 override 0.0 override` + `no_anim` + `no_blur` + `no_initial_focus` + `max_size 1 1`, `match:class ^(.*xwaylandvideobridge.*)$`.
- *Idle behaviour by app* : `idle_inhibit fullscreen` on browsers/players (videos don't trigger idle); `idle_inhibit always` + `immediate` (tearing) on game classes like `^(.*steam_app.*)$` (Matt-FTW).
- *Factor app-class regex into `$variables`* (Matt-FTW): `$center-float = class:^(center-float)$|^(.*[Gg]alculator.*)$` then reference `$center-float` in the float/size/center rules — one place to maintain the dialog list.
- *Per-component layer blur* (HyDE, Matt-FTW): blur each shell namespace with a tuned `ignore_alpha`, and optionally give each its own entry/exit animation. Common namespaces beyond `waybar`/`rofi`: `notifications`, `swaync-notification-window`, `swaync-control-center`, `gtk-layer-shell`, `logout_dialog`.
  ```ini
  layerrule {
      name = blur-swaync
      match:namespace = swaync-control-center
      blur = true
      ignore_alpha = 0.0
      animation = slide
  }
  ```
- *Smart gaps (zero gaps when a single window)* (shipped default): pair a workspace selector with `onworkspace:` window rules —
  ```ini
  workspace = w[tv1], gapsout:0, gapsin:0
  windowrule = bordersize 0, match:floating 0, match:onworkspace w[tv1]
  windowrule = rounding 0,   match:floating 0, match:onworkspace w[tv1]
  ```
  (`w[tv1]` = workspaces with exactly one tiled/visible window.)

**Property renames to flag** (deprecated → 0.53+): `ignorezero`→`ignore_alpha`, `keepaspectratio`→`keep_aspect_ratio`, `noinitialfocus`→`no_initial_focus`, `nofocus`→`no_focus`, `suppressevent`→`suppress_event`, `idleinhibit`→`idle_inhibit`, `noblur`→`no_blur`, `noanim`→`no_anim`, `bordersize`→`border_size`; matchers `class:`/`title:`→`match:class`/`match:title`, `initialTitle:`→`match:initial_title`. Emerging: end-4/ml4w use the Lua API (`hl.window_rule{…}`, `hl.layer_rule{…}`, `hl.workspace_rule{…}`).

## workspace rules

Per-workspace configuration via `workspace =`:

```ini
# Bind a workspace to a monitor
workspace = 1, monitor:DP-1, default:true
workspace = 5, monitor:HDMI-A-1
# Persistent + custom gaps + no decorations on a fullscreen-ish workspace
workspace = 9, monitor:DP-1, persistent:true, gapsout:0, gapsin:0, border:false, rounding:false
# Special workspace styling
workspace = special:magic, on-created-empty:foot
```

Rule keys: `monitor:`, `default:`, `persistent:`, `gapsin:`, `gapsout:`, `border:`,
`rounding:`, `decorate:`, `shadow:`, `on-created-empty:`, `layoutopt:`.

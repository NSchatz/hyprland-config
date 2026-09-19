# swaync - notifications

Everything this plugin knows about authoring **swaync** for the `notifications` surface:
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


Two files. `config.json` is **behaviour + widget array** (the panel layout is data, not CSS).
`style.css` is GTK CSS that `@import`s the rice-rendered `colors.css`.

### `config.json`

```json
{
  "positionX": "{{positionX}}",
  "positionY": "{{positionY}}",
  "control-center-width": 440,
  "timeout": {{timeout_s}},
  "timeout-low": 4,
  "timeout-critical": 0,
  "notification-window-width": 360,
  "fit-to-screen": true,
  "hide-on-clear": false,
  "hide-on-action": true,
  "script-fail-notify": true,
  "widgets": [
    "title",
    "dnd",
    "notifications",
    "mpris",
    "volume"
    {{#if has_backlight}}, "backlight"{{/if}}
    , "buttons-grid"
  ],
  "widget-config": {
    "title":   { "text": "Notifications", "clear-all-button": true, "button-text": "Clear All" },
    "dnd":     { "text": "Do Not Disturb" },
    "mpris":   { "show-album-art": "always", "autohide": false, "blacklist": [] },
    "volume":  { "label": "" },
    "buttons-grid": {
      "buttons-per-row": 4,
      "actions": [
        { "label": "", "command": "nm-connection-editor", "type": "toggle" },
        { "label": "", "command": "blueman-manager",       "type": "toggle" },
        { "label": "", "command": "hyprlock",              "type": "toggle" },
        { "label": "", "command": "wlogout",               "type": "toggle" }
      ]
    }
  }
}
```

**Position map** (9b → `positionX` / `positionY`):

| 9b answer | `positionX` | `positionY` |
|---|---|---|
| top-right    | `right`  | `top`    |
| top-center   | `center` | `top`    |
| top-left     | `left`   | `top`    |
| bottom-right | `right`  | `bottom` |

`has_backlight` is `true` iff `/sys/class/backlight` has at least one entry (laptop with internal
panel). On a desktop, **drop the `"backlight"` widget entirely** — see `gotchas.md`.

### `style.css`

```css
@import "colors.css";    /* rendered by rice from swaync.tmpl — exports @bg @fg @surface @muted @accent @accent2 @red */

* { font-family: "{{font_ui}}", "Symbols Nerd Font"; font-size: 14px; }

/* upstream selector chain: .notification-row > .notification-background > .notification.
   The .floating-notifications.background prefix scopes the toast (not the
   per-row entry inside .control-center). Mirrors ml4w + Matt-FTW. */
.floating-notifications.background .notification-row .notification-background .notification {
  border-radius: 10px;
  border: 2px solid @accent;
  margin: 6px 12px;
  background: alpha(@surface, 0.93);
  box-shadow: 0 2px 8px 0 rgba(0,0,0,0.6);
}
.floating-notifications.background .notification-row .notification-background .notification.critical {
  border-color: @red;
  box-shadow: inset 0 0 7px 0 @red;       /* Matt-FTW: critical reads instantly even in muted palettes */
}
.notification .summary { color: @fg; font-weight: bold; }
.notification .body,
.notification .time   { color: alpha(@fg, 0.8); }
.close-button {
  background: @surface; color: @fg;
  border-radius: 100%; min-width: 24px; min-height: 24px;
  margin: 8px 8px 0 0;
}

/* slide-out control center */
.control-center {
  background: alpha(@bg, 0.95);
  border: 1px solid @muted;
  border-radius: 12px;
  padding: 14px;
  color: @fg;
}
/* match the toast selector chain inside the panel too */
.control-center .notification-row .notification-background .notification.critical { border: 2px solid @red; }
.widget-dnd > switch:checked { background: @accent; }
.widget-title > button { background: @surface; color: @fg; border-radius: 8px; }

/* sliders — accent-filled trough, scoped to the slider widgets.
   GTK4 selector is `.<widget> trough highlight` (ml4w/glass, catppuccin/swaync).
   The unscoped `trough highlight` catches every progress bar (notification.critical
   progress included) — fine, but the scoped form prevents bleed-through into
   3rd-party themed sub-widgets. */
.widget-volume    trough highlight,
.widget-backlight trough highlight { background: @accent; }
slider { background: @fg; border-radius: 100%; }

.widget-buttons-grid flowboxchild > button.toggle:checked {
  background-color: @accent; color: @bg;
}
```

`@import "colors.css"` resolves to `~/.config/swaync/colors.css` — the rice engine writes that
file from `swaync.tmpl`. **Reference colors only by name** (`@accent`, `@red`, …); never inline
hex into `style.css`.

---

## Styling


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

---

## Validation


Two files, two parsers.

### `config.json` — JSON

```bash
test -r "$HOME/.config/swaync/config.json" || die "swaync config.json missing"

# 1. it's valid JSON
jq . "$HOME/.config/swaync/config.json" > /dev/null || die "swaync config.json: bad JSON"

# 2. required keys present
jq -e '.positionX and .positionY and (.timeout|type=="number")' \
   "$HOME/.config/swaync/config.json" > /dev/null \
  || die "swaync config.json: missing positionX/positionY/timeout"

# 3. widgets is an array of strings
jq -e '(.widgets|type=="array") and ([.widgets[]|type=="string"]|all)' \
   "$HOME/.config/swaync/config.json" > /dev/null \
  || die "swaync config.json: widgets must be array of strings"

# 4. backlight widget only when /sys/class/backlight has a device
if jq -e '.widgets | index("backlight")' \
     "$HOME/.config/swaync/config.json" > /dev/null; then
  compgen -G "/sys/class/backlight/*" > /dev/null \
    || die "swaync 'backlight' widget present but no backlight device — drop it"
fi
```

### `style.css` — GTK CSS

GTK doesn't ship a standalone CSS validator, but **balanced braces** + **balanced
parens** + **no unresolved `@var`** catches 95% of breakage:

```bash
test -r "$HOME/.config/swaync/style.css" || die "swaync style.css missing"

# 1. balanced braces
opens=$(grep -o '{' "$HOME/.config/swaync/style.css" | wc -l)
closes=$(grep -o '}' "$HOME/.config/swaync/style.css" | wc -l)
[ "$opens" -eq "$closes" ] || die "swaync style.css: unbalanced { } ($opens vs $closes)"

# 2. balanced parens (for alpha(), rgba(), etc.)
po=$(grep -o '(' "$HOME/.config/swaync/style.css" | wc -l)
pc=$(grep -o ')' "$HOME/.config/swaync/style.css" | wc -l)
[ "$po" -eq "$pc" ] || die "swaync style.css: unbalanced ( ) ($po vs $pc)"

# 3. every @name used is either an @import, @define-color, or @keyframes,
#    or a name imported via colors.css. Hard-list known-good names; flag others.
awk '
  /@import/ || /@define-color/ || /@keyframes/ { next }
  match($0, /@[a-zA-Z][a-zA-Z0-9_-]*/) {
    n = substr($0, RSTART+1, RLENGTH-1)
    if (n !~ /^(bg|fg|surface|muted|accent|accent2|red|theme_[a-z_]+)$/)
      { print "unknown @var: " n; bad=1 }
  }
  END { exit bad }
' "$HOME/.config/swaync/style.css"

# 4. no inline hex (must reference @vars from colors.css)
!  grep -qE '#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?' "$HOME/.config/swaync/style.css" \
   || die "swaync style.css contains inline hex — must use @vars from colors.css"

# 5. no unrendered rice template vars
!  grep -qE '\{\{[a-z]+\}\}' "$HOME/.config/swaync/style.css" \
   || die "unrendered template var in swaync style.css"

# 6. live check — `swaync-client -rs` reports CSS errors to stderr
if pgrep -x swaync > /dev/null; then
  swaync-client -rs 2>&1 | tee /tmp/swaync-reload.log
  ! grep -qiE 'error|warning' /tmp/swaync-reload.log || die "swaync style.css runtime error"
fi
```

---

## Gotchas


The `"backlight"` entry in swaync's `widgets` array drives a brightness slider via
`brightnessctl` / `/sys/class/backlight`. On a desktop with no internal panel, there is no
backlight device — the slider renders as a dead widget that errors on every change. Guard the
inclusion at generate-time:

```bash
has_backlight=0
if compgen -G "/sys/class/backlight/*" > /dev/null; then
  has_backlight=1
fi
```

Drop `"backlight"` from the widgets array on `has_backlight=0`. (Detection lives in
`scripts/detect-theme-tools.sh` and lands as `HAS_BACKLIGHT=1` for the writer to read.)

Same logic should also gate keybinds for brightness keys in `components/laptop/` — they're tied
to the same condition.

## swaync GTK4 toast selector chain: `.notification-row > .notification-background > .notification`

The current swaync (GTK4) DOM is `.notification-row` → `.notification-background` (per-notification
wrapper) → `.notification` (the actual content). Selectors written without `.notification-background`
in the chain — e.g. `.notification-row .notification { ... }` — match by cascade but bundle the
toast and in-panel rows together. To style them differently you need the full chain plus the
ancestor scope:

- toasts only: `.floating-notifications.background .notification-row .notification-background .notification`
- panel rows only: `.control-center .notification-row .notification-background .notification`

ml4w `themes/glass/{notifications,control_center}.css` and Matt-FTW use this everywhere. The recipe
in `template.md` was rewritten in the 2026 pass to use the upstream chain.

## swaync GTK4 slider fill is `trough highlight`, not `trough progress`

GTK3 swaync exposed the volume/backlight slider trough as `scale trough progress`; GTK4 swaync
paints the fill on `trough highlight` instead. Some older swaync configs (and the styling.md
battle-tested list) reference `scale trough progress` — that's not what paints on current swaync.
Scope to the widget (`.widget-volume trough highlight, .widget-backlight trough highlight`) to
avoid bleeding into `.notification.critical progress` and other progressbars. Verified against
ErikReider/SwayNotificationCenter `data/style/widgets/{volume,slider,backlight}.scss` HEAD.

## swaync `image-visibility` enum is hyphenated

Valid values for `config.json` `image-visibility` are `"always" | "never" | "when-available"`. The
binnewbs `arch-hyprland` config ships `"image-visibility": "when available"` (space, not hyphen) —
swaync silently falls back to the default. Validate the literal string against the three-value
enum in the writer; do not accept user variants with spaces.

## swaync per-rice position picks vary by orientation, not just preference

Corpus snapshot of `positionX` / `positionY`:

| Rice | X | Y | Notes |
|---|---|---|---|
| ml4w        | `right`  | `top`    | The "default" pick — toasts grow downward, panel slides from corner |
| JaKooLit    | `center` | `top`    | Notification-center-as-banner aesthetic |
| binnewbs    | `right`  | `top`    | JaKooLit-derived |
| Matt-FTW    | `right`  | `bottom` | Paired with `layer-shell-cover-screen: true` for click-outside dismiss |

`bottom`-anchored toasts grow **upward**, shoving older toasts up — which can fight a bottom-anchored
waybar. The interview's default (`top-right`) is the corpus-majority pick.

## swaync waybar palette reuse pattern

JaKooLit + binnewbs both `@import '../../.config/waybar/colors.css';` in their swaync style.css and
re-define swaync's `--noti-*` variables in terms of waybar's: `@define-color noti-border-color
@color12; @define-color noti-bg-alt @background-alt; @define-color text-color @foreground;`. This
guarantees the toast's border accent matches whatever the bar's active-workspace pill uses,
without duplicating colors.

The rice's `swaync.tmpl` does the equivalent by sharing the same `palette.conf` source — both
surfaces render `@accent` from the same key. **Cross-surface coherence flag:** if a future change
ever makes waybar's accent key drift from notifications' (e.g. waybar uses `accent2` for active
workspace but mako uses `accent` for the border), the rice surfaces will look uncoordinated. Keep
`waybar.tmpl` and `mako.tmpl` / `dunst.tmpl` / `swaync.tmpl` referencing the same primary
`{{accent}}` key for the active-/border-accent role.

---

## Reload


Two-step, two files:

```bash
if pgrep -x swaync > /dev/null; then
  # style.css changes — visual
  swaync-client -rs

  # config.json changes — behaviour (positions, timeouts, widget array)
  swaync-client -R
fi
```

`-rs` (`--reload-css`) re-parses `~/.config/swaync/style.css`. Use after any color, font, radius,
or selector change.

`-R` (`--reload`) reloads `~/.config/swaync/config.json`. Use after position, timeout, or widget
array changes.

**Forgetting which is which is the #1 swaync gotcha** — "my CSS didn't apply" means the user ran
`-R` after editing `style.css` (which only reloads the JSON), or vice versa. rice's writer always
runs both when *any* swaync file changes; the cost of running an unnecessary reload is zero, the
cost of skipping the needed one is a confused user.


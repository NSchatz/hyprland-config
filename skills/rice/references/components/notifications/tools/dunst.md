# dunst - notifications

Everything this plugin knows about authoring **dunst** for the `notifications` surface:
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


INI sections; `[global]` + `[urgency_*]` blocks. The rice-rendered `dunst.tmpl` contributes the
per-urgency colors (`background`/`foreground`/`frame_color`); this writer emits the layout +
behavior + reads those rendered colors back into the urgency sections.

```ini
[global]
    font = {{font_ui}} 11
    width = 340
    height = (0, 120)
    origin = {{origin}}               # top-right | top-center | top-left | bottom-right
    offset = (12, 12)
    corner_radius = 10
    frame_width = 2
    padding = 14
    horizontal_padding = 14
    separator_color = frame
    gap_size = 8
    corners = all                          # round every corner (dunst 1.10+)
    markup = full
    format = "<b>%s</b>\n%b"
    {{#if app-icons}}icon_position = left
    min_icon_size = 16
    max_icon_size = 48
    icon_corner_radius = 10                # round app icons to match the card (hyprdots)
    {{else}}icon_position = off{{/if}}
    progress_bar = true
    progress_bar_height = 8
    progress_bar_corner_radius = 4
    highlight = "#{{accent}}"              # progress_bar fill — themes volume/brightness OSD (catppuccin/dunst)
    {{#if group-by-app}}stack_duplicates = true
    hide_duplicate_count = false{{/if}}
    mouse_left_click = do_action, close_current
    mouse_middle_click = close_all
    mouse_right_click = context

[urgency_low]
    background = "#{{bg}}"
    foreground = "#{{muted}}"
    frame_color = "#{{surface}}"
    timeout = {{timeout_s}}

[urgency_normal]
    background = "#{{bg}}"
    foreground = "#{{fg}}"
    frame_color = "#{{accent}}"
    timeout = {{timeout_s}}

[urgency_critical]
    background = "#{{bg}}"
    foreground = "#{{fg}}"
    frame_color = "#{{red}}"
    timeout = 0                       # critical NEVER auto-dismisses

{{#if (eq utilities.osd_route "notification")}}
# --- OSD routing (utilities.osd_route == "notification") ---
# When volume/brightness binds use `notify-send -a OSD`, dunst can target the OSD app via
# a `[app_name="OSD"]` rule. Keeps the OSD palette coherent with the rest of the rice
# (avoids stock GTK fallback). The notification body still drives the progress bar via
# the existing `highlight = #{{accent}}` from `[global]`.
[osd_app]
    appname = "OSD"
    background = "#{{surface}}"
    foreground = "#{{fg}}"
    frame_color = "#{{accent}}"
    timeout = 1                       # transient — short
    history_ignore = yes              # don't clutter the history with OSD events
{{/if}}
```

`timeout_s` = `answers.timeout` (seconds). `0` for "never". `offset = (12, 12)` is the modern split
form; **do not** emit the legacy `geometry = "WxH-X+Y"` string.

---

## Styling


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

---

## Validation


dunst INI is **section-scoped** with **indented** `key = value` lines under each section. Validate:

```bash
test -r "$HOME/.config/dunst/dunstrc" || die "dunstrc missing"

# 1. dunst has no standalone --check / --syntax flag. `dunst -print` prints
#    received notifications, NOT a parse check (common confusion). The reliable
#    parse path is dunstctl reload — it exits non-zero on a bad config when the
#    daemon is running. On a fresh install with no daemon yet, fall through to
#    the awk shape-check below.
if pgrep -x dunst > /dev/null; then
  dunstctl reload 2>&1 | tee /tmp/dunst-reload.log
  ! grep -qiE 'error|invalid|parse' /tmp/dunst-reload.log || die "dunst parse error"
fi

# 2. every line is either a section header, a comment, blank, or "key = value"
awk '
  /^[[:space:]]*$/ || /^[[:space:]]*#/ || /^\[[a-zA-Z_0-9]+\]$/ { next }
  !/^[[:space:]]+[a-zA-Z][a-zA-Z0-9_]*[[:space:]]*=/ { print "bad dunst line: " $0; bad=1 }
  END { exit bad }
' "$HOME/.config/dunst/dunstrc"

# 3. NO legacy `geometry = "..."` (modern split form only)
!  grep -qE '^[[:space:]]*geometry[[:space:]]*=' "$HOME/.config/dunst/dunstrc" \
   || die "legacy geometry= key — use width/height/origin/offset"

# 4. critical urgency has timeout = 0 (the styling invariant)
awk '
  /^\[urgency_critical\]/ { in_crit=1; next }
  /^\[/ { in_crit=0 }
  in_crit && /^[[:space:]]*timeout[[:space:]]*=[[:space:]]*0[[:space:]]*$/ { ok=1 }
  END { exit !ok }
' "$HOME/.config/dunst/dunstrc" \
  || die "[urgency_critical] must have timeout = 0"

# 5. no unrendered rice template vars
!  grep -qE '\{\{[a-z]+\}\}' "$HOME/.config/dunst/dunstrc" \
   || die "unrendered template var in dunstrc"
```

dunst's most common parse failure is mixing the legacy `geometry` string with the split form —
the parser accepts both but the result is undefined. The legacy-check above forbids `geometry =`
outright.

---

## Gotchas


Old `dunstrc` files use `geometry = "700x15-0+80"`. Current dunst splits this into `width = …`,
`height = (min, max)`, `origin = …`, `offset = (x, y)`. The recipe in `template.md` uses the
split form. If the user has an existing config with `geometry = …`, the edit-config skill should
migrate it (the legacy string + the new keys together produce undefined behavior).

---

## Reload


```bash
if pgrep -x dunst > /dev/null; then
  dunstctl reload
fi
```

`dunstctl reload` re-reads `~/.config/dunst/dunstrc`. If dunst isn't running, **don't** force-start
it — dunst is D-Bus activatable, so the next `notify-send` (or any app sending a notification)
will spawn it with the new config automatically. The autostart `exec-once = dunst` is for
predictability across reboots, not a hard requirement.

Older recipes sometimes use `killall dunst` and let D-Bus respawn; `dunstctl reload` is the
preferred (no-restart) path on dunst 1.10+.


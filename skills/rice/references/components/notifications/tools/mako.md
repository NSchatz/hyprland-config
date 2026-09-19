# mako - notifications

Everything this plugin knows about authoring **mako** for the `notifications` surface:
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


Single file holds layout + behavior + colors. Colors come from the rice-rendered `mako.tmpl`
(inline keys + `[urgency=low]` and `[urgency=critical]` sections — mako's three urgency criteria
values are `low`/`normal`/`critical`, **not** `high`). The writer merges this with the user's
`position` / `timeout` / `behavior` picks.

```ini
font={{font_ui}} 11
width=340
height=120
margin=10
padding=14
border-size=2
border-radius=10
anchor={{anchor}}                     # top-right | top-center | top-left | bottom-right
layer=overlay
{{#if max-visible-5}}max-visible=5{{/if}}
{{#if app-icons}}icons=1
max-icon-size=48{{else}}icons=0{{/if}}
markup=1
format=<b>%s</b>\n%b
default-timeout={{timeout_ms}}        # answers.timeout * 1000, or 0 for "never"
ignore-timeout=1
{{#if group-by-app}}group-by=app-name{{/if}}

# --- colors (from rice palette via mako.tmpl) ---
background-color=#{{surface}}ee
text-color=#{{fg}}
border-color=#{{accent}}
progress-color=over #{{accent}}44

[urgency=low]
border-color=#{{muted}}

[urgency=critical]
border-color=#{{red}}
default-timeout=0                     # critical NEVER auto-dismisses — see styling.md

{{#if group-by-app}}
[grouped]
format=<b>%s</b>\n%b\n<small>(%g)</small>
{{/if}}

{{#if (eq utilities.osd_route "notification")}}
# --- OSD routing (utilities.osd_route == "notification") ---
# Volume/brightness keybinds fire `notify-send -a OSD …` instead of swayosd-client.
# This block themes those toasts to match the rest of the rice's palette (dusky pattern;
# avoids Matt-FTW's coherence-miss where the OSD falls back to stock GTK colors). The
# `-h int:value:N` hint renders the progress bar mako uses for transient OSDs.
[app-name=OSD]
default-timeout=900                    # short — OSD is transient, not actionable
border-color=#{{accent}}
background-color=#{{surface}}f2        # slightly more opaque than normal notifications
progress-color=over #{{accent}}
ignore-timeout=1
{{/if}}

[mode=do-not-disturb]
invisible=1
```

**Anchor map** (9b → `anchor=`): `top-right` → `top-right`, `top-center` → `top-center`,
`top-left` → `top-left`, `bottom-right` → `bottom-right`.

---

## Styling


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

---

## Validation


mako uses an INI-like grammar: top-level `key=value` lines, plus `[criteria]` sections (e.g.
`[urgency=critical]`, `[mode=do-not-disturb]`). Valid `urgency` values are `low`, `normal`,
`critical` (the freedesktop spec's three levels — **not** `high`). Validate:

```bash
# 1. file exists and is readable
test -r "$HOME/.config/mako/config" || die "mako config missing"

# 2. parse check — mako has no --check flag, but `makoctl reload` is the parse step.
#    Skip if mako isn't running (it's still safe — see reload.md).
if pgrep -x mako > /dev/null; then
  makoctl reload 2>&1 | tee /tmp/mako-reload.log
  ! grep -qE 'parse|invalid|error' /tmp/mako-reload.log || die "mako parse error"
fi

# 3. INI line shape — every non-blank, non-comment, non-section line is key=value
awk '
  /^[[:space:]]*$/ || /^[[:space:]]*#/ || /^\[.*\]$/ { next }
  !/^[a-zA-Z][a-zA-Z0-9_-]*=/ { print "bad mako line: " $0; bad=1 }
  END { exit bad }
' "$HOME/.config/mako/config"

# 4. colors are wrapped #RRGGBB or #RRGGBBAA — not the rice {{var}} placeholders
!  grep -qE '#\{\{|\{\{[a-z]+\}\}' "$HOME/.config/mako/config" \
   || die "unrendered template var in mako config"
```

Common parse failures: stray brace `{}` instead of `[criteria]`, `border-color: …` (CSS colon)
instead of `border-color=…`, hex without the leading `#`.

---

## Gotchas


Recent mako (1.10+) uses `outer-margin` for the gap to the screen edge; older mako used `margin`
for both that AND between-toast spacing. rice emits `margin=10` today (broadly compatible). If the
user is on a brand-new mako and reports the toasts hugging the edge, swap to `outer-margin=10` +
`margin=8` (the latter then controls between-toast). Not auto-detected today; track via
`scripts/detect-theme-tools.sh` if it becomes a friction point.

**Note (2026 verification against mako(5) master):** `outer-margin` did not *replace* `margin` —
they coexist. `outer-margin` applies once to the outside of the whole list; `margin` (default `10`)
applies to each individual notification. "First and last notifications will use the sum of both
margins" (mako(5)). dusky's matugen template sets both — `outer-margin=0,0,30,0` plus `margin=5`.
The version cliff is: pre-1.10 mako has no `outer-margin` key at all, so emitting it errors. Detect
mako version via `mako --version` if a future change wants to ship both.

## mako urgency criteria values: low/normal/critical (no "high")

mako follows the freedesktop notification spec — the only valid `urgency=` criteria values are
`low`, `normal`, `critical`. `[urgency=high]` looks reasonable but is **silently a no-op** (mako
parses it as a custom criteria that no real notification will ever satisfy). The pre-2026 `mako.tmpl`
in this folder shipped `[urgency=high]` — fixed in the 2026 deep-research pass. If a downstream
fork pattern resurfaces, reject it at validate-time.

---

## Reload


```bash
if pgrep -x mako > /dev/null; then
  makoctl reload
fi
```

`makoctl reload` re-reads `~/.config/mako/config` in place — no flicker, no missed toasts.
Returns non-zero if the config has a parse error; the validator (`validation.md`) should catch
that pre-reload. There is no kill-and-respawn fallback — mako is not D-Bus activatable.


# notifications — gotchas

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

## swaync `backlight` widget only when a backlight device exists

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
| swaync | `swaync-client -t` |

Wiring the mako command to a dunst session (or vice versa) silently no-ops — the CLI talks to
its own daemon's D-Bus interface, not the freedesktop spec's, so the wrong CLI succeeds with
nothing happening. The `keybinds` writer reads `notifications.daemon` to pick the right one.

## mako `outer-margin` vs `margin` (version drift)

Recent mako (1.10+) uses `outer-margin` for the gap to the screen edge; older mako used `margin`
for both that AND between-toast spacing. rice emits `margin=10` today (broadly compatible). If the
user is on a brand-new mako and reports the toasts hugging the edge, swap to `outer-margin=10` +
`margin=8` (the latter then controls between-toast). Not auto-detected today; track via
`scripts/detect-theme-tools.sh` if it becomes a friction point.

## dunst legacy `geometry` string

Old `dunstrc` files use `geometry = "700x15-0+80"`. Current dunst splits this into `width = …`,
`height = (min, max)`, `origin = …`, `offset = (x, y)`. The recipe in `template.md` uses the
split form. If the user has an existing config with `geometry = …`, the edit-config skill should
migrate it (the legacy string + the new keys together produce undefined behavior).

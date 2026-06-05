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
| swaync | `swaync-client -d` (note: `-t` toggles the panel, not DND) |

Wiring the mako command to a dunst session (or vice versa) silently no-ops — the CLI talks to
its own daemon's D-Bus interface, not the freedesktop spec's, so the wrong CLI succeeds with
nothing happening. The `keybinds` writer reads `notifications.daemon` to pick the right one.

## mako `outer-margin` vs `margin` (version drift)

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

## dunst legacy `geometry` string

Old `dunstrc` files use `geometry = "700x15-0+80"`. Current dunst splits this into `width = …`,
`height = (min, max)`, `origin = …`, `offset = (x, y)`. The recipe in `template.md` uses the
split form. If the user has an existing config with `geometry = …`, the edit-config skill should
migrate it (the legacy string + the new keys together produce undefined behavior).

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

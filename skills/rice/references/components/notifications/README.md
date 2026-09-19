# notifications

Interview group 9 — the notification daemon (mako, dunst, swaync, or none) and its themed config.
rice generates the daemon's functional config plus a rendered colors file from the rice palette.

**Only one notification daemon can run at a time** — mako, dunst, and swaync all claim the
`org.freedesktop.Notifications` D-Bus name; the second to start exits. If a full widget shell
(group 7) owns notifications, set this component's daemon to `none` and skip the rest.

## What to read - read TWO files, not the folder

This component supports 3 tools, and a writer only ever authors for the one the interview
picked. Reading the others is what makes a recipe get skimmed instead of read.

**Read `common.md`, plus the ONE `tools/<tool>.md` matching `notifications.daemon`. Nothing else.**

| `notifications.daemon` | Read |
|---|---|
| `mako` | `common.md` + [`tools/mako.md`](tools/mako.md) |
| `dunst` | `common.md` + [`tools/dunst.md`](tools/dunst.md) |
| `swaync` | `common.md` + [`tools/swaync.md`](tools/swaync.md) |

Each `tools/<tool>.md` is self-contained for that tool: what to emit, how to style it, how to
validate it, what bites, and how to reload it. `common.md` holds only what is true whichever
tool was picked.

## Other files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 9a–9d (daemon, position, timeout, behavior). One call. |
| `schema.md` | The `notifications.*` keys this component owns in `answers.json`. |
| `mako.tmpl` | Engine color template for `~/.config/mako/config` color section. Exports inline `background-color`/`text-color`/`border-color`/`progress-color` + `[urgency=low/critical]` overrides. |
| `dunst.tmpl` | Engine color template merged into `~/.config/dunst/dunstrc`. Exports `[global]` defaults + `[urgency_low/normal/critical]` blocks. |
| `swaync.tmpl` | Engine color template for `~/.config/swaync/colors.css`. Exports `@define-color bg fg surface muted accent accent2 red`. `style.css` `@import`s this. |
| `packages.md` | Arch package per daemon (mako / dunst / swaync). |

## Where this component lands

- **Daemon config:**
  - mako → `~/.config/mako/config` (single file; colors are inline keys)
  - dunst → `~/.config/dunst/dunstrc` (INI sections; rice colors merge into `[urgency_*]`)
  - swaync → `~/.config/swaync/config.json` (behaviour + widget array) **and**
    `~/.config/swaync/style.css` (GTK CSS, `@import "colors.css";`)
- **Colors file:** the rice engine renders the per-daemon colors from `palette.conf` — see
  `_shared/colors-contract.md` for the exact variable names each daemon exports.
- **Autostart:** the chosen daemon is added to `autostart-env`'s `autostart` list as
  `exec-once = mako` / `dunst` / `swaync`. dunst is also D-Bus activatable so the `exec-once` is
  optional there; mako and swaync need it.
- **Hyprland blur (swaync):** a block-form `layerrule` blur on `swaync-control-center` and
  `swaync-notification-window` lives in `components/window-rules/` for the frosted control center.
- **Waybar `custom/notification` module:** when waybar is the bar AND swaync is the daemon, the
  waybar module reads swaync's count via `swaync-client -swb`. Owned by `waybar/`, gated on this
  component's `daemon == "swaync"`.

## Related components

- [`widgets`](../widgets/) — full widget shells (eww/ags/quickshell/hyprpanel + turnkey distros)
  CAN own notifications themselves; when they do, set `notifications.daemon = none` here. The
  shell's own daemon takes the D-Bus name.
- [`waybar`](../waybar/) — the `custom/notification` waybar module only works with swaync (reads
  `swaync-client -swb`); mako/dunst don't expose a JSON count endpoint waybar can poll natively.
- [`window-rules`](../window-rules/) — owns the `layerrule` blur block for swaync's namespaces.
- [`autostart`](../autostart/) — owns the `exec-once = <daemon>` line.
- [`palette`](../../theming/palettes.md) — feeds the `bg fg surface muted accent accent2 red`
  values the daemon's colors file exports.

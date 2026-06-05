# autostart — gotchas

## `hyprctl reload` does NOT re-run `exec-once`

`exec-once` lines fire exactly once per Hyprland session — at the **initial** compositor startup.
A subsequent `hyprctl reload` re-reads every config file and applies the new settings, but it
**does not re-launch** the autostart programs. On a fresh-from-scratch install this is the
single most confusing symptom: the user runs `hyprctl reload`, sees the new colors / borders /
keybinds applied, then asks why there's no bar, no wallpaper, no notification daemon.

The fix: after writing `autostart.conf` and reloading, **offer to start each service now** with
`hyprctl dispatch exec <cmd>` mirroring each `exec-once` line. If the user declines, warn that the
services will appear at the next login. Example dispatcher loop:

```bash
while IFS= read -r line; do
  cmd="${line#exec-once = }"
  hyprctl dispatch exec "$cmd"
done < <(grep '^exec-once =' "$staging/autostart.conf")
```

This is also why the rice writer must never emit `exec-once = hyprctl reload` — reloads do not
restart `exec-once` programs, and a self-reload during startup would be a no-op.

## At most one polkit agent, at most one wallpaper daemon

Two polkit agents fight over the `org.freedesktop.PolicyKit1.AuthenticationAgent` D-Bus name —
prompts then either come from a random one of them, or from neither. Two wallpaper daemons fight
over the wlr-layer-shell `background` layer — the screen flickers between them or one silently
gives up. The schema enums for `autostart_env.polkit` and `autostart_env.wallpaper_tool` already
encode "exactly one or none"; the validator flags any `autostart.conf` emission with two
`exec-once` lines for either role.

## `SWWW_DAEMON_BIN` matters — never hard-code `swww-daemon`

The `awww` fork of swww declares `provides=swww` in its `PKGBUILD`, which means a package probe
(`pacman -Qi swww`) succeeds, but the binary on disk is `awww-daemon`, not `swww-daemon`. Hard-
coding `exec-once = swww-daemon` on an awww install is a silent no-op — Hyprland's `exec-once`
swallows the missing-binary error and the user gets no wallpaper.

Always emit the binary name `detect-version.sh` reports in `SWWW_DAEMON_BIN`:

```bash
# detect-version.sh output
SWWW_DAEMON_BIN=awww-daemon   # or swww-daemon
SWWW_CLIENT_BIN=awww          # or swww
```

The same rule applies when the user later sets a wallpaper: emit `{{swww_client_bin}} img <path>`,
not `swww img <path>`.

## Notification daemon name conflict

Only one process can own `org.freedesktop.Notifications` on the session bus. If the user picks a
widget shell (`ags` / `quickshell` / `hyprpanel` / a turnkey shell) that owns notifications
itself, **do not** also `exec-once` `mako` / `dunst` / `swaync` — the second one to start fails
silently and the user loses every notification from then on. The fix is upstream: when the
widgets component records its choice, the interviewer should set `notifications.daemon = null`,
so the `notif_*` branches in this component's template never fire.

The validator flags `bar.strategy == "full-shell"` or any widget shell that owns notifications
combined with a non-null `notifications.daemon` — that combination is the bug.

## Portal env propagation — the "screen-share is black" fix

The `dbus-update-activation-environment --systemd …` + `systemctl --user import-environment …`
pair is **always emitted** in `autostart.conf`, even when no screen sharing is asked for. Without
it, `xdg-desktop-portal-hyprland` starts under systemd's environment, which doesn't know
`WAYLAND_DISPLAY` or `XDG_CURRENT_DESKTOP` — every Pipewire screen-share stream then captures a
black frame. The pair is cheap, idempotent, and the standard recommended fix from the
xdg-desktop-portal-hyprland README; emit it unconditionally.

`XDG_CURRENT_DESKTOP=Hyprland` itself is set by the `../env/` component in `env.conf`; this
component just propagates it to the systemd user manager.

## Bar / notification daemon picks come from sibling components

`bar.strategy` and `notifications.daemon` are owned by `../waybar/` and `../notifications/`
respectively. This component **reads** them when emitting `autostart.conf` — don't ask the user
again, and don't try to "fix" a non-null notification daemon under a full-shell pick here; that's
the responsibility of the widgets/notifications interviewer pass.

## `exec-once` vs `exec` and the cliphist double-line

`exec-once` is the right dispatcher for every service in this component — they're long-lived and
must not respawn on reload. The two cliphist lines (`--type text` and `--type image`) are **two
separate `exec-once` directives**, not a single combined one; `wl-paste --watch` only watches one
MIME type per invocation, so a single line drops every image (or every text) snippet from the
history.

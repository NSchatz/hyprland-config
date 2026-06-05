# autostart — gotchas

## `hyprctl reload` does NOT re-run `exec-once`

Per the Hyprland Keywords wiki: `exec-once` = "command will execute only on launch", `exec` =
"command will execute on each reload", `exec-shutdown` = "command will execute only on shutdown"
(plus the raw variants `execr-once` / `execr` that skip support rules). So `exec-once` lines fire
exactly once per Hyprland session — at the **initial** compositor startup. A subsequent
`hyprctl reload` re-reads every config file and applies the new settings, but it **does not
re-launch** the autostart programs (that's what `exec` is for, and `exec` is wrong for long-lived
daemons because each reload would spawn a duplicate). On a fresh-from-scratch install this is the
single most confusing symptom: the user runs `hyprctl reload`, sees the new colors / borders /
keybinds applied, then asks why there's no bar, no wallpaper, no notification daemon.

Source: <https://wiki.hypr.land/Configuring/Keywords/> (Executing section).

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

Polkit only honors **one** registered authentication agent per session: agents register with
the authority via `RegisterAuthenticationAgent()` on the
`org.freedesktop.PolicyKit1.Authority` interface, and the second registration races with the
first — the daemon either uses whichever registered last, or rejects the late registrant with
an "already registered" error, leaving the user with prompts coming from a random one of them or
from neither. Two wallpaper daemons fight over the wlr-layer-shell `background` layer — the
screen flickers between them or one silently gives up. The schema enums for
`autostart_env.polkit` and `autostart_env.wallpaper_tool` already encode "exactly one or none";
the validator flags any `autostart.conf` emission with two `exec-once` lines for either role.

Source: <https://www.freedesktop.org/software/polkit/docs/latest/eggdbus-interface-org.freedesktop.PolicyKit1.AuthenticationAgent.html>.

## `SWWW_DAEMON_BIN` matters — never hard-code `swww-daemon`

`swww` (LGFae's "A Solution to your Wayland Wallpaper Woes") was **renamed to `awww`** and moved
from GitHub to Codeberg (`codeberg.org/LGFae/awww`) — same maintainer, new name, binaries are now
`awww` / `awww-daemon`. The upstream Arch `swww` package is the older pre-rename release; the
newer code ships as the AUR `awww-git` package (and historical/community wrappers may declare
`provides=swww` for back-compat). That back-compat means a package probe (`pacman -Qi swww`) can
succeed against an `awww-git` install, but the binary on disk is `awww-daemon`, **not**
`swww-daemon`. Hard-coding `exec-once = swww-daemon` on an awww install is a silent no-op —
Hyprland's `exec-once` swallows the missing-binary error and the user gets no wallpaper.

Always emit the binary name `detect-version.sh` reports in `SWWW_DAEMON_BIN`:

```bash
# detect-version.sh output (one of)
SWWW_DAEMON_BIN=swww-daemon   SWWW_CLIENT_BIN=swww   # upstream swww still on PATH
SWWW_DAEMON_BIN=awww-daemon   SWWW_CLIENT_BIN=awww   # post-rename build (codeberg.org/LGFae/awww)
```

The same rule applies when the user later sets a wallpaper: emit `{{swww_client_bin}} img <path>`,
not `swww img <path>`.

Sources: <https://github.com/LGFae/swww> ("This project has been renamed `awww` and moved to
Codeberg"), <https://codeberg.org/LGFae/awww> ("put both binaries `target/release/awww` and
`target/release/awww-daemon` in your path").

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
black frame.

The exact variables propagated are `DISPLAY` (XWayland), `WAYLAND_DISPLAY`, and
`XDG_CURRENT_DESKTOP`. The `--systemd` flag tells dbus to also update the list of variables
`systemd --user` will use when activating user services (including D-Bus session services for
which dbus-daemon delegates activation to systemd). The pair is cheap, idempotent, and the
standard recommended fix; emit it unconditionally.

`XDG_CURRENT_DESKTOP=Hyprland` itself is set by the `../env/` component in `env.conf` (and by
`uwsm` if the session was launched that way); this component just propagates whatever value is
already in the compositor environment to the systemd user manager — do **not** re-assign it
inline (e.g. `… XDG_CURRENT_DESKTOP=Hyprland`) in the propagation line, that fights with uwsm
sessions which may set a different value (`Hyprland:wlroots`, etc.).

Sources: <https://wiki.archlinux.org/title/XDG_Desktop_Portal>,
<https://dbus.freedesktop.org/doc/dbus-update-activation-environment.1.html>,
<https://gist.github.com/brunoanc/2dea6ddf6974ba4e5d26c3139ffb7580>.

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

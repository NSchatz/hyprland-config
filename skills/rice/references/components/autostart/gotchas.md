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

Some rices ship a single `wl-paste --watch cliphist store` (mylinuxforwork
`dotfiles/.config/hypr/conf/autostart.lua`) which **silently loses images** — the cliphist FAQ is
explicit that both invocations are required. The two-line form (HyDE
`Configs/.config/hypr/hyprland.conf`, JaKooLit `config/hypr/configs/Startup_Apps.conf`,
caelestia-dots/caelestia `hypr/hyprland/execs.conf`, dusky `.config/hypr/source/autostart.lua`,
end-4 `dots/.config/hypr/hyprland/execs.lua`) is the cross-rice consensus — emit both.

## `exec-once` ordering as observed across the corpus

Two ordering schools coexist; both are stable, the difference is which one a corner case (slow
keyring, missing portal) hurts first:

**School A — auth/portal first, then bar/wallpaper, then services** (HyDE, linuxmobile/kenos,
flickowoa, JaKooLit). Emits in this order: `resetxdgportal.sh` → `dbus-update-activation-environment
--systemd …` → `systemctl --user import-environment …` → polkit agent → bar (`waybar`) →
notification daemon (`dunst`/`swaync`) → clipboard watchers → wallpaper (`swww-daemon`) → idle
(`hypridle`) → trays. The portal env propagation runs **before any GUI** so screen-share works for
every client started later in the same session. HyDE `Configs/.config/hypr/hyprland.conf` literally
emits `resetxdgportal.sh` first, before any other `exec-once`.

**School B — wallpaper/keyring first, then env propagation, then daemons** (end-4, ML4W,
caelestia, Matt-FTW). Wallpaper paints first so the user sees the rice before the bar layers on;
keyring (`gnome-keyring-daemon --start --components=secrets`) runs early so the first browser /
Slack / KeePassXC launch finds the secrets bus. Env propagation lands in the middle. end-4's
`dots/.config/hypr/hyprland/execs.lua` shows this order: `geoclue agent → qs (shell) → wallpaper
restore script → gnome-keyring-daemon → hypridle → dbus-update-activation-environment --all → sleep
1 && dbus-update-activation-environment --systemd …`.

The recipe currently emits School A's order, which is the safer default for first-time installs
(screen-share works on first try). If the rice ships a wallpaper-restore step, lift it before the
env propagation block — that's School B and matches end-4 / ML4W.

## `dbus-update-activation-environment` — `--all` vs explicit-var debate

The exact env-propagation incantation varies meaningfully across the corpus:

| Form | Rices using it | Pros / cons |
|---|---|---|
| `dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP` | JaKooLit, linuxmobile/kenos, ML4W, koeqaife greeter, flickowoa | Minimum-viable for screen-share. Doesn't propagate `PATH`, `XDG_RUNTIME_DIR`, or rice-specific env vars to systemd-activated services — apps launched via `gio launch` / `.desktop` autostart may miss the rice's `PATH`. |
| `dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP` (current recipe) | (synthesised — includes XWayland) | Adds `DISPLAY` for XWayland clients started via dbus activation. Recommended pairing. |
| `dbus-update-activation-environment --systemd --all` | HyDE (alongside the explicit form, in addition), dusky (`systemctl --user import-environment $(env | cut -d'=' -f 1)` + this) | Propagates **every** env var. Maximum compatibility — fixes the "slow app launch" + missing-PATH class of bugs that hit GTK file-pickers and Flatpak apps started through portal activation. Cost: leaks every env var the compositor inherited (including session secrets like `SSH_AUTH_SOCK`, which may be desirable but is worth knowing). |
| `dbus-update-activation-environment --all` (no `--systemd`) | end-4 first call (followed by a second `--systemd` call after `sleep 1`) | The `--all` flag without `--systemd` updates only the dbus activation env, not systemd user-env. end-4's pattern uses both back-to-back with a sleep, citing "some fix idk" in a comment — empirical workaround for a systemd-user-bus race. |

The recipe form `dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY
XDG_CURRENT_DESKTOP` is correct for the screen-share fix and safe. For rices that want the
"every-launcher-just-works" behaviour, **also** emit `dbus-update-activation-environment --systemd
--all` after the explicit-var form (HyDE's pattern at `Configs/.config/hypr/hyprland.conf`) — the
two are idempotent and the second strictly broadens propagation.

`systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP` and
`dbus-update-activation-environment --systemd …` are **not redundant**: the former updates the
systemd user manager's environment (so newly-spawned user-units inherit `WAYLAND_DISPLAY`), the
latter updates dbus's activation env (so dbus-activated services inherit it). Both are needed; emit
them in the order `systemctl --user import-environment` first → `dbus-update-activation-environment
--systemd` second, because the `--systemd` flag on dbus tells it to **also** push to systemd, and
systemd needs the variables already imported for the propagation to do the right thing. (Some
rices, including HyDE, emit them in the opposite order and still work — both directions converge,
but the first-then-second order avoids a race where dbus pushes a stale set.)

Sources: <https://dbus.freedesktop.org/doc/dbus-update-activation-environment.1.html>,
<https://wiki.archlinux.org/title/XDG_Desktop_Portal#Troubleshooting>.

## `resetxdgportal.sh` — the "kill+restart portal" pattern

Several rices (HyDE `Configs/.config/hypr/hyprland.conf` line 1 of exec-once block; flickowoa
`config/hypr/scripts/portal.sh`; Matt-FTW `.config/hypr/scripts/portal`; JaKooLit's optional
`PortalHyprland.sh`) **kill every running `xdg-desktop-portal-*` instance and restart the
hyprland portal explicitly** before any GUI starts. The pattern:

```bash
killall -e xdg-desktop-portal-hyprland xdg-desktop-portal-gnome \
            xdg-desktop-portal-kde xdg-desktop-portal-wlr xdg-desktop-portal
sleep 1
/usr/lib/xdg-desktop-portal-hyprland &
sleep 2
/usr/lib/xdg-desktop-portal &
```

Why: dbus-activated portals can start under the **wrong** desktop (GNOME's portal picks itself
first if both are installed), and the screenshot / screen-share dialog then comes from
`xdg-desktop-portal-gnome` instead of `xdg-desktop-portal-hyprland`. The kill-and-restart forces
`xdg-desktop-portal-hyprland` to claim the interfaces. The 2-second sleep before launching
`xdg-desktop-portal` (the front-end) lets the backend register.

NixOS paths differ — HyDE's `resetxdgportal.sh` detects `/run/current-system/sw/libexec` and uses
it instead of `/usr/lib`. If the recipe ever needs a portal-reset hook, mirror the conditional.

The recipe does **not** emit this by default; users with `XDG_CURRENT_DESKTOP=Hyprland` (set by the
env component) and only `xdg-desktop-portal-hyprland` + `xdg-desktop-portal-gtk` installed do not
need it — dbus picks `hyprland` correctly. Flag it as an opt-in for users who report screen-share
showing the wrong picker.

## Wallpaper restore on login — engine recipes

Static wallpaper daemons (`hyprpaper`) read `~/.config/hypr/hyprpaper.conf` at startup and restore
automatically. Animated daemons (`swww-daemon` / `awww-daemon`) start with **no wallpaper loaded**
and need an explicit `swww img <path>` to repaint. Cross-rice recipes:

- **linuxmobile/kenos**, `.config/hypr/startup.conf`:
  `exec-once = swww init || swww img \`find $wallpaper_path -type f | shuf -n 1\``
  — initialises (or repaints with a random pick if init failed). Old `swww init` syntax; on newer
  swww / awww this is just `swww-daemon` + `swww img`.
- **JaKooLit**, `config/hypr/configs/Startup_Apps.conf`:
  `exec-once = swww-daemon --format xrgb` then optionally
  `exec-once = $SwwwRandom $wallDIR` for periodic rotation. Note `--format xrgb` — works around a
  swww 0.9+ default on hybrid GPUs where the auto-detected pixel format hangs on the first frame.
- **HyDE**: a single `exec-once = $scrPath/swwwallpaper.sh` shell script that locks (PID file at
  `/tmp/hyde$(id -u)swwwallpaper.sh.lock`), reads the last-set wallpaper from a symlink
  (`wallSet`), pipes through `swwwallcache.sh` + `swwwallbash.sh` (the wallbash regenerator), and
  calls `swww img`. The wallbash regen is what restores the rice's *colors* — wallpaper + theme
  are restored as one atomic step.
- **end-4**, `dots/.config/hypr/custom/scripts/__restore_video_wallpaper.sh`:
  generated-on-the-fly by `switchwall.sh`; the file body is overwritten each time the user picks a
  wallpaper, so the script is always literally `mpvpaper '*' <last-wallpaper>` (or `swww img <path>`
  depending on which daemon they last used). Pattern: **the wallpaper-set script writes a
  restore-this script as a side effect**; the autostart line just invokes the restore-this script.
  This is the cleanest "engine restores last theme on login" pattern in the corpus.
- **ML4W**, `dotfiles/.config/ml4w/scripts/ml4w-autostart`:
  reads `$HOME/.cache/ml4w/hyprland-dotfiles/current_wallpaper`, falls back to
  `$HOME/.config/ml4w/wallpapers/default.jpg`, then calls `ml4w-wallpaper` which handles the
  daemon-agnostic restore. Same pattern as end-4 (cached path + restore script), just split
  differently.

If the user's engine is matugen/wallust/wallbash and the rice owns the wallpaper-restore step,
emit a generated `<rice>-restore-wall.sh` and `exec-once = <rice>-restore-wall.sh` — do NOT
hard-code the last wallpaper path in `autostart.conf` (it'd be stale the next time the user picks a
new wallpaper without the rice rewriting the file).

## `systemctl --user start hyprpolkitagent` vs `exec-once = hyprpolkitagent`

`hyprpolkitagent` ships a systemd user unit (`hyprpolkitagent.service`) by default. binnewbs
(`.config/hypr/hyprland.conf`) emits `exec-once = systemctl --user start hyprpolkitagent` — this is
the recommended form because the **service is restarted by systemd if it crashes**, whereas a raw
`exec-once = hyprpolkitagent` is fire-and-forget (a crash leaves the user with no auth agent until
next login). The recipe currently uses the systemctl form; preserve it. The downside: the unit only
exists in recent `hyprpolkitagent` packages — on a very old install (`hyprpolkitagent < 0.1.2`),
fall back to the raw binary.

The same logic argues for `systemctl --user start hypridle` instead of `exec-once = hypridle` —
dusky explicitly notes "hypridle has systemd service" and comments out the exec-once line for that
reason. The recipe currently uses the raw form; both work, but the systemctl form is more robust
to crashes.

## uwsm-managed sessions launch services through `uwsm app --`

When the user starts Hyprland via `uwsm` (the Universal Wayland Session Manager — Arch's
recommended launcher), every `exec-once` line **should** be wrapped in `uwsm app -- <cmd>` so the
launched process becomes a transient systemd-scope unit under the session, not a child of the
compositor. This:

- gives the user `systemd-cgls`-visible per-app scopes,
- lets `loginctl terminate-session` clean up cleanly,
- ensures the app inherits the full uwsm-managed environment (including
  `XDG_CURRENT_DESKTOP=Hyprland:wlroots` which uwsm sets, not just `Hyprland`).

dusky (`.config/hypr/source/autostart.lua`) shows the full pattern:
`hl.exec_cmd("uwsm-app -- awww-daemon")`, `hl.exec_cmd("uwsm-app -- wl-paste --type text --watch
cliphist store")`, etc.

The recipe does **not** emit `uwsm app --` wrappers by default — the user-facing tradeoff is "more
robust cleanup on logout" vs "lines work whether you launch from uwsm or `Hyprland` bare". Detect
uwsm in `detect-version.sh` (presence of `/usr/bin/uwsm` plus `XDG_CURRENT_DESKTOP` ending in
`:wlroots` or `:uwsm`) and only wrap when it's confirmed.

Source: <https://wiki.archlinux.org/title/Hyprland#Starting_Hyprland_with_UWSM>.

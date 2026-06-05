# notifications — reload

Each daemon has a one-shot CLI to reload its config in place — **only run it when the daemon is
actually running**. On a fresh install (rice Mode A first run) the daemon hasn't been started
yet; running `makoctl reload` against no daemon fails with a confusing error. Guard every reload
on a `pgrep -x <daemon>`.

The autostart `exec-once = <daemon>` lives in `components/autostart/`; rice's first-run flow is
**write config → start daemon (Hyprland reload runs `exec-once`) → no explicit reload needed**.
Subsequent edits (rice Mode B re-theme, or `edit-config`) take the reload path below.

## mako

```bash
if pgrep -x mako > /dev/null; then
  makoctl reload
fi
```

`makoctl reload` re-reads `~/.config/mako/config` in place — no flicker, no missed toasts.
Returns non-zero if the config has a parse error; the validator (`validation.md`) should catch
that pre-reload. There is no kill-and-respawn fallback — mako is not D-Bus activatable.

## dunst

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

## swaync

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

## On the very first Mode A run

No daemon is yet running. The reload step is a **no-op** by design (every `pgrep` guard fails).
The daemon starts when Hyprland processes its `exec-once = <daemon>` line — at that point the
config is already on disk, so the daemon picks up the rice palette / position / timeout values
on first boot. **Do not** try to start the daemon from the notifications writer; that races with
Hyprland's startup and breaks Mode B's re-theme flow (which expects an already-running daemon).

## Cross-references

- Where the autostart `exec-once = <daemon>` is written → `../autostart/template.md`
- Parse checks that gate the reload → `validation.md`
- Per-daemon CLI references → `styling.md` (the "What you're styling" table at the top)

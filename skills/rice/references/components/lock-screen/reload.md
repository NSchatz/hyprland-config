# lock-screen — reload

**hyprlock has no live reload.** It is not a long-running daemon — it's launched fresh **per lock
event** (manual `bind = $mainMod, X, exec, hyprlock`, hypridle's `lock_cmd`, or `loginctl
lock-session` → hypridle → hyprlock). Each launch parses `~/.config/hypr/hyprlock.conf` from
disk, runs, and exits when the user unlocks.

## What this means for the rice engine

When `rice apply` regenerates `~/.config/hypr/hyprlock.conf` (because the palette, the lock-screen
answers, or the wallpaper changed), there is **no signal to send**. The next time the screen
locks, hyprlock picks up the new file. There is no equivalent of `hyprctl reload` for the locker.

The render-manifest line for hyprlock therefore has an **empty reload command**:

```
lock-screen <TAB> templates/hyprlock.conf <TAB> ~/.config/hypr/hyprlock.conf <TAB> :
```

(`:` is the shell no-op — explicitly written so the engine doesn't substitute a default
"`pkill -SIGUSR1 hyprlock`"; that signal does nothing useful for hyprlock and would log a
"process not found" warning on a session where no one's locking.)

## Previewing changes

Re-running `hyprlock` directly from a terminal is the canonical preview loop:

```bash
hyprlock          # locks the screen with the new config
# unlock with your password / Esc
```

Tweak `hyprlock.conf`, save, re-run. This is also how the `styling.md` reference recommends
iterating on the look.

## What does propagate live

Nothing in this component propagates live; **everything is "next lock"**. The related cross-component
changes that DO need a reload:

| Change source | What reloads | How |
|---|---|---|
| Lock bind added/removed (`bind = …, X, exec, hyprlock`) → `binds.conf` | Hyprland's bind table | `hyprctl reload` (Hyprland topic files share the standard reload mechanism; no per-component `reload.md`). |
| `lock_cmd` added/removed → `hypridle.conf` | hypridle daemon | `systemctl --user restart hypridle.service` or `pkill -SIGUSR1 hypridle` (owned by [`../companion-daemons/`](../companion-daemons/)). |
| Palette changes → new literal hex in `hyprlock.conf` | nothing right now | applies on next lock. |

## Edge case — locking while hyprlock.conf is being rewritten

`rice apply` writes `hyprlock.conf` atomically (`render-templates.sh` writes to a tempfile then
`mv`s into place), so there's no torn-read risk. Worst case the user locks **immediately** after
the rename and gets the previous-or-next config — never a half-file.

## Cross-references

- Engine architecture (render-manifest line shape) → `theming/engine.md`.
- The lock bind → [`../keybinds/`](../keybinds/).
- `lock_cmd` reload semantics → [`../companion-daemons/`](../companion-daemons/).

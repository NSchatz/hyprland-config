# companion-daemons — gotchas

## Companion configs use a different config language from `hyprland.conf`

`hypridle.conf`, `hyprpaper.conf`, and `hyprlock.conf` all use a **hyprlang-flavoured but
independent** config grammar. They share the brace/`key = value` shape with `hyprland.conf` but
**do not** share its keyword set:

- No `windowrule`, `bind`, `monitor`, `decoration`, `general:gaps_*`, `exec-once`, `$variables`,
  `source =`, … none of it applies inside companion configs.
- Each daemon has its **own** vocabulary (`listener {}` for hypridle, `preload` / `wallpaper` for
  hyprpaper, `background {}` / `input-field {}` / `label {}` for hyprlock).
- Do **not** run `hyprctl reload` against changes to these files — Hyprland never reads them.
- Do **not** lint them with hyprland keywords / a Hyprland validator. The rice validator has a
  separate (much smaller) keyword set for each companion.

If you find yourself wanting `$mainMod` or `windowrule` inside `hypridle.conf`, that's the wrong
file — those go in `hyprland.conf` (or the slices it `source`s).

## `lock_cmd = pidof hyprlock || hyprlock` — don't stack lockers

`hypridle` will happily call `lock_cmd` again on a subsequent idle timeout even if a previous
hyprlock instance is still running. Stacking hyprlocks **layers them** — the user types their
password, dismisses one, and sees another behind it (and another behind that). The fix is the
`pidof` guard:

```ini
general {
    lock_cmd = pidof hyprlock || hyprlock
}
```

`pidof hyprlock` exits 0 (true) when an instance is already running, short-circuiting the `||`;
otherwise it exits non-zero and the second command (`hyprlock`) launches a fresh instance. This is
the standard idiom — every shipped hypridle example uses it.

## `before_sleep_cmd = loginctl lock-session` — lock BEFORE sleep, not after

Use `before_sleep_cmd`, **not** `after_sleep_cmd`, to fire the lock. The kernel suspends the
machine before `after_sleep_cmd` runs, so the laptop screen briefly **unlocks** on wake (in the
window between resume and the lock kicking in) — visible to anyone who opens the lid before the
user. `before_sleep_cmd = loginctl lock-session` puts the lock screen up first; the suspend is
gated on it returning. `after_sleep_cmd = hyprctl dispatch dpms on` is fine — that's the right
hook to re-power the displays on wake.

## Lock listener fires BEFORE dpms-off — order matters in the ladder

The four listeners (dim, lock, dpms-off, suspend) **must** be ordered by ascending timeout:

```
dim_secs  <  lock_secs  <  dpms_secs  <  suspend_secs
```

If `dpms_secs <= lock_secs` the displays turn off **before** the lock screen comes up — the user
gets a black screen they can't see, types their password blind, and the unlock UI never appears
because the lock never fired. The four named ladders (`balanced` / `aggressive` / `relaxed` /
`never`) all satisfy this rule by construction; the validator double-checks it for hand-edited
configs.

## Desktops drop the suspend tier

A desktop machine that suspends mid-day usually isn't doing the right thing — long-running tasks
(builds, downloads, file servers, dev shells) get killed. The `balanced` and `aggressive` ladders
include a suspend listener that's appropriate for laptops on battery; **on desktops the writer
should drop the suspend listener** even when the user picked `balanced`. The detection is:

```bash
if jq -e '.laptop.enabled == true' answers.json >/dev/null; then
  emit_suspend_listener=true
else
  emit_suspend_listener=false  # desktop — drop the tier
fi
```

`relaxed` and `never` already omit the suspend listener, so this only affects `balanced` /
`aggressive`.

## hyprpaper `ipc = on` — so the wallpaper can switch live

The rice engine's wallpaper template ends with a reload hook:

```bash
hyprctl hyprpaper preload "<new-path>"
hyprctl hyprpaper wallpaper ",<new-path>"
```

Both commands talk to `hyprpaper` over its **IPC socket**, which is **off by default**. Without
`ipc = on` in `hyprpaper.conf` the commands silently no-op (or exit non-zero, depending on
version) — the user runs `rice apply` with a new wallpaper, the palette regenerates, every other
surface re-themes, and the wallpaper stays stuck on the old image. Always emit `ipc = on`.

## If hyprlock not chosen, drop the lock listener AND `lock_cmd`

When `companion_configs.hyprlock == false` (or `lock_screen.enabled == false`), hypridle has
nothing to lock with. Two changes to `hypridle.conf`:

1. **Drop** the `lock_cmd = pidof hyprlock || hyprlock` line from the `general {}` block. With it
   in place, `hypridle` calls a nonexistent `hyprlock` on each lock event and logs a flood of
   errors.
2. **Drop** the lock listener (the one that calls `loginctl lock-session`). Without a lock UI,
   `loginctl lock-session` still emits a `Lock` D-Bus signal but nothing receives it — the
   listener is effectively a no-op.

The `before_sleep_cmd = loginctl lock-session` line *can* stay or go; if there's no lock UI it's a
no-op, but harmless. Lean toward dropping it when `hyprlock == false` to keep the file clean.

## hypridle has no `hyprctl reload`

Unlike Hyprland itself, the companion daemons do not honour `hyprctl reload`. Config changes
require restarting the daemon:

- **hypridle:** `systemctl --user restart hypridle` (or `pkill hypridle && hypridle &`).
- **hyprpaper:** for new images, `hyprctl hyprpaper preload <path>` + `hyprctl hyprpaper wallpaper
  ",<path>"` (requires `ipc = on`); for structural changes to `hyprpaper.conf` (the `preload` /
  `splash` / `ipc` lines themselves), restart the daemon.
- **hyprlock:** no daemon — launched fresh per lock. Config changes apply on next lock.

The rice engine's reload hooks for these templates should use the right command per file (and
guard with `pgrep`/`pidof` so they no-op when the daemon isn't running).

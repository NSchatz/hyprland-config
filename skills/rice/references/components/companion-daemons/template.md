# companion-daemons — templates

Two config files this component owns: `hypridle.conf` and `hyprpaper.conf`. The third companion
(`hyprlock.conf`) is owned by [`../lock-screen/template.md`](../lock-screen/template.md) — it's the
visual config, lock-screen drives its look.

All three land in `~/.config/hypr/` next to `hyprland.conf` but are **read by their own daemons**,
not `source=`d into Hyprland's config. They use a hyprlang-flavoured but **independent** config
language; see `gotchas.md`.

## `~/.config/hypr/hypridle.conf`

The four listener timeouts (dim → lock → dpms-off → suspend) are parameterized by
`companion_configs.hypridle_ladder`. The mapping table below maps the named preset to the four
listeners that the writer emits in order.

| Ladder | dim (s) | lock (s) | dpms-off (s) | suspend (s) |
|---|---|---|---|---|
| `balanced` *(default)* | 150 | 300 | 360 | 1800 |
| `aggressive` | 60 | 120 | 180 | 600 |
| `relaxed` | 300 | 900 | 1200 | *(omit)* |
| `never` | *(omit)* | *(omit)* | *(omit)* | *(omit)* |

```ini
general {
    lock_cmd        = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd  = hyprctl dispatch dpms on
    inhibit_sleep    = 3
}

# Dim the backlight as a "you're idle" hint.
{{#if dim_secs}}listener {
    timeout   = {{dim_secs}}
    on-timeout = brightnessctl -s set 10%
    on-resume  = brightnessctl -r
}{{/if}}

# Lock the session. Fires BEFORE dpms-off (see gotchas).
{{#if lock_secs}}listener {
    timeout   = {{lock_secs}}
    on-timeout = loginctl lock-session
}{{/if}}

# Turn the displays off.
{{#if dpms_secs}}listener {
    timeout   = {{dpms_secs}}
    on-timeout = hyprctl dispatch dpms off
    on-resume  = hyprctl dispatch dpms on
}{{/if}}

# Suspend to RAM. Desktops usually drop this tier — see gotchas.
{{#if suspend_secs}}listener {
    timeout   = {{suspend_secs}}
    on-timeout = systemctl suspend
}{{/if}}
```

### Branches

- If `companion_configs.hyprlock == false` (no lock screen / user has their own):
  - **Drop** the `lock_cmd` line from `general {}`.
  - **Drop** the lock listener entirely (the one calling `loginctl lock-session`).
  - Keep `before_sleep_cmd` and the dim/dpms/suspend listeners — those still make sense without a
    rice-generated lock UI.
- If `hypridle_ladder == "never"`, all four listeners are omitted; the `general {}` block is
  still emitted (so `before_sleep_cmd` still locks before suspend if a lock screen exists, and
  so the daemon stays running to honour `inhibit_sleep`).
- **Desktops** (no `laptop.enabled`) commonly want the suspend tier dropped even when the user
  picked `balanced` — see `gotchas.md`. The writer asks once; the template just renders what was
  recorded.

### Reload

```bash
systemctl --user restart hypridle   # or: pkill hypridle && hypridle &
```

There is **no** `hyprctl reload` equivalent for hypridle; the daemon reads its config once at
startup. The rice engine's render-manifest line for `hypridle.conf` should use the `systemctl`
restart as its reload hook (guarded — no-op when hypridle isn't running).

## `~/.config/hypr/hyprpaper.conf`

Emitted only when `companion_configs.hyprpaper == true`. The wallpaper path comes from
`wallpaper.path`; if the user skipped the wallpaper question, use the placeholder
`~/.config/hypr/wall.png` and tell the user to drop an image there.

```ini
preload   = {{wallpaper_path_or_placeholder}}
wallpaper = , {{wallpaper_path_or_placeholder}}
splash    = false
ipc       = on
```

- `{{wallpaper_path_or_placeholder}}` ← `wallpaper.path` from `answers.json`, falling back to
  `~/.config/hypr/wall.png`.
- `ipc = on` is **required** so the rice engine can switch wallpapers live via
  `hyprctl hyprpaper wallpaper ",<path>"` when the user re-themes. See `gotchas.md`.
- The empty monitor prefix (`,`) on the `wallpaper` line applies the image to every output. To
  pin a wallpaper to a single monitor, write `wallpaper = DP-1, <path>` (multi-monitor users
  with different wallpapers per output would extend this; not a default we generate).

### Reload

```bash
hyprctl hyprpaper preload "<new-path>"
hyprctl hyprpaper wallpaper ",<new-path>"
```

Both require `ipc = on`. The rice engine's reload hook for the wallpaper template should run
these two commands in order (guarded — no-op when hyprpaper isn't running).

## `~/.config/hypr/hyprlock.conf`

**Not owned by this component.** See [`../lock-screen/template.md`](../lock-screen/template.md) for
the `background`, `input-field`, and `label` blocks. The `companion_configs.hyprlock` boolean only
gates whether the lock-screen writer emits its template — it does not duplicate the template here.

## What does NOT belong here

- The `exec-once = hypridle` / `exec-once = hyprpaper` lines that actually launch these daemons —
  those live in [`../autostart/template.md`](../autostart/template.md).
- The `bind = $mainMod, X, exec, hyprlock` manual lock bind — that's
  [`../keybinds/template.md`](../keybinds/template.md).
- The visual hyprlock config (clock, input-field, background) — that's `../lock-screen/`.

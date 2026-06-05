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
listeners that the writer emits in order. The lock→dpms-off gap matches the upstream example
(`hyprwm/hypridle/assets/example.conf`): lock fires at the lock timeout, dpms-off fires 30s later.

| Ladder | dim (s) | lock (s) | dpms-off (s) | suspend (s) |
|---|---|---|---|---|
| `balanced` *(default)* | 150 | 300 | 330 | 1800 |
| `aggressive` | 60 | 120 | 150 | 600 |
| `relaxed` | 300 | 900 | 930 | *(omit)* |
| `never` | *(omit)* | *(omit)* | *(omit)* | *(omit)* |

```ini
general {
    lock_cmd         = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd  = hyprctl dispatch dpms on
    # inhibit_sleep default is 2 (auto): hypridle picks lock-notify when it
    # sees `hyprlock` in lock_cmd/before_sleep_cmd, else falls back to normal
    # inhibition. Override only if you understand the mode semantics:
    #   0 = disable, 1 = normal, 2 = auto (default), 3 = lock notify.
}

# Dim the backlight as a "you're idle" hint.
{{#if dim_secs}}listener {
    timeout    = {{dim_secs}}
    on-timeout = brightnessctl -s set 10
    on-resume  = brightnessctl -r
}{{/if}}

# Lock the session. Fires BEFORE dpms-off (see gotchas).
{{#if lock_secs}}listener {
    timeout    = {{lock_secs}}
    on-timeout = loginctl lock-session
}{{/if}}

# Turn the displays off.
{{#if dpms_secs}}listener {
    timeout    = {{dpms_secs}}
    on-timeout = hyprctl dispatch dpms off
    on-resume  = hyprctl dispatch dpms on
}{{/if}}

# Suspend to RAM. Desktops usually drop this tier — see gotchas.
{{#if suspend_secs}}listener {
    timeout    = {{suspend_secs}}
    on-timeout = systemctl suspend
}{{/if}}
```

> **`inhibit_sleep` semantics** (verified against `src/core/Hypridle.cpp` and the
> [wiki](https://wiki.hypr.land/Hypr-Ecosystem/hypridle/)): the int values are **not** a bitfield
> over standby/sleep — they're four discrete coordination modes. `2` (auto) is the default and is
> almost always correct; the rice template intentionally leaves it unset.

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

> **HARD BREAK at hyprpaper 0.8.0** (Dec 2025) — hyprpaper was rewritten on top of hyprtoolkit
> and the **classic `preload =` / `wallpaper = MON, PATH` syntax was removed**. The new config
> is anonymous `wallpaper { … }` blocks; `hyprctl hyprpaper preload` / `unload` / `listloaded` /
> `listactive` are also gone. Arch's `extra/hyprpaper` is on 0.8.x as of v0.8.4 (Apr 2026), so
> the writer must branch on the installed package version.

### 0.8+ (current, hyprtoolkit rewrite)

Verified against the [official wiki](https://wiki.hypr.land/Hypr-Ecosystem/hyprpaper/) and
`hyprwm/hyprpaper@main` `src/config/ConfigManager.cpp`.

```ini
wallpaper {
    monitor  =                                  # empty = fallback for any output without a target
    path     = {{wallpaper_path_or_placeholder}}
    fit_mode = cover                            # cover (default) | contain | tile | fill
}

# Misc options (set OUTSIDE the wallpaper {} block).
# Both ipc and splash default to true upstream, so these lines are explicit overrides only:
splash = false                                  # disable the hyprland splash text overlay
# ipc  = true                                   # default; leave implicit so a future flip is honored
```

- `monitor =` (empty) means **fallback** — applies to outputs that have no explicit `wallpaper {}`
  block targeting them. It is **not** "apply to all outputs" semantically (that's the legacy
  interpretation); in practice with a single-block config it works for every monitor.
- `fit_mode` accepts `cover` (default), `contain`, `tile`, `fill`.
- `ipc` defaults to `true` in 0.8+ — the legacy "off by default, must enable" note is **wrong**
  for this version. Only set `ipc = false` to opt out (e.g. battery savings; see gotchas).
- No more `preload` — hyprpaper loads paths on-demand from the `wallpaper {}` blocks.

#### Reload (0.8+)

```bash
hyprctl hyprpaper wallpaper '[<monitor>], [<path>], [<fit_mode>]'   # fit_mode optional; mon may be empty
hyprctl hyprpaper reload                                            # reread hyprpaper.conf
```

The `preload` / `unload` / `listloaded` / `listactive` subcommands **do not exist** in 0.8+.
A wallpaper-swap reload hook must use the single `wallpaper` IPC line above.

### Legacy (0.7.x and earlier — only if a user pins an older package)

```ini
preload   = {{wallpaper_path_or_placeholder}}
wallpaper = , {{wallpaper_path_or_placeholder}}
splash    = false
ipc       = on
```

- The empty monitor prefix (`,`) sets the fallback wallpaper. Pin per-monitor with
  `wallpaper = DP-1, <path>`.
- `ipc` defaulted to `1` (on) in 0.7.x too, but the legacy README example commented `# ipc = off`,
  so emitting `ipc = on` explicitly is defensive.
- Reload commands: `hyprctl hyprpaper preload <path>` then `hyprctl hyprpaper wallpaper ",<path>"`.

The writer should default to the **0.8+ block form**; only fall back to the legacy form if the
user has a pinned `hyprpaper` < 0.8.0 (detect via `pacman -Q hyprpaper`).

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

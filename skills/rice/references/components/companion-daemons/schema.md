# companion-daemons — answers.json slice

Keys this component owns under the top-level `companion_configs` key.

```json
{
  "companion_configs": {
    "hyprlock":         true,
    "hypridle_ladder":  "balanced | aggressive | relaxed | never",
    "hyprpaper":        true
  }
}
```

## Types

- `companion_configs.hyprlock` — boolean. `true` means **generate** `hyprlock.conf` (template owned
  by `../lock-screen/`); `false` means skip — the user already has one or doesn't want a lock. The
  flag is set independently of `lock_screen.enabled` so the user can keep their own hyprlock config
  even when the lock screen is otherwise enabled.
- `companion_configs.hypridle_ladder` — string, one of four named presets. Maps to the four
  `listener {}` timeouts in `hypridle.conf`:

  | Value | dim (s) | lock (s) | dpms-off (s) | suspend (s) |
  |---|---|---|---|---|
  | `balanced` *(default)* | 150 | 300 | 360 | 1800 |
  | `aggressive` | 60 | 120 | 180 | 600 |
  | `relaxed` | 300 | 900 | 1200 | — |
  | `never` | — | — | — | — |

  `relaxed` omits the suspend listener entirely; `never` omits **all four** listeners but
  `hypridle.conf` is still emitted (for the `general { before_sleep_cmd = … }` block).

- `companion_configs.hyprpaper` — boolean. `true` means **generate** `hyprpaper.conf`; `false`
  means the user picked `swww` or `none` for `autostart_env.wallpaper_tool`, or already has their
  own hyprpaper config they want preserved.

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (`companion-daemons`) | Renders `hypridle.conf` (ladder → listener timeouts) + `hyprpaper.conf` when the booleans are true. |
| `hyprland-component-writer` (`lock-screen`) | Renders `hyprlock.conf` only when `companion_configs.hyprlock == true` **AND** `lock_screen.enabled == true`. |
| `hyprland-component-writer` (`autostart`) | Emits `exec-once = hypridle` only when `hypridle_ladder != "never"` *or* `hyprlock` is true (hypridle is still needed for `before_sleep_cmd`); emits `exec-once = hyprpaper` only when `hyprpaper == true`. |
| `hyprland-package-installer` | Reads each boolean and the ladder string against `packages.md` and adds `hyprlock` / `hypridle` / `hyprpaper` to the install batch. |

## Validation

- `hyprlock` and `hyprpaper` must be present and boolean.
- `hypridle_ladder` must be one of the four exact strings; anything else fails generation.
- Cross-check: if `companion_configs.hyprlock == true` but `lock_screen.enabled == false`, the
  lock-screen template will not actually render — the validator emits a warning ("no lock UI to
  back the companion flag") and the writer drops the `lock_cmd` line from `hypridle.conf`
  regardless of the ladder value.

## Cross-references

- The ladder → listener mapping is reified in `template.md`.
- The `hyprlock.conf` template lives in [`../lock-screen/schema.md`](../lock-screen/schema.md) /
  [`../lock-screen/template.md`](../lock-screen/template.md); this slice does not duplicate the
  `lock_screen.*` keys.
- Wallpaper-tool selection (`autostart_env.wallpaper_tool`) lives in
  [`../env/schema.md`](../env/schema.md); the `hyprpaper` boolean here is derived from it but
  still asked.

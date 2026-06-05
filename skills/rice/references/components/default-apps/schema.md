# default-apps — answers.json slice

Keys this component owns under the top-level `default_apps` key.

```json
{
  "default_apps": {
    "browser": "firefox | chromium | brave | qutebrowser | <other>",
    "files":   "nautilus | thunar | dolphin | nemo | pcmanfm | null"
  }
}
```

## Types

- `default_apps.browser` — string. The browser executable (`command -v $browser` must work after
  install). Always populated.
- `default_apps.files` — string or `null`. Must be a **GUI** file manager (one that can be
  `exec`'d as a standalone process). TUI picks (`yazi`, `ranger`) **must be recorded as `null`**
  so the standard `$fileManager` variable + `bind = $mainMod, E, exec, $fileManager` are
  suppressed; the TUI bind belongs in `keybinds` as `bind = $mainMod, E, exec, $terminal -e
  <tui>`. See `gotchas.md` → "TUI file managers" for the why. Downstream code branches on `null`
  rather than checking key presence.

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (Hyprland topic — `hyprland.conf`) | Writes `$browser = …`; writes `$fileManager = …` only when non-null. |
| `hyprland-component-writer` (`keybinds`) | The `bind = $mainMod, B, exec, $browser` and `bind = $mainMod, E, exec, $fileManager` lines (the second skipped on null). |
| `hyprland-component-writer` (`env`) | Adds `MOZ_ENABLE_WAYLAND,1` when `browser == "firefox"`. |
| `hyprland-package-installer` | Reads `default_apps.browser` / `default_apps.files` against `packages.md` and adds to the install batch. |

## Validation

- `browser` is required.
- `files` may be absent, `null`, or a string — all valid.

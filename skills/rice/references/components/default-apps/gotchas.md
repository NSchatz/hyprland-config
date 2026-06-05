# default-apps — gotchas

## Firefox needs the Wayland env var

If the user picks Firefox, the `env` component **must** add `MOZ_ENABLE_WAYLAND,1` to `env.conf`.
Without it, Firefox falls back to XWayland — visible symptoms are blurred fonts on fractional
scale, no native Wayland touchpad gestures, and screen sharing not seeing windows. Read
`default_apps.browser` from `answers.json` and gate the env line on `== "firefox"`.

## Omit `$fileManager` when not chosen

If `default_apps.files` is `null` (user opted for a TUI in the terminal, or none), **do not write**
`$fileManager =` to `hyprland.conf`, and **do not emit** the `bind = $mainMod, E, exec,
$fileManager` line in `binds.conf`. Leaving a `$fileManager =` empty makes the bind a no-op
(`exec` of an empty command).

## Chromium / Brave / Electron apps on Wayland

These pick up Wayland through `ELECTRON_OZONE_PLATFORM_HINT,auto` in `env`. Safe across all GPUs;
the `env` component already emits it as part of its toolkit block.

## TUI "file managers" (yazi, ranger)

If the user picks a TUI, the bind has to launch it inside the terminal, not as a standalone process:

```ini
bind = $mainMod, E, exec, $terminal -e yazi
```

This belongs in `keybinds`, not here, but flag it so the writer doesn't emit `exec, yazi` directly.

## Default-app picks land in the install batch

The selected browser and file manager are both installable packages — even if the user picks a
non-default. See `packages.md` for the map; the installer agent reads it.

# default-apps

The browser + file manager that get wired to `$browser` / `$fileManager` in `hyprland.conf`. The
**terminal** and **launcher** picks live in their own components (they each get themed configs);
this component is just the non-themed default apps.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions (browser, file manager). |
| `schema.md` | The `answers.json` keys this component owns. |
| `template.md` | Variable definitions injected into `hyprland.conf` (`$browser`, `$fileManager`) — there's no dedicated `.conf` for this component. |
| `gotchas.md` | Firefox-Wayland status (no-op on 121+, `env` still emits the marker), Chromium/Brave/Electron ozone-hint story, "omit `$fileManager` if not chosen", TUI handling, Dolphin/Nautilus dep weight, `xdg-mime` for default-app wiring, **corpus survey** of variable names / picks / theming-by-ricochet patterns across the top ~12 rices. |
| `packages.md` | The browser + file-manager package map. |

## Where this component lands

- **Hyprland config:** the `$browser` and `$fileManager` lines in `hyprland.conf` (see
  `components/keybinds/template.md` for the variables block).
- **Keybinds:** the `bind = $mainMod, E, exec, $fileManager` line lives in `components/keybinds/`,
  not here. This component just defines the variables.
- **env:** if Firefox is the browser, `components/env/` still emits `MOZ_ENABLE_WAYLAND,1` as
  an opt-in marker (no-op on Firefox 121+, which defaults to Wayland — see `gotchas.md`). For
  Chromium / Brave / Electron, `env`'s `ELECTRON_OZONE_PLATFORM_HINT,auto` is what enables
  native Wayland.

## Related components

- [`terminal`](../terminal/) — its own group (themed config).
- [`launcher`](../launcher/) — its own group (themed config).
- [`keybinds`](../keybinds/) — the binds that launch the chosen apps.
- [`env`](../env/) — the Firefox-Wayland env var.

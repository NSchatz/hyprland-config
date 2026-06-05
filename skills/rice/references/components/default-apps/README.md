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
| `gotchas.md` | The Firefox-Wayland coupling (`MOZ_ENABLE_WAYLAND` belongs in `env`), and "omit `$fileManager` if not chosen". |
| `packages.md` | The browser + file-manager package map. |

## Where this component lands

- **Hyprland config:** the `$browser` and `$fileManager` lines in `hyprland.conf` (see
  `components/keybinds/template.md` for the variables block).
- **Keybinds:** the `bind = $mainMod, E, exec, $fileManager` line lives in `components/keybinds/`,
  not here. This component just defines the variables.
- **env:** if Firefox is the browser, `components/env/` adds `MOZ_ENABLE_WAYLAND,1`.

## Related components

- [`terminal`](../terminal/) — its own group (themed config).
- [`launcher`](../launcher/) — its own group (themed config).
- [`keybinds`](../keybinds/) — the binds that launch the chosen apps.
- [`env`](../env/) — the Firefox-Wayland env var.

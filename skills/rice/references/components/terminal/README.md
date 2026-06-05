# terminal

Interview group 5 — the terminal emulator. Owns the `$terminal` variable in `hyprland.conf` and a
themed config file for the chosen emulator. This is the surface the user stares at most, so it
gets its own group (look + functional knobs) and a dedicated colors file driven by the rice
palette.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 5a–5f (emulator, opacity, padding, cursor, font size, extras). |
| `schema.md` | The `terminal.*` keys this component owns in `answers.json`. |
| `template.md` | Per-emulator recipes — `kitty.conf` / `alacritty.toml` / `foot.ini` / `wezterm.lua` / `ghostty/config`, each `include`ing the rice-rendered colors file. |
| `styling.md` | Full design library (palette, fonts, padding, opacity/blur, decorations) — verbatim copy of `hyprland-reference/styling/terminals.md`. The source of truth for the look. |
| `gotchas.md` | Font family vs. size separation, `enable_swallow` + regex requirement, `$terminal` variable matching, Alacritty YAML→TOML migration. |
| `packages.md` | One Arch package per emulator pick. |
| `reload.md` | Apply scope (new windows only); no global signal reload across emulators. |

## Where this component lands

- **Hyprland config:** `$terminal = <emulator>` lands in the variables block at the top of
  `hyprland.conf`. The bind that launches it (`bind = $mainMod, Return, exec, $terminal`) is owned
  by the `keybinds` component.
- **Emulator config:** `~/.config/<emulator>/<config>`:
  - kitty → `~/.config/kitty/kitty.conf` (+ `~/.config/kitty/colors.conf`)
  - alacritty → `~/.config/alacritty/alacritty.toml` (+ imported `colors.toml`)
  - foot → `~/.config/foot/foot.ini` (colors merged in; foot does have `include=` but rice merges so dual `[colors-dark]` / `[colors-light]` blocks coexist with user edits)
  - wezterm → `~/.config/wezterm/wezterm.lua` (+ `colors.lua` `require`d)
  - ghostty → `~/.config/ghostty/config` (+ `palette = N=#hex` lines or `theme = …`)
- **Colors file:** rendered by the rice engine from `palette.conf` — see `_shared/colors-contract.md`
  for the exact variable names each emulator exports.
- **Window swallowing:** when enabled, `misc:enable_swallow = true` and `swallow_regex =
  ^(<terminal-class>)$` land in `look-feel/looknfeel.conf` — not here.

## Related components

- [`keybinds`](../keybinds/) — owns `bind = $mainMod, Return, exec, $terminal`.
- [`look-feel`](../look-feel/) — owns the `misc:enable_swallow` + `swallow_regex` lines.
- [`default-apps`](../default-apps/) — sibling group (browser, file manager). TUI file managers
  (yazi, ranger) get launched inside `$terminal`.
- [`fonts`](../../theming/fonts.md) — the monospace Nerd Font family (group 13) feeds the
  emulator's `font_family` / `font.normal.family` / `font-family`.
- [`palette`](../../theming/palettes.md) — the 16-color ANSI set rendered into the emulator's
  colors file via `_shared/colors-contract.md`.

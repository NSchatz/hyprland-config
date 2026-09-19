# terminal

Interview group 5 — the terminal emulator. Owns the `$terminal` variable in `hyprland.conf` and a
themed config file for the chosen emulator. This is the surface the user stares at most, so it
gets its own group (look + functional knobs) and a dedicated colors file driven by the rice
palette.

## What to read - read TWO files, not the folder

This component supports 5 tools, and a writer only ever authors for the one the interview
picked. Reading the others is what makes a recipe get skimmed instead of read.

**Read `common.md`, plus the ONE `tools/<tool>.md` matching `terminal.emulator`. Nothing else.**

| `terminal.emulator` | Read |
|---|---|
| `kitty` | `common.md` + [`tools/kitty.md`](tools/kitty.md) |
| `alacritty` | `common.md` + [`tools/alacritty.md`](tools/alacritty.md) |
| `foot` | `common.md` + [`tools/foot.md`](tools/foot.md) |
| `wezterm` | `common.md` + [`tools/wezterm.md`](tools/wezterm.md) |
| `ghostty` | `common.md` + [`tools/ghostty.md`](tools/ghostty.md) |

Each `tools/<tool>.md` is self-contained for that tool: what to emit, how to style it, how to
validate it, what bites, and how to reload it. `common.md` holds only what is true whichever
tool was picked.

## Other files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 5a–5f (emulator, opacity, padding, cursor, font size, extras). |
| `schema.md` | The `terminal.*` keys this component owns in `answers.json`. |
| `packages.md` | One Arch package per emulator pick. |
| `kitty.tmpl` | Engine colors template for kitty — 16 ANSI cells + chrome (`cursor_text_color`, `url_color`, tab bar, window borders). All wired through existing palette keys; no new schema keys. |
| `btop.tmpl` | Engine theme template for btop — full 42-key set verified against upstream (`aristocratos/btop/main/themes/dracula.theme`), including `cached_*`, `available_*`, `download_*`, `upload_*`, `process_*` meter gradients. |
| `cava.tmpl` | Engine colors template for cava — 8 gradient stops + foreground/background, matches HyDE/JaKooLit community standard. |

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

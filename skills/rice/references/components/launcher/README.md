# launcher

The app launcher (`$menu` invocation) and its themed config. Picks one of wofi / rofi / fuzzel /
tofi / walker / vicinae / anyrun and writes its config + style so the rice engine themes it from
`palette.conf`.

The launcher's invocation is exported as `$menu` in `hyprland.conf` (and `$dmenu` for piped lists).
The bind that fires it (`bind = $mainMod, R, exec, $menu`) lives in `components/keybinds/` — this
component just defines the variable and ships the themed config.

## What to read - read TWO files, not the folder

This component supports 7 tools, and a writer only ever authors for the one the interview
picked. Reading the others is what makes a recipe get skimmed instead of read.

**Read `common.md`, plus the ONE `tools/<tool>.md` matching `launcher.tool`. Nothing else.**

| `launcher.tool` | Read |
|---|---|
| `wofi` | `common.md` + [`tools/wofi.md`](tools/wofi.md) |
| `rofi` | `common.md` + [`tools/rofi.md`](tools/rofi.md) |
| `fuzzel` | `common.md` + [`tools/fuzzel.md`](tools/fuzzel.md) |
| `tofi` | `common.md` + [`tools/tofi.md`](tools/tofi.md) |
| `walker` | `common.md` + [`tools/walker.md`](tools/walker.md) |
| `vicinae` | `common.md` + [`tools/vicinae.md`](tools/vicinae.md) |
| `anyrun` | `common.md` + [`tools/anyrun.md`](tools/anyrun.md) |

Each `tools/<tool>.md` is self-contained for that tool: what to emit, how to style it, how to
validate it, what bites, and how to reload it. `common.md` holds only what is true whichever
tool was picked.

## Other files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 8a–8e (tool, mode, layout, icons, behavior). |
| `schema.md` | The `answers.json` keys this component owns. |
| `packages.md` | The launcher package map (wofi / rofi (repo, Wayland built-in since 2.0) / fuzzel / tofi AUR / walker AUR / vicinae AUR / anyrun AUR). |
| `wofi.tmpl` | Engine colors template — renders `~/.config/wofi/colors.css` (4 keys: `bg fg surface accent`). |
| `rofi.tmpl` | Engine colors template — renders `~/.config/rofi/colors.rasi` (8 keys: `bg bg-alt fg muted accent accent2 red green`). |
| `fuzzel.tmpl` | Engine colors template — merges into `~/.config/fuzzel/fuzzel.ini` `[colors]` (7 keys: `background text match selection selection-text selection-match border`; 7-of-11 upstream — see `gotchas.md`). |

## Where this component lands

- **Hyprland variables** (in `hyprland.conf`, owned by `keybinds`):
  - `$menu  = wofi --show drun` (or `rofi -show drun`, `fuzzel`, …)
  - `$dmenu = wofi --dmenu` (or `rofi -dmenu`, `fuzzel --dmenu`, …)
- **Config files** under `~/.config/`:
  - wofi: `~/.config/wofi/{config,style.css,colors.css}`
  - rofi: `~/.config/rofi/{config.rasi,theme.rasi,colors.rasi}`
  - fuzzel: `~/.config/fuzzel/fuzzel.ini` (colors merged into `[colors]` section)
  - tofi: `~/.config/tofi/config`
  - walker: `~/.config/walker/config.toml` + `style.css`
  - vicinae: `~/.config/vicinae/settings.json` (JSONC; themes live inside this same file via vicinae's own schema)
  - anyrun: `~/.config/anyrun/config.ron` + `style.css`
- **Hyprland blur**: a `layerrule` block for the launcher's namespace lives in
  `components/window-rules/` so frosted-glass works.

## Related components

- [`keybinds`](../keybinds/) — owns the `$menu` / `$dmenu` variables in `hyprland.conf` and the
  `bind = $mainMod, R, exec, $menu` line.
- [`window-rules`](../window-rules/) — owns the launcher `layerrule` blur block.
- [`default-apps`](../default-apps/) — the non-themed defaults (browser, file manager) live there;
  launcher is its own group because it gets a themed config.
- [`terminal`](../terminal/) — the other themed-app group with the same shape (config + colors
  file).
- [`utilities`](../utilities/) — clipboard pickers, emoji pickers, calculator, etc. use the
  `$dmenu` invocation owned here.

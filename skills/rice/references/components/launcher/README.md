# launcher

The app launcher (`$menu` invocation) and its themed config. Picks one of wofi / rofi / fuzzel /
tofi / walker / vicinae / anyrun and writes its config + style so the rice engine themes it from
`palette.conf`.

The launcher's invocation is exported as `$menu` in `hyprland.conf` (and `$dmenu` for piped lists).
The bind that fires it (`bind = $mainMod, R, exec, $menu`) lives in `components/keybinds/` — this
component just defines the variable and ships the themed config.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 8a–8e (tool, mode, layout, icons, behavior). |
| `schema.md` | The `answers.json` keys this component owns. |
| `template.md` | Per-tool config + style recipes (wofi, rofi, fuzzel, plus brief notes for tofi/walker/vicinae/anyrun). |
| `styling.md` | Full styling-technique catalog — palette/layout split, three selection idioms, icon-grid vs pill-list, `em`/`%` sizing, blur. Verbatim copy of the styling reference. |
| `gotchas.md` | `$menu` vs `$dmenu` is a different invocation, fuzzel hex format, rofi-wayland vs X-only rofi. |
| `validation.md` | Parse checks for wofi `config`, rofi `.rasi`, fuzzel `.ini`; CSS balanced braces. |
| `packages.md` | The launcher package map (wofi / rofi / rofi-wayland AUR / fuzzel / tofi AUR / walker AUR / vicinae AUR / anyrun AUR). |
| `reload.md` | Launchers are stateless — config applies on next launch. No signal reload. |

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
  - vicinae: `~/.config/vicinae/config.json` (themes follow vicinae's own format)
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

# Wallpaper Backends, Dynamic Theming & Cycling

## Backends

| Tool        | Set command                                         | Notes                              |
|-------------|-----------------------------------------------------|------------------------------------|
| `swww`      | `swww img <img> --transition-type any`              | Animated transitions; needs `swww-daemon` running. |
| `hyprpaper` | `hyprctl hyprpaper preload <img>` + `… wallpaper ,<img>`; persist in `hyprpaper.conf` | First-party, low overhead. |
| `swaybg`    | `swaybg -i <img> -m fill &`                          | Minimal, static.                   |
| `mpvpaper`  | `mpvpaper '*' <video>`                               | Video wallpapers (AUR).            |

`set-wallpaper.sh` picks the first available in the order swww → hyprpaper → swaybg and persists
`hyprpaper.conf` when hyprpaper is used.

## Dynamic theming (wallpaper → palette → everything)

`rice wallpaper <img>` runs: set wallpaper → `palette-from-wallpaper.sh` (regenerate
`~/.config/hypr-rice/palette.conf`) → `render-templates.sh` (re-theme + reload). Generators, in
preference order:

- **matugen** (Material You). Rendered via a matugen template into `palette.conf`. The MD3 →
  terminal `color0..15` mapping is **approximate** (Material You isn't a 16-color ANSI scheme).
  Great for cohesive UI accents.
- **wallust** / **pywal** (`wal`). Produce a true 16-color scheme (pywal-compatible
  `~/.cache/wal/colors.json`), mapped straight to `color0..15`/`bg`/`fg`; `accent` derived from
  `color4`/`color5`. Best for terminal-accurate palettes.

If no generator is installed, set the wallpaper and pick a **named/manual** palette via
`theme-config` instead; suggest installing `matugen` (or `wallust`) for automatic extraction.

## Cycling

- One-off random: `rice random [dir]` (default `~/Pictures/wallpapers`) — picks a random image and
  re-themes.
- **Automate (no Claude in the loop):**
  - *systemd user timer* — create `~/.config/systemd/user/wallpaper.service` (`ExecStart=%h/.config/hypr-rice/rice random`)
    and `wallpaper.timer` (`OnUnitActiveSec=30min`), then
    `systemctl --user enable --now wallpaper.timer`.
  - *Hyprland exec loop* — `exec-once = while :; do ~/.config/hypr-rice/rice random; sleep 1800; done`
    (simpler, but no persistence across restarts beyond the config).
- To theme on **every** wallpaper change regardless of who changed it, point the cycler at
  `rice wallpaper` so the palette regenerates each time.

## Wallpaper sources

Keep wallpapers in a dedicated dir (e.g. `~/Pictures/wallpapers`) so `rice random` and pickers
(waypaper, swww's `swww img`, a wofi/rofi script) can enumerate them. The chosen wallpaper path is
stored in `palette.conf` (`wallpaper=…`) so it's captured by theme profiles and git versioning.

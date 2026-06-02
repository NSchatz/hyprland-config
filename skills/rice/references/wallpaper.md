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

## Curated theme wallpapers (curl-downloadable)

The engine ships a **theme-tagged wallpaper catalog** so a user can pick a wallpaper that matches the
scheme they chose, without hunting for one. It lives at `assets/wallpapers.tsv` in the plugin and is
copied into `~/.config/hypr-rice/wallpapers.tsv` by `rice-init.sh`. Format is
`scheme<TAB>name<TAB>url`, where every `url` is a **direct `raw.githubusercontent.com` blob** that
`curl -L` downloads. Entries are tagged by scheme key — `catppuccin-mocha`/`-frappe`/`-macchiato`/
`-latte`, `rose-pine`, `gruvbox`, `nord`, `tokyo-night`, `dracula`, `everforest`, `kanagawa`,
`solarized` — plus an `any` group of theme-agnostic dark wallpapers offered alongside every dark
scheme (~100 entries total). All links are verified live when shipped.

Two `rice` CLI commands drive it (so it works standalone, without the plugin):

```bash
rice wallpapers                 # list the whole catalog, grouped by scheme
rice wallpapers nord            # list just Nord + the `any` set, numbered continuously
rice get-wallpaper nord 2 --set # download entry #2 to ~/Pictures/wallpapers/ and apply it
rice get-wallpaper nord arctic  # select by name substring instead of number
```

`get-wallpaper` saves to `~/Pictures/wallpapers/<scheme>-<name>.<ext>` (override with `--dir`). With
`--set` it applies the wallpaper and records its path in `palette.conf` **but keeps the current
palette** (no `palette-from-wallpaper` re-theme) — correct for "I picked Nord *and* a Nord wallpaper."
Drop `--set` to just download. In the interview this is **Area D6**: after the user picks a named
scheme, list `rice wallpapers <scheme>`, present the names via `AskUserQuestion`, then
`get-wallpaper … --set`. (For a *wallpaper-generated* palette the user already has an image; for a
*manual* palette, offer the `any` set.)

**Sources & licensing** (community wallpaper repos — the same ecosystem the styling research drew
from): zhichaoh/catppuccin-wallpapers (MIT), rose-pine/wallpapers (CC0), AngelJumbo/gruvbox-wallpapers
(community), linuxdotexe/nordic-wallpapers (MIT), tokyo-night/wallpapers (MIT), dracula/wallpaper (MIT),
Apeiros-46B/everforest-walls (community), Gurjaka/Kanagawa-Wallpapers + philikarus/Kanagawa-wallpapers
(community), visika/solarized-wallpapers (Unlicense), JaKooLit/Wallpaper-Bank and dharmx/walls
(community — personal use, attribution unclear). Tell the user where a wallpaper came
from when relevant. To extend the catalog, add a `scheme<TAB>name<TAB>url` line (verify the raw URL
resolves first); `rice-init.sh --force` re-copies the plugin's copy over the engine's.

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
`rice` instead; suggest installing `matugen` (or `wallust`) for automatic extraction.

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

## Battle-tested techniques (from real dotfiles)

Concrete, attributed idioms (JaKooLit `WallpaperAutoChange.sh`/`WallpaperSelect.sh`/`WallustSwww.sh`,
swww docs, hyprpaper wiki).

- *Set the transition look once via env* (JaKooLit): `export SWWW_TRANSITION_FPS=60` +
  `export SWWW_TRANSITION_TYPE=simple` (or `fade`/`grow`/`wave`/`outer`/`center`) instead of repeating
  `--transition-*` flags on every `swww img`. Per-monitor: `swww img -o "$focused_monitor" "$img"`.
- *Re-theme as a chained hook **after** the wallpaper is set* — passing the image path — to avoid a
  palette/cache race: `swww img "$wp" && wallust run -s "$wp"` (or `matugen image "$wp"`), then signal
  apps: `killall -SIGUSR2 waybar` (and ghostty), `makoctl reload`, `swaync-client -rs`, `hyprctl reload`.
- *hyprpaper switches live via IPC* (needs `ipc = on` in `hyprpaper.conf`):
  `hyprctl hyprpaper preload "$new"` → `hyprctl hyprpaper wallpaper ",$new"` → `hyprctl hyprpaper unload "$old"`.
  hyprpaper holds preloaded images in **RAM**, so a cycler must `unload` old ones or memory grows.
- *Thumbnail picker* (JaKooLit): feed rofi icon entries — `printf "%s\x00icon\x1f%s\n" "$name" "$path"` —
  or the simple `swww img "$(ls "$WALLDIR" | wofi --dmenu)"`. Pre-render GIF/video frames to PNG
  (`magick`/`ffmpeg`) into a cache dir for previews.
- *swww is archived → awww* (Codeberg, same author): detect the real binary (`awww-daemon`/`awww img`)
  rather than assuming `swww`; `awww` declares `provides=swww`. (This plugin's `set-wallpaper.sh`
  already handles the detection.)

## Wallpaper sources

Keep wallpapers in a dedicated dir (e.g. `~/Pictures/wallpapers`) so `rice random` and pickers
(waypaper, swww's `swww img`, a wofi/rofi script) can enumerate them. The chosen wallpaper path is
stored in `palette.conf` (`wallpaper=…`) so it's captured by theme profiles and git versioning.

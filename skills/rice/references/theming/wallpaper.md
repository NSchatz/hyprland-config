# Wallpaper Backends, Dynamic Theming & Cycling

The interview asks the wallpaper pick at component 14 (see
[`_interview-protocol.md`](../_interview-protocol.md) → "Components walked"). The chosen path lands
in `palette.conf` as `wallpaper=…` so it's captured by theme profiles and git versioning.

## Backends

| Tool | Set command | Notes |
|---|---|---|
| `swww` | `swww img <img> --transition-type any` | Animated transitions; needs `swww-daemon` running. |
| `awww` | `awww img <img>` | Codeberg fork (swww is archived); declares `provides=swww`. Detect by binary name. |
| `hyprpaper` | `hyprctl hyprpaper preload <img>` + `… wallpaper ,<img>`; persist in `hyprpaper.conf` | First-party, low overhead. Needs `ipc = on` for live IPC. |
| `swaybg` | `swaybg -i <img> -m fill &` | Minimal, static. |
| `mpvpaper` | `mpvpaper '*' <video>` | Video wallpapers (AUR). |

`scripts/set-wallpaper.sh` picks the first available in the order swww → awww → hyprpaper → swaybg
and persists `hyprpaper.conf` when hyprpaper is used.

## Curated theme wallpapers

The engine ships a **theme-tagged wallpaper catalog** so a user can pick a wallpaper that matches
the scheme they chose, without hunting for one. It lives at `assets/wallpapers.tsv` in the plugin
and is copied to `~/.config/hypr-rice/wallpapers.tsv` by `rice-init.sh`.

Format: `scheme<TAB>name<TAB>url`. Every `url` is a **direct `raw.githubusercontent.com` blob** that
`curl -L` downloads. Entries are tagged by scheme key — the 12 keys from
[`palettes.md`](palettes.md) (`catppuccin-mocha`/`-frappe`/`-macchiato`/`-latte`, `rose-pine`,
`gruvbox`, `nord`, `tokyo-night`, `dracula`, `everforest`, `kanagawa`, `solarized-dark`) — plus an
`any` group of theme-agnostic dark wallpapers offered alongside every dark scheme (~100 entries
total). All links are verified live when shipped.

Two `rice` CLI commands drive it (so it works standalone, without the plugin):

```bash
rice wallpapers                 # list the whole catalog, grouped by scheme
rice wallpapers nord            # list just Nord + the `any` set, numbered continuously
rice get-wallpaper nord 2 --set # download entry #2 to ~/Pictures/wallpapers/ and apply it
rice get-wallpaper nord arctic  # select by name substring instead of number
```

`get-wallpaper` saves to `~/Pictures/wallpapers/<scheme>-<name>.<ext>` (override with `--dir`). With
`--set` it applies the wallpaper and records its path in `palette.conf` **but keeps the current
palette** (no `palette-from-wallpaper` re-theme) — correct for "I picked Nord *and* a Nord
wallpaper." Drop `--set` to just download. In the interview, after a named scheme is picked, list
`rice wallpapers <scheme>`, present the names via `AskUserQuestion`, then `get-wallpaper … --set`.
For a *wallpaper-generated* palette the user already has an image; for a *manual* palette, offer
the `any` set.

### Sources & licensing

Community wallpaper repos: zhichaoh/catppuccin-wallpapers (MIT), rose-pine/wallpapers (CC0),
AngelJumbo/gruvbox-wallpapers (community), linuxdotexe/nordic-wallpapers (MIT),
tokyo-night/wallpapers (MIT), dracula/wallpaper (MIT), Apeiros-46B/everforest-walls (community),
Gurjaka/Kanagawa-Wallpapers + philikarus/Kanagawa-wallpapers (community), visika/solarized-wallpapers
(Unlicense), JaKooLit/Wallpaper-Bank and dharmx/walls (community — personal use, attribution
unclear). Tell the user where a wallpaper came from when relevant. To extend the catalog, add a
`scheme<TAB>name<TAB>url` line (verify the raw URL resolves first); `rice-init.sh --force` re-copies
the plugin's copy over the engine's.

## Dynamic theming (wallpaper → palette → everything)

`rice wallpaper <img>` runs: set wallpaper → `palette-from-wallpaper.sh` (regenerates
`~/.config/hypr-rice/palette.conf`) → `render-templates.sh` (re-theme + reload). Generators, in
preference order:

- **matugen** (Material You / Material Design 3). Rendered via a matugen template into
  `palette.conf`. The MD3 → terminal `color0..15` mapping is **approximate** (Material You isn't a
  16-color ANSI scheme). Great for cohesive UI accents. Map: `primary→accent`, `secondary→accent2`,
  `surface→bg`, `on_surface→fg`, neutrals → `muted`/`surface`.
- **wallust** / **pywal** (`wal`). Produce a true 16-color scheme (pywal-compatible
  `~/.cache/wal/colors.json`), mapped straight to `color0..15`/`bg`/`fg`; `accent` derived from
  `color4`/`color5`. Best for terminal-accurate palettes.

If no generator is installed, set the wallpaper and pick a **named/manual** palette via `rice`
instead; suggest installing `matugen` (or `wallust`) for automatic extraction. Detection:
`scripts/detect-theme-tools.sh`.

### matugen 4.x configuration

matugen 4.x **requires** the `[config]` table in `~/.config/matugen/config.toml`; the bare
`[templates.*]` entries don't render without it. Minimal working config:

```toml
[config]
# (required header — must be present even if empty)

[config.wallpaper]
set = true
command = "swww img {{ image }}"

[templates.hyprland]
input_path  = '~/.config/matugen/templates/hyprland-colors.conf'
output_path = '~/.config/hypr/colors.conf'
post_hook   = 'hyprctl reload'
```

With `[config.wallpaper] set = true`, one `matugen image <wall>` call sets the wallpaper **and**
regenerates every template.

### matugen `--prefer` for headless multi-source

When matugen runs headless (cron, systemd timer, Hyprland `exec-once` loop) and the system has
multiple Material You source candidates (Wayland portal, gsettings, file source), pass
`--prefer image` so it doesn't fall back to a portal that isn't responding:

```bash
matugen --prefer image image "$wp"
```

Scheme & mode flags: `-t scheme-tonal-spot` (or `-expressive`/`-vibrant`/`-content`/`-neutral`/
`-monochrome`) and `-m dark|light`.

### wallust quick-config

`~/.config/wallust/wallust.toml`:

```toml
backend  = "Kmeans"            # Resized/FastResize fast; Kmeans/Full accurate
palette  = "dark16"            # or harddark / softdark / softlight
check_contrast = true

[templates.hyprland]
template = "hyprland.conf"     # in ~/.config/wallust/templates/
target   = "~/.config/hypr/colors.conf"
# pywal = true                 # opt into pywal {color1} syntax; default is Jinja2 {{color1}}
```

Run: `wallust run "$wp"`. The old `new_engine` key is gone — Jinja2 is the default.

## Cycling

- **One-off random** — `rice random [dir]` (default `~/Pictures/wallpapers`). Picks a random image
  and re-themes.
- **systemd user timer** — create `~/.config/systemd/user/wallpaper.service` with
  `ExecStart=%h/.config/hypr-rice/rice random` and `wallpaper.timer` with `OnUnitActiveSec=30min`,
  then `systemctl --user enable --now wallpaper.timer`. Survives Hyprland restart, has logging.
- **Hyprland `exec-once` loop** — `exec-once = while :; do ~/.config/hypr-rice/rice random; sleep
  1800; done` in `autostart.conf`. Simpler but no persistence across compositor restart beyond the
  config; no logging.

To theme on **every** wallpaper change regardless of who changed it, point the cycler at `rice
wallpaper` (not `rice random`) so the palette regenerates each time.

## Battle-tested techniques

Attributed idioms from real dotfiles (JaKooLit `WallpaperAutoChange.sh` / `WallpaperSelect.sh` /
`WallustSwww.sh`, swww docs, hyprpaper wiki):

- **Set the transition look once via env** (JaKooLit): `export SWWW_TRANSITION_FPS=60` +
  `export SWWW_TRANSITION_TYPE=simple` (or `fade`/`grow`/`wave`/`outer`/`center`) instead of
  repeating `--transition-*` flags on every `swww img`. Per-monitor: `swww img -o
  "$focused_monitor" "$img"`.
- **Chain palette regen *after* set** to avoid a race: `swww img "$wp" && wallust run -s "$wp"` (or
  `matugen image "$wp"`), then signal apps: `killall -SIGUSR2 waybar` (ghostty too), `makoctl
  reload`, `swaync-client -rs`, `hyprctl reload`.
- **hyprpaper switches live via IPC** (needs `ipc = on` in `hyprpaper.conf`):
  ```
  hyprctl hyprpaper preload  "$new"
  hyprctl hyprpaper wallpaper ",$new"
  hyprctl hyprpaper unload   "$old"
  ```
  hyprpaper holds preloaded images in **RAM**, so a cycler must `unload` old ones or memory grows.
- **Thumbnail picker** (JaKooLit): feed rofi icon entries — `printf "%s\x00icon\x1f%s\n" "$name"
  "$path"` — or the simple `swww img "$(ls "$WALLDIR" | wofi --dmenu)"`. Pre-render GIF/video frames
  to PNG (`magick`/`ffmpeg`) into a cache dir for previews.
- **swww is archived → awww** (Codeberg, same author): detect the real binary
  (`awww-daemon`/`awww img`) rather than assuming `swww`; `awww` declares `provides=swww`. This
  plugin's `set-wallpaper.sh` already handles the detection.

## Wallpaper sources

Keep wallpapers in a dedicated dir (e.g. `~/Pictures/wallpapers`) so `rice random` and pickers
(waypaper, `swww img`, a wofi/rofi script) can enumerate them. The chosen wallpaper path lives in
`palette.conf` (`wallpaper=…`).

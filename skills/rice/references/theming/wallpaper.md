# Wallpaper Backends, Dynamic Theming & Cycling

The interview asks the wallpaper pick at component 14 (see
[`_interview-protocol.md`](../_interview-protocol.md) → "Components walked"). The chosen path lands
in `palette.conf` as `wallpaper=…` so it's captured by theme profiles and git versioning.

## Backends

| Tool | Set command | Notes |
|---|---|---|
| `swww` | `swww img <img> --transition-type any` | Animated transitions; needs `swww-daemon` running. **Upstream archived** — `awww` is the maintained fork. |
| `awww` | `awww img <img>` | Codeberg fork (`codeberg.org/LGFae/awww`); declares `provides=swww`. Detect by binary name. ML4W (`dotfiles/.config/ml4w/scripts/ml4w-wallpaper`), dusky (`.config/hypr/source/autostart.lua`), Matt-FTW (`scripts/autostart/services`) all already migrated. |
| `hyprpaper` (≥ 0.8) | live: `hyprctl hyprpaper wallpaper '[<mon>], [<path>], [<fit_mode>]'`; persist in `~/.config/hypr/hyprpaper.conf` via anonymous `wallpaper { … }` blocks | First-party. **0.8.0 rewrite removed `preload =` and `wallpaper = MON, PATH` — see `../components/companion-daemons/template.md`** for the block form. `ipc` defaults to `true`. No `preload`/`unload`/`listloaded` subcommands anymore. |
| `hyprpaper` (≤ 0.7.x) | legacy: `hyprctl hyprpaper preload <img>` → `… wallpaper ,<img>` → `… unload <old>` | Holds preloaded images in RAM; a cycler **must `unload`** old paths or memory grows. |
| `swaybg` | `swaybg -i <img> -m fill &` | Minimal, static, no IPC — fully restart on every change. |
| `mpvpaper` | `mpvpaper '*' <video>` (or per-monitor `mpvpaper -o "$VIDEO_OPTS" "$mon" "$video"`) | Video/GIF wallpapers (AUR). Pin one process per monitor and `pkill -f -9 mpvpaper` before re-running (the end-4 / HyDE pattern). |

`scripts/set-wallpaper.sh` picks the first available in the order swww → awww → hyprpaper → swaybg
and writes the daemon-specific config when the daemon needs one (hyprpaper).

### Architecture fork — Quickshell shells own the wallpaper themselves

Three of the corpus's Quickshell-based rices **draw the wallpaper inside the shell process**, with
no external daemon at all:

- **caelestia-dots/shell** — `modules/background/Wallpaper.qml` renders the wallpaper as a layered
  `Image` driven by `services/Wallpapers.qml`.
- **noctalia-dev/noctalia-shell** — `Modules/Background/Background.qml` drives one
  `PanelWindow { WlrLayershell.layer: WlrLayer.Background }` per screen, with shader-based
  transitions (wipe, disc, stripe, pixelate, honeycomb).
- **AvengeMedia/DankMaterialShell** — `quickshell/Modules/WallpaperBackground.qml` + a
  `WallpaperWatcherDaemon` plugin; `SettingsData.getMonitorWallpaper(name)` is the source of truth.

For these rices the "wallpaper daemon" is the shell itself — `qs -c <name>` (or
`caelestia shell -d`, `dms run`, `noctalia-shell`) is the only `exec-once` line that needs to fire
and "restoring last wallpaper on login" is `SessionData`'s job. **Do not also schedule swww/awww/
hyprpaper for these shells** — two surfaces fighting over the background layer flicker.

The non-Quickshell-owning rices (waybar-based — HyDE, JaKooLit, dusky, ML4W, Matt-FTW, binnewbs,
Matt-FTW) all use an external daemon; swww/awww dominates in this group (see daemon-by-rice
table below).

## Daemon choice across the corpus

| Rice | Daemon | Engine | How it restores last wallpaper on login |
|---|---|---|---|
| end-4/dots-hyprland | mpvpaper (video) or matugen-set image | matugen | `dots/.config/hypr/custom/scripts/__restore_video_wallpaper.sh` — **generated** by `scripts/colors/switchwall.sh` on every pick; replays per-monitor `mpvpaper` invocations or no-ops for stills. `exec-once = $HOME/.config/hypr/custom/scripts/__restore_video_wallpaper.sh` in `hyprland/execs.lua`. |
| caelestia-dots/shell | shell-owned (Quickshell) | matugen | `services/Wallpapers.qml` persists `current` to its own state; restarting the shell restores it. No script needed. |
| prasanthrangan/hyprdots (HyDE) | swww (preferred), awww, hyprpaper, mpvpaper, waydeeper, kon — all dispatched by `Configs/.local/lib/hyde/wallpaper.<backend>.sh` | wallbash (`.dcol`) | `swwwallpaper.sh` re-applies `$HYDE_CACHE_HOME/wall.set` on session start (`exec-once = $scrPath/swwwallpaper.sh` — corpus-cited canonical). The swww/awww paths also call `swww query && swww restore` if the daemon is freshly started. |
| noctalia-dev/noctalia-shell | shell-owned (Quickshell) | hand-rolled JSON | `Settings.data.wallpaper.current` is shell state. No external daemon. |
| AvengeMedia/DankMaterialShell | shell-owned (Quickshell) + `WallpaperWatcherDaemon` plugin | matugen (Go-orchestrated) | `SessionData.getMonitorWallpaper(name)` reads persisted per-monitor wallpaper; greeter mode also reads it. |
| mylinuxforwork/dotfiles (ML4W) | awww | matugen | `dotfiles/.config/ml4w/scripts/ml4w-autostart` reads `~/.cache/ml4w/hyprland-dotfiles/current_wallpaper` and calls `ml4w-wallpaper "$(cat $CACHE_FILE)"` which starts `awww-daemon`, sets the image via `awww img --transition-type $SETTINGS_TRANSITION_EFFECT`, then re-runs `matugen image "$IMAGE_PATH" --source-color-index 0 -m "$mode"` and `qs ipc call theme-manager reload`. |
| JaKooLit/Hyprland-Dots | swww | wallust | `config/hypr/configs/Startup_Apps.conf`: `exec-once = swww-daemon --format xrgb`; swww's own cache redraws the last image on next `swww img` — but JaKooLit also offers `swww-daemon --format xrgb && swww img $wallDIR/<file>.png` as the persistent-wallpaper opt-in. Re-theming on every wallpaper change goes through `config/hypr/scripts/WallustSwww.sh` (calls `wallust run -s "$wallpaper_path"`, then SIGUSR2 to waybar/ghostty). |
| caelestia-dots/caelestia | (paired with caelestia/shell) | hand-rolled JSON | Shell owns it. |
| Jas-SinghFSU/HyprPanel | (consumer-supplied) | matugen-aware JSON | Not opinionated — `themes/*.json` only colors the panel, the wallpaper daemon is whatever the user runs. |
| dusklinux/dusky | awww | matugen | `.config/hypr/source/autostart.lua` → `hl.exec_cmd("uwsm-app -- awww-daemon")`. No explicit restore script — awww's own cache redraws after the daemon starts. |
| flickowoa/dotfiles | hand-rolled (theme.conf-driven) | hand-rolled | Theme switcher in `config/hypr/themes/base/scripts/apply.sh` is invoked manually; no autostart restore. |
| ryan4yin/nix-config | hyprpaper (`home/programs/wayland/hyprpaper.nix`) | nix-managed | NixOS module pins the path; daemon restart re-reads `hyprpaper.conf`. |
| linuxmobile/hyprland-dots (kenos) | swaybg or hand-rolled | hand-rolled JSON | Static path, set by `.config/hypr/startup.conf` `exec-once`. No live switching. |
| Axenide/Ax-Shell | matugen `[config.wallpaper] set = true` (delegates to `swww`/`hyprpaper`) | matugen | Matugen's wallpaper-set hook re-runs on every theme apply; `ax-shell` itself reads colors from matugen output. |
| koeqaife/hyprland-material-you | hand-rolled Python | hand-rolled Python | Python service in `hypryou/utils/colors/generation.py` manages wallpaper + colors together. |
| binnewbs/arch-hyprland | swww (JaKooLit-derived) | matugen | Mirrors JaKooLit pattern: `swww-daemon` exec-once, swww cache restores. |
| fufexan/dotfiles | hyprpaper (`home/programs/wayland/hyprpaper.nix`) | nix-managed | NixOS module pins the path; daemon-restart redraws. |
| Matt-FTW/dotfiles | awww | hand-rolled (catppuccin-style) | `.config/hypr/scripts/autostart/services` → `awww-daemon --format argb &`. Switcher in `scripts/random_wallpaper` branches on `pgrep -x hyprpaper` vs `pgrep -x swww`. |

**Read of the table:** swww/awww is the dominant daemon (HyDE, ML4W, JaKooLit, dusky, binnewbs,
Matt-FTW) — animated transitions + the built-in `restore` subcommand make it the default
choice for waybar-based rices. hyprpaper appears mostly in nix-managed rices (ryan4yin,
fufexan) where the config is statically managed and the 0.8 syntax break is handled at
rebuild time. mpvpaper is an opt-in addition (end-4 ships it as the primary path, HyDE/JaKooLit
as a swappable backend) — it's also the only daemon for video wallpapers. **Three Quickshell
rices skip the external-daemon layer entirely** — caelestia/noctalia/DMS draw the background
themselves via `WlrLayer.Background` panel windows.

## Daemon-choice trade-offs

When the rice generator asks "which wallpaper daemon" (component 14), the table above resolves
to four practical paths:

- **swww / awww** — the default for waybar-based rices. Animated transitions
  (`--transition-type wipe|grow|center|fade|outer|simple|wave`), per-monitor wallpapers, the
  built-in `swww restore` subcommand that redraws the last cached image. swww upstream is
  archived; pick `awww` on a fresh install (declares `provides=swww`, same CLI).
- **hyprpaper** — first-party. Lower overhead. Static only — no transitions. **0.8.0 (Dec 2025)
  rewrote the config and removed `preload`/`unload`/`listloaded`/`listactive` IPC** —
  rices that pin an older hyprpaper or a stale config snippet break on a fresh Arch install
  (current `extra/hyprpaper` is 0.8.4 as of Apr 2026). Use only when the user wants the
  first-party stack and a static look.
- **swaybg** — minimal, no IPC, no transitions. Restart the process to change images. A
  reasonable pick for a "set it once, no animations" desktop.
- **mpvpaper** — only path to video / animated wallpapers. Per-monitor `mpvpaper -o "<opts>"
  "$monitor" "$video"`, one process per output. `pkill -f -9 mpvpaper` before re-applying so
  old instances don't pile up.
- **Quickshell-owned (caelestia / noctalia / DMS)** — the shell is the wallpaper daemon. No
  external pick needed; the shell's autostart line already covers it.

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
regenerates every template. **dusky leaves this block out** (sets the wallpaper externally via
`awww`); **Ax-Shell uses it** (matugen owns the set). Both are valid — the rice engine sets
`[config.wallpaper]` only when the engine itself manages the daemon CLI.

### matugen `--prefer` for headless multi-source

When matugen runs headless (cron, systemd timer, Hyprland `exec-once` loop) and the system has
multiple Material You source candidates (Wayland portal, gsettings, file source), pass
`--prefer image` so it doesn't fall back to a portal that isn't responding:

```bash
matugen --prefer image image "$wp"
```

Scheme & mode flags: `-t scheme-tonal-spot` (or `-expressive`/`-vibrant`/`-content`/`-neutral`/
`-monochrome`) and `-m dark|light`. end-4's `switchwall.sh` (`dots/.config/quickshell/ii/scripts/
colors/switchwall.sh`) passes `--source-color-index 0` and assembles `--mode` and `--type` from
the picker UI; the canonical "right way" to invoke matugen from a wallpaper change.

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

## Restore last wallpaper on login

The autostart component (`../components/autostart/template.md`) schedules **one** generated
script — `~/.config/hypr/scripts/restore-theme.sh` — as `exec-once` *after* the wallpaper-daemon
line. The script's body is **engine-specific**: each engine's job (matugen / wallust / wallbash /
none) is to overwrite this file every time a new wallpaper is picked. The autostart template
just schedules it; this section is the canonical body per engine.

### Why a script and not just `exec-once = swww img <wall>`

- `swww-daemon` starts **empty** — without a restore call you log in to no wallpaper at all (or
  the default solid color), even though the last-set image is still cached.
- `hyprpaper.conf` has the path baked in, but rebuilding from a stale palette without re-running
  the engine leaves you with old colors on the new image (or, if the rice rendered colors during
  the previous `rice apply`, with last week's accents over today's `current_wallpaper`).
- `matugen` / `wallust` / `wallbash` each have a "regenerate everything from this wallpaper"
  command — running it on login is **idempotent**, cheap, and means the user always sees the
  exact state they left.
- Three rices (caelestia, noctalia, DMS) **own this in the shell** and need no script at all
  (see "Architecture fork" above).

### Canonical restore-script body per engine

The engine writes this file on every `rice apply` / wallpaper pick. The wallpaper-daemon set-command
is parameterised on `$WP_DAEMON` (`swww` / `awww` / `hyprpaper` / `swaybg` / `mpvpaper`) and the
last wallpaper path (`palette.conf`'s `wallpaper=` line, also cached at
`~/.cache/hypr-rice/current_wallpaper`).

**`engine = matugen`** (the most common — used by end-4, ML4W, dusky, Ax-Shell, binnewbs,
DMS-orchestrated):

```bash
#!/usr/bin/env bash
# Generated by rice apply / palette-from-wallpaper.sh. Do not edit by hand.
set -eu
WP="$(awk -F= '/^wallpaper=/{print $2}' "$HOME/.config/hypr-rice/palette.conf")"
[ -z "$WP" ] && exit 0
[ -f "$WP" ] || exit 0

# 1. Make sure the daemon is alive (idempotent — short-circuits if running).
pgrep -x swww-daemon  >/dev/null || swww-daemon  >/dev/null 2>&1 &
pgrep -x awww-daemon  >/dev/null || awww-daemon  >/dev/null 2>&1 &
sleep 0.3

# 2. Re-render templates against the cached palette (matugen 4.x; one call covers
#    every [templates.*] block AND, if [config.wallpaper] is set, the daemon CLI).
matugen --prefer image image "$WP" -m "${RICE_MODE:-dark}" >/dev/null 2>&1 || true

# 3. If matugen did NOT own the daemon (no [config.wallpaper] set = true),
#    paint the image now.
case "${WP_DAEMON:-swww}" in
    swww)     swww img "$WP" --transition-type fade ;;
    awww)     awww img "$WP" --transition-type fade ;;
    hyprpaper) hyprctl hyprpaper wallpaper ",${WP}" 2>/dev/null || true ;;  # 0.8+ form
    swaybg)   pkill -x swaybg 2>/dev/null; swaybg -i "$WP" -m fill & ;;
    mpvpaper) pkill -f -9 mpvpaper; for m in $(hyprctl monitors -j | jq -r '.[].name'); do
                  mpvpaper -o "no-audio loop hwdec=auto panscan=1.0" "$m" "$WP" &
                  sleep 0.1
              done ;;
esac

# 4. Signal apps to pick up the freshly-rendered colors. The render manifest
#    already does most of this, but the daemons started in step 1 may have
#    raced past the SIGUSR2.
hyprctl reload >/dev/null 2>&1 || true
pgrep -x waybar  >/dev/null && killall -SIGUSR2 waybar  2>/dev/null || true
pgrep -x mako    >/dev/null && makoctl reload          2>/dev/null || true
pgrep -x swaync  >/dev/null && swaync-client -rs       2>/dev/null || true
```

Cited from: end-4 `switchwall.sh` (the `matugen "${matugen_args[@]}"` invocation +
`__restore_video_wallpaper.sh` generator); ML4W `ml4w-autostart` + `ml4w-wallpaper` (the
`awww img` + `matugen image "$IMAGE_PATH" --source-color-index 0 -m "$mode"` chain); dusky
`autostart.lua` (the `awww-daemon` pgrep guard).

**`engine = wallust`** (JaKooLit pattern):

```bash
#!/usr/bin/env bash
# Generated by rice apply. Do not edit by hand.
set -eu
WP="$(awk -F= '/^wallpaper=/{print $2}' "$HOME/.config/hypr-rice/palette.conf")"
[ -z "$WP" ] && exit 0
[ -f "$WP" ] || exit 0

# 1. Daemon up.
pgrep -x swww-daemon >/dev/null || swww-daemon --format xrgb &
sleep 0.3

# 2. Paint the wallpaper.
swww img "$WP"

# 3. Re-derive the palette AND every template in wallust.toml from this wall.
#    -s (silent) matches JaKooLit's WallustSwww.sh.
wallust run -s "$WP" || true

# 4. Reload apps that don't auto-pick-up file changes.
hyprctl reload >/dev/null 2>&1 || true
pgrep -x waybar  >/dev/null && killall -SIGUSR2 waybar  2>/dev/null || true
pgrep -x ghostty >/dev/null && for p in $(pidof ghostty); do kill -SIGUSR2 "$p"; done
```

Cited from: JaKooLit `config/hypr/scripts/WallustSwww.sh` (the `wallust run -s "$wallpaper_path"`
+ SIGUSR2-to-waybar/ghostty pattern); JaKooLit `Startup_Apps.conf` (the `swww-daemon --format
xrgb` line).

**`engine = wallbash`** (HyDE pattern — for users who imported HyDE's `.dcol` templates):

```bash
#!/usr/bin/env bash
# Generated by rice apply. Defers entirely to HyDE's swwwallpaper.sh.
exec "$HOME/.local/lib/hyde/swwwallpaper.sh"
```

`swwwallpaper.sh` itself dispatches to the configured backend
(`Configs/.local/lib/hyde/wallpaper.<backend>.sh` — `awww` / `swww` / `hyprpaper` / `mpvpaper` /
`kon` / `waydeeper`), regenerates the `.dcol` color files, and runs `pkill -SIGUSR2 waybar`. The
rice engine's `restore-theme.sh` doesn't try to reimplement this — it just trusts the script the
user already has.

**`engine = none`** (no automatic palette regen on login — user pinned a named scheme like
Catppuccin and wants it stable across wallpapers):

```bash
#!/usr/bin/env bash
# Generated by rice apply. Do not edit by hand.
set -eu
WP="$(awk -F= '/^wallpaper=/{print $2}' "$HOME/.config/hypr-rice/palette.conf")"
[ -f "$WP" ] || exit 0
pgrep -x swww-daemon >/dev/null || swww-daemon &
sleep 0.3
case "${WP_DAEMON:-swww}" in
    swww|awww) "${WP_DAEMON}" img "$WP" ;;
    hyprpaper) hyprctl hyprpaper wallpaper ",${WP}" 2>/dev/null
               # if hyprpaper just started and isn't ready, the conf in
               # ~/.config/hypr/hyprpaper.conf already has the right path baked in
               ;;
    swaybg)    pkill -x swaybg 2>/dev/null; swaybg -i "$WP" -m fill & ;;
    mpvpaper)  pkill -f -9 mpvpaper
               for m in $(hyprctl monitors -j | jq -r '.[].name'); do
                   mpvpaper -o "no-audio loop hwdec=auto panscan=1.0" "$m" "$WP" &
               done ;;
esac
```

No palette regen — just re-paints the wall so a `swww-daemon` cold start doesn't show a blank
desktop. Equivalent to `swww img "$(swww query | awk -F: '/image:/{print $NF; exit}')"` after the
daemon is up — or, more bluntly, `swww query && swww restore` once the daemon is ready (the
upstream-canonical "redraw the last cached image" call).

### Choosing `WP_DAEMON` at script-generation time

The engine writes the daemon name into the script at *generate* time, not detect-at-runtime —
the user's choice from component 14 is the authority. The auto-detect fallback for the manual
`rice wallpaper <img>` path (no engine state yet) uses the order swww → awww → hyprpaper →
swaybg → mpvpaper (first running daemon wins); see `scripts/detect-wallpaper-tool.sh`.

### Where the script lives

`~/.config/hypr/scripts/restore-theme.sh` (chmod 755). The autostart template's
`{{restore_script_path}}` resolves to exactly this path. Engine-generated, never user-edited —
every `rice apply` truncates and rewrites it. Matches end-4
(`__restore_video_wallpaper.sh` warning: *"Generated by switchwall.sh - Don't modify it by
yourself"*), ML4W (`ml4w-autostart` calls `ml4w-wallpaper "$(cat $CACHE_FILE)"`), HyDE
(`exec-once = $scrPath/swwwallpaper.sh`).

## Lock-screen wallpaper decoupling

hyprlock paints its own background from `background { path = … }` — **independent of the
desktop wallpaper**. Three corpus patterns:

- **Match the desktop wallpaper** (default; HyDE, JaKooLit, Matt-FTW, dusky): `background { path
  = screenshot; blur_passes = 3 }` paints a blurred grab of the current Hyprland frame, which
  *is* the desktop wallpaper. Re-themes for free on every wallpaper change.
- **Pin a different image** (community pattern, often a brand asset or a solid color): `path =
  ~/.config/hypr/lock.png` or `path = "" ; color = rgb(1e1e2e)`. Doesn't follow the desktop
  cycler; explicit "this is the lock look".
- **Pre-baked blurred wallpaper** (ML4W): `~/.cache/ml4w/hyprland-dotfiles/blurred_wallpaper.png`
  is generated by `ml4w-wallpaper` whenever the desktop wallpaper changes, and hyprlock points
  at that file with `blur_passes = 0`. Lock-screen looks like the desktop blurred, but the GPU
  cost of the blur is paid once (at wallpaper-pick) instead of every unlock.

The rice engine's hyprlock template (in `../components/lock-screen/`) defaults to `path =
screenshot` (option 1) so it auto-follows the desktop. Switching to option 2 is a
`lock_screen.wallpaper_strategy` answer; option 3 is an opt-in that only matugen / wallust
engines can drive (needs the pre-blur step in the restore script). See
`../components/lock-screen/styling.md` → "Battle-tested techniques → Background depth → Bake the
blur offline" for the ML4W recipe.

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
`WallustSwww.sh`, end-4 `switchwall.sh`, HyDE `wallpaper.*.sh` family, ML4W `ml4w-wallpaper`,
swww docs, hyprpaper wiki):

- **Set the transition look once via env** (JaKooLit): `export SWWW_TRANSITION_FPS=60` +
  `export SWWW_TRANSITION_TYPE=simple` (or `fade`/`grow`/`wave`/`outer`/`center`) instead of
  repeating `--transition-*` flags on every `swww img`. Per-monitor: `swww img -o
  "$focused_monitor" "$img"`.
- **Cursor-aware transition origin** (HyDE `wallpaper.swww.sh` / `wallpaper.awww.sh`):
  `--transition-pos "$(hyprctl cursorpos | grep -E '^[0-9]' || echo '0,0')"` makes the wipe
  animate out from where the cursor is. Standard idiom across HyDE's swww/awww backends.
- **Chain palette regen *after* set** to avoid a race: `swww img "$wp" && wallust run -s "$wp"` (or
  `matugen image "$wp"`), then signal apps: `killall -SIGUSR2 waybar` (ghostty too), `makoctl
  reload`, `swaync-client -rs`, `hyprctl reload`.
- **Force-refresh a running hyprlock after a script-driven label** (HyDE): `pkill -u $USER
  -SIGUSR2 hyprlock` — pushes a synchronous redraw of `cmd[update:N]` labels instead of waiting
  for the next tick. Also used in playback-control buttons on the lock screen.
- **hyprpaper switches live via IPC** (≤ 0.7.x — needs `ipc = on` in `hyprpaper.conf`):
  ```
  hyprctl hyprpaper preload  "$new"
  hyprctl hyprpaper wallpaper ",$new"
  hyprctl hyprpaper unload   "$old"
  ```
  hyprpaper holds preloaded images in **RAM**, so a cycler must `unload` old ones or memory grows.
  **0.8+ uses one line: `hyprctl hyprpaper wallpaper '[<mon>], [<path>], [<fit_mode>]'`**, no
  preload step — see `../components/companion-daemons/template.md` for the full break-down.
- **`swww query && swww restore`** (HyDE `wallpaper.swww.sh` / `wallpaper.awww.sh`): the
  upstream-supplied "redraw the last cached image" sequence — runs after starting the daemon
  fresh so a freshly-loaded session sees the same wallpaper the user had last time without an
  explicit `swww img <path>` call. Effectively built-in restore.
- **One-process-per-monitor mpvpaper** (end-4 `__restore_video_wallpaper.sh`): `for monitor in
  $(hyprctl monitors -j | jq -r '.[] | .name'); do mpvpaper -o "$VIDEO_OPTS" "$monitor"
  "$video_path" &; sleep 0.1; done`. The `sleep 0.1` between launches prevents a race where the
  mpv handshake collides on shared GPU resources. Always `pkill -f -9 mpvpaper` first.
- **Thumbnail picker** (JaKooLit): feed rofi icon entries — `printf "%s\x00icon\x1f%s\n" "$name"
  "$path"` — or the simple `swww img "$(ls "$WALLDIR" | wofi --dmenu)"`. Pre-render GIF/video frames
  to PNG (`magick`/`ffmpeg`) into a cache dir for previews.
- **Cache file as the source of truth** (ML4W `~/.cache/ml4w/hyprland-dotfiles/current_wallpaper`,
  HyDE `$HYDE_CACHE_HOME/wall.set`): a single text file containing the last wallpaper path,
  written on every set, read on every restore. Avoids parsing daemon state. The rice engine
  already does this via `palette.conf`'s `wallpaper=` line — same idea, fewer files.
- **swww is archived → awww** (Codeberg, same author): detect the real binary
  (`awww-daemon`/`awww img`) rather than assuming `swww`; `awww` declares `provides=swww`. This
  plugin's `set-wallpaper.sh` already handles the detection. ML4W, dusky, Matt-FTW, HyDE all
  default to `awww`; JaKooLit still ships `swww-daemon` in its `Startup_Apps.conf`.

## Wallpaper sources

Keep wallpapers in a dedicated dir (e.g. `~/Pictures/wallpapers`) so `rice random` and pickers
(waypaper, `swww img`, a wofi/rofi script) can enumerate them. The chosen wallpaper path lives in
`palette.conf` (`wallpaper=…`).

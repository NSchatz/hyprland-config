# The Rice Interview (unified)

The single question bank for the `rice` skill — the same one whether you're **generating** a config
from scratch (Mode A: ask all areas) or **re-theming** an existing desktop (Mode B: ask only areas
**C** and **D**). Wallpaper-only (Mode D) and profile (Mode C) flows ask nothing here beyond the
image path / profile name. Keeping one bank means a fresh config and a later re-theme can never drift.

Ask with `AskUserQuestion`, **batched by area** (one call per area, several questions per call).
Always present the recommended default — marked **(default)** — as the first option, so "just pick
good defaults" can skip ahead. Skip anything already answered by `$ARGUMENTS` or discovered in an
existing config. Run `detect-version.sh` + `detect-theme-tools.sh` first so options reflect what's
installed (bias defaults to installed tools; name the package for anything missing — never install).

Map every answer to its template: areas A–C/E/F → `config-templates.md`; area D → the rice engine's
`palette.conf` (`engine.md`) which renders the colors. For *why a value looks good*, the styling
library (`hyprland-reference/.../styling/`) backs each look choice; cite it when explaining.

---

## Area A — Monitors & input

**A1. Monitor setup**
- Single monitor, auto-detect **(default)** → `monitor = , preferred, auto, auto`
- Single, specific resolution/refresh → ask res + refresh, e.g. `2560x1440@144`
- Dual side-by-side → ask both names/res; place the second at `<width>x0`
- More than two / complex → collect each monitor's name, mode, position, scale

Real names come from `hyprctl monitors`; use detected names, else placeholders (`DP-1`, `HDMI-A-1`,
`eDP-1`) + a note to adjust. For unknown hardware the `, highrr, auto, 1` / `, highres, auto, 1`
"magic" modes pick the highest refresh / resolution.

**A2. Fractional scaling?** (HiDPI / laptop panels)
- No, scale 1 **(default)**
- Yes, 1.5 · Yes, 2 · Custom

**Gotcha:** when a fractional `scale` is pinned, also emit a matching `env = GDK_SCALE,N` (area E)
and `xwayland { force_zero_scaling = true }` or XWayland/GTK apps render blurry/wrong-sized.

**A3. Keyboard layout** → free text, default `us`. Offer common `kb_options` (off by default):
`caps:swapescape` or `caps:escape` (Caps→Esc, the popular pick), `compose:caps`; for a multi-layout
(`kb_layout = us, es`) add `grp:win_space_toggle` (or `grp:alt_shift_toggle`) to cycle layouts.
Optional baseline: `accel_profile = flat` (no mouse accel), `numlock_by_default = true`.

**A4. Touchpad** (only if a laptop/touchpad is likely)
- Natural scroll + tap-to-click on **(default)** · Traditional scroll, tap on · No touchpad / desktop

The full touchpad block also offers `disable_while_typing`, `clickfinger_behavior`, `scroll_factor`.

---

## Area B — Keybinds & apps

**B1. Mod key** — SUPER (Windows key) **(default)** · ALT. Use `$mainMod` as the variable.

**B2. Terminal** → default `kitty`; common: `alacritty`, `foot`, `wezterm`, `ghostty`.
**B3. App launcher** → default `wofi --show drun`; common: `rofi -show drun`, `fuzzel`, `tofi-drun`.
**B4. Browser** → default `firefox`; common: `chromium`, `brave`, `qutebrowser`.
(Define these as `$terminal`/`$menu`/`$browser`/`$fileManager` variables and reference them in binds.)

**B5. Keybind flavor**
- Official default (SUPER+Q terminal, C close, R menu, E files, V float, M exit) **(default — matches
  the shipped config + tutorials, so muscle memory transfers)**
- i3/sway-style (SUPER+Return terminal, Q close, D menu, F fullscreen)
- Add vim HJKL focus (on top of either; `togglesplit` then moves off `J` → `T`)
- Minimal (just essentials)

Bind split-toggle with `layoutmsg, togglesplit` (not a bare dispatcher). Always include: terminal,
close, exit, launcher, float, fullscreen, workspaces 1–10 switch + move-to, focus move, window move,
mouse move/resize (`bindm`), volume & brightness (`bindel` — repeat + works while locked), and a
special/scratchpad workspace. Idioms worth using: `bindl` for media/`Print` so they work on the lock
screen, `bindd` (described) so a cheat-sheet can read the binds, `code:10`–`code:19` for the number
row (layout-independent). Wire **ecosystem binds** for the tools chosen in area E (see `ecosystem.md`):
screenshot (`hyprshot -m region` / `grimblast copy area` / `grim -g "$(slurp)" - | wl-copy`), lock
(`hyprlock`), color picker (`hyprpicker -a`), logout (`wlogout`), clipboard
(`cliphist list | $menu | cliphist decode | wl-copy`).

---

## Area C — Look & feel  *(re-theming asks this too)*

The compositor's own aesthetic. Defaults are the well-tuned shipped 0.54 values; see
`styling/hyprland-decoration.md` for the values-that-look-good and `design-principles.md` for the
archetypes. Offer to match a recognizable archetype (Catppuccin soft-glass · flat/minimal · heavy
glass · maximalist floating-islands) and set the knobs below to suit.

**C1. Gaps & borders** — Comfortable (in 5 / out 20 / border 2) **(default)** · Tight (2/6/1) ·
None (0/0/1) · Spacious (8/30/3). Rhythm: `gaps_out ≈ 2× gaps_in`, and rounding tracks `gaps_out`.

**C2. Corner rounding** — Rounded (10) **(default)** · Subtle (5) · Square (0). On 0.5x add
`rounding_power = 2` (bump to 2.3–4 for a softer "squircle").

**C3. Blur & shadows** — Blur + shadows on **(default)** · Blur on, shadows off · Both off (lighter
GPU). Frosted preset: `blur { size 6, passes 2 }`; pair window opacity with blur or it does nothing.

**C4. Window opacity** — Opaque 1.0 **(default)** · Slightly translucent inactive (active 1.0 /
inactive 0.9). Keep content windows opaque; make chrome (terminals) translucent per-app if wanted.

**C5. Animations** — On, smooth defaults **(default)** · On, snappy/fast (scale speeds ~0.6×) · Off.
Curve families to offer: the shipped `easeOutQuint` set, the `wind/winIn` slide-overshoot family, or
Material-3 `md3_decel`/`md3_accel` pairs.

**C6. Border color** — From my palette **(default)** → `col.active_border = $accent $accent2 45deg`
(the `$accent`/`$accent2` come from the engine's `colors.conf`, so the border re-themes for free) ·
Custom gradient (free text, e.g. `rgba(33ccffee) rgba(00ff99ee) 45deg`).

**C7. Layout** — Dwindle (BSP-like) **(default)** · Master/stack. (`scrolling` is plugin-only, not
core 0.54 — only offer it if a scrolling-layout plugin is installed.)

---

## Area D — Palette & fonts  *(re-theming asks this too)*

This is what makes the desktop **coherent** instead of a stock-gray box with a random border. Resolve
every answer into the engine's `palette.conf` (see *Mapping* below). Don't pick a scheme or fonts
silently — present them; if the user says "good defaults", use **Catppuccin Mocha** + an installed
Nerd Font (mono) + an installed UI font, and say what you chose.

**D1. Palette source** (always ask)
- **Named scheme (default)** → one from `palettes.md` (Catppuccin Mocha/Frappé/Macchiato/Latte,
  Gruvbox, Nord, Tokyo Night, Rosé Pine, Dracula, Everforest, Kanagawa, Solarized Dark). Ask the
  scheme as a second question; each ships a ready preset profile + matching wallpapers (D6).
- **Match my wallpaper** → needs `matugen` or `wallust`; confirm the wallpaper path. If neither is
  installed, say so and fall back to a named scheme or manual (don't install). With matugen, the
  scheme type is selectable (`-t scheme-tonal-spot`/`-expressive`/`-vibrant`/…); Material-You →
  ANSI is approximate, wallust/pywal give a true 16-color scheme.
- **Manual hex** → ask at least `bg`, `fg`, `accent`; derive the rest or collect all 16.

**D2. Accent** (let the user override) — each scheme has a sensible default `accent`/`accent2`; offer
to keep it or pick another hue from the scheme (Catppuccin mauve → blue/green/peach) or a custom hex.
The accent drives borders, focus rings, and bar highlights — the highest-leverage single choice.

**D3. Light vs dark** (only when ambiguous) — most schemes are dark; if the user picked one with a
light variant (Catppuccin Latte), confirm. For light, set GTK `color-scheme = prefer-light`.

**D4. UI / sans font** (always present) — the GTK/app text font. Present installed families first
(`FONT_SANS=`/`CURRENT_*FONT*`): Inter, Lexend, Rubik, Cantarell, Noto Sans, Adwaita Sans. Default to
an installed UI font; offer the catalog (naming the package) for one not present. Record as
`font_ui = <Family> <size>` (e.g. `Inter 11`).

**D5. Monospace / Nerd font** (always present) — terminal/bar/fetch/prompt font. **Default to an
installed Nerd Font** (`JetBrainsMono Nerd Font` is the universal pick) so glyphs render instead of
tofu (▯). Offer installed Nerd Fonts first; if `MISSING_NERD_FONT`, offer the catalog + name the
package and warn glyph-heavy bars/prompts show boxes until one is installed. Common pairings:
*Inter/Noto Sans + JetBrainsMono NF* (safe), *Space Grotesk + JetBrains Mono NF* (modern),
*Rubik/Readex Pro + Maple Mono NF* (cozy). Record as `font_mono = <Family> <size>`.

**D6. Matching wallpaper** (offer after the scheme is chosen — skip if the source was already
"match my wallpaper"). The engine ships a curated, theme-tagged catalog of curl-downloadable
wallpapers (`rice wallpapers <scheme>` lists the ones matching the chosen scheme, plus a few
theme-agnostic `any` ones). Present the names with `AskUserQuestion`, then download + set the pick:
`rice get-wallpaper <scheme> <number|name> --set` (downloads to `~/Pictures/wallpapers/` and sets it
**without** re-theming, so the named-scheme palette is kept). For a manual palette, offer the `any`
set. Offering one is optional — a desktop with no wallpaper looks unfinished, so it's worth asking.

### Mapping answers → `palette.conf`

Write resolved values into `~/.config/hypr-rice/palette.conf` (the rice state / source of truth; hex
without `#`):

```
scheme=<name | "manual" | "wallpaper">
wallpaper=<path or empty>
bg fg surface muted cursor accent accent2 red green yellow blue magenta cyan
color0 … color15
font_ui=<Family size>
font_mono=<Family size>
```

**Always populate `accent2`** — even on the manual path where only `bg`/`fg`/`accent` were given
(default it to `accent` or a derived neighbour). Templates like `col.active_border = $accent $accent2
45deg` reference it, so a missing value errors the reload. Then `rice apply` renders every wired app.
Full contract + render flow: `engine.md`; per-scheme hex: `palettes.md`; fonts: `fonts.md`.

---

## Area E — Autostart & env  *(generate only)*

Prefer first-party Hypr ecosystem tools as defaults (see `ecosystem.md`). Only suggest installed tools
as on-by-default; for missing ones, offer but note they need installing. Never install.

**E1. Status bar** — waybar **(default)** · hyprpanel · none · other.
**E2. Notification daemon** — mako **(default)** · dunst · swaync (has a control center) · none.
*Only one* can run (they fight for the `org.freedesktop.Notifications` D-Bus name).
**E3. Wallpaper tool** — hyprpaper **(default, first-party)** · swww/awww (animated) · none. For
swww emit the `SWWW_DAEMON_BIN` from `detect-version.sh` (`swww-daemon` *or* the `awww` fork's
`awww-daemon`), never a hard-coded binary.
**E4. Polkit agent** — hyprpolkitagent **(default)** → `systemctl --user start hyprpolkitagent`
(systemd unit survives reloads) · polkit-gnome · polkit-kde · none.
**E5. Also autostart** (multi-select; defaults checked): clipboard history —
`wl-paste --type text --watch cliphist store` **and** a second `--type image` line **(on)**; network
tray `nm-applet --indicator` **(on if NetworkManager)**; bluetooth `blueman-applet` (off); idle
`hypridle` **(on)**; blue-light `hyprsunset -t 4000` (off); OSD `swayosd-server` (off). The portal
env-propagation pair (`dbus-update-activation-environment --systemd …` + `systemctl --user
import-environment …`) is the standard "screen-share is black" fix — include it.
**E6. Lock screen (hyprlock)** — Yes **(default)** → generate a starter `hyprlock.conf` (area F) and
bind a lock key; if hypridle is on, point its `lock_cmd` at hyprlock · No.
**E7. Screen sharing / portals** (inform) — needs `xdg-desktop-portal-hyprland` +
`xdg-desktop-portal-gtk` and `XDG_CURRENT_DESKTOP=Hyprland`; add the env var and note missing packages.

**E8. Environment variables** (multi-select, sensible defaults checked):
- Cursor: `XCURSOR_SIZE,24` + `HYPRCURSOR_SIZE,24` **(on)**
- Toolkit: `QT_QPA_PLATFORM,wayland;xcb`, `GDK_BACKEND,wayland,x11,*` **(on)**
- Qt theming: `QT_QPA_PLATFORMTHEME,qt6ct` (on if qt6ct present; `QT_STYLE_OVERRIDE,kvantum` if Kvantum)
- Session/portals: `XDG_CURRENT_DESKTOP,Hyprland` (on)
- Firefox Wayland: `MOZ_ENABLE_WAYLAND,1` (on if browser is firefox)
- NVIDIA set (`LIBVA_DRIVER_NAME,nvidia`, `__GLX_VENDOR_LIBRARY_NAME,nvidia`, `GBM_BACKEND,nvidia-drm`,
  `NVD_BACKEND,direct`) **(off — only the proprietary `nvidia` driver)**

**Gate the NVIDIA block on the active driver, not the card.** Emit the NVIDIA lines only when
`NVIDIA_PROPRIETARY=1`; under `nouveau` they break GLX/VA-API. `ELECTRON_OZONE_PLATFORM_HINT,auto` is
safe on any GPU. Don't ask "is it NVIDIA?" — read the driver and confirm the result.

---

## Area F — Companion configs  *(generate only — when the matching tool is chosen)*

Generate a starter config for each tool picked in area E. These live in `~/.config/hypr/` next to
`hyprland.conf` but are read by their own daemons (NOT `source=`d). Formats: `ecosystem.md` +
`config-templates.md`. Ask before generating each if the user may already have one — never overwrite
without it being captured by the timestamped backup.

- **hyprlock** → `hyprlock.conf` (required by hyprlock or it errors): blurred-screenshot background +
  accent-outlined input pill + clock label. Colors are **literal hex** from the palette (hyprlock
  can't read Hyprland `$vars`).
- **hypridle** → `hypridle.conf`: dim → lock → dpms-off → suspend listeners; `lock_cmd = pidof
  hyprlock || hyprlock`; lock *before* dpms-off; `before_sleep_cmd = loginctl lock-session`.
- **hyprpaper** → `hyprpaper.conf`: `preload` + `wallpaper` (ask for an image path or leave a
  placeholder); set `ipc = on` so the wallpaper can be switched live.

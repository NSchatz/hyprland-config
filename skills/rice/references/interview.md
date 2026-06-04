# The Rice Interview (unified)

The single question bank for the `rice` skill — the same one whether you're **generating** a config
from scratch (Mode A: ask all groups) or **re-theming** an existing desktop (Mode B: ask only the
**look & feel**, **palette**, **fonts**, and **wallpaper** groups). Wallpaper-only (Mode D) and profile
(Mode C) flows ask nothing here beyond the image path / profile name. Keeping one bank means a fresh
config and a later re-theme can never drift.

rice is the **all-in-one** skill: a from-scratch build configures *and* generates the functional
configs for the whole desktop — compositor, terminal, status bar, launcher, notifications, lock screen
— then themes every surface from one palette. So the interview is **organized one group per component**,
each with its own focused set of questions, rather than a few broad catch-all areas.

## How to ask — group structure & the 4-question cap

Ask with `AskUserQuestion`, **one group per component, in order**. The tool accepts **at most 4
questions per call**, so a group with more than four sub-questions **must be split across consecutive
calls** — never drop, merge, or silently skip a sub-question just to fit the cap. Walk every group and
ask each sub-question; a group only shrinks when `$ARGUMENTS` or an existing config already answers some.

Always present the recommended default — marked **(default)** — as the first option, so "just pick good
defaults" can skip ahead. Run `detect-version.sh` + `detect-theme-tools.sh` first so options reflect
what's installed (bias defaults to installed tools; name the package for anything missing — never
install). Use `multiSelect` for the genuinely multi-choice questions (bar modules, autostart, env vars).

**The groups** (a from-scratch run walks all of them; expect **~21–26 `AskUserQuestion` calls** total —
if you've asked only a handful, you've collapsed groups incorrectly, go ask the rest):

| # | Group | Mode A | Mode B | Splits into |
|---|---|---|---|---|
| 1 | Monitors | ✓ | | 1 call |
| 2 | Input (keyboard & touchpad) | ✓ | | 1 call |
| 3 | Keybinds | ✓ | | 1 call |
| 4 | Default apps (browser, files) | ✓ | | 1 call |
| 5 | **Terminal** | ✓ | | 1–2 calls |
| 6 | **Status bar + waybar design** | ✓ | | 4 calls |
| 7 | **Launcher** | ✓ | | 1–2 calls |
| 8 | **Notifications** | ✓ | | 1 call |
| 9 | **Lock screen** | ✓ | | 1 call |
| 10 | Window look & feel | ✓ | ✓ | 2 calls |
| 11 | Palette | ✓ | ✓ | 1–2 calls + accent pick |
| 12 | Fonts | ✓ | ✓ | 1 call |
| 13 | Wallpaper | ✓ | ✓ | 1 call (catalog pick) |
| 14 | Autostart & env | ✓ | | 2 calls |
| 15 | Companion configs | ✓ | | 1 call |
| 16 | **Shell & prompt** | ✓ | | 1–2 calls |

Map every answer to its template: groups 1–10/14/15 → `config-templates.md`; the functional bar/launcher/
notification configs → `../../desktop-shell/references/components.md`; the shell/prompt configs →
`../../shell-config/references/shells.md`; groups 11–13 (and the prompt/fish *colors*) → the rice engine's
`palette.conf` (`engine.md`) which renders the colors. For *why a value looks good*, the styling library
(`hyprland-reference/.../styling/`) backs each look choice; cite it when explaining.

---

## 1. Monitors

**1a. Monitor setup**
- Single monitor, auto-detect **(default)** → `monitor = , preferred, auto, auto`
- Single, specific resolution/refresh → ask res + refresh, e.g. `2560x1440@144`
- Dual side-by-side → ask both names/res; place the second at `<width>x0`
- More than two / complex → collect each monitor's name, mode, position, scale

Real names come from `hyprctl monitors`; use detected names, else placeholders (`DP-1`, `HDMI-A-1`,
`eDP-1`) + a note to adjust. For unknown hardware the `, highrr, auto, 1` / `, highres, auto, 1`
"magic" modes pick the highest refresh / resolution.

**1b. Fractional scaling?** (HiDPI / laptop panels)
- No, scale 1 **(default)**
- Yes, 1.5 · Yes, 2 · Custom

**Gotcha:** when a fractional `scale` is pinned, also emit a matching `env = GDK_SCALE,N` (group 14)
and `xwayland { force_zero_scaling = true }` or XWayland/GTK apps render blurry/wrong-sized.

---

## 2. Input (keyboard & touchpad)

**2a. Keyboard layout** → free text, default `us`.
**2b. Caps/Esc & layout options** (offer common `kb_options`, off by default): `caps:swapescape` or
`caps:escape` (Caps→Esc, the popular pick), `compose:caps`; for a multi-layout (`kb_layout = us, es`) add
`grp:win_space_toggle` (or `grp:alt_shift_toggle`) to cycle layouts.
**2c. Input baseline** (multi-select, off by default): `accel_profile = flat` (no mouse accel),
`numlock_by_default = true`.
**2d. Touchpad** (only if a laptop/touchpad is likely): Natural scroll + tap-to-click on **(default)** ·
Traditional scroll, tap on · No touchpad / desktop. The full block also offers `disable_while_typing`,
`clickfinger_behavior`, `scroll_factor`.

---

## 3. Keybinds

**3a. Mod key** — SUPER (Windows key) **(default)** · ALT. Use `$mainMod` as the variable.
**3b. Keybind flavor**
- Official default (SUPER+Q terminal, C close, R menu, E files, V float, M exit) **(default — matches
  the shipped config + tutorials, so muscle memory transfers)**
- i3/sway-style (SUPER+Return terminal, Q close, D menu, F fullscreen)
- Minimal (just essentials)
**3c. Add vim HJKL focus?** — No **(default)** · Yes (on top of either flavor; `togglesplit` then moves
off `J` → `T`).

Bind split-toggle with `layoutmsg, togglesplit` (not a bare dispatcher). Always include: terminal,
close, exit, launcher, float, fullscreen, workspaces 1–10 switch + move-to, focus move, window move,
mouse move/resize (`bindm`), volume & brightness (`bindel` — repeat + works while locked), and a
special/scratchpad workspace. Idioms worth using: `bindl` for media/`Print` so they work on the lock
screen, `bindd` (described) so a cheat-sheet can read the binds, `code:10`–`code:19` for the number row
(layout-independent). Wire **ecosystem binds** for the tools chosen below + in group 14 (see
`ecosystem.md`): screenshot (`hyprshot -m region` / `grimblast copy area` / `grim -g "$(slurp)" - |
wl-copy`), lock (`hyprlock`), color picker (`hyprpicker -a`), logout (`wlogout`), clipboard
(`cliphist list | $menu | cliphist decode | wl-copy`).

---

## 4. Default apps

The launched apps wired to `$terminal`/`$menu`/`$browser`/`$fileManager` variables. (Terminal and
launcher get their own detailed groups next — here just confirm the non-themed picks.)

**4a. Browser** → default `firefox`; common: `chromium`, `brave`, `qutebrowser`. (Firefox → set
`MOZ_ENABLE_WAYLAND,1` in group 14.)
**4b. File manager** → default `nautilus`; common: `thunar`, `dolphin`, `nemo`, `pcmanfm`, or a TUI
(`yazi`, `ranger`) launched in `$terminal`.

---

## 5. Terminal  *(dedicated group)*

The terminal is the surface the user stares at most — worth its own group. Choice here also sets
`$terminal` for binds and gets a themed colors file (see `templates.md` / `styling/terminals.md`).

**5a. Emulator** → `kitty` **(default)**; common: `alacritty`, `foot`, `wezterm`, `ghostty`. Bias to the
installed one (`detect-theme-tools.sh`).
**5b. Background opacity** — Opaque 1.0 **(default)** · Slightly translucent 0.95 · Frosted 0.85 (pair
with Hyprland blur on the terminal's layer for a glass look) · Custom.
**5c. Window padding** — Comfortable (~8px) **(default)** · Tight (2–4px) · Roomy (12–16px).
**5d. Cursor shape & blink** — Block, no blink **(default)** · Beam · Underline · Block + blink.

Second call if needed:
**5e. Font size** — 11 **(default)** · 10 · 12 · 13 (the family is the monospace/Nerd font from group 12;
just size here).
**5f. Extras** (multi-select, off by default): font ligatures, larger scrollback (10k+ lines), audible
bell off, confirm-on-close off.

---

## 6. Status bar  *(dedicated group — full functional depth + waybar design)*

rice generates the **functional** bar config (`config.jsonc`) and its themed `style.css`, not just the
colors. Recipes: `../../desktop-shell/references/components.md` (waybar). The **design** library
`styling/waybar.md` holds the pattern catalog this group draws on — archetypes, the techniques harvested
from **~55 community configs** off the [Waybar Examples wiki](https://github.com/Alexays/Waybar/wiki/Examples),
plus the vertical/dual-bar/dock/macOS recipes. **Don't pick a bar look silently** — walk the design
questions; the option labels below are ordered by how often the pattern shows up in that corpus
(commonest = the default, first). Split across **four calls**: basics → design·shape → design·color &
state → content. The two design calls are the "waybar design" heart of this group.

**Call 1 — basics:**
**6a. Bar tool** — waybar **(default)** · hyprpanel (own config model) · none.
**6b. Form & position** — Top horizontal **(default)** · Bottom (dock feel) · Vertical (narrow left/right
column) · Dual (top + bottom). *Vertical and dual change the whole layout — see `styling/waybar.md`
("Bar form").*
**6c. Height & density** — Standard ~34px **(default)** · Compact ~26–28px · Tall ~40–44px. *(Vertical:
this becomes column **width** ~32–44px.)*

**Call 2 — Waybar design · shape** *(the look language — `styling/waybar.md` "Archetypes" backs each):*
**6d. Shape archetype** — Floating islands (transparent bar, three translucent rounded groups — the
dominant modern look) **(default)** · Separated per-module pills (every module its own capsule) · Single
bordered lozenge (whole bar one outlined capsule) · Edge-to-edge solid (flush, square, minimal). *(Long
tail in `waybar.md`: powerline/segmented, dock/shelf, minimal-flat transparent — offer via "Other".)*
**6e. Corner style** — Soft pills ~12px **(default)** · Full stadium/capsule (oversized radius, e.g.
`border-radius: 7rem`/`999px`) · Subtle ~4px · Square `0`.
**6f. Transparency** — Translucent ~0.8 + blur **(default)** · Glassy ~0.5 + blur · Frosted glass (low
~0.2 alpha + hairline border + drop shadow) · Opaque. *(Any translucency wants the `layerrule … blur`
block — see `waybar.md`.)*
**6g. Depth / elevation** — Flat **(default)** · Soft drop shadow (floating) · Border ring (2px accent
outline) · Inset glow.

**Call 3 — Waybar design · color & state:**
**6h. Workspace indicator** — Pill-fill active, tinted accent **(default)** · Underline (`border-bottom`)
· Dots (filled vs hollow glyph) · Plain numbers. *(Variants in `waybar.md`: nerd-icon glyphs,
opacity-only, outline-border, growing pill, gradient/skew.)*
**6i. Accent strategy** — Single accent (active ws + one or two signal modules) **(default)** · Per-module
hue (each module its own color) · Monochrome (accent only on the active workspace) · Semantic-state-only
(color only on warning/critical/charging).
**6j. Accent application** — Accent as glyph/text color on a dark bar **(default)** · Accent as pill
background with dark text (inverted "candy" pills).
**6k. Motion** — Subtle: hover fades + state cues (battery-critical blink, urgent pulse, mpris glow)
**(default)** · Static (no animation) · Springy/animated (cubic-bezier overshoot, breathing pulses).

**Call 4 — content:**
**6l. Modules** (multi-select; sensible set checked) — workspaces **(on)**, window title **(on)**, clock
**(on)**, audio/pulseaudio **(on)**, network **(on)**, CPU, memory, temperature, battery **(on if
laptop)**, system tray **(on)**, media/mpris, bluetooth, idle-inhibitor, notification (swaync if chosen),
updates, weather. Keep on-clicks aligned to installed tools (network → `nm-connection-editor`, audio →
`pavucontrol`).
**6m. Module grouping** — Inline **(default)** · Collapse cpu/mem/temp (and volume/brightness) behind a
`group/drawer` that reveals on hover/click — best on **narrow or vertical** bars; can hold GTK sliders ·
Segmented powerline (chained arrow separators welding modules into one strip).
**6n. Clock format** — `HH:MM` 24-hour + date tooltip **(default)** · 12-hour `hh:MM AM` · date inline.

**If 6b = Vertical:** prefer **icon-only** or two-line `\n` formats (`clock {:%H\n%M}`), `rotate: 90/270`
for text-bearing modules, and **vertical sliders** in drawers; round only the inward edge
(`border-radius: 0 6px 6px 0`). **If 6b = Dual:** put chrome on top (clock, tray, system, notifications)
and **workspaces + `wlr/taskbar` + sensors** on the bottom (a JSON **array of named bars**,
`"name": "top"/"bottom"`). Both are spelled out in `styling/waybar.md` ("Bar form").

**Validate `config.jsonc` as strict JSON before reload** — a malformed bar silently fails to appear
(see the desktop-shell JSON-check). `style.css` must start with `@import "colors.css";` so the engine
themes it.

---

## 7. Launcher  *(dedicated group — full functional depth)*

rice generates the launcher's functional config + themed style. Recipes:
`../../desktop-shell/references/components.md`; look: `styling/launchers.md`. Sets `$menu` for binds.

**7a. Launcher tool** — wofi **(default)** · rofi (most themeable) · fuzzel · tofi. Bias to installed.
**7b. Mode** — App launcher / `drun` **(default)** · Run + drun combined · Also offer window-switcher
bind.
**7c. Layout & size** — Centered overlay, ~600px, single column **(default)** · Compact list (top) ·
Fullscreen grid · Multi-column grid (icons).
**7d. Show icons?** — Yes, app icons **(default)** · Text only (faster, no icon theme needed).

Second call if needed:
**7e. Matching & behavior** (multi-select): fuzzy matching **(on)**, type-to-search, hide scrollbar,
close on focus-loss **(on)**.

Style file `@import`s/`include`s the generated colors file so the engine themes it.

---

## 8. Notifications  *(dedicated group)*

rice generates the daemon's functional config + themed colors. *Only one* daemon can run (they fight
for the `org.freedesktop.Notifications` D-Bus name). Recipes:
`../../desktop-shell/references/components.md`; look: `styling/notifications.md`.

**8a. Daemon** — mako **(default)** · dunst · swaync (adds a notification center / control panel) · none.
**8b. Position** — Top-right **(default)** · Top-center · Top-left · Bottom-right.
**8c. Default timeout** — 5s **(default)** · 3s (snappy) · 10s · Never (manual dismiss).
**8d. Behavior** (multi-select): group by app, show app icons **(on)**, a do-not-disturb toggle bind
**(on)**, max visible ~5.

Color keys come from the engine (leave them to rice / `@import` the colors file); don't hardcode hex.

---

## 9. Lock screen

Whether and how to lock (hyprlock). If on, generate a `hyprlock.conf` (group 15) and bind a lock key;
if hypridle is on (group 14), point its `lock_cmd` at hyprlock. Look: `styling/hyprlock.md`.

**9a. Enable a lock screen?** — Yes, hyprlock **(default)** · No.
**9b. Background** — Blurred screenshot **(default)** · The wallpaper · Solid palette color.
**9c. Clock** — Large time + date **(default)** · Time only · None.
**9d. Input pill style** — Accent-outlined, centered **(default)** · Minimal underline · Hidden until
typing.

hyprlock colors are **literal hex** from the palette (it can't read Hyprland `$vars`) — the engine fills
them.

---

## 10. Window look & feel  *(re-theming asks this too)*

The compositor's own aesthetic. Defaults are the well-tuned shipped 0.54 values; see
`styling/hyprland-decoration.md` for values-that-look-good and `design-principles.md` for the archetypes
(Catppuccin soft-glass · flat/minimal · heavy glass · maximalist floating-islands). Split across **two
calls**.

Call 1:
**10a. Gaps & borders** — Comfortable (in 5 / out 20 / border 2) **(default)** · Tight (2/6/1) ·
None (0/0/1) · Spacious (8/30/3). Rhythm: `gaps_out ≈ 2× gaps_in`, rounding tracks `gaps_out`.
**10b. Corner rounding** — Rounded (10) **(default)** · Subtle (5) · Square (0). On 0.5x add
`rounding_power = 2` (bump to 2.3–4 for a softer "squircle").
**10c. Blur & shadows** — Blur + shadows on **(default)** · Blur on, shadows off · Both off (lighter
GPU). Frosted preset: `blur { size 6, passes 2 }`; pair window opacity with blur or it does nothing.
**10d. Window opacity** — Opaque 1.0 **(default)** · Slightly translucent inactive (active 1.0 /
inactive 0.9). Keep content windows opaque; chrome (terminals) can be translucent per-app.

Call 2:
**10e. Animations** — On, smooth defaults **(default)** · On, snappy/fast (speeds ~0.6×) · Off. Curve
families: shipped `easeOutQuint`, the `wind/winIn` slide-overshoot family, or Material-3
`md3_decel`/`md3_accel`.
**10f. Border color** — From my palette **(default)** → `col.active_border = $accent $accent2 45deg`
(vars come from the engine's `colors.conf`, so the border re-themes for free) · Custom gradient (free
text, e.g. `rgba(33ccffee) rgba(00ff99ee) 45deg`).
**10g. Layout** — Dwindle (BSP-like) **(default)** · Master/stack. (`scrolling` is plugin-only, not core
0.54 — only offer it if a scrolling-layout plugin is installed.)

---

## 11. Palette  *(re-theming asks this too)*

This is what makes the desktop **coherent** instead of a stock-gray box with a random border. Resolve
every answer into the engine's `palette.conf` (see *Mapping* below). Don't pick a scheme silently —
present it; if the user says "good defaults", use **Catppuccin Mocha** and say so.

**11a. Palette source** (always ask)
- **Named scheme (default)** → one from `palettes.md` (Catppuccin Mocha/Frappé/Macchiato/Latte, Gruvbox,
  Nord, Tokyo Night, Rosé Pine, Dracula, Everforest, Kanagawa, Solarized Dark). Ask the scheme as a
  second question; each ships a ready preset profile + matching wallpapers (group 13).
- **Match my wallpaper** → needs `matugen` or `wallust`; confirm the wallpaper path. If neither is
  installed, say so and fall back to a named scheme or manual (don't install). With matugen, the scheme
  type is selectable (`-t scheme-tonal-spot`/`-expressive`/`-vibrant`/…); Material-You → ANSI is
  approximate, wallust/pywal give a true 16-color scheme.
- **Manual hex** → ask at least `bg`, `fg`, `accent`; derive the rest or collect all 16.
**11b. Light vs dark** (only when ambiguous) — most schemes are dark; if the user picked one with a light
variant (Catppuccin Latte), confirm. For light, set GTK `color-scheme = prefer-light`.

**Accent pick** (separate `AskUserQuestion` after the scheme): each scheme has a sensible default
`accent`/`accent2`. The curated in-palette options live in `accents.tsv`: list them with
`rice accents <scheme>` (6–8 variants — e.g. Catppuccin mauve/blue/teal/green/peach/pink/red; Gruvbox
yellow/orange/green/aqua/blue/purple/red) and present them. Apply with `rice accent <name|hex>` (sets
`accent=` + re-renders), or `--pin` it into `palette.user.conf` so it survives later theme/wallpaper
changes; a custom hex works too. The accent drives borders, focus rings, and bar highlights — the
highest-leverage single choice.

---

## 12. Fonts  *(re-theming asks this too)*

**12a. UI / sans font** (always present) — the GTK/app text font. Present installed families first
(`FONT_SANS=`/`CURRENT_*FONT*`): Inter, Lexend, Rubik, Cantarell, Noto Sans, Adwaita Sans. Default to an
installed UI font; offer the catalog (naming the package) for one not present. Record as
`font_ui = <Family> <size>` (e.g. `Inter 11`).
**12b. Monospace / Nerd font** (always present) — terminal/bar/fetch/prompt font. **Default to an
installed Nerd Font** (`JetBrainsMono Nerd Font` is the universal pick) so glyphs render instead of tofu
(▯). Offer installed Nerd Fonts first; if `MISSING_NERD_FONT`, offer the catalog + name the package and
warn glyph-heavy bars/prompts show boxes until one is installed. Common pairings: *Inter/Noto Sans +
JetBrainsMono NF* (safe), *Space Grotesk + JetBrains Mono NF* (modern), *Rubik/Readex Pro + Maple Mono
NF* (cozy). Record as `font_mono = <Family> <size>`.

---

## 13. Wallpaper  *(re-theming asks this too)*

**13a. Matching wallpaper** (offer after the scheme is chosen — skip if the source was already "match my
wallpaper"). The engine ships a curated, theme-tagged catalog of curl-downloadable wallpapers
(`rice wallpapers <scheme>` lists the ones matching the chosen scheme, plus a few theme-agnostic `any`
ones). Present the names, then download + set the pick: `rice get-wallpaper <scheme> <number|name>
--set` (downloads to `~/Pictures/wallpapers/` and sets it **without** re-theming, so the named-scheme
palette is kept). For a manual palette, offer the `any` set. A desktop with no wallpaper looks
unfinished, so it's worth asking even when optional.

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

## 14. Autostart & env  *(generate only)*

Prefer first-party Hypr ecosystem tools as defaults (see `ecosystem.md`). Only suggest installed tools
as on-by-default; for missing ones, offer but note they need installing. Never install. (The bar,
notification daemon, and lock screen were chosen in their own groups above — here wire their
`exec-once`/units plus the rest.) Split across **two calls**.

Call 1 — services:
**14a. Wallpaper tool** — hyprpaper **(default, first-party)** · swww/awww (animated) · none. For swww
emit the `SWWW_DAEMON_BIN` from `detect-version.sh` (`swww-daemon` *or* the `awww` fork's `awww-daemon`),
never a hard-coded binary.
**14b. Polkit agent** — hyprpolkitagent **(default)** → `systemctl --user start hyprpolkitagent`
(systemd unit survives reloads) · polkit-gnome · polkit-kde · none.
**14c. Also autostart** (multi-select; defaults checked): clipboard history — `wl-paste --type text
--watch cliphist store` **and** a second `--type image` line **(on)**; network tray `nm-applet
--indicator` **(on if NetworkManager)**; bluetooth `blueman-applet` (off); idle `hypridle` **(on)**;
blue-light `hyprsunset -t 4000` (off); OSD `swayosd-server` (off). The portal env-propagation pair
(`dbus-update-activation-environment --systemd …` + `systemctl --user import-environment …`) is the
standard "screen-share is black" fix — include it.
**14d. Screen sharing / portals** (inform) — needs `xdg-desktop-portal-hyprland` +
`xdg-desktop-portal-gtk` and `XDG_CURRENT_DESKTOP=Hyprland`; add the env var and note missing packages.

Call 2 — environment variables (multi-select, sensible defaults checked):
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

## 15. Companion configs  *(generate only — when the matching tool is chosen)*

Generate a starter config for each tool picked above. These live in `~/.config/hypr/` next to
`hyprland.conf` but are read by their own daemons (NOT `source=`d). Formats: `ecosystem.md` +
`config-templates.md`. Ask before generating each if the user may already have one — never overwrite
without it being captured by the timestamped backup. This group is usually a single confirmation call.

- **hyprlock** → `hyprlock.conf` (required by hyprlock or it errors): background + accent-outlined input
  pill + clock per the group-9 answers. Colors are **literal hex** from the palette.
- **hypridle** → `hypridle.conf`: dim → lock → dpms-off → suspend listeners; `lock_cmd = pidof hyprlock
  || hyprlock`; lock *before* dpms-off; `before_sleep_cmd = loginctl lock-session`.
- **hyprpaper** → `hyprpaper.conf`: `preload` + `wallpaper` (the group-13 image or a placeholder); set
  `ipc = on` so the wallpaper can be switched live.

---

## 16. Shell & prompt  *(dedicated group — generate only)*

The interactive shell is the last themed surface. rice sets up the prompt + shell colors by leaning on
the **shell-config** recipes (`../../shell-config/references/shells.md`) and the rice engine's
shell templates (`engine.md` → "Shell & prompt theming"); the *colors* are palette-driven so the prompt
re-themes with everything else. Bias defaults to what's installed (`detect-theme-tools.sh`:
`HAVE_fish`/`HAVE_starship`/`HAVE_ohmyposh`/`HAVE_fastfetch`).

**16a. Which shell do you want?** — **always ask this; don't silently default to the current shell.**
Keep current login shell **(default)** · bash · zsh · **fish** (the popular ricing pick — built-in
autosuggestions + tab-completions, i.e. "autocomplete" with no plugins). Bias the default to the
installed/current shell (`CURRENT_SHELL`/`HAVE_fish` from `detect-theme-tools.sh`); name the package
if a chosen shell isn't installed. If they want the pick as the **login** shell, that's a manual
`chsh -s "$(command -v <shell>)"` (the shell must be in `/etc/shells`) taking effect next login — or
offer the lower-risk **per-terminal** route (set the emulator's shell, e.g. kitty `shell
/usr/bin/fish`, foot `shell=…`), which keeps the login shell unchanged. Note whichever they pick;
never run `chsh` for them. Edits go in a guarded managed block, parse-tested after each change.
**16b. Prompt engine** — starship **(default, cross-shell)** · oh-my-posh (cross-shell, JSON themes) ·
native shell prompt · leave as-is. Wire it to the engine (`STARSHIP_CONFIG` → rice-owned `starship.toml`,
or `oh-my-posh init --config` → rice-owned `rice.omp.json`) so `rice apply` recolors it. Name the package
for a missing engine.
**16c. fish syntax colors** (fish only) — Theme `fish_color_*` from the palette **(default yes)** · leave
fish defaults. Renders to `~/.config/fish/conf.d/zz-hypr-rice-colors.fish` (auto-sourced).
**16d. Startup fetch** — fastfetch **(default)** · neofetch (archived) · none. Add a guarded line in the
managed block; needs a Nerd Font for the logo/glyphs (group 12).
**16e. fish plugins** (fish only, optional) — autosuggestions/completions are built in; offer a small
**fisher** set: autopair · fzf.fish (needs `fzf`) · sponge · done. Default **off** unless asked; record
the chosen set in `~/.config/fish/fish_plugins` so `fisher update` reproduces it (track via the dotfiles
skill). See `shells.md` → "Fish plugins".

Optional second call: aliases & modern-CLI integration (`eza`/`bat`/`zoxide`/`fzf`/`atuin`, all
`command -v`-guarded — in fish, prefer `abbr` for git/nav shortcuts) and editor/history — only for
installed tools; defer the rest to the shell-config skill. The prompt/fish-color manifest lines to
register live in `engine.md`. **Reminder:** new aliases/prompt only appear in shells started after the
change — tell the user to open a new terminal or `exec <shell>`.

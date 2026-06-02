# Interview Question Bank

Use `AskUserQuestion` to collect preferences. Batch by topic area (one call per area, several
questions per call). Always present a sensible default as the first option. Skip anything already
answered by `$ARGUMENTS` or discovered in an existing config. Map every answer to the
corresponding template in `templates.md`.

The recommended default for each question is marked **(default)** — when the user says "just
pick good defaults", use these and skip ahead.

---

## Area A — Monitors & input

**A1. Monitor setup**
- Single monitor, auto-detect resolution **(default)** → `monitor = ,preferred,auto,1`
- Single monitor, specific resolution/refresh → ask res + refresh, e.g. `2560x1440@144`
- Dual monitor side-by-side → ask both names/res; position the second at `<width>x0`
- More than two / complex → collect each monitor's name, mode, position, scale

Always tell the user real names come from `hyprctl monitors`; use detected names when available,
otherwise placeholders (`DP-1`, `HDMI-A-1`, `eDP-1`) and a note to adjust.

**A2. Fractional scaling?** (HiDPI / laptop panels)
- No, scale 1 **(default)**
- Yes, 1.5
- Yes, 2
- Custom

**A3. Keyboard layout** → free text, default `us`. Also offer common `kb_options` like
`caps:escape` (off by default).

**A4. Touchpad** (only if a laptop / touchpad likely)
- Natural scroll + tap-to-click on **(default)**
- Traditional scroll, tap on
- No touchpad / desktop

---

## Area B — Keybinds & apps

**B1. Mod key**
- SUPER (Windows key) **(default)**
- ALT

**B2. Terminal** → default `kitty`; common: `alacritty`, `foot`, `wezterm`, `ghostty`.

**B3. App launcher** → default `wofi --show drun`; common: `rofi -show drun`,
`fuzzel`, `tofi-drun`, `anyrun`.

**B4. Browser** → default `firefox`; common: `chromium`, `brave`, `qutebrowser`.

**B5. Keybind flavor**
- Official default (SUPER+Q terminal, C close, R menu, E files, V float, M exit) **(default,
  matches the shipped config + tutorials, so muscle memory transfers)**
- i3/sway-style (SUPER+Return terminal, Q close, D menu, F fullscreen)
- Add vim HJKL focus (on top of either scheme; togglesplit then moves off J → T)
- Minimal (just essentials)

Use `$mainMod` as the modifier variable (the official default's name). Default `SUPER`. Bind
split-toggle with `layoutmsg, togglesplit` (not a bare `togglesplit`).

Always include: launch terminal, close window, exit, launcher, toggle float, fullscreen,
workspace 1–10 switch + move-to, focus move, window move, mouse move/resize (`bindm`), volume &
brightness (`bindel`), and a special/scratchpad workspace.

Also wire **ecosystem binds** for whatever companion tools are chosen in Area D/E
(see `hyprland-reference/references/ecosystem.md` for commands):
- Screenshot: `hyprshot -m region`/`-m window`/`-m output`, or `grimblast copy area`, or
  `grim -g "$(slurp)" - | wl-copy` as the no-extra-deps fallback.
- Lock now: `hyprlock` (if hyprlock chosen).
- Color picker: `hyprpicker -a` (if hyprpicker chosen).
- Logout menu: `wlogout` (if chosen).
- Clipboard history: `cliphist list | $menu | cliphist decode | wl-copy` (if cliphist chosen).
- Emoji/other: only if the user asks.

---

## Area C — Look & feel

**C1. Gaps & borders**
- Comfortable (gaps_in 5, gaps_out 20, border 2) **(default)**
- Tight (gaps_in 2, gaps_out 6, border 1)
- None (gaps 0, border 1)
- Spacious (gaps_in 8, gaps_out 30, border 3)

**C2. Corner rounding**
- Rounded (10) **(default)**
- Subtle (5)
- Square (0)

**C3. Blur & shadows**
- Blur + shadows on **(default)**
- Blur on, shadows off
- Both off (lighter on GPU)

**C4. Window opacity**
- Opaque (1.0) **(default)**
- Slightly translucent inactive (active 1.0 / inactive 0.9)

**C5. Animations**
- On, smooth defaults **(default)**
- On, snappy/fast
- Off

**C6. Border color**
- From my theme palette **(default)** → `col.active_border = $accent $accent2 45deg` (the
  `$accent`/`$accent2` vars come from `colors.conf`, rendered by the rice engine from the palette
  chosen in Area C-theme). This keeps the border in sync with the rest of the desktop and with any
  later re-theme — no hardcoded color to drift.
- Custom gradient → free text, e.g. `rgba(33ccffee) rgba(00ff99ee) 45deg`. Use only if the user
  wants a border color independent of the palette.

**C7. Layout**
- Dwindle (BSP-like) **(default)**
- Master/stack

---

## Area C-theme — Palette & fonts (the colors of the whole desktop)

This is the part that makes the generated config look *coherent* rather than a stock gray box with
a random border. Ask the **shared theme interview** in
**`skills/theme-config/references/interview.md`** (palette source → scheme/wallpaper/manual,
accent, UI font, monospace/Nerd font). It is the same bank `theme-config` uses, so a config
generated here and a later `/hyprland-config:theme-config` run stay perfectly consistent.

Run `theme-config/scripts/detect-theme-tools.sh` first so the font/generator options reflect
what's installed. Resolve the answers into the rice engine's `palette.conf` (see step 4b of the
SKILL and `theme-config/references/engine.md`) — that's what renders `colors.conf` (the `$accent`
etc. used by C6) and themes any companion apps. Don't silently pick a scheme or fonts; present
them. If the user says "just pick good defaults", use Catppuccin Mocha + an installed Nerd Font for
mono and Inter (or any installed UI font) for sans, and tell them what you picked.

---

## Area D — Autostart & env

Prefer the first-party Hypr ecosystem tools as defaults (see
`hyprland-reference/references/ecosystem.md`). When a real system is available, only suggest
tools that are installed (`pacman -Qq <pkg>` / `command -v`); for missing ones, still offer them
but note they need installing. Never install anything.

**D1. Status bar**
- waybar **(default)**
- hyprpanel
- none / I'll add later
- other (free text)

**D2. Notification daemon**
- mako **(default)**
- dunst
- swaync (has a notification center)
- none

**D3. Wallpaper tool**
- hyprpaper **(default, first-party)** → also generate a starter `hyprpaper.conf`
- swww (animated) → `exec-once = swww-daemon` (or `awww-daemon` if the `awww` fork is installed —
  use the `SWWW_DAEMON_BIN` reported by `detect-version.sh`, never hard-code `swww-daemon`)
- none

**D4. Polkit authentication agent**
- hyprpolkitagent **(default, first-party)** → `exec-once = systemctl --user start hyprpolkitagent`
- polkit-gnome (`/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1`)
- polkit-kde-agent (`/usr/lib/polkit-kde-authentication-agent-1`)
- none

**D5. Also autostart** (multi-select; defaults checked):
- Clipboard history — `wl-paste --watch cliphist store` **(default on)**
- Network tray — `nm-applet --indicator` **(default on if NetworkManager)**
- Bluetooth tray — `blueman-applet` (default off)
- Idle daemon — `hypridle` **(default on)** → also generate a starter `hypridle.conf`
- Blue-light filter — `hyprsunset -t 4000` (default off)
- OSD daemon — `swayosd-server` (default off)

**D6. Lock screen (hyprlock)**
- Yes, set up hyprlock **(default)** → generate a starter `hyprlock.conf` and bind a lock key;
  if hypridle is also on, point its `lock_cmd` at hyprlock.
- No lock screen

**D7. Screen sharing / portals** — inform (not really a choice): a working setup needs
`xdg-desktop-portal-hyprland` + `xdg-desktop-portal-gtk` and `XDG_CURRENT_DESKTOP=Hyprland` in
the env. Add the env var and note the portal packages in the summary if they're missing.

**D8. Environment variables** (multi-select, sensible defaults checked):
- Cursor: `XCURSOR_SIZE,24` + `HYPRCURSOR_SIZE,24` **(default on)**
- Toolkit: `QT_QPA_PLATFORM,wayland;xcb`, `GDK_BACKEND,wayland,x11` **(default on)**
- Qt theming: `QT_QPA_PLATFORMTHEME,qt6ct` (default on if qt6ct present)
- Session/portals: `XDG_CURRENT_DESKTOP,Hyprland` (default on)
- NVIDIA set (`LIBVA_DRIVER_NAME,nvidia`, `__GLX_VENDOR_LIBRARY_NAME,nvidia`,
  `NVD_BACKEND,direct`, `ELECTRON_OZONE_PLATFORM_HINT,auto`) **(default off — ask if NVIDIA GPU)**
- Firefox Wayland: `MOZ_ENABLE_WAYLAND,1` **(default on if browser is firefox)**

Ask whether the GPU is NVIDIA when unsure — it changes both env vars and cursor settings.

## Area E — Companion configs (generated alongside)

When the matching tool is chosen above, also generate a starter config for it (these live in
`~/.config/hypr/` next to `hyprland.conf` but are read by their own daemons, not `source=`d).
Use the formats in `hyprland-reference/references/ecosystem.md`:

- **hyprlock** → `hyprlock.conf` (required by hyprlock or it errors; use a blurred-screenshot
  background + password input-field + clock label).
- **hypridle** → `hypridle.conf` (dim → lock → dpms off → suspend listeners; `lock_cmd`
  pointing at hyprlock).
- **hyprpaper** → `hyprpaper.conf` (preload + wallpaper; ask for an image path or leave a
  placeholder).

Ask the user before generating each companion config if they may already have one — never
overwrite an existing companion config without it being captured by the timestamped backup.

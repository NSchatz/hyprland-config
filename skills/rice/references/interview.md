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

## Recording answers (the discipline that prevents post-interview drift)

The interview is long enough — **28–38 `AskUserQuestion` calls** — that natural-language answers
scattered through chat history get garbled by the time downstream steps (file generation, package
list, component writers) try to use them. The fix: **persist every answer to `<staging>/answers.json`
as it comes in**, then every downstream step reads it with `jq`. The model never has to recall a pick.

**After every `AskUserQuestion`**, immediately call:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh" <answers-file> <key.path> <value>
# or for arrays / objects / numbers / bools:
bash "${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh" <answers-file> <key.path> --json '<jsonval>'
```

`record-answer.sh` `setpath`s the value into the JSON file (creating it if absent), idempotently —
re-asking a question and re-recording just overwrites the key, no duplicate state. The file lives at
`<staging>/answers.json` (e.g. `/tmp/hypr-gen-abc123/answers.json`); it's the single source of truth
the rest of Mode A reads from. **Never invent a key after-the-fact** — if a downstream step needs
something the interview didn't capture, go back and ask, then re-record.

### The schema

One top-level key per interview group. Use the exact key names below so every step reads the same
shape. Anything optional / not-asked is simply absent (don't write nulls). Multi-select answers are
arrays of the canonical option labels.

```json
{
  "version": 1,
  "staging_dir": "/tmp/hypr-gen-<id>",
  "hypr_version": "0.54.3",

  "monitors": {
    "setup": "single-auto | single-specific | dual-side-by-side | complex",
    "list": [{ "name": "DP-1", "mode": "2560x1440@144", "pos": "0x0", "scale": 1.0, "transform": 0, "vrr": 0, "bitdepth": 8 }],
    "scaling": 1.0,
    "dock_undock": false,
    "workspace_rules": { "1-5": "DP-1", "6-10": "HDMI-A-1", "scratchpad": false, "smart_gaps": false },
    "pin_apps": { "firefox": 1, "thunderbird": 9 }
  },
  "input": {
    "kb_layout": "us",
    "kb_options": ["caps:swapescape"],
    "key_repeat": { "rate": 25, "delay": 600 },
    "follow_mouse": 1,
    "mouse_sensitivity": 0.0,
    "touchpad_gestures": ["workspace-swipe"]
  },
  "keybinds": { "mod": "SUPER", "extras": ["theme-switch","blur-toggle","cheatsheet"], "resize_submap": false },
  "default_apps": { "browser": "firefox", "files": "thunar" },
  "terminal": { "emulator": "kitty", "opacity": 1.0, "padding": 8, "font_size": 11, "extras": ["scrollback-10k"], "swallow": false },
  "bar": {
    "strategy": "waybar | waybar+widgets | full-shell | hyprpanel | none",
    "form": "top | bottom | vertical-left | vertical-right | dual",
    "height": 34,
    "archetype": "floating-islands | separated-pills | single-lozenge | edge-to-edge | powerline | dock",
    "corner": "rounded | square | pill",
    "transparency": "opaque | translucent | glassy | frosted",
    "workspace_indicator": "pill-fill | underline | dots | numbers",
    "accent_strategy": "single | per-module | monochrome | semantic-state",
    "accent_application": "text | inverted-pill",
    "motion": "smooth | snappy | none",
    "modules": ["workspaces","window","clock","cpu","memory","pulseaudio","network","tray"]
  },
  "widgets": {
    "system": "none | eww | ags | quickshell | hyprpanel | turnkey",
    "turnkey": "end-4 | caelestia | noctalia | dankmaterial",
    "enabled": ["osd","notification-center","music","dashboard"],
    "look": "match-palette | material-you | glass | flat",
    "motion": "smooth | snappy | static"
  },
  "launcher": { "tool": "wofi | rofi | fuzzel | tofi | walker | vicinae | anyrun", "mode": "drun | run-drun", "layout": "centered | compact-top | fullscreen-grid | multi-column", "icons": true, "behavior": ["fuzzy","close-on-focus-loss"] },
  "notifications": { "daemon": "mako | dunst | swaync | none", "position": "top-right | top-center | top-left | bottom-right", "timeout": 5, "behavior": ["group-by-app","app-icons","dnd-bind"] },
  "lock_screen": { "enabled": true, "background": "blurred-screenshot | wallpaper | solid", "clock": "large | time-only | none", "input_pill": "accent-outlined | underline | hidden", "fingerprint": false },
  "look_feel": {
    "gaps_preset": "comfortable | tight | none | spacious",
    "rounding": "rounded | subtle | square",
    "blur_shadows": "both-on | blur-on-shadows-off | both-off",
    "opacity": { "active": 1.0, "inactive": 0.9 },
    "animations": "smooth | snappy | off",
    "border_color": "palette | custom-gradient",
    "layout": "dwindle | master",
    "master_orientation": "left",
    "groups": false,
    "per_app_rules": [{"class":"firefox-developer-edition","effects":["pin"]}],
    "blur_toggle": false
  },
  "palette": { "source": "named | wallpaper | manual", "scheme": "catppuccin-mocha", "light_dark": "dark", "accent": "mauve", "wallpaper_path": null, "manual": { "bg":"1e1e2e", "fg":"cdd6f4", "accent":"cba6f7" } },
  "fonts": { "ui": "Inter 11", "mono": "JetBrainsMono Nerd Font 11" },
  "wallpaper": { "path": "/home/u/Pictures/wallpapers/mocha.png", "catalog_pick": null },
  "autostart_env": {
    "wallpaper_tool": "hyprpaper | swww | none",
    "polkit": "hyprpolkitagent | polkit-gnome | polkit-kde | none",
    "autostart": ["cliphist-text","cliphist-image","nm-applet","hypridle"],
    "env": ["XCURSOR_SIZE,24","HYPRCURSOR_SIZE,24","QT_QPA_PLATFORM,wayland;xcb","GDK_BACKEND,wayland,x11,*","XDG_CURRENT_DESKTOP,Hyprland"]
  },
  "companion_configs": { "hyprlock": true, "hypridle_ladder": "balanced | aggressive | relaxed | never", "hyprpaper": true },
  "shell_prompt": { "shell": "fish | zsh | bash | keep-current", "prompt": "starship | oh-my-posh | native | keep-current", "fish_colors": true, "fetch": "fastfetch | neofetch | none", "fisher": ["autopair","fzf.fish","sponge","done"], "aliases": true, "modern_cli": ["eza","bat","zoxide","fzf"] },
  "utilities": { "selected": ["screenshot","clipboard","color-picker","power-menu","screen-record","ocr","emoji","calculator","wifi-applet","bluetooth-applet","night-light"] },
  "login_boot": { "greeter": "greetd-tuigreet | greetd-regreet | sddm | none", "plymouth": false, "grub_theme": false },
  "gaming": { "enabled": false, "tearing_classes": ["steam_app_"], "vrr_mode": 0, "strip_fullscreen_effects": true, "gamemode_toggle": true },
  "laptop": { "enabled": false, "lid_action": "suspend | lock | clamshell | nothing", "power_tool": "ppd | tlp | auto-cpufreq | none", "charge_limit": 80 },
  "accessibility": ["magnifier","large-cursor","night-light","larger-ui"],
  "plugins": { "enabled": false, "selected": ["hyprexpo","hy3"] }
}
```

Notes on writing this file:
- Keys are conservative — short, lowercase, snake_case. Don't introduce new top-level keys without
  updating this schema.
- Optional groups (gaming, accessibility, plugins, laptop, login_boot) keep their top-level key with
  `"enabled": false` when the user declines the gate — that way downstream code can branch on a
  single boolean instead of checking key presence.
- `palette.manual.*` is only populated on the manual path. The actual hex values that end up in
  `palette.conf` are derived from `palette.source`/`scheme`/`accent` plus `references/palettes.md`
  during A4 — don't try to record all 16 colors here.
- The Hyprland version + staging dir live at the top so any tool reading the file knows the build
  target without re-running detection.

### How downstream steps use it

| Step | What it reads from `answers.json` |
|---|---|
| A3 (Hyprland topic files) | `monitors`, `input`, `keybinds`, `terminal`, `look_feel`, `autostart_env`, `companion_configs`, `gaming`, `laptop`, `accessibility`, `plugins` |
| A3b (shell components) | `bar`, `widgets`, `launcher`, `notifications`, `terminal`, `lock_screen` |
| A3c (shell & prompt) | `shell_prompt` |
| A3d (install.sh) | every group — walks the JSON deterministically against `packages.md` |
| A4 (palette) | `palette`, `fonts`, `wallpaper` |
| Component-writer agents | `ANSWERS=` is a `jq` slice of the relevant group(s), passed in directly |

Read with `jq -r '.palette.scheme' <answers-file>` or pull a whole subtree with
`jq '.bar' <answers-file>`. **Never make up a value** that isn't in the file — if a downstream
template needs something you didn't ask for, add the question to the interview and re-record.

## How to ask — group structure & the 4-question cap

Ask with `AskUserQuestion`, **one group per component, in order**. The tool accepts **at most 4
questions per call**, so a group with more than four sub-questions **must be split across consecutive
calls** — never drop, merge, or silently skip a sub-question just to fit the cap. Walk every group
and **ask every sub-question**.

### Strict — ask every question. Never silently default.

The `(default)` marker on an option means "put this option first in the list" — it does **not**
authorize skipping the question. The user has explicitly said they don't want the interview
collapsed to a few presses; a short interview is a failed interview. The hard rules:

- Every sub-question gets an `AskUserQuestion` call. No exceptions for "obvious" picks.
- `$ARGUMENTS` and an existing config **reorder the option list** (so the matching pick is first
  and the user can confirm with one press); they do not answer the question. Vague hints like "no
  animations" or "make it nice" don't even reorder — they're not option selectors.
- Opt-in gate questions (groups 7 widgets, 19 login & boot, 20 gaming, 21 laptop, 22
  accessibility, 23 plugins) are **always asked**. Detection (e.g. `IS_LAPTOP=1`) decides which
  option is listed first in the gate, not the gate's answer.
- A from-scratch run produces roughly **28–38 `AskUserQuestion` calls**. Single-digit call counts
  mean the interview was collapsed — go back and ask the rest.

Run `detect-version.sh` + `detect-theme-tools.sh` first for **factual** context (Hyprland version,
GPU driver, monitor count, chassis, uwsm session, current gsettings), but **do not** filter or
reorder the menu by what's already installed — every user is offered the same options. Whatever the
user picks lands in the A3d install batch and A5 installs it. Use `multiSelect` for the genuinely
multi-choice questions (bar modules, autostart, env vars).

**The groups** (a from-scratch run walks all of them; expect **~28–38 `AskUserQuestion` calls** total on
a full build — fewer when opt-in groups are declined: 7 (widgets), 19 (login), 20 (gaming), 21
(laptop), 22 (accessibility), 23 (plugins) all start with a gate question and skip the rest on "no".
If you've asked only a handful, you've collapsed groups incorrectly, go ask the rest):

| # | Group | Mode A | Mode B | Splits into |
|---|---|---|---|---|
| 1 | Monitors | ✓ | | 1–2 calls |
| 2 | Input (keyboard, mouse, touchpad, gestures) | ✓ | | 1–2 calls |
| 3 | Keybinds | ✓ | | 1–2 calls |
| 4 | Default apps (browser, files) | ✓ | | 1 call |
| 5 | **Terminal** | ✓ | | 1–2 calls |
| 6 | **Status bar + waybar design** | ✓ | | 4 calls |
| 7 | **Desktop widgets** (eww / AGS / Quickshell / HyprPanel) | ✓ | | 0–2 calls |
| 8 | **Launcher** | ✓ | | 1–2 calls |
| 9 | **Notifications** | ✓ | | 1 call |
| 10 | **Lock screen** | ✓ | | 1 call |
| 11 | Window look & feel | ✓ | ✓ | 3 calls |
| 12 | Palette | ✓ | ✓ | 1–2 calls + accent pick |
| 13 | Fonts | ✓ | ✓ | 1 call |
| 14 | Wallpaper | ✓ | ✓ | 1 call (catalog pick) |
| 15 | Autostart & env | ✓ | | 2 calls |
| 16 | Companion configs | ✓ | | 1 call |
| 17 | **Shell & prompt** | ✓ | | 1–2 calls |
| 18 | **Utilities & menus** | ✓ | | 1 call |
| 19 | **Login & boot** | ✓ | | 1 call |
| 20 | **Gaming & performance** | ✓ | | 1–2 calls |
| 21 | **Laptop** *(opt-in; `IS_LAPTOP` is the default answer)* | ✓ | | 1 call |
| 22 | **Accessibility** *(opt-in)* | ✓ | | 0–1 call |
| 23 | **Hyprland plugins** *(hyprpm, opt-in)* | ✓ | | 0–2 calls |

Map every answer to its template: the **Hyprland-config** groups (monitors, input, keybinds, default
apps, terminal, window look & feel, autostart, companion configs) → `config-templates.md`; the functional
**bar/launcher/notification** configs → `components.md`; the **desktop-widget
shell** → its `styling/` page + the engine's widget template (`engine.md` → "Widget-shell theming"); the
**shell/prompt** configs → `shells.md`; the **utilities & menus** → their
shipped scripts + binds (`utilities.md`); the **login & boot** chrome → `login.md`; the
**gaming & performance** tweaks → `gaming.md`; the **Hyprland plugins** (hyprpm) → `plugins.md`
(`plugin {}` blocks into `plugins.conf` + the install commands); the **palette/fonts/wallpaper** groups
(and the prompt/fish *colors*) → the rice engine's `palette.conf` (`engine.md`) which renders the colors.
For *why a value looks good*, the styling library (`hyprland-reference/.../styling/`) backs each look
choice; cite it when explaining.

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

**Gotcha:** when a fractional `scale` is pinned, also emit a matching `env = GDK_SCALE,N` (group 15)
and `xwayland { force_zero_scaling = true }` or XWayland/GTK apps render blurry/wrong-sized.

**Multi-monitor extras** — ask these only when detection reports **`MONITOR_COUNT > 1`** (or the user
described more than one); a second call. Fields/blocks: `config-templates.md` → monitors.

**1c. Per-monitor extras** (multi-select, off by default) — VRR/adaptive sync per display (`vrr, 2`
fullscreen / `3` content-aware; needs FreeSync/G-Sync), rotation (`transform, 1/2/3` for a vertical/
flipped panel), mirroring (`mirror, <other>` for presentations), 10-bit (`bitdepth, 10`).
**1d. Dock/undock?** — No **(default)** · Yes — emit **`desc:`-based** monitor rules (survive port
renumbering) + a catch-all `monitor = , preferred, auto, 1`. For auto-switch on hotplug, name
`kanshi`/`shikane` (don't author the daemon config inline).
**1e. Workspace rules?** — None **(default)** · Bind workspaces to monitors (e.g. 1–5 → primary, 6–10 →
second) + make them **persistent**; optionally a **named scratchpad** (`special:magic`) and **smart
gaps** (no gaps/border when one tiled window). Block goes in `monitors.conf`.
**1f. Pin apps to workspaces?** — No **(default)** · Yes — collect class + target workspace for each app
that should always open on a fixed workspace (e.g. browser → 1, chat → 9). Emits per-app `workspace`
**window rules** (`windowrules.conf`); add ` silent` so they don't yank focus on launch. The
complementary "launch an app when a workspace is first opened" is `on-created-empty` in the workspace
rule (`monitors.conf`). Pairs naturally with persistent workspaces (1e).

---

## 2. Input (keyboard, mouse, touchpad, gestures)

Up to **6 sub-questions** — split across **two calls** (e.g. 4 + 2) to respect the 4-per-call cap;
the gesture call self-skips on desktops with no touchpad.

**2a. Keyboard layout** → free text, default `us`.
**2b. Caps/Esc & layout options** (offer common `kb_options`, off by default): `caps:swapescape` or
`caps:escape` (Caps→Esc, the popular pick), `compose:caps`; for a multi-layout (`kb_layout = us, es`) add
`grp:win_space_toggle` (or `grp:alt_shift_toggle`) to cycle layouts.
**2c. Key repeat** — Default (rate 25 / delay 600) **(default)** · Fast (rate 40 / delay 300) · Snappy
(rate 50 / delay 250) · Custom. Maps to `repeat_rate`/`repeat_delay`; only emit non-defaults.
**2d. Focus model** — Click / normal (`follow_mouse = 1`) **(default)** · Strict click-to-focus
(`0` — pointer never changes focus) · Sloppy / focus-follows-mouse (`2` detached, or `3` strict-follow).
A common power-user preference; don't assume `1` silently.
**2e. Input baseline** (multi-select, off by default): `accel_profile = flat` (no mouse acceleration —
gamers), `numlock_by_default = true`, raise/lower mouse `sensitivity` (-1.0 … 1.0, default 0).
**2f. Touchpad** (only if a laptop/touchpad is likely): Natural scroll + tap-to-click on **(default)** ·
Traditional scroll, tap on · No touchpad / desktop. The full block also offers `disable_while_typing`,
`clickfinger_behavior`, `scroll_factor`.
**2g. Touchpad gestures** (only when a touchpad is present — 0.45+ `gesture =` keyword API; multi-select,
3-finger workspace swipe pre-checked) — **3-finger horizontal → switch workspace** **(on)** · 4-finger
horizontal → move window · 3-finger up → fullscreen · 3-finger pinch → toggle float/tile (HyDE) ·
4-finger up → special/scratchpad. Each emits one `gesture =` line (`config-templates.md` → input). On a
pre-0.45 target fall back to the `gestures { workspace_swipe = true }` block (see `deprecations.md`).

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
**3d. Resize submap?** — Yes, `SUPER+R` enters a resize mode (arrows resize, Esc exits) **(default)** ·
No. Near-universal nicety; emits the `submap = resize` block (`config-templates.md` → binds). Always
include the Esc exit + a `submap = reset`.
**3e. Keybind cheat-sheet?** — Yes, bind `SUPER+/` to a searchable list **(default)** · No. Installs
`assets/scripts/keybind-cheatsheet.sh` (reads live binds via `hyprctl binds -j` — robust; richer when
the binds use `bindd` descriptions, which this scheme already prefers). Needs `jq` + a menu
(rofi/wofi/fuzzel) — name them if missing.
**3f. Theme-switcher keybind?** — Yes, `SUPER+SHIFT+T` opens a theme menu **(default)** · Menu + a
`SUPER+CTRL+T` dark/light toggle · No. Every major distro ships a live theme switcher (Omarchy
`SUPER+CTRL+SHIFT+Space`, HyDE, JaKooLit, ML4W); this leverages the rice engine you're already setting
up. Installs `assets/scripts/theme-switch.sh` (lists saved profiles via `rice themes` → `rice theme`);
the toggle binds `rice theme-toggle <light> <dark>` between two named profiles (default the chosen
scheme's dark variant + a light one, e.g. `catppuccin-mocha`/`catppuccin-latte`). Needs a menu for the
picker (rofi/wofi/fuzzel); the toggle needs none. Binds go in `binds.conf` (`config-templates.md`).

Bind split-toggle with `layoutmsg, togglesplit` (not a bare dispatcher). Always include: terminal,
close, exit, launcher, float, fullscreen, workspaces 1–10 switch + move-to, focus move, window move,
mouse move/resize (`bindm`), volume & brightness (`bindel` — repeat + works while locked), and a
special/scratchpad workspace. Idioms worth using: `bindl` for media/`Print` so they work on the lock
screen, `bindd` (described) so a cheat-sheet can read the binds, `code:10`–`code:19` for the number row
(layout-independent). Wire **ecosystem binds** for the tools chosen below + in group 15 (see
`ecosystem.md`): screenshot (`hyprshot -m region` / `grimblast copy area` / `grim -g "$(slurp)" - |
wl-copy`), lock (`hyprlock`), color picker (`hyprpicker -a`), logout (`wlogout`), clipboard
(`cliphist list | $menu | cliphist decode | wl-copy`).

---

## 4. Default apps

The launched apps wired to `$terminal`/`$menu`/`$browser`/`$fileManager` variables. (Terminal and
launcher get their own detailed groups next — here just confirm the non-themed picks.)

**4a. Browser** → default `firefox`; common: `chromium`, `brave`, `qutebrowser`. (Firefox → set
`MOZ_ENABLE_WAYLAND,1` in group 15.)
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
**5e. Font size** — 11 **(default)** · 10 · 12 · 13 (the family is the monospace/Nerd font from group 13;
just size here).
**5f. Extras** (multi-select, off by default): font ligatures, larger scrollback (10k+ lines), audible
bell off, confirm-on-close off, **window swallowing** (the terminal hides itself while a GUI app it
launched is open — Hyprland `misc:enable_swallow = true` + `swallow_regex = ^(<terminal-class>)$`,
emitted into `looknfeel.conf`).

---

## 6. Status bar  *(dedicated group — full functional depth + waybar design)*

rice generates the **functional** bar config (`config.jsonc`) and its themed `style.css`, not just the
colors. Recipes: `components.md` (waybar). The **design** library
`styling/waybar.md` holds the pattern catalog this group draws on — archetypes, the techniques harvested
from **~55 community configs** off the [Waybar Examples wiki](https://github.com/Alexays/Waybar/wiki/Examples),
plus the vertical/dual-bar/dock/macOS recipes. **Don't pick a bar look silently** — walk the design
questions; the option labels below are ordered by how often the pattern shows up in that corpus
(commonest = the default, first). Split across **four calls**: basics → design·shape → design·color &
state → content. The two design calls are the "waybar design" heart of this group.

**Call 1 — basics:**
**6a. Bar & shell strategy** — waybar **(default)** · waybar **+ extra widgets** (keep the bar, add eww
floating widgets / a swaync center — configured in group 7) · a **full widget shell that replaces the
bar** (Quickshell or AGS/Astal — caelestia/end-4-style; skip the rest of this group and do group 7
instead) · **HyprPanel** (turnkey bar+widgets panel, own config model — group 7) · none. *If a full shell
or HyprPanel is chosen, this group collapses to this one question and the bar look lives in group 7
(`styling/widgets.md`); waybar's design calls below only apply when waybar is the bar.*
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
updates, weather. Keep on-clicks aligned to the chosen tools (network → `nm-connection-editor`, audio →
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
(see `components.md` → JSON-check). `style.css` must start with `@import "colors.css";` so the engine
themes it.

---

## 7. Desktop widgets  *(dedicated group — beyond the bar)*

The widgets that make a desktop feel like a *rice* rather than a bar on a wallpaper: dashboards/control
centers, sidebars, on-screen displays (OSDs), music players, notification centers, calendars, power
menus, workspace overviews. Decided by the strategy answer in **6a**. The design library
`styling/widgets.md` is the decision guide (choosing a system + the widget archetypes); the per-toolkit
pages `styling/eww.md`, `styling/ags-astal.md`, `styling/quickshell.md` back the look. **Don't pick a
widget system silently** — it's a real commitment (a full shell *replaces* waybar, and only one
notification daemon can run). The engine themes the chosen shell via its widget template (`engine.md` →
"Widget-shell theming"). Skip this group entirely if 6a was plain **waybar** with no extra widgets.

**Call 1 — system & widgets:**
**7a. Widget system** — *(pre-filled from 6a; confirm)* None / just waybar **(default)** · **eww** (yuck +
SCSS — floating widgets, any shape; pairs with waybar) · **AGS / Astal** (TS/JS over GTK — batteries-
included services, the dashboard heritage) · **Quickshell** (QML — the modern, best-looking, animation-
rich shells; build-your-own; steepest curve) · a **turnkey pre-built shell** (install a ready Quickshell
desktop — see 7a-bis) · **HyprPanel** (turnkey AGS panel, GUI-configured — note it's **archived 2026-04**
but still usable; successor *Wayle*). Present all options uniformly — whatever the user picks is added
to the A3d install batch. A full shell (Quickshell/AGS/HyprPanel/turnkey) means **removing waybar's
`exec-once`** so two bars don't fight.
**7a-bis. Turnkey shell** (only if "pre-built" picked) — **end-4 / illogical-impulse** (the most-starred,
Material-You, AI/OCR extras) · **caelestia** (Material 3, per-monitor `shell.json`, fingerprint lock) ·
**Noctalia** (sleek minimal, multi-compositor) · **DankMaterialShell** (full shell replacing
bar/lock/idle/notifications/launcher at once). These are the trending 2025–2026 look — but they're a
**clone-and-install** of someone else's whole desktop, with their *own* theming model. Don't hand-theme
them: drive them with **matugen** on the same wallpaper (engine.md → "Widget-shell theming"), run the
project's install steps after one confirmation, and warn the plugin's per-app theming yields to theirs.
**7b. Which widgets** (multi-select; ordered by how often they appear in the corpus) — OSD
(volume/brightness) **(on)**, notification center **(on)**, dashboard / control center, music / now-playing
(MPRIS) **(on)**, calendar / clock panel, power / session menu, sidebar / quick-settings, system-info
gauges (CPU/RAM rings), workspace overview with live previews *(Quickshell only)*, clipboard / emoji /
color picker. *(A full shell typically ships most of these; eww-on-waybar usually adds just a couple — an
OSD + a dashboard.)*
**7c. Widget look** — Match my palette (engine-themed from the chosen scheme) **(default)** · Material You
(matugen, wallpaper-driven — the dominant full-shell look; needs `matugen`) · Glass / translucent + blur ·
Flat / opaque. *(Material You pairs naturally with Quickshell/AGS/HyprPanel; "match my palette" is the
engine's named-scheme path — see group 12.)*

Second call only if the system is a **full shell** and warrants it:
**7d. Motion & density** — Smooth eased (Material/`Behavior` animations, soft shadows) **(default)** ·
Snappy/minimal · Static. And card shape: Soft cards ~16px radius **(default)** · Pill/stadium · Square.

**Theming wiring:** register the chosen shell's line in the engine manifest (`eww`/`ags`/`quickshell`
template → its colors file) so `rice apply` re-themes it; one-time `@import`/`@use`/`qmldir` wiring per
`engine.md`. For **HyprPanel / Material-You-native** shells, don't fight their own theming — drive them
with **matugen** on the same wallpaper instead (`engine.md` → "Widget-shell theming"). Notification
widgets from a full shell (AGS `Notifd`, Quickshell `Notifications`) **replace** the group-9 daemon —
don't run both (the D-Bus name conflict); if a full shell owns notifications, set group 9 to *none*.

---

## 8. Launcher  *(dedicated group — full functional depth)*

rice generates the launcher's functional config + themed style. Recipes:
`components.md`; look: `styling/launchers.md`. Sets `$menu` for binds.

**8a. Launcher tool** — wofi **(default)** · rofi (most themeable) · fuzzel · tofi · **walker** (Wayland-
native, runs as a service for instant startup) · **vicinae** (the 2025 Raycast-for-Linux — Qt, runs
Raycast extensions, bundles clipboard/calc/emoji/window-switch) · **anyrun** (krunner-style, plugin-
extensible). Present all uniformly; the chosen one lands in the A3d install batch. The newer four (walker/vicinae/
anyrun + tofi) ship their own config/theme formats — for vicinae especially the engine themes only what
it exposes; default the **themeable** picks (wofi/rofi/fuzzel) when the user just wants palette coherence.
**8b. Mode** — App launcher / `drun` **(default)** · Run + drun combined · Also offer window-switcher
bind.
**8c. Layout & size** — Centered overlay, ~600px, single column **(default)** · Compact list (top) ·
Fullscreen grid · Multi-column grid (icons).
**8d. Show icons?** — Yes, app icons **(default)** · Text only (faster, no icon theme needed).

Second call if needed:
**8e. Matching & behavior** (multi-select): fuzzy matching **(on)**, type-to-search, hide scrollbar,
close on focus-loss **(on)**.

Style file `@import`s/`include`s the generated colors file so the engine themes it.

---

## 9. Notifications  *(dedicated group)*

rice generates the daemon's functional config + themed colors. *Only one* daemon can run (they fight
for the `org.freedesktop.Notifications` D-Bus name). Recipes:
`components.md`; look: `styling/notifications.md`.

**9a. Daemon** — mako **(default)** · dunst · swaync (adds a notification center / control panel) · none.
**9b. Position** — Top-right **(default)** · Top-center · Top-left · Bottom-right.
**9c. Default timeout** — 5s **(default)** · 3s (snappy) · 10s · Never (manual dismiss).
**9d. Behavior** (multi-select): group by app, show app icons **(on)**, a do-not-disturb toggle bind
**(on)**, max visible ~5.

Color keys come from the engine (leave them to rice / `@import` the colors file); don't hardcode hex.

---

## 10. Lock screen

Whether and how to lock (hyprlock). If on, generate a `hyprlock.conf` (group 16) and bind a lock key;
if hypridle is on (group 15), point its `lock_cmd` at hyprlock. Look: `styling/hyprlock.md`.

**10a. Enable a lock screen?** — Yes, hyprlock **(default)** · No.
**10b. Background** — Blurred screenshot **(default)** · The wallpaper · Solid palette color.
**10c. Clock** — Large time + date **(default)** · Time only · None.
**10d. Input pill style** — Accent-outlined, centered **(default)** · Minimal underline · Hidden until
typing.
**10e. Fingerprint unlock?** (offer when `IS_LAPTOP` / an `fprintd` device is likely) — No **(default)** ·
Yes — emit hyprlock's `auth { fingerprint { enabled = true } }` block so a registered finger unlocks
alongside the password. Requires `fprintd` + an enrolled finger (`fprintd-enroll`, root/user-side — name
it, never run it); note it falls back to password if no reader is present.

hyprlock colors are **literal hex** from the palette (it can't read Hyprland `$vars`) — the engine fills
them.

---

## 11. Window look & feel  *(re-theming asks this too)*

The compositor's own aesthetic. Defaults are the well-tuned shipped 0.54 values; see
`styling/hyprland-decoration.md` for values-that-look-good and `design-principles.md` for the archetypes
(Catppuccin soft-glass · flat/minimal · heavy glass · maximalist floating-islands). Now **10
sub-questions** — split across **three calls** (4 + 3 + 3) to respect the 4-per-call cap. **Ask
all three calls.** (Earlier wording suggested the last call was skippable; that was a mistake —
every sub-question gets asked. Defaults are option-list ordering only.)

Call 1:
**11a. Gaps & borders** — Comfortable (in 5 / out 20 / border 2) **(default)** · Tight (2/6/1) ·
None (0/0/1) · Spacious (8/30/3). Rhythm: `gaps_out ≈ 2× gaps_in`, rounding tracks `gaps_out`.
**11b. Corner rounding** — Rounded (10) **(default)** · Subtle (5) · Square (0). On 0.5x add
`rounding_power = 2` (bump to 2.3–4 for a softer "squircle").
**11c. Blur & shadows** — Blur + shadows on **(default)** · Blur on, shadows off · Both off (lighter
GPU). Frosted preset: `blur { size 6, passes 2 }`; pair window opacity with blur or it does nothing.
**11d. Window opacity** — Opaque 1.0 **(default)** · Slightly translucent inactive (active 1.0 /
inactive 0.9). Keep content windows opaque; chrome (terminals) can be translucent per-app.

Call 2:
**11e. Animations** — On, smooth defaults **(default)** · On, snappy/fast (speeds ~0.6×) · Off. Curve
families: shipped `easeOutQuint`, the `wind/winIn` slide-overshoot family, or Material-3
`md3_decel`/`md3_accel`.
**11f. Border color** — From my palette **(default)** → `col.active_border = $accent $accent2 45deg`
(vars come from the engine's `colors.conf`, so the border re-themes for free) · Custom gradient (free
text, e.g. `rgba(33ccffee) rgba(00ff99ee) 45deg`).
**11g. Layout** — Dwindle (BSP-like) **(default)** · Master/stack (offer `orientation` left/right/top/
bottom/center as a sub-pick). (`scrolling` is plugin-only, not core 0.54 — only offer it if a
scrolling-layout plugin is installed; defer to the hyprpm plugins flow.)
**11h. Window groups/tabs?** — No **(default)** · Yes, enable groups + a themed `groupbar` (tabbed
windows; `SUPER+G` togglegroup, `SUPER+TAB` cycle). Core Hyprland; the groupbar themes from the palette
like waybar (`config-templates.md` → looknfeel).
**11i. Per-app window rules?** — Beyond the shipped defaults (float pavucontrol/dialogs, PiP pin,
idleinhibit-on-fullscreen), ask if any apps should always **float / pin / go to a workspace / be
translucent**. Collect class + effect; emit block-form rules into `windowrules.conf`. Skippable —
the defaults already cover the common cases.
**11j. Runtime blur toggle?** — No **(default)** · Yes, bind `SUPER+SHIFT+B` to toggle blur (weak-GPU /
screenshot convenience). Installs `assets/scripts/blur-toggle.sh` (transient; a reload restores the real
setting). *(The heavier animation-preset switcher is a separate, deferred enhancement — the group-20
game-mode toggle already covers "all effects off".)*

---

## 12. Palette  *(re-theming asks this too)*

This is what makes the desktop **coherent** instead of a stock-gray box with a random border. Resolve
every answer into the engine's `palette.conf` (see *Mapping* below). Don't pick a scheme silently —
present it; if the user says "good defaults", use **Catppuccin Mocha** and say so.

**12a. Palette source** (always ask)
- **Named scheme (default)** → one from `palettes.md` (Catppuccin Mocha/Frappé/Macchiato/Latte, Gruvbox,
  Nord, Tokyo Night, Rosé Pine, Dracula, Everforest, Kanagawa, Solarized Dark). Ask the scheme as a
  second question; each ships a ready preset profile + matching wallpapers (group 14).
- **Match my wallpaper** → needs `matugen` or `wallust`; confirm the wallpaper path. If neither is
  currently installed, add the chosen generator (default matugen) to the A3d install batch — A5
  installs it before the palette is rendered. With matugen, the scheme type is selectable
  (`-t scheme-tonal-spot`/`-expressive`/`-vibrant`/…); Material-You → ANSI is approximate,
  wallust/pywal give a true 16-color scheme.
- **Manual hex** → ask at least `bg`, `fg`, `accent`; derive the rest or collect all 16.
**12b. Light vs dark** (only when ambiguous) — most schemes are dark; if the user picked one with a light
variant (Catppuccin Latte), confirm. For light, set GTK `color-scheme = prefer-light`.

**Accent pick** (separate `AskUserQuestion` after the scheme): each scheme has a sensible default
`accent`/`accent2`. The curated in-palette options live in `accents.tsv`: list them with
`rice accents <scheme>` (6–8 variants — e.g. Catppuccin mauve/blue/teal/green/peach/pink/red; Gruvbox
yellow/orange/green/aqua/blue/purple/red) and present them. Apply with `rice accent <name|hex>` (sets
`accent=` + re-renders), or `--pin` it into `palette.user.conf` so it survives later theme/wallpaper
changes; a custom hex works too. The accent drives borders, focus rings, and bar highlights — the
highest-leverage single choice.

---

## 13. Fonts  *(re-theming asks this too)*

**13a. UI / sans font** (always present) — the GTK/app text font. Present the catalog uniformly
(Inter, Lexend, Rubik, Cantarell, Noto Sans, Adwaita Sans); Inter is the default. The chosen family
lands in the A3d install batch. Record as `font_ui = <Family> <size>` (e.g. `Inter 11`).
**13b. Monospace / Nerd font** (always present) — terminal/bar/fetch/prompt font. **Default to
`JetBrainsMono Nerd Font`** (the universal pick) so glyphs render instead of tofu
(▯). Offer the full catalog (`fonts.md`); the chosen font lands in the A3d install batch so it's
present by the time anything glyph-heavy renders. Common pairings: *Inter/Noto Sans +
JetBrainsMono NF* (safe), *Space Grotesk + JetBrains Mono NF* (modern), *Rubik/Readex Pro + Maple Mono
NF* (cozy). Record as `font_mono = <Family> <size>`.

---

## 14. Wallpaper  *(re-theming asks this too)*

**14a. Matching wallpaper** (offer after the scheme is chosen — skip if the source was already "match my
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

## 15. Autostart & env  *(generate only)*

Prefer first-party Hypr ecosystem tools as defaults (see `ecosystem.md`). Present the same menu
regardless of what's currently installed; the picks land in the A3d install batch. (The bar,
notification daemon, and lock screen were chosen in their own groups above — here wire their
`exec-once`/units plus the rest.) Split across **two calls**.

Call 1 — services:
**15a. Wallpaper tool** — hyprpaper **(default, first-party)** · swww/awww (animated) · none. For swww
emit the `SWWW_DAEMON_BIN` from `detect-version.sh` (`swww-daemon` *or* the `awww` fork's `awww-daemon`),
never a hard-coded binary.
**15b. Polkit agent** — hyprpolkitagent **(default)** → `systemctl --user start hyprpolkitagent`
(systemd unit survives reloads) · polkit-gnome · polkit-kde · none.
**15c. Also autostart** (multi-select; defaults checked): clipboard history — `wl-paste --type text
--watch cliphist store` **and** a second `--type image` line **(on)**; network tray `nm-applet
--indicator` **(on if NetworkManager)**; bluetooth `blueman-applet` (off); idle `hypridle` **(on)**;
blue-light `hyprsunset -t 4000` (off); OSD `swayosd-server` (off). The portal env-propagation pair
(`dbus-update-activation-environment --systemd …` + `systemctl --user import-environment …`) is the
standard "screen-share is black" fix — include it.
**15d. Screen sharing / portals** (inform) — needs `xdg-desktop-portal-hyprland` +
`xdg-desktop-portal-gtk` and `XDG_CURRENT_DESKTOP=Hyprland`; add the env var and note missing packages.

Call 2 — environment variables (multi-select, sensible defaults checked):
- Cursor: `XCURSOR_SIZE,24` + `HYPRCURSOR_SIZE,24` **(on)**
- Toolkit: `QT_QPA_PLATFORM,wayland;xcb`, `GDK_BACKEND,wayland,x11,*` **(on)**
- Qt theming: `QT_QPA_PLATFORMTHEME,qt6ct` (on if qt6ct present; `QT_STYLE_OVERRIDE,kvantum` if Kvantum)
- Session/portals: `XDG_CURRENT_DESKTOP,Hyprland` (on)
- Firefox Wayland: `MOZ_ENABLE_WAYLAND,1` (on if browser is firefox)
- NVIDIA set — **2026 slim set**: `LIBVA_DRIVER_NAME,nvidia`, `__GLX_VENDOR_LIBRARY_NAME,nvidia`,
  `NVD_BACKEND,direct` (only with nvidia-vaapi-driver), `ELECTRON_OZONE_PLATFORM_HINT,auto` **(off —
  only the proprietary `nvidia` driver)**. **Do not emit `GBM_BACKEND` or `WLR_NO_HARDWARE_CURSORS`** —
  they're no longer in the required set (driver 555+ with explicit sync makes NVIDIA "just work").

**Gate the NVIDIA block on the active driver, not the card.** Emit the NVIDIA lines only when
`NVIDIA_PROPRIETARY=1`; under `nouveau` they break GLX/VA-API. `ELECTRON_OZONE_PLATFORM_HINT,auto` is
safe on any GPU. Don't ask "is it NVIDIA?" — read the driver and confirm the result. When
`CURSOR_NO_HARDWARE_RECOMMENDED=1` (nvidia/nouveau), also offer `cursor:no_hardware_cursors = true` in
looknfeel — the standard fix for a vanishing/stuttering cursor on those drivers.

---

## 16. Companion configs  *(generate only — when the matching tool is chosen)*

Generate a starter config for each tool picked above. These live in `~/.config/hypr/` next to
`hyprland.conf` but are read by their own daemons (NOT `source=`d). Formats: `ecosystem.md` +
`config-templates.md`. Ask before generating each if the user may already have one — never overwrite
without it being captured by the timestamped backup. This group is usually a single confirmation call.

- **hyprlock** → `hyprlock.conf` (required by hyprlock or it errors): background + accent-outlined input
  pill + clock per the group-9 answers. Colors are **literal hex** from the palette.
- **hypridle** → `hypridle.conf`: dim → lock → dpms-off → suspend listeners; `lock_cmd = pidof hyprlock
  || hyprlock`; lock *before* dpms-off; `before_sleep_cmd = loginctl lock-session`. **Ask the idle
  ladder** (one question): Balanced — lock 5m / screen-off 6m / suspend 30m **(default)** · Aggressive
  (laptop battery) — dim 1m / lock 2m / off 3m / suspend 10m · Relaxed — lock 15m / off 20m / no suspend ·
  Never (no auto-lock/suspend). Maps to the four `listener` timeouts (`config-templates.md` → hypridle);
  desktops usually drop the suspend tier.
- **hyprpaper** → `hyprpaper.conf`: `preload` + `wallpaper` (the group-13 image or a placeholder); set
  `ipc = on` so the wallpaper can be switched live.

---

## 17. Shell & prompt  *(dedicated group — generate only)*

The interactive shell is the last themed surface. rice sets up the prompt + shell colors by leaning on
the shell recipes (`shells.md`) and the rice engine's shell templates (`engine.md` → "Shell & prompt
theming"); the *colors* are palette-driven so the prompt re-themes with everything else. Present the
full menu of shells / prompt engines / fetches; whatever is picked lands in the A3d install batch.

**17a. Which shell do you want?** — **always ask this; don't silently default to the current shell.**
Keep current login shell **(default)** · bash · zsh · **fish** (the popular ricing pick — built-in
autosuggestions + tab-completions, i.e. "autocomplete" with no plugins). The pick lands in the A3d
install batch — even if the chosen shell isn't currently present, A5 installs it. If they want the
pick as the **login** shell, that's a manual `chsh -s "$(command -v <shell>)"` (the shell must be in
`/etc/shells`) taking effect next login — or offer the lower-risk **per-terminal** route (set the
emulator's shell, e.g. kitty `shell /usr/bin/fish`, foot `shell=…`), which keeps the login shell
unchanged. Note whichever they pick; never run `chsh` for them. Edits go in a guarded managed block,
parse-tested after each change.
**17b. Prompt engine** — starship **(default, cross-shell)** · oh-my-posh (cross-shell, JSON themes) ·
native shell prompt · leave as-is. Wire it to the engine (`STARSHIP_CONFIG` → rice-owned `starship.toml`,
or `oh-my-posh init --config` → rice-owned `rice.omp.json`) so `rice apply` recolors it. The chosen
engine's package lands in the A3d install batch.
**17c. fish syntax colors** (fish only) — Theme `fish_color_*` from the palette **(default yes)** · leave
fish defaults. Renders to `~/.config/fish/conf.d/zz-hypr-rice-colors.fish` (auto-sourced).
**17d. Startup fetch** — fastfetch **(default)** · neofetch (archived) · none. Add a guarded line in the
managed block; needs a Nerd Font for the logo/glyphs (group 13).
**17e. fish plugins** (fish only, optional) — autosuggestions/completions are built in; offer a small
**fisher** set: autopair · fzf.fish (needs `fzf`) · sponge · done. Default **off** unless asked; record
the chosen set in `~/.config/fish/fish_plugins` so `fisher update` reproduces it (track via the dotfiles
skill). See `shells.md` → "Fish plugins".

Optional second call: aliases & modern-CLI integration (`eza`/`bat`/`zoxide`/`fzf`/`atuin`, all
`command -v`-guarded — in fish, prefer `abbr` for git/nav shortcuts) and editor/history. Whichever the
user picks lands in the A3d install batch; the inits stay `command -v`-guarded so a future
uninstall doesn't break a login. The prompt/fish-color manifest lines to register live in
`engine.md`. **Reminder:** new aliases/prompt only appear in shells started after the
change — tell the user to open a new terminal or `exec <shell>`.

---

## 18. Utilities & menus  *(dedicated group — generate only)*

The small tools and pop-up menus that make a config feel *finished* — screenshots, screen recording,
OCR, color picker, clipboard/emoji pickers, and a power menu. Every popular rice ships these; a
generator easily skips them. Full recipes, install steps, deps, and binds: `utilities.md`. The
functional scripts ship as **plugin template files** in this skill's `assets/scripts/` (plain scripts,
no palette — copy + `chmod`, not render); their keybinds go into `binds.conf` (group 3).

**18a. Which utilities & menus?** (multi-select; order by corpus frequency; pre-check the items rices
typically include) — Screenshot (region/window/full + annotate) **(on)** · Clipboard history picker
**(on)** · Color picker **(on)** · Power menu **(on)** · Screen recording · OCR (screen → text) ·
Emoji picker · Calculator · Wi-Fi menu / applet · Bluetooth menu / applet · Night-light toggle.

Prefer the **2025–2026 tools** by default: **satty** for screenshot annotation (over the older swappy),
**wl-screenrec** for HW-encoded recording (over wf-recorder on AMD/Intel), **hyprshot**/`grimblast` for
the capture itself. The shipped `screenshot.sh`/`screenrecord.sh` auto-detect at runtime, so the chosen
tools land in the install batch and the scripts pick the right one once they're present.

For each checked item: copy its script (or just add the bind for the bind-only tools — clipboard,
emoji, calculator), wire the keybind into `binds.conf`, and ensure its autostart prerequisite (cliphist
watchers, nm-applet) is enabled in group 15. **Wi-Fi/Bluetooth** ship as the tray applets by default
(robust) — don't hand-author fragile nmcli/bluetoothctl rofi parsers; see `utilities.md` for the
keyboard-driven alternative. Any tool that isn't installed yet goes into the A3d package batch.
Validate `binds.conf` (`hyprctl reload` + `configerrors`) after writing.

---

## 19. Login & boot  *(dedicated group — generate only, root-side)*

The login screen and boot splash are part of a full rice (HyDE/Omarchy theme them; most generators
skip them). Unlike per-user configs these live under `/etc` and `/usr`, so changes need **root** — the
plugin **generates the palette-matched files and hands the user the exact `sudo`/`sudoedit`
commands**; Claude never sudos. Full recipes per tool: `login.md`. Detect the active manager first:
`systemctl is-enabled greetd sddm gdm 2>/dev/null` (also surfaced by detection). Skip silently if the
user only wants the per-user desktop.

**19a. Theme the login screen & boot?** (multi-select; default off unless asked — it's root-side) —
- **Greeter** *(pre-filled from the detected DM)* — greetd+tuigreet (theme flags), greetd+ReGreet (GTK,
  matched to the desktop GTK theme), or SDDM (a `theme.conf`-editable theme like `sddm-astronaut` /
  `sugar-candy` / a Catppuccin theme; SDDM is Qt — name the Qt deps). Generate colors from
  `palette.conf`; provide the `sudo cp`/`sudoedit` lines.
- **Plymouth** boot splash — a palette-matched theme in `/usr/share/plymouth/themes/`, set with
  `plymouth-set-default-theme -R <theme>` (root).
- **GRUB** theme — a theme in `/boot/grub/themes/` referenced by `GRUB_THEME=` in `/etc/default/grub`,
  then `grub-mkconfig -o /boot/grub/grub.cfg` (root).

These are coarse (palette-matched backgrounds, not live-regenerated on every re-theme) and entirely
root-side: **generate the files, print the commands, never run them silently.** Note the package for
any greeter/theme not installed.

---

## 20. Gaming & performance  *(dedicated group — generate only, opt-in)*

The latency/perf tweaks gamers expect and a generator usually omits: screen tearing, VRR, fullscreen
effect-stripping, and a runtime "game mode" toggle. **Gated behind one opt-in** so non-gamers never see
it. Full recipes, caveats, and the exact rules: `gaming.md`. All output is 0.54 hyprlang block-form.

**Call 1 — the gate:**
**20a. Set up gaming/performance tweaks?** — No, skip **(default)** · Yes.

**Call 2 (only if yes):**
**20b. Screen tearing** — Off **(default)** · On for specific games (ask classes from `hyprctl
clients`). Sets `general:allow_tearing = true` + a per-class `immediate` rule; **gate the `env =
WLR_DRM_NO_ATOMIC,1` line on kernel < 6.8 only** — don't emit it on modern kernels.
**20c. VRR / adaptive sync** — Off **(default)** · Fullscreen (`2`) · Content-aware (`3`, smartest).
Per-monitor `vrr` field; needs a FreeSync/G-Sync display.
**20d. Strip effects on fullscreen + inhibit idle?** — Yes **(default)** · No. Emits the
`no_blur`/`no_border`/`no_anim`/`idle_inhibit` fullscreen rules.
**20e. Game-mode toggle key?** — Yes, bind `SUPER+F1` **(default)** · No. Installs the shipped
`assets/scripts/gamemode.sh` (copy + `chmod`, like group 18) and binds it.

**`misc:vfr = true` is set unconditionally** (biggest idle/battery win) regardless of these answers —
it's a default in the generated `misc` block, not a question here. Validate (`hyprctl reload` +
`configerrors`) after writing.

---

## 21. Laptop  *(dedicated group — generate only; opt-in)*

Lid handling, power profile, and charge limit. Touchpad is already covered in group 2;
brightness/volume/media keys are already in the default `binds.conf`, so they're not re-asked.

**Call 1 — the gate:**
**21a. Set up laptop options?** — *(default = the chassis answer: `IS_LAPTOP=1` → Yes, else No)*. The
detected chassis only sets the default; the user can always pick the other answer.

**Call 2 (only if yes):**
**21b. Lid close action** — Suspend **(default)** · Lock (hyprlock) · Clamshell: blank the internal
panel, keep externals (good when docked) · Nothing. Emits a `bindl = , switch:on:Lid Switch, …` line
(device name from `hyprctl devices`; `config-templates.md` → binds). **Warn about double-handling:** if
systemd-logind also suspends on lid, set `HandleLidSwitch*` in `/etc/systemd/logind.conf` to `ignore`
(root-side; document, don't run).
**21c. Power-profile tool** — *(pre-filled from `POWER_TOOL` if detected; user can override)*
power-profiles-daemon **(default)** · TLP · auto-cpufreq · none. The three are **mutually exclusive** —
never enable two. PPD pairs with the waybar power module. The chosen tool's package lands in the A3d
install batch; enabling its daemon is root/systemd (document the `systemctl enable --now` line).
**21d. Battery charge limit?** — No **(default)** · Yes, 80% (longevity). Root-side: a systemd one-shot
writing `/sys/class/power_supply/BAT*/charge_control_end_threshold`, or TLP's
`STOP_CHARGE_THRESH`. Generate the unit + the `sudo` install command; never run it.

Dock/undock **monitor** profiles are part of the Monitors group (1), not here.

---

## 22. Accessibility  *(dedicated group — generate only, opt-in)*

Off by default — surface it once (a single multi-select with nothing pre-checked), since it's high
value for those who need it and cheap to skip for those who don't. Blocks: `config-templates.md`.

**22a. Accessibility helpers?** (multi-select, all off by default) —
- **Screen magnifier** — bind `SUPER+=` / `SUPER+-` to Hyprland's built-in `cursor:zoom_factor` (no
  external tool). Optionally `cursor:zoom_rigid = true` to keep the cursor centred.
- **Large cursor** — bump `XCURSOR_SIZE`/`HYPRCURSOR_SIZE` to 32/48 (group 15 env) + `hyprctl setcursor
  <theme> <size>`; also set GTK `cursor-size`.
- **Night-light toggle** — bind `hyprsunset` warm-temp toggle (shares the mechanism in `utilities.md` →
  night light; `SUPER+SHIFT+N`).
- **Larger UI** — a low-vision preset: bump monitor `scale` (group 1) + GTK `text-scaling-factor 1.25`
  (note the XWayland-blur fractional-scaling caveat).

Map each checked item to its block/env/bind. Magnifier and large-cursor are pure Hyprland; the UI-scale
one touches monitor scale + GTK settings (mention the fractional-scaling gotcha). Validate after writing.

---

## 23. Hyprland plugins  *(dedicated group — generate only, opt-in)*

The community-plugin layer (`hyprpm`) most generators skip: a **workspace overview** (exposé),
**scrolling / tree** layouts, **per-monitor workspaces**, window **title bars**, and dropdown
**scratchpads**. Gated behind one opt-in so non-plugin users never see it. Full flow, per-plugin config
blocks, and the version-pinning caveat: **`plugins.md`**.

**The hard rule:** plugins are compiled against the exact running Hyprland build, so a Hyprland upgrade
**breaks every plugin** until rebuilt. That makes install a *user* action — **Claude never runs
`hyprpm`**; we generate the `plugin {}` blocks (→ `plugins.conf`) + binds, then print the exact
`hyprpm add/enable/reload` commands and the build-toolchain dep. (User is on Hyprland 0.54.3 — plugins
must match.) Gate `general:layout =` / `hy3:` / `split-workspace` binds on the plugin actually being
installed (a missing non-core layout/dispatcher errors the reload; an unused `plugin {}` block is
harmless).

**Call 1 — the gate:**
**23a. Set up Hyprland plugins?** — No, skip **(default)** · Yes.

**Call 2 (only if yes; multiSelect, none pre-checked):**
**23b. Which plugins?** —
- **Workspace overview** — `hyprexpo` (grid exposé, `SUPER+\`` toggle). *Skip if a full widget shell
  (group 7) already provides an overview.*
- **Scrolling layout** — `hyprscrolling` (official) / `hyprscroller` — PaperWM-style infinite strip;
  **replaces** dwindle/master (group 11g).
- **i3/sway tree tiling** — `hy3` — manual split tree with tabbed groups; replaces the layout + split binds.
- **Per-monitor workspaces** — `split-monitor-workspaces` — each display gets its own 1–10 (offer only
  when `MONITOR_COUNT > 1`; rebinds the workspace keys).
- **Window title bars** — `hyprbars` (CSD-like bars + buttons; themable from the palette).
- **Dropdown scratchpads** — `pyprland` (Quake terminal + expose/magnify; **pip/AUR, not hyprpm** — its
  own `pyprland.toml` + `exec-once = pypr`). Core's `special:` workspace (group 1) already covers one
  scratchpad with no dependency — offer pyprland for **multiple named** dropdowns.
- **Decorative** — `borders-plus-plus` (extra border ring), `hyprtrails` (motion trails), `hyprwinwrap`
  (run an app as the wallpaper).

For each checked plugin: emit its `plugin {}` block into `plugins.conf` (add `source = ~/.config/hypr/
plugins.conf` to `hyprland.conf`), its binds into `binds.conf`, the `layout =` line for a layout plugin
(gated on install), and print the `hyprpm`/`pip` commands + the "re-run `hyprpm update && hyprpm reload`
after every Hyprland upgrade" warning. Validate (`hyprctl reload` + `configerrors`) after writing.

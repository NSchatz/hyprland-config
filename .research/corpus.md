# Hyprland dotfiles corpus

Cached 2026-06-05 from https://github.com/topics/hyprland (sorted by stars).
For each repo: stars, one-line description, theming engine, and the directory
paths a component-researcher should fetch. Paths are repo-root-relative.
Use `gh api repos/<owner>/<repo>/contents/<path>?ref=HEAD` to fetch a file,
or browse raw at `https://raw.githubusercontent.com/<owner>/<repo>/HEAD/<path>`.

Skipped from top-20 (not dotfiles/rices):
- `feschber/lan-mouse` — mouse-sharing daemon, not a rice
- `hyprland-community/awesome-hyprland` — awesome list
- `JaKooLit/Arch-Hyprland`, `JaKooLit/Fedora-Hyprland` — installer scripts (not configs)
- `SHORiN-KiWATA/Shorin-ArchLinux-Guide` — tutorial / written guide
- `gh0stzk/dotfiles` — BSPWM rice, not Hyprland
- `BarutSRB/Hiro` — Swift/macOS WM inspired by Hyprland, no Linux configs

Replacements pulled from pages 2-3: `linuxmobile/hyprland-dots`, `Axenide/Ax-Shell`,
`koeqaife/hyprland-material-you`, `binnewbs/arch-hyprland`, `fufexan/dotfiles`,
`Matt-FTW/dotfiles`.

---

## 1. end-4/dots-hyprland — 14.7k★
Usability-first Hyprland dotfiles, AI-integrated Quickshell. Engine: matugen.
Layout: `dots/.config/*` (mirrors `~/.config/`). Lua-based modular hypr config.

Relevant paths:
- hypr: `dots/.config/hypr/hyprland.lua`, `dots/.config/hypr/hyprland/` (env.lua, execs.lua, general.lua, keybinds.lua, rules.lua, variables.lua), `dots/.config/hypr/custom/` (user overrides), `dots/.config/hypr/hypridle.conf`
- waybar: none (uses Quickshell)
- launcher: `dots/.config/fuzzel/fuzzel.ini`, `dots/.config/fuzzel/fuzzel_theme.ini`
- notifications: none standalone (handled inside Quickshell)
- widgets: `dots/.config/quickshell/ii/` (the "illogical impulse" shell — bar, dashboard, overview, AI panel, sidebar)
- lockscreen: `dots/.config/hypr/hyprlock.conf`, `dots/.config/hypr/hyprlock/` (colors.conf, scripts)
- terminal: `dots/.config/kitty/kitty.conf`, `dots/.config/foot/foot.ini`
- shell-prompt: `dots/.config/starship.toml`, `dots/.config/fish/`
- utilities: `dots/.config/wlogout/`, `dots/.config/xdg-desktop-portal/hyprland-portals.conf`
- login-boot: none (KDE-style with `dots/.config/kde-material-you-colors/`)
- theming primitives: `dots/.config/matugen/config.toml`, `dots/.config/matugen/templates/` (ags, fuzzel, gtk-3.0/4.0, hyprland/colors.lua, hyprland/hyprlock-colors.conf, kde, qt6ct)

Notes: lua-based hypr config is unusual — `hyprland.lua` is the entry; runtime tool generates `.conf` from it. No traditional waybar/notif daemon — Quickshell does both.

## 2. caelestia-dots/shell — 9.8k★
Pure Quickshell shell ("No waybar here"). Engine: matugen (via companion repo).
This repo is the SHELL ONLY — not a full dotfiles set. Pair with #12.

Relevant paths:
- hypr: none (consumes hypr config from caelestia-dots/caelestia)
- waybar: none (by design)
- launcher: `modules/launcher/` (built-in)
- notifications: `modules/notifications/`, `services/Notifs.qml`
- widgets: `shell.qml` (entry), `modules/` (bar, dashboard, controlcenter, drawers, lockscreen, osd, session, launcher, notifications), `components/` (reusable QML), `services/` (Audio, Brightness, Network, etc.)
- lockscreen: `modules/lockscreen/` (no hyprlock — uses its own)
- terminal: none
- shell-prompt: none
- utilities: `modules/session/` (wlogout-equivalent), built-in clipboard via `services/`
- login-boot: none
- theming primitives: `assets/` (default schemes); reads matugen output at runtime

Notes: QML/C++ shell, has a CMake-built C++ plugin in `plugin/`. Nix flake provided. Pair with caelestia-dots/caelestia for full rice.

## 3. prasanthrangan/hyprdots (HyDE) — 8.5k★
"Aesthetic, dynamic and minimal dots for Arch hyprland". Engine: hand-rolled wallbash (`.dcol` templates).
Layout: `Configs/.config/*` for runtime; `Source/` for installer assets.

Relevant paths:
- hypr: `Configs/.config/hypr/hyprland.conf`, `Configs/.config/hypr/keybindings.conf`, `Configs/.config/hypr/monitors.conf`, `Configs/.config/hypr/windowrules.conf`, `Configs/.config/hypr/userprefs.conf`, `Configs/.config/hypr/nvidia.conf`, `Configs/.config/hypr/animations/`, `Configs/.config/hypr/themes/`
- waybar: `Configs/.config/waybar/config.jsonc`, `Configs/.config/waybar/config.ctl`, `Configs/.config/waybar/modules/` (per-module jsonc)
- launcher: `Configs/.config/rofi/` (clipboard.rasi, notification.rasi, quickapps.rasi, selector.rasi, steam/)
- notifications: `Configs/.config/dunst/dunstrc`, `Configs/.config/dunst/dunst.conf`, `Configs/.config/dunst/wallbash.conf`
- widgets: none (waybar + rofi only)
- lockscreen: `Configs/.config/hypr/hyprlock.conf` (in animations/ + themes/), `Configs/.config/swaylock/config` (legacy)
- terminal: `Configs/.config/kitty/kitty.conf`, `Configs/.config/kitty/theme.conf`, `Configs/.config/kitty/userprefs.conf`
- shell-prompt: `Configs/.p10k.zsh` (no starship); also `Configs/.config/fish/`
- utilities: `Configs/.config/wlogout/layout_1`, `layout_2`, `style_1.css`, `style_2.css`
- login-boot: `Source/arcs/Sddm_Candy.tar.gz`, `Source/arcs/Sddm_Corners.tar.gz`, `Source/arcs/Grub_Pochita.tar.gz`, `Source/arcs/Grub_Retroboot.tar.gz`
- theming primitives: `Configs/.config/hyde/wallbash/Wall-Dcol/` (gtk, kitty, kvantum, rofi, waybar, hypr — `.dcol` templates), `Configs/.config/hyde/wallbash/Wall-Ways/` (cava, code, discord, notification, etc.)

Notes: HyDE uses Configs/.config/* layout. Custom "wallbash" templating engine (`.dcol` files) instead of matugen — generates colors from wallpaper. Big monorepo with installer in `Scripts/`. Lots of theme variants under `Configs/.config/hypr/themes/`.

## 4. noctalia-dev/noctalia-shell — 7.3k★
Sleek Quickshell-based Wayland desktop shell. Engine: hand-rolled (JSON color schemes).
This repo is the SHELL ONLY — bring your own hypr config.

Relevant paths:
- hypr: `Assets/Templates/hyprland.conf` (recommended-snippet only)
- waybar: none (by design)
- launcher: `Modules/MainScreen/` / `Modules/Panels/` (built-in launcher view)
- notifications: `Modules/Notification/`, `Modules/Toast/`, `Services/Noctalia/`
- widgets: `shell.qml` (entry), `Modules/` (Background, Bar, Cards, DesktopWidgets, Dock, LockScreen, MainScreen, Notification, OSD, Panels, Toast, Tooltip), `Widgets/` (reusable: NBattery.qml, NButton.qml, etc.), `Services/` (Compositor, Control, Hardware, Media, Networking, Power, Theming)
- lockscreen: `Modules/LockScreen/` (in-shell lock, not hyprlock)
- terminal: none
- shell-prompt: `Assets/Templates/terminal/starship.toml`, `Assets/Templates/terminal/starship-predefined.toml`
- utilities: built into shell (no wlogout — `Modules/Panels/`)
- login-boot: none
- theming primitives: `Assets/ColorScheme/` (Ayu, Catppuccin, Dracula, Eldritch, Gruvbox, Kanagawa, Noctalia-default — all JSON), `Assets/Templates/pywalfox.json`, `Services/Theming/`

Notes: QML shell, Nix flake provided. JSON-driven color schemes — not matugen-native but can consume matugen output. Designed for Niri AND Hyprland.

## 5. AvengeMedia/DankMaterialShell — 6.7k★
Material You Quickshell + Go shell ("DMS"). Engine: matugen (deeply integrated).
This is a SHELL ONLY — distributed as a Quickshell module and Go CLI.

Relevant paths:
- hypr: none (consumer-supplied; greeter ships its own `hyprland.conf`)
- waybar: none (by design)
- launcher: `quickshell/Modules/AppDrawer/` (and Spotlight)
- notifications: `quickshell/Modules/Notifications/`
- widgets: `quickshell/shell.qml`, `quickshell/DMSShell.qml`, `quickshell/Modules/` (bar, dashboard, control center, etc.), `quickshell/Common/Appearance.qml`, `quickshell/Services/`, `quickshell/Widgets/`
- lockscreen: `quickshell/Modules/Lock/` (in-shell)
- terminal: `quickshell/matugen/configs/alacritty.toml` (matugen target only)
- shell-prompt: none
- utilities: `core/cmd/dms/` (Go CLI: clipboard, brightness, colorpicker, etc.)
- login-boot: `quickshell/Modules/Greetd/` (greetd greeter — `GreeterContent.qml`, `GreetdSettings.qml`); `distro/debian/dms-greeter/` packaging
- theming primitives: `quickshell/matugen/configs/` (alacritty, base, kitty, hyprland, etc.), `core/internal/matugen/` (Go matugen wrapper), `quickshell/matugen/templates/`

Notes: Hybrid Go+QML. Has its own greetd greeter (`dms-greeter`) — replaces sddm/tuigreet. Matugen orchestration done in Go (`core/cmd/dms/commands_matugen.go`).

## 6. mylinuxforwork/dotfiles (ML4W) — 4.8k★
Advanced Hyprland setup with multi-distro installer. Engine: matugen.
Layout: `dotfiles/.config/*`. Modular lua-style hypr config inspired by end-4.

Relevant paths:
- hypr: `dotfiles/.config/hypr/hyprland.conf` (or `.lua`), `dotfiles/.config/hypr/conf/` (animation.lua, animations/, autostart.lua, decoration.lua, decorations/, plus monitor/keybinds/window subdirs), `dotfiles/.config/hypr/colors.conf`, `dotfiles/.config/hypr/colors.lua`
- waybar: `dotfiles/.config/waybar/themes/default/config`, `dotfiles/.config/waybar/colors.css`, `dotfiles/.config/waybar/modules.json`, `dotfiles/.config/ml4w/settings/waybar-quicklinks.json`
- launcher: `dotfiles/.config/rofi/` (config-cliphist.rasi, config-compact.rasi, config-hyprshade.rasi, etc.), also `dotfiles/.config/walker/`
- notifications: `dotfiles/.config/swaync/config.json`, `dotfiles/.config/swaync/style.css`, `dotfiles/.config/swaync/themes/glass/`
- widgets: `dotfiles/.config/quickshell/` (CalendarApp, PowerApp, SidebarApp, WallpaperApp, WelcomeApp, overview — modular Quickshell apps), `dotfiles/.config/nwg-dock-hyprland/`, `dotfiles/.config/sidepad/`
- lockscreen: `dotfiles/.config/hypr/hyprlock.conf`
- terminal: `dotfiles/.config/kitty/kitty.conf`
- shell-prompt: `dotfiles/.config/ohmyposh/` (oh-my-posh JSON), `dotfiles/.config/fish/`
- utilities: `dotfiles/.config/wlogout/style.css`, `dotfiles/.config/wlogout/layout`, `dotfiles/.config/wlogout/colors.css`, `dotfiles/.config/waypaper/` (wallpapers)
- login-boot: install script `dotfiles/.config/ml4w/scripts/ml4w-install-sddm`
- theming primitives: `dotfiles/.config/matugen/config.toml`, `dotfiles/.config/matugen/templates/` (btop.theme, colors.css, colors.json, gtk-colors.css), `dotfiles/.config/matugen/post-hook-scripts/`

Notes: Uses oh-my-posh (not starship). Mixes Lua and conf-based hypr modules. Has Quickshell apps split per-feature (not one shell.qml). ML4W installer is the standard entry point.

## 7. JaKooLit/Hyprland-Dots — 3.4k★
Standalone dotfiles paired with JaKooLit's installers. Engine: wallust.
Layout: `config/*` (mirrors `~/.config/`).

Relevant paths:
- hypr: `config/hypr/hyprland.conf`, `config/hypr/UserConfigs/` (01-UserDefaults.conf, ENVariables.conf, LaptopDisplay.conf, Laptops.conf, Startup_Apps.conf, UserAnimations.conf, UserDecorations.conf, UserKeybinds.conf, UserSettings.conf, WindowRules.conf, WorkSpaceRules.conf), `config/hypr/Monitor_Profiles/default.conf`, `config/hypr/animations/`, `config/hypr/UserScripts/`
- waybar: `config/waybar/` (config.jsonc), `config/waybar/Modules/`, `config/waybar/ModulesCustom/`, `config/waybar/ModulesGroups/`, `config/waybar/ModulesVertical/`
- launcher: `config/rofi/` (config-Animations.rasi, config-Monitors.rasi, config-calc.rasi, config-clipboard.rasi, config-waybar-layout.rasi, config-waybar-style.rasi)
- notifications: `config/swaync/config.json`, `config/swaync/style.css`
- widgets: `config/ags/config.js`, `config/ags/modules/` (AGS-based) — but mostly waybar; `config/quickshell/` (newer Quickshell config alongside AGS)
- lockscreen: `config/hypr/hyprlock.conf`, `config/hypr/hyprlock-1080p.conf`, `config/hypr/hyprlock-2k.conf`
- terminal: `config/kitty/kitty.conf`, `config/kitty/kitty-themes/01-Wallust.conf`, `config/ghostty/ghostty.config`, `config/wezterm/`
- shell-prompt: none (relies on shell defaults)
- utilities: `config/wlogout/layout`, `config/wlogout/style.css`, `config/swappy/`, `config/cava/`
- login-boot: none in this repo (handled by installer scripts in JaKooLit/Arch-Hyprland etc.)
- theming primitives: `config/wallust/templates/` (colors-cava, colors-ghostty.conf, colors-waybar.css, etc.), `config/hypr/wallust/wallust-hyprland.conf`, `config/rofi/wallust/colors-rofi.rasi`

Notes: Strong "UserConfigs" pattern (split conf files for each concern). Wallust-native (not matugen). Both AGS and Quickshell trees coexist.

## 8. caelestia-dots/caelestia — 3.3k★
Companion dotfiles to caelestia-dots/shell. Engine: hand-rolled scheme JSON (consumed by shell).
Layout: per-tool top-level dirs (no `.config/` prefix).

Relevant paths:
- hypr: `hypr/hyprland.conf`, `hypr/hyprland/` (animations.conf, decoration.conf, env.conf, execs.conf, general.conf, gestures.conf, group.conf, input.conf, keybinds.conf, misc.conf, rules.conf, scrolling.conf), `hypr/variables.conf`, `hypr/scheme/default.conf`, `hypr/scripts/`
- waybar: none (uses caelestia shell)
- launcher: none (uses caelestia shell)
- notifications: none (uses caelestia shell)
- widgets: none (uses caelestia shell)
- lockscreen: none (caelestia shell ships its own lock)
- terminal: `foot/foot.ini`
- shell-prompt: `starship.toml`, `fish/config.fish`, `fish/functions/fish_greeting.fish`
- utilities: none
- login-boot: none
- theming primitives: `hypr/scheme/default.conf` (color scheme entry point)

Notes: This is the "system config side" of the caelestia split — pairs with caelestia-dots/shell. Use both together. PKGBUILD ships at root. `install.fish` is the installer.

## 9. Jas-SinghFSU/HyprPanel — 2.2k★
A configurable AGS-based bar/panel for Hyprland. Engine: matugen-aware (theme JSONs).
This is a WIDGET/BAR ONLY, not a full rice.

Relevant paths:
- hypr: none (consumer-supplied)
- waybar: none (HyprPanel REPLACES waybar)
- launcher: none
- notifications: built into panel (`src/components/notifications/`)
- widgets: `src/` (TypeScript AGS app — `src/components/bar/`, `src/components/menus/`, `src/components/notifications/`, `src/components/osd/`, `src/services/`)
- lockscreen: none
- terminal: none
- shell-prompt: none
- utilities: none
- login-boot: none
- theming primitives: `themes/` (catppuccin_frappe.json, catppuccin_latte.json, catppuccin_macchiato.json, catppuccin_mocha.json + split/vivid variants, cyberpunk.json, etc.), `src/services/matugen/` (matugen integration), `src/components/settings/pages/theme/menus/matugen.tsx`

Notes: Single-component repo (the panel itself). Bundle-style JSON theme files. Nix flake provided. Useful as a reference for "what should a waybar replacement do".

## 10. dusklinux/dusky — 2.2k★
Arch-Hyprland rice/distro. Engine: matugen.
Layout: `.config/*` at repo root. Heavy theme-variant approach.

Relevant paths:
- hypr: `.config/hypr/hyprland.conf`, `.config/hypr/hyprland.lua`, `.config/hypr/hypridle.conf`, `.config/hypr/hyprlock.conf`, `.config/hypr/hyprlock_themes/` (001_dusky, 002_dusky_oled, 003_cyberpunk, 004_dracula, 005_minimal — each has hyprlock.conf + theme.json)
- waybar: `.config/waybar/01_mechabar_h/` (config.jsonc, style.css), `.config/waybar/02_reminiscent_h/` (config.jsonc, style.css) — multiple themed bar variants
- launcher: `.config/rofi/config.rasi`, `.config/rofi/wallpaper.rasi`
- notifications: `.config/mako/config`
- widgets: none (waybar-based)
- lockscreen: `.config/hypr/hyprlock.conf`, `.config/hypr/hyprlock_themes/*/hyprlock.conf`
- terminal: `.config/alacritty/alacritty.toml`, `.config/foot/foot.ini`, `.config/kitty/kitty.conf`
- shell-prompt: `.config/starship.toml`, `.config/matugen/templates/starship-colors.toml`
- utilities: `.config/wlogout/layout`, `user_scripts/wlogout/dusky_session.sh`, `.config/cliphist/` indirectly via scripts
- login-boot: `user_scripts/sddm/` (sddm setup scripts only — no theme tarballs in tree)
- theming primitives: `.config/matugen/` (config.toml + templates: waybar-colors.css, starship-colors.toml, etc.), `.config/matugen/generated_fresh/` (output cache)

Notes: Multiple bar variants ("mechabar", "reminiscent") and lock themes as numbered folders — pattern to copy if you want a theme-switcher rice.

## 11. flickowoa/dotfiles — 2.0k★
Minimal "dotfiles go brrr" rice. Engine: hand-rolled (theme.conf-driven).
Layout: `config/hypr/` only — single-component rice.

Relevant paths:
- hypr: `config/hypr/hyprland.conf`, `config/hypr/land/binds.conf`, `config/hypr/land/defaults.conf`, `config/hypr/land/general.conf`, `config/hypr/land/nvidia.conf`, `config/hypr/land/rules.conf`, `config/hypr/profiles/battery.conf`, `config/hypr/profiles/power.conf`
- waybar: none (uses ironbar)
- launcher: none
- notifications: none
- widgets: `config/hypr/themes/base/components/ironbar/ironbar.json`, `config/hypr/themes/base/components/ironbar/style.sass` — uses ironbar instead of waybar
- lockscreen: `config/hypr/scripts/lock` (script only)
- terminal: `config/hypr/components/foot.ini`
- shell-prompt: `config/hypr/themes/base/starship.toml`, `config/hypr/components/fish/theme.fish`
- utilities: none (custom scripts in `config/hypr/scripts/`)
- login-boot: `util/udev/60-onbattery.rules`, `util/udev/61-onpower.rules` (laptop power profiles)
- theming primitives: `config/hypr/themes/base/colors/`, `config/hypr/themes/base/theme.conf`, `config/hypr/themes/base/scripts/apply.sh` — hand-rolled theme switcher

Notes: Tiny, structural rice. Uses ironbar (not waybar). Everything namespaced under `config/hypr/` even when not Hyprland-specific. Laptop focused.

## 12. ryan4yin/nix-config — 1.9k★
NixOS configuration for desktops/servers. Engine: hand-rolled (Nix-managed dotfiles).
Layout: NixOS modules — paths are `.nix` files producing configs at runtime.

Relevant paths:
- hypr: `system/programs/hyprland/default.nix`, `system/programs/hyprland/hyprland.lua`, `system/programs/hyprland/binds.lua`, `system/programs/hyprland/animations.lua`, `system/programs/hyprland/rules.lua`, `system/programs/hyprland/settings.lua`, `system/programs/hyprland/smartgaps.lua`, `system/programs/hyprland/variables.nix`, `hosts/io/hyprland.nix`
- waybar: none in tree (likely in home-manager elsewhere or not used)
- launcher: none in tree
- notifications: none in tree
- widgets: none (this is a server-leaning nix-config)
- lockscreen: `home/linux/gui/base/hypridle/hypridle.conf`, `home/linux/gui/base/hypridle/default.nix`
- terminal: `home/base/gui/terminal/alacritty/default.nix`, `home/base/gui/terminal/foot.nix`, `home/base/gui/terminal/ghostty.nix`, `home/base/gui/terminal/kitty.nix`
- shell-prompt: `home/base/core/starship.nix`
- utilities: none in tree
- login-boot: none specific to hypr (general nixos config in `nixos-installer/`)
- theming primitives: none structured (uses upstream nix module options)

Notes: NixOS-flavored. Hyprland config is written in LUA via Nix string templates (`system/programs/hyprland/*.lua`). Closer to "infra reference" than a visual rice. Useful for hypr modular config patterns and NixOS integration only.

## 13. 1amSimp1e/dots — 1.7k★
Hyprland dotfiles + customization. Engine: hand-rolled.
Layout: `configs/*` (top-level, NOT under `.config/`).

Relevant paths:
- hypr: none in tree (this repo is dotfiles for surrounding apps — actual hypr conf appears to be in a different release/branch)
- waybar: none in tree
- launcher: none in tree
- notifications: none in tree
- widgets: none in tree
- lockscreen: `configs/swaylock/config`
- terminal: `configs/alacritty/alacritty.yml`, `configs/kitty/kitty.conf`
- shell-prompt: `configs/prompt/starship.toml`
- utilities: none in tree
- login-boot: none
- theming primitives: `configs/spicetify/Themes/` (spicetify only — not Hyprland theming)

Notes: Despite its star count, this repo's HEAD ships only terminal/editor/spicetify configs. The hypr/waybar/rofi parts may be on a branch or in an unrelated rice. Treat as low-priority unless researching terminal/spicetify specifically.

## 14. linuxmobile/hyprland-dots (kenos) — 1.7k★
"Soft-spoken desktop environment". Engine: hand-rolled (no matugen/wallust).
Layout: `.config/*` at repo root.

Relevant paths:
- hypr: `.config/hypr/hyprland.conf`, `.config/hypr/env.conf`, `.config/hypr/keybinds.conf`, `.config/hypr/startup.conf`, `.config/hypr/windowrule.conf`, `.config/hypr/scripts/` (colorpicker, screensht)
- waybar: `.config/waybar/config.jsonc`, `.config/waybar/style.css`, `.config/waybar/scripts/playerctl/`
- launcher: `.config/rofi/config.rasi`, `.config/rofi/rofi.rasi`, `.config/rofi/global/` (emoji.rasi, history.txt, icons)
- notifications: `.config/dunst/dunstrc`
- widgets: none
- lockscreen: `.config/swaylock/config` (no hyprlock)
- terminal: `.config/wezterm/` (lua/, colors/rose-pine.toml + variants)
- shell-prompt: `.config/starship/starship.toml`
- utilities: `.config/wlogout/layout`, `.config/wlogout/style.css`
- login-boot: none
- theming primitives: `.themes/` (GTK themes), `.wallpapers/` — no engine, hand-curated

Notes: Conservative single-theme rice (Rose Pine). Uses wezterm, swaylock (not hyprlock), and dunst (not swaync). Good reference for "minimal/quiet" aesthetic.

## 15. Axenide/Ax-Shell — 1.6k★
A hackable Fabric-based Hyprland shell. Engine: matugen.
This is a SHELL ONLY (Python/GTK via Fabric), but ships a small hypr/* config bundle.

Relevant paths:
- hypr: `config/hypr/hypridle.conf`, `config/hypr/hyprlock.conf` (only — main hyprland.conf is user-supplied via installer)
- waybar: none (replaced by Ax-Shell bar)
- launcher: `modules/launcher.py`
- notifications: `modules/notch.py`, services for notifs in `services/`
- widgets: `main.py`, `main.css`, `modules/` (bar.py, dock.py, dashboard.py, kanban.py, controls.py, calendar.py, emoji.py, cliphist.py, cavalcade.py, corners.py), `widgets/` (circle_image.py, image.py, shadertoy.py), `services/` (brightness.py, mpris.py, network.py, monitor_focus.py), `styles/`
- lockscreen: `config/hypr/hyprlock.conf` (uses hyprlock)
- terminal: none
- shell-prompt: none
- utilities: `modules/cliphist.py`, `modules/cavalcade.py` (cava visualizer)
- login-boot: none
- theming primitives: `config/matugen/templates/ax-shell.css`, `config/matugen/templates/hyprland-colors.conf`, `config/cavalcade/cava.ini`

Notes: Python+Fabric shell (alternative to AGS/Quickshell). Single shell file (`main.py`) with module imports. Installer in `install.sh`.

## 16. koeqaife/hyprland-material-you (HyprYou) — 1.5k★
Dynamic Material You desktop. Engine: hand-rolled Python color generation (matugen-style).
This is a SHELL + GREETER bundle (Python).

Relevant paths:
- hypr: `hypryou-assets/greeter/hyprland.conf` (greeter session only), `hypryou-assets/templates/colors-hyprland.conf` — main hypr config is user-supplied
- waybar: none (built-in bar in `hypryou/src/modules/bar.py`)
- launcher: `hypryou/src/modules/apps_menu.py`
- notifications: `hypryou/src/modules/notifications/`
- widgets: `hypryou/__start__.py`, `hypryou/hypryou_ui.py`, `hypryou/src/modules/` (apps_menu, audio, bar, bluetooth_pin, brightness, calendar, clients, cliphist, emojis, info, keybinds, lockscreen, notifications)
- lockscreen: `hypryou/src/modules/lockscreen.py` (in-shell lock)
- terminal: none
- shell-prompt: none
- utilities: `hypryou/src/modules/cliphist.py`
- login-boot: `greeter/` (full greetd-style greeter — PKGBUILD, config.toml, install script), `hypryou/greeter_ui.py`
- theming primitives: `hypryou-assets/templates/` (colors-hyprland.conf, colors.tdesktop-theme), `hypryou/utils/colors/` (cache.py, generation.py, helpers.py, schemes.py, templates.py — hand-rolled color generation pipeline)

Notes: Python application (not AGS/Fabric/Quickshell). Custom color generation engine instead of matugen. Ships its own greeter as a separate PKGBUILD under `greeter/`. Two PKGBUILDs.

## 17. binnewbs/arch-hyprland — 1.2k★
Personal Hyprland rice for Arch. Engine: matugen.
Layout: `.config/*` at repo root.

Relevant paths:
- hypr: `.config/hypr/hyprland.conf`, `.config/hypr/colors.conf`, `.config/hypr/configs/` (UserAnimations.conf, input.conf, keybinds.conf, looknfeel.conf, tags.conf, windowrules.conf), `.config/hypr/hypridle.conf`, `.config/hypr/hyprlock.conf`, `.config/hypr/scripts/`
- waybar: `.config/waybar/` (configs/), `.config/waybar/Modules/`, `.config/waybar/ModulesCustom/`, `.config/waybar/ModulesGroups/`, `.config/waybar/ModulesWorkspaces/`, `.config/waybar/colors.css`
- launcher: `.config/rofi/config.rasi`, `.config/rofi/colors.rasi`
- notifications: `.config/swaync/config.json`, `.config/swaync/style.css`, `.config/swaync/themes/control_center.css`
- widgets: none (waybar-based)
- lockscreen: `.config/hypr/hyprlock.conf`
- terminal: `.config/kitty/kitty.conf`, `.config/kitty/colors.conf`
- shell-prompt: none (`.zshrc` at root but no starship/p10k)
- utilities: `.config/wlogout/layout`, `.config/wlogout/style.css`, `.config/cava/`
- login-boot: none
- theming primitives: `.config/matugen/config.toml`, `.config/matugen/templates/` (colors.css, gtk-colors.css, hyprland-colors.conf, kitty-colors.conf, matugen-cava, midnight-discord.css, rofi-colors.rasi)

Notes: Heavily inspired by JaKooLit (Modules/ModulesCustom/ModulesGroups layout). Matugen-driven theming. `.zshrc` lives at repo root.

## 18. fufexan/dotfiles — 1.1k★
NixOS + Home-Manager configuration. Engine: hand-rolled (Nix-managed).
Layout: NixOS modules. Configs generated from `.nix` files at build time.

Relevant paths:
- hypr: `system/programs/hyprland/hyprland.lua`, `system/programs/hyprland/binds.lua`, `system/programs/hyprland/rules.lua`, `system/programs/hyprland/animations.lua`, `system/programs/hyprland/settings.lua`, `system/programs/hyprland/smartgaps.lua`, `system/programs/hyprland/variables.nix`, `hosts/io/hyprland.nix`
- waybar: none (uses quickshell bar)
- launcher: none in tree (likely vicinae per `home/programs/vicinae/`)
- notifications: none in tree (likely in quickshell)
- widgets: `home/services/quickshell/bar/` (Bar.qml + per-module: Battery.qml, Bluetooth.qml, Clock.qml, Comms.qml, Mpris.qml, Network.qml, Resources.qml, Workspaces.qml, Tray/), `home/services/quickshell/components/` (Button.qml, HoverTooltip.qml, IconButton.qml)
- lockscreen: `home/programs/wayland/hyprlock.nix`
- terminal: `home/terminal/emulators/` (likely kitty/foot/ghostty nix modules — explore further)
- shell-prompt: `home/terminal/shell/starship.nix`
- utilities: `home/programs/wayland/wlogout.nix`
- login-boot: `system/services/greetd.nix`
- theming primitives: none structured (relies on inline nix theming + bibata-hyprcursor in `pkgs/bibata-hyprcursor/`)

Notes: NixOS canonical reference for Hyprland. Same author wrote `home/services/quickshell/bar/*` from scratch — minimal Quickshell bar reference. Hypr config split between `system/programs/hyprland/*.lua` (compositor) and `home/services/wayland/` (services like hypridle, hyprpaper).

## 19. Matt-FTW/dotfiles — 748★
"Aesthetic Hyprland Config". Engine: hand-rolled (catppuccin-style).
Layout: `.config/*` at repo root.

Relevant paths:
- hypr: `.config/hypr/hyprland.conf`, `.config/hypr/configs/` (binds.conf, default_apps.conf, env.conf, input.conf, launcher.conf, misc.conf, monitors.conf, monitors_var.conf, plugins.conf, workspaces.conf), `.config/hypr/hypridle.conf`, `.config/hypr/hyprlock.conf`
- waybar: `.config/waybar/config.jsonc`, `.config/waybar/colors.css`, `.config/waybar/bars/` (bottom-bar.jsonc, top-bar.jsonc, vertical-bar.jsonc) — multi-bar setup
- launcher: `.config/rofi/config.rasi`, `.config/rofi/scripts/clipboard/`
- notifications: `.config/swaync/config.json`, `.config/swaync/style.css`
- widgets: none (waybar-based)
- lockscreen: `.config/hypr/hyprlock.conf`
- terminal: `.config/kitty/kitty.conf`, `.config/ghostty/config`
- shell-prompt: `.config/starship/`, `.config/fish/conf.d/starship.fish`, `.config/fish/conf.d/atuin.fish`
- utilities: none specific (cliphist via rofi script)
- login-boot: none
- theming primitives: `.config/nvim/lua/plugins/extras/ui/colorschemes/mini-base16.lua` (base16 in editor only — no compositor-wide theming engine)

Notes: Modular hypr config (`.config/hypr/configs/` split files). Multi-bar waybar setup as a pattern. Catppuccin-themed throughout, hand-applied.

---

## Quick cross-reference

By shell tech:
- Waybar: hyprdots, JaKooLit, dusky, linuxmobile, binnewbs, Matt-FTW
- Quickshell: end-4, caelestia-shell, noctalia, dank, fufexan, mylinuxforwork (apps), JaKooLit (newer)
- AGS: HyprPanel, JaKooLit (legacy)
- Fabric (Python): Ax-Shell
- Python+GTK: koeqaife/HyprYou
- ironbar: flickowoa

By theming engine:
- matugen: end-4, mylinuxforwork, dusky, HyprPanel, Ax-Shell, binnewbs, caelestia-shell (consumes), dank (orchestrates via Go)
- wallust: JaKooLit
- hand-rolled (wallbash/dcol): hyprdots
- hand-rolled (Python): koeqaife
- hand-rolled (JSON schemes): noctalia, caelestia, linuxmobile, Matt-FTW, flickowoa
- nix-managed: ryan4yin, fufexan

By config layout:
- `dots/.config/*`: end-4
- `dotfiles/.config/*`: mylinuxforwork
- `Configs/.config/*`: hyprdots (HyDE)
- `config/*` (no dot): JaKooLit, flickowoa, Ax-Shell, koeqaife, axshell
- `.config/*` at root: dusky, linuxmobile, binnewbs, Matt-FTW
- per-tool top-level (`hypr/`, `foot/`, `starship.toml`): caelestia
- repo-as-shell (`shell.qml`, `Modules/`): caelestia-shell, noctalia, dank, HyprPanel
- nix modules: ryan4yin, fufexan

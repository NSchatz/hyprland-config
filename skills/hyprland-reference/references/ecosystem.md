# Hyprland Ecosystem & Common Packages

Hyprland is a bare compositor — a usable desktop is assembled from companion packages. This
catalogs the official **Hypr ecosystem** tools plus the community packages most commonly paired
with Hyprland, by role, with the typical launch/autostart command and config notes.

Package availability (official repo vs AUR) drifts over time and differs by distro. Names below
are the Arch package names; confirm location with `pacman -Ss <name>` or your AUR helper.
Suggest a tool only as `exec-once`/keybind — do **not** install anything.

## Official Hypr ecosystem (hyprwm)

User-facing tools, all first-party and designed for Hyprland:

| Package              | Role                              | Launch / notes                                            |
|----------------------|-----------------------------------|-----------------------------------------------------------|
| `hyprpaper`          | Wallpaper daemon                  | `exec-once = hyprpaper`; config `~/.config/hypr/hyprpaper.conf` |
| `hyprlock`           | Screen locker (GPU)               | bind to `hyprlock`; config `~/.config/hypr/hyprlock.conf` (required or it errors) |
| `hypridle`           | Idle daemon                       | `exec-once = hypridle`; config `~/.config/hypr/hypridle.conf` |
| `hyprpicker`         | Color picker                      | bind to `hyprpicker -a` (`-a` copies to clipboard)        |
| `hyprshot`           | Screenshot wrapper                | bind to `hyprshot -m region`/`-m window`/`-m output`      |
| `hyprsunset`         | Blue-light / gamma filter         | `exec-once = hyprsunset -t 4000` or toggle via `hyprctl hyprsunset` |
| `hyprpolkitagent`    | Polkit auth agent (Qt/QML)        | `exec-once = systemctl --user start hyprpolkitagent` or `exec-once = /usr/lib/hyprpolkitagent/hyprpolkitagent` |
| `hyprcursor`         | Cursor theme format/lib           | set `HYPRCURSOR_THEME`/`HYPRCURSOR_SIZE`; falls back to XCursor |
| `hyprsysteminfo`     | System info dialog                | invoked by other tools                                    |
| `hyprlauncher`       | First-party app launcher/picker   | bind to `hyprlauncher` (newer, AUR)                       |
| `xdg-desktop-portal-hyprland` | Screen-share/portal backend | needed for screensharing; pair with `xdg-desktop-portal-gtk` for file pickers |
| `hyprland-qt-support`, `hyprqt6engine` | Qt theming integration | pulled in for consistent Qt look                          |

Libraries (not user-facing, listed for recognition): `hyprutils`, `hyprlang`, `hyprgraphics`,
`hyprwayland-scanner`, `aquamarine`, `hyprtoolkit`.

## Status bars

| Package      | Notes                                                                 |
|--------------|-----------------------------------------------------------------------|
| `waybar`     | Default recommendation; GTK bar for wlroots. `exec-once = waybar`. Config in `~/.config/waybar/`. |
| `hyprpanel`  | Batteries-included bar built on AGS (AUR). `exec-once = hyprpanel`.    |
| `ags`/astal  | Aylur's GTK Shell — scriptable widgets/bars (AUR: `aylurs-gtk-shell`). |
| `quickshell` | QML-based shell toolkit (AUR).                                         |
| `eww`        | ElKowar's wacky widgets — custom bars/widgets.                         |
| `nwg-panel`  | Python/GTK panel from the nwg-shell project.                          |

## App launchers / menus

| Package         | Launch command            | Notes                                  |
|-----------------|---------------------------|----------------------------------------|
| `wofi`          | `wofi --show drun`        | GTK, simple, common default.           |
| `rofi-wayland`  | `rofi -show drun`         | Powerful; `rofi-wayland` is the Wayland build (mainline `rofi` also gained Wayland support in 2025). |
| `fuzzel`        | `fuzzel`                  | Fast native Wayland launcher.          |
| `tofi`          | `tofi-drun \| xargs swaymsg exec` / `tofi-run` | Minimal, very fast.       |
| `anyrun`        | `anyrun`                  | Plugin-based (AUR).                     |
| `walker`        | `walker`                  | Modular runner (AUR).                   |
| `bemenu`        | `bemenu-run`              | dmenu-like, scriptable.                |
| `hyprlauncher`  | `hyprlauncher`            | First-party (AUR).                     |

## Notification daemons

| Package  | Notes                                                                        |
|----------|------------------------------------------------------------------------------|
| `mako`   | Lightweight, Wayland-native. `exec-once = mako`. Config `~/.config/mako/config`. |
| `dunst`  | Popular, very configurable. `exec-once = dunst`.                              |
| `swaync` | SwayNotificationCenter — has a notification center panel. `exec-once = swaync`. |

Many daemons start automatically via D-Bus activation; an explicit `exec-once` is still common.

## Wallpaper

| Package     | Notes                                                                      |
|-------------|----------------------------------------------------------------------------|
| `hyprpaper` | First-party; preloads images, low overhead. Config `hyprpaper.conf`.       |
| `swww`      | Animated transitions; daemon + `swww img`. `exec-once = swww-daemon`.       |
| `swaybg`    | Minimal static background.                                                  |
| `mpvpaper`  | Video wallpapers via mpv (AUR).                                             |

## Lock & idle

- `hyprlock` (lock) + `hypridle` (idle) are the ecosystem pair. See `hyprlock`/`hypridle`
  config formats below. `hypridle` calls `loginctl lock-session`, which triggers `hyprlock` via
  its `lock_cmd`. Alternatives: `swaylock`(-effects), `swayidle`, `gtklock`.

## Screenshots & recording

| Package        | Notes                                                              |
|----------------|--------------------------------------------------------------------|
| `grim`+`slurp` | Core capture (`grim`) + region select (`slurp`).                   |
| `grimblast`    | Convenient wrapper (from `hyprland-contrib`, AUR): `grimblast copy area`. |
| `hyprshot`     | First-party wrapper: `hyprshot -m region`.                         |
| `satty`        | Screenshot annotation UI; pipe a capture into it.                  |
| `swappy`       | Snapshot editing/annotation.                                       |
| `wf-recorder`  | Screen recording to file.                                          |
| `wl-screenrec` | GPU-accelerated recorder.                                          |

## Clipboard

| Package        | Notes                                                              |
|----------------|--------------------------------------------------------------------|
| `wl-clipboard` | Provides `wl-copy`/`wl-paste` — required by most clipboard flows.  |
| `cliphist`     | Clipboard history: `exec-once = wl-paste --watch cliphist store`; query via a launcher. |
| `clipse`       | TUI clipboard manager (AUR).                                       |

## Logout / session, OSD, misc

| Package        | Role / notes                                                       |
|----------------|--------------------------------------------------------------------|
| `wlogout`      | Graphical logout/power menu: bind to `wlogout`.                    |
| `hyprshutdown` | First-party shutdown menu.                                         |
| `swayosd`      | On-screen volume/brightness/caps OSD (`swayosd-server` + client).  |
| `avizo`        | Alternative OSD daemon.                                            |
| `wlsunset`/`gammastep` | Blue-light alternatives to `hyprsunset`.                  |

## Audio, brightness, network, bluetooth

| Package                  | Role                                                    |
|--------------------------|---------------------------------------------------------|
| `pipewire`+`wireplumber`+`pipewire-pulse` | Audio server stack (also needed for screen-share audio). |
| `pavucontrol`            | GUI audio mixer.                                        |
| `pamixer` / `wpctl`      | CLI volume (`wpctl` ships with wireplumber).           |
| `playerctl`              | Media key control (`playerctl play-pause/next/prev`).  |
| `brightnessctl`          | Backlight control.                                      |
| `network-manager-applet` | `nm-applet --indicator` tray; needs NetworkManager.    |
| `blueman`                | Bluetooth manager (`blueman-applet`).                  |

## Theming (GTK/Qt consistency)

| Package        | Role                                                              |
|----------------|--------------------------------------------------------------------|
| `nwg-look`     | GTK theme/icon/cursor/font settings GUI.                          |
| `qt5ct`/`qt6ct`| Qt appearance config (`env = QT_QPA_PLATFORMTHEME,qt6ct`).         |
| `kvantum`      | Qt SVG theme engine.                                              |
| `hyprland-qt-support`/`hyprqt6engine` | First-party Qt integration for hypr tools. |

## Portals (screen sharing & file pickers)

Screen sharing and native file pickers need an xdg-desktop-portal backend:

- `xdg-desktop-portal-hyprland` — the Hyprland backend (screencast/screenshot).
- `xdg-desktop-portal-gtk` — provides file-chooser and settings portals; pair it with the
  Hyprland one.
- Ensure `XDG_CURRENT_DESKTOP=Hyprland` is in the session env so portals pick the right backend.

---

## hypridle config format

Default path: `~/.config/hypr/hypridle.conf`. The `general` block defines lock/sleep hooks;
each `listener` block is one idle timer (seconds).

```ini
general {
    lock_cmd = pidof hyprlock || hyprlock       # avoid spawning multiple instances
    before_sleep_cmd = loginctl lock-session    # lock before suspend
    after_sleep_cmd = hyprctl dispatch dpms on  # wake displays on resume
    inhibit_sleep = 3
}

listener {                       # dim/lower brightness first
    timeout = 150
    on-timeout = brightnessctl -s set 10%
    on-resume = brightnessctl -r
}

listener {                       # lock the screen
    timeout = 300
    on-timeout = loginctl lock-session
}

listener {                       # turn off displays
    timeout = 360
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}

listener {                       # suspend
    timeout = 1800
    on-timeout = systemctl suspend
}
```

## hyprlock config format

Default path: `~/.config/hypr/hyprlock.conf`. **Required** — hyprlock errors out if missing,
leaving the session unlocked. Minimal example:

```ini
background {
    monitor =
    path = screenshot          # or an image path; 'screenshot' blurs the current screen
    blur_passes = 2
    blur_size = 7
}

input-field {
    monitor =
    size = 250, 50
    outline_thickness = 2
    dots_center = true
    outer_color = rgb(33ccff)
    inner_color = rgb(1a1a1a)
    font_color = rgb(200, 200, 200)
    placeholder_text = <i>Password...</i>
    fade_on_empty = true
    position = 0, -40
    halign = center
    valign = center
}

label {
    monitor =
    text = $TIME                # also $TIME12, cmd[update:1000]<...> for live data
    font_size = 64
    font_family = Noto Sans
    position = 0, 80
    halign = center
    valign = center
}
```

## hyprpaper config format

Default path: `~/.config/hypr/hyprpaper.conf`.

```ini
preload = ~/.config/hypr/wall.png
wallpaper = , ~/.config/hypr/wall.png    # empty monitor = all monitors
splash = false
```

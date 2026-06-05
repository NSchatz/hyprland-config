# autostart — packages

Packages the autostart picks need. The installer agent reads this file when assembling the global
`PKGS` list. The **bar** package (`waybar` / `eww` / `quickshell` / …) lives in
[`../waybar/packages.md`](../waybar/packages.md); the **notification daemon** package (`mako` /
`dunst` / `swaync`) lives in [`../notifications/packages.md`](../notifications/packages.md). This
component only owns the services it gates directly.

## Map

### Wallpaper daemon
| Pick | Package | Repo / AUR | Notes |
|---|---|---|---|
| hyprpaper | `hyprpaper` | repo | First-party Hypr ecosystem. Static wallpapers only. |
| swww (pre-rename, Arch repo) | `swww` | repo | Animated transitions. Binary: `swww-daemon`. |
| awww (post-rename, codeberg.org/LGFae/awww) | `awww-git` | AUR | Same project, renamed by upstream. Binary: `awww-daemon`. May declare `provides=swww` for back-compat — pick by `SWWW_DAEMON_BIN`, not by both. |
| none | — | — | No `exec-once` wallpaper line emitted. |

### Polkit agent
| Pick | Package | Repo / AUR | Notes |
|---|---|---|---|
| hyprpolkitagent | `hyprpolkitagent` | repo | First-party Hypr ecosystem. Started via systemd user unit. |
| polkit-gnome | `polkit-gnome` | repo | Binary at `/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1`. |
| polkit-kde | `polkit-kde-agent` | repo | Binary at `/usr/lib/polkit-kde-authentication-agent-1`. Pulls a Qt runtime. |
| none | — | — | No agent — `pkexec` prompts silently fail. |

### Always-on services (from `autostart_env.autostart`)
| Token | Package(s) | Repo / AUR | Notes |
|---|---|---|---|
| `cliphist-text` | `wl-clipboard` `cliphist` | repo | `wl-clipboard` provides `wl-paste`; `cliphist` is the store. |
| `cliphist-image` | `wl-clipboard` `cliphist` | repo | Same packages — de-dupe at install time. |
| `nm-applet` | `network-manager-applet` | repo | Tray icon for `NetworkManager`. Also pulls `nm-connection-editor`. |
| `blueman` | `blueman` `bluez-utils` | repo | Tray applet + `bluetoothctl`. |
| `hypridle` | `hypridle` | repo | First-party Hypr ecosystem. Idle daemon. Config lives in `../companion-daemons/`. |
| `hyprsunset` | `hyprsunset` | repo | First-party Hypr ecosystem. Blue-light filter. |
| `swayosd` | `swayosd` | AUR | Volume/brightness OSD server. |

### Portal stack (always added when this component is walked)
| Tool | Package | Repo / AUR | Notes |
|---|---|---|---|
| Hyprland portal | `xdg-desktop-portal-hyprland` | repo | Required for screen sharing under Hyprland. |
| GTK portal | `xdg-desktop-portal-gtk` | repo | File-chooser fallback; standard pairing. |

The portal-env propagation `exec-once` lines depend only on `dbus-update-activation-environment`
(from `dbus`) and `systemctl --user` (from `systemd`) — both are baseline, so they don't add
anything to `PKGS`.

## First-party Hypr ecosystem picks

Marked above where they apply. The interviewer presents these as the first-listed default for
their slot (`hyprpaper`, `hyprpolkitagent`, `hypridle`, `hyprsunset`). Picking the first-party
option keeps the install lean and means upstream Hyprland tracks the daemon's compatibility.

## Assembly rule

```bash
# wallpaper
case "$(jq -r .autostart_env.wallpaper_tool answers.json)" in
  hyprpaper) pkgs+=(hyprpaper) ;;
  swww)      [ "$SWWW_DAEMON_BIN" = awww-daemon ] && pkgs+=(awww-git) || pkgs+=(swww) ;;
esac

# polkit
case "$(jq -r .autostart_env.polkit answers.json)" in
  hyprpolkitagent) pkgs+=(hyprpolkitagent) ;;
  polkit-gnome)    pkgs+=(polkit-gnome) ;;
  polkit-kde)      pkgs+=(polkit-kde-agent) ;;
esac

# services
for tok in $(jq -r '.autostart_env.autostart[]' answers.json); do
  case "$tok" in
    cliphist-text|cliphist-image) pkgs+=(wl-clipboard cliphist) ;;
    nm-applet)  pkgs+=(network-manager-applet) ;;
    blueman)    pkgs+=(blueman bluez-utils) ;;
    hypridle)   pkgs+=(hypridle) ;;
    hyprsunset) pkgs+=(hyprsunset) ;;
    swayosd)    pkgs+=(swayosd) ;;
  esac
done

# portals (always)
pkgs+=(xdg-desktop-portal-hyprland xdg-desktop-portal-gtk)
```

De-duplication happens at install time via `pacman --needed`.

## Cross-references

- Bar package (waybar / eww / quickshell / hyprpanel / …) → `../waybar/packages.md`.
- Notification daemon package (mako / dunst / swaync) → `../notifications/packages.md`.
- Companion config files (hypridle ladder, hyprpaper preload paths) → `../companion-daemons/`.
- Env-var half of group 15 (cursor, Qt, NVIDIA, `XDG_CURRENT_DESKTOP`) → `../env/`.

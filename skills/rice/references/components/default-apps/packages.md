# default-apps — packages

The browser and file-manager picks each map to one canonical Arch/AUR package. The installer agent
reads this file when assembling the global `PKGS` list.

## Map

### Browsers
| Pick | Package | Repo / AUR |
|---|---|---|
| firefox | `firefox` | repo (extra). Wayland is the **default backend since 121.0 (Dec 2023)** — no env var needed; see `gotchas.md`. |
| chromium | `chromium` | repo (extra). Needs `--ozone-platform-hint=auto` for native Wayland; `ELECTRON_OZONE_PLATFORM_HINT=auto` (set by `env`) is the env-var equivalent picked up by Chromium 95+ and all Electron apps. |
| brave | `brave-bin` | AUR (not in the official repos; verified at <https://archlinux.org/packages/?q=brave> — only `python-adblock` matches, no `brave`/`brave-browser`). Same `--ozone-platform-hint=auto` story as Chromium. |
| qutebrowser | `qutebrowser` | repo (extra). Built on QtWebEngine; supports both Qt5 and Qt6. Native Wayland runs via `QT_QPA_PLATFORM=wayland;xcb` (set by `env`'s toolkit block) — falls back to XWayland if Wayland session not detected. |

### File managers
| Pick | Package | Repo / AUR |
|---|---|---|
| nautilus | `nautilus` | repo (extra) — pulls `gtk4`, `libadwaita`, `gnome-desktop-4`, `gvfs`, `localsearch` (~38 deps); works standalone on Hyprland |
| thunar | `thunar` | repo (extra). Recommended companions (all repo/extra): `thunar-volman` (auto-mount removable media), `thunar-archive-plugin` (right-click archive ops), `tumbler` (thumbnails — required for previews), `gvfs` (trash + remote filesystems), `gvfs-smb` (Samba shares). |
| dolphin | `dolphin` | repo (extra) — **heavy**: ~33 hard deps across Qt6 + KDE Frameworks (`kio`, `kconfig`, `kxmlgui`, `solid`, `baloo`, …). Optional: `konsole` (embedded terminal panel), `kdegraphics-thumbnailers` (PDF/PS previews), `kio-admin` (root file ops). |
| nemo | `nemo` | repo (extra) |
| pcmanfm | `pcmanfm` | repo (extra) — GTK3 version. The Qt port is `pcmanfm-qt` (different package). There is **no** `pcmanfm-gtk3` package. |
| yazi (TUI) | `yazi` | repo (extra) |
| ranger (TUI) | `ranger` | repo (extra) |

Sources: <https://archlinux.org/packages/extra/x86_64/nautilus/>,
<https://archlinux.org/packages/extra/x86_64/dolphin/>,
<https://archlinux.org/packages/?q=pcmanfm>,
<https://archlinux.org/packages/?q=thunar>.

## Assembly rule

```bash
pkgs+=("$(jq -r .default_apps.browser answers.json | map-to-package)")
files=$(jq -r '.default_apps.files // empty' answers.json)
[ -n "$files" ] && pkgs+=("$(map-to-package "$files")")
```

The repo/AUR column is informational — `install.sh` auto-routes each name at runtime via
`pacman -Si`, so a package that drifts between repos doesn't break the install.

## Cross-references

- Script shape and global assembly rule → `theming/engine.md` is unrelated; the install-script
  shape lives in `skills/rice/scripts/` (the rice-init scaffold) and the installer agent's prompt.
- Other components' package maps live in `components/<x>/packages.md`.

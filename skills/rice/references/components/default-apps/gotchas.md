# default-apps — gotchas

## Firefox + Wayland: `MOZ_ENABLE_WAYLAND=1` is a no-op on 121+

Firefox shipped Wayland-by-default in **121.0 (December 2023)**. The variable is still respected
(`=0` forces X11/XWayland) but `=1` is the current default and has **no effect** on any modern
Firefox. The `env` component still emits `env = MOZ_ENABLE_WAYLAND,1` when the user picks
Firefox — kept as an opt-in marker and a safety net for older Firefox builds — but do **not**
present it in the interview as "required for Wayland Firefox". See
[`../env/gotchas.md`](../env/gotchas.md) for the canonical phrasing.

If Firefox falls back to XWayland on a current build, the cause is upstream of this var (no
`WAYLAND_DISPLAY`, `XDG_SESSION_TYPE=x11`, or the binary was built without Wayland support);
toggling `MOZ_ENABLE_WAYLAND` will not fix it.

## Omit `$fileManager` when not chosen

If `default_apps.files` is `null` (user opted for a TUI launched in-line or none), **do not write**
`$fileManager =` to `hyprland.conf`, and **do not emit** the `bind = $mainMod, E, exec,
$fileManager` line in `binds.conf`. Leaving a `$fileManager =` empty makes the bind a no-op
(`exec` of an empty command).

## Chromium / Brave / Electron apps on Wayland

Chromium and Brave need `--ozone-platform-hint=auto` to use native Wayland (the older
`--enable-features=UseOzonePlatform --ozone-platform=wayland` pair still works but is the
pre-Chromium-95 spelling). The `env` component emits `env = ELECTRON_OZONE_PLATFORM_HINT,auto`,
which Chromium 95+ and every Electron app pick up automatically — no per-launcher flag needed.
Safe across all GPUs; the `env` component already emits it as part of its NVIDIA / generic
toolkit block.

## TUI "file managers" (yazi, ranger) — write `null`, don't pass the TUI through

`$fileManager = yazi` then `bind = $mainMod, E, exec, $fileManager` runs `yazi` as a **bare
process** with no controlling terminal — it exits immediately. TUI picks must either:

1. **(Preferred)** be recorded as `default_apps.files = null` in `answers.json`, and the user's
   TUI keybind is added under `keybinds` as `bind = $mainMod, E, exec, $terminal -e yazi`
   (interview's TUI branch should set this). The current schema lists `yazi` / `ranger` as
   valid `files` strings, but the writer **must** detect them and wrap as `$terminal -e <tui>`
   rather than emitting `$fileManager = yazi`.
2. **(Alternate)** the writer rewrites `$fileManager = $terminal -e yazi` so the bind expansion
   becomes `exec, $terminal -e yazi`. Cheaper but couples the variable to the terminal pick.

The current keybinds template (`../keybinds/template.md`) only gates on `default_apps.files !=
null`; it does **not** wrap TUI strings. Either fix the writer (recommended: option 1, record
`null` when a TUI is chosen) or update keybinds to wrap. **Cross-component flag.**

## Dolphin pulls a large KDE/Qt6 tree

`dolphin` has ~33 hard dependencies across Qt6 and KDE Frameworks (`kio`, `kconfig`, `kxmlgui`,
`solid`, `baloo`, …). On a non-KDE host that's tens of MB of new packages and a Baloo file
indexer running in the background. Warn in the interview if the user picks Dolphin on a system
without any other KDE app. (See `packages.md` for the full dep callout.)

## Nautilus is modular but still GNOMEy

`nautilus` has 38 deps including `libadwaita`, `gnome-desktop-4`, `localsearch` (tracker file
indexer), `xdg-user-dirs-gtk`, and the full GVFS stack. It runs standalone on Hyprland — does
not require a GNOME session — but it will start the `localsearch` indexer the first time it
opens. Lighter alternatives on Hyprland: `thunar` (Xfce, GTK3) or `pcmanfm` (LXDE, GTK3).

## Setting the chosen browser as the system default (programmatic)

`xdg-mime` is the cross-DE way to wire the chosen browser into `xdg-open` for HTTP, HTTPS, and
HTML files. The desktop-file id is the basename of the `.desktop` file (e.g. `firefox.desktop`,
`chromium.desktop`, `brave-browser.desktop`, `org.qutebrowser.qutebrowser.desktop`). Per
`man xdg-mime`:

```bash
xdg-mime default firefox.desktop x-scheme-handler/http x-scheme-handler/https
xdg-mime default firefox.desktop text/html
# verify:
xdg-mime query default x-scheme-handler/http
```

The application must be installed (the `.desktop` file must exist under
`/usr/share/applications/` or `~/.local/share/applications/`) **before** the command is run.
This belongs in the post-install hook, not in `hyprland.conf`. (Source:
<https://man.archlinux.org/man/xdg-mime.1>.)

## Default-app picks land in the install batch

The selected browser and file manager are both installable packages — even if the user picks a
non-default. See `packages.md` for the map; the installer agent reads it.

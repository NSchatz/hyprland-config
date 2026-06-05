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

## Corpus survey — are default-apps picks theming-driven?

Researched 2026-06-05 against the top ~15 rices in `/workspace/.research/corpus.md`. The headline
finding: **for waybar-based rices the browser/file-manager picks are NOT theming-driven** — they
are set as `$browser` / `$fileManager` / `$file` / `$files` variables wired to keybinds and the
chosen apps either inherit GTK/Qt theme by ricochet (Thunar, Nautilus, Nemo via `gtk3.dcol` /
`gtk-colors.css`; Dolphin via Kvantum) or aren't themed at all (Firefox without the userChrome
hack). **For Quickshell-based "shells" (dank, noctalia) the picks ARE theming-driven** because
those shells ship a matugen template per chosen app.

### Variable names and picks across the corpus

| Rice | `$browser` | `$fileManager`/`$file`/`$files` | `$terminal` | Notes |
|---|---|---|---|---|
| HyDE (`hyprdots`) | `firefox` | `dolphin` (var: `$file`) | `kitty` | `$editor = code`; bind `SUPER+F` (not `B`) opens browser, `SUPER+E` files. |
| ML4W | (settings script) | (settings script) | (settings script) | `~/.config/ml4w/settings/{browser,filemanager,terminal}.sh` shell-out indirection — defaults `firefox`/`nautilus --new-window`/`kitty`. Lets the user swap without editing hypr. |
| JaKooLit | (none) | `thunar` (var: `$files`) | `kitty` (var: `$term`) | No `$browser` variable at all. |
| Matt-FTW | `zen-browser` | `$terminal yazi` (var: `$file-manager`) | `ghostty --gtk-single-instance=true` | Primary file-manager = yazi-in-ghostty; `$alter-file-manager = nemo` as fallback. Also `$editor = $terminal nvim`, `$alter-editor = vscodium`. |
| binnewbs | (`xdg-open "https://"` bind) | `nautilus` | `kitty` | No `$browser` var — `bind = $mainMod, B, exec, xdg-open "https://"` delegates to the `x-scheme-handler/http` xdg-mime handler. |
| dusky | `firefox` | `nemo` | `foot` | All execs wrapped in `uwsm-app --` so the spawned app inherits the systemd user manager env (XDG_*, GTK_THEME, etc.). |
| caelestia | `zen-browser` | `thunar` (var: `$fileExplorer`) | `foot` | `$editor = codium`. |
| linuxmobile | `brave` | `thunar` (var: `$files`) | `wezterm` (var: `$term`) | Defines `$browser` but **does not bind any key to it** — variable is documentation/scripts-only. |
| flickowoa | (none) | `nautilus` (hardcoded in bind) | `footclient` (var: `$TERM`) | No var indirection for file manager — `bind=$MOD1,E,exec,nautilus` literal. |
| end-4 | `launch_first_available.sh 'google-chrome-stable' 'zen-browser' 'firefox' 'brave' 'chromium' 'microsoft-edge-stable' 'opera' 'librewolf'` | same script with `'dolphin' 'nautilus' 'nemo' 'thunar' 'kitty -1 fish -c yazi'` fallback chain | same script with `'foot' 'kitty -1' 'alacritty' 'wezterm' 'konsole' 'kgx' 'uxterm' 'xterm'` | Variable values are **fallback-chain shell scripts**, not single binaries. README comment: *"PULL REQUESTS ADDING MORE WILL NOT BE ACCEPTED, CONFIG FOR YOURSELF."* End-4 also defines `codeEditor`, `officeSoftware`, `textEditor`, `volumeMixer`, `settingsApp`, `taskManager` the same way. |
| dank (DMS) | (shell-owned) | (shell-owned) | (shell-owned) | Ships matugen configs for `firefox.toml` + `zenbrowser.toml` + `alacritty/foot/ghostty/kitty/wezterm.toml` + `vesktop/vencord/equibop.toml` + `emacs/zed/neovim.toml` — i.e. picks ARE bound to which apps the shell can re-color. |
| noctalia | (shell-owned) | (shell-owned) | (shell-owned) | Ships `Assets/Templates/{pywalfox.json, zen-browser/, yazi.toml, spicetify.ini, code.json, discord-material.css, ...}` — same theming-driven pick pattern. Even `yazi.toml` is generated, so a TUI file manager is themed. |
| fufexan | (none) | (none) | `foot` (bare in bind) | NixOS — no `$browser`/`$fileManager` indirection at all; binds spawn `foot` directly. |

### Patterns to consider for the recipe

1. **`launch_first_available` fallback-chain script (end-4):** instead of one binary the var is
   `~/.../launch_first_available.sh 'binA' 'binB' 'binC'`. Survives the user uninstalling the
   first pick. Out of scope for our recipe — the rice skill records a single string per pick —
   but worth noting in the gotchas as an upstream idiom.
2. **Indirection script (ML4W):** the bind execs a shell script that `cat`s a one-line file the
   user can edit (`~/.config/ml4w/settings/browser.sh`). Lets the user swap without re-running
   `rice apply`. Out of scope for the same reason.
3. **`uwsm-app --` wrapping (dusky):** every `exec` is `uwsm-app -- <real-cmd>` so the spawned
   app ends up in the systemd user manager scope, picking up XDG_* and GTK_THEME from the
   propagated env. Real benefit when the user uses UWSM as their session manager. Currently the
   `keybinds` recipe spawns bare commands — flag for `keybinds` if we ever add a UWSM profile.
4. **`xdg-open "https://"` delegation (binnewbs):** lets the bind survive a browser swap because
   `xdg-mime`'s `x-scheme-handler/http` handler is what actually picks the binary. Already
   covered in our gotchas under "Setting the chosen browser as the system default".
5. **No `$browser` bind at all (JaKooLit, fufexan, flickowoa):** at least three top rices don't
   bind `SUPER+B` to a browser. Our recipe binds it via `keybinds/template.md`; that's fine but
   not universal — don't claim it's standard.

### Cross-surface coherence findings

- **GTK theming covers thunar / nautilus / nemo / pcmanfm**, so once `theming/gtk-qt.md`'s
  `gtk-3.0` and `gtk-4.0` matugen targets are wired, those file managers re-theme on `rice
  apply` without any default-apps-component change. (HyDE: `Wall-Dcol/gtk{3,4}.dcol`; ML4W:
  `matugen/templates/gtk-colors.css`; end-4: `matugen/templates/gtk-{3,4}.0/`.)
- **Kvantum themes Dolphin** (and any Qt6 app under `QT_STYLE_OVERRIDE=kvantum`). HyDE ships
  `Wall-Dcol/kvantum/{kvantum,kvconfig}.dcol`; end-4 ships `matugen/templates/qt6ct/`. Picking
  Dolphin without theming Kvantum leaves it Breeze-default.
- **Firefox userChrome / pywalfox is needed** to actually re-color Firefox chrome. The default
  Firefox binary is theme-agnostic — picking firefox does not auto-theme it. Dank and noctalia
  both ship a userChrome template; HyDE / ML4W / JaKooLit / dusky do NOT theme Firefox. If a
  user picks Firefox expecting it to match the rest of the desktop, set expectations: only the
  surrounding chrome (waybar / wallpaper) re-colors, the browser stays default unless a
  userChrome/pywalfox add-on is layered on top (out of scope for v0.13).
- **TUI file managers (yazi, ranger) CAN be themed** — noctalia ships `yazi.toml`. If we ever
  add a TUI branch, `components/terminal/yazi.tmpl` would be the right home (not here).

### Bottom line

The default-apps component is **mostly structural with one theming-by-ricochet angle: GTK and
Kvantum**. The browser pick is not theming-driven for waybar rices. We surface this in the
interview as a heads-up (Dolphin → Kvantum dep; nautilus → GTK4/libadwaita; firefox →
chrome-not-themed) and let the user pick on workflow grounds, not palette grounds. No interview
sub-question is added — picking by palette would force the user to pick file manager AFTER
picking the engine, and the corpus does not show any rice that gates the pick on theming
capability.

Sources: end-4 `dots/.config/hypr/hyprland/variables.lua`; HyDE
`Configs/.config/hypr/keybindings.conf`; ML4W
`dotfiles/.config/ml4w/settings/{browser,terminal,filemanager}.sh`; JaKooLit
`config/hypr/UserConfigs/01-UserDefaults.conf`; Matt-FTW
`.config/hypr/configs/default_apps.conf`; binnewbs `.config/hypr/configs/keybinds.conf`; dusky
`.config/hypr/hyprland.conf`; caelestia `hypr/variables.conf`; linuxmobile
`.config/hypr/keybinds.conf`; flickowoa `config/hypr/land/{defaults,binds}.conf`; fufexan
`system/programs/hyprland/binds.lua`; dank `quickshell/matugen/configs/*.toml` + `templates/*`;
noctalia `Assets/Templates/{pywalfox.json,zen-browser/,yazi.toml,code.json,...}`.

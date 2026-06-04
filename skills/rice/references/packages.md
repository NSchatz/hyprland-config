# Package install script (`install.sh`)

A from-scratch build (Mode A) ends up choosing many tools across the 23 interview groups — a terminal,
a bar, a launcher, a notification daemon, fonts, a palette generator, utility tools, a shell/prompt,
maybe a widget shell or plugins. The skill **never installs** any of them (Safety rules), but it
*does* hand the user a single reviewable artifact that installs exactly what their picks need: a
generated **`install.sh`**. This file is the selection→package map plus the script's shape and the
rule for assembling it.

The target is **Arch + AUR** (the Hyprland ecosystem is overwhelmingly Arch/AUR-centric). The script
is self-contained: it detects an AUR helper (`paru`/`yay`), splits **repo** vs **AUR** packages, and
falls back to listing names on non-pacman systems. It installs the **full set the selections imply**,
made idempotent with `--needed` — already-present packages are skipped, nothing is reinstalled or
upgraded, so it's safe to re-run after a fresh install or to keep in a dotfiles repo.

## How to assemble it

1. After the interview (A1) and detection (`detect-version.sh` / `detect-theme-tools.sh`), walk the
   user's actual selections group by group and collect each chosen tool's package(s) from the map
   below into two lists: **`REPO`** (official `extra`/`core`) and **`AUR`**.
2. Use the *real* binary the user has where it matters — e.g. the wallpaper daemon is `swww` *or* the
   `awww` fork (`SWWW_DAEMON_BIN`); don't list both.
3. De-duplicate (shared deps like `wl-clipboard`, `slurp`, `jq` recur across utility scripts).
4. Drop nothing for being already installed — `--needed` handles that. **Do** annotate already-present
   packages with a trailing `# installed` comment (from the `HAVE_*` flags) so the user sees the script
   is mostly a no-op for them.
5. Group-23 **hyprpm plugins** are *not* package-manager installable — emit them in the separate
   hyprpm section (see below), and add the build toolchain (`base-devel cmake meson cpio`) to `REPO`.
6. Stage it at `<staging>/install.sh` so it installs to `~/.config/hypr/install.sh` and travels with
   the config + its backup (and version-controls with the dotfiles skill). `chmod +x` it.

## The map — selection → package (repo vs AUR)

Repo = official `core`/`extra` (`pacman -S`). AUR = needs a helper. "either" notes packages that have
moved between repos across releases — prefer repo, fall back to AUR. Names are the canonical Arch
package, not the binary/font family.

### Compositor & portals (baseline — list these for every generated config)
| Tool | repo | AUR | note |
|---|---|---|---|
| Hyprland | `hyprland` | | already running; `--needed` skips it |
| screen-share portal | `xdg-desktop-portal-hyprland` `xdg-desktop-portal-gtk` | | needed for screen sharing |
| Wayland Qt | `qt5-wayland` `qt6-wayland` | | common toolkit deps |
| polkit agent | `hyprpolkitagent` | | auth prompts (group 15) |

### Companion daemons (groups 14–16)
| Tool | repo | AUR | note |
|---|---|---|---|
| lock | `hyprlock` | | |
| idle | `hypridle` | | |
| wallpaper (hyprpaper) | `hyprpaper` | | static only |
| wallpaper (swww) | `swww` | | or the `awww` fork below — pick by `SWWW_DAEMON_BIN` |
| wallpaper (awww fork) | | `awww` | declares `provides=swww` |
| color picker | `hyprpicker` | | |
| night light | `hyprsunset` | | |
| screenshot (hyprshot) | `hyprshot` | | |

### Terminal (group 5)
| | repo | AUR |
|---|---|---|
| kitty | `kitty` | |
| alacritty | `alacritty` | |
| foot | `foot` | |
| wezterm | `wezterm` | |
| ghostty | `ghostty` | (either) |

### Bar / widgets (groups 6–7)
| | repo | AUR | note |
|---|---|---|---|
| waybar | `waybar` | | |
| eww | | `eww` | GTK widget toolkit |
| AGS / Astal | | `aylurs-gtk-shell` | the `ags` CLI |
| Quickshell | | `quickshell` | heavy build — may leave to the user |
| HyprPanel | | `hyprpanel` | Material-You, matugen-driven |

### Launcher (group 8)
| | repo | AUR | note |
|---|---|---|---|
| wofi | `wofi` | | |
| rofi | `rofi` | | `rofi-wayland` (AUR) for wayland-native |
| fuzzel | `fuzzel` | | |
| tofi | | `tofi` | |
| walker | | `walker-bin` | 2025 launcher |
| vicinae | | `vicinae` | 2025 launcher |
| anyrun | | `anyrun` | |

### Notifications (group 9)
| | repo | AUR |
|---|---|---|
| mako | `mako` | |
| dunst | `dunst` | |
| swaync | `swaync` | (either) |

### Palette generators (group 12)
| | repo | AUR | note |
|---|---|---|---|
| matugen | | `matugen-bin` | Material-You, recommended |
| wallust | | `wallust` | true 16-color |
| pywal16 | | `python-pywal16` | maintained pywal fork |

### Fonts (group 13) — only the chosen families + the universal fallbacks
| Family | repo | AUR |
|---|---|---|
| JetBrainsMono Nerd Font | `ttf-jetbrains-mono-nerd` | |
| FiraCode Nerd Font | `ttf-firacode-nerd` | |
| CaskaydiaCove (Cascadia) Nerd | `ttf-cascadia-code-nerd` | |
| Hack Nerd Font | `ttf-hack-nerd` | |
| Iosevka Nerd Font | `ttf-iosevka-nerd` | |
| Maple Mono NF | | `ttf-maple-font` |
| Inter | `inter-font` | |
| Cantarell | `cantarell-fonts` | |
| Noto Sans | `noto-fonts` | |
| Lexend | `ttf-lexend` | |
| symbol fallback | `ttf-nerd-fonts-symbols` `ttf-nerd-fonts-symbols-mono` | |
| waybar icons | `otf-font-awesome` | |
| emoji | `noto-fonts-emoji` | |

Always add `noto-fonts-emoji` and a Nerd symbol fallback when `MISSING_NERD_FONT` — glyphs otherwise
render as tofu boxes.

### Utilities & menus (group 18) — only the scripts/tools the user enabled
| Need | repo | AUR | note |
|---|---|---|---|
| screenshot | `grim` `slurp` `jq` | `grimblast` | `grimblast` optional; bare grim+slurp works |
| screenshot annotate | `swappy` | `satty` | one of |
| screen record | `wf-recorder` | `wl-screenrec` | `wl-screenrec` HW-accelerated |
| OCR | `tesseract` `tesseract-data-eng` | | add `tesseract-data-<lang>` per language |
| clipboard | `wl-clipboard` `cliphist` | | watchers run from autostart (group 15) |
| emoji picker | | `bemoji` | |
| calculator | | `rofi-calc` | or the launcher's math plugin |
| logout grid | | `wlogout` | |
| brightness/media | `brightnessctl` `playerctl` | | |
| OSD | | `swayosd` | volume/brightness OSD |
| Wi-Fi tray | `network-manager-applet` | | `nm-connection-editor` for the editor |
| Bluetooth tray | `blueman` `bluez-utils` | | |
| audio mixer | `pavucontrol` | | waybar audio on-click |

### Shell & prompt (group 17)
| | repo | AUR | note |
|---|---|---|---|
| zsh / fish / bash | `zsh` `fish` `bash` | | only the chosen shell |
| starship | `starship` | | default prompt |
| oh-my-posh | | `oh-my-posh-bin` | |
| fastfetch | `fastfetch` | | default fetch |
| neofetch | `neofetch` | | deprecated; only if chosen |
| modern CLI | `eza` `bat` `zoxide` `fzf` `atuin` | | only the ones the managed block uses |
| fisher | | | fish plugin manager — `curl` install, NOT a package; print its one-liner instead |

### Login & boot (group 19) — root-side; note `sudo`, don't fold into the user install
| | repo | AUR | note |
|---|---|---|---|
| greetd | `greetd` | | |
| tuigreet | `greetd-tuigreet` | (either) | |
| ReGreet | | `greetd-regreet` | runs under `cage` |
| SDDM | `sddm` | | Qt — pulls Qt runtime |
| Plymouth | `plymouth` | | |

These install to the system, not the user's config — keep them in a clearly-labelled **commented**
block the user runs with `sudo`, never in the main `pacman`/AUR arrays.

### Laptop / power (group 21)
| | repo | AUR |
|---|---|---|
| power-profiles-daemon | `power-profiles-daemon` | |
| TLP | `tlp` | |
| auto-cpufreq | | `auto-cpufreq` |
| monitor profiles (kanshi) | `kanshi` | |
| monitor profiles (shikane) | | `shikane` |

### Plugins (group 23) — hyprpm, built from source, NOT the package manager
Add the build toolchain to `REPO`: `base-devel cmake meson cpio`. The plugins themselves
(`hyprexpo`, `hyprscrolling`, `hy3`, `split-monitor-workspaces`, `hyprbars`, …) are added/enabled via
`hyprpm` against the running Hyprland build and **break on every Hyprland upgrade** — so the script
emits them as a **separate, commented hyprpm section** the user runs deliberately, never inline with
package installs (`plugins.md` rule: Claude never runs `hyprpm`). `pyprland` (scratchpads) is the one
exception that *is* packaged — AUR `pyprland`.

## The script shape

Emit this skeleton, filling `REPO`, `AUR`, the optional root/hyprpm blocks, and the `# installed`
annotations from the selections + detect flags. Keep it readable — the user reviews it before running.

```bash
#!/usr/bin/env bash
# Generated by the Hyprland rice skill from your interview selections.
# Installs the packages your chosen desktop needs. Idempotent (--needed): already-installed
# packages are skipped — nothing is reinstalled or upgraded. Review, then run:  bash install.sh
set -euo pipefail

# Official-repo packages (pacman)
REPO=(
  hyprland            # installed
  waybar wofi mako kitty
  ttf-jetbrains-mono-nerd inter-font noto-fonts-emoji
  grim slurp jq wl-clipboard
  # …everything the picks imply…
)

# AUR packages (need paru/yay)
AUR=(
  matugen-bin
  # …
)

if ! command -v pacman >/dev/null 2>&1; then
  echo "This installer targets Arch Linux (pacman). On another distro, install these by hand:"
  printf '  %s\n' "${REPO[@]}" "${AUR[@]}"
  exit 1
fi

# Repo packages
[ ${#REPO[@]} -gt 0 ] && sudo pacman -S --needed --noconfirm "${REPO[@]}"

# AUR packages — prefer an installed helper, else explain how to get one
if [ ${#AUR[@]} -gt 0 ]; then
  if   command -v paru >/dev/null 2>&1; then paru -S --needed "${AUR[@]}"
  elif command -v yay  >/dev/null 2>&1; then yay  -S --needed "${AUR[@]}"
  else
    echo "These need the AUR but no helper (paru/yay) was found:"
    printf '  %s\n' "${AUR[@]}"
    echo "Install one first, e.g.:"
    echo "  sudo pacman -S --needed base-devel git && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si"
  fi
fi

# --- Root-side login/boot chrome (group 19) — run deliberately, reviews the DM config ---
# sudo pacman -S --needed greetd greetd-tuigreet

# --- Hyprland plugins (group 23) — built from source, pinned to THIS Hyprland build ---
# Re-run `hyprpm update && hyprpm reload` after every Hyprland upgrade or they vanish.
# hyprpm update
# hyprpm add https://github.com/hyprwm/hyprland-plugins
# hyprpm enable hyprexpo
# hyprpm reload

echo "Done. Log out/in (or start the autostart daemons) to see the full desktop."
```

Notes:
- Drop `--noconfirm` if you'd rather the user confirm each pacman transaction; keep it for a one-shot
  run. AUR helpers prompt anyway (build review), so no `--noconfirm` there.
- If the wallpaper daemon is the `awww` fork, put `awww` in `AUR`, not `swww` in `REPO`.
- Empty `AUR=()` is fine — the block self-skips.
- The user should run `install.sh` **before** the autostart daemons are started / before next login,
  or the bar/wallpaper/notification daemons (A6) have nothing to launch.
</content>
</invoke>

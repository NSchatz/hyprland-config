# widgets — packages

Per-shell package map. The installer agent reads this file when assembling the global `PKGS` list,
keyed off `widgets.system` (and `widgets.look` for the matugen branch).

## Map

### Core shells

| `widgets.system` | Package | Repo / AUR | Notes |
|---|---|---|---|
| `none` | (nothing) | — | No widget shell. |
| `eww` | `eww` | AUR (`eww`) | The yuck-and-SCSS widget toolkit. Standalone GTK3 binary; daemon + on-demand windows. SCSS compiled via the **grass** Rust engine (eww `Cargo.toml`: `grass = "0.13.4"`). |
| `ags` | `aylurs-gtk-shell` | AUR | The AGS v3 (Astal + Gnim) CLI. Pulls in `astal-*` libs as transitive deps. The plugin targets v3 (the latest release line — v3.1.x as of mid-2026), not the deprecated v1. |
| `quickshell` | `quickshell` | AUR (`quickshell` or `quickshell-git`) | The QML / Qt 6 shell. Builds from source — see `gotchas.md` → "Heavy shells take real build time". |
| `hyprpanel` | `ags-hyprpanel-git` | AUR | **Archived 2026-04-27** (read-only; successor *Wayle* in Rust) but still installs and runs. The canonical AUR name is **`ags-hyprpanel-git`**; a plain `hyprpanel` also exists. Depends on `aylurs-gtk-shell` (AGS v3). |

### Turnkey shells (`widgets.system == "turnkey"`)

The `widgets.turnkey` enum picks one:

| `widgets.turnkey` | Package(s) | Repo / AUR | Notes |
|---|---|---|---|
| `end-4` | n/a — the project's installer | (`git clone` + the upstream installer) | end-4/dots-hyprland; the install script lays out Quickshell config + matugen. Don't `yay -S` — clone and run their script. |
| `caelestia` | `caelestia-shell-git` (+ `caelestia-cli-git`) | AUR | Or the project's own upstream installer. Quickshell-based. |
| `noctalia` | `noctalia-shell` | AUR | Quickshell-based; multi-compositor. Pulls in `noctalia-qs` (the project's own Quickshell fork — they forked over upstream release cadence), not stock `quickshell`. |
| `dankmaterial` | `dms-shell` | **Arch `extra`** (official repo) | Quickshell + Go. **In `extra`, not the AUR** — `sudo pacman -S dms-shell`. Replaces waybar / lock / swayidle / mako / fuzzel in one shell; greetd greeter. Build deps (`quickshell`, `matugen`, `dgop`) still come from AUR. |

All turnkey shells depend (transitively) on a Quickshell build — the AUR helper pulls it in.
Allow the extra build time (`gotchas.md`). **Two exceptions worth knowing:**

- **noctalia** pulls in **`noctalia-qs`** (their own Quickshell fork, slower-cadence than
  upstream), not stock `quickshell` — co-installing both is a conflict.
- **dms-shell** is in Arch **`extra`** (`sudo pacman -S dms-shell`), but its hard build deps
  (`quickshell`, `matugen`, `dgop`) still come from AUR.

### Theming dependency — matugen

`matugen` is needed for any path where Material You owns the shell's colors:

| Condition | Add `matugen`? |
|---|---|
| `widgets.look == "material-you"` | **yes** |
| `widgets.system == "hyprpanel"` | yes (drives HyprPanel's GUI theming branch) |
| `widgets.system == "turnkey"` | yes (every turnkey shell uses it) |
| any other combination | no — palette.conf drives the colors file directly |

Package: `matugen-bin` (AUR; prebuilt) or `matugen` (AUR; builds from Rust source). The plugin
prefers `matugen-bin` to keep the install batch fast.

## Assembly rule

```bash
case "$(jq -r .widgets.system answers.json)" in
  none)      ;;                       # nothing to install
  eww)       pkgs+=(eww) ;;
  ags)       pkgs+=(aylurs-gtk-shell) ;;
  quickshell) pkgs+=(quickshell) ;;
  hyprpanel) pkgs+=(ags-hyprpanel-git aylurs-gtk-shell) ;;  # explicit; usually transitive
  turnkey)
    case "$(jq -r .widgets.turnkey answers.json)" in
      end-4)         pkgs+=(quickshell) ;;          # plus the project's own install.sh
      caelestia)     pkgs+=(caelestia-shell-git caelestia-cli-git) ;;
      noctalia)      pkgs+=(noctalia-shell) ;;     # pulls noctalia-qs (their QS fork)
      dankmaterial)  pkgs+=(dms-shell) ;;          # Arch `extra`, not AUR
    esac
    ;;
esac

# matugen branch
look=$(jq -r .widgets.look answers.json)
sys=$(jq -r .widgets.system answers.json)
case "$look:$sys" in
  material-you:*|*:hyprpanel|*:turnkey) pkgs+=(matugen-bin) ;;
esac
```

The repo/AUR column is informational — `install.sh` auto-routes each name at runtime via
`pacman -Si`, so a package that drifts between repos / AURs doesn't break the install.

## Build-time warning

`quickshell`, `aylurs-gtk-shell`, and the turnkey shells all compile from source via the AUR
helper. Pre-install warning the installer emits:

```text
Note: quickshell (and any turnkey shell that depends on it) builds Qt 6 + Qt Quick Effects from
source via your AUR helper. Expect 20–40 minutes on a modest CPU. Other packages continue
installing in parallel where possible.
```

## Cross-references

- The shell-replaces-waybar / notifications-conflict gates that decide what *else* gets installed
  (or skipped) → `gotchas.md`
- Per-shell wiring (templates, autostart commands) → `template.md`
- Reload hooks → `reload.md`
- The cross-component package assembly rule → the installer agent's prompt and
  `skills/rice/scripts/install.sh`.

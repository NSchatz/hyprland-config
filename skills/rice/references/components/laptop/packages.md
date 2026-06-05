# laptop — packages

This component installs **at most one** package — the chosen power-profile daemon. The
brightness/volume CLIs (`brightnessctl`, `playerctl`, `pamixer`) live in `../utilities/packages.md`
and are added by that component on every install; they are not re-added here.

## Map (keyed off `laptop.power_tool`)

| `power_tool` | Package | Repo / AUR | Notes |
|---|---|---|---|
| `ppd` | `power-profiles-daemon` | repo | The default. Pairs with the waybar `power-profiles-daemon` module. Conflicts with `tlp`. |
| `tlp` | `tlp` | repo | Heavier policy engine. Optionally add `tlp-rdw` (repo) for radio/Wi-Fi profile switching, but that's a user choice — the generator does not auto-add it. Conflicts with `power-profiles-daemon` (pacman will prompt to remove PPD when installing tlp — see <https://linrunner.de/tlp/installation/arch.html>) and `auto-cpufreq`. |
| `auto-cpufreq` | `auto-cpufreq` | AUR | Adaptive CPU governor. Conflicts with `power-profiles-daemon` and `tlp`. |
| `none` | *(no package)* | — | The user opted out of power management. |

When `laptop.enabled == false`, **no package from this component** is added regardless of
`power_tool`'s value (which will be `null` per the schema).

## Assembly rule

```bash
enabled=$(jq -r .laptop.enabled answers.json)
if [ "$enabled" = "true" ]; then
  tool=$(jq -r .laptop.power_tool answers.json)
  case "$tool" in
    ppd)          pkgs+=("power-profiles-daemon") ;;
    tlp)          pkgs+=("tlp") ;;
    auto-cpufreq) pkgs+=("auto-cpufreq") ;;          # AUR — installer's AUR helper routes it
    none|null|"") ;;                                 # nothing to add
  esac
fi
```

`install.sh` auto-routes repo vs. AUR at runtime via `pacman -Si`, so the repo/AUR column above
is informational — a package that drifts repos doesn't break the install.

## Daemon enable is root-side — documented, not run

Installing the package does **not** start its service. The install output prints **exactly one**
of:

```
sudo systemctl enable --now power-profiles-daemon.service
sudo systemctl enable --now tlp.service
sudo systemctl enable --now auto-cpufreq.service
```

…depending on `power_tool`. See `template.md` → "Root-side: power-tool daemon".

For TLP, the install output **always** prints the documented rfkill mask — TLP's own Arch install
docs (<https://linrunner.de/tlp/installation/arch.html>) recommend it unconditionally to make the
radio-device-switching options behave reliably:

```
sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket
```

The agent does not execute these — it only prints them.

## What does NOT belong in this packages.md

- `brightnessctl`, `playerctl`, `pamixer` → `../utilities/packages.md`.
- `hyprlock`, `hypridle` → `../lock-screen/packages.md` and `../companion-daemons/packages.md`.
  The lid bind's `loginctl lock-session` calls into hyprlock via hypridle's lock listener; that
  daemon's package comes from those components.
- `kanshi` / `shikane` for dock/undock → `../monitors/packages.md`.
- `waybar` itself and its modules → `../waybar/packages.md`. The `power-profiles-daemon`
  D-Bus module is built into waybar; no extra package is needed for it beyond PPD itself.

## Cross-references

- The `power_tool` key in the schema → `schema.md`
- Why the three tools are mutually exclusive → `gotchas.md` § b
- The `systemctl enable --now` lines and the charge-limit unit → `template.md`
- Brightness CLI lives in utilities, not here → `../utilities/packages.md`

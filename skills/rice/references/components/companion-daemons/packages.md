# companion-daemons — packages

The three companion daemons are all **first-party Hypr ecosystem** projects, all shipped in the
Arch repos. Each is gated on the matching `companion_configs.*` answer (with `hypridle` also
needed whenever `before_sleep_cmd` is wanted, i.e. effectively always when any lock screen exists).

## Map

| Daemon | Package | Repo / AUR | Gate |
|---|---|---|---|
| hyprlock | `hyprlock` | repo | `companion_configs.hyprlock == true` **AND** `lock_screen.enabled == true` |
| hypridle | `hypridle` | repo | `companion_configs.hypridle_ladder != "never"` **OR** `lock_screen.enabled == true` (for `before_sleep_cmd`) |
| hyprpaper | `hyprpaper` | repo | `companion_configs.hyprpaper == true` |

All three follow the upstream Hyprland release cadence (`hyprwm/hyprlock`, `hyprwm/hypridle`,
`hyprwm/hyprpaper` on GitHub). The Arch repo `extra/` versions are usually within a release of
upstream tip.

## Optional auxiliaries

| Need | Package | Notes |
|---|---|---|
| Backlight control for the hypridle dim listener | `brightnessctl` | Required for `brightnessctl -s set 10` / `brightnessctl -r` — `-s` saves current state to a tmp file, the `set` operation then drops to the dim value (raw integer; a `%` suffix works too but the upstream hypridle example uses bare `10`). `-r` restores from the saved state on resume. Install whenever the chosen ladder includes a dim tier (everything except `never`). |
| Fingerprint unlock in hyprlock | `fprintd` (+ matching `libfprint` device support) | Owned by [`../lock-screen/packages.md`](../lock-screen/packages.md), not here. Cross-referenced because hyprlock's `auth { fingerprint {} }` block depends on it. |
| Wallpaper swap targets the right monitor | (none) | hyprpaper's monitor-scoped wallpapers are built-in: on 0.8+ use a `wallpaper { monitor = DP-1; path = … }` block; on 0.7.x use `wallpaper = DP-1, <path>`. |

## Assembly rule

```bash
hyprlock_on=$(jq -r '.companion_configs.hyprlock' answers.json)
hyprpaper_on=$(jq -r '.companion_configs.hyprpaper' answers.json)
ladder=$(jq -r '.companion_configs.hypridle_ladder' answers.json)
lock_on=$(jq -r '.lock_screen.enabled' answers.json)

[ "$hyprlock_on" = true ] && [ "$lock_on" = true ] && pkgs+=("hyprlock")
[ "$hyprpaper_on" = true ] && pkgs+=("hyprpaper")

# hypridle is needed whenever the ladder has any listener OR a lock screen needs before_sleep_cmd.
if [ "$ladder" != "never" ] || [ "$lock_on" = true ]; then
  pkgs+=("hypridle")
fi

# brightnessctl is the dim hook — install whenever a dim listener will be emitted.
case "$ladder" in
  balanced|aggressive|relaxed) pkgs+=("brightnessctl") ;;
esac
```

The repo/AUR column is informational — `install.sh` auto-routes each name at runtime via
`pacman -Si`, so a package that drifts between `extra/` and `community/` doesn't break the
install.

## Cross-references

- `hyprlock` package + `fprintd` optional → [`../lock-screen/packages.md`](../lock-screen/packages.md)
- Wallpaper-tool selection (the `hyprpaper` vs `swww` vs `none` pick) →
  [`../env/packages.md`](../env/packages.md) — both files agree on `hyprpaper` when chosen.
- Install-script shape (the global `pkgs` array assembly) → `skills/rice/scripts/` (the rice-init
  scaffold) and the installer agent's prompt.

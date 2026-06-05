# notifications — packages

One Arch package per daemon pick. The installer agent reads this file when assembling the global
`PKGS` list. `none` adds no package.

## Map

| Pick | Package | Repo / AUR | Notes |
|---|---|---|---|
| mako   | `mako`                   | repo   | Wayland-native. `makoctl` ships in the same package. |
| dunst  | `dunst`                  | repo   | `dunstctl` ships in the same package. D-Bus activatable. |
| swaync | `swaync`                 | repo   | Drags in GTK4 + libgtk-layer-shell. `swaync-client` ships in the same package. |
| none   | —                        | —      | Widget shell or user-provided daemon owns notifications. |

## Companion / optional packages

These are not the daemon itself — they're tools the daemon's UX assumes are present. The
`utilities` / `widgets` / `laptop` components install most of them; mention here for completeness:

| Tool | Why | Component that installs it |
|---|---|---|
| `libnotify` (`notify-send`) | Send test notifications, used by many scripts. | `utilities` (always). |
| `brightnessctl` | swaync `backlight` widget slider. | `laptop` (laptop-gated). |
| `pamixer` / `wireplumber` | swaync `volume` widget slider. | `companion-daemons`. |
| `playerctl` | swaync `mpris` widget controls (play/pause/skip). | `companion-daemons`. |
| `papirus-icon-theme` (or similar) | App icons in toasts. dunst `icon_path` chain; mako/swaync also pull from the GTK icon theme. | `look-feel`. |

## Assembly rule

```bash
daemon=$(jq -r .notifications.daemon answers.json)
case "$daemon" in
  mako|dunst|swaync) pkgs+=("$daemon") ;;
  none)              : ;;
  *) die "unknown notifications.daemon: $daemon" ;;
esac
```

The repo/AUR column is informational — `install.sh` auto-routes each name at runtime via
`pacman -Si`, so a daemon that drifts to the extra/community split doesn't break the install.

## Cross-references

- Per-daemon recipes (config file paths the package writes to `~/.config/<daemon>/`) →
  `template.md`
- Reload commands (each ships in its daemon's package) → `reload.md`
- Widget shells that ship their own daemon (and so make this `none`) →
  `../widgets/packages.md`

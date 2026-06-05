# waybar — packages

`waybar` itself, plus the on-click tools waybar is responsible for launching when the user clicks
a module. NM/PA/BT applets land here even though their **autostart** entries (`nm-applet`,
`blueman-applet`) live in [`../autostart/packages.md`](../autostart/) — this file owns whatever
the bar's `on-click` strings reference.

## Map

### Core

| Pick | Package | Repo / AUR |
|---|---|---|
| waybar | `waybar` | repo |

Add unconditionally whenever `bar.strategy` ∈ `{waybar, waybar+widgets}`.

### Module on-click dependencies (owned by waybar)

| Module | On-click command | Package | Repo / AUR |
|---|---|---|---|
| `pulseaudio` | `pavucontrol` | `pavucontrol` | repo |
| `network` | `nm-connection-editor` | `networkmanager` (provides the bin) | repo |
| `bluetooth` | `blueman-manager` | `blueman` | repo |
| `mpris` | `playerctl play-pause` | `playerctl` | repo |
| `tray` (audio fallback) | `pavucontrol` | covered above | — |
| `cpu` (drill-down) | `kitty -e btop` | `btop` (optional) | repo |

Add each only when the corresponding entry is in `bar.modules` **and** the user picked a
matching tool upstream (e.g. don't pull `playerctl` if the user explicitly dropped `mpris`).

### Strategy alternatives (NOT waybar's packages)

Listed here for completeness so the installer-routing agent doesn't double-add: when
`bar.strategy` is one of the below, waybar itself is **not** installed and the corresponding
component owns the package list.

| Strategy | Owned by | Package(s) |
|---|---|---|
| `full-shell` (Quickshell) | `widgets` | `quickshell` (AUR) |
| `full-shell` (AGS/Astal) | `widgets` | `aylurs-gtk-shell` (AUR) |
| `hyprpanel` | `widgets` | `hyprpanel` (AUR) |
| `none` | — | nothing |

### Fonts (NOT waybar's package, but waybar's hard dependency)

The MDI glyphs in `template.md` need a **Nerd Font** installed. The font itself is owned by
[`theming/fonts.md`](../../theming/fonts.md). `ttf-jetbrains-mono-nerd` is the typical pick.
Without a Nerd Font every module icon renders as a tofu box.

## Assembly rule

```bash
strategy=$(jq -r .bar.strategy answers.json)
case "$strategy" in
  waybar|waybar+widgets)
    pkgs+=("waybar")
    mods=$(jq -r '.bar.modules // [] | .[]' answers.json)
    for m in $mods; do
      case "$m" in
        pulseaudio) pkgs+=("pavucontrol") ;;
        network)    pkgs+=("networkmanager") ;;  # provides nm-connection-editor
        bluetooth)  pkgs+=("blueman") ;;
        mpris)      pkgs+=("playerctl") ;;
      esac
    done
    ;;
  *) : ;;  # full-shell / hyprpanel / none — widgets owns it
esac
```

The repo/AUR column is informational — `install.sh` auto-routes each name at runtime via
`pacman -Si`, so a package that drifts between repos doesn't break the install.

## Cross-references

- The bar autostart line (`exec-once = waybar`) lives in [`../autostart/`](../autostart/) — and
  the autostart applets (`nm-applet`, `blueman-applet`) are its packages, not this one's.
- The Nerd Font that supplies waybar's glyphs lives in
  [`theming/fonts.md`](../../theming/fonts.md).
- Other components' package maps live in `components/<x>/packages.md`.

# launcher — packages

One launcher pick maps to one canonical package. The installer agent reads this file when
assembling the global `PKGS` list.

## Map

| Pick | Package | Repo / AUR | Notes |
|---|---|---|---|
| wofi | `wofi` | repo | GTK3, Wayland-native. Default. |
| rofi | `rofi-wayland` | AUR | lbonn's Wayland fork (the repo `rofi` is X-only — see `gotchas.md`). |
| fuzzel | `fuzzel` | repo | INI config, Wayland-native. |
| tofi | `tofi` | AUR | Text-only fast picker. |
| walker | `walker` | AUR | Wayland-native, runs as service. |
| vicinae | `vicinae-bin` | AUR | Qt Raycast-for-Linux (2025). The `-bin` package is the prebuilt; `vicinae` builds from source. |
| anyrun | `anyrun-git` | AUR | krunner-style plugin runner. The plain `anyrun` AUR name has been flaky; `-git` is more reliable as of 2025. |

The repo/AUR column is informational — `install.sh` auto-routes each name at runtime via
`pacman -Si` / `paru -Si`, so a package drifting between repos doesn't break the install.

## Companion packages

Pulled in alongside the launcher pick when relevant:

| Trigger | Package | Purpose |
|---|---|---|
| `icons == true` (any tool) | `papirus-icon-theme` | Icon theme referenced by every recipe. |
| `tool == rofi` | `rofi-emoji`, `rofi-calc` | Optional rofi modes (only if `utilities` selects emoji/calc and the launcher is rofi). |
| `tool == walker` | (none) | walker bundles its own service. |
| `tool == vicinae` | `qt6-base`, `qt6-declarative` | Vicinae's runtime deps — usually pulled by `vicinae-bin`. |
| any | `xdg-desktop-portal-hyprland` | Required for `drun` to enumerate `.desktop` entries reliably on Wayland. Already in the base Hyprland install batch. |

## Assembly rule

```bash
tool=$(jq -r .launcher.tool answers.json)
case "$tool" in
  wofi)    pkgs+=(wofi) ;;
  rofi)    pkgs+=(rofi-wayland) ;;
  fuzzel)  pkgs+=(fuzzel) ;;
  tofi)    pkgs+=(tofi) ;;
  walker)  pkgs+=(walker) ;;
  vicinae) pkgs+=(vicinae-bin) ;;
  anyrun)  pkgs+=(anyrun-git) ;;
esac

if [ "$(jq -r .launcher.icons answers.json)" = "true" ] && [ "$tool" != "tofi" ]; then
  pkgs+=(papirus-icon-theme)
fi
```

## Cross-references

- The launcher's invocation lines (`$menu`/`$dmenu`) land in `hyprland.conf` — see
  `../keybinds/template.md`.
- The blur `layerrule` for the launcher's namespace lives in `../window-rules/template.md`.
- Other components' package maps live in `components/<x>/packages.md`.

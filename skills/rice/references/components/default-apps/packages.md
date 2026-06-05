# default-apps — packages

The browser and file-manager picks each map to one canonical Arch/AUR package. The installer agent
reads this file when assembling the global `PKGS` list.

## Map

### Browsers
| Pick | Package | Repo / AUR |
|---|---|---|
| firefox | `firefox` | repo |
| chromium | `chromium` | repo |
| brave | `brave-bin` | AUR |
| qutebrowser | `qutebrowser` | repo |

### File managers
| Pick | Package | Repo / AUR |
|---|---|---|
| nautilus | `nautilus` | repo |
| thunar | `thunar` | repo (consider also `thunar-volman`, `tumbler`) |
| dolphin | `dolphin` | repo |
| nemo | `nemo` | repo |
| pcmanfm | `pcmanfm-gtk3` | repo |
| yazi (TUI) | `yazi` | repo |
| ranger (TUI) | `ranger` | repo |

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

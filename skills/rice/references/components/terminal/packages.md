# terminal — packages

The terminal emulator pick maps to one canonical Arch/AUR package. The installer agent reads
this file when assembling the global `PKGS` list.

## Map

| Pick | Package | Repo / AUR | Notes |
|---|---|---|---|
| kitty | `kitty` | repo | Plugin's primary terminal; rice generates `colors.conf` for it. |
| alacritty | `alacritty` | repo | TOML config (≥ 0.13). Rice writes `alacritty.toml`. |
| foot | `foot` | repo | Wayland-only, smallest deps. |
| wezterm | `wezterm` | repo | Lua config. |
| ghostty | `ghostty` | repo | Available in `extra` since mid-2024. |

## Assembly rule

```bash
term=$(jq -r .terminal.emulator answers.json)
pkgs+=("$(map-to-package "$term")")
```

The repo/AUR column is informational — `install.sh` auto-routes each name at runtime via
`pacman -Si`, so a package that drifts between repos doesn't break the install.

## Nerd Font dependency

The emulator alone isn't enough — the font family in `fonts.mono` (group 13) needs an installed
Nerd Font for prompts, `eza`/`lsd` icons, and TUIs to render glyphs correctly. That package is
owned by the **fonts** layer (`theming/fonts.md`), not here, but the link is hard: a terminal
package with no matching Nerd Font shows tofu boxes in place of icons. The installer reads
`fonts.mono` independently and adds the Nerd Font package.

## Cross-references

- Nerd Font package map → `theming/fonts.md`
- Other components' package maps → `components/<x>/packages.md`
- Install script shape → `skills/rice/scripts/` (the rice-init scaffold) and the installer
  agent's prompt.

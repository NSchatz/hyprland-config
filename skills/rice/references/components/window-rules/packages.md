# window-rules — packages

**None.** Window rules and layer rules are built into Hyprland — `windowrule`, `windowrulev2`,
`layerrule`, and `workspace =` are core directives parsed by `hyprlang`. There is nothing to
install for this component.

## What the installer agent should do

Skip this component when walking `components/*/packages.md` for the global `PKGS` list. There is
no map to assemble.

## Related (where packages do live)

| Sibling component | Package(s) it installs |
|---|---|
| `../monitors/packages.md` | `kanshi` / `shikane` (only if dock/undock auto-switch is opted in). |
| `../waybar/packages.md` | `waybar` (whose namespace this component emits a blur rule for). |
| `../launcher/packages.md` | `rofi` / `wofi` / `fuzzel` / `anyrun` (likewise). |
| `../notifications/packages.md` | `swaync` / `mako` / `dunst` (likewise). |

The `layerrule` blocks in `template.md` only reference these tools' **namespace strings** — the
packages themselves are installed by their owning components.

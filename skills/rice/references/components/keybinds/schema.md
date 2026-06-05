# keybinds — answers.json slice

Keys this component owns under the top-level `keybinds` key.

```json
{
  "keybinds": {
    "mod": "SUPER | ALT",
    "flavor": "official-default | i3-sway | minimal",
    "vim": false,
    "resize_submap": true,
    "extras": ["cheatsheet", "theme-switch", "theme-toggle"],
    "theme_dark":  "catppuccin-mocha",
    "theme_light": "catppuccin-latte"
  }
}
```

## Types

- `keybinds.mod` — string, required. Either `SUPER` or `ALT`. Becomes the value of the `$mainMod`
  variable in `hyprland.conf`.
- `keybinds.flavor` — string, required. One of `official-default`, `i3-sway`, `minimal`. Selects
  the apps + window-mgmt key map in `binds.conf`.
- `keybinds.vim` — bool, required. When true, emit HJKL focus binds **in addition to** the arrow
  binds and move `togglesplit` from `J` to `T`.
- `keybinds.resize_submap` — bool, required. When true, emit the `submap = resize` block.
- `keybinds.extras` — array of strings. Subset of `["cheatsheet", "theme-switch",
  "theme-toggle"]`. Drives the optional binds at the bottom of `binds.conf` and the script drops.
- `keybinds.theme_dark` / `keybinds.theme_light` — strings, required **only when** `extras`
  contains `theme-toggle`. Named rice-profile slugs the toggle flips between.

## Sibling-component keys this component reads

`hyprland.conf` (owned here) writes a variables block that pulls values from sibling components.
This component does **not** own those keys — it just consumes them. Schemas live in each sibling's
folder:

| Variable in `hyprland.conf` | answers.json key | Owner |
|---|---|---|
| `$terminal` | `terminal.emulator` | [`terminal/schema.md`](../terminal/schema.md) |
| `$menu` | `launcher.tool` + `launcher.mode` (composed → `rofi -show drun` etc.) | [`launcher/schema.md`](../launcher/schema.md) |
| `$dmenu` | `launcher.tool` (composed → `rofi -dmenu` etc.) | [`launcher/schema.md`](../launcher/schema.md) |
| `$browser` | `default_apps.browser` | [`default-apps/schema.md`](../default-apps/schema.md) |
| `$fileManager` | `default_apps.files` (omit the variable when null) | [`default-apps/schema.md`](../default-apps/schema.md) |

`binds.conf` (owned here) gates entire blocks on sibling keys:

| Gated block | answers.json key | Owner |
|---|---|---|
| Screenshot branch (`hyprshot` / `grimblast` / `grim+slurp`) | `utilities.selected` (contains `screenshot`) + the chosen tool | [`utilities/schema.md`](../utilities/schema.md) |
| Clipboard bind (`cliphist list \| $dmenu \| …`) | `utilities.selected` contains `clipboard` | [`utilities/schema.md`](../utilities/schema.md) |
| Color-picker bind (`hyprpicker -a`) | `utilities.selected` contains `color-picker` | [`utilities/schema.md`](../utilities/schema.md) |
| Power-menu bind (`wlogout`) | `utilities.selected` contains `power-menu` | [`utilities/schema.md`](../utilities/schema.md) |
| Lock bind (`hyprlock`) | `lock_screen.enabled` | [`lock-screen/schema.md`](../lock-screen/schema.md) |
| Magnifier zoom binds (`SUPER+=` / `SUPER+-`) | `accessibility` contains `magnifier` | [`accessibility/schema.md`](../accessibility/schema.md) |
| Laptop lid switch (`bindl = , switch:on:Lid Switch, …`) | `laptop.enabled` + `laptop.lid_action` | [`laptop/schema.md`](../laptop/schema.md) |
| Media keys (`playerctl …`) | always emitted; `playerctl` install gated by | [`utilities/packages.md`](../utilities/packages.md) |

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (`keybinds` topic) | Writes `hyprland.conf` from `keybinds.mod` + the sibling variables above; writes `binds.conf` from `keybinds.flavor` / `vim` / `resize_submap` / `extras` + the sibling gates above. |
| `hyprland-component-writer` (`utilities`) | Drops `keybind-cheatsheet.sh` / `theme-switch.sh` to `~/.config/hypr/scripts/` when the matching slug is in `keybinds.extras`. |
| `hyprland-package-installer` | Adds `jq` to the install batch when `keybinds.extras` contains `cheatsheet`. |
| `hyprland-validator` | Flags duplicate `MODS, KEY`; flags uncommented plugin dispatchers; flags bare `togglesplit` (prefers `layoutmsg, togglesplit`). |

## Validation

- `mod`, `flavor`, `vim`, `resize_submap` are required.
- `extras` defaults to `[]` if absent.
- When `extras` contains `theme-toggle`, both `theme_dark` and `theme_light` are required.
- `vim == true` and `flavor == "minimal"` is allowed; HJKL binds still emit (the validator only
  checks for duplicate `MODS, KEY`, not for "minimalism").

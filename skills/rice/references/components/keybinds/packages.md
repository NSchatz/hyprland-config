# keybinds — packages

This component owns very few packages — most binds shell out to tools owned by other components.

## Map

| Pick / gate | Package | Repo / AUR | Required when |
|---|---|---|---|
| cheat-sheet script | `jq` | repo | `keybinds.extras` contains `cheatsheet` (the script reads `hyprctl binds -j` and filters with `jq`). |

`jq` is also pulled in by several other components (`shell-prompt`, `utilities`, the installer's
own assembly step), so it's usually already in the install batch. The installer dedups with
`pacman -S --needed`.

## Cross-dependencies (NOT owned here)

The cheat-sheet and theme-switch scripts both pipe through a launcher. The launcher itself is
chosen + installed by the [`launcher`](../launcher/packages.md) component (rofi / wofi / fuzzel /
tofi / walker / vicinae / anyrun). Do **not** add a launcher package from here — that would
double-list it. The cheat-sheet bind just assumes `$dmenu` resolves to a working picker, which
the launcher component guarantees.

Other tools the bind table invokes — and the component that owns each — for reference:

| Bind | Tool | Owned by |
|---|---|---|
| Screenshot binds | `hyprshot` / `grimblast` / `grim` + `slurp` + `wl-clipboard` | [`utilities`](../utilities/packages.md) |
| `$mainMod SHIFT, V` (clipboard) | `cliphist` + `wl-clipboard` | [`utilities`](../utilities/packages.md) |
| `$mainMod SHIFT, P` (color picker) | `hyprpicker` | [`utilities`](../utilities/packages.md) |
| `$mainMod SHIFT, M` (power menu) | `wlogout` | [`utilities`](../utilities/packages.md) |
| `$mainMod, X` (lock) | `hyprlock` | [`lock-screen`](../lock-screen/packages.md) |
| Volume / brightness | `wireplumber` (for `wpctl`), `brightnessctl` | [`env`](../env/packages.md) / autostart |
| Media keys | `playerctl` | [`utilities`](../utilities/packages.md) |
| `$mainMod CTRL, T` (theme toggle) | the `rice` CLI itself | shipped by the rice skill, not a package |

## Assembly rule

```bash
extras=$(jq -r '.keybinds.extras // [] | join(" ")' answers.json)
case " $extras " in *" cheatsheet "*) pkgs+=("jq") ;; esac
```

That's it. Everything else this component depends on is added by the sibling component that owns
the tool.

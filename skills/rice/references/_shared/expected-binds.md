# Expected binds (cross-cutting registry)

When a component is selected by the user, it usually wants a keybind so the user can actually
**use** the thing — but the keybind lives in `binds.conf` (owned by `keybinds`), not in the
component's own template. Without a contract registering "if I'm chosen, please emit these
binds for me," it's easy for the keybinds writer to never hear about a selection and silently
ship a desktop without the bind. Defect #12 (eww widgets shipped without any toggle bind)
and #17 (power-menu utility never appeared on the bar) are the same shape.

**Every writer that needs a bind it doesn't own declares it here.** The keybinds writer reads
this registry and emits the corresponding `bind = …` lines into `binds.conf` when the gate
condition is true.

The validator agent uses this registry to lint:
- For every row whose gate is true in `answers.json`, the emitted `binds.conf` contains a
  `bind = …, exec, <cmd>` line matching the dispatcher (`exec`) and the command tail.

## Bind registry

| Bind                               | Gate (true → emit)                                 | Dispatcher / command                                          | Owner (declares)        |
|---|---|---|---|
| `$mainMod SHIFT, D`                | `widgets.system == "eww"` AND `widgets.enabled ∋ dashboard` | `exec, eww open --toggle dashboard`                  | widgets                 |
| `$mainMod SHIFT, M`                | `widgets.system == "eww"` AND `widgets.enabled ∋ music`     | `exec, eww open --toggle music`                      | widgets                 |
| `$mainMod SHIFT, I`                | `widgets.system == "eww"` AND `widgets.enabled ∋ sysinfo`   | `exec, eww open --toggle sysinfo`                    | widgets                 |
| `$mainMod SHIFT, N`                | `widgets.system == "eww"` AND `widgets.enabled ∋ notification-center` | `exec, eww open --toggle notifications`    | widgets                 |
| `$mainMod, A`                      | `widgets.system == "ags"`                                   | `exec, ags toggle bar` (or `ags request "toggle bar"`)| widgets                 |
| `$mainMod, A`                      | `widgets.system == "quickshell"`                            | `exec, qs ipc call shell toggleBar`                  | widgets                 |
| `$mainMod, slash`                  | `keybinds.extras ∋ cheatsheet`                              | `exec, ~/.config/hypr/scripts/keybind-cheatsheet.sh`  | utilities               |
| `$mainMod SHIFT, B`                | `look_feel.blur_toggle == true`                             | `exec, ~/.config/hypr/scripts/blur-toggle.sh`         | utilities               |
| `$mainMod, F1`                     | `gaming.gamemode_toggle == true`                            | `exec, ~/.config/hypr/scripts/gamemode.sh`            | gaming                  |
| `$mainMod, Escape`                 | `utilities.selected ∋ power-menu` AND rofi flavor           | `exec, ~/.config/hypr/scripts/powermenu.sh`           | utilities               |
| `$mainMod SHIFT, M`                | `utilities.selected ∋ power-menu` AND wlogout flavor        | `exec, wlogout -p layer-shell`                        | utilities               |
| `$mainMod, X`                      | `lock_screen.enabled == true`                               | `exec, hyprlock`                                      | lock-screen             |
| `$mainMod SHIFT, P`                | `utilities.selected ∋ color-picker`                         | `exec, hyprpicker -a` (or `colorpicker.sh`)           | utilities               |
| `$mainMod SHIFT, V`                | `utilities.selected ∋ clipboard`                            | `exec, cliphist list \| $dmenu -i -p Clipboard \| cliphist decode \| wl-copy` | utilities |

## Waybar modules (declared the same way)

For modules that need wiring into `waybar/config.jsonc` based on a selection in another
component, declare the module here so the waybar writer reads from one place.

| Module                  | Gate                                               | What waybar emits                                           | Owner                    |
|---|---|---|---|
| `custom/power`          | `utilities.selected ∋ power-menu`                  | a `custom/power` block whose `on-click` runs `powermenu.sh` (rofi flavor) or `wlogout` (wlogout flavor); appended to `modules-right`. | utilities |
| `custom/notification`   | `notifications.daemon == "swaync"`                 | a `custom/notification` block calling `swaync-client -t`; appended to `modules-right`. | notifications |
| `battery`               | `IS_LAPTOP == 1`                                   | the built-in `battery` module appended to `modules-right`.  | laptop                   |
| `backlight`             | `/sys/class/backlight/*` non-empty                 | the built-in `backlight` module appended to `modules-right`.| laptop                   |
| `mpris` / `custom/media`| `widgets.enabled ∋ music` AND no full-shell        | media display module; appended to `modules-center`.         | widgets / utilities      |

## Rules for writers

1. **Don't emit a bind from inside the owning component's template.** Add a row here, mention
   it in the component's own template ("toggle binds land in `keybinds`; see expected-binds"),
   and let the keybinds writer emit it. This way the keybinds writer can de-duplicate and
   detect conflicts before they ship.
2. **The keybinds writer reads `answers.json` slices for every component this registry
   references** (widgets, utilities, gaming, lock-screen). When a slice is missing from the
   writer's input, treat that gate as false (no bind).
3. **A waybar module declared here gets its config block from the waybar writer**, but the
   *meaning* of the block (icon, on-click target, JSON shape) is defined in the matching
   `components/<x>/template.md`.

## Validator rule

For every row above whose gate is true in `answers.json`, the assembled `binds.conf` must
contain a `bind = …, exec, <command>` line whose tail matches the registered command. The
validator emits `ERROR: <component> selected but expected bind '<keychord> -> <cmd>' is missing
from binds.conf`.

## Cross-references

- `components/keybinds/template.md` — the binds-emitting template.
- `components/widgets/template.md` — eww/ags/quickshell shell.
- `components/utilities/template.md` — power-menu / blur-toggle / cheatsheet scripts.
- `components/waybar/template.md` — the waybar config emitter that reads this registry.

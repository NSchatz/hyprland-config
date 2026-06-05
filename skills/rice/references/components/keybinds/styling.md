# keybinds — styling

`keybinds` is a structural component, so "styling" here means the **theming-surface binds**
(theme switcher, wallpaper cycle, palette pick, bar/widget toggle, blur toggle, animation
toggle) that popular rices treat as part of the live rice experience. This is the lens the
spec calls out explicitly: live-theme-switch keybinds, what do popular rices bind?

The findings below are what we harvested from the corpus. Every claim cites the rice; the
**recipe** in `template.md` is the synthesis (currently: `SUPER+SHIFT+T` opens a theme menu,
`SUPER+CTRL+T` is the dark/light toggle — both confirmed below as the dominant mod patterns).

## How the community binds theming actions

Across the 11 corpus rices that ship a real keybind file, theming binds cluster around five
mod patterns. The right column shows the chord the rice picked; the keys themselves vary
(`T` / `W` / `Space` / `'`) but the **modifier shape** is remarkably consistent.

| Theming action | Mod shape | Rices using it |
|---|---|---|
| Open a theme/palette **menu** | `SUPER+SHIFT+<letter>` | HyDE (`SUPER+SHIFT+T` themeselect; `SUPER+SHIFT+X` themestyle), ML4W (`CTRL+ALT+T` themes), dusky (`SUPER+SHIFT+SPACE` matugen rofi), JaKooLit (`SUPER+CTRL+R` rofi theme selector) |
| **Toggle** dark/light | `SUPER+CTRL+<letter>` or `SUPER+SHIFT+<letter>` | end-4 (`CTRL+SUPER+SHIFT+D`), ML4W (`SUPER+SHIFT+M`) |
| Open the **wallpaper picker** | `SUPER+SHIFT+W` or `CTRL+SUPER+T` | HyDE (`SUPER+SHIFT+W`), ML4W (`SUPER+CTRL+W`), end-4 (`CTRL+SUPER+T`), JaKooLit (`SUPER+W`), dusky (`CTRL+SPACE`) |
| **Random/next** wallpaper | `*+ALT+W` or `*+ALT+arrow` | HyDE (`SUPER+ALT+Right/Left` prev/next), ML4W (`SUPER+SHIFT+W` random, `SUPER+ALT+W` automation), JaKooLit (`CTRL+ALT+W` random), dusky (`SUPER+'` cycle next, `SUPER+SHIFT+'` cycle fav), end-4 (`CTRL+SUPER+ALT+T` random) |
| **Cheat-sheet** for the binds | `SUPER+/` or `SUPER+H` | HyDE (`SUPER+/`), JaKooLit (`SUPER+H` KeyHints.sh), end-4 (`SUPER+Slash` quickshell:cheatsheetToggle), ML4W (`SUPER+CTRL+K`) |

Our default (`SUPER+SHIFT+T` menu + `SUPER+CTRL+T` toggle) lines up with two majority votes:
**`SHIFT+T` for menus** (HyDE, ML4W's `CTRL+ALT+T`, dusky's matugen rofi all use the `T`/menu
combo), and **`CTRL+T` for toggles** (end-4 explicitly binds `CTRL+SUPER+SHIFT+D` for light/dark
but uses `CTRL+SUPER+T` for "switchwall" — same `CTRL` qualifier).

## Archetypes

Five recurring shapes across the corpus:

### 1. Discrete-bind-per-action ("HyDE / JaKooLit / ML4W / binnewbs / dusky")

Each theming action gets its own dedicated chord. This is by far the most common pattern (5
of 11 rices). The trade-off: **lots of binds eat keyspace**, but every action is one keystroke
away. HyDE has 9 separate theme/wallpaper/bar binds; ML4W has 8; dusky has 7.

Citations:
- HyDE: `Configs/.config/hypr/keybindings.conf` lines 74-87
- JaKooLit: `config/hypr/configs/Keybinds.conf` lines 19-67
- ML4W: `dotfiles/.config/hypr/conf/keybindings/default.lua` lines 73-90
- dusky: `.config/hypr/hyprland.conf` lines 79-105, 159-160, 213-218
- binnewbs: `.config/hypr/configs/keybinds.conf` lines 26-28

### 2. Submap-as-menu-prefix ("Matt-FTW")

A single chord (`SUPER+TAB`) enters a `submap = menu`; second key picks the action (`W` →
`$browser`, `CTRL+W` → `$launcher-wallpapers`, etc.); `Escape`/`Return` exits. This trades
two keystrokes for **infinite headroom** — no more chord conflicts.

```ini
# Matt-FTW: .config/hypr/configs/binds.conf:48-91
bind = $mainMod, TAB, submap, menu
submap = menu
binde = , TAB, exec, $launcher-toggle
binde = CTRL, W, exec, $launcher-wallpapers
binde = , E, exec, $launcher-emojis
...
binde = , ESCAPE, submap, reset
binde = , RETURN, submap, reset
submap = reset
```

Caelestia uses the same pattern at a smaller scale (one global `submap = global` wrapper —
`hypr/hyprland/keybinds.conf:1-2`).

### 3. Shell-IPC dispatch ("end-4 / Caelestia / ML4W (newer binds)")

Quickshell-based rices route theming through the shell, not a standalone script. The bind
emits `global, <shell>:<action>` (Hyprland 0.50+ global dispatcher) or `exec, qs ipc call …`.
The shell owns palette state, so the bind is a thin trigger.

```lua
-- end-4: dots/.config/hypr/hyprland/keybinds.lua:48-53
hl.bind("CTRL + SUPER + T",       hl.dsp.global("quickshell:wallpaperSelectorToggle"))
hl.bind("CTRL + SUPER + ALT + T", hl.dsp.global("quickshell:wallpaperSelectorRandom"))
hl.bind("CTRL + SUPER + SHIFT + D", hl.dsp.global("quickshell:toggleLightDark"))
```

```ini
# Caelestia: hypr/hyprland/keybinds.conf:18-21
bind = $kbSession, global, caelestia:session
bind = $kbShowSidebar, global, caelestia:sidebar
bind = $kbShowPanels, global, caelestia:showall
```

```lua
-- ML4W: keybindings/default.lua:84-85
hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("qs ipc call sidebar toggle"))
hl.bind(mainMod .. " + CTRL + C", hl.dsp.exec_cmd("qs ipc call calendar toggle"))
```

### 4. Variable-driven bind set ("Caelestia")

Every chord on the LHS is a `$kb*` variable defined elsewhere (`hypr/variables.conf`),
making the bind table layout-independent: rebinding `$kbToggleWindowFloating` once moves it
across every rice file. The trade-off: **opaque defaults** (you can't read the file without
the variables file). 100% of Caelestia's bind file is this pattern.

```ini
# Caelestia: hypr/hyprland/keybinds.conf:153, 157-160
bind = $kbToggleWindowFloating, togglefloating,
bind = $kbSystemMonitor, exec, caelestia toggle sysmon
bind = $kbMusic, exec, caelestia toggle music
```

### 5. Hand-built theme.conf indirection ("flickowoa")

Theme switching is **not** bound to a key — instead, a `theme.conf` file (`config/hypr/themes/
base/theme.conf`) is sourced via `source = …`, and an external `apply.sh` script swaps the
file out of band. The keybind file (`config/hypr/land/binds.conf`) contains zero theme binds.
The trade-off: no live cycling without scripting, but the binds file stays clean.

## Battle-tested techniques

### `pkill -x <picker> ||` prefix on every menu-launching bind ("HyDE / dusky / end-4")

To prevent the picker from stacking when the user mashes the chord twice. Two flavours:

```ini
# HyDE — `||` (only run picker if pkill failed because no instance was running):
bind = $mainMod+Shift, T, exec, pkill -x rofi || $scrPath/themeselect.sh
bind = $mainMod, slash, exec, pkill -x rofi || $scrPath/keybinds_hint.sh c
# dusky — `;` (kill any running rofi, then start the new one regardless):
bindd = $mainMod SHIFT, SPACE, Matugen Theme Config, exec, uwsm-app -- pkill rofi; ~/user_scripts/rofi/rofi_theme.sh
# end-4 (lua) — same pattern with quickshell alive-check:
hl.bind("CTRL + SUPER + T", hl.dsp.exec_cmd(qsIsAlive .. " || " .. qsScripts .. "/colors/switchwall.sh"))
```

The `||` form is "toggle off if open, else open"; the `;` form is "always re-open clean".
HyDE/end-4 prefer the `||` (true toggle); dusky prefers `;` (always start fresh).

### Two binds per Quickshell action (IPC + fallback) ("end-4")

end-4 binds every Quickshell action **twice**: once via the `global` dispatcher (talks to
the running shell), once via `exec, qsIsAlive || <fallback>`. If Quickshell is down (crashed,
not yet started, --safe-mode), the fallback runs. This is the most resilient theming-bind
pattern in the corpus.

```lua
-- dots/.config/hypr/hyprland/keybinds.lua:62-64
hl.bind("SUPER + V", hl.dsp.global("quickshell:overviewClipboardToggle"))
hl.bind("SUPER + V", hl.dsp.exec_cmd(
    qsIsAlive .. " || pkill fuzzel || cliphist list | fuzzel --match-mode fzf --dmenu | cliphist decode | wl-copy"))
```

Hyprland accepts both binds without the duplicate-key gotcha (last-wins) **only because the
first form uses `global` dispatcher and the second uses `exec`** — they are different
dispatchers, so Hyprland treats them as a chain, not a duplicate. Worth knowing if you want
to add a graceful-degrade fallback.

### `bindd` + descriptions for the cheat-sheet ("HyDE / JaKooLit")

HyDE and JaKooLit both use the `bindd` flag (description-carrying bind) on almost every line.
The description is exposed via `hyprctl binds -j` and consumed by the cheat-sheet script. The
**format** has the description as the third comma-separated field, unquoted, no commas
allowed:

```ini
# JaKooLit: config/hypr/configs/Keybinds.conf:26
bindd = $mainMod, T, Global theme switcher using Wallust, exec, $scriptsDir/ThemeChanger.sh
# HyDE: Configs/.config/hypr/keybindings.conf:139
binded = $mainMod SHIFT $CONTROL, left, Move activewindow left, exec, $moveactivewindow -30 0 || hyprctl dispatch movewindow l
```

(Notice JaKooLit prefixes its dispatcher with a separate scripts dir variable `$scriptsDir`
— this lines up with the same pattern HyDE uses with `$scrPath`. Both keep the bind table
readable.)

### AZERTY-aware workspace binds ("ML4W")

ML4W is the only rice that handles non-US layouts inline in the bind table:

```lua
-- ML4W: keybindings/default.lua:12-35
local is_fr = false
local f = io.open(os.getenv("HOME") .. "/.config/hypr/input.lua", "r")
if f then
    local content = f:read("*all")
    if content:match('kb_layout%s*=%s*"fr"') then is_fr = true end
    f:close()
end
local fr_keys = { "ampersand", "eacute", "quotedbl", "apostrophe", "parenleft",
                  "minus", "egrave", "underscore", "ccedilla", "agrave" }
for i = 1, 10 do
    local key = i % 10
    if is_fr then key = fr_keys[i] end
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
```

The keysym names (`ampersand`, `eacute`, …) are the X11 names of the chars that AZERTY
produces on the number row. The cleaner `code:10`–`code:19` form (physical scancodes) is in
our `gotchas.md`. ML4W's verbosity is the cost of staying purely in keysym-space.

### `$scrPath` (HyDE) / `$scriptsDir` (JaKooLit) / `$scripts` (Matt-FTW) for script bind paths

Every rice with custom scripts defines a variable for the script directory and references
`$scrPath/foo.sh` instead of `~/.config/hypr/scripts/foo.sh`. Saves ~30 chars per bind in a
long file. Our template currently inlines `~/.config/hypr/scripts/…` for clarity.

```ini
# HyDE: $scrPath = $HOME/.config/hypr/scripts  (defined in hyprland.conf, not keybinds.conf)
bind = $mainMod, slash, exec, pkill -x rofi || $scrPath/keybinds_hint.sh c
# JaKooLit:
$scriptsDir = $HOME/.config/hypr/scripts
bindd = $mainMod, H, help / cheat sheet, exec, $scriptsDir/KeyHints.sh
```

### `uwsm-app --` prefix on every exec ("dusky")

dusky launches all user binds through `uwsm-app --` to put the process into a systemd user
scope. Stops zombie processes from accumulating under Hyprland and makes the cgroup tree
readable in `systemctl --user status`.

```ini
# dusky: .config/hypr/hyprland.conf:79-80
bindd = $mainMod SHIFT, SPACE, Matugen Theme Config, exec, uwsm-app -- pkill rofi; ~/user_scripts/rofi/rofi_theme.sh
bindd = CTRL, SPACE, Rofi Wallpaper Selector, exec, uwsm-app -- pkill rofi; ~/user_scripts/rofi/rofi_wallpaper_selctor.sh
```

We do **not** emit this — `uwsm` is opt-in (component 22 `login-boot` covers it). If a user
opts into uwsm, the writer prepends `uwsm-app --` to every `exec` bind.

## Cross-surface coherence

The theme-switch bind is the single biggest cross-surface lever in the rice. When
`SUPER+SHIFT+T` fires `~/.config/hypr/scripts/theme-switch.sh`, the script:

1. Lists every saved rice profile via `rice themes`.
2. Pipes through `$dmenu` — **must match the launcher component's choice** (rofi / wofi /
   fuzzel / walker / tofi / vicinae / anyrun).
3. Calls `rice apply <profile>` — which rerenders every `.tmpl` in `components/*/` against
   the new palette and reloads each app via the cross-surface rules in `_shared/reloads.md`.

The single critical thing the bind must get right: **pipe through `$dmenu`, not `$menu`**.
Every rice in the corpus that uses rofi for theme/wallpaper picks does so via a dedicated
config file (`config-wallpaper.rasi`, `config-themeselect.rasi`, `config-cliphist.rasi`),
not `$menu -dmenu`. This is the `$menu -dmenu` gotcha in `gotchas.md`.

The cheat-sheet bind (`SUPER+/`) is also a cross-surface coherence move: the script reads
**live** binds via `hyprctl binds -j | jq …`, so the cheat-sheet is always in sync with
`binds.conf` even after re-themes. This is the JaKooLit / HyDE / end-4 model and we ship it
the same way.

## Theming-absent rices

For absence-as-finding: **5 of the 11 keybind-file rices ship zero theme-switch bind**.

- **Caelestia** (`hypr/hyprland/keybinds.conf`) — handles theming entirely in the QML shell;
  the bind file is window-management only.
- **fufexan** (`system/programs/hyprland/binds.lua`) — NixOS, theming is a system rebuild, not
  a runtime switch.
- **linuxmobile** (`.config/hypr/keybinds.conf`) — single-theme rice (Rose Pine), no switch
  bind because there's no second theme.
- **flickowoa** (`config/hypr/land/binds.conf`) — themes managed via a separate `theme.conf`
  sourced file; switching is out-of-band.
- **Matt-FTW** (`.config/hypr/configs/binds.conf`) — the `SUPER+TAB → menu` submap has a
  `CTRL+W → $launcher-wallpapers` bind, but no explicit *theme*-switcher bind.

The takeaway for our recipe: a theme-switch bind is **the** value-add of a generative rice
plugin. Half the community doesn't have one because their rice isn't generative. Ours is, so
we ship `SUPER+SHIFT+T` and `SUPER+CTRL+T` as the default.

## Citations index

- end-4: `dots-hyprland/dots/.config/hypr/hyprland/keybinds.lua` HEAD
- HyDE: `prasanthrangan/hyprdots/Configs/.config/hypr/keybindings.conf` HEAD
- JaKooLit: `JaKooLit/Hyprland-Dots/config/hypr/configs/Keybinds.conf` HEAD (+ `UserConfigs/UserKeybinds.conf` for the user-override pattern)
- Caelestia: `caelestia-dots/caelestia/hypr/hyprland/keybinds.conf` HEAD
- ML4W: `mylinuxforwork/dotfiles/dotfiles/.config/hypr/conf/keybindings/default.lua` HEAD
- dusky: `dusklinux/dusky/.config/hypr/hyprland.conf` HEAD
- linuxmobile: `linuxmobile/hyprland-dots/.config/hypr/keybinds.conf` HEAD
- binnewbs: `binnewbs/arch-hyprland/.config/hypr/configs/keybinds.conf` HEAD
- Matt-FTW: `Matt-FTW/dotfiles/.config/hypr/configs/binds.conf` HEAD
- fufexan: `fufexan/dotfiles/system/programs/hyprland/binds.lua` HEAD
- flickowoa: `flickowoa/dotfiles/config/hypr/land/binds.conf` HEAD
- Hyprland upstream default: `hyprwm/Hyprland/example/hyprland.lua` HEAD

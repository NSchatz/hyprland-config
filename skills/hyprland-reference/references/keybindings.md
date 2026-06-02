# Hyprland Keybindings & Dispatchers

## Bind syntax

```
bind = MODS, KEY, DISPATCHER, ARGS
```

- `MODS` is a space-joined mask: `SUPER`, `ALT`, `CTRL`, `SHIFT` (or empty for no modifier).
- `KEY` is an X keysym (`Return`, `Q`, `space`, `Print`, `XF86AudioRaiseVolume`) or a raw code
  as `code:NN`.
- `ARGS` is dispatcher-specific and may itself contain commas (for `exec`, everything after the
  dispatcher is the command).

## Official default keybinds (match user expectations)

The convention used by the shipped Hyprland default config and nearly all tutorials. Generators
should default to this scheme so muscle memory transfers. Note the variable name `$mainMod`:

```ini
$mainMod = SUPER                                  # the "Windows" key

bind = $mainMod, Q, exec, $terminal               # Q launches the terminal
bind = $mainMod, C, killactive,                   # C closes the focused window
bind = $mainMod, M, exit,                         # M exits Hyprland
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, V, togglefloating,
bind = $mainMod, R, exec, $menu                   # R opens the launcher
bind = $mainMod, P, pseudo,                        # dwindle
bind = $mainMod, J, layoutmsg, togglesplit         # dwindle — see note below
```

**`layoutmsg, togglesplit`**, not a bare `togglesplit` dispatcher: split toggling is a
layout message. The shipped default uses `bind = $mainMod, J, layoutmsg, togglesplit`. Prefer
this form. (A standalone `togglesplit`/`pseudo` may still work but `layoutmsg` is current.)

An alternative i3/sway-style scheme (Return=terminal, Q=close, D=menu) is also common; offer it
but default to the official one above.

## Gestures (touchpad)

Current Hyprland uses the `gesture =` keyword (see `sections.md`), e.g.
`gesture = 3, horizontal, workspace`.

## Bind flag variants

Append flags to `bind` to change behavior. They compose (e.g. `bindel`):

| Variant   | Meaning                                                                 |
|-----------|-------------------------------------------------------------------------|
| `bind`    | Standard, on key press.                                                  |
| `bindm`   | Mouse bind (used for move/resize): `bindm = $mod, mouse:272, movewindow` |
| `binde`   | Repeats while held (`e` = repeat) — good for volume/brightness.          |
| `bindl`   | Works on the lock screen / always (`l` = locked).                        |
| `bindr`   | Fires on key **release**.                                                |
| `bindn`   | No modifiers consumed.                                                    |
| `binded`  | Flags combine, in any order: `bindel`, `bindle` = repeat + locked.        |

Flags compose freely (`e`, `l`, `r`, `m`, `n`, …). Less common single flags exist (e.g.
transparent/ignore-mods variants); confirm any unusual flag against `hyprctl binds` and the
wiki for the installed version before relying on it.

Common combos:

```ini
# Volume (repeat + works when locked). -l 1 caps at 100% so it can't over-amplify.
bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindel = , XF86AudioMute,        exec, wpctl set-mute   @DEFAULT_AUDIO_SINK@ toggle
bindel = , XF86AudioMicMute,     exec, wpctl set-mute   @DEFAULT_AUDIO_SOURCE@ toggle
bindel = , XF86MonBrightnessUp,   exec, brightnessctl -e4 -n2 set 5%+
bindel = , XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-

# Media keys (require playerctl)
bindl = , XF86AudioNext,  exec, playerctl next
bindl = , XF86AudioPause, exec, playerctl play-pause
bindl = , XF86AudioPlay,  exec, playerctl play-pause
bindl = , XF86AudioPrev,  exec, playerctl previous

# Mouse move/resize
bindm = $mainMod, mouse:272, movewindow      # left button
bindm = $mainMod, mouse:273, resizewindow    # right button
```

## Workspaces

```ini
# Switch
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
# Move active window to workspace
bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
# Special (scratchpad) workspace
bind = $mod, S, togglespecialworkspace, magic
bind = $mod SHIFT, S, movetoworkspace, special:magic
# Scroll through workspaces
bind = $mod, mouse_down, workspace, e+1
bind = $mod, mouse_up, workspace, e-1
```

Workspace arg forms: absolute `1`, relative `e+1`/`e-1`, `previous`, `empty`, named
`name:web`, `special:magic`.

## Submaps (modal keybinds)

```ini
bind = $mod, R, submap, resize
submap = resize
binde = , right, resizeactive, 10 0
binde = , left,  resizeactive, -10 0
bind  = , escape, submap, reset
submap = reset
```

## Battle-tested techniques (from real dotfiles)

Concrete, attributed idioms harvested from the big rices' keybind files. All valid on 0.54.3.

- *Described binds feed a cheat-sheet* (HyDE, JaKooLit, omarchy): use `bindd = MODS, KEY, <description>, DISPATCHER, …` so every bind carries a human label that a help overlay / generated cheat-sheet can read. The `d` stacks with other flags — `bindeld`, `binddl`, `binddm`, `binddr` (described + repeat/locked/mouse/release in any order).
- *`code:10`–`code:19` for the number row* (JaKooLit, omarchy): bind workspaces by **keycode** instead of the digit keysym so they keep working under non-US / multi-layout keyboards — `bind = $mod, code:10, workspace, 1`.
- *App variables* (every rice): define `$term`/`$browser`/`$fileManager` (often pointed at a chooser script, e.g. `$term = $HOME/.config/.../terminal.sh`) and reference them in binds, so the user picks apps once. Upstream's `$menu = wofi --show drun` is the canonical example.
- *Media/brightness on the lock screen* (universal): `bindl` for play/pause/next (works while locked) and `binde`/`bindel` for volume/brightness (repeat-on-hold). Route through an OSD client for on-screen feedback — `swayosd-client --output-volume raise` (Matt-FTW, omarchy) — and cap volume with `wpctl set-volume -l 1` so it can't over-amplify.
- *Hardware switch binds* (omarchy): `bindl = , switch:on:Lid Switch, exec, …` fires on lid/dock events (locked so it always runs) — drive monitor on/off or lock from it.
- *Push-to-talk via a press/release pair* (omarchy): `bindd = , F9, Start dictation, exec, … record start` + `binddr = , F9, Stop dictation, exec, … record stop` — `bindr` fires on release, so holding the key gates the action.
- *Resize submap with arrows **and** HJKL* (Matt-FTW): the canonical modal-resize pattern uses `binde` (repeat) inside the submap for both arrow keys and vim keys, and `bind = , ESCAPE, submap, reset` to exit — the example below is the minimal version.
- *Defaults + user-override split* (JaKooLit): ship the scheme in a vendor `Keybinds.conf` and let the user add/override (including `unbind = …`) in a separate `UserKeybinds.conf`, so updates never clobber custom binds.
- *Emerging: the Lua bind API.* end-4, ml4w, and upstream's newest default express binds in Lua — `hl.bind("SUPER + Return", hl.dsp.exec_cmd(term), { locked = true, repeating = true, description = "…" })` — where the `bind` flag letters become an opts table (`locked`/`repeating`/`mouse`/`release`). The classic `bind*` `.conf` syntax above remains fully valid on 0.54.3; note Lua as the 0.5x direction.

## Dispatcher catalog (most used)

| Dispatcher                | Purpose                                              |
|---------------------------|------------------------------------------------------|
| `exec`                    | Run a shell command.                                 |
| `killactive`              | Close focused window.                                |
| `exit`                    | Exit Hyprland.                                        |
| `workspace`               | Switch workspace.                                     |
| `movetoworkspace`         | Move window to workspace and follow.                  |
| `movetoworkspacesilent`   | Move window without following.                         |
| `togglefloating`          | Toggle floating for the focused window.               |
| `fullscreen`              | `0` full, `1` maximize, `2` fullscreen-no-decoration. |
| `fakefullscreen`/`fullscreenstate` | Fullscreen state control.                    |
| `pseudo`                  | Toggle pseudotiling (dwindle).                        |
| `togglesplit`             | Toggle split direction (dwindle).                     |
| `movefocus`               | `l`/`r`/`u`/`d` move focus.                            |
| `movewindow`              | `l`/`r`/`u`/`d` move window, or `mon:NAME`.            |
| `resizeactive`            | Resize by `DX DY` or `exact W H`.                     |
| `swapwindow`              | Swap with neighbor `l`/`r`/`u`/`d`.                   |
| `centerwindow`            | Center a floating window.                              |
| `togglespecialworkspace`  | Toggle the scratchpad/special workspace.              |
| `cyclenext`               | Focus next window in workspace.                        |
| `focuscurrentorlast`      | Toggle between last two focused windows.              |
| `movecurrentworkspacetomonitor` | Move whole workspace to a monitor.              |
| `togglegroup` / `changegroupactive` | Window group control.                       |
| `pin`                     | Pin a floating window across workspaces.              |
| `forcerendererreload`     | Reload outputs.                                       |

Full list: `hyprctl dispatchers` on a running system.

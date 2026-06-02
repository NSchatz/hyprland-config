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

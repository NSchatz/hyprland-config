# Hyprland dispatchers (cross-cutting reference)

Dispatchers are what a `bind = MODS, KEY, DISPATCHER, ARGS` line invokes. Components reference
them: `keybinds` for the main bind table, `utilities` for the script binds, `autostart` for the
`exec` entries, `lock-screen`/`gaming`/`laptop`/`accessibility` for their dedicated binds, and
the **validator** for catching binds to unknown / plugin-only dispatchers.

For the bind-flag variants (`bindm`, `bindel`, `bindl`, `bindr`, `bindd`, …) and the full bind
syntax, see `${CLAUDE_PLUGIN_ROOT}/skills/hyprland-reference/references/keybindings.md`.

## Catalog (core, non-plugin)

| Dispatcher                | Purpose / args |
|---|---|
| `exec`                    | Run a shell command (everything after the dispatcher is the command). |
| `killactive`              | Close focused window. |
| `exit`                    | Exit Hyprland. |
| `workspace`               | Switch workspace. Args: absolute `1`, relative `e+1`/`e-1`, `previous`, `empty`, `name:web`, `special:magic`. |
| `movetoworkspace`         | Move window to workspace and follow. |
| `movetoworkspacesilent`   | Move window without following. |
| `togglespecialworkspace`  | Toggle the scratchpad/special workspace. Arg: name (e.g. `magic`). |
| `togglefloating`          | Toggle floating for focused window. |
| `fullscreen`              | Args: `0` full, `1` maximize, `2` fullscreen-no-decoration. |
| `fakefullscreen` / `fullscreenstate` | Fullscreen state variants. |
| `pseudo`                  | Toggle pseudotiling (dwindle). |
| `movefocus`               | `l`/`r`/`u`/`d`. |
| `movewindow`              | `l`/`r`/`u`/`d`, or `mon:NAME`. |
| `swapwindow`              | Swap with neighbor `l`/`r`/`u`/`d`. |
| `resizeactive`            | `DX DY`, or `exact W H`. |
| `centerwindow`            | Center a floating window. |
| `cyclenext`               | Focus next window in workspace. |
| `focuscurrentorlast`      | Toggle between last two focused windows. |
| `movecurrentworkspacetomonitor` | Move workspace to a monitor by name. |
| `togglegroup` / `changegroupactive` | Window group control (core 0.5x). |
| `pin`                     | Pin a floating window across workspaces. |
| `forcerendererreload`     | Reload outputs. |
| `submap`                  | Enter a named submap (modal binds); `submap = reset` exits. |
| `layoutmsg`               | Send a message to the active layout (e.g. `layoutmsg, togglesplit` for dwindle; `layoutmsg, move +col` / `colresize +conf` / `fit active` for the native `scrolling` layout in 0.53+). |

Full list lives in `hyprctl dispatchers` on a running system.

## Dispatcher rules the validator enforces

- **Bare `togglesplit` is the legacy form.** Prefer `layoutmsg, togglesplit` (matches the shipped
  default and tutorials).
- **Plugin dispatchers HARD-ERROR the reload** when the plugin isn't loaded. `hyprexpo:expo`,
  `hy3:…`, `split-workspace:…`, `scroller:…`, pyprland's dispatchers — all must be COMMENTED-OUT
  in `binds.conf` until the user has actually built + loaded the plugin. The validator flags any
  uncommented plugin dispatcher as an ERROR.
- **Exception — `layoutmsg` for the scrolling layout is core in 0.53+** (not a plugin), so
  `layoutmsg, move +col` / `colresize +conf` / `fit active` are safe uncommented.

## Variable conventions

The shipped default config uses variables for the apps a bind launches; treat these as the
canonical names so a generated config matches what tutorials assume:

| Var | Meaning | Notes |
|---|---|---|
| `$mainMod` | The modifier key (`SUPER` by default). | Use this name (not `$mod`, not `$mainmod`). |
| `$terminal` | Terminal emulator command. | Set by the `terminal` component. |
| `$menu` | App launcher invocation. | E.g. `rofi -show drun`, `wofi --show drun`. |
| `$dmenu` | Dmenu-mode invocation for piped lists. | E.g. `rofi -dmenu`, `wofi --dmenu`, `fuzzel --dmenu`. **Never compose `$menu -dmenu`** — if `$menu` already has a mode flag (`-show drun`), appending `-dmenu` produces conflicting flags and the picker silently fails to open. |
| `$browser` | Default browser. | |
| `$fileManager` | Default file manager. | Omit when not picked. |

## Workspace argument forms

| Form | Meaning |
|---|---|
| `1` … `10` | Absolute. |
| `e+1` / `e-1` | Relative, skipping empty. |
| `previous` | Last-visited workspace. |
| `empty` | First empty workspace. |
| `name:web` | Named workspace. |
| `special:magic` | The scratchpad workspace. |

## Bind-flag composition (quick reference)

`bind` is the base; suffixes compose in any order: `e` (repeat), `l` (works locked), `r` (release),
`m` (mouse), `n` (no-modifier-consume), `d` (described — `bindd = MODS, KEY, "description",
DISPATCHER, ARGS`). So `bindel` = repeat + locked, common for volume/brightness.

Full bind syntax + flag table → `hyprland-reference/keybindings.md`.

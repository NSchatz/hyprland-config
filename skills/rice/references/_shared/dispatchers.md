# Hyprland dispatchers (cross-cutting reference)

Dispatchers are what a `bind = MODS, KEY, DISPATCHER, ARGS` line invokes. Components reference
them: `keybinds` for the main bind table, `utilities` for the script binds, `autostart` for the
`exec` entries, `lock-screen`/`gaming`/`laptop`/`accessibility` for their dedicated binds, and
the **validator** for catching binds to unknown / plugin-only dispatchers.

For the bind-flag variants (`bindm`, `bindel`, `bindl`, `bindr`, `bindd`, …) and the full bind
syntax, see `${CLAUDE_PLUGIN_ROOT}/skills/hyprland-reference/references/keybindings.md`.

## Contents

- Catalog (core, non-plugin)
- Layout messages (layoutmsg, …)
- Dispatcher rules the validator enforces
- Variable conventions
- Workspace argument forms
- Bind-flag composition (quick reference)
- hyprctl binds -j JSON shape
- Lua dispatchers (the only form on 0.57)

## Catalog (core, non-plugin)

| Dispatcher                | Purpose / args |
|---|---|
| `exec`                    | Run a shell command (everything after the dispatcher is the command). |
| `killactive`              | Close focused window. |
| `exit`                    | Exit Hyprland. |
| `workspace`               | Switch workspace. See "Workspace argument forms" below for the full grammar. |
| `movetoworkspace`         | Move window to workspace and follow. Same arg forms. |
| `movetoworkspacesilent`   | Move window without following. |
| `togglespecialworkspace`  | Toggle the scratchpad/special workspace. Arg: bare name (e.g. `magic`) — NOT `special:magic`. |
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
| `moveintoorcreategroup`   | 0.55+ — move focused window into the neighbour group, creating one if needed. |
| `pin`                     | Pin a floating window across workspaces. |
| `forcerendererreload`     | Reload outputs. |
| `submap`                  | Enter a named submap (modal binds); `submap = reset` exits. |
| `layoutmsg`               | Send a message to the active layout. Dispatcher itself is core; messages depend on the layout — see "Layout messages" below. |

Full list lives in `hyprctl dispatchers` on a running system.

## Layout messages (`layoutmsg, …`)

**dwindle** (core):
- `togglesplit` — flip split direction (use `bind = $mainMod, J, layoutmsg, togglesplit`; bare
  `togglesplit` dispatcher is the legacy form).
- `swapsplit` — swap the two windows of a split.
- `preselect <l|r|u|d>` — bias the next-opened window placement.

**master** (core): `swapwithmaster`, `addmaster`, `removemaster`, `focusmaster`, `mfact <N>`, `orientationleft`/`right`/`top`/`bottom`/`center`/`next`/`prev`, `rollnext`/`rollprev`.

**scrolling** (CORE since Hyprland 0.54+ — NOT a plugin):
- `move <+col|-col|+win|-win>` — scroll viewport / move focus by column or window
- `colresize <+conf|-conf>` — cycle through `scrolling:explicit_column_widths`
- `fit <active|all|toend|tobeg>` — refit columns into the viewport
- `focus <l|r|u|d>` — focus neighbour column/window (analogue to `movefocus`)
- `promote` — promote the focused window to a top-level column
- `swapcol <l|r>` — swap columns
- `inhibit_scroll <0|1|toggle>` — pause/resume auto-scroll
- `expel` / `consume` / `consume_or_expel` — 0.55+ window-to-column relations
- `rotatesplit` — 0.55+ rotate the focused column's split direction

**Note**: `movewindowto` is NOT a valid scrolling-layout message — `move <±col|±win>` is the right
form for scrolling viewport movement.

## Dispatcher rules the validator enforces

- **Bare `togglesplit` is the legacy form.** Prefer `layoutmsg, togglesplit` (matches the shipped
  default and tutorials).
- **Plugin dispatchers must be COMMENTED until the plugin is loaded.** When a `bind = …` targets
  a plugin dispatcher (`hyprexpo:expo`, `hy3:…`, `split-workspace:…`/`split-cycleworkspaces` /
  `split-changemonitor` / `split-changemonitorsilent` / `split-grabroguewindows`, `scroller:…`,
  pyprland's dispatchers) and the plugin **isn't loaded**, `hyprctl configerrors` logs
  `Invalid dispatcher` and the specific bind silently fails to fire. The rest of the reload still
  applies — it's a per-bind no-op, **not** a whole-reload hard-fail. Sources:
  [hyprland-plugins#204](https://github.com/hyprwm/hyprland-plugins/issues/204),
  [hy3#169](https://github.com/outfoxxed/hy3/issues/169),
  [Hyprland#5247](https://github.com/hyprwm/Hyprland/issues/5247). The validator flags
  uncommented plugin-dispatcher binds as a **WARNING** (not ERROR) and recommends commenting.
- **`general:layout = <plugin-name>`** (e.g. `layout = hy3`, `layout = scroller`) IS a whole-reload
  hard-error when the plugin isn't loaded — comment that line until the plugin is built+loaded.
  Exception: `layout = scrolling` is core in 0.54+ and safe.
- **Exception — `layoutmsg` for the scrolling layout is core in 0.54+** (not a plugin), so
  `layoutmsg, move +col` / `colresize +conf` / `fit active` / etc. are safe uncommented.

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
| `~N` | Absolute, on the focused monitor (e.g. `~3` = third workspace on current monitor). |
| `e+1` / `e-1` | Relative, skipping empty. |
| `r+1` / `r-1` / `r~1` | Relative within currently-existing workspaces. |
| `m+1` / `m-1` | Move to next/previous workspace on the same monitor. |
| `previous` | Last-visited workspace. |
| `previous_per_monitor` | Last-visited workspace on the current monitor. |
| `empty` | First empty workspace. |
| `emptynm` | First empty workspace, **not** in the special/scratchpad set. |
| `name:web` | Named workspace. |
| `special:magic` | The scratchpad workspace. |

## Bind-flag composition (quick reference)

`bind` is the base; flag letters compose in any order. Each letter:

| Letter | Meaning |
|---|---|
| `e` | Repeats while held (volume/brightness). |
| `l` | Works when the screen is locked. |
| `r` | Fires on key release (push-to-talk pattern). |
| `m` | Mouse bind. Arg form: `mouse:272` (left), `mouse:273` (right). |
| `n` | Modifier keys not consumed. |
| `d` | Described — `bindd = MODS, KEY, description, dispatcher, args` (description is the **third arg**, plain text, no quotes; `hyprctl binds -j` exposes it). |
| `t` | Transparent. |
| `i` | Ignore mods. |

Common combos (the ones the shipped config + community dotfiles actually emit):
`bindel` (repeat + locked, for volume/brightness), `bindl` (locked, for media keys),
`bindle` (locked + repeat), `bindm` (mouse move/resize), `bindd` (described),
`bindeld` (repeat + locked + described), `binddl` (described + locked), `binddm` (described +
mouse), `binddr` (described + release — push-to-talk with a label).

Full bind syntax + worked examples → `hyprland-reference/keybindings.md`.

## `hyprctl binds -j` JSON shape

The keybind-cheatsheet script reads this. Each entry contains:
`locked` (bool), `mouse` (bool), `release` (bool), `repeat` (bool), `non_consuming` (bool),
`has_description` (bool), `modmask` (int — bitmap; check live values per-system), `submap` (str),
`key` (str), `keycode` (int), `catch_all` (bool), `description` (str), `dispatcher` (str),
`arg` (str). 0.55+ also exposes human-readable `modkeys` ([PR #8607](https://github.com/hyprwm/Hyprland/pull/8607)).

## Lua dispatchers (the only form on 0.57)

A lua config does NOT have the names in the catalog above. `hl.dsp.killactive` is nil, and one
call to a nil function aborts the file: every bind after it is lost. Each legacy dispatcher has
a lua call with its own shape ([wiki](https://wiki.hypr.land/0.57.0/configuring/core/dispatchers/)); `skills/rice/scripts/migrate-config.sh` applies
this table (`scripts/ricelib/hypr/luadispatch.py`) and leaves anything it cannot place as a
`-- NOT APPLIED` comment rather than guess.

| hyprlang | lua |
|---|---|
| `exec, cmd` | `hl.dsp.exec_cmd("cmd")` |
| `killactive` | `hl.dsp.window.close()` |
| `togglefloating` | `hl.dsp.window.float({ action = "toggle" })` |
| `fullscreen` / `fullscreen, 1` | `hl.dsp.window.fullscreen()` / `hl.dsp.window.fullscreen({ mode = "maximized" })` |
| `pseudo` / `pin` / `centerwindow` | `hl.dsp.window.pseudo()` / `.pin()` / `.center()` |
| `layoutmsg, msg` | `hl.dsp.layout("msg")` |
| `movefocus, l` | `hl.dsp.focus({ direction = "left" })` |
| `movewindow, l` | `hl.dsp.window.move({ direction = "left" })` |
| `workspace, 3` / `workspace, e+1` | `hl.dsp.focus({ workspace = 3 })` / `hl.dsp.focus({ workspace = "e+1" })` |
| `movetoworkspace, 3` | `hl.dsp.window.move({ workspace = 3 })` |
| `movetoworkspacesilent, 3` | `hl.dsp.window.move({ workspace = 3, follow = false })` |
| `togglespecialworkspace, name` | `hl.dsp.workspace.toggle_special("name")` (no `special:` prefix) |
| `togglegroup` | `hl.dsp.group.toggle()` |
| `changegroupactive, f` / `b` | `hl.dsp.group.next()` / `hl.dsp.group.prev()` |
| `moveoutofgroup` | `hl.dsp.window.move({ out_of_group = true })` |
| `moveintoorcreategroup, l` | `hl.dsp.window.move({ into_or_create_group = "left" })` |
| `focuscurrentorlast` | `hl.dsp.focus({ last = true })` |
| `setprop, active opaque toggle` | `hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" })` |
| `resizeactive, 10 0` | `hl.dsp.window.resize({ x = 10, y = 0, relative = true })` |
| `bindm ..., movewindow` / `resizewindow` | `hl.dsp.window.drag()` / `hl.dsp.window.resize()`, with `{ mouse = true }` |
| `submap, name` | `hl.dsp.submap("name")`; the block is `hl.define_submap("name", function() ... end)` |
| `dpms, off` | `hl.dsp.dpms({ action = "disable" })` (actions are `toggle` / `enable` / `disable`) |
| `exit` | `hl.dsp.exit()` |

The key string joins every modifier and the key with ` + `: `hl.bind("SUPER + SHIFT + Q", ...)`.
`"SUPER SHIFT + Q"` is rejected ("Unknown key: SUPER SHIFT"). Flags are a table:
`{ repeating = true, locked = true, mouse = true, description = "..." }`.

From a shell the same dispatcher is `hyprctl dispatch 'hl.dsp.window.close()'`. On 0.57 the
legacy `hyprctl dispatch killactive` and `hyprctl keyword ...` do nothing useful: a script or an
`exec` bind that calls them loads without error and then silently fails
([wiki](https://wiki.hypr.land/0.57.0/configuring/core/advanced-configuration/using-hyprctl/)).

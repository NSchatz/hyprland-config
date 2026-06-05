# keybinds — gotchas

## `$menu -dmenu` silently breaks the picker

`$menu` and `$dmenu` are **two different invocations**, not a base + flag. If `$menu = rofi -show
drun`, then `$menu -dmenu` expands to `rofi -show drun -dmenu` — two mode flags fighting each
other, and rofi opens nothing (no error in the journal; the bind appears dead).

Pipe lists through `$dmenu` instead:

```ini
# Wrong — silently broken:
bind = $mainMod SHIFT, V, exec, cliphist list | $menu -dmenu -p Clipboard | cliphist decode | wl-copy
# Right:
bind = $mainMod SHIFT, V, exec, cliphist list | $dmenu -i -p "Clipboard" | cliphist decode | wl-copy
```

Same rule for the cheat-sheet, emoji picker, power menu, theme switcher — anything that pipes a
list through a picker. The `launcher` component composes both variables; the variables block at
the top of `hyprland.conf` documents this inline as well.

## Plugin dispatchers fail with "Invalid dispatcher" until the plugin is loaded — keep them commented

Plugin dispatchers (`hyprexpo:expo`, `hy3:makegroup`, `split-workspace:…`, `scroller:…`, pyprland
dispatchers, …) are unknown to Hyprland's bind parser until the plugin is actually loaded.
Hyprland parses binds eagerly, so a config that references them at load time logs
`Invalid dispatcher, requested '<name>' does not exist` in `hyprctl configerrors`, and **the
specific bind silently doesn't fire** — the rest of the reload still applies. (Older releases
were stricter; current behaviour per [hyprwm/hyprland-plugins #204](https://github.com/hyprwm/hyprland-plugins/issues/204)
and [outfoxxed/hy3 #169](https://github.com/outfoxxed/hy3/issues/169) is "errors in
`configerrors`, bind dead, no cascade.") Either way the user sees a dead keybind and a noisy
`configerrors`, so we still ship these **commented**:

```ini
# bind = $mainMod, Tab, hyprexpo:expo, toggle
# bind = $mainMod, G, hy3:makegroup, h
```

The user uncomments them after `hyprpm` builds + loads the plugin (handled by the `plugins`
component). The validator flags any uncommented plugin dispatcher as a WARNING (not an error —
the reload still applies). See also the timing issue tracked in
[hyprwm/Hyprland #5247](https://github.com/hyprwm/Hyprland/issues/5247) (binds load before
plugins; the cycle is "parse binds → load plugins → unknown dispatchers stay unknown").

Catalog + exceptions (e.g. `layoutmsg, move +col` for the core scrolling layout in 0.53+) live in
[`../../_shared/dispatchers.md`](../../_shared/dispatchers.md).

## Vim mode shifts `togglesplit` off `J`

The default scheme uses `$mainMod + J` for `layoutmsg, togglesplit` (dwindle's split-axis flip).
When the user opts into vim HJKL focus (3c), `J` becomes `movefocus, d`, so `togglesplit` has to
move — convention is `$mainMod + T`:

```ini
# default scheme:
bind = $mainMod, J, layoutmsg, togglesplit
# vim mode:
bind = $mainMod, T, layoutmsg, togglesplit
bind = $mainMod, J, movefocus, d
```

If the writer emits both `bind = $mainMod, J, layoutmsg, togglesplit` and `bind = $mainMod, J,
movefocus, d`, Hyprland silently keeps only the last one (see the duplicate-key gotcha below).
Branch the template on `keybinds.vim` instead of emitting both.

Also: prefer `layoutmsg, togglesplit` over the bare `togglesplit` dispatcher. Bare `togglesplit`
is the legacy form; `layoutmsg` is what the shipped default config and every tutorial use, and
it's what the scrolling-layout binds look like (`layoutmsg, move +col`) so the file reads
consistently. The validator nudges (warning, not error) on bare `togglesplit`.

## Duplicate `MODS, KEY` — last-wins, silently

Hyprland accepts the file and binds the last definition; earlier ones are dropped with no
warning. Common ways to trip:

- Forgetting that `C` is `killactive` in the official scheme and reusing it for clipboard.
- Emitting the vim `togglesplit` (`T`) **and** the default (`J`) without branching on
  `keybinds.vim`.
- Stacking two screenshot branches (`hyprshot` + `grim+slurp` fallback) when the gate logic
  misfires.
- A util-script bind colliding with an ecosystem bind (e.g. binding `SUPER+P` to both `pseudo`
  and `hyprpicker`).

The validator (`hyprland-validator` agent) parses every `bind*` line out of `binds.conf`,
normalizes the mods + key, and errors on any duplicate. Run it after generation and after every
edit.

## `bindl` for lock-aware binds, `bindel` for repeat-while-locked

- **Media + brightness** → `bindel` (`e` = repeat, `l` = works when the session is locked). Volume
  keys you want to spam-press; brightness same.
- **Playerctl next/pause/prev** → `bindl` (no repeat, but should work locked so you can pause music
  without typing your password).
- **Print key** for screenshots → plain `bind`. The screen is locked, so capturing it is by
  design forbidden — the lock daemon should suppress XF86 keys on most setups, but don't add
  `bindl` here.
- **Lid switch** → `bindl` (the lid action — suspend, lock, clamshell — must work when the screen
  is already locked).

Full bind-flag composition table is in
[`../../_shared/dispatchers.md`](../../_shared/dispatchers.md).

## `code:10`–`code:19` for the number row on non-US layouts

Workspaces 1–10 are bound to `$mainMod + 1` through `$mainMod + 0`. On a US layout these are the
characters `1 2 3 4 5 6 7 8 9 0`; on AZERTY they're `& é " ' ( - è _ ç à`, and `$mainMod, 1` simply
doesn't fire. If `input.kb_layout` is not `us`, prefer the keycode form:

```ini
bind = $mainMod, code:10, workspace, 1   # AZERTY: physical "1" key, regardless of layout
…
```

We currently emit the character form by default for parity with the shipped config and tutorials.
Flag this as a known follow-up when the user picks a non-US layout in component 2.

## File-manager bind when `default_apps.files == null`

Don't emit `bind = $mainMod, E, exec, $fileManager` when the variable was omitted — the bind
becomes `exec` of an empty string. See [`../default-apps/gotchas.md`](../default-apps/gotchas.md)
for the full picture; the gate variable in this template is `filemanager`.

## TUI file managers need `$terminal -e`

If `default_apps.files` is `yazi` or `ranger`, the `$fileManager` variable in `hyprland.conf` is
`$terminal -e yazi` (the `default-apps` writer composes this). The bind line stays the same
(`exec, $fileManager`); no special branching here.

## 0.55+ — hyprlang `.conf` is "deprecated in favor of Lua" (but still functional)

As of Hyprland 0.55, the shipped default config is `hyprland.lua`, and the wiki's Binds page
opens with: "Since Hyprland 0.55, hyprlang is deprecated in favor of lua. Looking for the old
hyprlang syntax? Check the 0.54 wiki pages." The classic `bind = …` `.conf` syntax we emit here
**still parses and runs on 0.55+** — the wiki explicitly states `.conf` "remains functional for
several releases." We keep emitting `.conf` because every existing tutorial, rice, and dotfile
out there does. Track when to migrate via the rice's version detector.

For reference, the Lua-API equivalents of the bind flags compose differently — there's no
suffix-letter mash; instead, each flag is a key in an options table:

| `.conf` flag letter | Lua option       | Meaning |
|---|---|---|
| `e` | `repeating = true`     | repeat while held |
| `l` | `locked = true`        | works while inhibitor (lock screen) is active |
| `r` | `release = true`       | fire on release |
| `m` | `mouse = true`         | mouse-button bind |
| `n` | `non_consuming = true` | also pass the event to the app |
| `d` | `description = "…"`    | hyprctl-binds label |
| `t` | `transparent = true`   | cannot be shadowed |
| `i` | `ignore_mods = true`   | ignore modifier mask |

Lua-only flags (0.55+, no `.conf` equivalent) include `click`, `drag`, `long_press`,
`auto_consuming`, `bypass`, `submap_universal`, `device`. If a user asks for one of those, the
config has to be Lua.

## `bindd` (described binds) — `.conf` syntax has the description **between key and dispatcher**

The d flag (`bindd` / `bindeld` / `binddl` / `binddm` / `binddr`) inserts a description that
`hyprctl binds -j` exposes via the `description` field (and `has_description: true`). The
syntax in `.conf` is **not** quoted and **cannot contain commas**:

```ini
bindd = $mainMod, Q, Open my favourite terminal, exec, $terminal
#         ^MODS^  ^KEY^  ^^^^^ description ^^^^^  ^dispatcher^  ^args^
```

The cheat-sheet script (`assets/scripts/keybind-cheatsheet.sh`) parses the JSON shape:

```json
{"locked": false, "mouse": false, "release": false, "repeat": false,
 "non_consuming": false, "has_description": true, "modmask": 64,
 "submap": "", "key": "Q", "keycode": 0, "catch_all": false,
 "description": "Open my favourite terminal",
 "dispatcher": "exec", "arg": "kitty"}
```

`modmask` is the integer bitmap (SUPER = 64, ALT = 8, CTRL = 4, SHIFT = 1 — verify on the live
system; PR #8607 added human-readable modkeys to a separate field), so the cheat-sheet's jq
filter has to map bits → mod names. We currently default to the description-less form (plain
`bind`) and only emit `bindd` if the user opts into the cheat-sheet (3e), because every
description widens the file and the validator has to learn the longer signature.

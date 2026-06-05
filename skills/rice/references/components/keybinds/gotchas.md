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

## Plugin dispatchers HARD-ERROR the reload — keep them commented

Plugin dispatchers (`hyprexpo:expo`, `hy3:makegroup`, `split-workspace:…`, `scroller:…`, pyprland
dispatchers, …) make the **entire** `hyprctl reload` fail when the plugin isn't loaded — not just
the one bind. The user notices because window rules, monitors, and every later `source =` line
stop applying.

Always write these lines **commented**:

```ini
# bind = $mainMod, Tab, hyprexpo:expo, toggle
# bind = $mainMod, G, hy3:makegroup, h
```

The user uncomments them after `hyprpm` builds + loads the plugin (handled by the `plugins`
component). The validator flags any uncommented plugin dispatcher as an ERROR. Catalog +
exceptions (e.g. `layoutmsg, move +col` for the core scrolling layout in 0.53+) live in
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

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

> Counter-evidence from the corpus (2026-06-05 deep-research pass): of the rices that bind
> `togglesplit`, **the majority use the bare form**, not `layoutmsg, togglesplit`:
>
> - HyDE — bare (`Configs/.config/hypr/keybindings.conf:159` — `bind = $mainMod, J, togglesplit`)
> - Matt-FTW — bare (`.config/hypr/configs/binds.conf:137` — `bind = $mainMod, S, togglesplit`)
> - JaKooLit — bare (`config/hypr/configs/Keybinds.conf:96` — `bindd = $mainMod SHIFT, I, toggle split (dwindle), togglesplit`)
> - Upstream Hyprland default (`example/hyprland.lua:265`) — `hl.dsp.layout("togglesplit")`, which the Lua API maps to bare in `.conf` form
> - The `layoutmsg, togglesplit` form does not appear in any corpus rice's bind file as of HEAD.
>
> The "prefer `layoutmsg, togglesplit`" recommendation above stands for **consistency with the
> rest of `layoutmsg, …`** binds (move, colresize, fit, promote — these only exist as
> `layoutmsg, …`), but the bare form is what the community ships. The validator should treat
> bare `togglesplit` as **canonical, not legacy** — the next person to update the validator
> rules should flip this. Tracking as a TODO; not changing the template emit yet because the
> v0.13 pass intentionally chose `layoutmsg, togglesplit` and the orchestrator may have
> reasons.

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
hyprlang syntax? Check the 0.54 wiki pages." The classic `bind = …` `.conf` syntax below
**still parses and runs on 0.55+**, but only for a while: upstream supports hyprlang for
**1 - 2 releases starting from 0.55** and drops it after that. So `.conf` is no longer the
default emission: `scripts/config-language.sh` resolves the language from the detected version
(0.55+ emits `hyprland.lua`), and a `.conf` is never installed into a directory that already
holds a `hyprland.lua`, because the lua file is what the compositor would actually load.

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

## Picker stacking — `pkill -x` before launching, or two clicks of the bind opens two pickers

Every rice in the corpus that binds rofi/fuzzel/wofi to a chord (HyDE, JaKooLit, dusky, end-4,
ML4W) prefixes the `exec` with `pkill -x <picker> ||` (true toggle: kill if running, else
start) or `pkill <picker>;` (always start fresh). Without it, a second press launches a
**second** rofi window on top of the first — the second one accepts input, the first sits
there until the user `ESC`s out.

```ini
# HyDE pattern (true toggle):
bind = $mainMod+Shift, T, exec, pkill -x rofi || $scrPath/themeselect.sh
# dusky pattern (always fresh):
bindd = $mainMod SHIFT, SPACE, Matugen Theme Config, exec, pkill rofi; ~/user_scripts/rofi/rofi_theme.sh
# end-4 (Quickshell alive-check + pkill fallback):
hl.bind("SUPER + V", hl.dsp.exec_cmd(qsIsAlive .. " || pkill fuzzel || cliphist list | fuzzel ..."))
```

Our template emits the bare `exec, …` form for the theme-switch / cheat-sheet / clipboard
binds. **A user who mashes `SUPER+SHIFT+T` will stack pickers.** We tolerate it because (a)
the bare form is what every tutorial uses, (b) `pkill -x` is sensitive to launcher choice (it
has to be `pkill -x rofi` / `pkill fuzzel` / `pkill wofi` — the `launcher` component picks),
and (c) adding it across every menu bind doubles the line length. If we later add a "polish
mode" flag, this is the cheapest single upgrade we can ship.

## Quickshell-IPC fallback double-bind ("end-4 pattern") — Hyprland allows it because the dispatchers differ

end-4 binds every shell action **twice** at the same chord — once as `global, quickshell:foo`
and once as `exec, qsIsAlive || <fallback shell command>` — so the bind survives the shell
crashing:

```lua
-- end-4: dots/.config/hypr/hyprland/keybinds.lua:62-64
hl.bind("SUPER + V", hl.dsp.global("quickshell:overviewClipboardToggle"))
hl.bind("SUPER + V", hl.dsp.exec_cmd(qsIsAlive .. " || pkill fuzzel || cliphist list | ..."))
```

This **looks like** the duplicate-key gotcha (last-wins) but doesn't trip it — Hyprland's
duplicate detector treats the two as a chain because the dispatcher names differ (`global`
vs `exec`). Both fire on the chord; the `global` one is a no-op if Quickshell isn't running.
Worth knowing if you want to add a graceful-degrade fallback for the theme-switch bind to a
plain rofi list when `rice` isn't installed.

We don't currently emit the fallback form. If we did, the pattern would be:

```ini
bind = $mainMod SHIFT, T, global, rice:theme-menu   # not real — we don't ship a global dispatcher
bind = $mainMod SHIFT, T, exec, command -v rice >/dev/null && ~/.config/hypr/scripts/theme-switch.sh || notify-send "rice CLI missing"
```

## Theme-switch picker MUST use the user's `$dmenu`, not a hard-coded launcher

Five corpus rices bind a theme/wallpaper picker; **each one uses a launcher-specific config
file** (`config-themeselect.rasi`, `config-wallpaper.rasi`, `theme-rofi.rasi`, …), never a
naked `rofi` or `fuzzel` call. Reason: the user's actual launcher pick (component 8) might
be wofi/walker/tofi/vicinae/anyrun, in which case `rofi -dmenu …` is just broken. Our
`theme-switch.sh` script must pipe through `$dmenu` (the variable from the variables block
of `hyprland.conf`), which the `launcher` component composes correctly for whatever the user
picked.

The matching gotcha — never `$menu -dmenu` (it expands to `rofi -show drun -dmenu`, two
conflicting mode flags) — is at the top of this file.

## "Re-themer plus reload" — theme-switch keystroke must not race the engine

`SUPER+SHIFT+T` → `theme-switch.sh` → `rice apply <profile>` re-renders every component's
`.tmpl` and reloads each app. The reload chain (see `_shared/reloads.md`) is asynchronous:
hyprctl reload, `pkill -SIGUSR2 waybar`, `pkill -SIGUSR1 mako`, GTK_THEME env reload, …

Two race conditions to be aware of:

1. If the theme-switch script forgets to wait for `rice apply` to return before reloading
   surfaces, the user sees the OLD palette in waybar for ~1s before it snaps to the new one.
   `rice apply` is synchronous — the script should run it in the foreground, not background.
2. If the user is mid-launcher (rofi/fuzzel is open) when the theme reload fires, the
   launcher window is still rendering the old `colors.css`/`colors.rasi`. They have to close
   and re-open. **Not a bug** — every corpus rice has the same behaviour. Cite it in the
   user's `notes.md` if you want them to know.

## AZERTY / non-US layouts — workspace 1–10 binds need `code:10`–`code:19` OR keysym names

(Already covered in this file under "`code:10`–`code:19` for the number row on non-US
layouts" above.) ML4W (`dotfiles/.config/hypr/conf/keybindings/default.lua:12-35`) is the
only corpus rice that handles this inline, by reading `kb_layout` from a sibling lua file
and substituting the keysym names (`ampersand`, `eacute`, …) for the digits when AZERTY is
detected. They use **keysym names**, not `code:` scancodes — both work; `code:` is more
robust to layout changes (it picks the *physical* key) but less self-documenting.

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

# keybinds

The bind table — every `bind = …` line a generated config emits. Owns **two** files because the
bulk of `hyprland.conf` is the variables block plus a handful of `source =` lines, and the bind
table (`binds.conf`) is the single biggest file in the config.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 3a–3f (mod key, flavor, vim HJKL, resize submap, cheat-sheet, theme switcher). |
| `schema.md` | The `answers.json` keys this component owns (`keybinds.mod`, `keybinds.extras`, `keybinds.resize_submap`). Also notes which sibling-component keys feed the `$terminal` / `$menu` / `$dmenu` / `$browser` / `$fileManager` variables this component writes. |
| `template.md` | Two templates: `hyprland.conf` (the index — variables + source lines) and `binds.conf` (the full bind table). |
| `gotchas.md` | `$menu -dmenu` breaks the picker; plugin dispatchers hard-error the reload; vim mode shifts `togglesplit` off `J`; duplicate `MODS, KEY` silently last-wins. |
| `packages.md` | `jq` (for the cheat-sheet script). Notes the launcher cross-dependency (rofi/wofi/fuzzel are owned by `launcher`). |

## Where this component lands

- **`~/.config/hypr/hyprland.conf`** — the index. Variables block (`$mainMod`, `$terminal`,
  `$menu`, `$dmenu`, `$browser`, `$fileManager`) plus the `source = ~/.config/hypr/*.conf` lines
  that pull every other component's slice in. This component writes the whole file; sibling
  components contribute lines into the variables block but don't own the file.
- **`~/.config/hypr/binds.conf`** — the bind table itself: apps, window mgmt, focus/move,
  workspaces 1–10, scratchpad, mouse move/resize, media/brightness, screenshots, ecosystem binds
  (lock/picker/logout/clipboard), util-script binds, theme switcher, resize submap.
- **Cheat-sheet + theme-switch scripts** — `~/.config/hypr/scripts/keybind-cheatsheet.sh` and
  `theme-switch.sh` get dropped in by the writer when the user opts in (3e, 3f).

## Related components

The bind table launches stuff defined by other components. Each sibling owns the variable's
*value*; this component owns the bind that *uses* the variable.

- [`default-apps`](../default-apps/) — `$browser` / `$fileManager`.
- [`terminal`](../terminal/) — `$terminal`.
- [`launcher`](../launcher/) — `$menu` and `$dmenu`.
- [`utilities`](../utilities/) — the picks in group 18 (screenshot tool, clipboard, color picker,
  power menu, …) decide which ecosystem branch fires in the screenshots block and which
  util-script binds get emitted.
- [`lock-screen`](../lock-screen/) — owns the lock daemon; this component emits the
  `bind = $mainMod, X, exec, hyprlock` line.
- [`companion-daemons`](../companion-daemons/) — hyprpaper/hypridle/hyprpolkitagent live there;
  no binds from here unless utilities opted in.
- [`accessibility`](../accessibility/) — the magnifier zoom binds (`SUPER+=` / `SUPER+-`) are
  emitted here, gated on `accessibility` containing `magnifier`.
- [`laptop`](../laptop/) — the `bindl = , switch:on:Lid Switch, …` line is emitted here, gated on
  `laptop.enabled`.
- [`plugins`](../plugins/) — plugin dispatchers (`hyprexpo:expo`, `hy3:…`, …) are written
  **commented-out** by this component; `plugins` is responsible for the build/load step that
  unblocks uncommenting them.

## Dispatcher reference

Dispatcher catalog, bind-flag variants (`bindel`/`bindl`/`bindd`/`bindm`), and the validator
rules (plugin-dispatcher gating, `layoutmsg, togglesplit` vs bare `togglesplit`) live in
[`_shared/dispatchers.md`](../../_shared/dispatchers.md). This component links to it; nothing is
duplicated.

Quick `.conf` flag-letter map (the full Lua-API equivalents are in `gotchas.md`):

| Letter | `.conf` form | Meaning |
|---|---|---|
| `e` | `binde` / `bindel` | repeat while held |
| `l` | `bindl` / `bindel`  | works while an input inhibitor (lock screen) is active |
| `r` | `bindr`             | fire on key release |
| `m` | `bindm`             | mouse bind (used with `mouse:272` / `mouse:273`) |
| `n` | `bindn`             | non-consuming — also pass the event to the focused app |
| `d` | `bindd` / `bindeld` | inline description (`bindd = MODS, KEY, <description>, dispatcher, args`) — surfaces in `hyprctl binds -j` as `description` + `has_description: true` |
| `t` | `bindt`             | transparent — cannot be shadowed by other binds |
| `i` | `bindi`             | ignore modifiers |

Flags compose in any order: `bindel` = repeat + locked, `bindeld` = repeat + locked +
described, `binddr` = described + release, etc.

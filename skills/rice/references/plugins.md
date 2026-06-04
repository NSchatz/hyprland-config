# Hyprland plugins (group 23 — hyprpm, opt-in)

The community-plugin layer most generators skip but every power rice reaches for: a **workspace
overview** (exposé), **scrolling / tree** layouts, **per-monitor workspaces**, window **title bars**,
and dropdown **scratchpads**. Gated behind one opt-in (group 23) — non-plugin users never see it.

**The hard rule: plugins are pinned to the exact Hyprland build.** Every plugin is compiled against the
running Hyprland's headers, so a Hyprland upgrade **breaks every plugin** until you rebuild them. That
makes installation a user action, not ours: **Claude never runs `hyprpm`** — we generate the `plugin {}`
config blocks + binds, then hand the user the exact `hyprpm` commands. (User is on Hyprland 0.54.3; the
plugins must match.)

## The hyprpm flow (hand these to the user — never run them)

```bash
hyprpm update                         # build/refresh headers for the running Hyprland (run after EVERY Hyprland upgrade)
hyprpm add https://github.com/hyprwm/hyprland-plugins   # add a repo (official plugins live here)
hyprpm enable hyprexpo                 # enable a plugin from an added repo
hyprpm reload                          # load enabled plugins now
```

Persist across restarts with one autostart line (group 15) — **not** a raw `hyprpm reload`:

```ini
exec-once = hyprpm reload -n           # -n = no notification on success
```

On 0.45+ the dispatcher-permission system can gate plugin loading; if `ecosystem:enforce_permissions`
is on, the user also needs `permission = /usr/(bin|local/bin)/hyprpm, plugin, allow`. `hyprpm` needs the
build toolchain (`base-devel`/`cmake`/`meson`) present — name it, never install. After any Hyprland
update tell the user to re-run `hyprpm update && hyprpm reload` or plugins silently vanish.

## Catalog — what to offer (config block + bind, frequency-ordered)

### Workspace overview / exposé — **hyprexpo** (official, the common pick)
A grid of all workspaces (GNOME/macOS-style). Repo: `hyprwm/hyprland-plugins`.
```ini
plugin {
    hyprexpo {
        columns = 3
        gap_size = 5
        bg_col = rgb(000000)
        workspace_method = center current   # [center/first] [workspace]
    }
}
bind = $mainMod, grave, hyprexpo:expo, toggle    # SUPER+` opens the overview
```
A full **widget shell** (group 7: Quickshell/AGS) often provides a richer overview with live previews —
offer hyprexpo only when the user is on waybar / has no shell-provided overview.

### Scrolling layout (PaperWM/niri-style) — **hyprscrolling** (official) / hyprscroller (community)
Windows in an infinite horizontal strip. `hyprscrolling` is the official one (`hyprwm/hyprland-plugins`);
`hyprscroller` is the older community version. Sets the layout — replaces dwindle/master.
```ini
general { layout = scrolling }          # only valid WITH the plugin loaded — never emit it bare
plugin { scrolling { fullscreen_on_one_column = true } }
```
Never write `layout = scrolling` into `general` unless the plugin is confirmed installed (a bare
`scrolling` layout errors the reload).

### i3/sway tree tiling — **hy3** (community, very popular)
Manual i3-style split tree with tabbed groups. Repo: `outfoxxed/hy3`. Sets `layout = hy3` and replaces
the split binds with hy3 dispatchers:
```ini
general { layout = hy3 }
bind = $mainMod, v, hy3:makegroup, v
bind = $mainMod, h, hy3:makegroup, h
bind = $mainMod, w, hy3:changegroup, toggletab
bind = $mainMod, e, hy3:expand, expand
```

### Per-monitor workspaces — **split-monitor-workspaces** (multi-monitor near-essential)
Each monitor gets its own 1–10 (awesome/DWM feel). Repo: `Duckonaut/split-monitor-workspaces`.
```ini
plugin { split-monitor-workspaces { count = 10 keep_focused = 0 } }
# Rebind workspace keys to its dispatchers (replace the core workspace binds):
bind = $mainMod, 1, split-workspace, 1
bind = $mainMod SHIFT, 1, split-movetoworkspacesilent, 1
```
Only offer when `MONITOR_COUNT > 1`.

### Window title bars — **hyprbars** (official)
Per-window title bars with min/close buttons (CSD-like). Repo: `hyprwm/hyprland-plugins`.
```ini
plugin {
    hyprbars {
        bar_height = 24
        bar_color = $surface            # themable via the engine's colors.conf vars
        col.text = $fg
        bar_text_font = {{font_ui}}
        hyprbars-button = $red, 14, , hyprctl dispatch killactive
        hyprbars-button = $yellow, 14, , hyprctl dispatch fullscreen 1
    }
}
```

### Decorative — **borders-plus-plus**, **hyprtrails**, **hyprwinwrap** (official)
- `borders-plus-plus` — a second/third window border ring: `plugin { borders-plus-plus { add_borders = 1, col.border_1 = $accent, border_size_1 = 2 } }`.
- `hyprtrails` — smooth motion trail behind moving windows (pure eye-candy, GPU cost).
- `hyprwinwrap` — run any app *as* the wallpaper: `plugin { hyprwinwrap { class = wallpaper-term } }`.

## pyprland — scratchpads & more (NOT hyprpm — its own tool)
**pyprland** is a Python plugin daemon (pip/AUR `pyprland`, not `hyprpm`) — the standard way to get
**dropdown scratchpads** (Quake terminal), plus `expose`, `magnify`, `monitors`, `toggle_special`. Its
config is `~/.config/hypr/pyprland.toml`; autostart with `exec-once = pypr`.
```toml
[pyprland]
plugins = ["scratchpads"]
[scratchpads.term]
command = "kitty --class dropterm"
class = "dropterm"
size = "75% 60%"
```
```ini
exec-once = pypr
bind = $mainMod, grave, exec, pypr toggle term     # dropdown terminal
```
Core Hyprland's `special:` workspace (group 1) covers a *single* scratchpad without any dependency —
offer pyprland when the user wants **multiple named** dropdowns or expose/magnify.

## Mapping group-23 answers
Each checked plugin → its `plugin {}` block into a staged **`plugins.conf`** (`source`d from
`hyprland.conf`), its binds into `binds.conf` (group 3), and (for layout plugins) the `general:layout`
line — **only if** the plugin is confirmed present. For every plugin: print the `hyprpm`/`pip` install
commands, note the build-toolchain dep, and warn that a Hyprland upgrade requires `hyprpm update &&
hyprpm reload`. Validate (`hyprctl reload` + `configerrors`) after writing; a `plugin {}` block for an
unloaded plugin is **ignored** (harmless), but a layout/dispatcher from a missing plugin **errors** —
so gate `layout =`/`hy3:`/`split-workspace` binds on the plugin actually being installed.

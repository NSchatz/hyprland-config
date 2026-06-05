# Hyprland plugins (group 23 — hyprpm, opt-in)

The community-plugin layer most generators skip but every power rice reaches for: a **workspace
overview** (exposé), **tree** layouts, **per-monitor workspaces**, window **title bars**, and dropdown
**scratchpads**. Gated behind one opt-in (group 23) — non-plugin users never see it. (Note: the
**scrolling layout is now native core** — it is *not* a plugin anymore; see below.)

**The hard rule: plugins are pinned to the exact Hyprland build.** Every plugin is compiled against the
running Hyprland's headers, so a Hyprland upgrade **breaks every plugin** until you rebuild them. So
plugin installs need *two* explicit confirmations: one when first installing them, and another after
every Hyprland upgrade (run by the user or by the **hyprland-package-installer** agent on the next
build). We generate the `plugin {}` config blocks + binds, run the `hyprpm` commands after that
confirmation, and document the upgrade-day refresh.

## The hyprpm flow (run after one user confirmation; warn about Hyprland upgrades)

```bash
mkdir -p ~/.local/share/hyprpm        # data dir MUST exist or `hyprpm update` fails (see gotchas)
hyprpm update                         # build/refresh headers for the running Hyprland (run after EVERY Hyprland upgrade)
hyprpm add https://github.com/hyprwm/hyprland-plugins   # add a repo (the official hyprbars/borders-plus-plus/hyprfocus live here)
hyprpm enable hyprbars                 # enable a plugin from an added repo (one per line — never chain with &&)
hyprpm reload                          # load enabled plugins now
```

The official repo `hyprwm/hyprland-plugins` now holds **only** `borders-plus-plus`, `csgo-vulkan-fix`,
`hyprbars`, `hyprfocus`. `hyprexpo`/`hyprtrails`/`hyprscrolling` were removed — `hyprpm add` a community
fork URL for `hyprexpo` (scrolling is now native, see below).

Persist across restarts with one autostart line (group 15) — **not** a raw `hyprpm reload`:

```ini
exec-once = hyprpm reload -n           # -n = no notification on success
```

On 0.45+ the dispatcher-permission system can gate plugin loading; if `ecosystem:enforce_permissions`
is on, the user also needs `permission = /usr/(bin|local/bin)/hyprpm, plugin, allow`. The build
toolchain (`base-devel`/`cmake`/`meson`/`cpio`) is added to the install batch (A3d → packages.md →
"PKGS") so it lands with the rest. After any Hyprland update re-run `hyprpm update && hyprpm reload`
(prompt the user) or plugins silently vanish.

## hyprpm gotchas / how it really works (READ THIS — the common failure modes)

These are verified live on Hyprland 0.55.2 and explain why plugin setup so often breaks.

- **hyprpm needs an interactive TTY — Claude can never run it.** hyprpm keeps its state and the built
  `.so` files in **root-owned `/var/cache/hyprpm/<username>/`**, and shells out to `sudo`/`doas`/`run0`
  **internally** to write there. So `hyprpm add`/`update`/`enable`/`reload` all need an interactive
  password prompt — they **cannot run headless / from an agent**. This is the real reason for the
  **"Claude never runs hyprpm"** rule: hand the exact commands to the user and let them run them in
  their terminal.
- **The data dir must exist first.** `~/.local/share/hyprpm` must already exist or `hyprpm update`
  dies with `✖ Failed to write plugin state`. Tell the user to run **`mkdir -p ~/.local/share/hyprpm`**
  before their first hyprpm command.
- **Never chain enables with `&&`.** `hyprpm enable A && hyprpm enable B` aborts everything after the
  first failure (e.g. a plugin that didn't build), silently leaving the rest disabled. Emit **each
  `hyprpm enable <name>` on its own line.**
- **No-root alternative for the current session.** The built plugins are world-readable at
  `/var/cache/hyprpm/<user>/<repo>/<plugin>.so`. Load one into the *running* compositor with
  **`hyprctl plugin load /var/cache/hyprpm/<user>/<repo>/<plugin>.so`** — that talks to the user's
  running Hyprland over its socket, **no root needed**. It is **non-persistent** (gone on logout); use
  `hyprpm enable <name>` for persistence. Handy for testing/demoing a plugin without hitting the sudo
  wall.
- **Plugin-dispatcher binds HARD-ERROR the reload — emit them COMMENTED OUT.** This is the single most
  common way a plugin setup breaks the config. A bind to a plugin dispatcher that isn't loaded (e.g.
  `bind = $mod, grave, hyprexpo:expo, toggle`) is **not** a silent no-op — `hyprctl configerrors`
  reports **`Invalid dispatcher`** and the **whole reload FAILS** (and rolls back under safe-apply).
  Same for a non-core `general:layout = <plugin-layout>` when the plugin isn't loaded. So every such
  bind/layout line **MUST be written commented-out**, to be uncommented **only after** the plugin is
  actually built+enabled (or loaded via `hyprctl plugin load`).

## Catalog — what to offer (config block + bind, frequency-ordered)

### Workspace overview / exposé — **hyprexpo** (now a community fork, the common pick)
A grid of all workspaces (GNOME/macOS-style). **hyprexpo was REMOVED from `hyprwm/hyprland-plugins`** —
it now lives only as community forks. Recommend the maintained "original fork", actively kept current:
`https://github.com/sandwichfarm/hyprexpo` (alt: `https://github.com/colonelpanic8/hyprexpo`).
`hyprpm add` the fork's URL, then `hyprpm enable hyprexpo`. Config + dispatcher are unchanged:
```ini
plugin {
    hyprexpo {
        columns = 3
        gap_size = 5
        bg_col = rgb(000000)
        workspace_method = center current   # [center/first] [workspace]
    }
}
# Emit this bind COMMENTED-OUT until the plugin is enabled/loaded — an unloaded
# hyprexpo:expo dispatcher hard-errors the reload (see hyprpm gotchas):
# bind = $mainMod, grave, hyprexpo:expo, toggle    # SUPER+` opens the overview
```
A full **widget shell** (group 7: Quickshell/AGS) often provides a richer overview with live previews —
offer hyprexpo only when the user is on waybar / has no shell-provided overview.

### Scrolling layout (PaperWM/niri-style) — **NATIVE CORE, no plugin needed**
Windows in an infinite horizontal strip. **As of Hyprland 0.53+ this is built into core** — there is
**no `hyprscrolling` plugin to install** for current Hyprland (the old upstream plugin's README now just
says *"DEPRECATED: see wiki Configuring/Scrolling-Layout"*). It is the **recommended ultrawide option**,
and needs **zero** hyprpm. Configure it with the core `general:layout` plus a **TOP-LEVEL `scrolling {}`
block** (not under `plugin {}`):
```ini
general { layout = scrolling }          # core layout name in 0.53+ — no plugin required
scrolling {
    column_width = 0.5                  # 0–1, fraction of the viewport per column
    fullscreen_on_one_column = true
    focus_fit_method = 0                # 0 = center focused column, 1 = fit
    follow_focus = true
    explicit_column_widths = 0.333, 0.5, 0.667, 1.0   # cycle set for colresize
}
```
Binds use the `layoutmsg` dispatcher:
```ini
bind = $mainMod, comma,  layoutmsg, move +col          # scroll viewport right
bind = $mainMod, period, layoutmsg, move -col          # scroll viewport left
bind = $mainMod, equal,  layoutmsg, colresize +conf    # cycle column widths (next in explicit list)
bind = $mainMod, minus,  layoutmsg, colresize -conf    # cycle the other way
bind = $mainMod, f,      layoutmsg, fit active         # fit the active column
bind = $mainMod SHIFT, h, layoutmsg, movewindowto l    # move window <dir>: l/r/u/d
```
Because this is core in 0.53+, `general:layout = scrolling` and its `layoutmsg` binds are **safe to emit
uncommented** (unlike a plugin layout, which must be gated). See **config-templates.md** for where the
`scrolling {}` block + binds land in the modular config.

### i3/sway tree tiling — **hy3** (community, very popular, still maintained)
Manual i3-style split tree with tabbed groups. Still maintained at `https://github.com/outfoxxed/hy3`
(unchanged). Sets `layout = hy3` and replaces the split binds with hy3 dispatchers. Both the
`general:layout = hy3` line **and** the `hy3:` dispatcher binds reference an unloaded plugin until it's
built+enabled, so **emit them commented-out** and uncomment after enable/load:
```ini
# general { layout = hy3 }
# bind = $mainMod, v, hy3:makegroup, v
# bind = $mainMod, h, hy3:makegroup, h
# bind = $mainMod, w, hy3:changegroup, toggletab
# bind = $mainMod, e, hy3:expand, expand
```

### Per-monitor workspaces — **split-monitor-workspaces** (multi-monitor near-essential)
Each monitor gets its own 1–10 (awesome/DWM feel). Repo: `Duckonaut/split-monitor-workspaces`.
```ini
plugin { split-monitor-workspaces { count = 10 keep_focused = 0 } }
# Rebind workspace keys to its dispatchers (replace the core workspace binds) — but these are
# plugin dispatchers, so emit COMMENTED-OUT until the plugin is enabled/loaded (an unloaded
# split-workspace dispatcher hard-errors the reload):
# bind = $mainMod, 1, split-workspace, 1
# bind = $mainMod SHIFT, 1, split-movetoworkspacesilent, 1
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

### Decorative — **borders-plus-plus** (official), **hyprtrails** (community), **hyprwinwrap** (official)
The official `hyprwm/hyprland-plugins` repo now ships **only** `borders-plus-plus`, `csgo-vulkan-fix`,
`hyprbars`, and `hyprfocus` — `hyprexpo`, `hyprtrails`, and `hyprscrolling` were **removed**.
- `borders-plus-plus` — *(official)* a second/third window border ring: `plugin { borders-plus-plus { add_borders = 1, col.border_1 = $accent, border_size_1 = 2 } }`.
- `hyprtrails` — *(community forks only — removed from official; treat as optional / unmaintained-risk)*
  smooth motion trail behind moving windows (pure eye-candy, GPU cost).
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
`hyprland.conf`), and its binds into `binds.conf` (group 3). **Emit every plugin-dispatcher bind and
every non-core `general:layout = <plugin-layout>` line COMMENTED-OUT** (the `plugin {}` block itself is
safe — an unloaded one is just ignored). Uncomment them only after the plugin is actually built+enabled
(`hyprpm enable`) or live-loaded (`hyprctl plugin load …`). This is non-negotiable: a `plugin {}` block
for an unloaded plugin is **ignored** (harmless), but a layout/dispatcher from a missing plugin
**hard-errors** and fails the whole reload (rolled back under safe-apply). The lone exception is the
**native `scrolling` layout** (core in 0.53+) — its `general:layout = scrolling`, `scrolling {}` block,
and `layoutmsg` binds need **no plugin** and are safe to emit uncommented.

Never run `hyprpm` yourself — see the **hyprpm gotchas** section. Hand the user the commands (one
`hyprpm enable` per line, `mkdir -p ~/.local/share/hyprpm` first), and warn that a Hyprland upgrade
requires `hyprpm update && hyprpm reload`. For pyprland use `pip`/AUR, not hyprpm. Validate
(`hyprctl reload` + `configerrors`) after writing.

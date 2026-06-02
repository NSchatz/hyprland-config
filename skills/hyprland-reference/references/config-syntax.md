# Hyprland Config Syntax

## File location and loading

- Main file: `~/.config/hypr/hyprland.conf` (respects `$XDG_CONFIG_HOME`).
- Hyprland watches the file and reloads on change automatically. Disable with
  `misc:disable_autoreload = true`. Force a reload with `hyprctl reload`.
- Errors are shown in an on-screen overlay; check `hyprctl configerrors` programmatically.

## Values and types

- **Booleans:** `true`/`false` or `yes`/`no` or `1`/`0`.
- **Integers / floats:** plain numbers. Some options accept floats (e.g. `scale = 1.5`).
- **Strings:** unquoted, run to end of line. Quotes are literal characters, not delimiters.
- **Colors:**
  - `rgba(rrggbbaa)` e.g. `rgba(1a1a1aee)`
  - `rgb(rrggbb)` e.g. `rgb(ff0066)`
  - legacy `0xAARRGGBB` e.g. `0xee1a1a1a`
  - **Gradients** (borders): list 2+ colors and an optional angle in degrees:
    `col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg`
- **Modifier masks** (binds): `SUPER`, `ALT`, `CTRL`/`CONTROL`, `SHIFT`, and combos joined by
  spaces: `SUPER SHIFT`. `SUPER` is the Windows/command key.

## Variables

```ini
$mod = SUPER
$terminal = kitty
$menu = wofi --show drun

bind = $mod, Return, exec, $terminal
```

- Defined with `$name = value`; expanded wherever `$name` appears.
- Plain text substitution — variables can hold partial values and be concatenated.
- Hyprland also exposes built-in **dynamic variables** usable in some contexts, e.g.
  `$HYPRLAND_INSTANCE_SIGNATURE`. Environment variables are referenced in `env` lines, not with
  `$` expansion inside arbitrary values.

## Sections: block vs keyword form

These are equivalent:

```ini
# Block form (nesting allowed)
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

# Flat keyword form (colon-delimited path)
input:kb_layout = us
input:follow_mouse = 1
input:touchpad:natural_scroll = true
```

Use whichever is clearer. Generated configs typically use block form for readability and the
keyword form only for one-off overrides.

## Sourcing (modular configs)

```ini
# hyprland.conf
source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/input.conf
source = ~/.config/hypr/binds.conf
```

- Paths may be absolute or `~`-relative.
- Globs are supported on current versions: `source = ~/.config/hypr/conf.d/*.conf`.
- Order matters: later definitions override earlier ones for the same key.
- Variables defined in a sourced file are visible to files sourced afterward.

**Modularization patterns (from real dotfiles).** The common split is one file per concern —
`monitors.conf`, `input.conf`, `keybinds.conf`, `windowrules.conf`, `decorations.conf`,
`animations.conf`, `env.conf`, `autostart.conf`, `colors.conf` — sourced from `hyprland.conf`
(Matt-FTW is the clean flat example). Two **defaults-vs-user-override** idioms recur so package
updates don't clobber edits:
- *Paired sources* (JaKooLit): `source = $configs/X.conf` then `source = $UserConfigs/X.conf` for
  each concern — the user file is sourced second so it wins. `$configs`/`$UserConfigs` are path
  variables defined at the top.
- *Marker-guarded thin file* (HyDE): a small `hyprland.conf` that `source`s a generated system
  fallback first, then a handful of `source = ./file.conf` (relative) overrides + one
  `userprefs.conf`; a `$HYDE_HYPRLAND=set` marker var tells the updater not to overwrite it.

Source a `colors.conf`/`theme.conf` (the rice palette as `$variables`) **last** so the rest of the
config can reference `$accent` etc.; a theme switcher rewrites that one file + `hyprctl reload`. (The
newest rices — omarchy, ml4w, upstream's default — wrap all this in a **Lua** config with
`require(...)` instead of `source =`. As of **0.55, Lua is the default config language** and the
wiki has switched to it, but hyprlang `.conf` "remains functional for several releases" — so
emitting `.conf` is still correct and is what this engine does; the `.conf` form remains fully
valid on 0.54.3 and 0.55.)

## exec, exec-once, env

```ini
exec-once = waybar &            # run once at startup
exec = killall -SIGUSR2 waybar  # run on every config reload
env = XCURSOR_SIZE,24           # set env var (note the COMMA, no '=')
envd = HYPRCURSOR_SIZE,24       # env var also exported to systemd/dbus activation env
```

- `env` uses a **comma** between name and value, not `=`.
- `env` lines must appear before the programs that need them; cleanest at the very top of the
  config (or in a sourced `env.conf` sourced first).
- `execr` runs a command without Hyprland's shell-arg mangling; `exec` re-runs on every reload
  (use it to re-apply something after a theme reload), `exec-once` only at startup.

**Universal autostart block** (appears in nearly every rice's `exec-once`): a clipboard watcher —
`exec-once = wl-paste --type text --watch cliphist store` **and** a second line for `--type image`;
the systemd/portal env import — `exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP`
(+ `systemctl --user import-environment …`); a polkit agent (`hyprpolkitagent` or
`/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1`); exactly **one** notification daemon
(swaync **or** mako/dunst — never two, they fight for the D-Bus name); `waybar`; `hypridle`; and a
wallpaper daemon (`swww-daemon`, `swaybg`, or the swww fork `awww-daemon`).

**Universal env block:** `XCURSOR_SIZE`/`HYPRCURSOR_SIZE` (+ `*_THEME`), the XDG trio
`XDG_CURRENT_DESKTOP=Hyprland` / `XDG_SESSION_TYPE=wayland` / `XDG_SESSION_DESKTOP=Hyprland`
(Matt-FTW uses `envd =` for these so they reach the systemd/dbus activation env),
`QT_QPA_PLATFORM=wayland;xcb` + `QT_QPA_PLATFORMTHEME` (and `QT_STYLE_OVERRIDE=kvantum` if using
Kvantum), `GDK_BACKEND=wayland,x11,*`, `MOZ_ENABLE_WAYLAND=1`, `ELECTRON_OZONE_PLATFORM_HINT=auto`.
Ship the NVIDIA block (`LIBVA_DRIVER_NAME=nvidia`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`,
`GBM_BACKEND=nvidia-drm`, `NVD_BACKEND=direct`) **only** under the proprietary driver — under nouveau
those break GLX/VA-API (see `rice`).

## Categories quick map

| Category      | Purpose                                           |
|---------------|---------------------------------------------------|
| `monitor=`    | Display setup (positional syntax, not a block)    |
| `input`       | Keyboard, mouse, touchpad, per-device             |
| `general`     | Gaps, borders, layout, tearing                    |
| `decoration`  | Rounding, opacity, `blur{}`, `shadow{}`, dim      |
| `animations`  | `bezier=` curves and `animation=` rules           |
| `dwindle`     | Dwindle layout options                            |
| `master`      | Master layout options                             |
| `gestures`    | Touchpad/workspace swipe                           |
| `group`       | Window grouping + `groupbar`                       |
| `misc`        | VFR, logo, anims defaults, autoreload             |
| `cursor`      | Cursor behavior (moved here from general/input)   |
| `binds`       | Global bind behavior toggles                      |
| `xwayland`    | XWayland scaling/behavior                          |

See `sections.md` for option-level detail.

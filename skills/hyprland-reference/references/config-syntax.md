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

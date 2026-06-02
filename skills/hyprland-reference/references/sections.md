# Hyprland Config Sections

Option-level reference for the major config sections. Value types and defaults reflect recent
Hyprland releases (roughly 0.40+). Where an option is version-sensitive it is flagged; verify
against `deprecations.md` and the installed `hyprctl version` when accuracy matters.

---

## monitor=

Positional, **not** a block. Syntax:

```
monitor = NAME, RESOLUTION@REFRESH, POSITION, SCALE [, extra args]
```

Examples:

```ini
monitor = DP-1, 2560x1440@144, 0x0, 1
monitor = HDMI-A-1, 1920x1080@60, 2560x0, 1
monitor = eDP-1, preferred, auto, 1.5         # laptop panel, auto-place, fractional scale
monitor = , preferred, auto, 1                # catch-all default for any monitor
monitor = DP-2, disable                       # turn a monitor off
```

Extra trailing args (keyword form, repeatable):

- `transform, N` — rotation/flip (0=normal, 1=90°, 2=180°, 3=270°, 4-7 flipped).
- `mirror, NAME` — mirror another output.
- `bitdepth, 10` — 10-bit color.
- `vrr, 1` — variable refresh (also a global `misc:vrr`).

Find names/modes with `hyprctl monitors`.

---

## input

```ini
input {
    kb_layout = us
    kb_variant =
    kb_options = caps:escape
    follow_mouse = 1            # 0 none, 1 normal, 2 detached, 3 strict
    mouse_refocus = true
    sensitivity = 0             # -1.0 .. 1.0 (libinput accel); NOT general:sensitivity
    accel_profile =            # flat | adaptive
    natural_scroll = false

    touchpad {
        natural_scroll = true
        disable_while_typing = true
        clickfinger_behavior = true
        tap-to-click = true
        scroll_factor = 1.0
    }

    # Per-device overrides:
    # device {
    #     name = epic-mouse-v1
    #     sensitivity = -0.5
    # }
}
```

---

## general

```ini
general {
    gaps_in = 5                 # may take up to 4 values (top right bottom left)
    gaps_out = 20
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle            # dwindle | master
    resize_on_border = true
    allow_tearing = false       # enable per-window via window rule `immediate`
    no_focus_fallback = false
}
```

Note: cursor-related options that used to live here (`no_cursor_warps`,
`cursor_inactive_timeout`) moved to the `cursor` category. `sensitivity` moved to `input`.

---

## decoration

```ini
decoration {
    rounding = 10
    rounding_power = 2          # 0.5x+: corner curve exponent (2 = circular; higher = squircle)
    active_opacity = 1.0
    inactive_opacity = 1.0
    fullscreen_opacity = 1.0

    blur {
        enabled = true
        size = 3
        passes = 1
        vibrancy = 0.1696
        new_optimizations = true
        ignore_opacity = false
    }

    shadow {
        enabled = true
        range = 4
        render_power = 3
        color = rgba(1a1a1aee)
    }

    dim_inactive = false
    dim_strength = 0.1
}
```

**Deprecated forms** (older tutorials): `drop_shadow`, `shadow_range`, `shadow_render_power`,
`col.shadow` at the `decoration` level, and `blur = true` as a bool. Use the `shadow {}` /
`blur {}` subcategories instead. See `deprecations.md`.

---

## animations

```ini
animations {
    enabled = true
    # bezier = NAME, x0, y0, x1, y1
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    # animation = NAME, ONOFF, SPEED, CURVE [, STYLE]
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}
```

Speed is in deciseconds (1 = 100ms). Animatable targets include `global`, `windows`,
`windowsIn`, `windowsOut`, `windowsMove`, `border`, `borderangle`, `fade`, `workspaces`,
`specialWorkspace`, `layers`.

---

## dwindle / master

```ini
dwindle {
    pseudotile = true
    preserve_split = true
    smart_split = false
    force_split = 0
}

master {
    new_status = master         # master | slave | inherit  (was: new_is_master = true)
    new_on_top = false
    mfact = 0.55
    orientation = left
}
```

---

## gestures (0.45+ keyword API)

Current Hyprland (the 0.54 default config ships this) uses a `gesture = ...` **keyword**, not a
`gestures {}` block:

```
gesture = FINGERS, DIRECTION, ACTION [, args]
```

```ini
gesture = 3, horizontal, workspace          # 3-finger swipe to change workspace
gesture = 4, horizontal, move               # 4-finger swipe to move window
gesture = 3, up, fullscreen
```

The older block form (deprecated on these versions):

```ini
# Legacy — pre-0.45
gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
}
```

Emit the `gesture =` keyword on 0.45+; fall back to the `gestures {}` block only for older
targets. See `deprecations.md`.

---

## group

```ini
group {
    col.border_active = rgba(33ccffee)
    col.border_inactive = rgba(595959aa)
    groupbar {
        enabled = true
        font_size = 10
        gradients = true
    }
}
```

---

## misc

```ini
misc {
    force_default_wallpaper = -1   # 0 disables the anime mascot wallpaper
    disable_hyprland_logo = false
    disable_splash_rendering = false
    vfr = true                     # variable frame rate (was: no_vfr inverse)
    vrr = 0                        # 0 off, 1 on, 2 fullscreen-only
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
    disable_autoreload = false
    focus_on_activate = false
    animate_manual_resizes = false
}
```

---

## cursor

```ini
cursor {
    no_hardware_cursors = false
    inactive_timeout = 0           # was general:cursor_inactive_timeout
    no_warps = false               # was general:no_cursor_warps
    hide_on_key_press = false
    hide_on_touch = true
}
```

---

## binds (behavior toggles)

```ini
binds {
    workspace_back_and_forth = false
    allow_workspace_cycles = false
    pass_mouse_when_bound = false
    scroll_event_delay = 300
}
```

---

## xwayland

```ini
xwayland {
    enabled = true
    force_zero_scaling = false     # fixes blurry XWayland apps on scaled monitors
}
```

## permissions (recent Hyprland)

Newer Hyprland gained an opt-in permission system that gates sensitive capabilities
(screencopy, plugin loading, keyboard grabbing) per executable. The shipped default config
ships it commented out. Permission changes require a **Hyprland restart** (not applied on
reload), for security.

```ini
ecosystem {
    enforce_permissions = 1        # turn the permission system on
}

# permission = <regex path>, <capability>, allow|deny|ask
permission = /usr/(bin|local/bin)/grim, screencopy, allow
permission = /usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland, screencopy, allow
permission = /usr/(bin|local/bin)/hyprpm, plugin, allow
```

If `enforce_permissions` is enabled, screenshot/screen-share tools (`grim`,
`xdg-desktop-portal-hyprland`) need explicit `screencopy` allows or they silently fail. Leave it
off (the default) unless the user wants the hardening.

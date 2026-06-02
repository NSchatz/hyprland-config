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

**Real-world idioms** (from dotfiles): the universal fallback is `monitor = , preferred, auto, auto`.
JaKooLit ships "magic" resolution tokens — `monitor = , highrr, auto, 1` (highest refresh rate) and
`monitor = , highres, auto, 1` (highest resolution) — for unknown hardware. For **fractional
scaling**, pair the monitor `scale` with a matching `GDK_SCALE` env so XWayland/GTK apps don't
double-scale (omarchy: `env = GDK_SCALE,2` alongside an HiDPI panel). Other real trailing args:
`addreserved, TOP BOTTOM LEFT RIGHT` (reserve space, e.g. for a bar), and named-monitor `$variables`
(`monitor = $main, 2560x1080@75, 0x0, 1`). Many rices keep `monitors.conf` separate and
**nwg-displays**-generated so a GUI owns it.

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

**Real-world idioms** (from dotfiles): common `kb_options` recipes — `caps:swapescape` or
`caps:escape` (Caps→Esc, the most popular), `compose:caps` (omarchy: Caps as Compose),
`grp:win_space_toggle` / `grp:alt_shift_toggle` paired with a **multi-layout** `kb_layout = us, es`
to cycle layouts. Sane baseline keys seen across HyDE/JaKooLit/omarchy: `accel_profile = flat`
(disable mouse acceleration; supersedes the deprecated `force_no_accel = 1`),
`numlock_by_default = true`, `repeat_rate = 50`, `repeat_delay = 300`. Full touchpad block:
`natural_scroll`, `disable_while_typing`, `tap-to-click`, `clickfinger_behavior`,
`middle_button_emulation`, `drag_lock`, `scroll_factor`. Disable a laptop touchpad via a
`device { name = …; enabled = false }` block.

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

    snap {                      # floating-window snapping (0.49+); off by default
        enabled = true
        window_gap = 10
        monitor_gap = 10
    }
}
```

**`layout = scrolling`** (Matt-FTW) is a niri-style scrolling layout but is **not** a core 0.54
layout — it's provided by a plugin (e.g. hyprscroller). Core built-ins are `dwindle` and `master`;
only emit `scrolling` when the plugin is installed.

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

**0.55+** adds **spring** animations alongside bezier curves — physics-based motion you tune by
mass/damping/stiffness rather than control points. Only use the spring form when the target is
0.55+; emit bezier curves for ≤0.54. See `deprecations.md`.

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
gesture = 3, pinchin, float, tile           # pinch to toggle float/tile (HyDE)
gesture = 4, up, dispatcher, exec, [zoom increase]   # arbitrary dispatcher (JaKooLit)
```

**Swipe tuning** still lives in the `gestures {}` block as member vars even when you use the
`gesture =` keyword (JaKooLit ships exactly this hybrid): `workspace_swipe_distance`,
`workspace_swipe_invert`, `workspace_swipe_min_speed_to_force`, `workspace_swipe_cancel_ratio`,
`workspace_swipe_create_new` (swipe past the last workspace to make a new one),
`workspace_swipe_forever`.

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
    vfr = true                     # variable frame rate (was: no_vfr inverse).
                                   # MOVED in 0.55 → `debug:vfr` (see below). Keep here on ≤0.54.
    vrr = 0                        # 0 off, 1 on, 2 fullscreen-only
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
    disable_autoreload = false
    focus_on_activate = false
    animate_manual_resizes = false
}
```

**Real-world keys** (verified on 0.54.3): `anr_missed_pings = 5` (how many missed pings before the
"app not responding" dialog), `on_focus_under_fullscreen = 1` (behaviour when a window requests
focus under a fullscreen one), `enable_swallow` + `swallow_regex` (terminal window-swallowing),
`allow_session_lock_restore = true` (recover if the lock crashes), `animate_mouse_windowdragging`,
`force_default_wallpaper = -1` (`-1` random anime mascot, `0` none). Related toggles live in their
own categories: `binds { hide_special_on_workspace_change, movefocus_cycles_fullscreen }` and
`cursor { warp_on_change_workspace, hide_on_key_press }` (all verified present on 0.54.3).

**0.55 change:** `misc:vfr` was **moved to `debug:vfr`** (reclassified as a debug variable, "not
for production"). On 0.55+ set `debug { vfr = true }`; on ≤0.54 keep `misc:vfr`. Detect with
`hyprctl version` and branch. Also removed in 0.55: `dwindle:pseudotile` (was non-functional) and
`render:cm_fs_passthrough` (now automatic under `render:cm_auto_hdr`). See `deprecations.md`.

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

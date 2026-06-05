# monitors — template

Owns `~/.config/hypr/monitors.conf`. Sourced from `hyprland.conf` (the sourcing block lives in
`../keybinds/template.md`). Output config + workspace rules + smart-gaps go here; per-app
`workspace` window rules do **not** — they live in `../window-rules/template.md`.

## monitors.conf

```ini
# Monitors: NAME, RESOLUTION@REFRESH, POSITION, SCALE
# Real names from `hyprctl monitors`. Adjust if these are placeholders.
{{monitor_lines}}

# Fallback rule for any monitor not listed above (covers hotplug / docks):
monitor = , preferred, auto, 1

{{#if workspace_rules}}
# --- Workspace rules -----------------------------------------------------------
{{workspace_rules_block}}
{{/if}}
```

## `{{monitor_lines}}` variants

Pick the form that matches `monitors.setup` and the per-entry fields in `monitors.list[]`.

```ini
# single-auto: HL picks everything (incl. fractional auto-scale)
monitor = , preferred, auto, auto

# single-specific: explicit primary
monitor = DP-1, 2560x1440@144, 0x0, 1

# dual-side-by-side: primary + second placed to its right
monitor = DP-1, 2560x1440@144, 0x0, 1
monitor = HDMI-A-1, 1920x1080@60, 2560x0, 1

# laptop HiDPI: explicit fractional scale
monitor = eDP-1, preferred, auto, 1.5
```

Use an explicit scale (`1`, `1.5`, `2`) only when the user pinned one in 1b. The shipped Hyprland
default is `monitor = , preferred, auto, auto`; `auto` lets Hyprland choose the scale (and it will
pick fractional values on its own when sensible).

## Per-monitor extra fields (1c)

Appended **after** the scale, comma-separated. Multiple extras chain on the same line.

```ini
monitor = DP-1, 2560x1440@165, 0x0, 1, vrr, 2          # adaptive sync (0 off,1 on,2 fullscreen,3 content)
monitor = DP-2, 1920x1080@60, auto, 1, transform, 1    # rotate 90° (1=90,2=180,3=270; 4-7 flipped)
monitor = HDMI-A-1, preferred, auto, 1, mirror, DP-1   # mirror another output
monitor = DP-1, 3840x2160@120, 0x0, 1, bitdepth, 10    # 10-bit color
```

## Dock/undock (1d)

Hyprland has no first-class "profiles," but `desc:` matching survives port renumbering across
docks. Pull the description from `hyprctl monitors` ("description" field) verbatim:

```ini
monitor = desc:Dell Inc. DELL U2720Q ..., 3840x2160@60, 0x0, 1.5
monitor = desc:LG Electronics LG ULTRAGEAR ..., 2560x1440@144, 3840x0, 1
monitor = , preferred, auto, 1          # catch-all so any unlisted/hotplugged panel still lights up
```

For **automatic switching on hotplug**, the user runs `kanshi` or `shikane` (named in this
component's `packages.md`). The daemon config (`~/.config/kanshi/config`) is **not authored
inline** by the rice engine — see `gotchas.md`.

## `{{workspace_rules_block}}` (1e)

Rendered only when `monitors.workspace_rules` is non-empty. The map's range keys (`"1-5"`) expand
into one `workspace = N, monitor:NAME, default:true, persistent:true` line per workspace number.

```ini
# Per-monitor binding + persistent (1-5 on the primary, 6-10 on the second)
workspace = 1, monitor:DP-1, default:true, persistent:true
workspace = 2, monitor:DP-1, persistent:true
workspace = 3, monitor:DP-1, persistent:true
workspace = 4, monitor:DP-1, persistent:true
workspace = 5, monitor:DP-1, persistent:true
workspace = 6, monitor:HDMI-A-1, default:true, persistent:true
workspace = 7, monitor:HDMI-A-1, persistent:true
workspace = 8, monitor:HDMI-A-1, persistent:true
workspace = 9, monitor:HDMI-A-1, persistent:true
workspace = 10, monitor:HDMI-A-1, persistent:true

{{#if scratchpad}}
# Named scratchpad — toggle with the special-workspace bind in binds.conf
workspace = special:magic, on-created-empty:$terminal
{{/if}}

{{#if smart_gaps}}
# Smart gaps — no gaps/border when a workspace holds a single tiled window
workspace = w[tv1], gapsout:0, gapsin:0
windowrule { name = smartgaps-noborder; match:onworkspace = w[tv1]; match:float = false; border_size = 0 }
windowrule { name = smartgaps-norounding; match:onworkspace = w[tv1]; match:float = false; rounding = 0 }
{{/if}}
```

The `windowrule { … }` block form is the **0.53+ shipped default**. On older targets fall back to
the line form (`windowrule = bordersize 0, onworkspace:w[tv1]`); see `../../_shared/version-matrix.md`
for the cliff.

## What does NOT belong here

- `windowrule = workspace 1 silent, class:^(firefox)$` (the pin-apps emissions from 1f). Lives in
  `../window-rules/template.md`; collected here, rendered there.
- `env = GDK_SCALE,N` and `xwayland { force_zero_scaling = true }`. Live in `../env/template.md`
  and the Hyprland top-level template respectively.
- The kanshi/shikane daemon config. See `gotchas.md`.

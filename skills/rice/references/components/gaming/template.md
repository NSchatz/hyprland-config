# gaming — template

This component **does not own its own `.conf` file**. It emits a fan-out of lines into five
sibling components' files, plus copies one shipped shell script into place. Every emission below
is gated on `gaming.enabled == true` *and* the per-key condition. When `gaming.enabled` is false,
every block below is a no-op.

The one thing that is **not** gated here — `misc:vfr = true` — is set unconditionally for every
user in [`../look-feel/template.md`](../look-feel/template.md) (or `debug:vfr = true` on 0.55+;
see [`_shared/version-matrix.md`](../../_shared/version-matrix.md)). It is intentionally not a
question in this group: it's the biggest idle / battery win and it benefits everyone.

## 1. `looknfeel.conf` — master tearing toggle

Owned by `look-feel`. Emit **only** when `gaming.tearing_classes` is non-empty.

```ini
general {
    allow_tearing = true     # master switch; per-class `immediate` rules in windowrules.conf
}
```

This replaces the `allow_tearing = false` default in
[`../look-feel/template.md`](../look-feel/template.md). It is a no-op without at least one
per-class `immediate` rule below — Hyprland never tears unless a window asks for it.

## 2. `windowrules.conf` — per-class tearing rules

Owned by `window-rules`. One block per entry in `gaming.tearing_classes`. Block-form is required
on 0.53+ (see [`_shared/version-matrix.md`](../../_shared/version-matrix.md)).

```ini
{{#each tearing_classes as |klass i|}}
windowrule {
    name = tear-{{i}}
    match:class = {{klass}}
    immediate = true
}
{{/each}}
```

Tearing only engages when the matched window is fullscreen and alone on its monitor — a bar or
notification on the same output suppresses it. See [`gotchas.md`](gotchas.md).

## 3. `monitors.conf` — per-monitor VRR field

Owned by `monitors`. Emit **only** when `gaming.vrr_mode != 0`. The monitors component owns the
`monitor =` line shape; this component supplies the field appended at the end.

```ini
# For every entry in monitors.list:
monitor = {{name}}, {{mode}}, {{pos}}, {{scale}}, vrr, {{vrr_mode}}
```

Modes: `1` always-on, `2` fullscreen-only, `3` content-aware (`video` / `game` content type only —
the smartest mode; default to `2` or `3`). Per-monitor overrides the global `misc:vrr`. Needs a
FreeSync / G-Sync display.

## 4. `windowrules.conf` — fullscreen effect-strip + idle inhibit

Owned by `window-rules`. Emit **only** when `gaming.strip_fullscreen_effects == true`. Four
block-form rules; do not collapse — Hyprland's window-rule processor reads one field per block.

```ini
windowrule { name = fs-noblur;   match:fullscreen = true; no_blur      = true }
windowrule { name = fs-noborder; match:fullscreen = true; no_border    = true }
windowrule { name = fs-noanim;   match:fullscreen = true; no_anim      = true }
windowrule { name = fs-idle;     match:fullscreen = true; idle_inhibit = fullscreen }
```

The `idle_inhibit = fullscreen` line is what keeps `hypridle` from blanking the screen during a
fullscreen game or video.

## 5. `binds.conf` — game-mode toggle bind

Owned by `keybinds`. Emit **only** when `gaming.gamemode_toggle == true`.

```ini
bind = $mainMod, F1, exec, ~/.config/hypr/scripts/gamemode.sh
```

The script itself is **copied verbatim** from
`${CLAUDE_PLUGIN_ROOT}/skills/rice/assets/scripts/gamemode.sh` to `~/.config/hypr/scripts/` and
`chmod +x` — there is no template substitution, see [`gotchas.md`](gotchas.md). The script is
listed in [`../utilities/README.md`](../utilities/README.md) (`Shipped scripts inventory`) but
owned by this component.

The script toggles by reading `animations:enabled`: if effects are on it disables animations,
blur, shadows, gaps, rounding, and shrinks the border to 1; if effects are already off it
restores by `hyprctl reload` (so settings can never drift).

## 6. `env.conf` — kernel-gated DRM atomic disable

Owned by `env`. Emit **only** when **both**:
- `gaming.tearing_classes` is non-empty, *and*
- the detected kernel is **< 6.8** (`KERNEL_VERSION_MAJOR < 6` OR
  (`KERNEL_VERSION_MAJOR == 6` AND `KERNEL_VERSION_MINOR < 8`)).

```ini
env = WLR_DRM_NO_ATOMIC,1
```

**Do not emit on kernel ≥ 6.8.** Atomic modesetting on modern kernels supports tearing natively;
forcing the legacy DRM path on a 6.8+ kernel regresses VRR and multi-monitor behaviour. See
[`gotchas.md`](gotchas.md).

## 7. `~/.config/hypr/scripts/gamemode.sh` — script copy

Emit **only** when `gaming.gamemode_toggle == true`.

```bash
install -Dm 0755 \
  "$CLAUDE_PLUGIN_ROOT/skills/rice/assets/scripts/gamemode.sh" \
  "$HOME/.config/hypr/scripts/gamemode.sh"
```

The script is listed, not rendered — keep its source under
`skills/rice/assets/scripts/gamemode.sh` and copy verbatim. Same pattern as the
[`utilities`](../utilities/) scripts.

## What does NOT belong here

- `misc:vfr = true` — set unconditionally in [`../look-feel/template.md`](../look-feel/template.md).
- The `cursor:no_hardware_cursors` workaround for NVIDIA / nouveau — emitted by `look-feel` based
  on detection, not by this component.
- Launch-wrapper tools (`gamemoderun`, `mangohud`, `gamescope`) — these are **Steam launch
  options**, documented to the user but not written to any `.conf`. The optional system service
  `gamemoded` lives in [`packages.md`](packages.md).
- The global `misc:vrr` key — per-monitor `vrr` field overrides it; we don't emit a global value.

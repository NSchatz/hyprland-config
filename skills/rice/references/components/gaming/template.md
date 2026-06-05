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

Verified against the
[main Variables.md → general](https://raw.githubusercontent.com/hyprwm/hyprland-wiki/main/content/Configuring/Basics/Variables.md):
*"allow_tearing — master switch for allowing tearing to occur. See the Tearing page. bool
`false`"*. Replaces the `allow_tearing = false` default in
[`../look-feel/template.md`](../look-feel/template.md). It is a no-op without at least one
per-class `immediate` rule below — the
[Tearing wiki](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/) is explicit:
*"Set `general.allow_tearing` to `true`. This is a 'master toggle'. Add an `immediate`
windowrule effect to your game of choice."*

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

The field name is `immediate` (boolean) — verified against the
[main Window-Rules.md → Dynamic effects](https://raw.githubusercontent.com/hyprwm/hyprland-wiki/main/content/Configuring/Basics/Window-Rules.md):
*"immediate — boolean — Forces the window to allow tearing."* The legacy field name
`immediate_render` is **not** valid in any 0.53+ target. The 0.54 wiki uses the form
`windowrule = match:class cs2, immediate yes` in its example, which maps 1-to-1 onto the block
form above.

Tearing only engages when the matched window is fullscreen and alone on its monitor — a bar or
notification on the same output suppresses it. See [`gotchas.md`](gotchas.md).

## 3. `monitors.conf` — per-monitor VRR field

Owned by `monitors`. Emit **only** when `gaming.vrr_mode != 0`. The monitors component owns the
`monitor =` line shape; this component supplies the field appended at the end.

```ini
# 0.53/0.54 hyprlang form — for every entry in monitors.list:
monitor = {{name}}, {{mode}}, {{pos}}, {{scale}}, vrr, {{vrr_mode}}
```

```lua
-- 0.55+ lua form — keyword field on the table:
hl.monitor({ output = "{{name}}", mode = "{{mode}}", position = "{{pos}}",
             scale = {{scale}}, vrr = {{vrr_mode}} })
```

Modes (verified against
[main Configuring/Basics/Variables.md](https://raw.githubusercontent.com/hyprwm/hyprland-wiki/main/content/Configuring/Basics/Variables.md),
`misc.vrr`): `0` off, `1` always-on, `2` fullscreen-only, `3` fullscreen with `video` or `game`
content type (smartest — avoids desktop/browser flicker). Per-monitor overrides the global
`misc.vrr`. Needs a FreeSync / G-Sync display. The per-monitor field syntax `, vrr, N` is
verified against the
[0.54 Monitors wiki](https://wiki.hypr.land/0.54.0/Configuring/Monitors/): *"Per-display VRR
can be done by adding `, vrr, X` where X is the mode from the variables page."*

## 4. `windowrules.conf` — fullscreen effect-strip + idle inhibit

Owned by `window-rules`. Emit **only** when `gaming.strip_fullscreen_effects == true`. Five
block-form rules; do not collapse — Hyprland's window-rule processor reads one field per block.

```ini
windowrule { name = fs-noblur;     match:fullscreen = true; no_blur      = true }
windowrule { name = fs-noborder;   match:fullscreen = true; border_size  = 0 }
windowrule { name = fs-norounding; match:fullscreen = true; rounding     = 0 }
windowrule { name = fs-noanim;     match:fullscreen = true; no_anim      = true }
windowrule { name = fs-noshadow;   match:fullscreen = true; no_shadow    = true }
windowrule { name = fs-idle;       match:fullscreen = true; idle_inhibit = fullscreen }
```

There is **no** `no_border` window-rule field on any 0.53+ target (verified against the 0.54
and main wiki Window-Rules pages). Borders are stripped via `border_size = 0`. `rounding = 0`
is included so the corner curve doesn't render over a borderless fullscreen surface. The
`idle_inhibit = fullscreen` line is what keeps `hypridle` from blanking the screen during a
fullscreen game or video; legal modes are `none | always | focus | fullscreen` (per the wiki
Dynamic effects table).

> Cross-component note: `window-rules/template.md` already ships an unconditional
> `idleinhibit-fullscreen` block in its defaults — see the duplication flag in the changes
> report. When `gaming.strip_fullscreen_effects` is true and the shipped default is also
> present, the writer should skip emitting the duplicate `fs-idle` block.

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

## 6. `env.conf` — nothing to emit

There is **no env var** to emit for tearing. Hyprland uses **aquamarine** (not wlroots) for
its DRM backend since v0.42 — well before this plugin's 0.53+ target floor — so the legacy
`WLR_DRM_NO_ATOMIC=1` variable is a no-op (verified: the var name is not present in any
Hyprland or aquamarine wiki page; see
[`../env/gotchas.md`](../env/gotchas.md) "2026 slim NVIDIA set").

The aquamarine equivalent is `AQ_NO_ATOMIC=1`, but the [Environment-variables wiki
page](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/) explicitly
flags it "**NOT** recommended" — vaxerski's own answer in
[hyprwm/Hyprland #7186](https://github.com/hyprwm/Hyprland/discussions/7186) reads
*"AQ_NO_ATOMIC, but not recommended as it is not very well supported."* Do **not** emit it
from this component.

If a user on a very old kernel reports tearing freezing fullscreen games, the
[wiki Tearing page](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/) says this is
a GPU-driver limitation, not a Hyprland one — recommend reverting the per-class `immediate`
rule rather than reaching for legacy env vars.

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

- `misc:vfr = true` / `debug:vfr = true` — set unconditionally in
  [`../look-feel/template.md`](../look-feel/template.md). VFR (variable frame rate) and the
  tearing/VRR knobs above are **independent**: VFR throttles idle redraws to save battery; VRR
  matches monitor refresh to GPU output for smoothness; tearing skips vsync for input latency.
  None of them conflict.
- The `cursor:no_hardware_cursors` workaround for NVIDIA / nouveau — emitted by `look-feel` based
  on detection, not by this component. There is also a related upstream `cursor:no_break_fs_vrr`
  (default `2` = auto, on for content type 'game') that mitigates cursor-induced framerate
  spikes under VRR — also owned by `look-feel`, not us.
- Launch-wrapper tools (`gamemoderun`, `mangohud`, `gamescope`) — these are **Steam launch
  options**, documented to the user but not written to any `.conf`. The optional daemon
  `gamemoded` (D-Bus activated) lives in [`packages.md`](packages.md).
- The global `misc.vrr` key — per-monitor `vrr` field overrides it; we don't emit a global value.
  (Spelled `misc.vrr` in main / `misc:vrr` in 0.54 hyprlang — same key, two syntactic forms.)
- Any env var — Hyprland is aquamarine-based since 0.42 so `WLR_DRM_NO_ATOMIC` is a no-op, and
  the aquamarine equivalent `AQ_NO_ATOMIC` is upstream-flagged "**NOT** recommended". See §6
  above and [`gotchas.md`](gotchas.md).

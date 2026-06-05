# gaming — gotchas

## `WLR_DRM_NO_ATOMIC` is gated on kernel < 6.8 — never blindly emit it

The `env = WLR_DRM_NO_ATOMIC,1` line forces the legacy DRM modeset path. On kernels **< 6.8** it
was needed for tearing to engage at all; on **≥ 6.8** atomic modesetting handles tearing natively
and forcing the legacy path **regresses VRR, multi-monitor, and HDR**. Read
`KERNEL_VERSION_MAJOR` / `KERNEL_VERSION_MINOR` from `detect-version.sh` and gate the env emission
on **`major < 6` OR (`major == 6` AND `minor < 8`)**. The env component is the file owner, but the
gate condition lives here — make sure both ends agree.

## VRR is a per-monitor field, not its own block

VRR in Hyprland is set as the **last field on a `monitor =` line**, not as a `misc:vrr` global or
its own `vrr {}` block. The monitors component owns the `monitor =` shape; this component just
supplies the integer (`2` for fullscreen, `3` for content-aware). Practical consequences:

- A user with a FreeSync display *and* a fixed-refresh one wants `vrr_mode` per-monitor — but the
  current schema is a single `gaming.vrr_mode` applied to every monitor. Document that they can
  hand-edit `monitors.conf` afterwards to drop the `vrr` field from the fixed-refresh line.
- It needs a FreeSync / G-Sync display. Hyprland cannot reliably query VRR capability, so the
  interview **asks** rather than detects.
- VRR + hardware cursors can stutter on NVIDIA. The `cursor:no_hardware_cursors = true` mitigation
  is emitted by `look-feel` based on `CURSOR_NO_HARDWARE_RECOMMENDED=1` from detection, *not* by
  this component — but the two interact, so if the user picks VRR-on and the GPU is NVIDIA, both
  emissions should fire.

## `gamemode.sh` ships as a plugin template file — copy + chmod, do not render

The script under `${CLAUDE_PLUGIN_ROOT}/skills/rice/assets/scripts/gamemode.sh` is a **shipped
asset**, not a Handlebars template. Install is `install -Dm 0755 <src> <dst>` (or `cp` + `chmod
+x`) — there is no palette substitution, no per-user values. Same pattern as the
[`utilities`](../utilities/) scripts (`screenshot.sh`, `colorpicker.sh`, etc). Editing the script
should happen by editing the shipped file in the plugin and re-running install, not by patching
the rendered output. Listed in
[`../utilities/README.md`](../utilities/README.md)'s `Shipped scripts inventory` for discoverability.

## Fullscreen effect-strip rules go in `windowrules.conf`, not `looknfeel.conf`

The four `match:fullscreen = true; no_blur / no_border / no_anim / idle_inhibit` rules are
**`windowrule` blocks**, not `decoration {}` knobs. They belong in `windowrules.conf` (owned by
[`window-rules`](../window-rules/)). A common mistake: dropping them into the `decoration {}`
block of `looknfeel.conf`, where they silently no-op and the user wonders why blur is still on in
fullscreen.

## Tearing class regexes come from the user via `hyprctl clients`

The interview suggests `hyprctl clients | grep class` as the discovery path. Common patterns to
seed:

```
^(cs2)$
^(steam_app_\d+)$
^(gamescope)$
^(dota2)$
^(factorio)$
```

Surface the user's input **as-given** to the windowrule `match:class` field — do not auto-anchor
with `^…$` if the user didn't, and do not lowercase. A bad pattern silently matches nothing
(easier to debug than the opposite — a too-broad pattern tearing the desktop).

A content-type rule (`match:content = game`) is more general but evaluates *once at map time*;
many games don't advertise `content:game` until after mapping, so the per-class rule is the
reliable form. The template emits only per-class — content-type rules are a documented manual
addition, not generated.

## `misc:vfr = true` is **not** gated by this component

`misc:vfr = true` (or `debug:vfr = true` on 0.55+ — see
[`_shared/version-matrix.md`](../../_shared/version-matrix.md)) is the **single biggest idle /
battery win** and is **always on for every user**. It's a default in
[`../look-feel/template.md`](../look-feel/template.md), *not* a question in group 20.
Specifically:

- A user who picks "No, skip" on **20a** still gets `misc:vfr = true` from `look-feel`. That is
  correct — do not interpret 20a-no as turning vfr off.
- Re-asking it here would be a behaviour regression; the interviewer agent should treat any
  attempt to surface it in group 20 as a bug.

## Tearing only engages when the game is fullscreen and alone on its monitor

`allow_tearing = true` plus a per-class `immediate` rule is necessary but not sufficient — any
bar, notification, or floating window on the same output suppresses tearing. Document this to the
user when 20b is answered "On for specific games". If a game *freezes* instead of tearing, the
GPU driver doesn't support tearing on this kernel / Hyprland combination — recommend turning the
class rule back off rather than continuing to debug.

# Gaming & performance

The opt-in tweaks that competitive/gaming users expect and a generator usually omits: screen tearing
for latency, VRR/adaptive sync, fullscreen effect-stripping, and a runtime "game mode" toggle.
**Group 20** of the interview decides these; it's gated behind a single opt-in so non-gamers never see
it. All output is 0.54 hyprlang, block-form rules. Detection feeds the defaults (`GPU_DRIVER`,
`NVIDIA_PROPRIETARY` — the NVIDIA *env* block lives in group 15, not here).

## 1. Screen tearing (latency)

Two parts, **both required** — a master switch plus a per-game rule:

```ini
general {
    allow_tearing = true          # master toggle (default false)
}
# block-form window rule (0.53+) — tears only this app:
windowrule {
    name = tear-cs2
    match:class = ^(cs2)$
    immediate = true
}
```

Facts to encode and tell the user:
- Tearing **only engages when the game is fullscreen and alone on its monitor** — any bar/notification
  on that output suppresses it.
- It's GPU-driver-dependent and officially experimental. If a game *freezes* instead of tearing, the
  driver doesn't support it — turn it back off.
- Kernels **< 6.8** also need `env = WLR_DRM_NO_ATOMIC,1`. On a modern kernel (≥6.8) do **not** emit
  this — gate it on the detected kernel version, never blindly.
- A content-type rule (`match:content = game`) is more general but evaluates *once at map time*; many
  games don't advertise `content:game` until after mapping, so a per-class rule is the reliable form.
  Emit both when possible (class rule + content fallback).

Ask which game classes to tear (get classes from `hyprctl clients`, or common ones: `^(cs2)$`,
`^(steam_app_\d+)$`, `^(gamescope)$`).

## 2. VRR / adaptive sync

Per-monitor is the preferred granularity (overrides the global `misc:vrr`):

```ini
monitor = DP-1, 2560x1440@165, 0x0, 1, vrr, 2
```
Modes: `0` off · `1` always · `2` fullscreen only · `3` fullscreen only for `video`/`game` content
(the safest "smart" mode — avoids VRR flicker on the desktop/browser). Default to `2` or `3`. VRR
capability isn't reliably queryable, so **ask** (note it needs a FreeSync/G-Sync display). Caveat to
document: VRR + hardware cursors can stutter — pairs with `cursor:no_break_fs_vrr` (default auto) and,
on NVIDIA, `cursor:no_hardware_cursors` (already recommended by detection on nvidia/nouveau).

## 3. Fullscreen effect-stripping + idle inhibit

Cheap, broadly desirable — strip expensive effects on fullscreen windows and don't sleep mid-game/video
(these can ship as defaults in `windowrules.conf`, but surface them as a question so the user knows):

```ini
windowrule { name = fs-noblur;   match:fullscreen = true; no_blur = true }
windowrule { name = fs-noborder; match:fullscreen = true; no_border = true }
windowrule { name = fs-noanim;   match:fullscreen = true; no_anim = true }
windowrule { name = fs-idle;     match:fullscreen = true; idle_inhibit = fullscreen }
```

## 4. `misc:vfr` (always-on perf win)

`misc { vfr = true }` (variable frame rate — drops frame submission when the screen is static) is the
single biggest idle/battery win and should be **on for everyone**, not just gamers. It's a default, not
a question — make sure the generated `looknfeel`/`misc` block sets it.

## 5. Game-mode toggle script

The dominant community pattern — a key that disables animations/blur/shadows/rounding/gaps and restores
by reloading the config. Ships as a plugin template file: `assets/scripts/gamemode.sh`. Install like
the group-18 utilities (copy → `~/.config/hypr/scripts/`, `chmod +x`) and bind:

```ini
bind = $mainMod, F1, exec, ~/.config/hypr/scripts/gamemode.sh
```

## 6. Launch-wrapper tools (document, don't configure)

Not hyprland.conf settings — mention for completeness: **feral gamemode** (`gamemoderun %command%`),
**MangoHud** (`mangohud %command%`), **gamescope** (`gamescope -W … -H … -f -- %command%`, which does
its own VRR/tearing so the rules above are redundant inside it). These are Steam launch options; the
generator documents them, it doesn't write them.

## Group 20 question (how to ask)

**Call 1 — the gate (single question):**
**20a. Set up gaming/performance tweaks?** — No, skip **(default)** · Yes.

**Call 2 (only if yes):**
**20b. Screen tearing** — Off **(default)** · On for specific games (ask the classes). *(Sets
`allow_tearing` + per-class `immediate` rule; gate the `WLR_DRM_NO_ATOMIC` env on kernel < 6.8.)*
**20c. VRR / adaptive sync** — Off **(default)** · Fullscreen (`2`) · Content-aware (`3`). *(Needs a
FreeSync/G-Sync monitor; per-monitor field.)*
**20d. Strip effects on fullscreen + inhibit idle?** — Yes **(default)** · No. *(The §3 rules.)*
**20e. Game-mode toggle key?** — Yes, bind `SUPER+F1` **(default)** · No. *(Installs `gamemode.sh`.)*

`misc:vfr = true` is set unconditionally regardless of these answers. Validate the generated files
(`hyprctl reload` + `configerrors`) after writing.

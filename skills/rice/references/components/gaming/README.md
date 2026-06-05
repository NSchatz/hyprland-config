# gaming

**OPT-IN** — the latency/perf tweaks competitive and gaming users expect and a generator usually
omits: screen tearing, VRR / adaptive sync, fullscreen effect-stripping, and a runtime "game mode"
toggle bound to `SUPER+F1`. Gated behind a single yes/no question (20a) so non-gamers never see
the sub-questions. On `no`, only `enabled: false` lands in `answers.json` and nothing in this
folder generates output.

Most of what this component does is *tweak existing files* — it doesn't own its own `.conf`. It
appends to `looknfeel.conf`, `windowrules.conf`, `monitors.conf`, `binds.conf`, and (kernel-gated)
`env.conf`, and copies one shell script into `~/.config/hypr/scripts/`.

The biggest single perf win — `misc:vfr = true` — is **not** gated by this component; it's a
default in the `look-feel` template for every user, gamer or not.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Gate (20a) + four sub-questions (20b–20e) asked only on yes. |
| `schema.md` | The `gaming.{enabled, tearing_classes, vrr_mode, strip_fullscreen_effects, gamemode_toggle}` slice. |
| `template.md` | The lines emitted *into other components' files* — `allow_tearing`, per-class `immediate` rules, per-monitor `vrr` field, fullscreen effect-strip rules, the `SUPER+F1` bind, and the kernel-gated `WLR_DRM_NO_ATOMIC` env line. |
| `gotchas.md` | Kernel gate on `WLR_DRM_NO_ATOMIC`, per-monitor VRR placement, `gamemode.sh` ships as a copy-not-render template, where the fullscreen rules actually go, where to source tearing classes, and the `misc:vfr` non-gate. |
| `packages.md` | None (Hyprland-internal). Optional `gamemoded` if the user wants the system service. |

## Where this component lands

- **`looknfeel.conf`** (owned by `look-feel`): adds `general:allow_tearing = true` when any
  tearing classes were given. The unconditional `misc:vfr = true` is set there too, but as a
  baseline — not via this component.
- **`windowrules.conf`** (owned by `window-rules`): per-class `immediate = true` rules (one per
  entry in `gaming.tearing_classes`) and the four fullscreen effect-strip rules when
  `strip_fullscreen_effects` is true.
- **`monitors.conf`** (owned by `monitors`): the `, vrr, <N>` field appended to every `monitor =`
  line when `vrr_mode != 0`. The monitors component owns the line; this component supplies the
  integer.
- **`binds.conf`** (owned by `keybinds`): the `bind = $mainMod, F1, exec, ~/.config/hypr/scripts/gamemode.sh`
  line when `gamemode_toggle` is true.
- **`env.conf`** (owned by `env`): `env = WLR_DRM_NO_ATOMIC,1` — **only on kernels < 6.8**, never
  on modern kernels.
- **`~/.config/hypr/scripts/gamemode.sh`**: copy (`cp` + `chmod +x`) of
  `${CLAUDE_PLUGIN_ROOT}/skills/rice/assets/scripts/gamemode.sh`. No template substitution.

## Related components

- [`look-feel`](../look-feel/) — owns `looknfeel.conf` (`allow_tearing` lands there; `misc:vfr` is
  its baseline).
- [`window-rules`](../window-rules/) — owns `windowrules.conf` (per-class tearing + fullscreen
  effect-strip rules land there).
- [`monitors`](../monitors/) — owns `monitors.conf` (per-monitor `vrr` field).
- [`keybinds`](../keybinds/) — owns `binds.conf` (`SUPER+F1` lands there).
- [`env`](../env/) — owns `env.conf` (`WLR_DRM_NO_ATOMIC` lands there, kernel-gated).
- [`utilities`](../utilities/) — the copy-not-render script install pattern is shared with this
  component's `gamemode.sh`.

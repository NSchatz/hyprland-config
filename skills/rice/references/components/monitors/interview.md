# monitors — interview

Six sub-questions. Cap is 4 per `AskUserQuestion` call, so this component takes **two passes** at
minimum (1a–1d, then 1e–1f), or three if multi-monitor extras (1c) is a separate call. Every
sub-question is asked — `(default)` reorders options, it does not skip the question (see
`../../_interview-protocol.md`).

Detection (`scripts/detect-version.sh`) reports `MONITOR_COUNT`; only ask 1c when
`MONITOR_COUNT > 1` **or** the user describes more than one display in 1a. Detected monitor
names from `hyprctl monitors` should appear pre-filled in the option list; if detection failed,
use placeholders (`DP-1`, `HDMI-A-1`, `eDP-1`) and note "adjust after first reload."

## Sub-questions

**1a. Monitor setup** — reorder so the *detected native mode* is the first option when
`hyprctl monitors` reports one (defect #9; native almost always beats `highrr` because
high-refresh-rate signalling is usually only available at lower resolutions on ultrawide /
4K panels, and `highrr` will silently downgrade resolution for the refresh win — see
`gotchas.md`).

- **Pin the detected native mode** (e.g. `3440x1440@60`) → `monitor = NAME, <native>, auto, auto`
  — listed first when detection reports the current preferred mode; this is the recommended
  pick for most displays.
- Single monitor, auto-detect → `monitor = , preferred, auto, auto`
- Single, specific resolution/refresh → ask res + refresh (e.g. `2560x1440@144`)
- Dual side-by-side → ask both names/res; place the second at `<width>x0`
- More than two / complex → collect each monitor's name, mode, position, scale

The `highrr` / `highres` / `maxwidth` "magic" modes pick from the EDID mode list when the user
doesn't want to pin a specific mode:

- `highres` — **highest resolution; recommended** for most displays. Picks the panel's native
  resolution at the *best* refresh rate available *at that resolution*.
- `highrr` — **highest refresh rate; may drop resolution.** Useful when frame rate matters more
  than pixel count (some games), but on an ultrawide / 4K / OLED panel the highest advertised
  refresh is often only available at 1080p, so `highrr` silently picks `1920x1080@<hz>` on a
  `3440x1440` panel. Surface as opt-in for "I'd rather have refresh than resolution."
- `maxwidth` — widest horizontal resolution. Niche; useful for ultrawide-aware setups.

Use detected names where possible (the catch-all `monitor = , …` form is a safety net, not the
preferred shape — see `gotchas.md` "Use detected names").

**1b. Fractional scaling?** (HiDPI / laptop panels)
- No, scale 1 **(default)**
- Yes, 1.5
- Yes, 2
- Custom (ask the float)

A non-1 scale here triggers two downstream emissions (see `gotchas.md`): `env = GDK_SCALE,N`
in `../env/` and `xwayland { force_zero_scaling = true }` in the Hyprland top-level template.

**1c. Per-monitor extras** (multi-select, off by default; **ask only when `MONITOR_COUNT > 1`**)
- VRR / adaptive sync (`vrr, 2` = fullscreen-only, `3` = fullscreen with `video`/`game` content
  type; needs FreeSync/G-Sync hardware + a `misc:vrr` global that permits per-monitor override)
- Rotation (`transform, 1` = 90°, `2` = 180°, `3` = 270°; `4`–`7` flipped variants)
- Mirroring (`mirror, <other>`)
- 10-bit color (`bitdepth, 10` — 8 or 10 only)
- ICC profile (`icc, /absolute/path.icm` — forces sRGB EOTF; overrides any `cm` preset)

**1d. Dock/undock?**
- No **(default)**
- Yes → emit `desc:`-based monitor rules (survive port renumbering) + a catch-all
  `monitor = , preferred, auto, 1`. For auto-switch on hotplug, name `kanshi` or `shikane`
  (this component's `packages.md` carries them). Don't author the daemon config inline.

**1e. Workspace rules?**
- None **(default)**
- Bind workspaces to monitors (e.g. 1–5 → primary, 6–10 → second) + make them **persistent**
- Add a named scratchpad (`special:magic`)
- Add smart gaps (no gaps/border when one tiled window)

The block goes in `monitors.conf` (see `template.md`).

**1f. Pin apps to workspaces?**
- No **(default)**
- Yes → collect `class -> workspace` pairs (e.g. browser → 1, chat → 9)

These emit per-app `workspace N silent` **window rules** in `windowrules.conf` (owned by
`../window-rules/`). The complementary "launch an app when a workspace is first opened" is
`on-created-empty:` in the workspace rule itself (see `template.md` — it stays here). Pairs
naturally with persistent workspaces (1e).

## Record paths

After each `AskUserQuestion`, record the answer with `record-answer.sh`:

```bash
# 1a
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" monitors.setup single-auto
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" monitors.list --json \
  '[{"name":"DP-1","mode":"2560x1440@144","pos":"0x0","scale":1.0,"transform":0,"vrr":0,"bitdepth":8}]'

# 1b
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" monitors.scaling --json 1.5

# 1c — fold extras into the matching monitors.list entry (transform/vrr/bitdepth fields)
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" monitors.list --json \
  '[{"name":"DP-1","mode":"2560x1440@165","pos":"0x0","scale":1.0,"transform":0,"vrr":2,"bitdepth":10}]'

# 1d
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" monitors.dock_undock --json true

# 1e
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" monitors.workspace_rules --json \
  '{"1-5":"DP-1","6-10":"HDMI-A-1","scratchpad":true,"smart_gaps":true}'

# 1f
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" monitors.pin_apps --json \
  '{"firefox":1,"thunderbird":9}'
```

If 1e or 1f is "No," still record an explicit empty value — `--json '{}'` for `workspace_rules`
and `pin_apps`, `--json false` for `dock_undock`. Never leave the key absent.

## Cross-references

- Schema → `schema.md`
- The `monitors.conf` template + workspace-rule block + dock/undock `desc:` form → `template.md`
- Fractional-scale, detected-names, kanshi/shikane → `gotchas.md`
- `GDK_SCALE` line → `../env/template.md`
- Per-app workspace pin rules → `../window-rules/template.md`
- Packages → `packages.md`

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

**1a. Monitor setup**
- Single monitor, auto-detect **(default)** → `monitor = , preferred, auto, auto`
- Single, specific resolution/refresh → ask res + refresh (e.g. `2560x1440@144`)
- Dual side-by-side → ask both names/res; place the second at `<width>x0`
- More than two / complex → collect each monitor's name, mode, position, scale

For unknown hardware the `, highrr, auto, 1` / `, highres, auto, 1` / `, maxwidth, auto, 1`
"magic" modes pick the highest refresh / highest resolution / widest resolution from the EDID
mode list. Use detected names where possible.

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

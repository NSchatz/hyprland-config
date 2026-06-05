# gaming — interview

Group 20. **Opt-in gate** — one yes/no question first; the four sub-questions are asked only on
yes. The gate itself is **always asked** (per the strict-no-defaulting rule in
[`_interview-protocol.md`](../../_interview-protocol.md)) — never skip it because the user
"doesn't sound like a gamer".

Detection is informational only: nothing here is reordered or hidden by `GPU_DRIVER`,
`HAS_GAMEPAD`, or anything else. `KERNEL_VERSION` from `detect-version.sh` only affects whether
the `WLR_DRM_NO_ATOMIC` env line gets emitted later — it does not change the questions.

## Sub-questions

### Call 1 — the gate (always asked)

**20a. Set up gaming / performance tweaks?**
- No, skip **(default)**
- Yes

On **no** → record `gaming.enabled = false` and skip the rest of this component.
On **yes** → continue to Call 2.

### Call 2 — only on yes (4 sub-questions; respects the ≤ 4 cap)

**20b. Screen tearing** — for max-input-latency-sensitive games. Tearing only engages when the
game is fullscreen and alone on its monitor; if a game *freezes* instead of tearing, the GPU
driver doesn't support it.
- Off **(default)**
- On for specific games — ask the user for window classes (suggest `hyprctl clients` to discover,
  or common ones: `^(cs2)$`, `^(steam_app_\d+)$`, `^(gamescope)$`)

**20c. VRR / adaptive sync** — needs a FreeSync / G-Sync display (the interviewer should mention
this; VRR capability isn't reliably queryable from Hyprland).
- Off (`0`) **(default)**
- Fullscreen only (`2`)
- Content-aware (`3`, smartest — avoids desktop/browser flicker)

**20d. Strip effects on fullscreen + inhibit idle?** — emits the four `no_blur` / `no_border` /
`no_anim` / `idle_inhibit` fullscreen rules in `windowrules.conf`. Broadly desirable; safe even
for non-gamers who turned this group on for VRR alone.
- Yes **(default)**
- No

**20e. Game-mode toggle key?** — installs `assets/scripts/gamemode.sh` (copy + `chmod +x`) and
binds it. Toggles animations/blur/shadows/rounding/gaps off; re-press reloads the config to
restore.
- Yes, bind `SUPER+F1` **(default)**
- No

## Record paths

After **20a**:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" \
  gaming.enabled --json true     # or false on the "skip" branch
```

After **20b** (on yes — record the classes the user named as a JSON array; record `[]` if the
user picked "Off"):

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" \
  gaming.tearing_classes --json '["^(cs2)$","^(steam_app_\\d+)$"]'
```

After **20c** (the integer `0`, `2`, or `3` — never `1` from this question; `1` is "always on"
and is not offered as a default-friendly pick):

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" \
  gaming.vrr_mode --json 2
```

After **20d**:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" \
  gaming.strip_fullscreen_effects --json true
```

After **20e**:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" \
  gaming.gamemode_toggle --json true
```

On the **no** branch of 20a, record the remaining keys as their off-defaults so downstream
readers don't have to branch on key presence:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" gaming.tearing_classes          --json '[]'
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" gaming.vrr_mode                  --json 0
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" gaming.strip_fullscreen_effects  --json false
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" gaming.gamemode_toggle           --json false
```

## Cross-references

- Schema → [`schema.md`](schema.md)
- Where each answer lands (file by file) → [`template.md`](template.md)
- Kernel gate on `WLR_DRM_NO_ATOMIC`, VRR-per-monitor caveats, `misc:vfr` non-gate →
  [`gotchas.md`](gotchas.md)
- Packages (none, possibly `gamemoded`) → [`packages.md`](packages.md)
- Strict-no-defaulting rule → [`../../_interview-protocol.md`](../../_interview-protocol.md)

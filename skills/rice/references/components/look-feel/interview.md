# look-feel — interview

**10 sub-questions, 3 `AskUserQuestion` calls (4 + 3 + 3).** This is the largest interview group.
Both Mode A (full interview) and Mode B (re-theming) walk it.

**Strict no-defaulting.** Every sub-question gets asked — including 11i (per-app rules) and 11j
(blur toggle). The `(default)` marker on an option only sets the order of the option list so the
user can confirm with one press; it never authorizes skipping the question. See
[`_interview-protocol.md`](../../_interview-protocol.md) ("Strict — ask every question. Never
silently default.").

## Call 1 — gaps / rounding / blur+shadows / opacity (4 sub-qs)

**11a. Gaps & borders.**
- Comfortable — `gaps_in 5 / gaps_out 20 / border 2` **(default)**
- Tight — `2 / 6 / 1`
- None — `0 / 0 / 1`
- Spacious — `8 / 30 / 3`

Rhythm: `gaps_out ≈ 2× gaps_in`; rounding tracks `gaps_out`.

**11b. Corner rounding.**
- Rounded — `rounding = 10` **(default)**
- Subtle — `rounding = 5`
- Square — `rounding = 0`

On 0.5x targets also emit `rounding_power = 2` (bump to 2.3–4 for a softer "squircle"). See
[`_shared/version-matrix.md`](../../_shared/version-matrix.md) (0.53+ added `rounding_power`).

**11c. Blur & shadows.**
- Both on **(default)**
- Blur on, shadows off
- Both off (lighter on weak GPUs)

"Frosted" preset: `blur { size = 6; passes = 2 }`. Pair window opacity with blur — blur is a no-op
on opaque windows (see `gotchas.md`).

**11d. Window opacity.**
- Opaque 1.0 / 1.0 **(default)**
- Slightly translucent inactive — `active 1.0 / inactive 0.9`

Keep content windows opaque; terminals can be translucent per-app via window rules.

## Call 2 — animations / border colour / layout (3 sub-qs)

**11e. Animations.**
- On, smooth defaults **(default)**
- On, snappy/fast — multiply speeds by ~0.6
- Off — `animations { enabled = false }`, drop the curve lines

Curve families: shipped `easeOutQuint`; the `wind / winIn` slide-overshoot family; Material-3
`md3_decel` / `md3_accel`.

**11f. Border colour.**
- From my palette **(default)** → `col.active_border = $accent $accent2 45deg` (the engine's
  `colors.conf` exports these — the border re-themes for free; see
  [`_shared/colors-contract.md`](../../_shared/colors-contract.md))
- Custom gradient — free text, e.g. `rgba(33ccffee) rgba(00ff99ee) 45deg`

**11g. Layout.**
- Dwindle (BSP-like) **(default)**
- Master / stack — follow-up sub-pick: `orientation = left | right | top | bottom | center`
- Scrolling (niri/PaperWM-style) — **core in 0.53+, not a plugin** (safe uncommented; see
  `_shared/version-matrix.md`)
- `hy3` tree-style — *plugin only*, gated through `components/plugins/`; do NOT offer here unless
  the user already enabled the plugins gate

## Call 3 — groups / per-app rules / blur toggle (3 sub-qs)

**11h. Window groups / tabs?**
- No **(default)**
- Yes — enable groups + a themed `groupbar`; `keybinds` adds `SUPER+G` → `togglegroup` and
  `SUPER+TAB` → `changegroupactive`. Core Hyprland; groupbar themes from the palette.

**11i. Per-app window rules?** *(always asked — skippable answer = empty array)*

Beyond the shipped defaults (float `pavucontrol` / dialogs, PiP pin, idleinhibit-on-fullscreen),
ask if any apps should always **float / pin / be sent to a workspace / be translucent**. Collect
`{ class, effects[] }` pairs. The user can say "none" (record `[]`) — that's a valid answer and
the question still gets asked.

**11j. Runtime blur toggle?**
- No **(default)**
- Yes — `SUPER+SHIFT+B` toggles blur (weak-GPU / screenshot convenience). Installs
  `assets/scripts/blur-toggle.sh`. The toggle is transient: a reload restores the user's real
  setting. (The heavier animation-preset switcher is intentionally deferred — the gaming-component
  "game mode" already covers "all effects off".)

## Record paths

After each `AskUserQuestion` call, persist with `record-answer.sh`:

```bash
# Call 1
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" look_feel.gaps_preset comfortable
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" look_feel.rounding rounded
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" look_feel.blur_shadows both-on
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" look_feel.opacity \
    --json '{"active":1.0,"inactive":1.0}'

# Call 2
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" look_feel.animations smooth
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" look_feel.border_color palette
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" look_feel.layout dwindle
# If layout == master, also:
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" look_feel.master_orientation left

# Call 3
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" look_feel.groups --json false
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" look_feel.per_app_rules \
    --json '[{"class":"firefox-developer-edition","effects":["pin"]}]'
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" look_feel.blur_toggle --json false
```

For 11i with no extras, record `--json '[]'` — the empty array is a valid answer and downstream
code checks the array length, not key presence.

## Cross-references

- Schema → `schema.md`
- Full `looknfeel.conf` template + version branches → `template.md`
- Cursor / VFR / pseudotile gotchas → `gotchas.md`
- Block-form `windowrule {}` emission (consumes `per_app_rules`) → `../window-rules/template.md`
- `SUPER+G` / `SUPER+TAB` / `SUPER+SHIFT+B` binds → `../keybinds/template.md`
- Palette wiring (`$accent` etc.) → `../../_shared/colors-contract.md`

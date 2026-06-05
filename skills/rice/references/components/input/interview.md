# input — interview

Up to **7 sub-questions** (2a–2g). The `AskUserQuestion` tool caps at 4 sub-questions per call,
so this component is split across **two consecutive calls** (4 + 3). Every sub-question is asked
— no silent defaulting (see `_interview-protocol.md` → "Strict — ask every question").

The gesture sub-question (2g) self-skips on a desktop with no touchpad. Touchpad detection is a
**default-ordering hint only**: if the user is on a desktop, the touchpad sub-block question
(2f) lists "No touchpad / desktop" first; on `IS_LAPTOP=1` it lists the on-by-default option
first. The question is still asked.

## Call 1 — keyboard + focus model (4 sub-questions)

**2a. Keyboard layout** → free text, default `us`. Multi-layout is allowed (e.g. `us, es`); if
the user gives two, the writer must add a layout-cycle option in 2b.

**2b. Caps/Esc & layout options** (multi-select, off by default):
- `caps:swapescape` — swap Caps and Esc (the popular pick).
- `caps:escape` — Caps acts as Esc, Esc unchanged.
- `compose:caps` — Caps becomes a Compose key.
- `grp:win_space_toggle` — cycle layouts with Super+Space (only meaningful with a multi-layout `kb_layout`).
- `grp:alt_shift_toggle` — alternative layout-cycle binding.

**2c. Key repeat** — Default (rate 25 / delay 600) **(default)** · Fast (rate 40 / delay 300) ·
Snappy (rate 50 / delay 250) · Custom. Only non-default values are emitted to `input.conf`.

**2d. Focus model** —
- **Focus follows mouse** — moving the pointer over a window focuses it (`follow_mouse = 1`,
  the Hyprland default) **(default)**.
- **Click to focus** — focus changes only on click (`follow_mouse = 0`; pointer never refocuses).
- **Detached / loose** — pointer can scroll the window under it but keyboard focus changes only
  on click (`follow_mouse = 2`; `3` is the fuller-loose variant).

Read the answer carefully — `1` (NOT `2`) is the real "focus follows mouse". See
`gotchas.md`.

## Call 2 — input baseline + touchpad (3 sub-questions)

**2e. Input baseline** (multi-select, off by default):
- `accel_profile = flat` — disable mouse acceleration (gamers).
- `numlock_by_default = true` — NumLock on at session start.
- Mouse `sensitivity` slider — float `-1.0 … 1.0`, default `0.0`. Record as `mouse_sensitivity`.

**2f. Touchpad** (skip on desktop / when `IS_LAPTOP=0` and the user confirms no touchpad):
- Natural scroll + tap-to-click on **(default on laptops)**.
- Traditional scroll, tap on.
- No touchpad / desktop **(default on desktops)**.

The full `touchpad {}` block also sets `disable_while_typing`, `clickfinger_behavior`, and
honors a user `scroll_factor` — those are template-fixed, not asked.

**2g. Touchpad gestures** (multi-select; only asked when 2f didn't say "no touchpad"; 0.45+
keyword API — see `_shared/version-matrix.md`). Default-on: 3-finger horizontal workspace swipe.
- **3-finger horizontal → switch workspace** **(on)**.
- 4-finger horizontal → move window.
- 3-finger up → fullscreen.
- 3-finger pinch → toggle float/tile (HyDE preset).
- 4-finger up → special/scratchpad.

On pre-0.45 the template falls back to a `gestures { workspace_swipe = true }` block — only the
first item maps; the rest emit a comment noting the version gate.

## Record paths

After each `AskUserQuestion` call, record every sub-answer with `record-answer.sh`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" input.kb_layout us
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" input.kb_options --json '["caps:swapescape"]'
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" input.key_repeat --json '{"rate":25,"delay":600}'
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" input.follow_mouse --json 1
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" input.mouse_sensitivity --json 0.0
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" input.touchpad_gestures --json '["workspace-swipe"]'
```

If 2f says "no touchpad", record an empty array for gestures and skip 2g:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" input.touchpad_gestures --json '[]'
```

## Cross-references

- Schema → `schema.md`
- Generated `input.conf` template → `template.md`
- `follow_mouse` semantics + version gates → `gotchas.md`
- 0.45+ gesture-keyword cliff → `../../_shared/version-matrix.md`
- Laptop detection (default-ordering only) → `../laptop/interview.md`

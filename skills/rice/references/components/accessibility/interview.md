# accessibility — interview

Group 22. **One** `AskUserQuestion` call, one multi-select sub-question, **nothing pre-checked**.

Off by default — surface it once (high value for those who need it, cheap to skip for those who
don't). Every option is genuinely optional; the user may check zero, one, or all four.

## Sub-question

**22a. Accessibility helpers?** (multi-select, all off by default)

| Option | What it does |
|---|---|
| `magnifier` | Bind `SUPER+=` / `SUPER+-` to Hyprland's built-in `cursor:zoom_factor` (no external tool). |
| `large-cursor` | Bump `XCURSOR_SIZE` / `HYPRCURSOR_SIZE` to 32 (or 48), call `hyprctl setcursor`, set GTK `cursor-size`. |
| `night-light` | Bind `SUPER+SHIFT+N` to `hyprsunset` warm-temp toggle. |
| `larger-ui` | Low-vision preset: bump monitor `scale` + GTK `text-scaling-factor 1.25`. |

Use `multiSelect: true`. **Nothing pre-checked.** Hint text on the question should note that the
larger-UI option may trigger the fractional-scaling gotcha (see `../monitors/gotchas.md`).

## Record path

After the user answers, record with `record-answer.sh` using the `--json` form (it's an array):

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" \
  "$staging/answers.json" accessibility --json '["magnifier","large-cursor"]'
```

If the user checks zero items, record an empty array (do **not** omit the key):

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" \
  "$staging/answers.json" accessibility --json '[]'
```

Downstream writers branch on `(.accessibility // []) | length == 0`, so the key must exist.

## Strict-asking note

Per `../../_interview-protocol.md`: this gate is **always asked**, even if no `$ARGUMENTS` hint
mentions accessibility and no existing config has it. Detection (e.g. did a previous install set
`HYPRCURSOR_SIZE`?) doesn't decide the gate — the user does. Skipping this call is a defect.

## Cross-references

- Schema → `schema.md`
- Per-helper output routing → `template.md`
- Fractional-scale + cursor-format gotchas → `gotchas.md`
- Packages → `packages.md`
- Night-light overlap with utilities → `../utilities/interview.md`

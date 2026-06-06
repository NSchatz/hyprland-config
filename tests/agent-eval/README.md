# tests/agent-eval — Layer B regression (local + CI loop)

The agents-driven regression layer. Lives in two halves:

- **Local half:** `/regression-eval` (see `commands/regression-eval.md`) spawns each fixture's
  agent with pinned answers + preset, captures the configs it produces into
  `generated/<fixture>/`, runs assertions, and shows a diff vs. the prior baseline.
- **CI half:** the visual test (`tests/test_visual_themes.sh`) mounts whatever's committed under
  `generated/<fixture>/` into the sway container, runs the real apps against those configs, and
  uploads screenshots as a workflow artifact. **CI does not invoke any agents** — it consumes the
  committed output of the local half.

That loop is the regression bedrock: the screenshots are evidence of what the plugin's
component-writer actually produces, not what a test stub hand-wrote.

## Layout

```
fixtures/<name>.json           # input: surface + preset + answers slice + assertions
generated/<name>/              # output: agent's real configs — COMMIT THIS
output/<run-id>/               # per-invocation logs, diffs, verdicts — NOT committed
```

## Workflow

```
                                ┌──────────────────────────────────┐
                                │  fixtures/<name>.json            │
                                │  (you author by hand)            │
                                └────────────────┬─────────────────┘
                                                 │
                       (local)                   ▼
            ┌────────────────────────┐   /regression-eval
            │  hyprland-component-   │ ◄──────────────── spawns agent
            │      writer agent      │   with pinned answers + preset
            └────────────┬───────────┘
                         │ writes files
                         ▼
                generated/<name>/      ◄── you `git add` + commit this
                         │
                         │ (CI)
                         ▼
            tests/test_visual_themes.sh  → mounts generated/ into sway container
                         │
                         ▼
            tests/visual/output/<preset>/*.png  → uploaded as `theme-screenshots` artifact
```

## Adding a fixture

1. **Decide the contract.** What surface? What answers? What preset? What must the output do
   (parse as JSON, contain `@import "colors.css"`, NOT contain `[urgency=high]`, …)?

2. **Write `fixtures/<name>.json`.** Schema documented in `commands/regression-eval.md`.

3. **Populate the baseline.** Run `/regression-eval <name>` locally. The agent writes to
   `generated/<name>/`. Review the diff (`git diff tests/agent-eval/generated/<name>/`); if
   the output looks right, commit it.

4. **Watch the screenshots.** Next CI run will screenshot the new fixture's surface as part of
   the preset composite. The artifact zip on the workflow run page is the regression evidence.

## When this catches a regression

- Agent's prompt drift produces a worse config → diff vs. committed baseline is non-empty → user
  sees the diff and decides if it's a regression or an improvement.
- Agent stops adding `@import "colors.css"` → `file_contains` assertion fails → CI screenshot
  also drops in quality (no per-theme colors).
- Component-writer starts inlining hex literals → `file_not_contains` assertion fails OR the
  CI screenshot looks identical across presets (the theme can't override the literals).
- A new agent prompt re-orders config keys → diff non-empty but screenshots identical →
  user can re-bless the baseline without breakage.

## What this is NOT

- Not a CI gate. CI runs only the consumer half (visual test). Agent invocations are local.
- Not a substitute for `bash tests/run.sh` — that's the cheap mechanical layer; run it first.
- Not auto-blessing. The user inspects the diff and decides whether to commit the new baseline.

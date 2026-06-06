---
description: Run the local agent-eval regression suite — for each fixture, spawns the component-writer, writes the generated configs into tests/agent-eval/generated/<fixture>/, runs assertions, and diffs against the prior committed baseline so drift is visible. CI then screenshots whatever lands in generated/.
argument-hint: "[fixture-name-substring]   # optional filter; runs every fixture if omitted"
allowed-tools: Bash, Read, Write, Glob, Agent
---

# /regression-eval — local agent regression suite

This command is the **local half** of plugin regression testing. It spawns the
`hyprland-component-writer` agent with each fixture's pinned answers + preset, captures whatever
config the agent produces, writes those files under `tests/agent-eval/generated/<fixture>/`, runs
structural assertions on them, and shows you a diff against the previously-committed baseline (if
one exists).

The point: **the user commits the `generated/<fixture>/` dirs**, and the CI visual test then
screenshots those exact files. That makes the screenshots evidence of what the plugin actually
produces — not test stubs hand-written in the screenshot harness.

## Workflow

```
fixtures/<name>.json     →   /regression-eval   →   generated/<name>/  (commit this)
                                                            ↓
                                       CI visual test mounts + screenshots
                                                            ↓
                                            theme-screenshots artifact
```

This command runs **locally**, not in CI — each fixture costs a real agent call. Run it when:

- You've changed an agent prompt and want to confirm the output still passes assertions.
- You've added a new fixture and need to populate its baseline.
- You're about to release a new plugin version and want fresh evidence on disk.

CI does **not** invoke this command. CI just consumes the committed `generated/` dirs.

## Inputs

`$ARGUMENTS` — optional substring filter. If present, only fixtures whose filename contains the
substring are run. Empty = every fixture.

## Fixture format

Each `tests/agent-eval/fixtures/<name>.json`:

```json
{
  "name":        "waybar-pill-mocha",
  "description": "What this fixture pins down.",
  "agent":       "hyprland-component-writer",
  "surface":     "waybar",
  "preset":      "catppuccin-mocha",
  "answers":     { "bar_style": "centered-pill", "bar_modules_left": ["sway/workspaces"], ... },
  "assertions": [
    { "type": "file_exists",      "path": "waybar/config.jsonc" },
    { "type": "json_parses",      "path": "waybar/config.jsonc" },
    { "type": "file_contains",    "path": "waybar/style.css", "needle": "@import" },
    { "type": "file_not_contains","path": "waybar/style.css", "needle": "literal-hex-leak" }
  ]
}
```

Supported `assertions[].type`:

| `type`              | semantics                                                              |
|---------------------|------------------------------------------------------------------------|
| `file_exists`       | file at `path` (relative to fixture's generated dir) must exist        |
| `json_parses`       | file must parse as strict JSON (`python3 -c "import json; json.load(open(...))"`) |
| `file_contains`     | file must contain the literal `needle` substring                       |
| `file_not_contains` | file must NOT contain the literal `needle` substring                   |

## Steps

1. **Resolve the fixture set.** `Glob tests/agent-eval/fixtures/*.json`. If `$ARGUMENTS` is
   non-empty, keep only basenames containing the substring (case-insensitive). If nothing
   matches, tell the user the filter matched nothing and stop.

2. **Print a header** with the fixture count and run ID (UTC timestamp e.g. `20260606-053000`).
   Create `tests/agent-eval/output/<run-id>/` to hold per-run logs.

3. **For each fixture:**

   a. `Read` the fixture JSON.

   b. Compose the component-writer's invocation message. Pass `SURFACE`, `ANSWERS` (as
      JSON), the preset's palette path
      (`${CLAUDE_PLUGIN_ROOT}/skills/rice/assets/profiles/<preset>.conf`), and a `STAGING`
      directory pointing at `tests/agent-eval/generated/<fixture-name>/`. Tell the agent to
      write the files under that staging dir. Example:

      > Write the `waybar` surface to `STAGING=<repo>/tests/agent-eval/generated/waybar-pill-mocha/`.
      > ANSWERS (JSON): `{...}`. PALETTE: `<repo>/skills/rice/assets/profiles/catppuccin-mocha.conf`.
      > HYPR_VERSION: `0.55.0`. Return the list of files you wrote.

   c. Spawn the agent via the `Agent` tool with `subagent_type` = the fixture's `agent` field.

   d. After the agent returns, capture the staging directory state. For each assertion run the
      check against files under `tests/agent-eval/generated/<fixture-name>/`.

   e. **Diff against the prior baseline.** Before this run, you snapshotted the staging dir to
      `tests/agent-eval/output/<run-id>/<fixture>-prior/`. After the agent writes, `diff -ru`
      the prior vs. the new and store the diff at
      `tests/agent-eval/output/<run-id>/<fixture>.diff`. If the diff is empty, the baseline
      didn't change. If non-empty, the user must inspect it.

   f. Write `tests/agent-eval/output/<run-id>/<fixture>.json`:
      ```json
      {
        "fixture":            "<name>",
        "agent":              "<agent>",
        "verdict":            "pass" | "fail",
        "drift_vs_baseline":  "none" | "<N lines changed>",
        "assertion_results":  [ { "type": "...", "path": "...", "verdict": "pass|fail", "detail": "..." } ]
      }
      ```

   g. Print a one-line status: `✓ <name>  (no drift)` / `✓ <name>  (drift: N lines — review with git diff)` /
      `✗ <name>  — <first failing assertion>`.

4. **Final summary** — pass/fail counts, list of failed fixtures (if any), path to
   `tests/agent-eval/output/<run-id>/`.

5. **Remind the user to commit.** If any baselines changed (drift > 0 or new fixture), print:
   `git add tests/agent-eval/generated/ && git commit` — that's how CI picks up the new configs.

## What this command is NOT

- Not a CI gate. CI consumes the committed `generated/` dirs; it does not run agents.
- Not a substitute for `bash tests/run.sh` — run that first; it's free and catches mechanical drift.
- Not a benchmark. Each fixture pins one specific behavior. Add fixtures for new failure modes
  as you discover them; don't try to make the suite "cover everything."

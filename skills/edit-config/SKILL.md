---
name: edit-config
description: This skill should be used when the user runs "/hyprland-config:edit-config" or asks to change, fix, inspect, or test an EXISTING Hyprland config — e.g. "add a keybind to my hyprland config", "change my gaps", "add a window rule", "add my second monitor to my existing config", "read my hyprland config", or "test my hyprland config". Reads the current ~/.config/hypr config, makes the change, and live-tests after every edit (hyprctl reload + configerrors) with automatic rollback. To build a config from scratch, use rice instead.
argument-hint: "[what to change, e.g. 'add SUPER+T for thunar' or 'read my config']"
allowed-tools: Read, Edit, Write, Bash, Glob, Grep, Agent
version: 0.1.0
---

# Edit & Test Hyprland Config

Read, inspect, and safely modify an **existing** Hyprland config under `~/.config/hypr`, testing
after **every** change so a broken edit never silently persists. Treat `$ARGUMENTS` as the
requested change (or a read/inspect request).

Use the **Hyprland Config Reference** skill for correct syntax — read its reference files under
`${CLAUDE_PLUGIN_ROOT}/skills/hyprland-reference/references/` (especially `testing.md` for the
test/rollback mechanics, `deprecations.md` to avoid stale syntax, and the section/keybind/
window-rule files). For generating a config from scratch, defer to the **rice** skill
instead.

## Workflow

### 1. Read & understand the current config

- Read `~/.config/hypr/hyprland.conf`, then follow every `source=` line (resolve `~` and globs)
  and read those files too. Build a picture of the current setup: monitors, layout, binds, rules,
  autostart. Companion configs (`hyprlock.conf`, `hypridle.conf`, `hyprpaper.conf`) are read by
  their own daemons, not `source=`d — read them only when the change concerns them.
- Detect the version:
  `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/detect-version.sh"`. Emit syntax
  matching it (window-rule block vs line form, `gesture=` vs `gestures{}`, etc.).
- If the user only asked to **read/inspect/explain**, do that now and stop — no backup needed.

### 2. Back up once, before the first edit

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/backup-config.sh"
```

Record the `BACKUP=` path. This is the rollback target for the whole session.

### 3. Make the change in the right file

- Locate the correct sourced file (e.g. a new bind → `binds.conf`; a gap tweak →
  `looknfeel.conf`; a rule → `windowrules.conf`). If the config is a single monolithic
  `hyprland.conf`, edit it in place. Use the `Edit` tool for surgical changes.
- Write the new syntax correctly for the detected version; cross-check `deprecations.md`.
- Avoid introducing a duplicate `MODS, KEY` bind — grep the bind files first.

### 4. Test after EVERY change (the core requirement)

After each individual edit, live-test:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/verify-config.sh"
```

Read the `VERIFY=` line:

- `VERIFY=ok` — the change reloaded with no parse errors. Keep it; proceed to the next change.
- `VERIFY=errors` — the printed errors tell you what broke. **Revert that edit** (undo it with
  `Edit`, or restore the affected file from the `BACKUP=` dir), re-run `verify-config.sh` to
  confirm the session is clean again, then report the problem and fix instead of leaving it
  broken.
- `VERIFY=skipped` — no running Hyprland to test against. Fall back to the
  **hyprland-config-validator** agent for static checking, and tell the user the change is
  untested until next login.

When applying several changes, edit→verify **one change at a time** so a failure pinpoints the
exact culprit. Never batch many edits and test once.

### 5. Optional deeper validation

For non-trivial changes, also run the **hyprland-config-validator** agent (via `Agent`) on
`~/.config/hypr` for static issues (deprecations, duplicate binds, conflicts) that a clean reload
won't flag. Surface its report.

### 6. Report

Summarize what changed, which file, the `VERIFY` result, and the backup path. If anything was
rolled back, say exactly what failed and the corrected approach.

## Previewing a single option (no file write)

To trial one setting live before committing it to disk:
`hyprctl keyword <category:name> <value>` (e.g. `hyprctl keyword decoration:rounding 0`). It
applies immediately and is reverted by the next reload — handy for "show me before you save it".

## Safety rules

- Always back up (step 2) before the first edit; keep the `BACKUP=` path for rollback.
- Test after every change; never leave the live config in a `VERIFY=errors` state.
- Never emit deprecated syntax — cross-check `hyprland-reference/references/deprecations.md`.
- Preserve the user's existing structure, comments, and variable names; make minimal diffs.

## Resources

- **`${CLAUDE_PLUGIN_ROOT}/skills/hyprland-reference/references/testing.md`** — read/test/rollback
  mechanics in depth.
- **`${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/verify-config.sh`** — live test;
  `VERIFY=ok|errors|skipped`.
- **`${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/backup-config.sh`** — timestamped
  backup; prints `BACKUP=`.
- **`${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/detect-version.sh`** — installed
  version + ecosystem probe.

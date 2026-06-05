---
name: edit-config
description: This skill should be used when the user runs "/hyprland-config:edit-config" or asks to change, fix, inspect, or test an EXISTING desktop config — Hyprland (`~/.config/hypr/*.conf`), the desktop-shell pieces around it (waybar, wofi/rofi/fuzzel, mako/dunst/swaync), the terminal shell (bash/zsh/fish — prompt, aliases, fetch), or any companion daemon's config (hyprlock/hypridle/hyprpaper). Examples: "add a keybind", "change my gaps", "add a window rule", "add a module to my waybar", "swap my launcher to rofi", "make my notifications stay longer", "add a starship prompt", "set up zsh aliases", "read my hyprland config", "test my config". Reads the current files, makes the change in the right place, and **verifies after every edit** with automatic rollback (Hyprland: `hyprctl reload` + `configerrors`; bar: JSON parse + `SIGUSR2`; shell rc: parse-only — never sourced). To build a config from scratch, use rice instead.
argument-hint: "[what to change, e.g. 'add SUPER+T for thunar' or 'set up zsh with starship' or 'add a network module to my waybar']"
allowed-tools: AskUserQuestion, Read, Edit, Write, Bash, Glob, Grep, Agent
version: 0.2.0
---

# Edit & Test the Desktop Config

Read, inspect, and safely modify an **existing** desktop config — Hyprland, the desktop shell around
it (waybar / launcher / notifications), the terminal shell (bash/zsh/fish), and the companion daemons
(hyprlock/hypridle/hyprpaper). Treat `$ARGUMENTS` as the requested change (or a read/inspect request).
Test after **every** change so a broken edit never silently persists.

This skill owns *editing*; from-scratch generation is the **rice** skill. For Hyprland syntax read
the **hyprland-reference** skill (`testing.md`, `deprecations.md`, `sections.md`,
`keybindings.md`, `window-rules.md`). For the per-surface recipes, read each component's folder
under **`../rice/references/components/<x>/`** — `waybar/`, `launcher/`, `notifications/`,
`terminal/`, `lock-screen/`, `widgets/`, `shell-prompt/` — the same `template.md` (+ `gotchas.md`,
`styling.md`, `validation.md`, `reload.md`) files rice uses when generating. For coloring any
surface, drive the rice engine (`../rice/references/theming/engine.md`) rather than hardcoding hex.

## What scope are you in?

Decide from the request which surface(s) the edit touches — the test command differs:

| Surface | Files | Test |
|---|---|---|
| **Hyprland** | `~/.config/hypr/*.conf` (modular `source=`d set) | `verify-config.sh` → `hyprctl reload` + `configerrors` |
| **Waybar / launcher / notifications** | `~/.config/{waybar,wofi,rofi,mako,dunst,swaync}/*` | JSON/CSS parse + `apply-theme.sh` (signal reload) |
| **Terminal shell** | `~/.bashrc` · `~/.zshrc` · `~/.config/fish/config.fish` (or `conf.d/*.fish`) | `verify-shell.sh` (parse-only, never sourced) |
| **Companion daemons** | `hyprlock.conf` · `hypridle.conf` · `hyprpaper.conf` | parse-check (balanced braces); the daemon errors on next start |
| **Read/inspect only** | — | no test, no backup |

A request can span surfaces ("add a workspace to Hyprland *and* a workspaces module to waybar") —
walk each surface one at a time with its own back-up + verify, so a failure in one doesn't bleed into
another.

## Workflow

### 1. Read & understand the current state

- **Hyprland scope:** read `~/.config/hypr/hyprland.conf`, then follow every `source=` line
  (resolve `~` and globs) and read those too. Build a picture of monitors, layout, binds, rules,
  autostart. Companion configs (`hyprlock.conf`, `hypridle.conf`, `hyprpaper.conf`) are read by their
  own daemons, not `source=`d — read them only when the change concerns them.
- **Shell scope:** read the rc file(s) and any `conf.d/` snippets the chosen shell auto-sources.
- **Desktop-shell scope:** read the existing `config.jsonc`/`style.css`/`config`/`dunstrc` so edits
  preserve the user's structure.
- Detect the Hyprland version when relevant:
  `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/detect-version.sh"` — emit syntax matching it
  (window-rule block vs line form, `gesture=` vs `gestures{}`, etc.).
- If the user only asked to **read/inspect/explain**, do that now and stop — no backup needed.

### 2. Back up once, before the first edit (per surface)

```bash
# Hyprland
bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/backup-config.sh"
# Anything else
bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" ~/.config/waybar ~/.bashrc …
```

Pass only the paths actually being touched. Record the `BACKUP=` path — that's the session's rollback
target.

### 3. Make the change in the right file

- **Hyprland modular set:** put the change in the right sourced file (new bind → `binds.conf`; gap
  tweak → `looknfeel.conf`; rule → `windowrules.conf`). Monolithic config: edit in place. Avoid
  introducing a duplicate `MODS, KEY` bind — grep the bind files first.
- **Waybar/launcher/notifications:** edit per the matching component's `template.md` (and its
  `gotchas.md` / `validation.md`) — `../rice/references/components/waybar/`,
  `../rice/references/components/launcher/`, `../rice/references/components/notifications/`. Don't
  hardcode theme colors anywhere — `@import`/include the rice colors file (the engine owns colors).
- **Shell rc:** put additions in the managed block (`# >>> hyprland-config managed >>>` …
  `# <<< hyprland-config managed <<<`) so re-runs replace rather than duplicate. Guard every
  external tool with `command -v`. The managed-block recipe + parse-test live in
  `../rice/references/components/shell-prompt/template.md` (and `gotchas.md`). Never hand-pick
  *colors* — drive the prompt/fish colors from the rice engine
  (`../rice/references/theming/engine.md` → "Shell & prompt theming").
- For all surfaces: write the new syntax correctly for the detected version; cross-check
  `deprecations.md`.

### 4. Verify after EVERY change (the core requirement)

Pick the test that matches the surface and run it after each individual edit:

- **Hyprland:** `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/verify-config.sh"` →
  reads `VERIFY=ok|errors|skipped`.
- **Waybar `config.jsonc`:**
  `python3 -c "import json,sys; json.load(open(sys.argv[1]))" ~/.config/waybar/config.jsonc`
  then reload with `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/apply-theme.sh"` (sends
  `SIGUSR2` to a running waybar). A malformed `config.jsonc` makes the bar silently fail to appear —
  validate first. If the file uses `//` comments, strip into a temp copy first
  (`sed -E 's@//.*$@@' file > /tmp/x.json`) and parse that.
- **Notifications / launcher CSS:** reload via `apply-theme.sh` (mako `makoctl reload`, dunst
  `dunstctl reload`, swaync `swaync-client -rs` — only if running).
- **Shell rc:** `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/verify-shell.sh" ~/.bashrc` →
  reads `VERIFY_SHELL=ok|errors|skipped`. **Parse-only** — never `source` the rc to test.

Read the result line:

- `ok` — keep it; proceed to the next change.
- `errors` — the printed errors tell you what broke. **Revert that edit** (undo with `Edit`, or
  restore the affected file from the backup), re-run the test to confirm the surface is clean
  again, then report the problem and fix instead of leaving it broken.
- `skipped` — no running compositor / shell isn't installed. Fall back to the
  **hyprland-config-validator** agent for static checking, and tell the user the change is untested
  until next login.

When applying several changes, edit→verify **one change at a time** so a failure pinpoints the exact
culprit. Never batch many edits and test once.

### 5. Optional deeper validation

For any non-trivial Hyprland edit, also run the **hyprland-config-validator** agent (via `Agent`) on
`~/.config/hypr` — it catches deprecations, duplicate binds, conflicts, and ecosystem-coherence
issues a clean reload won't flag. Surface its report.

### 6. Report

Summarize what changed (which file, which surface), the verify result, the backup path, and any
follow-up the user needs to see the change (shell: open a new terminal or `exec <shell>`; live theme
reload: applies immediately; companion daemon: visible on next start).

## Previewing a single Hyprland option (no file write)

To trial one setting live before committing it to disk:
`hyprctl keyword <category:name> <value>` (e.g. `hyprctl keyword decoration:rounding 0`). It
applies immediately and is reverted by the next reload — handy for "show me before you save it".

## Safety rules

- Always back up (step 2) before the first edit on a surface; keep the `BACKUP=` path for rollback.
- Test after every change; never leave a surface in an `errors` state.
- Never emit deprecated syntax — cross-check `hyprland-reference/references/deprecations.md`.
- Preserve the user's existing structure, comments, and variable names; make minimal diffs.
- Never `source`/execute a shell rc to "test" it — parse only.
- Don't hardcode hex colors — drive coloring through the rice engine so re-themes stay coherent.
- If a missing package blocks the edit (e.g. user asks to switch to rofi and rofi isn't installed),
  install it via the package install flow (look up the relevant
  `../rice/references/components/<x>/packages.md` slice) after asking the user once for permission.

## Resources

Recipes are organized per-component under `../rice/references/components/<x>/`. Each folder owns its
`template.md` (the recipe), `gotchas.md`, and for visual components `styling.md` / `validation.md` /
`reload.md`. Look up the surface you're editing:

- **`../rice/references/components/waybar/`** — `config.jsonc` + `style.css` recipes, modules,
  signals, the JSON-strictness gotcha.
- **`../rice/references/components/launcher/`** — wofi / rofi / fuzzel / tofi recipes.
- **`../rice/references/components/notifications/`** — mako / dunst / swaync recipes.
- **`../rice/references/components/terminal/`** — kitty / alacritty / foot / wezterm recipes.
- **`../rice/references/components/lock-screen/`** — hyprlock styling (companion daemon config
  itself lives in `companion-daemons/`).
- **`../rice/references/components/companion-daemons/`** — `hyprlock.conf` / `hypridle.conf` /
  `hyprpaper.conf` recipes.
- **`../rice/references/components/widgets/`** — eww / AGS-Astal / Quickshell / HyprPanel recipes.
- **`../rice/references/components/shell-prompt/`** — per-shell rc locations, the managed block,
  prompt engines (starship/oh-my-posh), aliases/env/history, parse-test recipe.
- **`../rice/references/components/keybinds/`** — bind syntax, dispatchers, the bind catalog.
- **`../rice/references/components/window-rules/`** — `windowrulev2` syntax + recipes.
- **`../rice/references/components/look-feel/`** — gaps / borders / rounding / blur / animations.
- **`../rice/references/components/<x>/packages.md`** — the install slice for the "install a tool
  to unblock an edit" path (use the component matching the surface).
- **`../rice/references/theming/engine.md`** — rice engine (palette + render + reload), incl.
  shell/prompt color templates.
- **`../rice/references/_shared/colors-contract.md`** — per-app color variable contracts (which
  names the rendered colors file exports for each surface).
- **`../rice/references/_shared/dispatchers.md`** — the Hyprland dispatcher catalog (handy for any
  keybind edit).
- **`${CLAUDE_PLUGIN_ROOT}/skills/hyprland-reference/references/`** — `testing.md`, `deprecations.md`,
  `sections.md`, `keybindings.md`, `window-rules.md`, `ecosystem.md`.
- **`${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/verify-config.sh`** — Hyprland live test;
  `VERIFY=ok|errors|skipped`.
- **`${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/verify-shell.sh`** — shell rc parse test;
  `VERIFY_SHELL=ok|errors|skipped`.
- **`${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/apply-theme.sh`** — reload waybar / mako / dunst /
  swaync (only if running).
- **`${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/backup-config.sh`** — timestamped backup of
  `~/.config/hypr`.
- **`${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh`** — timestamped backup of arbitrary paths.
- **`${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/detect-version.sh`** — installed version + ecosystem
  probe.

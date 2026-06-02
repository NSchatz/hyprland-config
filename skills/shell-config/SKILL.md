---
name: shell-config
description: This skill should be used when the user runs "/hyprland-config:shell-config" or asks to set up or change their terminal shell — e.g. "configure my bash/zsh/fish", "set up my shell", "add a starship prompt", "add shell aliases", "add fastfetch/neofetch to my shell", "set up my zshrc/bashrc", "switch to zsh/fish", or "make my shell nicer". Configures the interactive shell (bash/zsh/fish): prompt (starship or built-in), aliases, environment, history, a startup fetch (fastfetch by default, or neofetch), and guarded modern-CLI integration — backing up rc files and syntax-checking after every change. For coloring the terminal emulator itself, use theme-config.
argument-hint: "[request, e.g. 'set up zsh with starship and aliases']"
allowed-tools: AskUserQuestion, Bash, Read, Write, Edit, Glob, Grep
version: 0.1.0
---

# Configure Terminal Shell

Set up the interactive terminal shell (bash, zsh, or fish) safely: prompt, aliases, environment,
history, and modern-CLI integration — with rc backups and a **syntax check after every change**.
Treat `$ARGUMENTS` as the request.

Read `references/shells.md` for per-shell file locations, prompt init lines, aliases/env/history
defaults, integration snippets, and the parse-only test commands. Keep every addition **guarded**
(`command -v tool`) and **idempotent** (a marked managed block) so a missing tool or a re-run never
breaks a login.

## Workflow

### 1. Detect shell & tools

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/detect-theme-tools.sh"
```

Use the `CURRENT_SHELL=` line and the `HAVE_*` lines for `bash/zsh/fish/starship/eza/bat/zoxide/
fzf/atuin`. Default to configuring the user's current login shell unless they ask to switch.

### 2. Decide scope (ask)

Confirm with the user (offer sensible defaults):

- **Which shell** to configure (default: current). If they want to switch to a shell that isn't
  installed, note the package and that `chsh` is a manual step (see `shells.md`).
- **Prompt**: starship (if installed) / built-in / leave as-is.
- **Aliases & modern CLI**: standard aliases; enable guarded `eza`/`bat`/`zoxide`/`fzf`/`atuin`
  integration only for tools that are installed (others can be added later — keep them guarded).
- **Startup fetch**: offer a system-info fetch on terminal open — **fastfetch (default)**,
  neofetch, or none. fastfetch is the maintained choice; neofetch is archived. If the chosen tool
  isn't installed (`HAVE_fastfetch`/`HAVE_neofetch` from step 1), note the package and still wire a
  guarded line so it works once installed. Glyphs render best with a Nerd Font terminal font — if
  `MISSING_NERD_FONT`, point the user at the theme-config fonts step.
- **Env/history**: editor, history sizes/dedup.

### 3. Back up the rc file(s)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" ~/.bashrc      # or ~/.zshrc, ~/.config/fish/config.fish
```

### 4. Edit inside a managed block

Add/update the additions inside a clearly delimited block so re-runs replace rather than
duplicate:

```sh
# >>> hyprland-config managed >>>
# (prompt init, aliases, env, history, guarded tool inits, interactive startup fetch)
# <<< hyprland-config managed <<<
```

Use `Edit` to replace an existing managed block, or append it if absent. Write fish config to
`~/.config/fish/config.fish` (or a `conf.d/*.fish` snippet). Use the exact init lines and guards
from `shells.md`. Never set terminal *colors* here — that's theme-config's job.

### 5. Test after every change (parse-only, never source)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/shell-config/scripts/verify-shell.sh" ~/.bashrc
```

Read the `VERIFY_SHELL=` line:

- `VERIFY_SHELL=ok` — no syntax errors; keep it.
- `VERIFY_SHELL=errors` — the parser output shows the problem; **revert that edit** (restore the
  rc from the backup or undo with `Edit`), re-run to confirm clean, then fix and retry.
- `VERIFY_SHELL=skipped` — that shell isn't installed; you can't parse-test it. Note it.

Apply several changes one at a time, testing between each. A clean parse does not prove a tool is
installed — that's why every tool use is `command -v`-guarded.

### 6. Report

Summarize what changed, the file, the `VERIFY_SHELL` result, and the backup path. To take effect
the user opens a new shell or `source`s the rc. If they asked to switch login shells, give the
`chsh -s "$(command -v <shell>)"` command and note it's a manual, password-prompted step.

## Safety rules

- Back up before editing; keep the backup path for rollback.
- Test (parse-only) after every change; never leave the rc in a `VERIFY_SHELL=errors` state.
- Never `source`/execute the rc to "test" it — parse only.
- Guard every external tool with `command -v`; keep additions in the managed block.
- Don't run `chsh` for the user — suggest it.

## Resources

- **`references/shells.md`** — per-shell locations, prompt, aliases, env, history, integration,
  testing, and login-shell switching.
- **`scripts/verify-shell.sh`** — parse-only syntax check; `VERIFY_SHELL=ok|errors|skipped`.
- **`${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh`** — timestamped backup of rc files.
- **`${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/detect-theme-tools.sh`** — shell + tool probe.

# shell-prompt — interview

Group 17. Five sub-questions cap of 4 per `AskUserQuestion` → **split across 2 consecutive calls**.
A third optional call covers aliases / modern-CLI integration when the user wants it.

**Strict rule (see `_interview-protocol.md`):** every sub-question gets its own `AskUserQuestion`
prompt. The `(default)` marker on an option just reorders the menu so the default is first; it
does **not** authorize skipping the question. Even if the user's current login shell is bash,
**still ask 17a** — they may want fish for ricing.

## Sub-questions

**17a. Which shell?** — default option ordering: **Keep current login shell (default)**, bash,
zsh, **fish** (popular ricing pick — built-in autosuggestions + tab-completions).
Notes for the writer:
- Whichever shell is picked lands in the install batch (even if not currently installed).
- The pick does **not** automatically change the login shell. `chsh` is suggested as a manual
  follow-up; the lower-risk alternative is per-terminal (`kitty.conf`: `shell /usr/bin/fish`,
  foot: `shell=/usr/bin/fish`). Never run `chsh` on the user's behalf.

**17b. Prompt engine?** — **starship (default, cross-shell)**, oh-my-posh (cross-shell, JSON
themes), native shell prompt, leave as-is.
- starship/oh-my-posh wire to the rice engine; `rice apply` re-colors them.
- native = no engine; rc gets a thin `PS1`/`PROMPT`/`fish_prompt` snippet.

**17c. fish syntax colors?** *(fish-only — skip if 17a is not fish.)* Default **yes**: theme
`fish_color_*` from the rice palette via `~/.config/fish/conf.d/zz-hypr-rice-colors.fish`
(auto-sourced). The alternative is leaving fish defaults.

**17d. Startup fetch?** — **fastfetch (default)**, neofetch (archived since 2024), none.
Adds a guarded line inside the managed block. Needs a Nerd Font (set in group 13).

**17e. fish plugins?** *(fish-only, optional — skip if 17a is not fish.)* Default **off**.
Offer the small, low-risk fisher set as a multi-select:
- `jorgebucaran/autopair.fish`
- `PatrickF1/fzf.fish` (requires `fzf`)
- `meaningful-ooo/sponge`
- `franciscolourenco/done`
Plus the manager itself (`jorgebucaran/fisher`) listed in `~/.config/fish/fish_plugins` so
`fisher update` is reproducible.

## Optional second-pass: aliases & modern-CLI

A separate `AskUserQuestion` (1–2 calls) when the user opts in to modern-CLI integration:

- **Modern-CLI tools** (multi-select): `eza`, `bat`, `zoxide`, `fzf`, `atuin`. Each emits a
  `command -v` / `type -q` -guarded alias + init line inside the managed block. Whatever's
  picked lands in the install batch.
- **Editor / pager defaults**: `EDITOR` / `VISUAL` / `PAGER` / `MANPAGER` (optional one-shot).

In fish, prefer `abbr -a` for git/nav shortcuts (`abbr -a gco 'git checkout'`) over `alias` —
the abbreviation expands inline as the user types.

## Recording answers

After each `AskUserQuestion`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" shell_prompt.shell fish
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" shell_prompt.prompt starship
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" shell_prompt.fish_colors --json true
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" shell_prompt.fetch fastfetch
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" shell_prompt.fisher \
    --json '["jorgebucaran/fisher","jorgebucaran/autopair.fish","PatrickF1/fzf.fish"]'
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" shell_prompt.aliases --json true
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" shell_prompt.modern_cli \
    --json '["eza","bat","zoxide","fzf"]'
```

When 17a is not fish:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" shell_prompt.fish_colors --json false
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" shell_prompt.fisher --json '[]'
```

When 17b is `keep-current` or `native`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" shell_prompt.prompt keep-current
```

(downstream skips the prompt-engine manifest line and the init line in the rc).

## Final reminder to surface

After this group's pass is done, tell the user: **new aliases/prompt only appear in shells
started after the change** — open a new terminal, or `exec fish` / `exec bash` / `exec zsh` in
the current one. See `reload.md`.

## Cross-references

- Schema → `schema.md`
- Managed-block contents (per shell) → `template.md`
- Styling deep-dive (btop / cava / fastfetch / starship / oh-my-posh / fish colors) → `styling.md`
- Parse-test recipe → `validation.md`
- Packages → `packages.md`
- Engine manifest lines for fish / starship / oh-my-posh → `../../theming/engine.md`
  → "Shell & prompt theming"

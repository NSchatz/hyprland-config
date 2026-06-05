# shell-prompt — template

This component touches three categories of file:

1. **The user's shell rc** (`~/.bashrc` / `~/.zshrc` / `~/.config/fish/config.fish`) — additions
   live inside a single guarded **managed block**. Outside the block, the user's content is
   untouched.
2. **Rice-owned prompt configs** (`~/.config/hypr-rice/starship.toml`,
   `~/.config/hypr-rice/rice.omp.json`, `~/.config/fish/conf.d/zz-hypr-rice-colors.fish`) —
   re-rendered from templates on every `rice apply`. Source of truth: the rice engine.
3. **fish plugin manifest** (`~/.config/fish/fish_plugins`) — one `owner/repo` per line.

## The managed-block convention

Every rc edit lives between these two sentinel lines:

```
# >>> hyprland-config managed >>>
# (rice-managed additions; safe to delete this block to detach)
…contents…
# <<< hyprland-config managed <<<
```

Re-running rice **finds and replaces** this block in place; without the sentinels, repeated runs
would append-duplicate. The replace is greedy from the first opener to the matching closer; if
either is missing, the block is appended at EOF.

In fish, `# ` is also the comment marker — the same sentinels work.

## Per-shell managed block

The exact contents depend on `shell_prompt.{prompt, fetch, aliases, modern_cli}`. Every external
command is `command -v` / `type -q` -guarded so a future uninstall doesn't break a login.

### bash — appended to `~/.bashrc`

```bash
# >>> hyprland-config managed >>>
# (rice-managed additions; safe to delete this block to detach)

# History
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth
shopt -s histappend

# Editor / pager
export EDITOR=nvim
export VISUAL="$EDITOR"
export PAGER=less
export MANPAGER='less -R'

{{#if prompt_is_starship}}
# Prompt — starship, pointed at the rice-owned config so `rice apply` re-themes it.
export STARSHIP_CONFIG="$HOME/.config/hypr-rice/starship.toml"
command -v starship >/dev/null && eval "$(starship init bash)"
{{/if}}
{{#if prompt_is_omp}}
# Prompt — oh-my-posh, rice-owned theme file.
command -v oh-my-posh >/dev/null && \
    eval "$(oh-my-posh init bash --config "$HOME/.config/hypr-rice/rice.omp.json")"
{{/if}}
{{#if prompt_is_native}}
PS1='\[\e[1;34m\]\w\[\e[0m\] $ '
{{/if}}

{{#if aliases}}
# Aliases
alias ll='ls -lah'
alias la='ls -A'
alias ..='cd ..'
alias grep='grep --color=auto'
alias mkdir='mkdir -p'
{{/if}}

{{#if modern_cli_includes_eza}}
command -v eza >/dev/null && alias ls='eza --group-directories-first' && alias ll='eza -lah --git'
{{/if}}
{{#if modern_cli_includes_bat}}
command -v bat >/dev/null && alias cat='bat --paging=never'
{{/if}}
{{#if modern_cli_includes_zoxide}}
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
{{/if}}
{{#if modern_cli_includes_fzf}}
command -v fzf >/dev/null && eval "$(fzf --bash)"
{{/if}}
{{#if modern_cli_includes_atuin}}
# atuin on bash needs bash-preexec loaded first
[ -f /usr/share/bash-preexec/bash-preexec.sh ] && \
    source /usr/share/bash-preexec/bash-preexec.sh && \
    command -v atuin >/dev/null && eval "$(atuin init bash)"
{{/if}}

{{#if fetch_is_fastfetch}}
case $- in *i*) command -v fastfetch >/dev/null && fastfetch ;; esac
{{/if}}
{{#if fetch_is_neofetch}}
case $- in *i*) command -v neofetch  >/dev/null && neofetch  ;; esac
{{/if}}
# <<< hyprland-config managed <<<
```

### zsh — appended to `~/.zshrc`

Same shape; key differences:

- History block uses `setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE INC_APPEND_HISTORY`
  with `HISTSIZE=10000  SAVEHIST=10000  HISTFILE=~/.zsh_history`.
- Prompt init: `eval "$(starship init zsh)"` or
  `eval "$(oh-my-posh init zsh --config $HOME/.config/hypr-rice/rice.omp.json)"`. Native
  fallback: `PROMPT='%F{blue}%~%f %# '`.
- `fzf`: `eval "$(fzf --zsh)"` (upstream's canonical form; `source <(fzf --zsh)` is equivalent
  via process substitution). fzf >= 0.48 for the `--zsh` flag; older versions source
  `/usr/share/fzf/{completion,key-bindings}.zsh` instead.
- `zoxide` **must** init **after** `compinit` — completions break otherwise.
- `atuin` is standalone on zsh (no preexec shim needed).

### fish — appended to `~/.config/fish/config.fish`

```fish
# >>> hyprland-config managed >>>
# (rice-managed additions; safe to delete this block to detach)

if status is-interactive
    set -gx EDITOR nvim
    set -gx VISUAL $EDITOR
    set -gx PAGER less
    set -gx MANPAGER 'less -R'

    {{#if prompt_is_starship}}
    set -gx STARSHIP_CONFIG $HOME/.config/hypr-rice/starship.toml
    type -q starship; and starship init fish | source
    {{/if}}
    {{#if prompt_is_omp}}
    type -q oh-my-posh; and oh-my-posh init fish \
        --config $HOME/.config/hypr-rice/rice.omp.json | source
    {{/if}}

    {{#if aliases}}
    alias ll 'ls -lah'
    alias la 'ls -A'
    abbr -a -- .. 'cd ..'
    abbr -a gco 'git checkout'
    abbr -a gst 'git status'
    {{/if}}

    {{#if modern_cli_includes_eza}}
    type -q eza; and alias ls 'eza --group-directories-first'; and alias ll 'eza -lah --git'
    {{/if}}
    {{#if modern_cli_includes_bat}}
    type -q bat; and alias cat 'bat --paging=never'
    {{/if}}
    {{#if modern_cli_includes_zoxide}}
    type -q zoxide; and zoxide init fish | source
    {{/if}}
    {{#if modern_cli_includes_fzf}}
    type -q fzf; and fzf --fish | source
    {{/if}}
    {{#if modern_cli_includes_atuin}}
    type -q atuin; and atuin init fish | source
    {{/if}}

    {{#if fetch_is_fastfetch}}
    type -q fastfetch; and fastfetch
    {{/if}}
    {{#if fetch_is_neofetch}}
    type -q neofetch ; and neofetch
    {{/if}}
end
# <<< hyprland-config managed <<<
```

Note: fish's syntax-highlighting colors **are not in this block**. They live in
`~/.config/fish/conf.d/zz-hypr-rice-colors.fish`, rendered from `fish.tmpl` and auto-sourced.

## Rice-owned prompt configs

These are generated by the rice engine from templates in
`~/.config/hypr-rice/templates/` and re-rendered on every `rice apply`.

| Engine | Template | Output | Wired via |
|---|---|---|---|
| starship | `~/.config/hypr-rice/templates/starship.tmpl` | `~/.config/hypr-rice/starship.toml` | `export STARSHIP_CONFIG=…` in the rc managed block |
| oh-my-posh | `~/.config/hypr-rice/templates/oh-my-posh.tmpl` | `~/.config/hypr-rice/rice.omp.json` | `oh-my-posh init <shell> --config …` in the rc managed block |
| fish colors | `~/.config/hypr-rice/templates/fish.tmpl` | `~/.config/fish/conf.d/zz-hypr-rice-colors.fish` | Auto-sourced by fish on every interactive start; **no wiring needed** |

Why rice-owned (not in-place edited): neither starship nor oh-my-posh supports `include` / palette
import from an external file, so the engine renders the **whole** config to a rice path and the
shell is pointed at it. The user's own `~/.config/starship.toml` is left untouched.

The matching engine-manifest lines (TAB-separated, empty reload-cmd because new shells pick the
colors up automatically) are listed in `../../theming/engine.md` → "Shell & prompt theming".

## fish plugin manifest

When `shell_prompt.fisher` is non-empty, write `~/.config/fish/fish_plugins`:

```
jorgebucaran/fisher
jorgebucaran/autopair.fish
PatrickF1/fzf.fish
meaningful-ooo/sponge
franciscolourenco/done
```

Then run (interactive, inside fish; **not** by the writer agent — the install script prints the
bootstrap one-liner since fisher itself is `curl`-installed, see `gotchas.md`):

```fish
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
fisher update
```

`fisher update` installs exactly what `fish_plugins` lists, so the file is the reproducible source
of truth — version-control it (via the `dotfiles` skill).

## What does NOT belong here

- The terminal emulator's colors — that's `components/terminal/`.
- Modern-CLI tool *packages* (`eza`, `bat`, …) — listed here in `packages.md`, but the canonical
  package set per tool is the install layer's concern, not the rc template.
- Login-shell changes — `chsh` is a manual step (see `gotchas.md`); the writer never runs it.

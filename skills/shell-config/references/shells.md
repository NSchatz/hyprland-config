# Terminal Shell Configuration

Reference for configuring bash, zsh, and fish: file locations, a cross-shell prompt (starship),
common aliases/env, history settings, modern-CLI integration, and how to test a change without
executing the rc. Keep edits **idempotent** and **guarded** (`command -v tool` before using it) so
a config never breaks a login because a tool isn't installed.

## File locations

| Shell | Interactive rc          | Login/env                       | Notes                          |
|-------|-------------------------|---------------------------------|--------------------------------|
| bash  | `~/.bashrc`             | `~/.bash_profile` / `~/.profile`| `.bashrc` is the common target |
| zsh   | `~/.zshrc`              | `~/.zshenv`, `~/.zprofile`      | `$ZDOTDIR` may relocate these  |
| fish  | `~/.config/fish/config.fish` | `~/.config/fish/conf.d/*.fish` | fish has its own syntax     |

Prefer dropping additions into a clearly marked block (e.g. between
`# >>> hyprland-config managed >>>` and `# <<< hyprland-config managed <<<`) so they can be found
and rewritten idempotently rather than duplicated.

## Prompt

- **starship** (cross-shell, recommended): one config `~/.config/starship.toml`, themeable. Init
  line per shell:
  - bash: `eval "$(starship init bash)"`
  - zsh:  `eval "$(starship init zsh)"`
  - fish: `starship init fish | source`
  Guard with `command -v starship >/dev/null && ...`. If starship isn't installed, offer a
  built-in prompt instead (see below) and note the package.
- **Built-in fallbacks** (no deps):
  - bash `PS1='\[\e[1;34m\]\w\[\e[0m\] $ '`
  - zsh `PROMPT='%F{blue}%~%f %# '`
  - fish defines `function fish_prompt; ...; end`
- Heavier frameworks (oh-my-zsh, powerlevel10k) exist but pull in more; only set up if asked.

## Common aliases & options (cross-shell)

```sh
alias ll='ls -lah'
alias la='ls -A'
alias ..='cd ..'
alias grep='grep --color=auto'
alias mkdir='mkdir -p'
# guarded modern replacements (only if installed)
command -v eza  >/dev/null && alias ls='eza --group-directories-first' && alias ll='eza -lah --git'
command -v bat  >/dev/null && alias cat='bat --paging=never'
```

(For fish use `alias name 'cmd'` / `abbr`, and `if type -q eza; ...; end`.)

## Environment

```sh
export EDITOR=nvim          # or vim/nano — pick what's installed
export VISUAL="$EDITOR"
export PAGER=less
export MANPAGER='less -R'
```

fish: `set -gx EDITOR nvim`.

## History (sensible defaults)

- bash: `HISTSIZE=10000  HISTFILESIZE=20000  HISTCONTROL=ignoreboth  shopt -s histappend`
- zsh: `HISTSIZE=10000  SAVEHIST=10000  setopt SHARE_HISTORY HIST_IGNORE_DUPS`
- fish: history is automatic and unbounded by default — there's no simple max-size variable;
  leave it alone (or use a named session via `$fish_history`).
- **atuin** (if installed) replaces history with a searchable DB: `atuin init <shell> | source`/`eval`.

## Modern CLI integration (guarded)

```sh
command -v zoxide   >/dev/null && eval "$(zoxide init bash)"   # 'z' smart cd
command -v fzf      >/dev/null && eval "$(fzf --bash)"          # fuzzy finder (zsh: --zsh); needs fzf >= 0.48
# older fzf: source the shipped key-bindings + completion scripts from /usr/share/fzf/ instead
command -v starship >/dev/null && eval "$(starship init bash)"
```

fish equivalents use `| source`. Always `command -v`/`type -q` guard so missing tools are no-ops.

## Startup fetch (system info)

A "fetch" tool prints a logo + system info — commonly run when a terminal opens. Offer it as an
option; **default to `fastfetch`**.

- **fastfetch** (default) — fast, actively maintained, configurable. Config:
  `~/.config/fastfetch/config.jsonc` (scaffold with `fastfetch --gen-config`). Package: `fastfetch`.
- **neofetch** (alternative) — the classic, but **archived/unmaintained since 2024**; offer it if
  the user prefers it. Config: `~/.config/neofetch/config.conf`. Package: `neofetch`.

Run it on **interactive** shell startup only (never in scripts/non-interactive shells), guarded so
a missing binary is a no-op. Inside the managed block:

```sh
# bash/zsh — only when interactive and the tool exists
case $- in *i*)
    command -v fastfetch >/dev/null && fastfetch ;;
esac
# (swap `fastfetch` for `neofetch` if chosen; or define `alias ff='fastfetch'` to run on demand)
```

fish (`config.fish`):

```fish
if status is-interactive
    type -q fastfetch; and fastfetch
end
```

Glyphs/logo render best with a **Nerd Font** terminal font (see the theme-config fonts reference);
fastfetch can also show an image logo on terminals that support it. Don't install the fetch tool —
suggest the package.

## Theme integration

- The terminal's colors come from the terminal emulator (kitty/alacritty/foot), which the
  **theme-config** skill themes — the shell rc doesn't set terminal colors.
- The shell can still align: set `LS_COLORS` via `vivid` (`command -v vivid && export LS_COLORS="$(vivid generate <theme>)"`)
  or rely on `eza`'s own coloring; point `starship`/prompt accents at the scheme.

## Testing a change (without executing it)

Never `source` the rc to test it (side effects). Parse-only:

- bash: `bash -n ~/.bashrc`
- zsh:  `zsh -n ~/.zshrc`
- fish: `fish --no-execute ~/.config/fish/config.fish`

The plugin's `verify-shell.sh` wraps these and reports `VERIFY_SHELL=ok|errors|skipped`. Run it
after **every** edit. A clean parse means no syntax errors; it does not prove a referenced tool is
installed (that's why guards matter).

## Changing the login shell

Switching shells (e.g. to zsh/fish) is `chsh -s "$(command -v zsh)"` — it prompts for the user's
password and takes effect on next login, so it cannot be done non-interactively by the assistant.
Suggest the command; never assume it ran. Ensure the target shell is installed first.

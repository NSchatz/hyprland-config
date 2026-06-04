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

Two cross-shell engines (both recolor from a single palette block, so the rice engine can re-theme
them — see *Palette-driven colors* below): **starship** (default) and **oh-my-posh**.

- **starship** (cross-shell, recommended): one config `~/.config/starship.toml`, themeable. Init
  line per shell:
  - bash: `eval "$(starship init bash)"`
  - zsh:  `eval "$(starship init zsh)"`
  - fish: `starship init fish | source`
  Guard with `command -v starship >/dev/null && ...`. If starship isn't installed, offer a
  built-in prompt instead (see below) and note the package.
- **oh-my-posh** (cross-shell): a single theme file (`*.omp.json`/`.toml`/`.yaml`) you init against.
  - bash: `eval "$(oh-my-posh init bash --config <theme>)"`
  - zsh:  `eval "$(oh-my-posh init zsh --config <theme>)"`
  - fish: `oh-my-posh init fish --config <theme> | source`
  Guard with `command -v oh-my-posh >/dev/null && ...`. Themes recolor from a top-level `palette` of
  named colors referenced as `p:name`; pick a built-in with `oh-my-posh init <shell>` (no `--config`)
  to start, then theme. Package: `oh-my-posh` (AUR / official install script).
- **Built-in fallbacks** (no deps):
  - bash `PS1='\[\e[1;34m\]\w\[\e[0m\] $ '`
  - zsh `PROMPT='%F{blue}%~%f %# '`
  - fish defines `function fish_prompt; ...; end`
- Heavier frameworks (oh-my-zsh, powerlevel10k) exist but pull in more; only set up if asked.
  powerlevel10k is zsh-only — its edge is Instant Prompt (renders before plugins load).

### Palette-driven colors (re-theme with the desktop)

Rather than hand-picking prompt colors, render them from the rice palette so a `rice apply` recolors
the prompt with everything else. The rice engine ships `starship.tmpl` / `oh-my-posh.tmpl` /
`fish.tmpl`; register a manifest line in `~/.config/hypr-rice/templates.list` (see
`../../rice/references/engine.md` → "Shell & prompt theming"), then point the shell at the rendered
file: starship via `export STARSHIP_CONFIG=~/.config/hypr-rice/starship.toml`, oh-my-posh via
`--config ~/.config/hypr-rice/rice.omp.json`. Neither engine can `include` a palette file, so the
engine renders the *whole* config to a rice-owned path; the user's own `~/.config/starship.toml` is
left alone.

### fish colors (syntax highlighting — separate from the prompt)

Fish themes its own command-line *syntax highlighting* and completion *pager* via ~25 `fish_color_*`
/ `fish_pager_color_*` variables, independent of whichever prompt engine runs. Set them with
`set -g fish_color_command <hex>` (bare hex, no `#`; add `--bold`/`--underline`/`--background=<hex>`).
The rice engine's `fish.tmpl` renders these to `~/.config/fish/conf.d/zz-hypr-rice-colors.fish`, which
fish auto-sources every interactive start — so re-rendering recolors the next shell with no manual
`fish_config theme choose`. Gotcha: a value previously set with `set -U` (universal) **shadows**
`set -g`; clear it (`set -e fish_color_command`) if a re-theme seems to not take. fish also supports
`~/.config/fish/themes/<name>.theme` files (lines like `fish_color_command 89b4fa`, no prefix on the
value, no `#`) loaded with `fish_config theme choose <name>` — fine for hand-switching, but `set -g`
in `conf.d` is the re-renderable path.

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

Glyphs/logo render best with a **Nerd Font** terminal font (see the rice fonts reference);
fastfetch can also show an image logo on terminals that support it. Don't install the fetch tool —
suggest the package.

## Battle-tested setups (from real dotfiles)

Concrete, attributed idioms from real rices. All guard-friendly.

- *bat as the man pager + eza aliases* (omarchy): `export MANPAGER="sh -c 'col -bx | bat -l man -p'"`
  and `export BAT_THEME=ansi` (so it follows the terminal palette); `alias ls='eza -lh --group-directories-first --icons=auto'`, `alias lt='eza --tree --level=2 --icons --git'`. High-value, low-cost.
- *Replace `cd` with zoxide* (omarchy): `eval "$(zoxide init bash --cmd cd)"` makes `cd`→`z` and `cdi`→`zi` outright. On **zsh, init zoxide _after_ `compinit`** or completions break.
- *fzf with fd + default command* : `export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix'` + `export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"`. The tool-agnostic init is `eval "$(fzf --bash)"` / `source <(fzf --zsh)` / `fzf --fish | source`; older fzf sources `/usr/share/fzf/{completion,key-bindings}.<shell>`.
- *zsh plugin trio via zinit* (HyDE): `zinit light zsh-users/zsh-autosuggestions` + `zinit light zdharma-continuum/fast-syntax-highlighting` (use fast-syntax-highlighting **or** plain zsh-syntax-highlighting, not both). HyDE also exports `STARSHIP_CONFIG`/`STARSHIP_CACHE` under `$XDG_*`. Beginner dotfiles lean on oh-my-zsh (`plugins=(git …)`).
- *zsh history block*: `setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE INC_APPEND_HISTORY` with `HISTSIZE`/`SAVEHIST` both large.
- *fish needs no plugin manager* for autosuggest/highlight (built in); use `conf.d/*.fish` for auto-sourced fragments, **fisher** only when you want plugins, `abbr -a gco 'git checkout'` (expands inline, editable) over `alias`, and `fish_add_path ~/.local/bin` (idempotent) instead of mangling `$PATH`. caelestia/Matt-FTW put `starship init fish | source` inside `if status is-interactive`.
- *atuin on bash needs a preexec shim* — `atuin init bash` requires **ble.sh** or **bash-preexec** loaded first; on zsh/fish it's standalone.

## Fish plugins (fisher)

Fish's headline "autocomplete" — **autosuggestions** (ghost-text from history, accept with → / Ctrl-F)
and rich tab-completions — is **built in, no plugin needed**. Plugins are optional polish, installed
with **fisher** (the de-facto manager). Make it **reproducible**: list plugins in
`~/.config/fish/fish_plugins` (one `owner/repo` per line) and version-control that file — `fisher
update` (re)installs exactly that set on any machine.

Bootstrap (run inside fish, after fish is installed):
```fish
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
fisher update    # installs everything listed in ~/.config/fish/fish_plugins
```

High-value, low-risk set (all pure-fish, no daemons):
- **jorgebucaran/autopair.fish** — auto-close/delete brackets, quotes, parens.
- **PatrickF1/fzf.fish** — fuzzy **Ctrl-R** history, file/dir/git/process search. *Needs the `fzf`
  package* (suggest it; the plugin only adds the bindings).
- **meaningful-ooo/sponge** — auto-prunes failed/typo'd commands from history, keeping
  autosuggestions clean.
- **franciscolourenco/done** — desktop notification (via the notification daemon) when a long
  command finishes while the terminal is unfocused.

`jorgebucaran/fisher` itself goes in `fish_plugins` so `fisher update` keeps the manager current too.
The plugin set + `fish_plugins` are part of the rice → track them with the **dotfiles** skill.

**aliases vs abbreviations in fish.** Use `alias name 'cmd …'` for command *replacements* with flags
(`alias ls 'eza …'`, `alias cat 'bat …'`) — they become functions. Use **`abbr -a` for shortcuts you
want to see expand inline** as you type (Space/Enter), which is the idiomatic fish way for git etc.:
`abbr -a gco 'git checkout'`, `abbr -a gst 'git status'`, `abbr -a -- .. 'cd ..'`. Define both inside
`if status is-interactive` in `config.fish`.

## Theme integration

- The terminal's colors come from the terminal emulator (kitty/alacritty/foot), which the
  **rice** skill themes — the shell rc doesn't set terminal colors.
- The shell can still align: set `LS_COLORS` via `vivid` (`command -v vivid && export LS_COLORS="$(vivid generate <theme>)"`)
  or rely on `eza`'s own coloring; point `starship`/prompt accents at the scheme.

## Testing a change (without executing it)

Never `source` the rc to test it (side effects). Parse-only:

- bash: `bash -n ~/.bashrc`
- zsh:  `zsh -n ~/.zshrc`
- fish: `fish --no-execute ~/.config/fish/config.fish`

The plugin's `verify-shell.sh` wraps these and reports `VERIFY_SHELL=ok|errors|skipped`. Run it
after **every** edit. A clean parse means no syntax errors; it does not prove a referenced tool is
installed (that's why guards matter). (`VERIFY_SHELL=skipped` for fish just means fish isn't
installed yet — the config can still be staged; it parses once fish is in.)

**Changes only apply to shells started *after* the edit.** `config.fish`/`.bashrc`/`.zshrc` run at
shell startup, so an **already-open** shell won't have the new aliases/abbrs/prompt — the #1 "my
aliases aren't working" cause. Tell the user to open a new terminal, or **reload in place** with
`exec fish` / `exec bash` / `exec zsh`. (Don't claim a change is "live" in the current shell when it
isn't.)

## Changing the login shell

Switching shells (e.g. to zsh/fish) is `chsh -s "$(command -v fish)"` — it prompts for the user's
password and takes effect on next login, so it cannot be done non-interactively by the assistant.
Suggest the command; never assume it ran. Ensure the target shell is installed **and listed in
`/etc/shells`** first (`grep fish /etc/shells`, else `chsh` refuses it).

**Lower-risk alternative — point the terminal at the shell instead of `chsh`.** To get fish in every
terminal *without* changing the login shell (so TTY/SSH/display-manager scripts that assume POSIX
stay on bash), set the emulator's shell: kitty `shell /usr/bin/fish` in `kitty.conf`, foot
`shell=/usr/bin/fish`, Alacritty `[terminal.shell] program = "/usr/bin/fish"`. Reversible and
contained; offer it as the default, with `chsh` for users who want fish everywhere. (Don't point the
emulator at a shell binary that isn't installed yet — it'll fail to launch.)

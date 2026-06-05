# shell-prompt — gotchas

## Parse-test ONLY — never `source` the rc to "verify it"

Sourcing a shell rc executes every line: `eval "$(starship init …)"`, `command -v` checks,
`fastfetch` on interactive shells, alias definitions that shadow `cd` (zoxide), `fisher`
bootstraps, history-rewrites. A test-`source` from inside the writer can pollute the writer's
environment, mutate the user's history file, launch processes, or break the very rc it's trying
to test. Use parse-only checks:

| Shell | Parse-test |
|---|---|
| bash | `bash -n ~/.bashrc` |
| zsh  | `zsh  -n ~/.zshrc`  |
| fish | `fish --no-execute ~/.config/fish/config.fish` |

A clean parse means **no syntax errors** — it does **not** prove referenced tools are installed.
That's why every external invocation in `template.md` is wrapped in `command -v` / `type -q`. See
`validation.md` for the full recipe and exit-code interpretation.

## Managed-block pattern — find-and-replace, don't append

Every rice-emitted edit lives between sentinels:

```
# >>> hyprland-config managed >>>
…
# <<< hyprland-config managed <<<
```

Re-runs of the writer must locate the existing block and **replace its body in place**, not
append a second block. Without this discipline the rc fills up with duplicated alias/init lines
over multiple `rice apply` runs, and the *last* duplicate wins — usually masking what the user
actually wanted. The same sentinel pair works in bash/zsh/fish (all use `#` for comments).

The replace is greedy from the first opener to the matching closer. If only one sentinel is
present (user deleted half), prefer **erroring loudly** over guessing — ask the user to delete
the orphan sentinel.

## `chsh` is a manual step — Claude never runs it

The shell pick (`shell_prompt.shell`) goes into the install batch, but it does **not** change
the user's *login* shell. That's `chsh -s "$(command -v fish)"` and:

- prompts for the user's password (interactive — the assistant can't drive it),
- only takes effect on **next login**, not in the current session,
- refuses if the target shell isn't listed in `/etc/shells` (`grep fish /etc/shells` to check).

Tell the user the command; never assume it ran. The **lower-risk alternative** that the writer
can fully execute is **per-terminal**: set the emulator's shell directive (kitty
`shell /usr/bin/fish` in `kitty.conf`, foot `shell=/usr/bin/fish` in `foot.ini`, alacritty
`[terminal.shell] program = "/usr/bin/fish"`). This keeps the system login shell unchanged
(TTY/SSH/display-manager scripts stay POSIX), but every new terminal opens the chosen shell.

Don't point the emulator at a shell binary that isn't installed yet — it'll fail to launch.

## "My aliases aren't working" = already-open shells

`config.fish` / `.bashrc` / `.zshrc` run at **shell startup**. An already-open terminal won't see
new aliases, abbrs, prompt init, fetch line, or `STARSHIP_CONFIG` until it's restarted. After a
shell-prompt edit, tell the user to:

- open a new terminal window, **or**
- `exec fish` / `exec bash` / `exec zsh` to reload the current session in place.

Don't claim a change is "live" in the current shell when it isn't.

## fish `set -U` shadows `set -g`

If the user previously ran `fish_config theme choose <name>` or `set -U fish_color_command …`,
those values live in fish's **universal-variable store** (`~/.config/fish/fish_variables`) and
**shadow** the `set -g` snippet rice writes. Symptom: after `rice apply`, the next fish shell
still uses the old colors.

Fix:

```fish
# wipe the offending universals so set -g in conf.d wins
for v in (set -nU | string match 'fish_color_*' 'fish_pager_color_*')
    set -e $v
end
```

The rice template at `~/.config/fish/conf.d/zz-hypr-rice-colors.fish` deliberately uses
`set -g` (per-session global, no `-U`) so re-rendering wins on the next shell — but the writer
should flag this fix to users who report "fish colors not updating" after a re-theme.

## fisher is `curl`-installed, NOT a package

There is no `pacman` / `aur` package for fisher (and Arch doesn't ship one). Bootstrap is a
one-liner that must run **inside fish** **after** fish is installed:

```fish
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
fisher update
```

The install script (`scripts/install.sh`) prints this one-liner as a follow-up step when
`shell_prompt.fisher` is non-empty; it does not try to map "fisher" through `packages.md`. The
*manager itself* (`jorgebucaran/fisher`) goes in `~/.config/fish/fish_plugins` as the first line
so subsequent `fisher update` keeps it pinned.

## `fish_color_*` lives in `conf.d`, not in `config.fish`

The syntax-highlighting colors are **separate** from the managed block in `config.fish`. They go
in `~/.config/fish/conf.d/zz-hypr-rice-colors.fish` (the `zz-` prefix makes it sort late so it
overrides any earlier `fish_color_*` set by other `conf.d/` snippets or themes). fish
auto-sources every `*.fish` in `conf.d/` on each interactive start; no wiring in `config.fish`
needed. Re-rendering the file = next shell is recolored.

Use `set -g` (not `set -U`) so re-rendering wins (see "universal store" above).

## `atuin` on bash needs `bash-preexec`

`atuin init bash` emits hooks that require `bash-preexec` (or `ble.sh`) loaded *before* `atuin`.
On Arch the path is `/usr/share/bash-preexec/bash-preexec.sh` (from the `bash-preexec` package).
On zsh and fish atuin is standalone. The template (`template.md`) gates the atuin init on
`bash-preexec` existing, so missing-package is a silent no-op rather than a broken shell.

## `zoxide` on zsh — order matters

`eval "$(zoxide init zsh)"` **must** be invoked **after** `compinit` (the zsh completion init).
If it runs before, `_z` completion either fails to register or shadows `compinit`'s own
side-effects. The zsh template puts the modern-CLI inits at the bottom, after the implicit
`compinit` from system zsh defaults. If the user disabled the auto-compinit, they need to call
`compinit` themselves before the managed block.

## Don't compose `$menu -dmenu` for shell launchers

Unrelated to this component's rc but worth flagging when the writer also touches launcher
bindings: `$menu` is already a full launcher invocation; appending `-dmenu` to it gives
conflicting mode flags. The `dispatchers.md` cross-cutting reference covers this in the
variables-convention table.

## Catalogued elsewhere

- The `MANPAGER='sh -c "col -bx | bat -l man -p"'` + `BAT_THEME=ansi` idiom (omarchy) — picked up
  by the template when both `bat` and `aliases` are set.
- The starship/oh-my-posh palette-substitution and TUI-color recipes — see `styling.md`.
- Hyprland-version branches — none; this component doesn't touch hyprlang.

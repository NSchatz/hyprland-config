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
`[terminal] shell = { program = "/usr/bin/fish" }` in `alacritty.toml`). This keeps the system
login shell unchanged (TTY/SSH/display-manager scripts stay POSIX), but every new terminal
opens the chosen shell.

Don't point the emulator at a shell binary that isn't installed yet — it'll fail to launch.

## "My aliases aren't working" = already-open shells

`config.fish` / `.bashrc` / `.zshrc` run at **shell startup**. An already-open terminal won't see
new aliases, abbrs, prompt init, fetch line, or `STARSHIP_CONFIG` until it's restarted. After a
shell-prompt edit, tell the user to:

- open a new terminal window, **or**
- `exec fish` / `exec bash` / `exec zsh` to reload the current session in place.

Don't claim a change is "live" in the current shell when it isn't.

## fish `set -U` vs `set -g` — and the `set` (no flag) trap

Per fish's documented scoping rules
([language.html "Variable scope"](https://fishshell.com/docs/current/language.html)),
"the smallest scoped variable of that name will be used" and the hierarchy is
`local > function > global > universal`. So a `set -g fish_color_command …` snippet **does**
override a `set -U fish_color_command …` left over from a previous
`fish_config theme choose <name>`. The two values coexist (`set -g` doesn't delete the
universal — they're separate variables in separate scopes), but reads inside the session
resolve to the global.

The real trap is **`set` with no scope flag**: per
[`cmds/set.html`](https://fishshell.com/docs/current/cmds/set.html), "If the scope of a
variable is not explicitly set _but a variable by that name has been previously defined_, the
scope of the existing variable is used." So a snippet that writes `set fish_color_command …`
(no `-g`, no `-U`) when a universal of that name already exists will silently **update the
universal**, not create a global. The rice template at
`~/.config/fish/conf.d/zz-hypr-rice-colors.fish` therefore uses **explicit `set -g`** on every
line — never bare `set` — so the snippet stays scope-stable across re-runs regardless of
what's already in `~/.config/fish/fish_variables`.

If a user still reports "fish colors not updating after a re-theme", the likely cause is a
shell session opened before the re-render (conf.d files only run on shell start) or a custom
function that explicitly re-sets `-U`. Optional cleanup the user can run by hand to clear any
stale universals:

```fish
for v in (set --names -U | string match 'fish_color_*' 'fish_pager_color_*')
    set -e $v
end
```

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
auto-sources every `*.fish` in `conf.d/` on every shell start (before `config.fish`); no wiring
in `config.fish` needed. Re-rendering the file = next shell is recolored.

Always write **explicit `set -g`** in the snippet — never bare `set` — so the snippet stays
scope-stable even when a `set -U fish_color_*` already exists from a prior
`fish_config theme choose` (see "`set -U` vs `set -g`" above).

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

## starship has no `include` — `.tmpl` MUST render the whole config

starship's TOML parser is single-file. There's no `include`, `import`, or palette-merge mechanism.
The `dusklinux/dusky` repo confirms this in the wild: `.config/matugen/templates/starship-colors.toml`
emits **only** a `[palettes.colors]` block, but the corresponding `[templates.starship]` entry in
`.config/matugen/config.toml` is **commented out** — the maintainers couldn't splice it cleanly,
and the workaround (commented-out post-hook `ln -nfs` of the generated palette over the user's
`~/.config/starship.toml`) loses every line of the user's prompt config that isn't `palettes`. The
rice's answer is: render the whole starship config (palette + format + every module) to a
**rice-owned path** (`~/.config/hypr-rice/starship.toml`) and point `STARSHIP_CONFIG` at it. The
user's own `~/.config/starship.toml` stays unmodified.

`noctalia-dev/noctalia-shell` ships a **palette-only `.tmpl`** (`Assets/Templates/terminal/starship.toml`
= just a `[palettes.noctalia]` block, no `palette = ...` line, no format strings) — this is a valid
alternative for users who already have a starship config: they add `palette = "noctalia"` at the top
of their own `starship.toml` and **manually** `include` the palette block via copy/paste. Not a
re-rendering pipeline. We don't ship this shape because the rice's job is to make `rice apply`
re-theme the prompt without user edits.

## oh-my-posh has no `include` either — same story

oh-my-posh's `--config` takes a single theme file (`.omp.json` / `.toml` / `.yaml`). The CLI offers
**no** `@import` / `include` of an external palette. `mylinuxforwork/dotfiles
dotfiles/.config/ohmyposh/zen.toml` is the in-the-wild reference: a single TOML with palette,
blocks, segments, `[transient_prompt]`, `[secondary_prompt]` all in one file. Rice renders the
whole `rice.omp.json` from `oh-my-posh.tmpl`.

## fish: `oh-my-posh init fish` — `| source` is canonical, `eval "$(...)"` works in 3.4+

The fish convention is `oh-my-posh init fish --config <path> | source` (pipe the init output to
`source`). `mylinuxforwork/dotfiles dotfiles/.config/fish/conf.d/20-customization.fish` uses
`eval "$(oh-my-posh init fish --config ...)"` — fish 3.4+ added `$(...)` as a synonym for `(...)`
(per [fish 3.4 release notes](https://fishshell.com/release_notes.html)), so this **does** work,
but it's bash idiom in fish skin. Our template (`template.md`) uses the canonical `| source` form
for clarity and to match `fish-shell.com`'s own docs.

## omp `transient_prompt` recolors via `foreground_templates`, not `foreground`

omp's `[transient_prompt]` block takes a single `foreground` **or** a list of
`foreground_templates` that resolve to the first non-empty Go-template result. ml4w's `zen.toml`
uses two templates back-to-back:

```toml
foreground_templates = [
  '{{if gt .Code 0}}red{{end}}',
  '{{if eq .Code 0}}magenta{{end}}',
]
```

— the first matches on a failed command, the second on success. Setting `foreground = 'red'`
alongside makes the static color win; pick one model.

## starship `command_timeout` is per-prompt-render, not per-module

omarchy's `command_timeout = 200` is starship's global cap on **any single module** (per starship
docs); each module that exceeds it is dropped silently with a stderr warning. The default is 500
in newer starship and 1000 in older. Set it lower if a network module (gcloud, aws, kubernetes)
hangs your prompt; set it higher if `git_status` on a big repo gets dropped. Our `starship.tmpl`
defaults to 500; bump to 1000 for slow CI/SSH.

## atuin's `Up-arrow rebind` is an opt-in extra step

`atuin init fish | source` sets up Ctrl-R for the fullscreen UI but **does not** rebind the Up
arrow. `Matt-FTW/dotfiles .config/fish/conf.d/atuin.fish` opts in by setting `ATUIN_NOBIND true`
**before** init, then explicitly binding Up post-init:

```fish
set -x ATUIN_NOBIND true
atuin init fish | source
bind \cr _atuin_search
bind up _atuin_bind_up
bind \eOA _atuin_bind_up     # alt arrow-up escape (xterm-ish)
bind \e\[A _atuin_bind_up    # alt arrow-up escape (vt100-ish)
if bind -M insert >/dev/null 2>&1
    bind -M insert \cr _atuin_search
    bind -M insert up _atuin_bind_up
end
```

Our template only emits the init line — the rebind is documentation, not a default, because the
default Ctrl-R is the cross-shell convention and Up-rebinding is a personal-preference change.

## fish: an empty `config.fish` is a valid pattern

`mylinuxforwork/dotfiles dotfiles/.config/fish/config.fish` is 0 bytes — ml4w drives everything
from `conf.d/{00_init,10-aliases,20-customization,30-autostart}.fish`. fish auto-sources every
`*.fish` in `conf.d/` on every interactive start (before `config.fish`). Our managed block sits
in `config.fish` because find-and-replace on a single file is cleaner than coordinating multiple
`conf.d` snippets; a user who already lives in `conf.d/` can move the managed block to
`~/.config/fish/conf.d/zz-hypr-rice.fish` without changing semantics.

## Catalogued elsewhere

- The `MANPAGER='sh -c "col -bx | bat -l man -p"'` + `BAT_THEME=ansi` idiom (omarchy) — picked up
  by the template when both `bat` and `aliases` are set.
- The starship/oh-my-posh palette-substitution and TUI-color recipes — see `styling.md`.
- Hyprland-version branches — none; this component doesn't touch hyprlang.
- p10k (powerlevel10k) — out of scope for this plugin's starship/omp/fish lineup. `prasanthrangan/hyprdots Configs/.p10k.zsh` confirms HyDE uses p10k; the rice user can keep p10k by picking `prompt = "keep-current"` in the interview.

# shell-prompt — reload

The most common "my aliases / prompt aren't working" report is straightforward: shell rc files
run at **shell startup**. An already-open terminal won't see the new managed block until that
shell is restarted. There's no live-reload signal a shell rc responds to.

## What gets picked up when

| Change | What sees it | What does NOT see it |
|---|---|---|
| Aliases / abbreviations | Shells started after the edit | Already-open shells (alias was never defined in their session) |
| Prompt engine init (`STARSHIP_CONFIG`, `oh-my-posh init`) | New shells | Open shells (`PS1`/`PROMPT` is already set; the env var changes are inert) |
| `fastfetch` / `neofetch` startup line | New shells | Open shells (the fetch only runs on rc-load) |
| `export EDITOR=…` | New shells **and** any subprocess spawned from a shell that has been restarted | Already-open shells until restart |
| `~/.config/fish/conf.d/zz-hypr-rice-colors.fish` (palette re-render) | New fish shells | Open fish shells (fish auto-sources `conf.d/` on shell start, not on signal) |
| `~/.config/hypr-rice/starship.toml` (palette re-render) | The **next prompt redraw** in any starship shell — instant, no shell restart needed | — |
| `~/.config/hypr-rice/rice.omp.json` (palette re-render) | The **next prompt redraw** in any oh-my-posh shell — instant | — |

The split is: **prompt-engine *configs* are hot-reloaded by the engine itself; the *init wiring*
(env var, init line in the rc) requires a shell restart.**

## Reload recipes

### Open a new terminal window

The simplest path. The user opens a fresh terminal; it reads the updated rc; everything's live.

### `exec <shell>` in the current terminal

Replaces the running shell with a new instance — same window, same `$TERM`, but the rc runs
fresh. Tell the user:

| Shell | Command |
|---|---|
| bash | `exec bash` |
| zsh  | `exec zsh`  |
| fish | `exec fish` |

Caveats:

- Background jobs in the current shell are **killed** (`exec` replaces the process). The user
  should `disown -a` first if anything important is running.
- Subshells / `tmux` panes / SSH inside the shell are **not** affected — they're still using
  their own pre-edit rc until they too restart.
- In `tmux`, prefer **restarting the pane** (`Ctrl-b x` then `Ctrl-b "` / `Ctrl-b %`) — exec'ing
  inside a tmux pane works but `tmux` itself may have set `default-shell` to the old shell.

### After a re-theme (`rice apply`)

Pure palette change — no rc edit. Then:

- **starship / oh-my-posh:** *no action needed*. The next prompt redraw uses the freshly
  rendered config. The user might press Enter to see the recolor immediately.
- **fish syntax-highlighting colors** (`conf.d/zz-hypr-rice-colors.fish`): need a new fish shell
  (or `source ~/.config/fish/conf.d/zz-hypr-rice-colors.fish` in the current one). Re-running
  the file is safe — it's all `set -g` assignments.
- **fastfetch output already on screen:** historical (it ran once at shell start); next shell
  prints the recolored logo.

## What the writer should tell the user, every time

After the writer finishes a shell-prompt edit, surface this in the summary:

> Shell config updated. Already-open terminals are still on the old config — open a new terminal
> (or `exec <shell>` in the current one) to load the new aliases / prompt / fetch. (The current
> shell session is unchanged.)

## After a `chsh` (if the user ran one)

`chsh -s "$(command -v fish)"` only changes the login shell on **next login** — closing and
re-opening the current terminal is not enough on most setups. The user must log out of the
graphical session (or reboot, or SSH out and back in). New TTY sessions started after the
re-login use the new login shell.

If the user wants per-terminal fish without the re-login, point them at the emulator's `shell`
directive instead (`kitty.conf`: `shell /usr/bin/fish`); kitty re-reads its config on save and
the *next* terminal opened uses the new shell — but **already-open kitty windows** still need to
be closed/reopened.

## What never reloads

Nothing here is daemonized; there's no IPC signal to send. `kill -HUP $shell_pid` does not
re-source the rc on bash/zsh/fish — it terminates the shell. Don't suggest signals; suggest a
fresh shell.

## Cross-references

- The reason a parse-test isn't a reload trigger → `validation.md`
- The managed-block content the user is reloading into a shell → `template.md`
- The `set -U` shadowing issue if fish colors look unchanged after a re-theme → `gotchas.md`
- Per-terminal shell directive (kitty/foot) as the `chsh`-free alternative →
  `gotchas.md` → "`chsh` is a manual step"

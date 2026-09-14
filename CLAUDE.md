# CLAUDE.md

Guidance for Claude Code working in this repository.

## What this is

A Claude Code PLUGIN that builds and edits an Arch/Hyprland desktop. It
interviews a user component by component, generates a modular Hyprland config
plus the functional surfaces around it (bar, launcher, notifications, terminal,
lock screen), themes every surface from one palette, installs the packages the
picks need, and version-controls the result.

The repo ships skills, agents, commands and scripts. It does not ship a desktop:
it WRITES ONE onto a live machine.

## The invariant that governs every change (do not weaken it)

**This plugin edits a running desktop and a user's home directory. Every write is
reversible, and reversibility is proven before the write, not after.**

- `~/.config/hypr` has its own backup plus a live test with AUTO-ROLLBACK:
  `hyprctl reload` after an edit, and a config that does not load is reverted.
- Everything OUTSIDE `~/.config/hypr` - rendered app configs, Firefox profile
  files, shell rc files - belongs to an APPLY ID. Each file is copied to
  `<path>.bak.<apply-id>` BEFORE it is overwritten and listed in that apply's
  restore point. `rice restore --list` and `rice restore <id>` put the whole set
  back byte-for-byte and remove what the apply created.
- If a backup cannot be written, THE SURFACE IS SKIPPED rather than overwritten
  (`RENDER_SKIPPED`). Never overwrite a file you could not back up first.
- A restore point clears only when every file in it is restored, so re-running is
  always safe and a partial failure reports the paths it could not put back.

Two things outlive an apply and a restore cannot take them back: INSTALLED
PACKAGES and anything written outside the tracked surfaces. Both are recorded on
the machine so a user can find out afterwards what happened. Keep that true.

A shell rc file is NEVER SOURCED to check it - it is parsed. Sourcing a user's rc
to see if it is valid executes it.

## The exit-code table (every command this repo ships)

| code | meaning |
|---|---|
| 0 | it ran and the answer is yes |
| 1 | it ran and the answer is NO: the verdict it was asked for came back negative |
| 2 | usage error: unknown subcommand or option, missing or unusable argument |
| 3 | it could not run: a capability it needs is absent - a tool, a binary feature, a running compositor, the network |
| 4 | it refused to act and wrote nothing: a backup it could not take, a target it will not overwrite, a disclosed action declined, no config directory it will resolve |
| 5 | an input it was given is defective: missing, unreadable, unparseable, corrupt or ambiguous |
| 6 | it acted and could not finish or could not record what it did: state is mixed and a re-run is not automatically safe |

**A capability a script could not reach is NEVER reported as a verdict or as a
refusal.** 3 means the check did not happen, so a caller may carry on and try
another route; 1 means the check happened and said no; 4 means the script
decided not to act and nothing was written. `preflight-config.sh` is where that
distinction earns its keep: `unverified` (no binary offers the offline check, so
nothing was proven) is 3 and the caller installs and live-tests behind it, while
`uncheckable` (the staged config could not be checked at all) is 5 and the
caller refuses. Statuses above 6 belong to the shell: 126 not executable, 127
not found, 128+N killed by signal N.

Every command states the codes it can return in its own `--help`, and
`tests/test_exit_codes.sh` fails when a script can return a status its help does
not document, or documents one it cannot return. Each deliberate termination
carries an `# rc=<class>` tag naming its class - ok, verdict, usage, capability,
refusal, input, partial - and the harness reds when a tag and its number
disagree.

The commands the table binds: `skills/rice/assets/rice`, every `.sh` directly
under `scripts/` or `skills/rice/scripts/` that is executed rather than only
sourced, and `tests/run.sh`. `scripts/xdg-config.sh` and
`skills/rice/scripts/version-ledger.sh` are sourced-only libraries: they define
helpers, terminate nothing, and a helper that `return`s a status is not an exit
code. `skills/rice/assets/scripts/*` are desktop assets a user copies onto their
own machine, not this plugin's command surface.

## The gate

```bash
bash tests/run.sh                   # everything except the Docker integration
bash tests/run.sh <substring>       # only files matching the substring
RUN_INTEGRATION=1 bash tests/run.sh # plus Hyprland-in-Docker
```

Exit 0 only if every test passed; skipped is acceptable, failed is not. A filter
that matches no test file exits 2 rather than reporting a clean pass, and a
tests directory with no test file in it exits 5. Plain bash, `jq` and `git` - no
framework. `tests/README.md` is the table of what each file covers.

Every change that touches a script the user invokes, or a path that writes to a
home directory, extends this harness so it reds on that specific regression. A
tool that edits a live desktop proves its unhappy paths.

## Layout

- `skills/` - `rice` (the all-in-one: interview, generate, theme, profiles,
  wallpaper), `edit-config` (edits an EXISTING desktop, tests after every edit
  with auto-rollback), `dotfiles` (git version control for the configs),
  `hyprland-reference` (auto-triggered syntax, ecosystem and styling reference).
- `agents/` - `hyprland-interviewer` (owns the from-scratch interview and
  persists every answer as it goes), `hyprland-config-validator` (static
  validation plus an optional live load test), `hyprland-package-installer`
  (runs the generated `install.sh` after one confirmation; pacman plus paru/yay
  routing), `hyprland-component-writer` (authors ONE surface into staging;
  several run in parallel).
- `commands/` - `reset-config`, which wipes `~/.config/hypr` to a bare-bones
  config behind a full backup, a live test and auto-rollback.
- `scripts/` - the shared mechanics: `backup-path.sh`, `restore-point.sh`,
  `rice-restore.sh`, `record-answer.sh`, `install-packages.sh`,
  `install-record.sh`, `firefox-prefs.sh`, `dotfiles.sh`, `xdg-config.sh`.
- `tests/` - the harness, plus `tests/integration/` for the container run.

## Conventions

- Emit syntax matching the DETECTED Hyprland version (`hyprctl version`), never
  the syntax of an old tutorial. Ground conventions in the shipped default config
  and the official keybind scheme.
- Every user sees the same interview menu regardless of what is installed; the
  install step adds whatever is missing.
- Idempotent: re-running an install or an apply is always safe.
- Respect `XDG_CONFIG_HOME`; never hardcode `~/.config`.
- No secrets, ever.
- Commit as `Noah Schatz <noah.lane.schatz@gmail.com>`; no `Co-Authored-By` and
  no AI co-author trailer. Conventional Commits.
- Plain hyphens only - no en or em dashes, anywhere.
- No dates and no narrated history in this file. Git and `CHANGELOG.md` hold that.

## Local testing

```bash
claude --plugin-dir <path to this repo>
```

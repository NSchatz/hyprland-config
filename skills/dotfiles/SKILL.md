---
name: Version-Control Dotfiles
description: This skill should be used when the user runs "/hyprland-config:dotfiles" or asks to version-control, back up to git, or sync their config/dotfiles — e.g. "put my hyprland config in git", "version control my dotfiles", "set up a dotfiles repo", "commit my config", "push my dotfiles", "track my config in git", or "back up my rice to github". Initializes a dotfiles git repo (bare-repo, GNU Stow, or chezmoi), tracks the Hyprland/desktop configs, and commits/pushes — committing after each verified change.
argument-hint: "[action, e.g. 'set up a bare repo and push to github']"
allowed-tools: AskUserQuestion, Bash, Read, Write, Edit, Glob, Grep
version: 0.1.0
---

# Version-Control Dotfiles

Put the user's Hyprland/desktop configs under git so the whole rice is reproducible and backed
up, and **commit after each verified change**. Supports three standard methods — ask which to use
(default **bare repo**). Treat `$ARGUMENTS` as the request.

Read `references/dotfiles.md` for the methods, the bare-repo alias, secrets handling, and
new-machine restore. All operations go through the helper:
`${CLAUDE_PLUGIN_ROOT}/scripts/dotfiles.sh`.

## Methods (ask per run; default bare)

- **bare** — a bare git repo (`~/.dotfiles`) tracking files **in place** in `$HOME`, no symlinks.
  Best fit: it versions the live config exactly where the plugin writes it. Recommended default.
- **stow** — GNU Stow symlink farm from `~/dotfiles`. Organized, but restructures files into the
  repo and symlinks them back (requires `stow`).
- **chezmoi** — a chezmoi-managed source repo with templating/secrets/multi-machine (requires
  `chezmoi`).

If the chosen tool isn't installed (stow/chezmoi), say so and offer bare instead — don't install.

## Workflow

### 1. Initialize

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/dotfiles.sh" init <bare|stow|chezmoi> [git@github.com:USER/dotfiles.git]
```

Pass the remote URL if the user has one (or add it later). For bare it sets
`status.showUntrackedFiles=no` so unrelated `$HOME` files never show up accidentally.

### 2. Track the configs

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/dotfiles.sh" add-defaults
```

Tracks the common desktop config paths that exist (`~/.config/hypr`, `hypr-rice`, `waybar`,
`kitty`, `rofi`, `wofi`, `mako`, `dunst`, `gtk-3.0/4.0`, `qt5ct/6ct`, `swaync`, `wlogout`,
`fastfetch`, `starship.toml`). Add more with `dotfiles.sh add <path>…`. **Shell rc files
(`~/.bashrc`/`~/.zshrc`) are opt-in** — add them explicitly only if the user wants, and warn about
secrets (tokens/keys) first.

### 3. Commit & push

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/dotfiles.sh" commit "describe the change"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/dotfiles.sh" push       # if a remote is set
```

### 4. Commit after every verified change (the habit)

This is the point of the skill: after **any** verified config change — a `generate-config`
install, an `edit-config` edit, a `theme-config`/`rice apply`, a profile switch — run
`dotfiles.sh commit "<what changed>"` (and `push`). Suggest doing this automatically as part of
those flows so history stays granular and the remote is current.

### 5. Report

Summarize: method, repo location, what's tracked, commit hash, push result, and the remote URL (or
how to add one). For a new machine, give the restore command from `dotfiles.md`.

## Safety rules

- **Never track secrets.** Don't add files containing tokens/keys/passwords; the bare repo's
  `showUntrackedFiles=no` already prevents accidental `$HOME` adds. Warn before adding shell rc.
- Don't install `stow`/`chezmoi` — suggest them; fall back to bare.
- Pushing publishes the configs — confirm the remote/visibility with the user first.

## Resources

- **`references/dotfiles.md`** — the three methods, bare-repo alias, secrets, `.gitignore`,
  new-machine restore, recommended tracked paths.
- **`${CLAUDE_PLUGIN_ROOT}/scripts/dotfiles.sh`** — init / add / add-defaults / commit / push / status.

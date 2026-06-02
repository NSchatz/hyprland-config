# Dotfiles Version Control

How to keep the Hyprland/desktop config under git. Three common methods; the plugin's
`scripts/dotfiles.sh` wraps all three behind one interface.

## Method comparison

| Method | Repo | Symlinks? | Best for | Needs |
|--------|------|-----------|----------|-------|
| **bare** | `~/.dotfiles` (bare) | No — tracks files in place | Versioning the live config exactly where it lives | git only |
| **stow** | `~/dotfiles` | Yes (symlink farm) | Organized, portable repo layout | `stow` |
| **chezmoi** | `~/.local/share/chezmoi` | No (renders to target) | Templating, secrets, many machines | `chezmoi` |

The **bare-repo** method is the recommended default for this plugin: the plugin writes configs to
`~/.config/...` in place, and the bare repo tracks them there with no restructuring — so
"version-control my existing rice" just works.

## Bare repo — how it works

```bash
git init --bare ~/.dotfiles
# all operations use this git-dir + $HOME work-tree:
git --git-dir=~/.dotfiles --work-tree=$HOME ...
# convenient alias (add to your shell rc):
alias dot='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
git --git-dir=~/.dotfiles --work-tree=$HOME config status.showUntrackedFiles no
```

`status.showUntrackedFiles no` is important: without it, `git status` lists your entire `$HOME`.
With it, only files you explicitly `dot add` are tracked. Then:

```bash
dot add ~/.config/hypr ~/.config/waybar ~/.config/hypr-rice
dot commit -m "track hyprland rice"
dot remote add origin git@github.com:USER/dotfiles.git
dot push -u origin HEAD
```

**New machine restore:**
```bash
git clone --bare git@github.com:USER/dotfiles.git ~/.dotfiles
git --git-dir=~/.dotfiles --work-tree=$HOME checkout   # may need to move conflicting files first
git --git-dir=~/.dotfiles --work-tree=$HOME config status.showUntrackedFiles no
```

## Stow — how it works

Files live in `~/dotfiles/<package>/<relative-path>`; `stow <package>` symlinks them into `$HOME`.
E.g. `~/dotfiles/hypr/.config/hypr/hyprland.conf` → `stow -d ~/dotfiles -t ~ hypr`. Migrating away
requires un-stowing (the symlinks must be replaced with real files).

## chezmoi — how it works

`chezmoi add <path>` copies a file into the source repo (optionally templated); `chezmoi apply`
renders it to the target. `chezmoi git -- <git args>` runs git in the source repo. Strong for
per-host differences and secrets (age/gpg). Files in the target are real files, so you can stop
using chezmoi anytime.

## What to track

Recommended (the plugin's `add-defaults` adds those that exist):

```
~/.config/hypr  ~/.config/hypr-rice  ~/.config/waybar  ~/.config/kitty
~/.config/rofi  ~/.config/wofi  ~/.config/mako  ~/.config/dunst
~/.config/gtk-3.0  ~/.config/gtk-4.0  ~/.config/qt5ct  ~/.config/qt6ct
~/.config/swaync  ~/.config/wlogout  ~/.config/fastfetch  ~/.config/starship.toml
```

**Opt-in (warn about secrets first):** `~/.bashrc`, `~/.zshrc`, `~/.config/fish/config.fish`.

## Secrets & hygiene

- Never commit tokens, API keys, SSH private keys, or `*.local`/credential files.
- Backups created by the plugin (`*.bak.*`) and caches don't belong in the repo. Add a
  `.gitignore` (in the work-tree root for stow/chezmoi; for bare, use `~/.gitignore` referenced via
  `core.excludesFile`, or just don't `add` them).
- Pushing publishes the configs — confirm visibility (public/private) before adding a remote.

## Commit-after-every-change

The rice stays reproducible only if history is kept current. After each **verified** change
(`generate-config` install, `edit-config` edit, `theme-config`/`rice apply`, profile switch), run:

```bash
dotfiles.sh commit "<what changed>" && dotfiles.sh push
```

Tie this into those flows so every applied-and-verified change becomes a commit.

# hyprland-config

A Claude Code plugin that generates complete, validated [Hyprland](https://hyprland.org)
configurations from scratch through an interactive interview - then writes them, safely backed
up, into `~/.config/hypr`.

## What it does

- **Interviews you** one component at a time - monitors, input, keybinds, default apps, terminal,
  status bar, launcher, notifications, lock screen, look & feel, palette, fonts, wallpaper, autostart
  & env - then generates the whole desktop (Hyprland config **plus** the functional bar/launcher/
  notification configs), themed from one palette. **Every user sees the same menu** regardless of
  what's installed - the install step (below) adds whatever's missing.
- **Installs the packages your picks need.** After the interview, you confirm the resolved package
  batch **once**, then a dedicated agent runs the install (pacman + auto-detected paru/yay for AUR,
  bootstrap if the helper is missing). Idempotent - re-runs are safe. A reviewable **`install.sh`**
  also ships with the dotfiles so the rice replicates cleanly to a new machine.
- **Detects your installed Hyprland version** (`hyprctl version`) and emits matching syntax -
  no deprecated options from old tutorials. Conventions are grounded in the **shipped default
  config** and popular community dotfiles: the official keybind scheme (Q=terminal, C=close,
  R=menu, E=files, V=float, M=exit) with `$mainMod`, `layoutmsg, togglesplit`, the `gesture=`
  touchpad API, `windowrule { match:… }` block rules (0.53+), `rounding_power`, and the
  well-tuned default animation curves.
- **Knows the Hyprland ecosystem.** First-party defaults - `hyprlock`, `hypridle`, `hyprpaper`,
  `hyprpicker`, `hyprshot`, `hyprsunset`, `hyprpolkitagent` - alongside common community choices
  (waybar / hyprpanel, wofi / rofi / fuzzel, mako / dunst / swaync, swww, cliphist, wlogout,
  swayosd, and the `xdg-desktop-portal-hyprland` stack for screen sharing). Pick anything; it's
  installed.
- **Generates a modular config**: a main `hyprland.conf` that `source=`s topic files
  (`env`, `monitors`, `input`, `looknfeel`, `binds`, `windowrules`, `autostart`).
- **Generates companion configs** when you opt in: starter `hyprlock.conf`, `hypridle.conf`,
  and `hyprpaper.conf` (read by their own daemons, not `source=`d).
- **Backs up safely**: copies your existing `~/.config/hypr` to a timestamped
  `~/.config/hypr.bak.<timestamp>` before writing anything.
- **Live-tests every change**: after writing, it runs `hyprctl reload` + `hyprctl configerrors`
  to confirm the config actually loads - and **automatically rolls back** to the backup if it
  doesn't. The `edit-config` skill does the same after *each* incremental edit, so a broken
  change never silently persists.
- **Reads your existing config**: follows `source=` includes to understand your current setup,
  whether to pre-fill the interview or to make a targeted edit.
- **Themes the whole desktop from one palette**: named scheme, wallpaper-generated
  (matugen/wallust), or manual hex - rendered into Hyprland, hyprlock, waybar, notifications,
  launcher, terminal, and GTK/Qt/cursor/icons, then hot-reloaded.
- **Is a real rice engine**: scaffolds a self-contained `~/.config/hypr-rice/` (one `palette.conf`
  source of truth + per-app templates + a `rice` CLI) that re-themes everything with one command,
  keeps working **without** the plugin, supports **wallpaper-driven** theming, **named profiles**
  with a **user-override cascade**, and **version control** of the whole rice in git.
- **Configures the terminal and desktop shell**: bash/zsh/fish setup (prompt, aliases, env) and
  the bar/launcher/notification functional configs - each backed up and tested after every change.
  All of this lives in the `rice` skill on a fresh build and in `edit-config` for later edits.
- **Uses agents in parallel.** The from-scratch build spawns one **`hyprland-component-writer`**
  per surface (waybar / launcher / notifications / terminal / lock-screen / Hyprland topic files)
  so the per-component authoring runs concurrently instead of serializing on the main loop.
- **Validates** the result with the **`hyprland-config-validator`** agent - syntax, deprecations,
  conflicts (duplicate binds, undefined variables, missing source files), flags ecosystem coherence
  issues, optional live load-test. Invoked automatically after generation **and** after non-trivial
  edits.

## Components

| Type  | Name                        | Purpose                                                        |
|-------|-----------------------------|----------------------------------------------------------------|
| Skill | `rice`                      | User-invoked. The **all-in-one** rice: **generate** a whole desktop from scratch (per-component interview → modular Hyprland config + functional bar/launcher/notification/terminal configs + **shell & prompt** + an `install.sh` Claude actually runs after one confirmation → install + live-test), **theme** every surface from one palette (named / wallpaper-generated / manual + font choices), manage named **profiles** (12 presets + a user-override cascade), and set/cycle the **wallpaper** with dynamic theming - all driven by a self-contained rice engine (`~/.config/hypr-rice/` with `palette.conf` + templates + a `rice` CLI). |
| Skill | `edit-config`               | User-invoked. Edits an **existing** desktop config - Hyprland (`~/.config/hypr/*.conf`), the surfaces around it (waybar, wofi/rofi, mako/dunst/swaync), the terminal shell (bash/zsh/fish rc files), and companion daemons (hyprlock/hypridle/hyprpaper). **Tests after every edit** with auto-rollback (Hyprland: `hyprctl reload`; bar: JSON parse + `SIGUSR2`; shell: parse-only - never sourced). Installs any tool a requested edit needs (after asking once). |
| Skill | `dotfiles`                  | User-invoked. Version-controls the configs in git (bare-repo / stow / chezmoi) and commits after each verified change. |
| Skill | `hyprland-reference`        | Auto-triggered. Hyprland config syntax, ecosystem, **testing**, and a **styling reference library** (per-package design guides + cross-cutting design principles, researched from the community). |
| Command | `reset-config`            | User-invoked. Wipes `~/.config/hypr` to a minimal bare-bones `hyprland.conf` - full backup + live-test + auto-rollback. |
| Agent | `hyprland-interviewer`      | Owns the rice from-scratch interview (28-38 `AskUserQuestion` calls across 23 groups) and persists every answer to `<staging>/answers.json` as it goes. Runs a "review your picks" pass at the end. Returns just the file path so the main rice loop's context stays clean for the work that follows. |
| Agent | `hyprland-config-validator` | Static validation (plus an optional live load-test) of a generated/edited config. Run automatically after rice generation and after non-trivial edits. |
| Agent | `hyprland-package-installer`| Runs the generated `install.sh` (or an ad-hoc package list) after the user confirms the batch once. Handles pacman + paru/yay routing, bootstraps a helper if missing, retries transient failures, returns a structured verdict. |
| Agent | `hyprland-component-writer` | Authors **one** desktop surface (waybar / launcher / notifications / terminal / lock-screen / a Hyprland topic file) into staging. The rice skill spawns several in parallel during Mode A so the per-component writing runs concurrently, each fed a `jq` slice of `answers.json`. |

## Usage

Build a config from scratch:

```
/hyprland-config:rice
```

Optionally pass hints to pre-fill the interview:

```
/hyprland-config:rice set up from scratch - dual monitor, vim keybinds, no animations
```

The `rice` skill picks the mode from your request (generate / theme / profiles / wallpaper). For a
fresh build it walks you through one short interview, spawns several **component-writer agents** in
parallel to author each surface (waybar, launcher, notifications, terminal, lock-screen, Hyprland
topic files), statically validates the staging dir, **asks once to install the packages your picks
need** (handled by the installer agent - pacman + paru/yay routing), backs up and installs the
configs into `~/.config/hypr` + `~/.config/<app>/`, then **live-tests** Hyprland (`hyprctl reload` +
`configerrors`) - rolling back automatically if it fails to load.

### Changing an existing config

```
/hyprland-config:edit-config add SUPER+T to launch thunar
/hyprland-config:edit-config make my gaps smaller and turn off shadows
/hyprland-config:edit-config read my config and explain my keybinds
```

`edit-config` reads your current config (following `source=` includes), makes the change in the
right file, and **tests after every change** with `hyprctl reload` + `configerrors`, reverting
any edit that breaks the reload. Read-only requests ("read/explain my config") skip the backup
and just report.

### Theming the whole desktop

```
/hyprland-config:rice catppuccin mocha
/hyprland-config:rice match my wallpaper
/hyprland-config:rice set my accent to #89b4fa
```

`rice` resolves **one palette** - a named scheme (Catppuccin, Gruvbox, Nord, Tokyo Night,
Rosé Pine), wallpaper-generated (matugen/wallust), or manual hex - and renders it into a separate
colors file for each app (Hyprland, hyprlock, waybar, mako/dunst, wofi/rofi, kitty, GTK4 `gtk.css`,
Qt, cursor/icons/fonts), then reloads each running app so it shows immediately. Re-theming later is
a one-file-per-app rewrite + reload.

### Editing the shells & surfaces around Hyprland

From-scratch builds are owned by `rice`; later edits to any surface are owned by `edit-config`:

```
/hyprland-config:edit-config set up zsh with starship and aliases
/hyprland-config:edit-config add a network module to my waybar
/hyprland-config:edit-config swap my launcher to rofi
/hyprland-config:edit-config make my notifications stay longer
```

`edit-config` covers Hyprland (`*.conf`), the desktop-shell surfaces (waybar, wofi/rofi, mako/
dunst/swaync - `style.css` + functional config), the terminal shell (bash/zsh/fish - prompt,
aliases, env, history, fetch), and companion daemons (hyprlock/hypridle/hyprpaper). Every edit is
backed up and **tested before keeping** - Hyprland gets `hyprctl reload` + `configerrors`, waybar
gets a strict JSON parse + `SIGUSR2` reload, shell rc files get parse-only (`bash -n`/`zsh -n`/
`fish --no-execute`, never sourced). If an edit needs a tool that isn't installed (e.g. you ask to
switch to rofi but it's not there), the skill installs it after asking once. Colors are always
driven through the rice engine so they stay coherent with the rest of the desktop. `rice` also
**presents font choices** - a UI font and a monospace/Nerd font (needed for bar/fetch/prompt
glyphs) - and applies them across GTK, kitty, and waybar.

### The rice engine, wallpaper, profiles

```
/hyprland-config:rice     ~/Pictures/wall.png and theme from it
/hyprland-config:rice     switch to nord
/hyprland-config:rice     save my current look as midnight
/hyprland-config:dotfiles set up a bare repo and push to github
```

`rice` scaffolds a self-contained engine into `~/.config/hypr-rice/` - one `palette.conf`
+ per-app templates + a `rice` CLI. After setup it keeps working **without Claude**:

```bash
rice apply               # re-render every app from palette.conf and reload
rice restore --list      # applies you can still undo, newest first
rice restore <apply-id>  # undo one apply: every file it wrote, back the way it was
rice installs            # what was put on this machine: installed / already there / failed
rice prefs               # the Firefox preferences this plugin set, and where
rice prefs remove        # take those preferences back off (a restore cannot: see below)
rice wallpaper PIC.png   # set wallpaper, regenerate palette from it, re-theme everything
rice random ~/Pictures   # random wallpaper + re-theme (bind it to a key or a timer)
rice wallpapers nord     # list curated, theme-matched wallpapers you can download
rice get-wallpaper nord 2 --set   # curl a matching wallpaper and set it (keeps the palette)
rice accents             # list the current scheme's accent variants (6-8 per scheme)
rice accent peach --pin  # swap the accent (in-palette name or hex); --pin survives re-theming
rice theme nord          # switch to a saved profile (12 ship: catppuccin-{mocha,frappe,macchiato,latte}, gruvbox, nord, tokyo-night, rose-pine, dracula, everforest, kanagawa, solarized-dark)
rice save midnight       # snapshot the current palette as a profile
```

Personal pins go in `~/.config/hypr-rice/palette.user.conf` (`KEY=hex`) - they win over any
theme/wallpaper change, so tweaks survive re-theming. Version-control the whole rice with
`dotfiles` so every change is committed (and pushed).

You can also just **ask Hyprland config questions** ("how do I set fractional scaling in
Hyprland?", "is `drop_shadow` still valid?", "what should I use for a status bar / clipboard
manager?") - the `hyprland-reference` skill answers from versioned reference material, including
an ecosystem catalog of the common companion packages.

> **Note:** install is *additive* - each generated `.conf` is copied over the top, but the
> target directory is not wiped. Unrelated files you keep in `~/.config/hypr` (e.g.
> `hyprpaper.conf`, `hypridle.conf`, `hyprlock.conf`) are left in place, and the full prior
> state is preserved in the timestamped backup regardless.

### Starting over (bare-bones reset)

```bash
/hyprland-config:reset-config        # confirms first
/hyprland-config:reset-config -y     # skip the confirmation
```

Wipes `~/.config/hypr` down to a single minimal, working `hyprland.conf` (monitor auto-detect,
basic input, and essential keybinds - terminal, close, exit, launcher, focus, workspaces 1-5,
mouse move/resize) so you can rebuild from a clean slate. The **entire** existing directory is
backed up to `~/.config/hypr.bak.<timestamp>` first, the result is live-tested, and it
auto-rolls-back if it somehow fails to load. Configs outside `~/.config/hypr` (waybar, rofi, etc.)
are untouched. Rebuild with `/hyprland-config:rice` or extend with `edit-config`.

### Restoring a backup

```bash
rm -rf ~/.config/hypr && mv ~/.config/hypr.bak.<timestamp> ~/.config/hypr
```

### Undoing an apply, and what a restore cannot take back

Every apply gets one id. Every file it writes outside `~/.config/hypr` - rendered
app configs, Firefox profile files, shell rc files - is copied to
`<path>.bak.<apply-id>` before it is overwritten and listed in that apply's
restore point:

```bash
rice restore --list       # 20260517-142233   14 file(s)
rice restore 20260517-142233
```

One command puts the whole set back: overwritten files return byte-for-byte,
files the apply created are removed, and the point clears only when every file is
done, so re-running is always safe. A file that cannot be put back is reported by
path and the rest still goes back. If a backup cannot be WRITTEN during an apply,
that surface is skipped rather than overwritten (`RENDER_SKIPPED`).

`~/.config/hypr` is deliberately separate: it keeps its own backup and
auto-rollback, above.

Two things outlive an apply and a restore cannot undo them: INSTALLED PACKAGES,
and anything written outside the tracked surfaces. Both are recorded on the
machine so you can find out afterwards what happened and act on it.

## Prerequisites

- **Arch Linux + pacman** (the install step targets `pacman` directly; an AUR helper - paru or yay -
  is auto-detected and bootstrapped if missing). On other distros the install step skips with the
  package list printed for manual install.
- **Hyprland** installed (the plugin detects the version; if neither `hyprctl` nor `Hyprland`
  is on `PATH` it assumes the latest stable syntax and tells you).
- Everything else is optional - `rice` installs whatever the interview picks need, after you confirm
  the batch once. First-party Hypr defaults: `hyprlock`, `hypridle`, `hyprpaper`, `hyprpicker`,
  `hyprshot`, `hyprsunset`, `hyprpolkitagent`. Common extras: `waybar`/`hyprpanel`, `wofi`/`rofi`/
  `fuzzel`, `mako`/`dunst`/`swaync`, `swww`, `cliphist` + `wl-clipboard`, `wlogout`, `swayosd`,
  `grim`/`slurp`/`grimblast`, `wpctl` (PipeWire), `brightnessctl`, `playerctl`. The full ecosystem
  catalog lives in `skills/hyprland-reference/references/ecosystem.md`.

## Configuration

- `HYPR_DIR` - override the install target (default `~/.config/hypr`). Useful for testing:
  ```bash
  HYPR_DIR=/tmp/hypr-test bash skills/rice/scripts/install-config.sh <staging-dir>
  ```
- `HYPR_CONFIG_LANG`: force the config language (`lua` or `hyprlang`) instead of resolving it
  from the detected Hyprland version. Since 0.55 a `hyprland.lua` is loaded *instead of*
  `hyprland.conf`, so the language is a correctness decision, not a preference; when the version
  cannot be detected the plugin refuses to guess and asks for this variable.
  ```bash
  bash skills/rice/scripts/config-language.sh          # what would be emitted, and why
  HYPR_CONFIG_LANG=lua bash skills/rice/scripts/emit-config.sh /tmp/hypr-stage
  bash skills/rice/scripts/migrate-config.sh           # offer to convert an existing .conf set
  bash skills/rice/scripts/migrate-config.sh --convert # accept; the .conf is kept as a backup
  ```
  The conversion follows `source =` lines, so a modular set converts as one unit. A line with no
  documented lua mapping (`bezier`, `animation`, `gesture`) is carried across as a `-- NOT APPLIED`
  comment and reported (`NOT_APPLIED=`, `MIGRATE=ok-with-unmapped`) rather than silently dropped:
  it stops taking effect once the lua exists, and the kept `.conf` is where you port it from.
- `HYPR_BACKUP_DIR`: where `migrate-config.sh` writes its `.pre-lua.<timestamp>` backups
  (default: `$HYPR_DIR`).

## Installation (local testing)

```bash
claude --plugin-dir /home/nschatz/projects/hyprland-plugin
```

## Layout

```
.claude-plugin/plugin.json
skills/     rice · edit-config · dotfiles · hyprland-reference
agents/     interviewer · config-validator · package-installer · component-writer
commands/   reset-config
scripts/    backup-path · restore-point · rice-restore · record-answer ·
            install-packages · install-record · firefox-prefs · dotfiles · xdg-config
tests/      the bash harness; tests/integration/ is the container run
```

`CLAUDE.md` carries the invariant every change is held to and the gate command.
`tests/README.md` is the table of what each test file covers.

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).

## License

MIT

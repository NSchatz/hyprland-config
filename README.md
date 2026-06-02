# hyprland-config

A Claude Code plugin that generates complete, validated [Hyprland](https://hyprland.org)
configurations from scratch through an interactive interview — then writes them, safely backed
up, into `~/.config/hypr`.

## What it does

- **Interviews you** about monitors & input, keybinds & apps, look & feel, and autostart & env.
- **Detects your installed Hyprland version** (`hyprctl version`) and emits matching syntax —
  no deprecated options from old tutorials. Conventions are grounded in the **shipped default
  config** and popular community dotfiles: the official keybind scheme (Q=terminal, C=close,
  R=menu, E=files, V=float, M=exit) with `$mainMod`, `layoutmsg, togglesplit`, the `gesture=`
  touchpad API, `windowrule { match:… }` block rules (0.53+), `rounding_power`, and the
  well-tuned default animation curves.
- **Knows the Hyprland ecosystem.** It probes which companion packages you have installed and
  wires in first-party tools by default — `hyprlock`, `hypridle`, `hyprpaper`, `hyprpicker`,
  `hyprshot`, `hyprsunset`, `hyprpolkitagent` — alongside common community choices (waybar /
  hyprpanel, wofi / rofi / fuzzel, mako / dunst / swaync, swww, cliphist, wlogout, swayosd, and
  the `xdg-desktop-portal-hyprland` stack for screen sharing).
- **Generates a modular config**: a main `hyprland.conf` that `source=`s topic files
  (`env`, `monitors`, `input`, `looknfeel`, `binds`, `windowrules`, `autostart`).
- **Generates companion configs** when you opt in: starter `hyprlock.conf`, `hypridle.conf`,
  and `hyprpaper.conf` (read by their own daemons, not `source=`d).
- **Backs up safely**: copies your existing `~/.config/hypr` to a timestamped
  `~/.config/hypr.bak.<timestamp>` before writing anything.
- **Live-tests every change**: after writing, it runs `hyprctl reload` + `hyprctl configerrors`
  to confirm the config actually loads — and **automatically rolls back** to the backup if it
  doesn't. The `edit-config` skill does the same after *each* incremental edit, so a broken
  change never silently persists.
- **Reads your existing config**: follows `source=` includes to understand your current setup,
  whether to pre-fill the interview or to make a targeted edit.
- **Themes the whole desktop from one palette**: named scheme, wallpaper-generated
  (matugen/wallust), or manual hex — rendered into Hyprland, hyprlock, waybar, notifications,
  launcher, terminal, and GTK/Qt/cursor/icons, then hot-reloaded.
- **Is a real rice engine**: scaffolds a self-contained `~/.config/hypr-rice/` (one `palette.conf`
  source of truth + per-app templates + a `rice` CLI) that re-themes everything with one command,
  keeps working **without** the plugin, supports **wallpaper-driven** theming, **named profiles**
  with a **user-override cascade**, and **version control** of the whole rice in git.
- **Configures the terminal and desktop shell**: bash/zsh/fish setup (prompt, aliases, env) and
  the bar/launcher/notification functional configs — each backed up and tested after every change.
- **Validates** the result with a dedicated agent that checks syntax, deprecations, and
  conflicts (duplicate binds, undefined variables, missing source files), flags
  referenced-but-not-installed ecosystem tools, and can run a live load-test on request.

## Components

| Type  | Name                        | Purpose                                                        |
|-------|-----------------------------|----------------------------------------------------------------|
| Skill | `rice`                      | User-invoked. The whole rice in one skill: **generate** a config from scratch (interview incl. palette & fonts → modular config → install + live-test), **theme** every surface from one palette (named / wallpaper-generated / manual + font choices), manage named **profiles** (12 presets + a user-override cascade), and set/cycle the **wallpaper** with dynamic theming — all driven by a self-contained rice engine (`~/.config/hypr-rice/` with `palette.conf` + templates + a `rice` CLI). |
| Skill | `edit-config`               | User-invoked. Reads an existing config and makes changes, **testing after every change** with auto-rollback. |
| Skill | `shell-config`              | User-invoked. Configures the terminal shell (bash/zsh/fish): prompt, aliases, env, history, a startup **fetch** (fastfetch default / neofetch), and modern-CLI integration — syntax-checked after every change. |
| Skill | `desktop-shell`             | User-invoked. Functional configs for the bar (waybar), launcher (wofi/rofi), and notifications (mako/dunst). |
| Skill | `dotfiles`                  | User-invoked. Version-controls the configs in git (bare-repo / stow / chezmoi) and commits after each verified change. |
| Skill | `hyprland-reference`        | Auto-triggered. Hyprland config syntax, ecosystem, **testing**, and a **styling reference library** (per-package design guides + cross-cutting design principles, researched from the community). |
| Command | `reset-config`            | User-invoked. Wipes `~/.config/hypr` to a minimal bare-bones `hyprland.conf` — full backup + live-test + auto-rollback. |
| Agent | `hyprland-config-validator` | Static validation (plus an optional live load-test) of a generated/edited config. |

## Usage

Build a config from scratch:

```
/hyprland-config:rice
```

Optionally pass hints to pre-fill the interview:

```
/hyprland-config:rice set up from scratch — dual monitor, vim keybinds, no animations
```

The `rice` skill picks the mode from your request (generate / theme / profiles / wallpaper). For a
fresh build it walks you through one short interview, generates the config into a staging directory,
statically validates it, backs up and installs it to `~/.config/hypr`, then **live-tests** it
(`hyprctl reload` + `configerrors`) — rolling back automatically if it fails to load.

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

`rice` resolves **one palette** — a named scheme (Catppuccin, Gruvbox, Nord, Tokyo Night,
Rosé Pine), wallpaper-generated (matugen/wallust), or manual hex — and renders it into a separate
colors file for each app (Hyprland, hyprlock, waybar, mako/dunst, wofi/rofi, kitty, GTK4 `gtk.css`,
Qt, cursor/icons/fonts), then reloads each running app so it shows immediately. Re-theming later is
a one-file-per-app rewrite + reload.

### Configuring the shells

```
/hyprland-config:shell-config set up zsh with starship and aliases
/hyprland-config:desktop-shell set up waybar with battery, network, and tray
```

`shell-config` sets up your **terminal shell** (bash/zsh/fish — prompt, aliases, env, history, a
startup **fetch** [fastfetch by default, or neofetch], and guarded `eza`/`bat`/`zoxide`/`fzf`
integration) inside a managed block, **syntax-checking after every change** (parse-only, never
executed). `desktop-shell` writes the **functional** configs for waybar / launcher / notifications
(colors come from `rice`). `rice` also **presents font choices** — a UI font and a
monospace/Nerd font (needed for bar/fetch/prompt glyphs) — and applies them across GTK, kitty, and
waybar.

### The rice engine, wallpaper, profiles

```
/hyprland-config:rice     ~/Pictures/wall.png and theme from it
/hyprland-config:rice     switch to nord
/hyprland-config:rice     save my current look as midnight
/hyprland-config:dotfiles set up a bare repo and push to github
```

`rice` scaffolds a self-contained engine into `~/.config/hypr-rice/` — one `palette.conf`
+ per-app templates + a `rice` CLI. After setup it keeps working **without Claude**:

```bash
rice apply               # re-render every app from palette.conf and reload
rice wallpaper PIC.png   # set wallpaper, regenerate palette from it, re-theme everything
rice random ~/Pictures   # random wallpaper + re-theme (bind it to a key or a timer)
rice wallpapers nord     # list curated, theme-matched wallpapers you can download
rice get-wallpaper nord 2 --set   # curl a matching wallpaper and set it (keeps the palette)
rice accents             # list the current scheme's accent variants (6-8 per scheme)
rice accent peach --pin  # swap the accent (in-palette name or hex); --pin survives re-theming
rice theme nord          # switch to a saved profile (12 ship: catppuccin-{mocha,frappe,macchiato,latte}, gruvbox, nord, tokyo-night, rose-pine, dracula, everforest, kanagawa, solarized-dark)
rice save midnight       # snapshot the current palette as a profile
```

Personal pins go in `~/.config/hypr-rice/palette.user.conf` (`KEY=hex`) — they win over any
theme/wallpaper change, so tweaks survive re-theming. Version-control the whole rice with
`dotfiles` so every change is committed (and pushed).

You can also just **ask Hyprland config questions** ("how do I set fractional scaling in
Hyprland?", "is `drop_shadow` still valid?", "what should I use for a status bar / clipboard
manager?") — the `hyprland-reference` skill answers from versioned reference material, including
an ecosystem catalog of the common companion packages.

> **Note:** install is *additive* — each generated `.conf` is copied over the top, but the
> target directory is not wiped. Unrelated files you keep in `~/.config/hypr` (e.g.
> `hyprpaper.conf`, `hypridle.conf`, `hyprlock.conf`) are left in place, and the full prior
> state is preserved in the timestamped backup regardless.

### Starting over (bare-bones reset)

```bash
/hyprland-config:reset-config        # confirms first
/hyprland-config:reset-config -y     # skip the confirmation
```

Wipes `~/.config/hypr` down to a single minimal, working `hyprland.conf` (monitor auto-detect,
basic input, and essential keybinds — terminal, close, exit, launcher, focus, workspaces 1–5,
mouse move/resize) so you can rebuild from a clean slate. The **entire** existing directory is
backed up to `~/.config/hypr.bak.<timestamp>` first, the result is live-tested, and it
auto-rolls-back if it somehow fails to load. Configs outside `~/.config/hypr` (waybar, rofi, etc.)
are untouched. Rebuild with `/hyprland-config:rice` or extend with `edit-config`.

### Restoring a backup

```bash
rm -rf ~/.config/hypr && mv ~/.config/hypr.bak.<timestamp> ~/.config/hypr
```

## Prerequisites

- **Hyprland** installed (the plugin detects the version; if neither `hyprctl` nor `Hyprland`
  is on `PATH` it assumes the latest stable syntax and tells you).
- Common companions are optional — the generator **probes which you have installed** and biases
  defaults toward them, but you can pick anything. First-party defaults: `hyprlock`, `hypridle`,
  `hyprpaper`, `hyprpicker`, `hyprshot`, `hyprsunset`, `hyprpolkitagent`. Common extras:
  `waybar`/`hyprpanel`, `wofi`/`rofi`/`fuzzel`, `mako`/`dunst`/`swaync`, `swww`, `cliphist` +
  `wl-clipboard`, `wlogout`, `swayosd`, `grim`/`slurp`/`grimblast`, `wpctl` (PipeWire),
  `brightnessctl`, `playerctl`.
- For **screen sharing** and native file pickers, install `xdg-desktop-portal-hyprland` and
  `xdg-desktop-portal-gtk`. The validator notes these if missing.
- Generated lines for tools you don't have are harmless no-ops — install the tool or remove the
  line. The full ecosystem catalog lives in
  `skills/hyprland-reference/references/ecosystem.md`.

## Configuration

- `HYPR_DIR` — override the install target (default `~/.config/hypr`). Useful for testing:
  ```bash
  HYPR_DIR=/tmp/hypr-test bash skills/rice/scripts/install-config.sh <staging-dir>
  ```

## Installation (local testing)

```bash
claude --plugin-dir /home/nschatz/projects/hyprland-plugin
```

## Layout

```
hyprland-config/
├── .claude-plugin/plugin.json
├── commands/
│   └── reset-config.md              # /hyprland-config:reset-config (bare-bones reset)
├── agents/
│   └── hyprland-config-validator.md
├── scripts/                         # shared across skills
│   ├── backup-path.sh               # timestamped backup of arbitrary paths
│   └── dotfiles.sh                  # git versioning: bare / stow / chezmoi
├── skills/
│   ├── rice/              (generate + theme + profiles + wallpaper — the whole rice)
│   │   ├── references/   (interview, config-templates, theming, palettes, templates, fonts,
│   │   │                  engine, apps, login, wallpaper)
│   │   ├── scripts/      (detect-version, detect-theme-tools, rice-init, render-templates,
│   │   │                  apply-theme, set-wallpaper, palette-from-wallpaper, safe-apply,
│   │   │                  install-config, verify-config, backup-config, reset-config)
│   │   ├── templates/    (*.tmpl color templates rendered by the engine)
│   │   ├── assets/       (rice CLI, profiles/*.conf presets, wallpapers.tsv catalog)
│   │   └── examples/     (a complete generated modular config)
│   ├── edit-config/       (read + change existing config, test after every change)
│   ├── shell-config/      (bash/zsh/fish: prompt, aliases, fetch; parse-checked)
│   ├── desktop-shell/     (waybar / launcher / notification functional configs)
│   ├── dotfiles/          (git version control of the configs)
│   └── hyprland-reference/  (auto-triggered: syntax, ecosystem, testing knowledge)
│       └── references/styling/  (per-package styling guides + design principles, researched)
└── README.md
```

The **rice engine** the plugin scaffolds (lives in your home, version-controlled by you):

```
~/.config/hypr-rice/
├── palette.conf        # source of truth (KEY=hex + scheme/wallpaper/fonts)
├── palette.user.conf   # your overrides — win over everything (optional)
├── templates/          # <app>.tmpl files
├── templates.list      # render manifest
├── profiles/           # saved + preset rices (*.conf)
├── render-templates.sh # the engine
└── rice                # the CLI
```

## License

MIT

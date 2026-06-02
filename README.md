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
- **Configures the terminal and desktop shell**: bash/zsh/fish setup (prompt, aliases, env) and
  the bar/launcher/notification functional configs — each backed up and tested after every change.
- **Validates** the result with a dedicated agent that checks syntax, deprecations, and
  conflicts (duplicate binds, undefined variables, missing source files), flags
  referenced-but-not-installed ecosystem tools, and can run a live load-test on request.

## Components

| Type  | Name                        | Purpose                                                        |
|-------|-----------------------------|----------------------------------------------------------------|
| Skill | `generate-config`           | User-invoked. Runs the interview, writes the config, and live-tests it. |
| Skill | `edit-config`               | User-invoked. Reads an existing config and makes changes, **testing after every change** with auto-rollback. |
| Skill | `theme-config`              | User-invoked. Applies one palette (named / wallpaper-generated / manual) across **every surface** — Hyprland, hyprlock, waybar, notifications, launcher, terminal, GTK/Qt/cursor/icons — and **presents font choices** (UI + monospace/Nerd). |
| Skill | `shell-config`              | User-invoked. Configures the terminal shell (bash/zsh/fish): prompt, aliases, env, history, a startup **fetch** (fastfetch default / neofetch), and modern-CLI integration — syntax-checked after every change. |
| Skill | `desktop-shell`             | User-invoked. Functional configs for the bar (waybar), launcher (wofi/rofi), and notifications (mako/dunst). |
| Skill | `hyprland-reference`        | Auto-triggered. Hyprland config syntax, ecosystem, and **testing** knowledge. |
| Agent | `hyprland-config-validator` | Static validation (plus an optional live load-test) of a generated/edited config. |

## Usage

Run the generator:

```
/hyprland-config:generate-config
```

Optionally pass hints to pre-fill the interview:

```
/hyprland-config:generate-config dual monitor, vim keybinds, no animations
```

The skill walks you through a short interview, generates the config into a staging directory,
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
/hyprland-config:theme-config catppuccin mocha
/hyprland-config:theme-config match my wallpaper
/hyprland-config:theme-config set my accent to #89b4fa
```

`theme-config` resolves **one palette** — a named scheme (Catppuccin, Gruvbox, Nord, Tokyo Night,
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
(colors come from `theme-config`). `theme-config` also **presents font choices** — a UI font and a
monospace/Nerd font (needed for bar/fetch/prompt glyphs) — and applies them across GTK, kitty, and
waybar.

You can also just **ask Hyprland config questions** ("how do I set fractional scaling in
Hyprland?", "is `drop_shadow` still valid?", "what should I use for a status bar / clipboard
manager?") — the `hyprland-reference` skill answers from versioned reference material, including
an ecosystem catalog of the common companion packages.

> **Note:** install is *additive* — each generated `.conf` is copied over the top, but the
> target directory is not wiped. Unrelated files you keep in `~/.config/hypr` (e.g.
> `hyprpaper.conf`, `hypridle.conf`, `hyprlock.conf`) are left in place, and the full prior
> state is preserved in the timestamped backup regardless.

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
  HYPR_DIR=/tmp/hypr-test bash skills/generate-config/scripts/install-config.sh <staging-dir>
  ```

## Installation (local testing)

```bash
claude --plugin-dir /home/nschatz/projects/hyprland-plugin
```

## Layout

```
hyprland-config/
├── .claude-plugin/plugin.json
├── agents/
│   └── hyprland-config-validator.md
├── scripts/                         # shared across skills
│   └── backup-path.sh               # timestamped backup of arbitrary paths
├── skills/
│   ├── generate-config/
│   │   ├── SKILL.md
│   │   ├── references/   (interview.md, templates.md)
│   │   ├── scripts/      (detect-version, install-config, verify-config,
│   │   │                  safe-apply, backup-config)
│   │   └── examples/     (sample-config/)
│   ├── edit-config/
│   │   └── SKILL.md      (read + change existing config, test after every change)
│   ├── theme-config/
│   │   ├── SKILL.md
│   │   ├── references/   (theming, palettes, templates, fonts)
│   │   └── scripts/      (detect-theme-tools, apply-theme)
│   ├── shell-config/
│   │   ├── SKILL.md
│   │   ├── references/   (shells)
│   │   └── scripts/      (verify-shell)
│   ├── desktop-shell/
│   │   ├── SKILL.md
│   │   └── references/   (components)
│   └── hyprland-reference/
│       ├── SKILL.md
│       └── references/   (config-syntax, sections, keybindings, window-rules,
│                          deprecations, ecosystem, testing)
└── README.md
```

## License

MIT

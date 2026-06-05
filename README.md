# hyprland-config

A Claude Code plugin that generates complete, validated [Hyprland](https://hyprland.org)
configurations from scratch through an interactive interview — then writes them, safely backed
up, into `~/.config/hypr`.

## What it does

- **Interviews you** one component at a time — monitors, input, keybinds, default apps, terminal,
  status bar, launcher, notifications, lock screen, look & feel, palette, fonts, wallpaper, autostart
  & env — then generates the whole desktop (Hyprland config **plus** the functional bar/launcher/
  notification configs), themed from one palette. **Every user sees the same menu** regardless of
  what's installed — the install step (below) adds whatever's missing.
- **Installs the packages your picks need.** After the interview, you confirm the resolved package
  batch **once**, then a dedicated agent runs the install (pacman + auto-detected paru/yay for AUR,
  bootstrap if the helper is missing). Idempotent — re-runs are safe. A reviewable **`install.sh`**
  also ships with the dotfiles so the rice replicates cleanly to a new machine.
- **Detects your installed Hyprland version** (`hyprctl version`) and emits matching syntax —
  no deprecated options from old tutorials. Conventions are grounded in the **shipped default
  config** and popular community dotfiles: the official keybind scheme (Q=terminal, C=close,
  R=menu, E=files, V=float, M=exit) with `$mainMod`, `layoutmsg, togglesplit`, the `gesture=`
  touchpad API, `windowrule { match:… }` block rules (0.53+), `rounding_power`, and the
  well-tuned default animation curves.
- **Knows the Hyprland ecosystem.** First-party defaults — `hyprlock`, `hypridle`, `hyprpaper`,
  `hyprpicker`, `hyprshot`, `hyprsunset`, `hyprpolkitagent` — alongside common community choices
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
  All of this lives in the `rice` skill on a fresh build and in `edit-config` for later edits.
- **Uses agents in parallel.** The from-scratch build spawns one **`hyprland-component-writer`**
  per surface (waybar / launcher / notifications / terminal / lock-screen / Hyprland topic files)
  so the per-component authoring runs concurrently instead of serializing on the main loop.
- **Validates** the result with the **`hyprland-config-validator`** agent — syntax, deprecations,
  conflicts (duplicate binds, undefined variables, missing source files), flags ecosystem coherence
  issues, optional live load-test. Invoked automatically after generation **and** after non-trivial
  edits.

## Components

| Type  | Name                        | Purpose                                                        |
|-------|-----------------------------|----------------------------------------------------------------|
| Skill | `rice`                      | User-invoked. The **all-in-one** rice: **generate** a whole desktop from scratch (per-component interview → modular Hyprland config + functional bar/launcher/notification/terminal configs + **shell & prompt** + an `install.sh` Claude actually runs after one confirmation → install + live-test), **theme** every surface from one palette (named / wallpaper-generated / manual + font choices), manage named **profiles** (12 presets + a user-override cascade), and set/cycle the **wallpaper** with dynamic theming — all driven by a self-contained rice engine (`~/.config/hypr-rice/` with `palette.conf` + templates + a `rice` CLI). |
| Skill | `edit-config`               | User-invoked. Edits an **existing** desktop config — Hyprland (`~/.config/hypr/*.conf`), the surfaces around it (waybar, wofi/rofi, mako/dunst/swaync), the terminal shell (bash/zsh/fish rc files), and companion daemons (hyprlock/hypridle/hyprpaper). **Tests after every edit** with auto-rollback (Hyprland: `hyprctl reload`; bar: JSON parse + `SIGUSR2`; shell: parse-only — never sourced). Installs any tool a requested edit needs (after asking once). |
| Skill | `dotfiles`                  | User-invoked. Version-controls the configs in git (bare-repo / stow / chezmoi) and commits after each verified change. |
| Skill | `hyprland-reference`        | Auto-triggered. Hyprland config syntax, ecosystem, **testing**, and a **styling reference library** (per-package design guides + cross-cutting design principles, researched from the community). |
| Command | `reset-config`            | User-invoked. Wipes `~/.config/hypr` to a minimal bare-bones `hyprland.conf` — full backup + live-test + auto-rollback. |
| Agent | `hyprland-interviewer`      | Owns the rice from-scratch interview (28–38 `AskUserQuestion` calls across 23 groups) and persists every answer to `<staging>/answers.json` as it goes. Runs a "review your picks" pass at the end. Returns just the file path so the main rice loop's context stays clean for the work that follows. |
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
/hyprland-config:rice set up from scratch — dual monitor, vim keybinds, no animations
```

The `rice` skill picks the mode from your request (generate / theme / profiles / wallpaper). For a
fresh build it walks you through one short interview, spawns several **component-writer agents** in
parallel to author each surface (waybar, launcher, notifications, terminal, lock-screen, Hyprland
topic files), statically validates the staging dir, **asks once to install the packages your picks
need** (handled by the installer agent — pacman + paru/yay routing), backs up and installs the
configs into `~/.config/hypr` + `~/.config/<app>/`, then **live-tests** Hyprland (`hyprctl reload` +
`configerrors`) — rolling back automatically if it fails to load.

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

### Editing the shells & surfaces around Hyprland

From-scratch builds are owned by `rice`; later edits to any surface are owned by `edit-config`:

```
/hyprland-config:edit-config set up zsh with starship and aliases
/hyprland-config:edit-config add a network module to my waybar
/hyprland-config:edit-config swap my launcher to rofi
/hyprland-config:edit-config make my notifications stay longer
```

`edit-config` covers Hyprland (`*.conf`), the desktop-shell surfaces (waybar, wofi/rofi, mako/
dunst/swaync — `style.css` + functional config), the terminal shell (bash/zsh/fish — prompt,
aliases, env, history, fetch), and companion daemons (hyprlock/hypridle/hyprpaper). Every edit is
backed up and **tested before keeping** — Hyprland gets `hyprctl reload` + `configerrors`, waybar
gets a strict JSON parse + `SIGUSR2` reload, shell rc files get parse-only (`bash -n`/`zsh -n`/
`fish --no-execute`, never sourced). If an edit needs a tool that isn't installed (e.g. you ask to
switch to rofi but it's not there), the skill installs it after asking once. Colors are always
driven through the rice engine so they stay coherent with the rest of the desktop. `rice` also
**presents font choices** — a UI font and a monospace/Nerd font (needed for bar/fetch/prompt
glyphs) — and applies them across GTK, kitty, and waybar.

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

- **Arch Linux + pacman** (the install step targets `pacman` directly; an AUR helper — paru or yay —
  is auto-detected and bootstrapped if missing). On other distros the install step skips with the
  package list printed for manual install.
- **Hyprland** installed (the plugin detects the version; if neither `hyprctl` nor `Hyprland`
  is on `PATH` it assumes the latest stable syntax and tells you).
- Everything else is optional — `rice` installs whatever the interview picks need, after you confirm
  the batch once. First-party Hypr defaults: `hyprlock`, `hypridle`, `hyprpaper`, `hyprpicker`,
  `hyprshot`, `hyprsunset`, `hyprpolkitagent`. Common extras: `waybar`/`hyprpanel`, `wofi`/`rofi`/
  `fuzzel`, `mako`/`dunst`/`swaync`, `swww`, `cliphist` + `wl-clipboard`, `wlogout`, `swayosd`,
  `grim`/`slurp`/`grimblast`, `wpctl` (PipeWire), `brightnessctl`, `playerctl`. The full ecosystem
  catalog lives in `skills/hyprland-reference/references/ecosystem.md`.

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
│   └── reset-config.md                    # /hyprland-config:reset-config (bare-bones reset)
├── agents/
│   ├── hyprland-interviewer.md            # owns the 23-group interview, writes answers.json
│   ├── hyprland-config-validator.md       # static lint (+ optional live load-test)
│   ├── hyprland-package-installer.md      # runs install.sh / ad-hoc package list
│   └── hyprland-component-writer.md       # one surface per agent, spawned in parallel
├── scripts/                               # shared across skills
│   ├── backup-path.sh                     # timestamped backup of arbitrary paths
│   ├── dotfiles.sh                        # git versioning: bare / stow / chezmoi
│   └── record-answer.sh                   # jq setpath into <staging>/answers.json
├── skills/
│   ├── rice/              (generate + theme + profiles + wallpaper + shell/desktop-shell)
│   │   ├── references/
│   │   │   ├── _interview-protocol.md          (asking discipline, components walked, no-defaulting)
│   │   │   ├── _shared/                        (palette-schema, colors-contract, dispatchers, version-matrix)
│   │   │   ├── components/                     (one folder per component — README, interview, schema,
│   │   │   │                                    template, gotchas, +styling/validation/packages/reload
│   │   │   │                                    for visual surfaces. 22 components: monitors, input,
│   │   │   │                                    keybinds, default-apps, env, look-feel, window-rules,
│   │   │   │                                    autostart, companion-daemons, plugins, terminal,
│   │   │   │                                    waybar, widgets, launcher, notifications, lock-screen,
│   │   │   │                                    shell-prompt, utilities, login-boot, gaming, laptop,
│   │   │   │                                    accessibility)
│   │   │   └── theming/                        (engine, palettes, fonts, wallpaper, apps,
│   │   │                                        theming-architecture, gtk-qt)
│   │   ├── scripts/      (detect-version, detect-theme-tools, rice-init, render-templates,
│   │   │                  apply-theme, set-wallpaper, palette-from-wallpaper, safe-apply,
│   │   │                  install-config, verify-config, verify-shell, backup-config,
│   │   │                  reset-config)
│   │   ├── templates/    (*.tmpl color templates rendered by the engine)
│   │   ├── assets/       (rice CLI, profiles/*.conf presets, wallpapers.tsv catalog)
│   │   └── examples/     (a complete generated modular config)
│   ├── edit-config/       (read + change ANY existing surface, test after every change)
│   ├── dotfiles/          (git version control of the configs)
│   └── hyprland-reference/  (auto-triggered: syntax, ecosystem, testing knowledge)
│       └── references/styling/  (design-principles only — per-surface styling now lives in
│                                  rice/references/components/<x>/styling.md)
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

## Changelog

### 0.12.0

The interview no longer drifts into hallucination after it finishes. The fix has three parts that
work together — a structured answers file, a dedicated interviewer agent, and a review pass:

- **Persisted answers (`answers.json`).** A new `scripts/record-answer.sh` `jq`-`setpath`s each
  pick into `<staging>/answers.json` as it's chosen. Every downstream step (A3 Hyprland topic
  files, A3b shell components, A3c shell/prompt, A3d install.sh, A4 palette) and every
  component-writer agent now reads picks from that file deterministically — no more recalling
  picks from a 28-round chat history. The schema (one top-level key per group, with normalised
  value types) is documented in `interview.md` so the agent and downstream code share one source
  of truth.
- **`hyprland-interviewer` agent.** A new agent owns the entire interview. The main rice loop
  spawns it once at A1; the 28–38 `AskUserQuestion` calls happen *inside* the agent's context, and
  the main loop sees a single short tool result (`answers_file: …`, summary). This is the
  structural fix: the Q/A noise that used to crowd out generation now stays in the subagent.
- **Review pass.** Before returning, the interviewer prints a structured summary of the key
  picks (palette, fonts, bar, launcher, terminal, notifications, shell, opt-ins) and asks once:
  approve / fix one or more groups / start over. "Fix" re-asks just the chosen group(s) and
  loops back to the review.
- **Mode B (re-theming)** keeps its inline interview (only 4 groups — too light to need the
  agent) but still uses `record-answer.sh`, so a later A-mode build or a profile save can replay
  the picks exactly.

### 0.11.0

A structural overhaul — what the plugin **does** (it installs now), how it **chooses** (no
detection-based filtering), how it's **organized** (four skills instead of six), and how it
**works** (parallel agents).

- **Claude installs packages.** The strict "never install" policy is gone. After the interview
  the user confirms the resolved package batch **once**; a new **`hyprland-package-installer`**
  agent then runs the install (pacman + auto-detected paru/yay, with a one-question bootstrap if
  no AUR helper is present). Idempotent (`--needed`); retries transient failures; classifies real
  ones; returns a structured `INSTALL=ok|partial|failed|skipped` verdict the rice flow acts on.
  `install.sh` still ships as a reviewable artifact so the rice replicates to a new machine.
  Same policy in `edit-config`: an edit that needs a missing tool installs it after one ask.
- **The interview stops filtering by what's installed.** Every user sees the same menu of choices;
  detection's `HAVE_*`/`MISSING_*` flags only annotate the install batch (`# installed` comments
  + `--needed`) and don't reorder, hide, or default-bias the options. Group 21 (laptop) is now
  opt-in with the DMI chassis answer as just the default — desktops are no longer silently skipped
  past it. **Factual** detection still drives correctness (Hyprland version, GPU driver, uwsm
  session, monitor names, chassis as default).
- **Four skills, not six.** `desktop-shell` (waybar/launcher/notifications) and `shell-config`
  (bash/zsh/fish) are merged: their **recipes** now live under `rice/references/` (`components.md`
  and `shells.md` — same files), and their **editing entry point** lives in `edit-config`, which
  now covers Hyprland *and* the surfaces around it *and* the terminal shell — one
  "edit→verify→roll-back" loop per surface (Hyprland: `hyprctl reload`; waybar: JSON parse +
  `SIGUSR2`; shells: parse-only, never sourced). The from-scratch story (rice) is unchanged in
  scope.
- **Parallel writers.** A new **`hyprland-component-writer`** agent authors one surface (waybar,
  launcher, notifications, terminal, lock-screen, a Hyprland topic file) into staging. Mode A
  spawns several in parallel — one per surface — so the per-component writing doesn't serialize on
  the main loop. Each writer reads only its own recipe, fills the template, validates the output
  (JSON parse / balanced braces / deprecation check) and returns a verdict; failed surfaces
  re-spawn individually.
- **Validator becomes a post-edit default.** `edit-config` step 5 invokes
  `hyprland-config-validator` after non-trivial edits as a matter of course — not just on demand.

### 0.10.0

A from-scratch build now hands the user a **generated `install.sh`** for the packages their interview
picks need — closing the gap between "the config is written" and "the apps it references exist." The
skill still **never installs** anything; the script is a single reviewable artifact the user runs.

- **New step A3d — generate `install.sh`.** Walking the actual answers across all 23 groups, the skill
  collects each chosen tool's package into one list and emits a self-contained installer that
  **auto-routes at runtime**: `pacman -Si <pkg>` decides whether each name is an official-repo package
  (installed via `pacman`) or from the AUR (installed via a detected `paru`/`yay` helper) — so packages
  that have drifted between the repos and the AUR (`swww`/`swaync`/`ghostty`/`cliphist`) land in the
  right bucket on the user's actual system, no static classification to go stale. `--needed` makes it
  **idempotent** — already-installed packages are skipped, nothing is reinstalled or upgraded. Targets
  **Arch + AUR** (where the Hyprland ecosystem lives); on other distros it prints the name list. Stages
  to `~/.config/hypr/install.sh`, so it travels with the config + its backup and version-controls with
  the **dotfiles** skill.
- **New reference — [`packages.md`](skills/rice/references/packages.md).** The authoritative
  selection→package map (repo vs AUR) across every group — compositor/portals, terminal, bar, widgets,
  launcher, notifications, palette generators, fonts, utilities, shell/prompt — plus the script shape.
  Login/boot packages (group 19) go in a commented `sudo` block; group-23 **hyprpm plugins** stay in a
  separate commented section (built from source, pinned to the Hyprland build — never inline with the
  package installs), with the build toolchain folded into `REPO`.
- **A6 surfaces it first.** When anything was missing, the report tells the user to run `install.sh`
  *before* starting the autostart daemons / next login — otherwise the bar, wallpaper daemon, and
  notification daemon have nothing to launch.

### 0.9.0

A second **interview expansion** from deep research across the GitHub `hyprland` topic (HyDE, end-4,
ML4W, JaKooLit, Omarchy, caelestia) and the Hyprland wiki — closing the gaps the survey surfaced. The
interview grows from **22 groups to 23** and ~26–34 calls to **~28–38**.

- **New group 23 — "Hyprland plugins"** (hyprpm, opt-in). The community-plugin layer every power rice
  reaches for: `hyprexpo` workspace overview, `hyprscrolling`/`hy3` scrolling & tree layouts,
  `split-monitor-workspaces`, `hyprbars`, `pyprland` dropdown scratchpads, and the decorative set. Plugins
  are pinned to the exact Hyprland build, so install stays a *user* action — the plugin generates the
  `plugin {}` blocks (→ `plugins.conf`) + binds and prints the `hyprpm` commands, never runs them. See
  [`plugins.md`](skills/rice/references/plugins.md). (Replaces the 0.8.0 "deferred" note.)
- **Live theme switching.** A new group-3 keybind (`SUPER+SHIFT+T` menu, `SUPER+CTRL+T` dark/light
  toggle) backed by new engine commands `rice theme-toggle <a> <b>` / `rice theme-next` and a shipped
  `theme-switch.sh` — the live switcher every major distro ships, leveraging the existing profile engine.
- **Expanded group 2 — Input.** Key repeat rate/delay, focus model (`follow_mouse`), mouse sensitivity,
  and a **touchpad-gestures** sub-question (0.45+ `gesture =` API: workspace swipe, move, pinch-float).
- **Smaller gaps closed.** Pin-apps-to-workspaces (1), terminal window swallowing (5), turnkey pre-built
  Quickshell shells — end-4/caelestia/Noctalia/DankMaterialShell (7), the 2025 launchers
  vicinae/walker/anyrun (8), hyprlock fingerprint auth (10), a hypridle idle-tier ladder (16), and
  satty/wl-screenrec as the modern annotation/recording picks (18).

### 0.8.0

A broad **interview expansion** — built from deep research across the GitHub `hyprland` topic (ML4W,
JaKooLit, HyDE, end-4, Omarchy, caelestia, gh0stzk), the Hyprland wiki, and the companion-tool
ecosystem. The interview grows from 17 groups to **22**, surfacing capabilities the reference layer
already knew but never *asked* about, plus genuinely new categories. Functional helper scripts ship as
plugin template files in [`skills/rice/assets/scripts/`](skills/rice/assets/scripts/).

- **New group 18 — "Utilities & menus."** The screenshot / screen-record / OCR / color-picker /
  clipboard / emoji / power-menu tools every popular rice ships. Seven shipped scripts (`screenshot.sh`,
  `screenrecord.sh`, `ocr.sh`, `colorpicker.sh`, `powermenu.sh`, `keybind-cheatsheet.sh`,
  `blur-toggle.sh`) auto-detect the best installed tool; Wi-Fi/Bluetooth documented as the robust tray
  applets rather than fragile homegrown parsers. See [`utilities.md`](skills/rice/references/utilities.md).
- **New group 19 — "Login & boot."** Wires the previously-orphaned
  [`login.md`](skills/rice/references/login.md) into the interview: palette-matched SDDM/greetd greeter
  + Plymouth + GRUB, generated root-side with the exact `sudo` commands (never run for you).
- **New group 20 — "Gaming & performance"** (opt-in). Tearing (`allow_tearing` + per-class `immediate`,
  with the kernel-gated `WLR_DRM_NO_ATOMIC`), VRR modes, fullscreen effect-stripping, `misc:vfr` as an
  unconditional default, and a shipped `gamemode.sh` toggle. See [`gaming.md`](skills/rice/references/gaming.md).
- **New group 21 — "Laptop"** (self-skips on desktops via DMI/battery detection): lid-close action,
  power-profile tool, optional battery charge limit.
- **New group 22 — "Accessibility"** (opt-in): built-in cursor-zoom magnifier, large cursor, night-light
  toggle, larger-UI preset.
- **Expanded existing groups.** Monitors (1) gains per-monitor VRR/transform/mirror/10-bit, dock/undock
  `desc:` profiles, and workspace rules (per-monitor binding, persistent, scratchpad, smart-gaps).
  Keybinds (3) gains a resize submap and the cheat-sheet. Look & feel (11) gains window groups/tabs,
  per-app window rules, and a blur toggle. Group 15's NVIDIA env tightened to the 2026 slim set.
- **Detection.** `detect-version.sh` now reports `IS_LAPTOP`/`HAVE_BATTERY`/`HAVE_LID`, `MONITOR_COUNT`,
  `POWER_TOOL`, and the extra utility tools, so the new groups self-gate and bias defaults to what's
  installed. A full from-scratch run is now ~26–34 calls (fewer when conditional groups skip).
- *Deferred to a later release:* a hyprpm community-plugins group (hyprexpo/hyprbars/hy3/hyprwinwrap)
  — **shipped in 0.9.0** — and a 0.55+ Lua-dialect output branch (still deferred).

### 0.7.0

An extensive **desktop-widget** implementation — the widget shells (dashboards, sidebars, OSDs, control
centers, notification hubs, music players, overviews) that define the modern Hyprland scene, which the
styling library had no coverage of. Built from a wide survey of the GitHub `hyprland`/`quickshell` topics
and r/unixporn:

- **Four new styling references.** [`styling/widgets.md`](skills/hyprland-reference/references/styling/widgets.md)
  is the cross-cutting decision guide — a system-by-system **decision matrix** (waybar+custom · eww ·
  AGS/Astal · Quickshell · HyprPanel · fabric · nwg-shell), the ranked **widget archetypes**, turnkey
  panels, and the cross-toolkit theming flow. Three deep per-toolkit pages back it: **`eww.md`** (yuck +
  SCSS — cards, sliders, circular-progress, reveal animations), **`ags-astal.md`** (the v1→v2/Astal
  split, material cards, quick-settings toggles, blurred album-art player, matugen Material You), and
  **`quickshell.md`** (QML, *not* CSS — the `Theme`/`Colors` singleton, `Behavior` animations,
  layer-namespace blur). Each is attributed to real community configs.
- **New interview group 7 — "Desktop widgets."** A `6a` **bar & shell strategy** question now decides
  waybar vs waybar+widgets vs a full shell that *replaces* the bar (Quickshell/AGS) vs HyprPanel; group 7
  then walks the **widget system**, **which widgets** (OSD · notification center · dashboard · music ·
  calendar · power menu · sidebar · gauges · overview), the **look**, and **motion/density**. The
  remaining groups renumbered (launcher→8 … shell & prompt→17); a from-scratch run is now ~22–28 calls.
- **Engine widget-shell theming.** New `eww.tmpl` → eww `colors.scss`, `ags.tmpl` → AGS/Astal
  `colors.scss`, `quickshell.tmpl` → Quickshell `Colors.qml`, registered in the manifest when a shell is
  chosen so `rice apply` re-themes it with everything else (HyprPanel/Material-You shells are driven by
  matugen instead). See `engine.md` → "Widget-shell theming".

### 0.6.0

A dedicated **waybar design** interview group, backed by a styling reference rebuilt from a wide survey
of the community:

- **Survey of ~55 configs.** Read the `config.jsonc` + `style.css` of every reachable example linked off
  the [Waybar Examples wiki](https://github.com/Alexays/Waybar/wiki/Examples), extracting the recurring
  design axes and the long-tail tricks.
- **Group 6 is now "Status bar + waybar design"** (4 calls). Beyond the functional questions (tool,
  modules, clock) it walks the look language: **archetype** (floating islands · separated pills · single
  lozenge · edge-to-edge · powerline · dock), **corner style**, **transparency** (translucent/glassy/
  frosted/opaque), **depth**, **workspace indicator** (pill-fill · underline · dots · numbers), **accent
  strategy** (single · per-module hue · monochrome · semantic-state), **accent application** (text vs
  inverted-pill), **motion**, and **module grouping** (inline · drawer-collapsed · powerline). Options are
  ordered by how often the pattern appears in the corpus.
- **`styling/waybar.md` grew a "Bar form" section** — **vertical** bars (`position:left/right`, `rotate`,
  two-line formats, vertical sliders, edge-hugging radius), **dual** top+bottom bars (JSON array of named
  bars), and **dock / macOS Sequoia / Windows 10** mimic recipes — plus two new archetypes (powerline,
  dock) and ~20 newly-harvested techniques (single-lozenge `7rem` pill, two-level pill nesting, inverted
  candy pills, `border-color`-as-state, stepped blink, springy overshoot, glassmorphism stack, icon-gauge
  ramps, conditional `.solo`/`.empty` backdrops, theme-as-folder, …).

### 0.5.0

Hardening from real-world ricing — uwsm sessions, NVIDIA/nouveau cursors, GTK install quirks, and a
clearer shell setup:

- **uwsm session awareness.** `detect-version.sh` now reports `HAVE_uwsm` / `UWSM_ENV` /
  `UWSM_SESSION`. On uwsm-launched sessions, `~/.config/uwsm/env` is the **authoritative** env source
  and overrides `hypr/env.conf` for app launches — including `GTK_THEME` (which silently overrides
  GTK theming) and the cursor vars. The rice/theming skills now edit it and live-propagate with
  explicit `dbus-update-activation-environment` pairs.
- **Disappearing cursor fix.** Detects `CURSOR_NO_HARDWARE_RECOMMENDED` on nouveau/NVIDIA and emits a
  `cursor { no_hardware_cursors = true }` block — the cursor no longer vanishes when the screen is idle.
- **GTK theming robustness.** `render-templates.sh` replaces a symlinked `gtk-4.0/gtk.css` instead of
  failing with *Permission denied*; docs cover murrine-dependent AUR themes that won't `yay`-install
  (build from SCSS with `sassc` instead), the `GTK_THEME` env override, and that **folder color is the
  icon theme, not the GTK theme**.
- **Shell setup.** The interview now **explicitly asks which shell you want** (fish first-class for
  built-in autocomplete), adds an optional **fisher plugin** set (autopair · fzf.fish · sponge · done)
  recorded in `fish_plugins`, documents the alias-vs-`abbr` split, the per-terminal `shell` directive
  as a lower-risk alternative to `chsh`, and the "changes only apply to new shells" gotcha.

## License

MIT

---
name: rice
description: This skill should be used when the user runs "/hyprland-config:rice" or asks to build, theme, or restyle their Hyprland desktop — i.e. (1) GENERATE a config from scratch ("generate/create my hyprland.conf", "set up Hyprland from scratch", "make me a new config", "build a hyprland config"); (2) THEME/recolor/set fonts ("theme my desktop", "apply Catppuccin/Gruvbox/Nord/Tokyo Night/Dracula/Everforest/Kanagawa/Solarized/Rosé Pine", "change my color scheme/accent", "match my colors to my wallpaper", "set up matugen/wallust", "change my font"); (3) manage named theme PROFILES / "rices" ("save my theme as X", "switch to nord", "list my themes", "load my <name> rice", "pin my accent"); or (4) set/change/cycle the WALLPAPER ("set my wallpaper", "random wallpaper", "make my theme match my wallpaper"). It runs one interactive interview, generates a modular version-matched config, and drives a self-contained rice engine (~/.config/hypr-rice/ — one palette.conf + templates + a `rice` CLI + profiles + a user-override cascade) that themes Hyprland, hyprlock, waybar, notifications, launcher, terminal, GTK/Qt/cursor/icons/fonts and the wallpaper consistently — backing up, live-testing, and reloading after every change.
argument-hint: "[what you want, e.g. 'set up from scratch', 'catppuccin mocha', 'switch to nord', 'wallpaper ~/x.png and theme from it']"
allowed-tools: AskUserQuestion, Bash, Read, Write, Edit, Glob, Grep, Agent
version: 0.12.0
---

# Rice — Build & Theme the Hyprland Desktop

The **all-in-one** rice skill: **generate** a complete Hyprland desktop from scratch — compositor,
terminal, status bar, launcher, notifications, lock screen, **shell & prompt** — **theme** every surface
from one palette, manage named **profiles**, and set the **wallpaper** (with dynamic theming). A
from-scratch build emits not just the Hyprland config but the **functional** configs for the whole shell
(waybar `config.jsonc` + `style.css`, launcher config, notification daemon config), sets up the
interactive shell (prompt engine + fish colors + fetch), and **installs the packages the picks need**
(Arch + AUR; the user confirms the batch once, then `install.sh` ships as a reviewable artifact so the
dotfiles travel to a new machine cleanly), so the user gets a working, themed desktop in one pass. They are one skill because they share one source of truth — the **rice engine** at
`~/.config/hypr-rice/` (`palette.conf` → templates → every app's colors, driven by the `rice` CLI). Read
`references/engine.md` for the engine contract before touching it. The functional shell-config recipes
live in `references/components.md` and the terminal-shell recipes in `references/shells.md` (used by
rice for both generation and for `edit-config`'s later edits — one source per surface).

Treat `$ARGUMENTS` as the request (a scheme name, an image path, "set up from scratch", "switch to
nord", freeform setup hints). Use it to pick the **mode** (A/B/C/D). Use it to **reorder option
lists** in the interview so a hinted pick is the first option (so the user can confirm with one
press). **Do not use it to skip interview questions** — the user has explicitly required every
sub-question be asked (see Safety rules below + the interviewer agent's prompt).

This skill leans on the **hyprland-reference** skill for syntax and look-and-feel. Read its files
under `skills/hyprland-reference/references/` when generating or theming, and **cross-check every
emitted option against `deprecations.md`** so deprecated syntax never ships. For tasteful defaults
(so a generated config looks designed, not stock-gray) consult the styling library
`skills/hyprland-reference/references/styling/` — `design-principles.md` (coherence, accent
discipline, the archetypes) and the per-app pages (`hyprland-decoration.md`, `waybar.md`,
`widgets.md` + `eww.md`/`ags-astal.md`/`quickshell.md` (desktop widget shells), `terminals.md`,
`notifications.md`, `launchers.md`, `hyprlock.md`, `gtk-qt.md`, `tui-and-prompt.md`), all written
around this skill's palette contract. For companion apps read `ecosystem.md`.

## Routing — pick the mode from the request

| The user wants… | Mode | What it does |
|---|---|---|
| a config built from scratch / "set up Hyprland" / "generate hyprland.conf" | **A — Generate** | full interview → modular config + functional shell configs (bar/launcher/notifications) → install the packages the picks need → install config + live-test |
| to theme / recolor / change scheme / set fonts / match wallpaper colors | **B — Theme** | one palette across every surface |
| to save / list / switch a named rice, or pin a color | **C — Profiles** | the `rice` CLI + override cascade |
| to set / change / cycle the wallpaper | **D — Wallpaper** | set wallpaper (+ optional dynamic theme) |

They compose on the **same engine**: Mode A finishes by establishing the palette through the engine
(Mode B's machinery), so a fresh config comes out coherently themed; B, C, and D all rewrite
`palette.conf` and `rice apply`. When a request spans modes ("set up from scratch with Tokyo Night
and this wallpaper"), run A and fold the B/D answers into its interview.

Always start by detecting the **environment** (the facts that drive correctness — Hyprland version,
GPU driver, monitors, uwsm session, chassis). Do **not** use detection to filter the menu of choices
the user sees — every user is offered the same options regardless of what's currently installed, and
the install step at A5 installs whatever's missing.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/detect-version.sh"      # Hyprland version + env facts
bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/detect-theme-tools.sh"  # current gsettings + font families
```

Use these factual fields: `HYPR_VERSION=` (version-sensitive syntax — see `deprecations.md`),
`GPU_DRIVER=`/`NVIDIA_PROPRIETARY=` (gates the NVIDIA env block under the proprietary driver only),
`SWWW_DAEMON_BIN=` (`swww-daemon` vs the `awww` fork's `awww-daemon`), `UWSM_SESSION=`/`UWSM_ENV=`
(uwsm session env source), `CURSOR_NO_HARDWARE_RECOMMENDED=` (nvidia/nouveau cursor blanking),
`IS_LAPTOP=` (use as the *default* for the laptop question — never to skip it), `MONITOR_COUNT=`,
`CURRENT_*` gsettings, font families. The scripts also emit `HAVE_<tool>=1` / `MISSING_<tool>=1` —
**ignore those for filtering options**; the only legitimate use is annotating the install batch at A5
(`# installed` comments and the idempotent `--needed` flag handle that automatically).

---

## Mode A — Generate a config from scratch

Generate a complete, validated, **modular** config (a main `hyprland.conf` that `source=`s topic
files), back up any existing config, install it, and live-test with auto-rollback. Do not write to
`~/.config/hypr` until the config is generated and the user has seen the plan.

### A1. Delegate the interview to the `hyprland-interviewer` agent

The interview is 28–38 `AskUserQuestion` calls across 23 groups. **Do not run it in the main rice
loop** — by the time it finishes, the main context is full of Q/A noise and downstream steps start
hallucinating picks. Instead, set up a staging dir and spawn the **`hyprland-interviewer`** agent:

```bash
staging="/tmp/hypr-gen-$(date +%s)-$$"
mkdir -p "$staging"
```

Then call the Agent tool with `subagent_type: hyprland-interviewer` passing:
- `STAGING=<staging>`
- `HYPR_VERSION=<from detect-version.sh>`
- `ARGUMENTS=<the user's $ARGUMENTS>`
- `EXISTING_CONFIG=~/.config/hypr/hyprland.conf` (if present)
- `DETECT_VERSION=<the detect-version.sh kv dump>` / `DETECT_THEME=<detect-theme-tools.sh kv dump>`

The agent walks the question bank in `references/interview.md`, **asks every sub-question**
(see the agent's "STRICT — ASK EVERY QUESTION" rules: `(default)` only reorders the option list,
it doesn't authorize skipping; `ARGUMENTS` / `EXISTING_CONFIG` reorder, they don't answer),
records every answer to `<staging>/answers.json` as it goes (via `scripts/record-answer.sh`),
runs a "review your picks" pass at the end, and returns just the file path + a short summary.
The 23 groups stay in the agent's context; your main loop only sees the summary line.

**Verify the call count before accepting the agent's report.** If the agent returns
`groups_recorded` ≪ 23 or a summary that suggests fewer than ~28 `AskUserQuestion` calls were
made, the interview was collapsed — re-spawn the agent (or fall back to the inline question bank
in the main loop, asking each question yourself).

For **re-theming (Mode B)** you don't need the full interviewer — Mode B only asks groups 11–14
(look & feel · palette · fonts · wallpaper) inline; running the heavy agent for four groups is
overkill. Same `answers.json` schema applies though, so a Mode B run can also persist its picks
into the rice engine for later replay. The same no-defaulting rule applies: each of the 4 groups'
sub-questions still gets an `AskUserQuestion`.

### A2. Pre-load context for the interviewer

Run `detect-version.sh` + `detect-theme-tools.sh` and capture their output as the `DETECT_*` blobs
above. If `~/.config/hypr/hyprland.conf` exists, pass the path as `EXISTING_CONFIG` (the agent
reads it for monitor names + obvious current picks; the file is backed up wholesale at install,
not edited in place).

### A3. Generate into the staging dir (reading answers.json, not memory)

Build the file set in the same `<staging>` the interviewer wrote `answers.json` into (not
`~/.config/hypr`) using **`references/config-templates.md`** as the structure. **Read every pick
from `<staging>/answers.json` with `jq`** — never from memory or chat history. The schema is the
canonical map between answers and files (see `interview.md` → "Recording answers" → "How
downstream steps use it"). If the template needs a value that isn't in the file, that's a missing
question — go back through the interviewer rather than inventing.

The actual file authoring is **delegated to `hyprland-component-writer` agents in parallel** (see
A3b for the spawn pattern — the same agent handles Hyprland topic files via
`SURFACE=hyprland-topic`). Each writer gets a `jq` slice of `answers.json` as its `ANSWERS`
parameter, e.g.:

```bash
ANSWERS="$(jq '{monitors, input}' "$staging/answers.json")"
```

The main loop is responsible for:
- The index file `hyprland.conf` (variables + `source=` lines — small, benefits from the
  surrounding context),
- `colors.conf` (filled in A4 — not by hand),
- Aggregating the per-topic writer reports.

The writer agents produce the rest in parallel: `env.conf`, `monitors.conf`, `input.conf`,
`looknfeel.conf`, `binds.conf`, `windowrules.conf`, `autostart.conf`, plus the **companion configs**
(`hyprlock.conf`/`hypridle.conf`/`hyprpaper.conf`) for any tool the user chose (these are read by
their own daemons — NOT `source=`d — but stage them so they install + back up together). Match syntax
to the detected version; wire ecosystem keybinds per `config-templates.md`. `hyprland.conf` must
`source = ~/.config/hypr/colors.conf` early, and `looknfeel.conf`'s `col.active_border` defaults to
`$accent $accent2 45deg` — those vars come from the engine in A4, so the look stays in sync with a
later re-theme.

### A3b. Generate the functional shell configs — in parallel via writer agents

rice is all-in-one, so also stage the **functional** configs for the shell components chosen in
interview groups 5–10, using **`references/components.md`** as the recipe source. These live under
their own `~/.config/<app>/` dirs (not in `~/.config/hypr/`), so stage them in a parallel tree, e.g.
`<staging>/_shell/<app>/`.

**Spawn one `hyprland-component-writer` agent per surface**, in parallel (one message with several
Agent tool calls), passing each:
- `SURFACE=<waybar|launcher|notifications|terminal|lock-screen|widgets>`
- `ANSWERS=<jq slice of answers.json>` — e.g. for waybar:
  `ANSWERS="$(jq '{bar, palette, fonts}' "$staging/answers.json")"`
- `PALETTE=~/.config/hypr-rice/palette.conf`
- `STAGING=<staging>` (each writer respects the `_shell/<app>/` layout)
- `HYPR_VERSION=<x.y.z>`

Each writer reads only its own recipe, fills it, validates the output (waybar JSON parse, balanced
braces, no deprecations), and returns `COMPONENT=…` + `VALIDATED=yes|failed`. Aggregate the reports;
on any `VALIDATED=failed`, re-spawn just that writer with the failure reason. The same approach
applies to the Hyprland topic files (`env.conf`, `monitors.conf`, `input.conf`, `looknfeel.conf`,
`binds.conf`, `windowrules.conf`, `autostart.conf`, the companion `hyprlock.conf`/`hypridle.conf`/
`hyprpaper.conf`) — spawn writers with `SURFACE=hyprland-topic` and the topic sub-name; the main loop
only has to assemble + author `hyprland.conf` itself (the index file with the `source =` lines and
`$var`s), which is small and benefits from the surrounding context.

The per-surface notes the writers follow:

- **Status bar** (group 6): `waybar/config.jsonc` (the chosen modules/position/height — **strict,
  comment-free JSON**) + `waybar/style.css` (the archetype/transparency look, starting with
  `@import "colors.css";`). Validate the JSON before install (`python3 -c "import json…"`); a malformed
  `config.jsonc` makes the bar silently fail to appear.
- **Desktop widgets** (group 7): only if a widget system was chosen. For **eww** stage `eww/eww.yuck` +
  `eww/eww.scss` (`@import "colors";` → the engine's `eww.tmpl`); for an **AGS/Astal** or **Quickshell**
  shell, scaffold per its tooling and wire its colors file (`ags.tmpl`/`quickshell.tmpl`) — recipes in
  `styling/{eww,ags-astal,quickshell}.md`, wiring in `engine.md` → "Widget-shell theming". A **full shell
  replaces waybar** (drop the waybar `exec-once`) and may **own notifications** (then skip the group-9
  daemon). **HyprPanel / Material-You** shells: drive via matugen, don't hand-theme. Heavy shells
  (Quickshell/AGS) take real time to compile — warn the user about that at install time (A5) so they
  know the batch will be slow.
- **Launcher** (group 8): `wofi/config` + `wofi/style.css` (`@import "colors.css";`), or
  `rofi/config.rasi` (+ a theme that `@import`s `colors.rasi`), or fuzzel/tofi `.ini` — per the chosen
  tool/mode/layout.
- **Notifications** (group 9): `mako/config` / `dunst/dunstrc` / `swaync/config.json`+`style.css` — per
  the chosen daemon/position/timeout/behavior. Leave color keys to the engine (don't hardcode hex). Skip
  if a full widget shell (group 7) owns notifications — only one daemon can hold the D-Bus name.
- **Terminal** (group 5): the emulator's config (e.g. `kitty/kitty.conf`, `alacritty/alacritty.toml`,
  `foot/foot.ini`) with opacity/padding/cursor/font-size from the interview, including its colors file
  the engine themes (`include`/`source`).

Keep module on-clicks aligned to installed tools (network → `nm-connection-editor`, audio →
`pavucontrol`). Don't hardcode theme colors anywhere — every shell config reads the engine's colors
file. These get backed up + installed alongside the Hyprland config in A5.

### A3c. Set up the shell & prompt (group 17)

Read the shell pick from `answers.json` (`jq -r .shell_prompt.shell answers.json` → `fish`/`zsh`/
`bash`/`keep-current`; same for `.shell_prompt.prompt`, `.shell_prompt.fetch`,
`.shell_prompt.fish_colors`, `.shell_prompt.fisher`, `.shell_prompt.modern_cli`). Then configure
the interactive shell, leaning on **`references/shells.md`** (managed block, guarded inits,
parse-test) for *behavior* and the rice engine (A4) for *colors*:

- **Prompt engine** (starship default / oh-my-posh): register its manifest line so the engine renders a
  rice-owned config (`~/.config/hypr-rice/starship.toml` / `rice.omp.json`), and add the guarded init to
  the shell's managed block — starship with `export STARSHIP_CONFIG=…` first, oh-my-posh with
  `oh-my-posh init <shell> --config …`. See `engine.md` → "Shell & prompt theming" for the exact lines.
- **fish colors** (if fish): register the `fish` manifest line → `conf.d/zz-hypr-rice-colors.fish`
  (auto-sourced; themes fish's syntax highlighting from the palette).
- **Startup fetch & aliases**: add the chosen fetch (fastfetch default) + guarded modern-CLI aliases to
  the managed block per `shells.md`.

Editing rc files mid-generation is delicate (parse-test after each change, never source). If the shell
work is substantial, it's fine to finish the Hyprland install (A5/A6) first, then do the shell pass —
but the prompt/fish *colors* must go through the engine so they re-theme. Back up rc files before
editing (`backup-path.sh`).

### A3d. Generate the package install script (for review + replication)

The interview selects many tools (terminal, bar, launcher, notification daemon, fonts, palette
generator, utilities, shell/prompt, widget shell, plugins). Stage a reviewable **`install.sh`** so
the user can see exactly what will be installed and so the script ships with the dotfiles to a new
machine (idempotent on re-run). Read **`references/packages.md`** for the selection→package map and
the script shape.

**Walk `answers.json` deterministically — don't recall picks.** Iterate the answer keys, look up
each pick's package name(s) in the `packages.md` map, collect into **one `PKGS` list** (Arch + AUR
target — repo and AUR names mixed), de-dupe shared deps, and annotate already-present packages
(`HAVE_*` from detection) with `# installed`. A reference shape:

```bash
pkgs=()
[ "$(jq -r .bar.strategy        answers.json)" = "waybar" ]   && pkgs+=(waybar)
case "$(jq -r .launcher.tool      answers.json)" in
  wofi)    pkgs+=(wofi) ;;
  rofi)    pkgs+=(rofi) ;;
  fuzzel)  pkgs+=(fuzzel) ;;
  …
esac
case "$(jq -r .notifications.daemon answers.json)" in
  mako)    pkgs+=(mako) ;;
  dunst)   pkgs+=(dunst) ;;
  swaync)  pkgs+=(swaync) ;;
esac
mapfile -t utils < <(jq -r '.utilities.selected[]' answers.json)
for u in "${utils[@]}"; do …; done
…
```

(The actual mapping table lives in `packages.md` — iterate the JSON, look up the table, emit names.)
The emitted script **auto-routes at runtime** — it loops over `PKGS`, sends whatever `pacman -Si`
knows to `pacman` and the rest to a detected `paru`/`yay` helper — so you never have to classify
repo-vs-AUR (drift-proof), and `--needed` makes it idempotent (non-pacman systems just get the name
list). Group-19 login/boot packages go in a commented `sudo` block; group-23 hyprpm plugins go in
the separate commented hyprpm section (never inline) with the build toolchain added to `PKGS`.
Stage it at `<staging>/install.sh` (installs to `~/.config/hypr/install.sh`, travels with the
config + its backup, version-controls with the dotfiles skill) and `chmod +x` it.

The script is **also what A5 runs** to do the actual install — once written, you don't author a
separate install path.

### A4. Establish the palette via the rice engine

The colors/fonts from interview groups 12–14 (palette, fonts, wallpaper) live in `answers.json`
under `.palette` / `.fonts` / `.wallpaper`. Read them with `jq`; the engine's `palette.conf` is the
materialized form. Read `references/engine.md`. Then:

1. Scaffold (idempotent — never clobbers an existing palette):
   `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/rice-init.sh"`
2. Write `~/.config/hypr-rice/palette.conf` from `answers.json` — resolve the chosen source:
   - `.palette.source == "named"` → look up `.palette.scheme` in `references/palettes.md`,
   - `.palette.source == "wallpaper"` → `scripts/palette-from-wallpaper.sh "$(jq -r .wallpaper.path answers.json)"`,
   - `.palette.source == "manual"` → take the hex from `.palette.manual.*`.
   Resolve to the contract keys + `scheme`/`wallpaper`/`font_ui`/`font_mono` (from `.fonts.ui` /
   `.fonts.mono`). **Always populate `accent2`** (default it to `accent` on the manual path) — the
   border template references it.
3. Fill `<staging>/colors.conf` so it installs with the rest (don't let the engine write to
   `~/.config/hypr` before A5): take `templates/hyprland.tmpl`, substitute its `{{accent}}` etc.
   from `palette.conf`, and `Write` the result. Likewise fill any companion-config color placeholders
   **and the staged shell configs' colors files** (`_shell/<app>/colors.css`/`.rasi` etc.) by rendering
   the matching `templates/*.tmpl` so the bar/launcher/notifications install already themed. If a
   **widget shell** was chosen (group 7), **register its manifest line** (`eww`/`ags`/`quickshell` →
   its colors file) so `rice apply` re-themes it on every switch, and render its colors file into the
   staged shell tree — see `engine.md` → "Widget-shell theming" (HyprPanel/Material-You shells are
   driven by matugen instead, not the manifest).
4. **Only after a successful install** (A5 returns `ok`/`installed-untested`), run
   `bash ~/.config/hypr-rice/rice apply` so any already-present apps pick up the palette. **Skip it on
   `rolled-back`/`install-failed`** — it would re-render outside the safe-apply harness.

### A5. Validate, install packages, back up, install configs, live-test, auto-rollback

1. **Static validation:** invoke the **hyprland-config-validator** agent (Agent tool) on the staging
   dir with the detected version; fix any ERRORs and regenerate before installing.
2. **Validate the bar JSON:** for any staged `waybar/config.jsonc`, confirm it parses as strict JSON
   (`python3 -c "import json,sys; json.load(open(sys.argv[1]))" <file>`) before installing — a broken
   bar silently fails to appear.
3. **Install the packages the picks need.** Show the user the resolved `PKGS` list from A3d (with
   `# installed` annotations) and ask once with `AskUserQuestion` to confirm the install batch
   ("Install N packages now? Yes / No, I'll run install.sh later"). On yes, delegate to the
   **hyprland-package-installer** agent (Agent tool) passing the staged `install.sh`; it runs the
   script, handles `paru`/`yay` detection (offering to install one if missing), distinguishes
   transient retries from real failures, and returns a structured `INSTALL=ok|partial|failed`
   verdict + the package list. On `partial`/`failed`, surface what failed and ask whether to proceed
   with the config install anyway (some failures are non-blocking — e.g. an optional utility); the
   user can re-run `install.sh` later. On no, skip ahead and surface the `install.sh` path in A6.
4. **Safe install (Hyprland):** `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/safe-apply.sh" /tmp/hypr-gen-<id>`
   — it timestamp-backs up the **entire** `~/.config/hypr`, installs, then `hyprctl reload` +
   `configerrors`, and **auto-rolls-back** if the new config fails. Read the final `SAFE_APPLY=` line:
   `ok` (installed + clean), `rolled-back` (errors shown; restored — fix + retry),
   `installed-untested` (no running Hyprland; test next login), `install-failed`/`errors-no-backup`
   (surface + stop). Relay the `BACKUP=` path. Respect a `HYPR_DIR` override. (`install-config.sh` /
   `verify-config.sh` exist for running a step alone — see `hyprland-reference/references/testing.md`.)
5. **Install the shell configs:** only after `ok`/`installed-untested`, back up then install the staged
   `_shell/<app>/` tree to `~/.config/<app>/`: first
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" ~/.config/waybar ~/.config/wofi ~/.config/rofi ~/.config/mako ~/.config/dunst ~/.config/kitty …`
   (only the dirs you're writing), then copy each staged dir into place. Reload running apps with
   `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/apply-theme.sh"` (waybar `SIGUSR2`, mako/dunst
   reload — only if running). Skip on `rolled-back`/`install-failed`.

### A6. Report (and start the daemons)

Summarize version, files, backup, validator verdict, **`INSTALL=` package install verdict**,
`SAFE_APPLY`/`VERIFY` result, the chosen palette/fonts (now in `palette.conf` as the source of
truth), and how to restore the backup (`rm -rf ~/.config/hypr && cp -a ~/.config/hypr.bak.<ts>
~/.config/hypr && hyprctl reload`).

If the user declined the install batch at A5, point them at `~/.config/hypr/install.sh` so the bar,
wallpaper daemon, and notification daemon below have something to launch (it's idempotent — safe to
re-run after they install the helper of their choice).

**`hyprctl reload` does NOT run `exec-once`.** A reload re-reads settings but does not start the
`autostart.conf` programs (bar, wallpaper daemon, notification daemon, polkit, trays) — they only
launch on a fresh start (next login), so after `ok` the user sees the new look but **no bar / no
wallpaper this session**, which reads as "broken." Either **offer to start them now**
(`hyprctl dispatch exec <cmd>` mirroring each `exec-once`; skip the wallpaper daemon if its image is
a missing placeholder), **or** tell them they appear on next login. After starting a daemon live,
**verify it stayed up** (`pgrep -x <name>`). Two common silent failures: a **notification-daemon name
conflict** (only one can own `org.freedesktop.Notifications`; stop the stray with `pkill -x dunst`
first), and a **wrong wallpaper binary** (use `SWWW_DAEMON_BIN`, not a hard-coded `swww-daemon`). Two
more env gotchas keyed off `detect-version.sh` — the nouveau/NVIDIA `no_hardware_cursors` block and
uwsm's `~/.config/uwsm/env` override — are in the Safety rules below (full detail in
`config-templates.md`).

---

## Mode B — Theme every surface from one palette

Apply one coherent palette across the whole desktop: **one normalized palette → render per-app color
files → reload each app** (see `references/theming.md`). Use only current syntax (defer to
hyprland-reference). For *how* each surface should look — where the accent goes, contrast,
transparency, the archetypes — read the styling library (`design-principles.md` + the per-app pages).

### B1. Choose the palette source & fonts (always ask)

Run interview **groups 11–14** (look & feel, palette, fonts, wallpaper) from `references/interview.md`
(palette source → scheme/wallpaper/manual, accent, light/dark; UI font; monospace/Nerd font). Four
groups is light enough to run inline, but **still record each answer** via `record-answer.sh` into
`~/.config/hypr-rice/answers.json` — that way a later A-mode build (or a profile save) can replay
exactly what was chosen. The named-scheme catalog is `references/palettes.md`; for the wallpaper
source, `scripts/palette-from-wallpaper.sh` produces the palette when matugen/wallust is present.
Resolve every answer into the **palette contract** (`theming.md`) as bare `RRGGBB`. Don't pick a
scheme or fonts silently — present them.

### B2. Choose surfaces (default: all installed)

Default to every surface whose app is installed/running: Hyprland + hyprlock, waybar, mako/dunst/swaync,
wofi/rofi, kitty/terminal, GTK (3+4), Qt, cursor/icons/fonts. Skip (and note) absent apps.

### B3. Prefer the engine (reproducible)

For a real rice, drive the **engine** rather than writing each file ad hoc — it makes the theme
reproducible, re-applyable, and version-controllable (see `references/engine.md`):

1. `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/rice-init.sh"` (scaffold/refresh, idempotent).
2. Resolve the palette and write `~/.config/hypr-rice/palette.conf` (the source of truth).
3. Ensure each app reads its colors file (one-time wiring: `source=`/`@import`/`include`).
4. Back up first: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" <paths being changed>`.
5. `bash ~/.config/hypr-rice/rice apply` (renders every template + reloads running apps). Apply fonts
   across `gsettings` (`font-name`/`monospace-font-name`), GTK `settings.ini`, kitty `font_family`,
   waybar `font-family` per `fonts.md`. For the cursor, also `hyprctl setcursor <Cursor> <size>`.

**GTK theming has three engine-breaking gotchas** — a session `GTK_THEME=` (default under uwsm —
`~/.config/uwsm/env`) that silently defeats the re-theme until the env is fixed and live-propagated;
"folder color is the icon theme, not the GTK theme" (set a scheme-matched `icon-theme` too); and a
root-owned `gtk-4.0/gtk.css` symlink that render hits as *Permission denied* (now handled by
`render-templates.sh`). Full detail, the propagation commands, and the murrine-needs-`sassc` build
note live in **`references/theming.md` → GTK** and `styling/gtk-qt.md`.

For one-off, non-engine theming the per-app templates in `references/templates.md` and
`scripts/apply-theme.sh` (reloads running apps + cursor) remain valid.

### B4. Verify & report

Confirm the Hyprland color file still parses:
`bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/verify-config.sh"`. `VERIFY=ok` → done; `VERIFY=errors`
→ restore the Hyprland files from the backup, reload, report. Summarize source/scheme, surfaces
themed, files written, backups, reload/verify results, and any package to install for more.

---

## Mode C — Named profiles & the override cascade

A **profile** is a snapshot of `palette.conf` (palette + scheme + wallpaper + fonts) at
`~/.config/hypr-rice/profiles/<name>.conf`. Twelve presets ship: `catppuccin-mocha`,
`catppuccin-frappe`, `catppuccin-macchiato`, `catppuccin-latte` (light), `gruvbox`, `nord`,
`tokyo-night`, `rose-pine`, `dracula`, `everforest`, `kanagawa`, `solarized-dark`.

1. Ensure the engine exists: `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/rice-init.sh"` (also
   installs the presets without clobbering customized ones).
2. Act via the `rice` CLI:
   - **List:** `bash ~/.config/hypr-rice/rice themes`
   - **Switch/apply:** `bash ~/.config/hypr-rice/rice theme <name>` (loads that palette + its recorded
     wallpaper, renders every template, reloads apps).
   - **Save current:** `bash ~/.config/hypr-rice/rice save <name>`.
   - **Re-apply current:** `bash ~/.config/hypr-rice/rice apply`.
   Back up `palette.conf` before a switch if the current state isn't saved
   (`bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" ~/.config/hypr-rice/palette.conf`).
3. **User-override layer** (pins that survive every theme/wallpaper change): write `KEY=hex` lines into
   `~/.config/hypr-rice/palette.user.conf` — the render overlays it *after* the profile/generated
   palette (`generated/profile → user`), then `rice apply`. Switching a profile does **not** clear it
   (overrides are intentionally persistent; remove a line + `rice apply` to drop one).
4. Verify (`verify-config.sh`) and report: profile applied, wallpaper, apps reloaded, active overrides.

Profiles version-control well — committing `~/.config/hypr-rice/` (see the **dotfiles** skill)
captures every saved rice and the current state.

---

## Mode D — Wallpaper (+ dynamic theming)

Set the wallpaper and optionally re-theme the whole desktop from it — the canonical rice front door
("change wallpaper, the desktop follows"). Read `references/wallpaper.md`.

1. Ensure the engine exists: `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/rice-init.sh"`.
2. Resolve the image. If the user has a file, use it (common dir `~/Pictures/wallpapers`). If they
   don't — or want one that suits their scheme — offer the **curated theme catalog**:
   `bash ~/.config/hypr-rice/rice wallpapers [scheme]` lists matching downloadable wallpapers (the
   chosen scheme's set + a few theme-agnostic `any` ones); present them with `AskUserQuestion`, then
   `bash ~/.config/hypr-rice/rice get-wallpaper <scheme> <number|name> --set` curl-downloads the pick
   to `~/Pictures/wallpapers/` and applies it (keeping the current palette — no re-theme). Then:
   - **Wallpaper only:** `bash ~/.config/hypr-rice/rice wallpaper '<image>' --no-theme`
   - **Wallpaper + dynamic theme:** `bash ~/.config/hypr-rice/rice wallpaper '<image>'` — sets it,
     regenerates `palette.conf` from it (matugen/wallust/pywal), renders every template, reloads apps.
   Back up first if overwriting: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" ~/.config/hypr/hyprpaper.conf ~/.config/hypr-rice/palette.conf`.
   If no generator is installed you can still set the wallpaper; for dynamic theming fall back to a
   named/manual palette and suggest `matugen` (recommended) or `wallust`. matugen's Material-You →
   ANSI `color0..15` mapping is approximate; wallust/pywal give a true 16-color scheme.
3. **Cycling (optional):** `rice random [dir]` (random pick + re-theme). To automate without Claude,
   set up a **systemd user timer** or a Hyprland `exec-once` loop — see `wallpaper.md`; tell the user
   the cadence and how to stop it. Set the transition look once via `SWWW_TRANSITION_TYPE`/`_FPS` env.
4. Verify (`verify-config.sh`) and report: wallpaper + backend, whether/how the palette regenerated,
   apps reloaded, backups, any package to install. The wallpaper path is recorded in `palette.conf`,
   so profiles/version-control reproduce it.

---

## Safety rules (all modes)

- Never overwrite `~/.config/hypr` (Mode A) or any app config (B/C/D) without a timestamped backup
  first. Keep the `BACKUP=` paths for rollback.
- Never emit deprecated syntax — cross-check `hyprland-reference/references/deprecations.md`. Keep
  monitor names exactly as `hyprctl monitors` reports; use placeholders + a note when unavailable.
- **Read picks from `<staging>/answers.json` with `jq` — never from memory.** The interviewer agent
  writes every answer there; downstream A3/A3b/A3c/A3d/A4 and the component-writer agents read it.
  If a template needs something that isn't in the file, that's a missing question — go back through
  the interviewer rather than guessing.
- **Never silently default an interview answer.** The user has explicitly required every
  sub-question be asked. `(default)` on an option means "list first", not "skip the question".
  `$ARGUMENTS` and `EXISTING_CONFIG` reorder option lists; they do not answer questions on the
  user's behalf. Opt-in gates (widgets, login, gaming, laptop, accessibility, plugins) are always
  asked — chassis / detection only decides which option is first. A full Mode A run produces
  ~28–38 `AskUserQuestion` calls; collapsing to single digits is a failure mode, not an
  optimization.
- Reload running apps rather than forcing a logout; only reload what's running.
- Install packages **only** after one explicit user confirmation per batch (delegate to the
  **hyprland-package-installer** agent — see A5). Show the resolved package list before asking. For
  out-of-band installs (a single tool an edit needs), still ask once. `install.sh` remains a
  reviewable artifact so the rice replicates to a new machine.
- After any Hyprland color/config change, run `verify-config.sh`; never leave it in `VERIFY=errors`.
- **On uwsm sessions** (`detect-version.sh` → `UWSM_SESSION=1`/`UWSM_ENV=`), `~/.config/uwsm/env` is
  the authoritative env source and **overrides hypr `env.conf`** for app launches — change
  cursor/`GTK_THEME`/toolkit env *there* too (back it up first), and live-propagate with
  `dbus-update-activation-environment --systemd VAR=value` (explicit pairs, never bare names).
- **Cursor disappears when idle on nouveau/NVIDIA** → `cursor:no_hardware_cursors = true`
  (`CURSOR_NO_HARDWARE_RECOMMENDED=1`). **GTK folder color = the icon theme**, not the GTK theme.

## Resources

- **`references/interview.md`** — the one unified question bank, one group per component (23 groups;
  re-theming reuses groups 11–14). Groups 5–10 (terminal/bar/widgets/launcher/notifications/lock) ask
  full functional depth; 18 ships utility scripts, 19 themes the login/boot chrome, 20 is the opt-in
  gaming/performance bundle, 21 (laptop) opt-in (chassis answer is just the default), 22 (accessibility) and 23 (Hyprland
  plugins / hyprpm) are opt-in.
- **`references/plugins.md`** — group-23 hyprpm community plugins: the version-pinned install flow
  (runs after one confirmation, with the "re-run after every Hyprland upgrade" warning) + catalog
  (hyprexpo overview, hyprscrolling/hy3 layouts, split-monitor-workspaces, hyprbars,
  borders-plus-plus/hyprtrails/hyprwinwrap, pyprland scratchpads) → `plugins.conf`.
- **`references/config-templates.md`** — annotated templates for every generated Hyprland file
  (Mode A): `env`/`monitors`/`input`/`looknfeel`/`binds`/`windowrules`/`autostart` + companion configs.
- **`references/components.md`** — the functional shell-config recipes (waybar `config.jsonc`+
  `style.css`, wofi/rofi/fuzzel, mako/dunst/swaync) used by Mode A3b and by `edit-config` for later
  edits.
- **`references/shells.md`** — per-shell rc locations, prompt engines, aliases/env/history, parse-test
  command. Used by Mode A3c and by `edit-config` for later shell tweaks.
- **`references/packages.md`** — the selection→package map (repo vs AUR) and the `install.sh` shape the
  skill generates in A3d. A5 runs that script via the **hyprland-package-installer** agent after one
  user confirmation; the script itself remains the reviewable, replication-friendly artifact (Arch +
  AUR; idempotent).
- **`references/theming.md`** — theming architecture, palette contract, per-surface mechanics, reloads.
- **`references/templates.md`** — per-app **color** templates the rendered colors files use.
- **`references/palettes.md`** — named schemes → contract hex (+ matching GTK/cursor/icons).
- **`references/engine.md`** — the rice engine: `palette.conf` source of truth, render manifest, the
  `rice` CLI, matugen/wallust integration, adding apps, the override cascade, reproducibility.
- **`references/fonts.md`** — font roles, the catalog to present, detection, applying UI + Nerd fonts.
- **`references/apps.md`** — shipped long-tail templates (btop/cava/starship/swaync/wlogout/fuzzel) +
  reaching matugen's 50+ app library.
- **`references/login.md`** — login/display-manager theming (greetd/tuigreet/ReGreet, SDDM) + boot.
- **`references/utilities.md`** — group-18 utilities & menus: screenshot/record/OCR/color-picker/power
  scripts (shipped in `assets/scripts/`), clipboard/emoji/calc binds, Wi-Fi/BT applet recipe.
- **`references/gaming.md`** — group-20 opt-in tweaks: tearing (`allow_tearing`+`immediate`), VRR
  modes, fullscreen effect-stripping, `misc:vfr`, the shipped `gamemode.sh` toggle.
- **`references/wallpaper.md`** — backends, dynamic theming, cycling automation.
- **`scripts/`** — `detect-version.sh`, `detect-theme-tools.sh`, `rice-init.sh`, `render-templates.sh`,
  `apply-theme.sh`, `set-wallpaper.sh`, `palette-from-wallpaper.sh`, `safe-apply.sh`,
  `install-config.sh`, `verify-config.sh`, `verify-shell.sh`, `backup-config.sh`, `reset-config.sh`.
- **`${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh`** — `jq`-based `setpath` into `answers.json`.
  Called by the interviewer agent after every `AskUserQuestion` so picks land on disk before the
  next question.
- **Agents** (under `${CLAUDE_PLUGIN_ROOT}/agents/`):
  - `hyprland-interviewer` — owns the 23-group interview, records each answer to
    `<staging>/answers.json`, runs the review pass, returns just the path + a summary. **A1 spawns
    this so the main loop's context stays clean.**
  - `hyprland-component-writer` — authors one surface (waybar / launcher / notifications / terminal /
    lock-screen / widgets / Hyprland topic) into staging. **A3 + A3b spawn several in parallel**,
    each fed a `jq` slice of `answers.json`.
  - `hyprland-package-installer` — runs the generated `install.sh` (or an ad-hoc package list) after
    A5 user confirmation. Handles pacman/paru routing, paru bootstrap, transient retries.
  - `hyprland-config-validator` — static lint of the staging dir (and optional live load-test). A5
    step 1.
- **`assets/scripts/*.sh`** — group-18 utility scripts shipped as-is (copy + `chmod`, not rendered):
  `screenshot.sh`, `screenrecord.sh`, `ocr.sh`, `colorpicker.sh`, `powermenu.sh` (see `utilities.md`),
  `gamemode.sh` (group-20 effects toggle, see `gaming.md`), `keybind-cheatsheet.sh` (group 3, reads
  `hyprctl binds -j`), `blur-toggle.sh` (group 11), `theme-switch.sh` (group 3, menu of saved rices →
  `rice theme`).
- **`templates/*.tmpl`** — the color templates the engine renders (incl. the shell/prompt set:
  `fish.tmpl` → fish `conf.d` colors, `starship.tmpl` → rice-owned `starship.toml`, `oh-my-posh.tmpl` →
  rice-owned `rice.omp.json`; and the **widget-shell set**: `eww.tmpl` → eww `colors.scss`, `ags.tmpl`
  → AGS/Astal `colors.scss`, `quickshell.tmpl` → Quickshell `Colors.qml`; registered in the manifest
  when chosen — see `engine.md` → "Shell & prompt theming" and "Widget-shell theming").
- **`assets/profiles/*.conf`** — the twelve shipped preset rices; **`assets/rice`** — the CLI
  (incl. `rice wallpapers [scheme]` to list and `rice get-wallpaper <scheme> <n|name> [--set]` to
  curl-download a matching wallpaper; `rice accents [scheme]` to list per-scheme accent variants and
  `rice accent <name|hex> [--pin]` to swap the accent; `rice theme-toggle <a> <b>` flips two profiles
  for the dark/light keybind and `rice theme-next` cycles them). **`assets/wallpapers.tsv`** — the curated,
  theme-tagged, curl-downloadable wallpaper catalog (verified raw URLs; `scheme<TAB>name<TAB>url`).
  **`assets/accents.tsv`** — per-scheme accent variants (`scheme<TAB>name<TAB>hex`, 6–8 each).
- **`examples/sample-config/`** — a complete reference output (a generated modular config set).
- **`${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh`** — timestamped backup of arbitrary paths.

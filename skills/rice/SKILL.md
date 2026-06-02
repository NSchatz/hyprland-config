---
name: rice
description: This skill should be used when the user runs "/hyprland-config:rice" or asks to build, theme, or restyle their Hyprland desktop — i.e. (1) GENERATE a config from scratch ("generate/create my hyprland.conf", "set up Hyprland from scratch", "make me a new config", "build a hyprland config"); (2) THEME/recolor/set fonts ("theme my desktop", "apply Catppuccin/Gruvbox/Nord/Tokyo Night", "change my color scheme/accent", "match my colors to my wallpaper", "set up matugen/wallust", "change my font"); (3) manage named theme PROFILES / "rices" ("save my theme as X", "switch to nord", "list my themes", "load my <name> rice", "pin my accent"); or (4) set/change/cycle the WALLPAPER ("set my wallpaper", "random wallpaper", "make my theme match my wallpaper"). It runs one interactive interview, generates a modular version-matched config, and drives a self-contained rice engine (~/.config/hypr-rice/ — one palette.conf + templates + a `rice` CLI + profiles + a user-override cascade) that themes Hyprland, hyprlock, waybar, notifications, launcher, terminal, GTK/Qt/cursor/icons/fonts and the wallpaper consistently — backing up, live-testing, and reloading after every change.
argument-hint: "[what you want, e.g. 'set up from scratch', 'catppuccin mocha', 'switch to nord', 'wallpaper ~/x.png and theme from it']"
allowed-tools: AskUserQuestion, Bash, Read, Write, Edit, Glob, Grep, Agent
version: 0.3.0
---

# Rice — Build & Theme the Hyprland Desktop

One skill for the whole rice: **generate** a Hyprland config from scratch, **theme** every surface
from one palette, manage named **profiles**, and set the **wallpaper** (with dynamic theming). They
are one skill because they share one source of truth — the **rice engine** at `~/.config/hypr-rice/`
(`palette.conf` → templates → every app's colors, driven by the `rice` CLI). Read
`references/engine.md` for the engine contract before touching it.

Treat `$ARGUMENTS` as the request (a scheme name, an image path, "set up from scratch", "switch to
nord", freeform setup hints). Use it to pick the mode and pre-fill or skip interview questions.

This skill leans on the **hyprland-reference** skill for syntax and look-and-feel. Read its files
under `skills/hyprland-reference/references/` when generating or theming, and **cross-check every
emitted option against `deprecations.md`** so deprecated syntax never ships. For tasteful defaults
(so a generated config looks designed, not stock-gray) consult the styling library
`skills/hyprland-reference/references/styling/` — `design-principles.md` (coherence, accent
discipline, the archetypes) and the per-app pages (`hyprland-decoration.md`, `waybar.md`,
`terminals.md`, `notifications.md`, `launchers.md`, `hyprlock.md`, `gtk-qt.md`, `tui-and-prompt.md`),
all written around this skill's palette contract. For companion apps read `ecosystem.md`.

## Routing — pick the mode from the request

| The user wants… | Mode | What it does |
|---|---|---|
| a config built from scratch / "set up Hyprland" / "generate hyprland.conf" | **A — Generate** | full interview → modular config → install + live-test |
| to theme / recolor / change scheme / set fonts / match wallpaper colors | **B — Theme** | one palette across every surface |
| to save / list / switch a named rice, or pin a color | **C — Profiles** | the `rice` CLI + override cascade |
| to set / change / cycle the wallpaper | **D — Wallpaper** | set wallpaper (+ optional dynamic theme) |

They compose on the **same engine**: Mode A finishes by establishing the palette through the engine
(Mode B's machinery), so a fresh config comes out coherently themed; B, C, and D all rewrite
`palette.conf` and `rice apply`. When a request spans modes ("set up from scratch with Tokyo Night
and this wallpaper"), run A and fold the B/D answers into its interview.

Always start by detecting tooling so options reflect what's installed:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/detect-version.sh"      # Hyprland version + ecosystem packages
bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/detect-theme-tools.sh"  # generators/fonts/terminals/bars + current gsettings
```

`detect-version.sh` prints `HYPR_VERSION=` (decides version-sensitive syntax — see `deprecations.md`),
`HAVE_<tool>=1`/`MISSING_<tool>=1` for ecosystem packages, `GPU_DRIVER=`/`NVIDIA_PROPRIETARY=` (gates
the NVIDIA env block), and `SWWW_DAEMON_BIN=` (`swww-daemon` vs the `awww` fork's `awww-daemon`).
`detect-theme-tools.sh` prints `HAVE_*`/`MISSING_*` for matugen/wallust/pywal + fonts, and `CURRENT_*`
gsettings. Bias defaults toward installed tools; suggest (never install) anything missing.

---

## Mode A — Generate a config from scratch

Generate a complete, validated, **modular** config (a main `hyprland.conf` that `source=`s topic
files), back up any existing config, install it, and live-test with auto-rollback. Do not write to
`~/.config/hypr` until the config is generated and the user has seen the plan.

### A1. Run the unified interview

Gather preferences with `AskUserQuestion` using the bank in **`references/interview.md`** — one call
per area, several questions per call, sensible default first, skip anything answered by `$ARGUMENTS`
or an existing config. The areas: **A** monitors & input · **B** keybinds & apps · **C** look & feel
· **D** palette & fonts (this is what makes the result *coherent*, not a gray box — don't pick a
scheme or fonts silently) · **E** autostart & env · **F** companion configs. The same interview
serves re-theming (Mode B uses only areas C/D) so the two never drift.

### A2. Read any existing config (context only)

If `~/.config/hypr/hyprland.conf` exists, read it to learn monitor names, layout, and apps so
questions pre-fill. Don't edit in place — it's backed up wholesale at install.

### A3. Generate into a staging dir

Build the file set in `/tmp/hypr-gen-<stable-id>` (not `~/.config/hypr`) using
**`references/config-templates.md`** as the structure. Produce `hyprland.conf` (variables +
`source=` lines), `env.conf`, `colors.conf` (filled in A4 — not by hand), `monitors.conf`,
`input.conf`, `looknfeel.conf`, `binds.conf`, `windowrules.conf`, `autostart.conf`, plus the
**companion configs** (`hyprlock.conf`/`hypridle.conf`/`hyprpaper.conf`) for any tool the user chose
(these are read by their own daemons — NOT `source=`d — but stage them so they install + back up
together). Match syntax to the detected version; wire ecosystem keybinds per `config-templates.md`.
`hyprland.conf` must `source = ~/.config/hypr/colors.conf` early, and `looknfeel.conf`'s
`col.active_border` defaults to `$accent $accent2 45deg` — those vars come from the engine in A4, so
the look stays in sync with a later re-theme.

### A4. Establish the palette via the rice engine

The colors/fonts from interview area D are owned by the **engine** (`~/.config/hypr-rice/`). Wiring
it here is what makes the config come out themed and keeps a later re-theme consistent. Read
`references/engine.md`. Then:

1. Scaffold (idempotent — never clobbers an existing palette):
   `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/rice-init.sh"`
2. Write `~/.config/hypr-rice/palette.conf` from the area-D answers — resolve a named scheme
   (`references/palettes.md`), a wallpaper palette (`scripts/palette-from-wallpaper.sh`), or manual
   hex into the contract keys + `scheme`/`wallpaper`/`font_ui`/`font_mono`. **Always populate
   `accent2`** (default it to `accent` on the manual path) — the border template references it.
3. Fill `<staging>/colors.conf` so it installs with the rest (don't let the engine write to
   `~/.config/hypr` before A5): take `templates/hyprland.tmpl`, substitute its `{{accent}}` etc.
   from `palette.conf`, and `Write` the result. Likewise fill any companion-config color placeholders.
4. **Only after a successful install** (A5 returns `ok`/`installed-untested`), run
   `bash ~/.config/hypr-rice/rice apply` so any already-present apps pick up the palette. **Skip it on
   `rolled-back`/`install-failed`** — it would re-render outside the safe-apply harness.

### A5. Validate, back up, install, live-test, auto-rollback

1. **Static validation:** invoke the **hyprland-config-validator** agent (Agent tool) on the staging
   dir with the detected version; fix any ERRORs and regenerate before installing.
2. **Safe install:** `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/safe-apply.sh" /tmp/hypr-gen-<id>`
   — it timestamp-backs up the **entire** `~/.config/hypr`, installs, then `hyprctl reload` +
   `configerrors`, and **auto-rolls-back** if the new config fails. Read the final `SAFE_APPLY=` line:
   `ok` (installed + clean), `rolled-back` (errors shown; restored — fix + retry),
   `installed-untested` (no running Hyprland; test next login), `install-failed`/`errors-no-backup`
   (surface + stop). Relay the `BACKUP=` path. Respect a `HYPR_DIR` override. (`install-config.sh` /
   `verify-config.sh` exist for running a step alone — see `hyprland-reference/references/testing.md`.)

### A6. Report (and start the daemons)

Summarize version, files, backup, validator verdict, `SAFE_APPLY`/`VERIFY` result, the chosen
palette/fonts (now in `palette.conf` as the source of truth), and how to restore the backup
(`rm -rf ~/.config/hypr && cp -a ~/.config/hypr.bak.<ts> ~/.config/hypr && hyprctl reload`).

**`hyprctl reload` does NOT run `exec-once`.** A reload re-reads settings but does not start the
`autostart.conf` programs (bar, wallpaper daemon, notification daemon, polkit, trays) — they only
launch on a fresh start (next login), so after `ok` the user sees the new look but **no bar / no
wallpaper this session**, which reads as "broken." Either **offer to start them now**
(`hyprctl dispatch exec <cmd>` mirroring each `exec-once`; skip the wallpaper daemon if its image is
a missing placeholder), **or** tell them they appear on next login. After starting a daemon live,
**verify it stayed up** (`pgrep -x <name>`). Two common silent failures: a **notification-daemon name
conflict** (only one can own `org.freedesktop.Notifications`; stop the stray with `pkill -x dunst`
first), and a **wrong wallpaper binary** (use `SWWW_DAEMON_BIN`, not a hard-coded `swww-daemon`).

---

## Mode B — Theme every surface from one palette

Apply one coherent palette across the whole desktop: **one normalized palette → render per-app color
files → reload each app** (see `references/theming.md`). Use only current syntax (defer to
hyprland-reference). For *how* each surface should look — where the accent goes, contrast,
transparency, the archetypes — read the styling library (`design-principles.md` + the per-app pages).

### B1. Choose the palette source & fonts (always ask)

Run interview **areas C/D** from `references/interview.md` (palette source → scheme/wallpaper/manual,
accent, light/dark; UI font; monospace/Nerd font). The named-scheme catalog is `references/palettes.md`;
for the wallpaper source, `scripts/palette-from-wallpaper.sh` produces the palette when matugen/wallust
is present. Resolve every answer into the **palette contract** (`theming.md`) as bare `RRGGBB`. Don't
pick a scheme or fonts silently — present them.

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
- Reload running apps rather than forcing a logout; only reload what's running.
- Don't install packages — suggest them.
- After any Hyprland color/config change, run `verify-config.sh`; never leave it in `VERIFY=errors`.

## Resources

- **`references/interview.md`** — the one unified question bank (areas A–F; re-theming reuses C/D).
- **`references/config-templates.md`** — annotated templates for every generated Hyprland file
  (Mode A): `env`/`monitors`/`input`/`looknfeel`/`binds`/`windowrules`/`autostart` + companion configs.
- **`references/theming.md`** — theming architecture, palette contract, per-surface mechanics, reloads.
- **`references/templates.md`** — per-app **color** templates the rendered colors files use.
- **`references/palettes.md`** — named schemes → contract hex (+ matching GTK/cursor/icons).
- **`references/engine.md`** — the rice engine: `palette.conf` source of truth, render manifest, the
  `rice` CLI, matugen/wallust integration, adding apps, the override cascade, reproducibility.
- **`references/fonts.md`** — font roles, the catalog to present, detection, applying UI + Nerd fonts.
- **`references/apps.md`** — shipped long-tail templates (btop/cava/starship/swaync/wlogout/fuzzel) +
  reaching matugen's 50+ app library.
- **`references/login.md`** — login/display-manager theming (greetd/tuigreet/ReGreet, SDDM) + boot.
- **`references/wallpaper.md`** — backends, dynamic theming, cycling automation.
- **`scripts/`** — `detect-version.sh`, `detect-theme-tools.sh`, `rice-init.sh`, `render-templates.sh`,
  `apply-theme.sh`, `set-wallpaper.sh`, `palette-from-wallpaper.sh`, `safe-apply.sh`,
  `install-config.sh`, `verify-config.sh`, `backup-config.sh`, `reset-config.sh`.
- **`templates/*.tmpl`** — the color templates the engine renders.
- **`assets/profiles/*.conf`** — the five shipped preset rices; **`assets/rice`** — the CLI
  (incl. `rice wallpapers [scheme]` to list and `rice get-wallpaper <scheme> <n|name> [--set]` to
  curl-download a matching wallpaper; `rice accents [scheme]` to list per-scheme accent variants and
  `rice accent <name|hex> [--pin]` to swap the accent). **`assets/wallpapers.tsv`** — the curated,
  theme-tagged, curl-downloadable wallpaper catalog (verified raw URLs; `scheme<TAB>name<TAB>url`).
  **`assets/accents.tsv`** — per-scheme accent variants (`scheme<TAB>name<TAB>hex`, 6–8 each).
- **`examples/sample-config/`** — a complete reference output (a generated modular config set).
- **`${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh`** — timestamped backup of arbitrary paths.

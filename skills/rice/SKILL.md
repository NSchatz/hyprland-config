---
name: rice
description: This skill should be used when the user runs "/hyprland-config:rice" or asks to build, theme, or restyle their Hyprland desktop — i.e. (1) GENERATE a config from scratch ("generate/create my hyprland.conf", "set up Hyprland from scratch", "make me a new config", "build a hyprland config"); (2) THEME/recolor/set fonts ("theme my desktop", "apply Catppuccin/Gruvbox/Nord/Tokyo Night/Dracula/Everforest/Kanagawa/Solarized/Rosé Pine", "change my color scheme/accent", "match my colors to my wallpaper", "set up matugen/wallust", "change my font"); (3) manage named theme PROFILES / "rices" ("save my theme as X", "switch to nord", "list my themes", "load my <name> rice", "pin my accent"); or (4) set/change/cycle the WALLPAPER ("set my wallpaper", "random wallpaper", "make my theme match my wallpaper"). It runs one interactive interview, generates a modular version-matched config, and drives a self-contained rice engine (~/.config/hypr-rice/ — one palette.conf + templates + a `rice` CLI + profiles + a user-override cascade) that themes Hyprland, hyprlock, waybar, notifications, launcher, terminal, GTK/Qt/cursor/icons/fonts and the wallpaper consistently — backing up, live-testing, and reloading after every change.
argument-hint: "[what you want, e.g. 'set up from scratch', 'catppuccin mocha', 'switch to nord', 'wallpaper ~/x.png and theme from it']"
allowed-tools: AskUserQuestion, Bash, Read, Write, Edit, Glob, Grep, Agent
version: 0.22.0
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
`references/theming/engine.md` for the engine contract before touching it. The functional shell-config
recipes live one folder per surface under `references/components/` (`waybar/`, `launcher/`,
`notifications/`, `terminal/`, `lock-screen/`, `widgets/`, `shell-prompt/`, …) — used by rice for both
generation and for `edit-config`'s later edits, one source per surface. **Multi-tool surfaces are
sharded by tool**: read that component's `common.md` plus the one `tools/<tool>.md` the answer names.

Treat `$ARGUMENTS` as the request (a scheme name, an image path, "set up from scratch", "switch to
nord", freeform setup hints). Use it to pick the **mode** (A/B/C/D). Use it to **reorder option
lists** in the interview so a hinted pick is the first option (so the user can confirm with one
press). **Do not use it to skip interview questions** — the user has explicitly required every
sub-question be asked (see Safety rules below + the interviewer agent's prompt).

This skill leans on the **hyprland-reference** skill for syntax and look-and-feel. Read its files
under `skills/hyprland-reference/references/` when generating or theming, and **cross-check every
emitted option against `deprecations.md`** so deprecated syntax never ships. For tasteful defaults
(so a generated config looks designed, not stock-gray) read
`skills/hyprland-reference/references/styling/design-principles.md` for the cross-cutting layer
(coherence, accent discipline, the archetypes). **Per-surface styling lives with its surface**, in
that component's own folder — `components/<x>/styling.md`, or the `Styling` section of
`components/<x>/tools/<tool>.md` on a sharded component — all written around this skill's palette
contract. For companion apps read `ecosystem.md`.

## Contents

- Routing — pick the mode from the request
- The four modes live in their own files
- Safety rules (all modes)
- Resources

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
bash "${CLAUDE_PLUGIN_ROOT}/scripts/ensure-python.sh"                   # FIRST - see below
bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/detect-version.sh"      # Hyprland version + env facts
bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/config-language.sh"     # which config LANGUAGE this Hyprland reads
bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/detect-theme-tools.sh"  # current gsettings + font families
```

**`ensure-python.sh` runs first, before the interview, and its result gates everything.** Every
answer is recorded to `answers.json` through a Python helper, so a machine without `python3`
cannot start an interview — and **python is not guaranteed on Arch**: it is absent from the
`base` meta-package's 28 dependencies, and `pacman` needs it only as a *check* dependency that
is never installed on a user's machine. Read the last line:

| Line | What it means |
|---|---|
| `PYTHON=present <path>` | already installed, nothing was done - carry on |
| `PYTHON=installed <path>` | installed just now and written to the install record - carry on |
| `PYTHON=declined` | the user said no. **Stop.** Do not start an interview whose answers cannot be saved; say what is needed and why |
| `PYTHON=missing` | not installable here (no pacman). **Stop** and tell them to install python 3 themselves |
| `PYTHON=failed` | the install was attempted and did not work. **Stop** and surface the output |

**The config language is a detection fact, not a default.** Since 0.55 Hyprland reads
`hyprland.lua` and loads it *instead of* `hyprland.conf`, and since 0.56.0 a fresh install
autogenerates one. `config-language.sh` reports `CONFIG_LANGUAGE=`, `CONFIG_FILE=` and
`CONFIG_LANGUAGE_RANGE=`; on an undetectable version it exits non-zero, prints
`EMITTABLE_LANGUAGES=lua hyprlang` with each option's range, and **requires an explicit
`HYPR_CONFIG_LANG=lua|hyprlang`**. Relay that question to the user - do not pick for them. A wrong
guess is not an error, it is a config the compositor never reads.

Use these factual fields: `HYPR_VERSION=` (version-sensitive syntax — see `deprecations.md`),
`GPU_DRIVER=`/`NVIDIA_PROPRIETARY=` (gates the NVIDIA env block under the proprietary driver only),
`SWWW_DAEMON_BIN=` (`swww-daemon` vs the `awww` fork's `awww-daemon`), `UWSM_SESSION=`/`UWSM_ENV=`
(uwsm session env source), `CURSOR_NO_HARDWARE_RECOMMENDED=` (nvidia/nouveau cursor blanking),
`IS_LAPTOP=` (use as the *default* for the laptop question — never to skip it), `MONITOR_COUNT=`,
`CURRENT_*` gsettings, font families. The scripts also emit `HAVE_<tool>=1` / `MISSING_<tool>=1` —
**ignore those for filtering options**; the only legitimate use is annotating the install batch at A5
(`# installed` comments and the idempotent `--needed` flag handle that automatically).

---

## The four modes live in their own files

Read **only** the mode the request selects. Mode A is split at the line this whole plugin is
built around: `generate.md` builds into a staging dir and touches nothing the user owns;
`apply.md` is everything that writes to their machine, and every step of it is reversible
before it runs.

| Mode | Read | What it covers |
|---|---|---|
| **A - Generate** (part 1) | [`references/modes/generate.md`](references/modes/generate.md) | A1 interview -> A2 context -> A3 staging -> A3b parallel writers -> A3c shell & prompt -> A3d `install.sh` |
| **A - Generate** (part 2) | [`references/modes/apply.md`](references/modes/apply.md) | A4 palette via the engine -> A5 validate, install packages, back up, live-test, auto-rollback -> A6 report |
| **B / C / D** | [`references/modes/theme.md`](references/modes/theme.md) | theme every surface from one palette; named profiles + the override cascade; wallpaper and dynamic theming |

A request that spans modes ("set up from scratch with Tokyo Night and this wallpaper") runs A and
folds the B/D answers into its interview - read `generate.md` and `apply.md`, not `theme.md`.

The full map of the reference tree is [`references/index.md`](references/index.md). Do not read it
to perform a task; read it to find which file performs the task.


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

The reference tree is per-component - one folder per interview component, plus the shared
contracts and the theming engine docs. **The full index, with what each file holds, is
[`references/index.md`](references/index.md).**

The four files worth knowing by name before you go looking:

- [`references/_interview-protocol.md`](references/_interview-protocol.md) - interview order, the no-defaulting rule, how answers are recorded.
- [`references/_shared/palette-schema.md`](references/_shared/palette-schema.md) - the `palette.conf` key contract every surface renders from.
- [`references/theming/engine.md`](references/theming/engine.md) - the rice engine: palette source of truth, render manifest, the `rice` CLI.
- [`references/_shared/version-matrix.md`](references/_shared/version-matrix.md) - Hyprland version branches and syntax gates.

Each component folder owns its own `interview.md`, `schema.md`, `packages.md` and recipe.
**Multi-tool components are sharded by tool**: read that component's `common.md` plus the one
`tools/<tool>.md` the answer names, never its siblings. The component `README.md` is the
routing table.

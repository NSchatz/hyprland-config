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
recipes live under `references/components/<x>/template.md` (one folder per surface — `waybar/`,
`launcher/`, `notifications/`, `terminal/`, `lock-screen/`, `widgets/`, `shell-prompt/`, …) — used by
rice for both generation and for `edit-config`'s later edits, one source per surface.

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
bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/config-language.sh"     # which config LANGUAGE this Hyprland reads
bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/detect-theme-tools.sh"  # current gsettings + font families
```

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

## Mode A — Generate a config from scratch

Generate a complete, validated, **modular** config (a main `hyprland.conf` that `source=`s topic
files), back up any existing config, install it, and live-test with auto-rollback. Do not write to
`~/.config/hypr` until the config is generated and the user has seen the plan.

### A1. Run the interview — pick the path deterministically up front

The interview is 28–38 `AskUserQuestion` calls across 23 groups. Some Claude Code harnesses
**disable `AskUserQuestion` inside subagents**; on those, the interviewer agent immediately
returns `INTERVIEW=blocked`. So **probe availability once, up front, and pick the path
deterministically.** Both paths are first-class — neither is a fallback (defect #2: the inline
path is the *expected* path in this environment, not an error).

Set up a staging dir first (both paths use it):

```bash
staging="/tmp/hypr-gen-$(date +%s)-$$"
mkdir -p "$staging"
```

Then probe `AskUserQuestion` availability with one trivial throwaway call (e.g. "Ready to start
the interview?" Yes / Cancel). If it returns normally, both **agent** and **inline** paths are
open — prefer the agent (the context-isolation matters at 28-38 calls). If the probe errors as
"not available inside subagents", the inline path is the only path **and that is fine** — do not
spawn the interviewer just to have it bounce back.

#### A1a — Agent path (when `AskUserQuestion` works in subagents)

Call the Agent tool with `subagent_type: hyprland-interviewer` passing:
- `STAGING=<staging>`
- `HYPR_VERSION=<from detect-version.sh>`
- `ARGUMENTS=<the user's $ARGUMENTS>`
- `EXISTING_CONFIG=~/.config/hypr/hyprland.conf` (if present)
- `DETECT_VERSION=<the detect-version.sh kv dump>` / `DETECT_THEME=<detect-theme-tools.sh kv dump>`

The agent walks the question bank in `references/_interview-protocol.md` (protocol + the
components-walked table) plus each `references/components/<x>/interview.md`, **asks every
sub-question** (see the agent's "STRICT — ASK EVERY QUESTION" rules: `(default)` only reorders
the option list, it doesn't authorize skipping; `ARGUMENTS` / `EXISTING_CONFIG` reorder, they
don't answer), records every answer to `<staging>/answers.json` as it goes (via
`scripts/record-answer.sh`), runs a "review your picks" pass at the end, and returns just the
file path + a short summary. The 23 groups stay in the agent's context; your main loop only
sees the summary line.

**Verify the call count before accepting the agent's report.** If the agent returns
`components_recorded` ≪ 22 or a summary suggesting fewer than ~28 `AskUserQuestion` calls were
made, the interview was collapsed — re-spawn the agent (or run inline yourself).

#### A1b — Inline path (when `AskUserQuestion` is blocked in subagents)

This is co-equal to the agent path — not a fallback. The probe told you up front that the
agent can't ask questions; running it just to have it return `INTERVIEW=blocked` is wasted
work. Instead, **run the interview yourself in the main rice loop**:

1. Seed `<staging>/answers.json` with `version` / `staging_dir` / `hypr_version`:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh" "$staging/answers.json" version --json 1
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh" "$staging/answers.json" staging_dir "$staging"
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh" "$staging/answers.json" hypr_version "$HYPR_VERSION"
   ```
2. Read `references/_interview-protocol.md` for the order + the asking discipline. Read each
   `references/components/<x>/interview.md` in walked-order for that component's sub-questions.
3. Ask every sub-question with `AskUserQuestion`; immediately record each answer with
   `record-answer.sh`. The same strict no-defaulting rule applies — `(default)` reorders the
   option list, `$ARGUMENTS` / `EXISTING_CONFIG` reorder the first option, neither answers the
   question.
4. Run the review pass with one final `AskUserQuestion` summarizing palette/fonts/bar/launcher/
   terminal/notif/shell/monitors/opt-ins.

The context-isolation benefit is lost (28-38 Q/A rounds live in the main loop), but a real
interview beats a fabricated one — **never invent answers the user didn't see.**

For **re-theming (Mode B)** you don't need the full interviewer — Mode B only walks the `look-feel`
component (palette · fonts · wallpaper sub-questions) inline; running the heavy agent for one
component is overkill. Same `answers.json` schema applies though, so a Mode B run can also persist
its picks into the rice engine for later replay. The same no-defaulting rule applies: each of the
component's sub-questions still gets an `AskUserQuestion`.

### A2. Pre-load context for the interviewer

Run `detect-version.sh` + `detect-theme-tools.sh` and capture their output as the `DETECT_*` blobs
above. If `~/.config/hypr/hyprland.conf` exists, pass the path as `EXISTING_CONFIG` (the agent
reads it for monitor names + obvious current picks; the file is backed up wholesale at install,
not edited in place).

### A3. Generate into the staging dir (reading answers.json, not memory)

Build the file set in the same `<staging>` the interviewer wrote `answers.json` into (not
`~/.config/hypr`) using each **`references/components/<x>/template.md`** as the structure (one per
Hyprland topic file — `monitors`, `input`, `keybinds`, `env`, `look-feel`, `window-rules`,
`autostart`, `companion-daemons`, `plugins`). **Read every pick from `<staging>/answers.json` with
`jq`** — never from memory or chat history. The component schemas (each `components/<x>/schema.md`)
are the canonical map between answers and files (see `_interview-protocol.md` → "Recording
answers" → "How downstream steps use it"). If a template needs a value that isn't in the file,
that's a missing question — go back through the interviewer rather than inventing.

The actual file authoring is **delegated to `hyprland-component-writer` agents in parallel** (see
A3b for the spawn pattern — the same agent handles Hyprland topic files via
`SURFACE=hyprland-topic`). Each writer gets a slice of `answers.json` as its `ANSWERS`
parameter, sliced via `scripts/answers.py` (the Python helper — `jq` is not yet installed
at generation time):

```bash
ANSWERS="$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/answers.py" slice "$staging/answers.json" monitors input)"
```

**Cross-surface slices the writer needs to *integrate* go in too.** Several writers reference
selections the user made in a *different* component — and historically didn't see them
(defects #11/#12/#14/#17). The cross-surface slices for each writer:

- `window-rules` writer → `widgets utilities notifications` (so blur namespaces for
  `widgets.system` and `utilities.osd_route` land — see `_shared/namespaces.md`)
- `keybinds` writer → `widgets utilities gaming lock_screen` (so the expected toggle/launch
  binds for those surfaces land — see `_shared/expected-binds.md`)
- `waybar` writer → `utilities notifications` (so `custom/power` and `custom/notification`
  modules land — see `_shared/expected-binds.md` "Waybar modules")
- `autostart` writer → `widgets utilities notifications` (so the shell autostart, swayosd
  daemon, and notification daemon lines land in one consistent order)

> **No jq at generation time.** Everything between A0 and the package install batch (A5
> step 3) runs on a clean Arch box where `jq` is not yet on disk — `jq` is itself one of
> the packages the rice installs. Generation-time tooling reads `answers.json` through
> `scripts/answers.py` (`get` / `slice` / `list` / `has`) and writes through
> `scripts/record-answer.py`; both depend only on the Python stdlib (Arch's `pacman` pulls
> in `python3` as a base dep). Runtime helpers (`keybind-cheatsheet.sh`, eww data scripts,
> rice CLI) keep using `jq` because they execute after the install.

The main loop is responsible for:
- The index file `hyprland.conf` (variables + `source=` lines — small, benefits from the
  surrounding context),
- `colors.conf` (filled in A4 — not by hand),
- Aggregating the per-topic writer reports.

The writer agents produce the rest in parallel: `env.conf`, `monitors.conf`, `input.conf`,
`looknfeel.conf`, `binds.conf`, `windowrules.conf`, `autostart.conf`, plus the **companion configs**
(`hyprlock.conf`/`hypridle.conf`/`hyprpaper.conf`) for any tool the user chose (these are read by
their own daemons — NOT `source=`d — but stage them so they install + back up together). Match
syntax to the detected version; wire ecosystem keybinds per `components/keybinds/template.md`.
`hyprland.conf` must `source = ~/.config/hypr/colors.conf` early, and `looknfeel.conf`'s
`col.active_border` defaults to `$accent $accent2 45deg` — those vars come from the engine in A4,
so the look stays in sync with a later re-theme.

**v0.14 cross-surface coherence rules the writer agent enforces** (see
`agents/hyprland-component-writer.md` → "Cross-surface coherence" for the full list with
upstream citations): pill `border-radius` references `{{rounding}}`; active/highlight colors
reuse `{{accent}}`/`{{accent2}}`; `env` emits `envd =` (not `env =`) for `XDG_CURRENT_DESKTOP`
so D-Bus-activated apps inherit it; `window-rules` emits a per-tool layerrule map that picks
the correct upstream namespace per chosen tool (fuzzel→`launcher`, swaync→two blocks for
`swaync-control-center` + `swaync-notification-window`, walker gated on the
`HYPR_HAS_EXT_BG_EFFECT_V1` capability flag from `detect-version.sh`). The validator agent
flags the legacy/incorrect forms in A5 step 1.

### A3b. Generate the functional shell configs — in parallel via writer agents

rice is all-in-one, so also stage the **functional** configs for the shell components chosen during
the interview (terminal, waybar, widgets, launcher, notifications, lock-screen), using each
**`references/components/<x>/template.md`** as the recipe source. These live under their own
`~/.config/<app>/` dirs (not in `~/.config/hypr/`), so stage them in a parallel tree, e.g.
`<staging>/_shell/<app>/`.

**Spawn one `hyprland-component-writer` agent per surface**, in parallel (one message with several
Agent tool calls), passing each:
- `SURFACE=<waybar|launcher|notifications|terminal|lock-screen|widgets>`
- `ANSWERS=<answers.py slice of answers.json>` — e.g. for waybar:
  `ANSWERS="$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/answers.py" slice "$staging/answers.json" bar palette fonts)"`
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
- **Desktop widgets** (`widgets`): only if a widget system was chosen. For **eww** stage
  `eww/eww.yuck` + `eww/eww.scss` (`@import "colors";` → the engine's `eww.tmpl`); for an **AGS/Astal**
  or **Quickshell** shell, scaffold per its tooling and wire its colors file
  (`ags.tmpl`/`quickshell.tmpl`) — recipes in `components/widgets/template.md` and
  `components/widgets/styling.md`, wiring in `theming/engine.md` → "Widget-shell theming". A **full
  shell replaces waybar** (drop the waybar `exec-once`) and may **own notifications** (then skip the
  notifications component). **HyprPanel / Material-You** shells: drive via matugen, don't hand-theme.
  Heavy shells (Quickshell/AGS) take real time to compile — warn the user about that at install time
  (A5) so they know the batch will be slow.
- **Launcher** (`launcher`): `wofi/config` + `wofi/style.css` (`@import "colors.css";`), or
  `rofi/config.rasi` (+ a theme that `@import`s `colors.rasi`), or fuzzel/tofi `.ini` — per the chosen
  tool/mode/layout, recipe in `components/launcher/template.md`.
- **Notifications** (`notifications`): `mako/config` / `dunst/dunstrc` / `swaync/config.json`+
  `style.css` — per the chosen daemon/position/timeout/behavior (recipe in
  `components/notifications/template.md`). Leave color keys to the engine (don't hardcode hex). Skip
  if a full widget shell owns notifications — only one daemon can hold the D-Bus name.
- **Terminal** (`terminal`): the emulator's config (e.g. `kitty/kitty.conf`, `alacritty/alacritty.toml`,
  `foot/foot.ini`) with opacity/padding/cursor/font-size from the interview (recipe in
  `components/terminal/template.md`), including its colors file the engine themes
  (`include`/`source`).

Keep module on-clicks aligned to installed tools (network → `nm-connection-editor`, audio →
`pavucontrol`). Don't hardcode theme colors anywhere — every shell config reads the engine's colors
file. These get backed up + installed alongside the Hyprland config in A5.

### A3c. Set up the shell & prompt (shell-prompt component)

Read the shell pick from `answers.json` (`python3 scripts/answers.py get answers.json
shell_prompt.shell` → `fish`/`zsh`/`bash`/`keep-current`; same for `.shell_prompt.prompt`,
`.shell_prompt.fetch`, `.shell_prompt.fish_colors`, `.shell_prompt.fisher`,
`.shell_prompt.modern_cli`). Then configure
the interactive shell, leaning on **`references/components/shell-prompt/template.md`** (managed
block, guarded inits, parse-test) and **`components/shell-prompt/gotchas.md`** for *behavior* and
the rice engine (A4) for *colors*:

- **Prompt engine** (starship default / oh-my-posh): register its manifest line so the engine
  renders a rice-owned config (`~/.config/hypr-rice/starship.toml` / `rice.omp.json`), and add the
  guarded init to the shell's managed block — starship with `export STARSHIP_CONFIG=…` first,
  oh-my-posh with `oh-my-posh init <shell> --config …`. See `theming/engine.md` → "Shell & prompt
  theming" for the exact lines.
- **fish colors** (if fish): register the `fish` manifest line → `conf.d/zz-hypr-rice-colors.fish`
  (auto-sourced; themes fish's syntax highlighting from the palette).
- **Startup fetch & aliases**: add the chosen fetch (fastfetch default) + guarded modern-CLI
  aliases to the managed block per `components/shell-prompt/template.md`.

Editing rc files mid-generation is delicate (parse-test after each change, never source). If the
shell work is substantial, it's fine to finish the Hyprland install (A5/A6) first, then do the
shell pass — but the prompt/fish *colors* must go through the engine so they re-theme. Back up rc
files before editing (`backup-path.sh`).

### A3d. Generate the package install script (for review + replication)

The interview selects many tools (terminal, bar, launcher, notification daemon, fonts, palette
generator, utilities, shell/prompt, widget shell, plugins). Stage a reviewable **`install.sh`** so
the user can see exactly what will be installed and so the script ships with the dotfiles to a new
machine (idempotent on re-run). **Each component owns its own install slice** at
**`references/components/<x>/packages.md`** — walk every component the user picked something from
and concatenate. The installer agent (A5) assembles `install.sh` from these slices.

**Walk `answers.json` deterministically — don't recall picks.** Iterate the answer keys, look up
each pick's package name(s) in the relevant `components/<x>/packages.md` slice, collect into **one
`PKGS` list** (Arch + AUR target — repo and AUR names mixed), de-dupe shared deps, and annotate
already-present packages (`HAVE_*` from detection) with `# installed`. A reference shape:

```bash
A="${CLAUDE_PLUGIN_ROOT}/scripts/answers.py"
pkgs=()
[ "$(python3 "$A" get answers.json bar.strategy)" = "waybar" ]   && pkgs+=(waybar)
case "$(python3 "$A" get answers.json launcher.tool)" in
  wofi)    pkgs+=(wofi) ;;
  rofi)    pkgs+=(rofi) ;;
  fuzzel)  pkgs+=(fuzzel) ;;
  …
esac
case "$(python3 "$A" get answers.json notifications.daemon)" in
  mako)    pkgs+=(mako) ;;
  dunst)   pkgs+=(dunst) ;;
  swaync)  pkgs+=(swaync) ;;
esac
mapfile -t utils < <(python3 "$A" list answers.json utilities.selected)
for u in "${utils[@]}"; do …; done
…
```

(The actual mapping tables live in each `components/<x>/packages.md` — iterate the JSON, look up
the right slice, emit names.) The emitted script **auto-routes at runtime** — it loops over `PKGS`,
sends whatever `pacman -Si` knows to `pacman` and the rest to a detected `paru`/`yay` helper — so
you never have to classify repo-vs-AUR (drift-proof), and `--needed` makes it idempotent (non-pacman
systems just get the name list). The `login-boot` component's `packages.md` slice goes in a
commented `sudo` block; the `plugins` component's hyprpm entries go in the separate commented
hyprpm section (never inline) with the build toolchain added to `PKGS`. Stage it at
`<staging>/install.sh` (installs to `~/.config/hypr/install.sh`, travels with the config + its
backup, version-controls with the dotfiles skill) and `chmod +x` it.

The script is **also what A5 runs** to do the actual install — once written, you don't author a
separate install path.

### A4. Establish the palette via the rice engine

The colors/fonts from the `look-feel` component (palette, fonts, wallpaper sub-questions) live in
`answers.json` under `.palette` / `.fonts` / `.wallpaper`. Read them with `jq`; the engine's
`palette.conf` is the materialized form (key contract in `_shared/palette-schema.md`). Read
`references/theming/engine.md`. Then:

0. **Open ONE restore point for the whole apply, first.** Every stage below (the render pass,
   the browser theming step, the shell-rc edits in A5) enrols in it, so the user can undo the lot
   with one command:
   ```bash
   export RICE_APPLY_ID="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/restore-point.sh" new-id)"
   ```
   Keep that value exported for the rest of the session and relay it in A6 (`rice restore <id>`).
   Skip this and each stage mints its own id: still restorable, but as several sets, not one.
1. Scaffold (idempotent — never clobbers an existing palette):
   `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/rice-init.sh"`
2. Write `~/.config/hypr-rice/palette.conf` from `answers.json` — resolve the chosen source:
   - `.palette.source == "named"` → look up `.palette.scheme` in `references/theming/palettes.md`,
   - `.palette.source == "wallpaper"` → `scripts/palette-from-wallpaper.sh "$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/answers.py" get answers.json wallpaper.path)"`
     (override the scheme type/mode/prefer with `MATUGEN_TYPE`/`MATUGEN_MODE`/`MATUGEN_PREFER` env vars
     if needed — `scheme-tonal-spot`/`dark`/`saturation` by default). **matugen 4.x note:** the script
     now writes a `[config]` table and passes `--prefer` (headless matugen needs it when an image has
     multiple source colors); if you ever invoke matugen by hand, do the same or it errors.
   - `.palette.source == "manual"` → take the hex from `.palette.manual.*`.
   Resolve to the contract keys + `scheme`/`wallpaper`/`font_ui`/`font_mono`/`font_ui_scale`
   (from `.fonts.ui` / `.fonts.mono` / `.fonts.ui_scale`). **Always populate `accent2`**
   (default it to `accent` on the manual path) — the border template references it.
   **Always populate `font_ui_scale`** (default `1.0`) — every visual surface multiplies by it,
   and a missing key on a re-render would un-scale the desktop. On the wallpaper path the
   matugen template already keeps `font_ui` / `font_mono` / `font_ui_scale`, so a later
   re-render (e.g. a wallpaper cycle) won't drop the fonts or the scale.
3. Fill `<staging>/colors.conf` so it installs with the rest (don't let the engine write to
   `~/.config/hypr` before A5): take `references/components/look-feel/hyprland.tmpl`, substitute its `{{accent}}` etc.
   from `palette.conf`, and `Write` the result. Likewise fill any companion-config color placeholders
   **and the staged shell configs' colors files** (`_shell/<app>/colors.css`/`.rasi` etc.) by rendering
   the matching `references/components/<component>/*.tmpl` so the bar/launcher/notifications install already themed. If a
   **widget shell** was chosen (`widgets` component), **register its manifest line**
   (`eww`/`ags`/`quickshell` → its colors file) so `rice apply` re-themes it on every switch, and
   render its colors file into the staged shell tree — see `theming/engine.md` → "Widget-shell
   theming" (HyprPanel/Material-You shells are driven by matugen instead, not the manifest).

   **Mandatory render-manifest entries — one row per selected themable surface.** The
   validator (A5 step 1) ERRORs if any required line is missing — this matrix is the source of
   truth and must stay synchronized with the validator's matrix in
   `agents/hyprland-config-validator.md` → "Render-manifest completeness".

   | Condition in `answers.json` | Manifest name | Template | Output | Reload-cmd | next-X (5th col, v0.21+) |
   |---|---|---|---|---|---|
   | `lock_screen.style` selected OR `companion_configs.hyprlock == true` | `hyprlock` | `templates/hyprlock.tmpl` | `~/.config/hypr/hyprlock.conf` | `:` | `next-lock` |
   | Any Qt default-app picked OR `env.qt_platformtheme == "qt6ct"` | `qt6ct` | `templates/qt6ct.tmpl` | `~/.config/qt6ct/colors/rice.conf` | `:` | `next-launch` |
   | `utilities.osd_route == "swayosd"` | `swayosd` | `templates/swayosd.tmpl` | `~/.config/swayosd/style.css` | `:` | `server-restart` |
   | Any GTK3 default app selected | `gtk3` | `templates/gtk3.tmpl` | `~/.config/gtk-3.0/gtk.css` | `:` | `next-launch` |
   | `default_apps.browser == "firefox"` AND `browser_theming.opt_in == true` AND `browser_theming.restart_hook == true` (default) | `firefox` | `templates/firefox.tmpl` | `<profile>/chrome/rice-colors.css` (resolved by `firefox-bootstrap.sh`) | `bash ~/.config/hypr-rice/firefox-restart.sh` | *(empty — the script restarts)* |
   | `default_apps.browser == "firefox"` AND `browser_theming.opt_in == true` AND `browser_theming.restart_hook == false` | `firefox` | `templates/firefox.tmpl` | `<profile>/chrome/rice-colors.css` | *(empty)* | `next-launch` |

   `:` is the shell no-op — explicit so the engine doesn't substitute a default. The "next X"
   surface group is footer-reported by `rice apply` (Issue 15.3, v0.21.0+ — the
   `next-x-hint` column drives the grouping; see `theming/engine.md` → "Manifest format").

   **Browser theming integration** (v0.21+): when `browser_theming.opt_in == true`, also run
   `bash ~/.config/hypr-rice/firefox-bootstrap.sh` from the install batch to resolve the
   default profile from `profiles.ini` and copy `userChrome.css` + `user.js` into
   `<profile>/chrome/`. Capture `FIREFOX_RICE_COLORS=` from its stdout and substitute that
   path into the firefox manifest line's `output` column. Run it with `RICE_APPLY_ID` still
   exported (A4 step 0) so both profile files it touches join the same restore point as every
   rendered surface; a `FIREFOX_SKIPPED <path> (<why>)` line means that file was left alone
   because its backup could not be written.
4. **Only after a successful install** (A5 returns `ok`/`installed-untested`), run
   `bash ~/.config/hypr-rice/rice apply` so any already-present apps pick up the palette. **Skip it on
   `rolled-back`/`install-failed`** — it would re-render outside the safe-apply harness.

   Every surface it writes is backed up first and enrolled in `RICE_APPLY_ID`'s restore point; the
   run ends with `RESTORE_POINT=<apply-id>`. Read any `RENDER_SKIPPED <name> -> <output> (<why>)`
   line out loud to the user: that surface was deliberately NOT rendered because its backup could
   not be written (usually a read-only directory), and the rest of the manifest still applied.

**Restore-on-login script (v0.14+).** When the rice uses a dynamic engine (matugen/wallust/wallbash),
invoke `render-templates.sh` with `RICE_THEMING_ENGINE=<engine>` in env so it writes
`~/.config/hypr/scripts/restore-theme.sh`. The autostart component's `template.md` adds the matching
`exec-once = …/restore-theme.sh` line (ordered immediately after the wallpaper-daemon line). Script
body per engine is in `theming/engine.md` → "Theme-restore on login". On `theming.engine == none`,
omit both the env var and the `exec-once` line.

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
   `installed-untested` (no running Hyprland; test next login), `refused` (install-config.sh
   declined and changed **nothing**: read the `REFUSED=`/`SHADOWED_BY=` lines above it),
   `install-failed`/`errors-no-backup` (surface + stop). Relay the `BACKUP=` and
   `CONFIG_LANGUAGE=` lines. Respect a `HYPR_DIR` override. (`install-config.sh` /
   `verify-config.sh` exist for running a step alone — see `hyprland-reference/references/testing.md`.)
   - **`REFUSED=lua-config-takes-precedence`** means `~/.config/hypr/hyprland.lua` is already
     there, so a hyprlang `.conf` would be installed and then ignored. Do not work around it by
     deleting the lua file: regenerate in lua (`HYPR_CONFIG_LANG=lua`), or offer the user
     `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/migrate-config.sh"` (an offer that changes
     nothing; `--convert` accepts it and keeps the `.conf` as a backup).
5. **Install the shell configs:** only after `ok`/`installed-untested`, back up then install the staged
   `_shell/<app>/` tree to `~/.config/<app>/`: first
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" ~/.config/waybar ~/.config/wofi ~/.config/rofi ~/.config/mako ~/.config/dunst ~/.config/kitty …`
   (only the dirs you're writing), then copy each staged dir into place. With `RICE_APPLY_ID`
   exported (A4 step 0) those backups join the apply's restore point too. `backup-path.sh` exits
   non-zero and prints `BACKUP <path> -> FAILED (<why>)` for any path it could not back up:
   **do not write that path**; report it instead. Reload running apps with
   `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/apply-theme.sh"` (waybar `SIGUSR2`, mako/dunst
   reload — only if running). Skip on `rolled-back`/`install-failed`.
   - **GTK dark theming needs settings.ini, not just gsettings.** Also stage + install
     `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini` (+ `~/.gtkrc-2.0`) — without
     them GTK3 apps (nm-connection-editor, etc.) render in the default *light* theme on Wayland. See the
     four GTK gotchas under Mode B and `references/theming/gtk-qt.md`.
   - **Plugin daemons started live by `exec-once` don't run on a `hyprctl reload`** — a reload re-reads
     settings but does NOT launch `autostart.conf` programs (bar, wallpaper daemon, notifications,
     widgets, `pypr`, trays). After `ok`, either start them now (`hyprctl dispatch exec <cmd>` mirroring
     each `exec-once`) or tell the user they appear next login — see A6.
   - **Dynamic-wallpaper cycle (optional, from `look-feel`):** if the user wants periodic re-theming, install a
     **systemd user timer** (`OnCalendar=…` + a small `cycle-wallpaper.sh` that runs `rice random <dir>`
     and re-points the hyprlock `current-wallpaper.png` symlink) rather than an `exec-once` loop. The
     matugen path (A4) must be fixed for 4.x or every cycle silently keeps the old palette.

### A6. Report (and start the daemons)

Summarize version, files, backup, validator verdict, **`INSTALL=` package install verdict**,
`SAFE_APPLY`/`VERIFY` result, the chosen palette/fonts (now in `palette.conf` as the source of
truth), and how to restore the backup (`rm -rf ~/.config/hypr && cp -a ~/.config/hypr.bak.<ts>
~/.config/hypr && hyprctl reload`).

**Give the user the undo for everything else.** One line, one command: every surface outside
`~/.config/hypr` that this apply wrote (rendered app configs, Firefox profile files, shell rc
files) goes back with `rice restore <apply-id>`, using the `RESTORE_POINT=`/`RICE_APPLY_ID` value
from A4. `rice restore --list` shows what is still undoable. It is a different mechanism from the
Hyprland-dir backup above, on purpose: that directory keeps its own separate restore.

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
`components/env/gotchas.md` and `components/look-feel/gotchas.md`).

---

## Mode B — Theme every surface from one palette

Apply one coherent palette across the whole desktop: **one normalized palette → render per-app color
files → reload each app** (see `references/theming/theming-architecture.md`, and the per-app contracts
in `references/_shared/colors-contract.md`). Use only current syntax (defer to hyprland-reference).
For *how* each surface should look — where the accent goes, contrast, transparency, the archetypes —
read each visual component's `styling.md` plus `hyprland-reference/references/styling/design-principles.md`.

### B1. Choose the palette source & fonts (always ask)

Run the `look-feel` component's interview inline (`references/components/look-feel/interview.md`
— palette source → scheme/wallpaper/manual, accent, light/dark; UI font; monospace/Nerd font; plus
the wallpaper sub-questions). One component is light enough to run inline, but **still record each
answer** via `record-answer.sh` into `~/.config/hypr-rice/answers.json` — that way a later A-mode
build (or a profile save) can replay exactly what was chosen. The named-scheme catalog is
`references/theming/palettes.md`; for the wallpaper source, `scripts/palette-from-wallpaper.sh`
produces the palette when matugen/wallust is present. Resolve every answer into the **palette
contract** (`references/_shared/palette-schema.md`) as bare `RRGGBB`. Don't pick a scheme or fonts
silently — present them.

### B2. Choose surfaces (default: all installed)

Default to every surface whose app is installed/running: Hyprland + hyprlock, waybar, mako/dunst/swaync,
wofi/rofi, kitty/terminal, GTK (3+4), Qt, cursor/icons/fonts. Skip (and note) absent apps.

### B3. Prefer the engine (reproducible)

For a real rice, drive the **engine** rather than writing each file ad hoc — it makes the theme
reproducible, re-applyable, and version-controllable (see `references/theming/engine.md`):

1. `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/rice-init.sh"` (scaffold/refresh, idempotent).
2. Resolve the palette and write `~/.config/hypr-rice/palette.conf` (the source of truth).
3. Ensure each app reads its colors file (one-time wiring: `source=`/`@import`/`include`).
4. Back up first: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" <paths being changed>`.
5. `bash ~/.config/hypr-rice/rice apply` (renders every template + reloads running apps). Apply fonts
   across `gsettings` (`font-name`/`monospace-font-name`), GTK `settings.ini`, kitty `font_family`,
   waybar `font-family` per `theming/fonts.md`. For the cursor, also `hyprctl setcursor <Cursor> <size>`.

**GTK theming has four engine-breaking gotchas** — (1) a session `GTK_THEME=` (default under uwsm —
`~/.config/uwsm/env`) that silently defeats the re-theme until the env is fixed and live-propagated;
(2) "folder color is the icon theme, not the GTK theme" (set a scheme-matched `icon-theme` too); (3) a
root-owned `gtk-4.0/gtk.css` symlink that render hits as *Permission denied* (now handled by
`render-templates.sh`); and (4) **`gsettings` alone does NOT theme GTK3 apps** (nm-connection-editor,
etc.) on Wayland — they fall back to the default *light* theme unless you also write
`~/.config/gtk-3.0/settings.ini` **and** `~/.config/gtk-4.0/settings.ini` (`gtk-theme-name=Adwaita-dark`,
`gtk-application-prefer-dark-theme=1`, `gtk-icon-theme-name`, `gtk-font-name`, `gtk-cursor-theme-name/size`)
plus `~/.gtkrc-2.0` for GTK2. (libadwaita follows `color-scheme=prefer-dark` via the portal but still
wants the settings.ini; changes apply only to newly-launched apps.) Full detail, the propagation
commands, and the murrine-needs-`sassc` build note live in **`references/theming/gtk-qt.md`**.

For one-off, non-engine theming, each visual component's `template.md` plus the per-app color
contracts in `references/_shared/colors-contract.md` and `scripts/apply-theme.sh` (reloads running
apps + cursor) remain valid.

### B4. Verify & report

Confirm the Hyprland color file still parses:
`bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/verify-config.sh"`. `VERIFY=ok` → done; `VERIFY=errors`
→ restore the Hyprland files from the backup, reload, report. Summarize source/scheme, surfaces
themed, files written, backups, reload/verify results, and any package to install for more.

---

## Mode C — Named profiles & the override cascade

A **profile** is a snapshot of `palette.conf` (palette + scheme + wallpaper + fonts) at
`~/.config/hypr-rice/profiles/<name>.conf`. Fourteen presets ship: `catppuccin-mocha`,
`catppuccin-frappe`, `catppuccin-macchiato`, `catppuccin-latte` (light), `gruvbox`, `nord`,
`tokyo-night`, `rose-pine`, `dracula`, `everforest`, `kanagawa`, `solarized-dark`,
`high-contrast-dark` (WCAG-AAA), `high-contrast-light` (WCAG-AAA).

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
("change wallpaper, the desktop follows"). Read `references/theming/wallpaper.md`.

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
   set up a **systemd user timer** or a Hyprland `exec-once` loop — see `theming/wallpaper.md`; tell the user
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

The reference tree is **per-component** — one folder per interview component, plus a small set of
shared contracts and the theming engine docs. Each component folder owns its sub-interview, schema,
template, gotchas, install slice, and (for visual components) styling/validation/reload notes:

```
references/
├── _interview-protocol.md       # interview protocol + components-walked table
├── _shared/
│   ├── palette-schema.md        # palette.conf key contract
│   ├── colors-contract.md       # per-app color var contracts
│   ├── dispatchers.md           # Hyprland dispatcher catalog
│   └── version-matrix.md        # Hyprland version branches & syntax gates
├── components/<x>/              # one folder per component (22 total)
│   ├── README.md
│   ├── interview.md             # sub-questions for the interviewer
│   ├── schema.md                # answers.json keys this component owns
│   ├── template.md              # what gets emitted (Mode A)
│   ├── gotchas.md
│   ├── packages.md              # this component's install slice
│   ├── styling.md               # visual components only
│   ├── validation.md            # visual components only
│   └── reload.md                # visual components only
└── theming/                     # the rice engine + cross-surface theming
    ├── engine.md                # palette.conf, render manifest, rice CLI
    ├── theming-architecture.md  # the overall theming model
    ├── palettes.md              # named schemes → contract hex
    ├── fonts.md                 # font roles + catalog + apply
    ├── wallpaper.md             # backends, dynamic theming, cycling
    ├── apps.md                  # long-tail per-app templates
    └── gtk-qt.md                # GTK/Qt gotchas + theming
```

**Protocol & shared contracts**

- **`references/_interview-protocol.md`** — the interview protocol (order, no-defaulting rule,
  `answers.json` recording, components-walked table). Used by the **hyprland-interviewer** agent.
- **`references/_shared/palette-schema.md`** — the `palette.conf` key contract (accent/accent2,
  bg/fg, ANSI 0..15, scheme, font_ui, font_mono, font_ui_scale, wallpaper). A4 fills this;
  B/C/D rewrite it.
- **`references/_shared/colors-contract.md`** — per-app color variable contracts (the names each
  rendered colors file exports for waybar/wofi/mako/kitty/eww/…).
- **`references/_shared/dispatchers.md`** — the Hyprland dispatcher catalog (keybinds component
  and component-writer agents lean on this).
- **`references/_shared/version-matrix.md`** — Hyprland version branches and syntax gates.

**Components (one folder each — 22 total)**

Walked in interview order:

- **`components/monitors/`** — display layout, resolution, scale, transforms.
- **`components/input/`** — kbd layout/variant/options, mouse/touchpad, gestures.
- **`components/keybinds/`** — mod, app launchers, window/workspace dispatchers, custom binds.
- **`components/default-apps/`** — browser/file-manager/terminal/editor defaults + handlers.
- **`components/env/`** — toolkit env, NVIDIA gates, uwsm `~/.config/uwsm/env`.
- **`components/look-feel/`** — gaps/borders/rounding/blur/animations **plus** the palette,
  fonts, and wallpaper sub-questions (also re-used by Mode B).
- **`components/window-rules/`** — `windowrulev2` recipes (workspaces, float, size, opacity).
- **`components/autostart/`** — `exec-once` lineup (bar, wallpaper daemon, notif daemon, polkit, …).
- **`components/companion-daemons/`** — `hyprlock.conf` / `hypridle.conf` / `hyprpaper.conf`.
- **`components/plugins/`** — hyprpm community plugins (hyprexpo, hyprscrolling, hy3,
  split-monitor-workspaces, hyprbars, borders-plus-plus, hyprtrails, hyprwinwrap, pyprland).
- **`components/terminal/`** — kitty / alacritty / foot / wezterm config + colors include.
- **`components/waybar/`** — `config.jsonc` + `style.css` (full functional depth).
- **`components/widgets/`** — eww / AGS-Astal / Quickshell / HyprPanel scaffold + colors wiring.
- **`components/launcher/`** — wofi / rofi / fuzzel / tofi config + colors.
- **`components/notifications/`** — mako / dunst / swaync config + colors.
- **`components/lock-screen/`** — hyprlock styling (the lock surface; the daemon config is in
  `companion-daemons/`).
- **`components/shell-prompt/`** — interactive shell (bash/zsh/fish) + prompt engine
  (starship/oh-my-posh) + fetch + modern-CLI aliases; managed-block recipe lives here.
- **`components/utilities/`** — screenshot / screenrecord / OCR / color-picker / power-menu scripts
  (shipped in `assets/scripts/`), clipboard / emoji / calc binds, Wi-Fi/BT applets.
- **`components/login-boot/`** — greetd/tuigreet/ReGreet + SDDM + boot chrome.
- **`components/gaming/`** — tearing (`allow_tearing` + `immediate`), VRR, fullscreen
  effect-stripping, `misc:vfr`, the shipped `gamemode.sh` toggle.
- **`components/laptop/`** — battery/lid/backlight/touchpad-gesture sub-questions (opt-in; chassis
  is the default, not an answer).
- **`components/accessibility/`** — opt-in a11y tweaks.

Each component's `packages.md` is the install slice for A3d/A5 (the installer agent concatenates
them into `install.sh`). Each visual component's `styling.md` is the design-principles guide for
that surface.

**Theming**

- **`references/theming/engine.md`** — the rice engine: `palette.conf` source of truth, render
  manifest, the `rice` CLI, matugen/wallust integration, the user-override cascade, reproducibility,
  shell-and-prompt theming, widget-shell theming.
- **`references/theming/theming-architecture.md`** — the overall theming model (palette → per-app
  colors → reload), how the contract files compose.
- **`references/theming/palettes.md`** — named schemes → contract hex (+ matching GTK/cursor/icons).
- **`references/theming/fonts.md`** — font roles, the catalog to present, detection, applying UI +
  Nerd fonts.
- **`references/theming/wallpaper.md`** — backends, dynamic theming, cycling automation.
- **`references/theming/apps.md`** — shipped long-tail templates (btop/cava/starship/swaync/wlogout/
  fuzzel) + reaching matugen's 50+ app library.
- **`references/theming/gtk-qt.md`** — GTK/Qt theming gotchas (the four engine-breaking ones —
  `GTK_THEME=`, icon-theme vs GTK-theme, root-owned `gtk.css` symlink, `gsettings`-alone-misses-GTK3).
- **`scripts/`** — `detect-version.sh`, `detect-theme-tools.sh`, `rice-init.sh`, `render-templates.sh`,
  `apply-theme.sh`, `set-wallpaper.sh`, `palette-from-wallpaper.sh`, `safe-apply.sh`,
  `install-config.sh`, `verify-config.sh`, `verify-shell.sh`, `backup-config.sh`, `reset-config.sh`,
  `config-language.sh`, `emit-config.sh`, `migrate-config.sh`.
- **`${CLAUDE_PLUGIN_ROOT}/scripts/record-answer.sh`** — `jq`-based `setpath` into `answers.json`.
  Called by the interviewer agent after every `AskUserQuestion` so picks land on disk before the
  next question.
- **Agents** (under `${CLAUDE_PLUGIN_ROOT}/agents/`):
  - `hyprland-interviewer` — owns the 22-component interview (walking
    `_interview-protocol.md` + each `components/<x>/interview.md`), records each answer to
    `<staging>/answers.json`, runs the review pass, returns just the path + a summary. **A1 spawns
    this so the main loop's context stays clean.**
  - `hyprland-component-writer` — authors one surface (waybar / launcher / notifications / terminal /
    lock-screen / widgets / Hyprland topic) into staging. **A3 + A3b spawn several in parallel**,
    each fed a `jq` slice of `answers.json`.
  - `hyprland-package-installer` — runs the generated `install.sh` (or an ad-hoc package list) after
    A5 user confirmation. Handles pacman/paru routing, paru bootstrap, transient retries.
  - `hyprland-config-validator` — static lint of the staging dir (and optional live load-test). A5
    step 1.
- **`assets/scripts/*.sh`** — utility scripts shipped as-is (copy + `chmod`, not rendered):
  `screenshot.sh`, `screenrecord.sh`, `ocr.sh`, `colorpicker.sh`, `powermenu.sh` (see
  `components/utilities/template.md`), `gamemode.sh` (effects toggle, see
  `components/gaming/template.md`), `keybind-cheatsheet.sh` (reads `hyprctl binds -j`),
  `blur-toggle.sh`, `theme-switch.sh` (menu of saved rices → `rice theme`).
- **`references/components/<component>/*.tmpl`** + **`references/theming/{gtk4,palette.matugen}.tmpl`** —
  the color templates the engine renders (incl. the shell/prompt set:
  `shell-prompt/fish.tmpl` → fish `conf.d` colors, `shell-prompt/starship.tmpl` → rice-owned `starship.toml`,
  `shell-prompt/oh-my-posh.tmpl` → rice-owned `rice.omp.json`; and the **widget-shell set**:
  `widgets/eww.tmpl` → eww `colors.scss`, `widgets/ags.tmpl` → AGS/Astal `colors.scss`,
  `widgets/quickshell.tmpl` → Quickshell `Colors.qml`; registered in the manifest
  when chosen — see `theming/engine.md` → "Shell & prompt theming" and "Widget-shell theming").
- **`assets/profiles/*.conf`** — the twelve shipped preset rices; **`assets/rice`** — the CLI
  (incl. `rice wallpapers [scheme]` to list and `rice get-wallpaper <scheme> <n|name> [--set]` to
  curl-download a matching wallpaper; `rice accents [scheme]` to list per-scheme accent variants and
  `rice accent <name|hex> [--pin]` to swap the accent; `rice theme-toggle <a> <b>` flips two profiles
  for the dark/light keybind and `rice theme-next` cycles them). **`assets/wallpapers.tsv`** — the curated,
  theme-tagged, curl-downloadable wallpaper catalog (verified raw URLs; `scheme<TAB>name<TAB>url`).
  **`assets/accents.tsv`** — per-scheme accent variants (`scheme<TAB>name<TAB>hex`, 6–8 each).
- **`examples/sample-config/`** — a complete reference output (a generated modular config set).
- **`${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh`** — timestamped backup of arbitrary paths.

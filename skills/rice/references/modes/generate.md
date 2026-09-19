# Mode A, part 1 - generate into staging

Interview the user, then build the whole desktop into a STAGING directory. Nothing in
this file touches the user's machine: that is the point of the split. When staging is
complete and validated, continue with [`apply.md`](apply.md).

## Contents

- A1. Run the interview
- A2. Pre-load context
- A3. Generate into staging
- A3b. Functional shell configs (parallel writers)
- A3c. Shell & prompt
- A3d. The package install script

---

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

The agent walks the question bank in `../_interview-protocol.md` (protocol + the
components-walked table) plus each `../components/<x>/interview.md`, **asks every
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
2. Read `../_interview-protocol.md` for the order + the asking discipline. Read each
   `../components/<x>/interview.md` in walked-order for that component's sub-questions.
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
`~/.config/hypr`) using each **`../components/<x>/template.md`** as the structure (one per
Hyprland topic file — `monitors`, `input`, `keybinds`, `env`, `look-feel`, `window-rules`,
`autostart`, `companion-daemons`, `plugins`). **Read every pick from `<staging>/answers.json` with
`jq`** — never from memory or chat history. The component schemas (each `../components/<x>/schema.md`)
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
  `widgets.system` and `utilities.osd_route` land — see `../_shared/namespaces.md`)
- `keybinds` writer → `widgets utilities gaming lock_screen` (so the expected toggle/launch
  binds for those surfaces land — see `../_shared/expected-binds.md`)
- `waybar` writer → `utilities notifications` (so `custom/power` and `custom/notification`
  modules land — see `../_shared/expected-binds.md` "Waybar modules")
- `autostart` writer → `widgets utilities notifications` (so the shell autostart, swayosd
  daemon, and notification daemon lines land in one consistent order)

> **No jq at generation time, and python is not free either.** Everything between A0 and the
> package install batch (A5 step 3) runs on a clean Arch box where `jq` is not yet on disk —
> `jq` is itself one of the packages the rice installs. Generation-time tooling reads
> `answers.json` through `scripts/answers.py` (`get` / `slice` / `list` / `has`) and writes
> through `scripts/record-answer.py`; both depend only on the Python stdlib.
>
> **Python is NOT guaranteed on Arch.** The `base` meta-package depends on 28 packages and
> python is not among them; `pacman` lists python only as a *check* dependency, which is used
> to run pacman's own test suite and is never installed on a user's machine. So a genuinely
> minimal Arch install — the exact case this path was written for — can have no `python3`, and
> the interview would not be able to record a single answer. **A0 runs
> `scripts/ensure-python.sh` before the interview starts**, which asks once, installs `python`,
> and records it like any other package. Do not skip it and do not assume the interpreter.
>
> Runtime helpers (`keybind-cheatsheet.sh`, eww data scripts, rice CLI) keep using `jq`
> because they execute after the install.

The main loop is responsible for:
- The index file `hyprland.conf` (variables + `source=` lines — small, benefits from the
  surrounding context),
- `colors.conf` (filled in A4 — not by hand),
- Aggregating the per-topic writer reports.

The writer agents produce the rest in parallel: `env.conf`, `monitors.conf`, `input.conf`,
`looknfeel.conf`, `binds.conf`, `windowrules.conf`, `autostart.conf`, plus the **companion configs**
(`hyprlock.conf`/`hypridle.conf`/`hyprpaper.conf`) for any tool the user chose (these are read by
their own daemons — NOT `source=`d — but stage them so they install + back up together). Match
syntax to the detected version; wire ecosystem keybinds per `../components/keybinds/template.md`.
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
**`../components/<x>/template.md`** as the recipe source. These live under their own
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

**Multi-tool surfaces are sharded by tool** (`launcher`, `notifications`, `terminal`, `widgets`):
the writer reads that component's `common.md` plus the ONE `tools/<tool>.md` its pick names, never
the siblings. That is the difference between a writer reading ~10k tokens about the tool it is
writing and ~27k about five tools it is not. The component `README.md` holds the routing table.

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
  (`ags.tmpl`/`quickshell.tmpl`) — recipe in `../components/widgets/common.md` **plus the one**
  `../components/widgets/tools/<system>.md` the pick names (never the others), wiring in
  `../theming/engine.md` → "Widget-shell theming". A **full
  shell replaces waybar** (drop the waybar `exec-once`) and may **own notifications** (then skip the
  notifications component). **HyprPanel / Material-You** shells: drive via matugen, don't hand-theme.
  Heavy shells (Quickshell/AGS) take real time to compile — warn the user about that at install time
  (A5) so they know the batch will be slow.
- **Launcher** (`launcher`): `wofi/config` + `wofi/style.css` (`@import "colors.css";`), or
  `rofi/config.rasi` (+ a theme that `@import`s `colors.rasi`), or fuzzel/tofi `.ini` — per the chosen
  tool/mode/layout, recipe in `../components/launcher/common.md` + the one `tools/<tool>.md`.
- **Notifications** (`notifications`): `mako/config` / `dunst/dunstrc` / `swaync/config.json`+
  `style.css` — per the chosen daemon/position/timeout/behavior (recipe in
  `../components/notifications/common.md` + the one `tools/<daemon>.md`). Leave color keys to the engine (don't hardcode hex). Skip
  if a full widget shell owns notifications — only one daemon can hold the D-Bus name.
- **Terminal** (`terminal`): the emulator's config (e.g. `kitty/kitty.conf`, `alacritty/alacritty.toml`,
  `foot/foot.ini`) with opacity/padding/cursor/font-size from the interview (recipe in
  `../components/terminal/common.md` + the one `tools/<emulator>.md`), including its colors file the engine themes
  (`include`/`source`).

Keep module on-clicks aligned to installed tools (network → `nm-connection-editor`, audio →
`pavucontrol`). Don't hardcode theme colors anywhere — every shell config reads the engine's colors
file. These get backed up + installed alongside the Hyprland config in A5.

### A3c. Set up the shell & prompt (shell-prompt component)

Read the shell pick from `answers.json` (`python3 scripts/answers.py get answers.json
shell_prompt.shell` → `fish`/`zsh`/`bash`/`keep-current`; same for `.shell_prompt.prompt`,
`.shell_prompt.fetch`, `.shell_prompt.fish_colors`, `.shell_prompt.fisher`,
`.shell_prompt.modern_cli`). Then configure
the interactive shell, leaning on **`../components/shell-prompt/template.md`** (managed
block, guarded inits, parse-test) and **`../components/shell-prompt/gotchas.md`** for *behavior* and
the rice engine (A4) for *colors*:

- **Prompt engine** (starship default / oh-my-posh): register its manifest line so the engine
  renders a rice-owned config (`~/.config/hypr-rice/starship.toml` / `rice.omp.json`), and add the
  guarded init to the shell's managed block — starship with `export STARSHIP_CONFIG=…` first,
  oh-my-posh with `oh-my-posh init <shell> --config …`. See `../theming/engine.md` → "Shell & prompt
  theming" for the exact lines.
- **fish colors** (if fish): register the `fish` manifest line → `conf.d/zz-hypr-rice-colors.fish`
  (auto-sourced; themes fish's syntax highlighting from the palette).
- **Startup fetch & aliases**: add the chosen fetch (fastfetch default) + guarded modern-CLI
  aliases to the managed block per `../components/shell-prompt/template.md`.

Editing rc files mid-generation is delicate (parse-test after each change, never source). If the
shell work is substantial, it's fine to finish the Hyprland install (A5/A6) first, then do the
shell pass — but the prompt/fish *colors* must go through the engine so they re-theme. Back up rc
files before editing (`backup-path.sh`).

### A3d. Generate the package install script (for review + replication)

The interview selects many tools (terminal, bar, launcher, notification daemon, fonts, palette
generator, utilities, shell/prompt, widget shell, plugins). Stage a reviewable **`install.sh`** so
the user can see exactly what will be installed and so the script ships with the dotfiles to a new
machine (idempotent on re-run). **Each component owns its own install slice** at
**`../components/<x>/packages.md`** — walk every component the user picked something from
and concatenate. The installer agent (A5) assembles `install.sh` from these slices.

**Walk `answers.json` deterministically — don't recall picks.** Iterate the answer keys, look up
each pick's package name(s) in the relevant `../components/<x>/packages.md` slice, collect into **one
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

(The actual mapping tables live in each `../components/<x>/packages.md` — iterate the JSON, look up
the right slice, emit names.) The `login-boot` component's `packages.md` slice goes in a
commented `sudo` block; the `plugins` component's hyprpm entries go in the separate commented
hyprpm section (never inline) with the build toolchain added to `PKGS`. Stage it at
`<staging>/install.sh` (installs to `~/.config/hypr/install.sh`, travels with the config + its
backup, version-controls with the dotfiles skill) and `chmod +x` it.

**The emitted script resolves the list; it does NOT implement the install.** Routing repo-vs-AUR,
the AUR-helper bootstrap and its disclosure, the non-Arch skip and the install record all live in
one shipped routine, `install-packages.sh`, which the installer agent calls for an ad-hoc list
too. That is what makes a scripted install and an ad-hoc one leave the SAME record in the same
place: a record only one route writes is a record the user cannot rely on. So the tail of every
emitted `install.sh` is this shape, verbatim:

```bash
# The one install routine: routing, the AUR-helper disclosure, and the record that says what
# this put on the machine. Installed beside the engine by rice-init.sh, so this script still
# works on a new machine without the plugin.
#
# Never spell $HOME/.config here. This script is installed INTO the hypr config dir, so the
# rice dir is its sibling whatever the user set XDG_CONFIG_HOME to - which is the same answer
# scripts/xdg-config.sh gives, arrived at without re-deciding it.
_here="$(cd "$(dirname "$0")" && pwd)"
INSTALLER=""
for c in "${RICE_DIR:+$RICE_DIR/install-packages.sh}" \
         "$_here/../hypr-rice/install-packages.sh" \
         "${CLAUDE_PLUGIN_ROOT:-}/scripts/install-packages.sh"; do
    [ -n "$c" ] && [ -f "$c" ] && { INSTALLER="$c"; break; }
done
if [ -z "$INSTALLER" ]; then
    echo "ERROR: install-packages.sh not found (looked beside this script's rice dir and in" >&2
    echo "       \$CLAUDE_PLUGIN_ROOT/scripts). Nothing was installed: an install that leaves no" >&2
    echo "       record is not something this script does. Re-run rice-init.sh, then re-run this." >&2
    exit 2
fi
bash "$INSTALLER" --route install.sh "${PKGS[@]}"
echo "Done"
```

`--needed` idempotence, the `pacman -Si` partition, one-at-a-time AUR installs and the non-Arch
name-list-only behaviour are all inside that routine: do not re-spell any of them in the emitted
script. A re-run is safe and produces a second record showing everything as already present,
which is exactly what it should say.

The script is **also what A5 runs** to do the actual install — once written, you don't author a
separate install path.


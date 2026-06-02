---
name: generate-config
description: This skill should be used when the user runs "/hyprland-config:generate-config" or asks to "generate a hyprland config", "create my hyprland.conf", "set up Hyprland from scratch", "make me a new Hyprland config", or "build a hyprland config". Runs an interactive interview, generates a modular Hyprland config matching the installed version, backs up any existing config, writes it to ~/.config/hypr, and validates the result.
argument-hint: "[optional notes, e.g. 'dual monitor, vim keybinds']"
allowed-tools: AskUserQuestion, Bash, Read, Write, Glob, Agent
version: 0.2.0
---

# Generate Hyprland Config

Generate a complete, validated Hyprland configuration from scratch by interviewing the user
about their setup, then emit a **modular** config (a main `hyprland.conf` that `source=`s topic
files), back up any existing config, write it to `~/.config/hypr`, and validate it.

Treat `$ARGUMENTS` as freeform hints (monitor count, keybind style, apps). Use them to
pre-fill or skip interview questions, but still confirm anything load-bearing.

This skill leans on the **Hyprland Config Reference** skill for syntax. Read its reference files
(under `skills/hyprland-reference/references/`) whenever generating a section, and cross-check
every option against `deprecations.md` so deprecated syntax is never emitted. For **tasteful
look-and-feel and palette defaults** (so the generated config looks designed, not stock-gray),
consult its styling library `skills/hyprland-reference/references/styling/` — especially
`hyprland-decoration.md` (gaps/borders/rounding/blur/shadow/animation values that look good) and
`design-principles.md` (palette coherence, accent discipline). The Area C and C-theme answers map
onto these. For companion apps
(bars, launchers, lock/idle, screenshots, clipboard, portals) read
`hyprland-reference/references/ecosystem.md` — it has the package names, launch commands, and the
`hyprlock`/`hypridle`/`hyprpaper` config formats. Prefer the first-party Hypr ecosystem tools as
defaults.

## Workflow

Execute these steps in order. Do not write to `~/.config/hypr` until the config is generated and
the user has seen the plan.

### 1. Detect the Hyprland version

Run the detection script and record the version — it determines which syntax to emit:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/generate-config/scripts/detect-version.sh"
```

It tries `hyprctl version`, then `Hyprland --version`, and prints `HYPR_VERSION=<x.y.z>` or
`HYPR_VERSION=unknown`. If unknown, assume the latest stable syntax and tell the user that
assumption. Use the version to decide version-sensitive choices (shadow/blur subcategories,
`master:new_status`, `gesture=` vs `gestures{}`, `windowrule` vs `windowrulev2`) per
`hyprland-reference/references/deprecations.md`.

The script also probes which common ecosystem packages are installed (via `pacman -Qq` and
`command -v`) and prints `HAVE_<tool>=1` / `MISSING_<tool>=1` lines. Use these to bias interview
defaults toward installed tools, and to flag in the final summary any recommended package the
user would need to install (especially `xdg-desktop-portal-hyprland` for screen sharing). Never
install anything.

### 2. Run the interview

Gather preferences with the `AskUserQuestion` tool, grouped into the five topic areas. Use the
question bank and recommended defaults in **`references/interview.md`**. Guidance:

- Ask in batches (one `AskUserQuestion` call per topic area, multiple questions per call).
- Offer sensible defaults as the first option so a user can move fast.
- Skip questions already answered by `$ARGUMENTS` or by an existing config (read it first if
  present — see step 3).
- The five areas: **(a) Monitors & input**, **(b) Keybinds & apps**, **(c) Look & feel**,
  **(c-theme) Palette & fonts**, **(d) Autostart & env**.

**Area C-theme (palette & fonts) is what makes the result look coherent** instead of a stock-gray
box with a random border. It is the *same* question bank `theme-config` uses — read the shared
**`skills/theme-config/references/interview.md`** (palette source, accent, UI font, monospace/Nerd
font). Run `theme-config/scripts/detect-theme-tools.sh` first so the font/generator options match
what's installed. These answers feed the rice engine in step 4, so they must be gathered in the
interview, not improvised at generation time. Don't pick a scheme or fonts silently — present them
(if the user says "good defaults", use Catppuccin Mocha + an installed Nerd Font + an installed UI
font and say what you chose).

### 3. Read any existing config (context only)

If `~/.config/hypr/hyprland.conf` exists, read it to learn the current monitor names, layout,
and apps so questions can be pre-filled. Do not edit it in place — it will be backed up wholesale
in step 5.

### 4. Generate the modular config into a staging directory

Build the file set in a temp staging dir (e.g. `/tmp/hypr-gen-<something-stable>`), not directly
in `~/.config/hypr`. Use the templates in **`references/templates.md`** as the structure. Produce:

| File              | Contents                                                        |
|-------------------|-----------------------------------------------------------------|
| `hyprland.conf`   | Variables (`$mod`, apps) + `source=` lines for the files below  |
| `env.conf`        | `env=` lines (sourced first, before anything that needs them)   |
| `colors.conf`     | Palette vars (`$accent` …) — **do not author by hand; filled in step 4b** |
| `monitors.conf`   | `monitor=` lines                                                |
| `input.conf`      | `input {}` block                                                |
| `looknfeel.conf`  | `general {}`, `decoration {}`, `animations {}`, layout block    |
| `binds.conf`      | `bind`/`bindm`/`bindel` lines                                   |
| `windowrules.conf`| `windowrule` / `layerrule` lines                               |
| `autostart.conf`  | `exec-once=` lines for the chosen ecosystem tools              |

Plus **companion configs** for any ecosystem tool the user opted into (these are NOT `source=`d —
they are read by their own daemons, but are staged here so they install and back up together):

| File             | When                          | Source of format                                  |
|------------------|-------------------------------|---------------------------------------------------|
| `hyprlock.conf`  | hyprlock chosen (Area D6)     | `ecosystem.md` → hyprlock (required or it errors) |
| `hypridle.conf`  | hypridle chosen (Area D5)     | `ecosystem.md` → hypridle                         |
| `hyprpaper.conf` | hyprpaper chosen (Area D3)    | `ecosystem.md` → hyprpaper                        |

Write each file with the `Write` tool into the staging dir. Keep the syntax matched to the
detected version. Add brief `#` comments grouping sections. Wire ecosystem keybinds (screenshot,
lock, color picker, logout, clipboard history) into `binds.conf` per `references/templates.md`,
using the tool the user picked.

`hyprland.conf` must `source = ~/.config/hypr/colors.conf` (early — see `templates.md`), and
`looknfeel.conf`'s `col.active_border` defaults to `$accent $accent2 45deg`. Those variables come
from the rice engine in step 4b, not from a hand-written color — so the look stays in sync with a
later re-theme.

### 4b. Establish the palette via the shared rice engine

The colors and fonts gathered in **Area C-theme** are owned by the **rice engine**
(`~/.config/hypr-rice/`), the same source of truth `theme-config` uses. Wiring it here is what
makes a generated config come out coherently themed and keeps a later
`/hyprland-config:theme-config` perfectly consistent (it just rewrites the same `palette.conf`).
Read `theme-config/references/engine.md` for the contract. Do this:

1. **Scaffold the engine** (idempotent — never clobbers an existing palette):
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/rice-init.sh"
   ```
2. **Write `~/.config/hypr-rice/palette.conf`** from the Area C-theme answers — resolve the chosen
   named scheme (`theme-config/references/palettes.md`), wallpaper-generated palette (run
   `${CLAUDE_PLUGIN_ROOT}/skills/theme-config/scripts/palette-from-wallpaper.sh`), or manual hex
   into the contract keys, and set `scheme`, `wallpaper`, `font_ui`, `font_mono`. This file is the
   source of truth; overwrite the seeded default with the user's actual choice. **Always populate
   `accent2`** even for the manual-hex path (default it to `accent`, or a derived neighbouring hue)
   — the border template below references `$accent2`, so an undefined value would error the reload.
3. **Fill `colors.conf` into the staging dir** so it installs and backs up with the rest (do *not*
   let the engine write to `~/.config/hypr` yet — that breaks the "nothing touches `~/.config/hypr`
   before step 5" rule). Take the engine's Hyprland template
   `${CLAUDE_PLUGIN_ROOT}/skills/theme-config/templates/hyprland.tmpl`, substitute its `{{accent}}`
   `{{accent2}}` `{{bg}}` `{{fg}}` `{{surface}}` `{{muted}}` placeholders with the bare hex from
   `palette.conf`, and `Write` the result to `<staging>/colors.conf` (it defines `$accent`/`$accent2`
   /`$bg`/`$fg`/`$surface`/`$muted`). Likewise fill the `{{accent_hex}}`/`{{surface_hex}}`/`{{fg_hex}}`
   /`{{font_ui_family}}` placeholders in any companion configs (e.g. `hyprlock.conf`) from the same
   palette. (Equivalently you can run `render-templates.sh --no-reload <palette> <manifest>` with a
   one-line manifest whose output column is `<staging>/colors.conf`, but inline substitution is
   simpler and keeps the write inside staging.)
4. **Only after a successful install** (step 5 returns `SAFE_APPLY=ok` or `installed-untested`), run
   `bash ~/.config/hypr-rice/rice apply` so any *already-present* app configs (kitty, waybar if the
   user already had them) also pick up the palette. **Skip `rice apply` on `SAFE_APPLY=rolled-back`
   or `install-failed`** — it would re-render `~/.config/hypr/colors.conf` and `hyprctl reload`
   outside the safe-apply harness, undoing the rollback.

On a fresh setup the only wired app is Hyprland itself (its `colors.conf` is already installed by
step 5), so `rice apply` here is essentially a no-op except for apps the user already had. The
bar/terminal/GTK get themed from this same `palette.conf` as those configs come to exist (the
`desktop-shell` skill folds colors in, and a later `theme-config`/`rice apply` renders them).
Mention this in the final summary so the user knows the palette is already set for everything
downstream.

### 5. Back up and install

### 5a. Static validation (before touching disk)

Before installing, invoke the **hyprland-config-validator** agent (via the `Agent` tool) on the
**staging dir**, passing the detected version. Fix any ERRORs it reports and regenerate before
proceeding — it is far cheaper to catch problems here than after install.

### 5b. Install + live-test + auto-rollback

Run the **safe-apply** script, passing the staging dir. It timestamp-backs up the **entire**
existing `~/.config/hypr`, installs the staged files, then **live-tests** the result
(`hyprctl reload` + `hyprctl configerrors`) and **auto-rolls-back to the backup** if the new
config fails to load:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/generate-config/scripts/safe-apply.sh" /tmp/hypr-gen-<id>
```

Read its final `SAFE_APPLY=` line and relay the outcome:

- `SAFE_APPLY=ok` — installed and the live config reloaded with **no errors**. Done.
- `SAFE_APPLY=rolled-back` — the new config had parse errors (printed above the line); the
  previous config was restored and reloaded. Show the errors, fix them, regenerate, retry.
- `SAFE_APPLY=installed-untested` — no running Hyprland to test against; installed, relying on
  static validation. Tell the user to test on next login.
- `SAFE_APPLY=install-failed` / `errors-no-backup` — surface the message and stop.

Relay the `BACKUP=` path too. Respect a `HYPR_DIR` env override if the user sets one. Install is
**additive per file** (`cp -f`): unrelated files the user keeps (`hyprpaper.conf`,
`hypridle.conf`, `hyprlock.conf`) survive, and the full backup preserves prior state regardless.
(The lower-level `install-config.sh` and `verify-config.sh` exist if a step needs to be run on
its own — see `hyprland-reference/references/testing.md`.)

### 6. Report and next steps

Summarize: version targeted, files written, backup location, validator verdict, and the live
`SAFE_APPLY`/`VERIFY` result. If `ok`, the config **settings** are live (reload ran). Tell the user how
to restore the backup (`rm -rf ~/.config/hypr && cp -a ~/.config/hypr.bak.<timestamp> ~/.config/hypr && hyprctl reload`).

Also report the **theme**: which palette/scheme and fonts were chosen, and that they now live in
`~/.config/hypr-rice/palette.conf` as the single source of truth. Tell the user re-theming is one
command (`/hyprland-config:theme-config`, or `rice apply` after editing `palette.conf`) and that
any bar/launcher/terminal they add later (e.g. via `/hyprland-config:desktop-shell`) will pick up
this same palette automatically — so colors stay coherent without re-generating.

**Important — `hyprctl reload` does NOT run `exec-once`.** A reload re-reads settings (monitors,
binds, look-and-feel, window rules) but **does not start the `autostart.conf` programs** — the
bar, wallpaper daemon, notification daemon, polkit agent, trays, etc. only launch on a fresh
Hyprland start (next login). So after a `SAFE_APPLY=ok` the user will see the new look/behavior but
**no bar and no wallpaper this session**, which reads as "nothing happened / broken." Always either:

- **Offer to start the autostart programs now**, e.g. for each chosen tool
  `hyprctl dispatch exec <cmd>` (waybar, hypridle, the wallpaper daemon, etc.) — mirror the
  `exec-once` lines in `autostart.conf`. Skip the wallpaper daemon if its image path is a missing
  placeholder (`hyprpaper` with no `wall.png` shows nothing); point the user at the wallpaper skill.
- **Or tell them explicitly** that the bar/daemons appear on next login and how to trigger them now.

Note in the summary that any `exec-once` daemon not already running won't be visible until then.

## Version-sensitive forms (match the detected version)

The shipped 0.54 default establishes the current conventions; older targets differ. Pick the
right form per `hyprland-reference/references/deprecations.md`:

- **Keybinds:** default to the official scheme (Q=terminal, C=close, R=menu, E=files, V=float,
  M=exit) with `$mainMod`. Toggle split with `layoutmsg, togglesplit`, not a bare dispatcher.
- **Gestures:** `gesture = 3, horizontal, workspace` on 0.45+; `gestures { workspace_swipe }`
  block only on older targets.
- **Window rules:** the `windowrule { match:class = ... }` block form on 0.53+; the single-line
  `windowrule = ...` form on older. Don't mix forms for one rule.
- **Decoration:** include `rounding_power` on 0.5x; omit on older.
- **Permissions:** leave the `ecosystem { enforce_permissions }` / `permission =` block out by
  default (off). Offer it only if the user wants hardening, and note it needs a Hyprland restart
  and explicit `screencopy` allows for grim/portal.

## Safety rules

- Never overwrite `~/.config/hypr` without the timestamped backup having run first.
- Never emit deprecated syntax — cross-check `hyprland-reference/references/deprecations.md`.
- Keep monitor names exactly as the system reports them (`hyprctl monitors`); when the system is
  unavailable, use placeholders and tell the user to adjust them.

## Additional resources

- **`references/interview.md`** — full question bank, options, and recommended defaults per area
  (Areas A–D structural; Area C-theme defers to the shared theme bank below).
- **`skills/theme-config/references/interview.md`** — the shared **palette & font** question bank
  (Area C-theme). Same one `theme-config` uses, so the two never drift.
- **`skills/theme-config/references/engine.md`** — the rice engine wired up in step 4b
  (`palette.conf` source of truth, `colors.conf` render, the `rice` CLI).
- **`skills/theme-config/references/palettes.md`** — named schemes → palette contract hex.
- **`skills/theme-config/scripts/rice-init.sh`** — scaffolds `~/.config/hypr-rice/` (step 4b).
- **`skills/theme-config/scripts/palette-from-wallpaper.sh`** — generates a palette from a wallpaper
  (matugen/wallust) for the wallpaper-source path in step 4b.2.
- **`skills/theme-config/templates/hyprland.tmpl`** — the `colors.conf` template filled in step 4b.3.
- **`skills/theme-config/scripts/detect-theme-tools.sh`** — probes installed fonts/generators for
  the Area C-theme options.
- **`references/templates.md`** — annotated templates for every generated file.
- **`scripts/detect-version.sh`** — prints the installed Hyprland version and probes installed
  ecosystem packages.
- **`scripts/install-config.sh`** — backs up and installs the staged config (lower-level).
- **`scripts/verify-config.sh`** — live-tests the config (`hyprctl reload` + `configerrors`);
  prints `VERIFY=ok|errors|skipped`.
- **`scripts/safe-apply.sh`** — install + verify + auto-rollback; the preferred install path.
- **`examples/`** — a complete reference output (a generated modular config set).

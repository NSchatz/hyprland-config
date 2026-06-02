---
name: Generate Hyprland Config
description: This skill should be used when the user runs "/hyprland-config:generate-config" or asks to "generate a hyprland config", "create my hyprland.conf", "set up Hyprland from scratch", "make me a new Hyprland config", or "build a hyprland config". Runs an interactive interview, generates a modular Hyprland config matching the installed version, backs up any existing config, writes it to ~/.config/hypr, and validates the result.
argument-hint: "[optional notes, e.g. 'dual monitor, vim keybinds']"
allowed-tools: AskUserQuestion, Bash, Read, Write, Glob, Agent
version: 0.1.0
---

# Generate Hyprland Config

Generate a complete, validated Hyprland configuration from scratch by interviewing the user
about their setup, then emit a **modular** config (a main `hyprland.conf` that `source=`s topic
files), back up any existing config, write it to `~/.config/hypr`, and validate it.

Treat `$ARGUMENTS` as freeform hints (monitor count, keybind style, apps). Use them to
pre-fill or skip interview questions, but still confirm anything load-bearing.

This skill leans on the **Hyprland Config Reference** skill for syntax. Read its reference files
(under `skills/hyprland-reference/references/`) whenever generating a section, and cross-check
every option against `deprecations.md` so deprecated syntax is never emitted. For companion apps
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

Gather preferences with the `AskUserQuestion` tool, grouped into the four topic areas. Use the
question bank and recommended defaults in **`references/interview.md`**. Guidance:

- Ask in batches (one `AskUserQuestion` call per topic area, multiple questions per call).
- Offer sensible defaults as the first option so a user can move fast.
- Skip questions already answered by `$ARGUMENTS` or by an existing config (read it first if
  present — see step 3).
- The four areas: **(a) Monitors & input**, **(b) Keybinds & apps**, **(c) Look & feel**,
  **(d) Autostart & env**.

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

- **`references/interview.md`** — full question bank, options, and recommended defaults per area.
- **`references/templates.md`** — annotated templates for every generated file.
- **`scripts/detect-version.sh`** — prints the installed Hyprland version and probes installed
  ecosystem packages.
- **`scripts/install-config.sh`** — backs up and installs the staged config (lower-level).
- **`scripts/verify-config.sh`** — live-tests the config (`hyprctl reload` + `configerrors`);
  prints `VERIFY=ok|errors|skipped`.
- **`scripts/safe-apply.sh`** — install + verify + auto-rollback; the preferred install path.
- **`examples/`** — a complete reference output (a generated modular config set).

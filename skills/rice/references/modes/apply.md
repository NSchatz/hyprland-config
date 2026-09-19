# Mode A, part 2 - put it on the machine

Everything from here writes to the user's home directory. Each step backs up first, and
the apply is reversible before it is performed, never after. Read
[`generate.md`](generate.md) first - this file assumes a validated staging dir.

## Contents

- A4. Establish the palette via the rice engine
- A5. Validate, install, back up, live-test, auto-rollback
- A6. Report (and start the daemons)

---

### A4. Establish the palette via the rice engine

The colors/fonts from the `look-feel` component (palette, fonts, wallpaper sub-questions) live in
`answers.json` under `.palette` / `.fonts` / `.wallpaper`. Read them with `jq`; the engine's
`palette.conf` is the materialized form (key contract in `../_shared/palette-schema.md`). Read
`../theming/engine.md`. Then:

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
   - `.palette.source == "named"` → look up `.palette.scheme` in `../theming/palettes.md`,
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
   `~/.config/hypr` before A5): take `../components/look-feel/hyprland.tmpl`, substitute its `{{accent}}` etc.
   from `palette.conf`, and `Write` the result. Likewise fill any companion-config color placeholders
   **and the staged shell configs' colors files** (`_shell/<app>/colors.css`/`.rasi` etc.) by rendering
   the matching `../components/<component>/*.tmpl` so the bar/launcher/notifications install already themed. If a
   **widget shell** was chosen (`widgets` component), **register its manifest line**
   (`eww`/`ags`/`quickshell` → its colors file) so `rice apply` re-themes it on every switch, and
   render its colors file into the staged shell tree — see `../theming/engine.md` → "Widget-shell
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
   `next-x-hint` column drives the grouping; see `../theming/engine.md` → "Manifest format").

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
body per engine is in `../theming/engine.md` → "Theme-restore on login". On `theming.engine == none`,
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
   script, handles `paru`/`yay` detection (asking before it BUILDS one from source, naming the
   package and the AUR URL), distinguishes transient retries from real failures, and returns a
   structured `INSTALL=ok|partial|failed|declined-aur-build|skipped (non-arch)` verdict + the
   package list + `Record:`, the path of the durable install record. On `partial`/`failed`,
   surface what failed and ask whether to proceed with the config install anyway (some failures
   are non-blocking, e.g. an optional utility); the user can re-run `install.sh` later. On
   `declined-aur-build`, nothing was cloned or built and the AUR picks did not install: that is a
   choice, not a fault, so report it plainly and carry on with what did install. On no, skip ahead
   and surface the `install.sh` path in A6.

   **Relay the record.** Packages are the one thing this whole flow does that a restore cannot
   undo, so the record is what the user is owed: pass the `Record:` path and its id through to A6
   (`rice installs <id>` prints it back). If the agent reports the record as `unwritten`, say so
   in as many words and include the printed transaction in the report: it exists nowhere else.
4. **Safe install (Hyprland):** `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/safe-apply.sh" /tmp/hypr-gen-<id>`
   It **checks the staged config for keys removed at the target version, then preflights it
   offline**, then timestamp-backs up the **entire**
   `~/.config/hypr`, installs, then `hyprctl reload` + `configerrors` + "is the file I wrote the
   one you loaded", and **auto-rolls-back** if the new config fails. Read the final `SAFE_APPLY=`
   line: `ok` (installed, clean, and the compositor confirms it is what it loaded),
   `rolled-back` (errors shown; restored, so fix + retry),
   `installed-untested` (no running Hyprland; test next login), `refused` (install-config.sh
   declined and changed **nothing**: read the `REFUSED=`/`SHADOWED_BY=` lines above it),
   `removed-keys-failed`/`preflight-failed`/`preflight-uncheckable`/`unconfirmed` (below),
   `install-failed`/`errors-no-backup` (surface + stop). Relay the `BACKUP=` and
   `CONFIG_LANGUAGE=` lines. Respect a `HYPR_DIR` override. (`install-config.sh` /
   `verify-config.sh` / `preflight-config.sh` exist for running a step alone, see
   `hyprland-reference/references/testing.md`.)
   - **`SAFE_APPLY=removed-keys-failed`**: the staged config sets a key that
     `../_shared/version-matrix.md` records as REMOVED at or before the target version,
     where it is a hard parse error. This runs FIRST, before the compositor is consulted at all,
     so nothing was checked by Hyprland, nothing was backed up and nothing was written;
     `~/.config/hypr` is byte-identical. Each `REMOVED_KEY=` line above names the key, the staged
     file and line, and the release that removed it - open those paths, drop or rename the key
     (the line names the replacement), re-run. This check needs no compositor, so it is the one
     that still answers on a host where `PREFLIGHT=unverified`. A `REMOVED_KEYS=unknown-target-version`
     line is **not** a refusal: the target version could not be read, so no verdict was reached
     and the apply carried on to the checks that do not need one. Say "not checked for removed
     keys", never "checked and clean".
   - **`SAFE_APPLY=preflight-failed`**: the compositor's own offline check
     (`Hyprland --verify-config`) parsed the **staged** files and found errors, so the apply
     stopped before any backup and any write. `~/.config/hypr` is byte-identical; there is
     nothing to roll back and nothing to restore. The `PREFLIGHT_ERROR=` lines above name the
     staged file and line number, so open those paths, fix the generated config, re-run. This is
     the outcome to *want*: a refusal costs the user nothing, where the old order made every
     failure start from an already-overwritten desktop.
   - **`SAFE_APPLY=preflight-uncheckable`**: the offline check could not be *run* at all, so
     nothing was checked and nothing was installed. Read `PREFLIGHT_REASON=`:
     `no-main-config` / `ambiguous-staging` (the staging dir has no `hyprland.conf`/`hyprland.lua`,
     or has both, so regenerate it), `staged-main-unreadable` (fix the permissions on the staged
     file), `invocation-rejected` (the compositor refused the invocation before parsing anything,
     which is a *bug in this plugin or a Hyprland CLI change*, not a problem with the user's
     config; report it with the stderr lines above). Never read this as "the config is bad".
   - **`PREFLIGHT=unverified`** is not an outcome, it is a note: this host has no Hyprland
     binary offering `--verify-config`, so nothing was proven either way and the apply carried
     on to the install / live-test / rollback path exactly as it always did. Say "not
     pre-checked", never "checked and clean".
   - **`SAFE_APPLY=unconfirmed`**: the config installed cleanly and `hyprctl configerrors` is
     empty, but the running compositor did **not** confirm it loaded the file that was just
     written. The `LOADED_CONFIG=` line names what it *did* load. An empty error list is also
     exactly what a config that was never parsed produces, so this is not reported as success.
     Nothing is rolled back, because the config on disk is fine, it is just not what is running.
     The usual cause is a `~/.config/hypr/hyprland.lua` shadowing the `.conf` (see
     `REFUSED=lua-config-takes-precedence` below for the remedies), or a session started with
     `Hyprland -c <somewhere else>`. If `LOADED_CONFIG=unknown`, the compositor simply never
     named its config, so the change may well be live: say so, and have the user check visually
     or log out and back in.
   - **`REFUSED=lua-config-takes-precedence`** means `~/.config/hypr/hyprland.lua` is already
     there (the default on 0.56+, which autogenerates one), so a hyprlang `.conf` would be
     installed and then ignored. **This interview generates hyprlang only**: the component
     templates under `../components/` are `.conf`, and `HYPR_CONFIG_LANG` is read by
     `config-language.sh`/`emit-config.sh`/`reset-config.sh`, *not* by A3. So do not offer
     "regenerate the rice in lua"; it is not a thing this skill can do yet. Do not delete the
     user's lua file either. Offer, in this order: (a) convert an existing `.conf` set with
     `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/migrate-config.sh"`, an offer that
     changes nothing, where `--convert` accepts it, keeps every `.conf` as a backup, and names any
     line it could not map (`NOT_APPLIED=`, `MIGRATE=ok-with-unmapped`); (b) ask the user to
     move `hyprland.lua` aside themselves and re-run; (c) a bare lua baseline via
     `HYPR_CONFIG_LANG=lua bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/reset-config.sh"`,
     which is a minimal config, not this rice.
   - **`REFUSED=mixed-staging`** means the staging dir holds files in both config languages;
     only one set would be installed. Stage exactly one language and re-run.
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
     four GTK gotchas under Mode B and `../theming/gtk-qt.md`.
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

**Say what a restore does NOT take back, and where the account of it is.** Two things outlive the
apply, and both have their own surface:

- **The packages.** Report the install record: `rice installs` lists every transaction newest
  first and `rice installs <id>` prints one in full: every package installed, every one already
  present, every one that failed with its reason, and any AUR helper built from source with the
  URL it came from. It stays on the machine. Nothing here uninstalls anything: removing software
  the user may now depend on is their decision, and the record is what makes it an informed one.
- **The Firefox preferences**, if the browser theming ran. `firefox-bootstrap.sh` merged
  `toolkit.legacyUserProfileCustomizations.stylesheets` and `browser.startup.page` into
  `<profile>/user.js` (it prints `FIREFOX_PREF_SET=<key>` for each one it actually added).
  Firefox re-applies those at every start and does not show them as changed in its own UI, so a
  restore cannot undo them. Tell the user the way back: `rice prefs` shows what was set and
  where, `rice prefs remove` takes exactly those lines off (backing the file up first, leaving
  every other line byte-identical, and leaving alone any line they have changed by hand). Say the
  consequence too: without
  `toolkit.legacyUserProfileCustomizations.stylesheets` the browser theming stops working
  entirely. Details in `../components/browser/template.md`.

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
`../components/env/gotchas.md` and `../components/look-feel/gotchas.md`).

---

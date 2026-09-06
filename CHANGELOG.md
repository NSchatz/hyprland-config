# Changelog

## Unreleased

Say what was put on the machine, and what a restore cannot take back (roadmap phase INSTALL-7).

A user who let this plugin install packages and theme their browser had no way, afterwards, to
find out what landed. The installer agent returned counts in a verdict line that lived only in a
chat transcript, and the two Firefox preferences merged into `<profile>/user.js` are re-applied by
the browser at every start and hidden from its own UI, so a config restore does not undo them and
nothing said how to.

- **`scripts/install-record.sh`** (new) persists one transaction per install under
  `<state>/hypr-rice/installs` (`$XDG_STATE_HOME`, else `~/.local/state` - the same state root
  restore points already use, now `rp_state_root` so it is decided once). Each record names every
  package installed, every one already present, every one that failed **with the one-line reason
  the install reported**, and any AUR helper built from source with the URL it was cloned from.
  `rice installs` lists them newest first, `rice installs <id>` prints one in full - no knowing
  where they are stored required. If the record cannot be written, the failure is reported by
  path, the whole transaction is still printed, and the install is **not** reported as recorded.
  An install where nothing was installed, skipped or failed leaves no record: nothing invents a
  history.
- **`scripts/install-packages.sh`** (new) is now the ONE implementation of repo-vs-AUR routing,
  the AUR-helper bootstrap, the non-Arch skip and the recording. The generated `install.sh` and
  the installer agent's ad-hoc list both call it, so both leave the same record in the same place
  and the same form - a record only one route writes is a record a user cannot rely on. It
  refuses to install at all when it cannot find the record component.
- **The AUR-helper build now discloses before it builds.** It names the package (`paru`), says it
  will be built **from source on this machine**, shows `https://aur.archlinux.org/paru.git`, and
  requires an explicit yes - an unanswered prompt is a decline. A decline clones nothing, builds
  nothing, installs no AUR package, and reports `INSTALL=declined-aur-build`, which is its own
  outcome and not a failed build.
- **`scripts/firefox-prefs.sh`** (new) records which preferences the profile bootstrap actually
  merged, against that profile's absolute path - never a key that was already there and left at
  the user's value - and ships the way back: `rice prefs` / `rice prefs remove`. The removal backs
  the file up before editing it (enrolled in a restore point, so the removal itself goes back with
  `rice restore <apply-id>`), removes **only** the recorded lines leaving every other line
  byte-identical, leaves a line changed by hand alone and reports it rather than deleting the
  user's value, reports a profile file that is gone by path without creating it or abandoning the
  other profiles, and on a second run says there is nothing left to remove. Removing
  `toolkit.legacyUserProfileCustomizations.stylesheets` turns the browser theming off entirely,
  which is why this is a command you run rather than something that happens to you - documented in
  `references/components/browser/template.md` and the README.
- `firefox-bootstrap.sh` refuses to merge a preference it cannot record, the same fail-safe it
  already applies to a file it cannot back up.
- **Regression guards for behaviour that already held**, asserted so it cannot go quietly:
  `tests/test_firefox_profile_backup.sh` (every profile file backed up before it is replaced,
  including a `userChrome.css` this plugin wrote before; a file that cannot be backed up is not
  written and the skip names the path) and `tests/test_install_no_pacman.sh` (no pacman means the
  list is printed, no package manager or helper is invoked at all, and the outcome reads as
  skipped rather than failed). Neither changes behaviour.
- Nothing here uninstalls anything. Removing software a user may now depend on is their decision;
  the record is what makes it an informed one.

Write where the platform says the config lives (roadmap phase XDG-6).

Hyprland reads `$XDG_CONFIG_HOME/hypr/hyprland.lua`; `~/.config/hypr` is only the common case.
Every script here resolved `$HOME/.config` unconditionally, so a user who had moved
`XDG_CONFIG_HOME` was told their desktop was configured while nothing about their desktop
changed - the plugin had backed up, installed, live-tested and reported success against a
directory the compositor never reads.

- **`scripts/xdg-config.sh`** (new) is the one place this plugin decides where configuration
  lives: an explicit override (`HYPR_DIR`, `RICE_DIR`) wins outright, else `$XDG_CONFIG_HOME`
  when it is an **absolute** path, else `$HOME/.config`, else it refuses and writes nothing. A
  *relative* `XDG_CONFIG_HOME` is invalid rather than merely unusual (the XDG base directory
  specification says an implementation "should consider the path invalid and ignore it"), so it
  is ignored - and the fallback is announced with `XDG_CONFIG_HOME_IGNORED=` plus the absolute
  path actually used, never taken in silence.
- It is one decision on purpose. `install-config.sh`, `backup-config.sh`, `safe-apply.sh`,
  `reset-config.sh` and `migrate-config.sh` each used to resolve their own target; five
  resolutions is how a backup gets taken from directory A while the reset wipes directory B,
  and that wipe has no inverse. They now share one answer, and `tests/test_xdg_config_home.sh`
  fails the build if any shipped script starts spelling `$HOME/.config` for itself again.
- The **themed** surfaces follow too, not just `hypr`: the rice state directory
  (`rice-init.sh`, `render-templates.sh`, `set-wallpaper.sh`, `palette-from-wallpaper.sh`, the
  `rice` CLI) and a render manifest row whose output column reads `~/.config/<app>/...`. The
  **cache** destination is untouched - `~/.cache/hypr-rice/lock-blur.png` is `XDG_CACHE_HOME`'s
  base directory, a separate variable with a separate default, and this change is the config
  one only.
- **Reporting**: `backup-config.sh` now prints `TARGET=<dir>` (it printed only `BACKUP=`), and
  `reset-config.sh` prints it on its refusal paths as well as its write path, so every script
  that reports a write also says where. `safe-apply.sh`'s parse of `install-config.sh`'s
  `TARGET=` line is unchanged.
- **Fail-safes** on the way: `reset-config.sh` proves the resolved directory is writable
  *before* it wipes anything (`RESET=refused-target-not-writable`), and `backup-config.sh`
  reports a failed copy against the resolved path instead of dying with a bare `cp` error.
  Neither ever falls back to another directory.

Prove the config parses before writing a byte of it (roadmap phase PREFLIGHT-5).

`safe-apply.sh` installed first and tested second, so every failure path started from a machine
whose desktop had already been overwritten and depended on a rollback working. And `VERIFY=ok`
came from one fact, `hyprctl configerrors` printing nothing, which is also exactly what a config
that was never parsed produces. Both are closed here.

- **`scripts/preflight-config.sh`** (new) runs the compositor's own offline check
  (`Hyprland --verify-config`) against the **staged** files, before any backup and any write. The
  staged set is copied into a throwaway sandbox whose `HOME` is the sandbox, so the
  `source = ~/.config/hypr/<file>` lines a generated config carries resolve to the staged
  companions and not to whatever is already installed: the verdict is about the files you are
  about to install and nothing else. Errors are surfaced against the staged paths, so the file in
  the message is a file you can open. Prints
  `PREFLIGHT=ok|errors|unverified|uncheckable`.
  `unverified` (no binary offering the check on this host) is deliberately **not** `ok`; and
  `uncheckable` is deliberately **not** `errors`, because `Hyprland --verify-config` exits 1 both
  for "your config is broken" and for "you invoked me wrong", and confusing the two would turn a
  packaging change into a refusal that blames the user's config.
- **`scripts/safe-apply.sh`** runs that preflight first and refuses on it, with
  `SAFE_APPLY=preflight-failed` / `SAFE_APPLY=preflight-uncheckable` and a target directory that
  is byte-identical afterwards: no backup taken, nothing written, nothing to restore. The
  existing install / live-test / rollback path stays exactly as it was behind it, as the second
  net, and keeps every one of its outcome words.
- **`scripts/loaded-config.sh`** (new) asks the running compositor which config file it actually
  loaded. `hyprctl` has no command for it, but Hyprland logs `Using config: <path>` for every file
  it reads and re-logs them on each reload, so `hyprctl rollinglog` (or the instance log) names
  them. Prints `LOADED_CONFIG=<path>`, or `LOADED_CONFIG=unknown` rather than a guess.
- **`scripts/verify-config.sh`** gains `--expect <file>`: with it, `VERIFY=ok` means the
  compositor confirmed it loaded that file, and a mismatch or a non-answer is the new
  `VERIFY=unconfirmed` (which names what *was* loaded). `safe-apply.sh` always passes it, so
  `SAFE_APPLY=ok` is now a claim the compositor backed rather than a silence. A mismatch reports
  `SAFE_APPLY=unconfirmed` and does **not** roll back, because the config is not what is broken. Called
  without `--expect`, the script behaves exactly as it always did.
- **CI** re-derives the `--verify-config` contract against the real binary on every integration
  run and adds a **negative control**: a deliberately broken generated config is put through the
  offline check inside the container, and the build fails if it is reported clean. The measured
  contract (exit codes, the parsing-result marker that separates a broken config from a rejected
  invocation, `~`-expands-from-`$HOME`, the lua form, and the fact that the check completes with
  no session and no `/dev/dri`) is written down in `tests/integration/offline-check-contract.md`,
  which answers the roadmap phase's open question.

Emit the config language the machine actually loads (roadmap phase LUA-4).

Since Hyprland 0.55 hyprlang is deprecated in favour of lua, and a `hyprland.lua` in the config
dir is loaded **instead of** `hyprland.conf`. Since 0.56.0 a freshly installed Hyprland
autogenerates one into that very directory. The plugin emitted hyprlang `.conf` and only hyprlang
`.conf`, so on a current machine it could print a clean `SAFE_APPLY=ok` for a change the
compositor never read. This release closes that.

- **`scripts/config-language.sh`** (new) resolves the config language from the detected version
  (0.55 or higher is lua, below is hyprlang) and reports the Hyprland range that language is valid
  for. On an undetectable version it does **not** assume: it prints
  `EMITTABLE_LANGUAGES=lua hyprlang` with each option's range and exits non-zero until an explicit
  `HYPR_CONFIG_LANG=lua|hyprlang` is supplied. `detect-version.sh` no longer tells the reader to
  "assume latest stable syntax".
- **`scripts/emit-config.sh`** (new) is the emitter pair: a lua writer beside the hyprlang one,
  selected by that resolution. Every generated config now carries a
  `CONFIG_LANGUAGE=` / `CONFIG_LANGUAGE_RANGE=` header, so a user reading the file on their own
  machine can tell what it is and what it is good for. `reset-config.sh` generates through it, and
  generates **before** the wipe, so a run that cannot pick a language leaves the config untouched.
- **`scripts/install-config.sh`** refuses to install a hyprlang `.conf` into a directory that
  already holds a `hyprland.lua`, naming the file and saying that the lua config takes precedence
  (`REFUSED=lua-config-takes-precedence`). It also refuses, before taking any backup, when the
  target exists but cannot be written to, and it installs `*.lua` sets as well as `*.conf` ones.
  A staging dir that mixes the two languages is refused (`REFUSED=mixed-staging`) rather than
  half-installed, a `hyprland.lua` that is a **dangling symlink** trips the shadow guard just like
  a real one, and a staged config that carries no `CONFIG_LANGUAGE=` header of its own gets one
  added on install (`PROVENANCE=`). `safe-apply.sh` surfaces the refusals as `SAFE_APPLY=refused`,
  never as ok.
- **`scripts/migrate-config.sh`** (new) offers to convert an existing `.conf` set to lua, including
  the modular `source = ~/.config/hypr/*.conf` set the rice interview generates, resolved against
  `HYPR_DIR`. The bare invocation is the offer and changes nothing; `--convert` accepts it. Every
  `.conf` is kept, never deleted, and a verified readable copy is written beside it. It refuses,
  changing nothing, when a `hyprland.lua` is already there, when a `.conf` does not parse
  (`MIGRATE=refused-unparseable`), when a `source =` cannot be resolved to a concrete file inside
  the config dir (`MIGRATE=refused-unresolvable-source`), and when the backup step does not produce
  a readable copy. A construct that parses but has **no documented lua mapping** (`bezier`,
  `animation`, `gesture`) is not a refusal: it is carried across as a `-- NOT APPLIED` comment at
  its original position, counted in the file's header, reported line by line
  (`NOT_APPLIED=`/`MIGRATE=ok-with-unmapped`), and left intact in the kept `.conf`. Nothing is
  dropped in silence, and a config this plugin wrote is never called unparseable.
- **The stated hyprlang support window is now the published one.** Five places claimed `.conf`
  "remains functional for several releases"; upstream says **1 - 2 releases starting from 0.55**,
  after which hyprlang is dropped. The version matrix no longer says the rice still emits `.conf`
  on 0.55+, because it does not.
- **Tests:** `tests/test_lua_emit.sh`, `tests/test_lua_install.sh`, `tests/test_lua_migrate.sh`
  (`bash tests/run.sh lua`), plus `tests/test_regress_0018_F1/F2/F3.sh`
  (`bash tests/run.sh regress_0018`), which pin the three holes the implementation review found.

## 0.22.0

Restore points. Everything the rice writes on a machine **outside** `~/.config/hypr` can now be
put back the way it was, as one set, with one command, by someone who never read the code.
`~/.config/hypr` itself is untouched by this release: it keeps its own separate backup,
live-test and auto-rollback, and the new restore command never reads, calls, wraps or touches it.

### One restore point per apply

- **`scripts/restore-point.sh`** (new) is the backup-before-write mechanism and the ledger over
  it. Every apply has an id (`RICE_APPLY_ID`, a `YYYYmmdd-HHMMSS` stamp); before any surface is
  written its existing content is copied to `<path>.bak.<apply-id>` and the path is appended to
  `${XDG_STATE_HOME:-~/.local/state}/hypr-rice/restore/<apply-id>/entries.tsv`. A path that did
  not exist is recorded as `new`, so restoring removes the file the apply created instead of
  orphaning it.
- **One id spans every stage of one apply**: the render pass, the Firefox profile bootstrap and
  any `backup-path.sh` call for a shell rc file all enrol in the same point when the caller
  exports `RICE_APPLY_ID` (the rice skill now does, in A4 step 0). Entries are written *before*
  the write they protect, so an apply killed partway through still leaves a restore point
  covering everything already written by every stage.

### The undo

- **`scripts/rice-restore.sh`** (new) + **`rice restore <apply-id>`** / **`rice restore --list`**
  put every file that apply wrote back the way it was: overwritten files copied back,
  created files removed. The point is cleared on a fully successful restore, so a second run
  reports `RESTORE=nothing-to-restore` rather than restoring again; the `.bak.<apply-id>` copies
  stay on disk.
- **Per-file resilient.** A missing or unreadable backup, or a target that cannot be written, is
  reported by path (`RESTORE_FAILED …`) while every other file in the point is still restored,
  and the point is kept so a re-run finishes the job. Re-running after an interrupted restore is
  always safe: files already put back are skipped, not restored twice.
- **Overlapping paths in one point are correct in both orders.** An apply routinely enrols a whole
  directory (`backup-path.sh ~/.config/waybar`) *and* files the render pass writes inside it. A
  path enrolled while a surface around it is already in the point folds into that surface
  (`covered` in the ledger) rather than taking a second `.bak` copy inside the directory a restore
  replaces wholesale; in the other order the restore replays containers before their contents, so
  the nested entries have the last word. Either way `rice restore` returns the prior state and
  never the apply's own output, and a nested file put back by an earlier partial attempt is
  replayed - not skipped - when a later attempt replaces the directory around it.
- **Containment respects the boundary in both directions.** `~/.config/hypr` is not only never
  enrolled itself: a path that *contains* it (`backup-path.sh ~/.config`) is refused enrolment
  too, because a directory is put back wholesale and restoring an ancestor would revert that
  directory along with it. Such a path is still copied exactly as `backup-path.sh` always has -
  a copy touches nothing - and reported as `NOT_ENROLLED <path>`: yours to put back by hand, not
  `rice restore`'s. A ledger hand-edited to hold such a path is refused by the restore command
  and reported by path rather than acted on.

### Fail-safe writes

- **A surface whose backup cannot be written is not rendered.** `render-templates.sh` prints
  `RENDER_SKIPPED <name> -> <output> (<why>)` and carries on with the rest of the manifest.
  That includes a brand-new output with nothing to overwrite: if the "this apply created it"
  record cannot be persisted, the file is not created, because nothing could ever take it back.
- **`scripts/backup-path.sh`** now exits non-zero and prints `BACKUP <path> -> FAILED (<why>)`
  for any path it could not back up, and ends with `RESTORE_POINT=<apply-id>`. The edit-config
  skill relays that id as the undo line for a shell-rc or desktop-shell edit.
- **`firefox-bootstrap.sh`** backs up `userChrome.css` and `user.js` through the same mechanism
  under the apply's id (replacing its own ad-hoc `.bak.<epoch>` copy), and skips a profile file
  it could not back up. A `chrome/` directory it *creates* is enrolled too, so a restore takes it
  away again instead of leaving an empty orphan in the profile.
- **A write that failed is reported as failed.** `render-templates.sh` prints
  `RENDER_FAILED <name> -> <output> (<why>)` when the backup succeeded but the output could not be
  written, instead of claiming `RENDERED` for a file that is not there.
- **The pre-baked lock-screen blur** (`~/.cache/hypr-rice/lock-blur.png`) is enrolled like any
  other surface the render pass writes, so a restore puts the previous one back or removes the
  one the apply created.

### Tests

`tests/test_restore_point.sh`, `tests/test_restore_command.sh`,
`tests/test_restore_interrupt.sh` and `tests/test_restore_overlap.sh` (136 assertions): a render
over known-content files backed up under one shared id and restored byte-identical; applies killed
mid-manifest, between stages, mid-browser-theming and mid-shell-rc; an unwritable backup
destination; a damaged backup; an unwritable restore target; a restore run twice; a restore killed
partway and re-invoked; a restore point holding a directory and a file inside it, in both
enrolment orders, plus the partial-then-retry variant and the created-nested-file variant in both
orders - including the one where the directory's backup was taken after the apply created that
file, so only the container-first replay can still take it away again; a path that
contains `~/.config/hypr`, which no restore here may put back; and the boundary itself, i.e. that
no code path or test here reads, calls or wraps `~/.config/hypr`'s own restore.

## 0.21.0

The browser-theming release deferred from v0.20.0. Closes the last two of the 16 v0.19.0
shakedown defects (Issues 14 + 15.1/15.2/15.3): Firefox chrome theming opt-in via a new
`components/browser/` tree, profile bootstrap that resolves the dynamic profile dir, a
restart hook that re-themes the running browser with session restore, and a
`rice apply` footer for surfaces that can't hot-reload.

### Issue 14 — Firefox chrome theming (userChrome route)

New `components/browser/` opt-in component. Master gate: `default_apps.browser ==
"firefox"` AND `browser_theming.opt_in == true`. Off by default — most users haven't asked
for browser theming; the small minority who care about a coherently themed browser opt in.
Two routes documented; one (userChrome) is fully wired.

- **`components/browser/firefox.tmpl`** — engine-rendered palette-only `:root{--rice-*}`
  block (12 CSS custom properties from `palette.conf`) → `<profile>/chrome/rice-colors.css`.
  Re-rendered on every `rice apply`.
- **`components/browser/userChrome.css`** — palette-agnostic static mapping of `--rice-*`
  onto Firefox chrome via the `lwt-*` lightweight-theme custom properties + direct
  selectors (tab bar, URL bar, nav bar, menus, sidebar). Copied once into the profile via
  the bootstrap script; `@import "rice-colors.css"` makes re-themes pick up automatically.
- **`components/browser/user.js`** — locks two prefs in the profile, re-applied on every
  startup: `toolkit.legacyUserProfileCustomizations.stylesheets = true` (without it the
  userChrome.css is dead — Firefox stopped processing it by default years ago) and
  `browser.startup.page = 3` (session restore — the restart hook would lose tabs
  otherwise).
- **`gotchas.md`** + **`packages.md`** + **`schema.md`** + **`interview.md`** +
  **`validation.md`** + **`README.md`** flesh out the component (the four big traps:
  dead-without-the-pref, dynamic profile dirs, restart-flash, pywalfox vs userChrome
  mixing).

The **pywalfox** route (wallpaper-engine + content theming) is documented in `gotchas.md`
but not auto-wired — it needs the AUR package + the in-browser add-on, both manual. Pick
it when the rice uses a wallpaper-driven engine and content theming matters; pick
userChrome otherwise.

Chromium / Brave / Zen / LibreWolf are out of scope for v0.21 (Chromium/Brave have no
userChrome equivalent; Zen + LibreWolf inherit the mechanism but ship selectors this
template doesn't cover — documented as follow-ups).

### Issue 15.1 — `firefox-bootstrap.sh`

New `assets/scripts/firefox-bootstrap.sh`. Resolves the default Firefox profile by parsing
`~/.mozilla/firefox/profiles.ini` (the profile dir prefix is random —
`xxxxxxxx.default-release`; hardcoding it breaks ESR / Developer Edition). If no
`profiles.ini` exists, runs `firefox --headless --no-remote --CreateProfile default-release`
to create one. Copies `userChrome.css` + `user.js` into `<profile>/chrome/` idempotently
— appends `@import "rice-colors.css"` to an existing userChrome.css rather than
clobbering it; merges user.js prefs by key. Emits
`FIREFOX_PROFILE=` / `FIREFOX_CHROME=` / `FIREFOX_RICE_COLORS=` on stdout so `install.sh`
can substitute the resolved path into the firefox manifest line.

### Issue 15.2 — `firefox-restart.sh`

New `assets/scripts/firefox-restart.sh` — the manifest's reload-cmd. No-op if Firefox
isn't running; otherwise `pkill -x firefox`, poll for the profile-lock release (up to
~5s), relaunch detached with `setsid` + `disown`. ~1s blank-window flash; session restore
brings every non-private tab back. If `browser_theming.restart_hook == false` the
manifest's reload-cmd is empty instead and Firefox goes in the "applies on next launch"
footer below.

### Issue 15.3 — `templates.list` 5th column + needs-relaunch footer

`render-templates.sh` learns an optional 5th column on manifest lines: the `next-X` hint
that classifies surfaces whose effect lands on the next launch / lock / server restart,
not on the current `rice apply`. Known values: `next-launch`, `next-lock`,
`server-restart`, `restart`. Empty 5th column is allowed for surfaces that pick up via
file-watch (eww, ags, wofi, rofi, gtk4 — their existing lines unchanged) — only surfaces
that need an external trigger declare the hint.

After every render pass, the script prints one grouped footer per hint value:

```
$ rice apply
RENDERED qt6ct -> ~/.config/qt6ct/colors/rice.conf
RENDERED gtk3  -> ~/.config/gtk-3.0/gtk.css
RENDERED hyprlock -> ~/.config/hypr/hyprlock.conf
RENDERED swayosd -> ~/.config/swayosd/style.css
2 surfaces apply on next launch: qt6ct, gtk3
1 surface applies on next lock: hyprlock
1 surface applies on server restart: swayosd
RENDER=done
```

Closes the "switch looks half-applied" gap the v0.20.0 Issue-10/11/12/13 surfaces all hit
— `rice apply` now tells the user exactly what won't re-paint until the next trigger
event.

`theming/engine.md` "Manifest format" section rewritten with the 5-column schema + the
footer example. `SKILL.md` A4.3 matrix gets a `next-X` column showing which hint each
themable surface declares. `agents/hyprland-config-validator.md` gains a lint that WARNs
(not ERRORs — the engine still works without the hint) when a manifest line with empty
reload-cmd ships no 5th column.

### Wiring

- **`SKILL.md` A4.3** — matrix updated with the firefox row (gated on
  `browser_theming.opt_in == true`) AND the new `next-X` column. Documents the
  install.sh integration recipe: run `firefox-bootstrap.sh`, capture
  `FIREFOX_RICE_COLORS=`, substitute into the manifest line.
- **`agents/hyprland-config-validator.md`** — firefox row in render-manifest-completeness
  matrix; lint for next-X-hint coverage.
- **`theming/apps.md`** — firefox row added.
- **`default-apps/template.md`** — the "Firefox is not auto-themed (out of scope for
  v0.13)" note replaced with a pointer to `components/browser/`.
- **`rice-init.sh`** — copies `firefox-bootstrap.sh` + `firefox-restart.sh` +
  the static `userChrome.css` + `user.js` into `~/.config/hypr-rice/` so a user opting
  in post-install doesn't need to re-init.

### Version bumps

- **`SKILL.md`**, **`.claude-plugin/plugin.json`**, **`.claude-plugin/marketplace.json`**:
  bumped to `0.21.0`.

## 0.20.0

Second end-to-end production-shakedown release. A two-session full rice run against v0.19.0
on Arch + Hyprland 0.55.x surfaced 16 defects: nine functional (Part I — kitty rejects
trailing comments, wallpaper picks evaporate, lock screen / autostart carry literal paths
that don't track theme switches, waybar pill shadows render as boxy halos, dividers float
at the first child when mpris collapses, eww silently sits on stale colors and refuses to
open the music window) and six theming-coverage (Part II — hyprlock widget colors / Qt
apps / swayosd / GTK3 apps were installed and routed but never re-themed; the validator
had no check closing the loop). v0.20 closes 14 of the 16 (Issues 14-15 — browser theming
+ next-launch reporting — defer to v0.21.0 because the browser component is real new scope).

### Part I — functional defects (9 fixes)

- **#1 — kitty: trailing inline comments stripped.** kitty's parser has no value-line
  comment-stripping, so `background_blur 1  # pair with Hyprland decoration blur` is read
  as `background_blur = "1 # pair with Hyprland decoration blur"` and silently disabled
  on every launch. The template (`terminal/template.md` kitty block + `terminal/styling.md`
  recipe) now puts every explanatory comment on its own line above the setting; foot.ini
  and ghostty (same comment-strict parsers) got the same treatment. New
  `terminal/validation.md` ships a hard-fail lint (regex for `<key> <value> ... # comment`)
  plus a `kitty +runpy load_config` full parse when kitty is available.

- **#2 — `rice wallpaper <img> --no-theme` lost the choice.** The branch short-circuited
  before `wallpaper=` was written to `palette.conf`, so the next `rice apply` / `rice
  theme` / `rice save` evaporated the pick. Now persisted unconditionally before the
  --no-theme check — setting a wallpaper is the source of truth, theme regen or not.

- **#3 — current-wallpaper symlink as the single live pointer.** Reboot used to snap
  back to the generation-time image and the lock screen always painted that one wallpaper,
  because autostart.conf / hyprpaper.conf / hyprlock.conf carried literal paths. Now
  `scripts/set-wallpaper.sh` maintains `~/.config/hypr-rice/current-wallpaper` as a
  symlink to the active image on every successful pick (swww/awww, hyprpaper, swaybg).
  The three consumers reference the symlink; re-theme changes one link, everyone follows.
  New `_shared/wallpaper-pointer.md` documents the consumer list + the generation-time
  invariant the validator (#16) enforces.

- **#4 — preset profiles carry a wallpaper.** Each of the 12 shipped profiles under
  `assets/profiles/` now has a `wallpaper=<scheme>:<name>` catalog selector line. `rice
  theme <name>` recognizes the selector, resolves through `rice get-wallpaper` on first
  use (downloads to ~/Pictures/wallpapers/), rewrites palette.conf with the local path,
  and paints. No bundled images. Pairings cover the highest-width entry per scheme.

- **#5 — wallpaper catalog width metadata.** `assets/wallpapers.tsv` gains a `width`
  column. Rows reordered to descending-width per scheme so `rice get-wallpaper <scheme>
  1` resolves to the highest-resolution image. `--min-res W` filters by minimum pixel
  width. Three explicit overrides documented inline: catppuccin-latte promotes
  cloudy-day above clear-day (Clearday.jpg is 1080p), nord promotes lighthouse above
  abstract-nord, solarized adopts dharmx/walls minimal-mountains-stars as its first-pick
  because the native set tops out at 1080p.

- **#6 — waybar heavy box-shadow default rendered boxy.** The floating-islands archetype
  shipped a multi-layer `0 6px 24px rgba(0,0,0,0.40), 0 1px 3px rgba(0,0,0,0.30)` on
  every group pill. Cairo's blur falls back to a hard-edged bounding-box stamp on small
  rounded translucent surfaces — users saw a rectangular halo, not a soft shadow.
  Default dropped (the universal `box-shadow: none` from `*` takes over); an opt-in
  single-layer `0 1px 2px rgba(0,0,0,0.20)` block documents the soft-lift alternative.

- **#7 — waybar divider on first child.** Separator dividers between stat modules now
  use `:not(:first-child)` semantics, not an enumerated per-module list. mpris is the
  canonical leader in the stats group and disappears when nothing's playing; pulseaudio
  then becomes first and an enumerated `#pulseaudio { border-left: ... }` recipe leaves
  a stray vertical line floating at the group edge. The new `waybar/template.md` →
  "Module dividers" section gives the canonical block + enumerates the frequently-empty
  leading modules (mpris, tray, idle_inhibitor, custom/*).

- **#8 — eww `RELOAD_SKIPPED` + music window won't open.** Two sub-defects: the
  manifest's `eww reload` non-zero-exits when the daemon isn't running and the
  re-themed colors.scss sat on disk; and `(deflisten playing "playerctl status -F")`
  feeds an uninitialized var into `:visible`, eww refuses to open the music window
  with a bool parse error. Switch the manifest reload to `pgrep -x eww >/dev/null &&
  eww reload || true` (no-op when not running, reload when it is). Document the two
  bool-safe-default idioms in `widgets/gotchas.md` — `:initial "false"` on the
  declaration, `(playing ?: "false")` at the use site — and ship a `widgets/
  validation.md` step that greps every unprotected boolean binding AND dry-run-opens
  each defwindow against the staged config.

- **#9 — profiles are palette-only — documented.** `rice save <name>` snapshots only
  `palette.conf`; structural look (looknfeel.conf, waybar style.css, hyprlock layout)
  doesn't travel. `rice` help text and `theming/engine.md` now state this clearly and
  point at the dotfiles skill for whole-tree snapshots.

### Part II — theming-coverage / doc-vs-generation parity (5 fixes — #14, #15 deferred)

The Part-II issues shared a structural root: the docs already described correct behavior
and the generator emitted the routing half (env vars, autostart, packages), but the
config half (themed artifact + manifest entry) was missing. Issue 16 (do-it-first) closes
the loop with a validator assertion.

- **#16 — validator manifest-completeness assertion.** `agents/hyprland-config-validator.md`
  gains a semantic lint: given `answers.json` AND the generated `templates.list`, every
  selected themable surface must have a manifest line, AND the referenced `.tmpl` +
  output directory must exist. ERROR on a miss (not warn — this is silent-failure
  territory). Matrix covers hyprlock, qt6ct, swayosd, gtk3, firefox (v0.21.0+). The same
  matrix lives in `SKILL.md` A4.3 as a generation requirement, so the component-writer
  emits what the validator asserts. A second lint ERRORs on any literal wallpaper path
  in autostart.conf / hyprpaper.conf / hyprlock.conf — the only acceptable wallpaper
  reference is the `current-wallpaper` symlink (per #3).

- **#10 — hyprlock template + manifest entry.** New
  `components/lock-screen/hyprlock.tmpl` (5-color literal-hex render: accent / surface
  / fg / green / red, plus `{{font_ui_family}}`; background references the Issue-3
  symlink). The required `hyprlock <TAB> … <TAB> :` manifest line (empty reload =
  applies on next lock) is documented + asserted.

- **#11 — qt6ct + Fusion + custom_palette.** New `components/qt/` directory with
  `qt6ct.tmpl` (21 QPalette roles × {active, inactive, disabled}, `#AARRGGBB`) +
  `template.md` documenting the static `qt6ct.conf` writer (`style=Fusion`,
  `custom_palette=true`, `color_scheme_path=…/colors/rice.conf`). Fusion + custom_palette
  is the lightest route — zero extra packages, re-themes from one INI rewrite (vs
  Kvantum's folder-name dance + `kvantummanager --set` round-trip). `theming/gtk-qt.md`
  gets a "lightweight Qt route" section explaining the trade-off; Kvantum remains
  documented for SVG-fidelity / content-theming.

- **#12 — swayosd theming.** New `components/utilities/swayosd.tmpl` (rounded container,
  accent progress bar; sources `{{bg}} {{surface}} {{fg}} {{accent}}`). `utilities/
  template.md` gains the swayosd section + manifest line. Empty reload — applies on
  next server restart.

- **#13 — gtk3 accent.** New `components/look-feel/gtk3.tmpl` parallel to
  `theming/gtk4.tmpl`. Defines the older GTK3 aliases
  (`theme_selected_bg_color`/`_fg_color`/`theme_bg_color`/`theme_base_color`) AND a
  direct `*:selected { background-color: accent }` override — without the override, the
  inherited Adwaita selection rule wins on specificity and thunar's selection bar reads
  as stock blue even when `theme_selected_bg_color` is set. Registered when any GTK3
  default app is in scope.

### Deferred to v0.21.0

- **#14 — browser (firefox) theming.** Browser is real new component scope (new
  `components/browser/` tree with userChrome route + pywalfox route, profile resolution,
  optional restart-hook reload script). Lands as one focused release rather than rushed
  into v0.20.
- **#15 — browser-profile bootstrap + needs-relaunch footer.** Sub-issue 15.3 (a
  `rice apply` footer reporting "3 surfaces apply on next launch/lock: gtk3, qt6ct,
  hyprlock") will land alongside #14, because all the next-launch surfaces are already
  in v0.20.0 and the footer makes them legible.

### Version bumps

- **`SKILL.md`**, **`.claude-plugin/plugin.json`**, **`.claude-plugin/marketplace.json`**:
  bumped to `0.20.0`.

## 0.19.0

End-to-end production-shakedown release. A complete `/hyprland-config:rice` run on Arch +
Hyprland 0.55.2 (Pascal/nouveau, ultrawide, uwsm, plugin v0.18.0) surfaced 17 defects spanning
templates, agents, the validator, and a missing cross-writer contract layer. v0.19 fixes them
at the recipe / writer / contract level (no patches in generated output) and adds the
matching semantic lints so the same defect classes can't ship silently again.

### Cross-writer integration contracts (new `_shared/` registries)

Defects #8, #11, #12, #14, and #17 are the same shape: writer A emits something writer B is
supposed to match (binary name, layer-shell namespace, keybind, bar module, helper script),
and they don't see each other's answers. Four new registries — the single source of truth —
are now consumed by every writer that needs the cross-component view:

- **`references/_shared/namespaces.md`** — every layer-shell namespace and window class any
  writer emits or matches. Eww uses `eww-<name>`; swayosd uses `swayosd`; quickshell uses
  `quickshell:*`; fuzzel uses `launcher` (not `fuzzel`). Window-rules reads from here.
- **`references/_shared/binaries.md`** — the detected-binary registry. SWWW resolves to
  `swww-daemon` (upstream, archived) or `awww-daemon` (fork). Every writer that emits a
  binary takes it from this registry or emits the agnostic `sh -c …` launcher when detection
  ran pre-install.
- **`references/_shared/expected-binds.md`** — when component X is selected, the keybind /
  waybar module that goes with it. Eww widgets, power-menu, blur-toggle, theme-switch are all
  declared here. The keybinds + waybar writers read this so a selection actually wires up.
- **`references/_shared/helper-scripts.md`** — the runtime helper scripts each surface needs.
  Eww's `sysinfo` / `audio` / `player` / `toggles` are declared here; the installer copies
  them. Without this registry, eww shipped as styled-empty widgets.

### Defect fixes (priority order)

- **#1 — generation-time jq dependency dropped.** `scripts/record-answer.py` (new) implements
  the answers-persistence helper in Python stdlib; `record-answer.sh` is now a thin wrapper.
  New `scripts/answers.py` (`get` / `slice` / `list` / `has`) replaces every generation-time
  `jq` invocation across SKILL.md, the interviewer, the component-writer, and the widgets
  gotchas. Runtime scripts (`keybind-cheatsheet.sh`, eww data scripts) keep using jq.
- **#2 — inline interview path is co-equal.** `SKILL.md` A1 now probes `AskUserQuestion`
  availability up-front and picks the agent vs inline path deterministically; the inline path
  is documented as a peer, not a fallback. The interviewer agent's message reflects the
  orchestrator pre-check.
- **#3 — `rgb($bg)` double-wrap removed.** `look-feel/template.md` emits `background_color =
  $bg` (palette vars in `colors.conf` are already `rgb(<hex>)`; re-wrapping fails the reload).
  Validator agent now lints `rgb($var)` / `rgba($var)` / `#$var` patterns in emitted `*.conf`.
- **#4 — rofi theme is self-contained.** `launcher/template.md` ships the global `*` block
  + explicit `background-color` on listview/element/element-text/element-icon + the full
  nine-state element matrix (`{normal,alternate,selected}.{normal,urgent,active}`). The base
  theme no longer bleeds through. Validator + `launcher/validation.md` lint each required
  selector.
- **#5/#6 — paru bootstrap rebuilt.** `agents/hyprland-package-installer.md` probes that the
  helper actually runs (`paru --version`), builds `paru` from source (not `paru-bin` —
  prebuilt fails on libalpm ABI bumps), and sweeps both `paru-bin` AND `paru-bin-debug`
  together before the source build (otherwise `paru-debug` from the new build conflicts with
  the orphan).
- **#7 — wf-recorder default + per-package AUR install.** `utilities/interview.md` /
  `template.md` / `packages.md` / `gotchas.md` default screen-record to `wf-recorder` (repo,
  C, no ffmpeg-next pin); `wl-screenrec` is opt-in with the AUR-Rust-build warning.
  `screenrecord.sh` prefers `wf-recorder` first. Installer agent now installs AUR packages
  individually so one broken build (typical: `wl-screenrec`) can't abort the whole batch.
- **#8 — SWWW binary threaded through.** `autostart/template.md` reads `SWWW_DAEMON_BIN`
  from `detect-version.sh` when present and otherwise emits the binary-agnostic launcher
  `sh -c 'command -v swww-daemon >/dev/null && exec swww-daemon || exec awww-daemon'`.
  Validator lints any literal `exec-once = swww-daemon` / `awww-daemon` outside the
  detector.
- **#9 — monitor magic-mode picker reworded.** `monitors/interview.md` lists the detected
  native mode first when one is reported, then `highres` (recommended, native resolution)
  before `highrr` (highest refresh, may downgrade resolution). `gotchas.md` documents why
  `highrr` can silently land at 1080p on an ultrawide.
- **#10 — eww helper scripts ship.** `assets/scripts/eww/{sysinfo,audio,player,toggles}` are
  new POSIX-shell helpers; the contract lives in `_shared/helper-scripts.md`; the installer
  copies them under `~/.config/eww/scripts/` and `chmod +x`s. `components/widgets/template.md`
  references the canonical paths and lists the runtime deps (`wireplumber`, `brightnessctl`,
  `playerctl`, `networkmanager`, `bluez-utils`); `widgets/packages.md` pulls them.
- **#11 — eww blur layerrule matches `eww-.*`.** `window-rules/template.md` matches the
  family namespace (not bare `eww`, which exists nowhere); the contract is declared in
  `_shared/namespaces.md`. Validator lints every `match:namespace` against the registry.
- **#12 — keybind contract.** `keybinds/template.md` emits widget-toggle binds gated on
  `widgets.system`/`widgets.enabled`, per `_shared/expected-binds.md`. Same contract used
  for #17.
- **#13 — OSD owner cross-validate.** `widgets/gotchas.md` documents the conflict-resolution
  rule when `widgets.enabled` ∋ OSD AND `utilities.osd_route == swayosd`. The orchestrator
  asks the user which side owns OSDs and drops the other instead of letting both render.
- **#14 — swayosd blur via the same namespace contract.** `window-rules/template.md`
  emits a `match:namespace = swayosd` block when `utilities.osd_route == "swayosd"`;
  `SKILL.md` A3b threads the utilities slice to the window-rules writer.
- **#15 — NVIDIA driver branch mapping.** `scripts/detect-version.sh` reads the PCI device
  id, maps it to a generation (blackwell/ada/ampere/turing/volta/pascal/maxwell/kepler/
  fermi), and emits `NVIDIA_GENERATION=` + `NVIDIA_DRIVER_BRANCH=`
  (`nvidia-open` for Turing+, `nvidia-580xx` for Volta/Pascal/Maxwell,
  `nvidia-470xx` for Kepler, `nvidia-390xx` for Fermi). `env/gotchas.md` documents the
  package set per branch + the AUR caveats. Validator lints a bare `nvidia` package install
  on Pascal-or-older.
- **#16 — cursor `no_hardware_cursors` comment fixed.** `look-feel/template.md` now says
  "0 = HW cursors / 1 = software / 2 = auto" plainly, instead of the confusing original
  "disable/enable/auto".
- **#17 — power-menu module on waybar.** `waybar/template.md` emits a `custom/power`
  module wired to `powermenu.sh` (rofi flavor) or `wlogout -p layer-shell` (wlogout
  flavor) when `utilities.selected ∋ power-menu`. Declared in
  `_shared/expected-binds.md` → "Waybar modules".

### Validator semantic lints (defect-class hardening)

`agents/hyprland-config-validator.md` step 6 (new) blocks each defect class above:

- No `rgb($var)` / `rgba($var)` / `#$var` double-wrap in emitted `*.conf`.
- Rofi themes declare the global `*` block AND the full nine-state element matrix.
- No literal `swww-daemon` / `awww-daemon` outside the binary registry and detector.
- Every `match:namespace` in `windowrules.conf` corresponds to a declared namespace whose
  owner is selected.
- Every gate in `expected-binds.md` that holds in `answers.json` has a matching `bind = …,
  exec, <cmd>` line.
- NVIDIA package recommendation matches the detected `NVIDIA_DRIVER_BRANCH`.

### Tests

- **`tests/test_record_answer.sh`**: now exercises the Python implementation and asserts
  `record-answer.py` runs with no `jq` on `PATH`.
- **`tests/test_answers.sh`** (new): full `get` / `slice` / `list` / `has` coverage for the
  new jq-free read helper; pins jq-independence.
- **`tests/test_semantic_lints.sh`** (new): regression tests for the recipe state the
  validator agent enforces — `rgb($var)` absence, the rofi state matrix, the SWWW exec-once
  literal absence, the `_shared/*` registry shape, the expected-binds emission. Catches each
  defect class at the template level.

### Skill

- **`SKILL.md`**: bumped to `0.19.0`.

## 0.18.0

Final orchestrator decision originally flagged: lock-screen wallpaper strategy. The
batch-3 `wallpaper.md` agent hinted at a `lock_screen.wallpaper_strategy` field that
didn't exist; reality was the existing `lock_screen.background` enum was missing one
corpus pattern (ML4W's pre-baked blur). v0.18 closes the gap.

### Lock-screen

- **`components/lock-screen/schema.md`** + **`interview.md`**: `background` enum grows
  from 3 → 4 values. New: `pre-baked-blur` (ML4W pattern — `path = ~/.cache/hypr-rice/lock-blur.png`
  + `blur_passes = 0`; cache file regenerated by the engine on every wallpaper-pick so
  GPU cost is paid once instead of every unlock).
- **`components/lock-screen/template.md`**: new background block for the
  `pre-baked-blur` case. Documents the ImageMagick dep and the fallback behavior.

### Engine

- **`scripts/render-templates.sh`**: new `write_lock_blur()` function. Gated on
  `RICE_LOCK_BLUR=pre-baked` env (mirrors `RICE_THEMING_ENGINE` shape). Reads the
  current wallpaper path from `palette.conf`, pre-blurs to
  `~/.cache/hypr-rice/lock-blur.png` via `magick`/`convert` (`-blur 0x12` matches
  hyprlock's perceptual blur_passes=3,blur_size=7). Soft-fails when ImageMagick isn't
  installed — the writer's coherence rule appends `imagemagick` to the install batch
  when the user picks `pre-baked-blur`, so this only fires for users who deliberately
  skipped the install.

### References

- **`theming/wallpaper.md`** § "Lock-screen wallpaper decoupling": stale field
  reference (`lock_screen.wallpaper_strategy`, never existed) corrected to
  `lock_screen.background`. Documents the new `pre-baked-blur` option and the engine
  hook.

### Agents

- **`agents/hyprland-component-writer.md`**: new coherence rule enumerating all four
  `lock_screen.background` forms and their emission shape, including the
  `imagemagick` install-batch append for `pre-baked-blur`.

### Skill

- **`SKILL.md`**: bumped to `0.18.0`.

### All orchestrator decisions complete

The four orchestrator decisions originally flagged in v0.14 are all shipped:

- v0.15 — `font_ui_scale` cross-surface multiplier (DMS/caelestia prior art)
- v0.16 — `high-contrast-dark` / `high-contrast-light` schemes (WCAG-AAA)
- v0.17 — `utilities.osd_route` (the #1 cross-surface coherence miss in the corpus)
- v0.18 — `lock_screen.background = pre-baked-blur` (ML4W pattern)

## 0.17.0

Lands the OSD-routing question (orchestrator decision #4 of 4 originally flagged).
The laptop batch-2 agent named this **the #1 cross-surface coherence miss across the
top-19 rices** — Matt-FTW ships `swayosd-client` binds without a swayosd matugen
template, and the OSD reverts to stock GTK colors that clash with the rest of the
rice. v0.17 makes the route an explicit interview pick and emits coherent recipes
for every choice.

### Interview

- **`components/utilities/interview.md`**: new sub-question **18b. OSD routing.**
  Four options — `in-shell` (Quickshell IPC), `swayosd` (dedicated daemon),
  `notification` (`notify-send -a OSD` + `[app-name=OSD]` palette block), `none`
  (silent). Defaults reordered per detected widget shell: `in-shell` when the user
  picks a Quickshell-based shell, `swayosd` otherwise.
- **`components/utilities/schema.md`**: `utilities.osd_route` enum added. Documents
  which downstream component-writer reads it for what emission.
- **`references/_interview-protocol.md`**: group 18 count `1 call` → `2 calls`.

### Recipes

- **`components/keybinds/template.md`**: media-key bind block (lines 183-189
  formerly) now switches on `utilities.osd_route`. Four variants — IPC, swayosd,
  notify-send, silent. Volume/brightness keys still WORK in every branch.
- **`components/notifications/template.md`** (mako + dunst sections): emits an
  `[app-name=OSD]` (mako) or `[osd_app]` (dunst) palette override block when
  `utilities.osd_route == "notification"`. Uses `{{accent}}` for the frame and
  `{{surface}}` for the bg so the OSD inherits the rice palette.
- **`components/autostart/template.md`**: the `swayosd` autostart gate is now keyed
  on `utilities.osd_route == "swayosd"` instead of a separate `autostart_env`
  entry — the route decision is what gates it.
- **`components/laptop/gotchas.md`** § (j): "Open question for the orchestrator"
  flipped to **"Resolved (v0.17+)"** with the schema reference.

### Agents

- **`agents/hyprland-component-writer.md`**: new coherence rule for OSD routing.
  Explicitly notes the Matt-FTW coherence-miss antipattern and prescribes the
  coherent recipe per route (don't double-render in-shell + swayosd; ship a
  swayosd matugen template when `osd_route == swayosd`).

### Skill

- **`SKILL.md`**: bumped to `0.17.0`.

### Orchestrator decisions still pending

- `lock-screen.wallpaper_strategy` schema addition (the last one).

## 0.16.0

Lands `high-contrast-dark` and `high-contrast-light` schemes — the WCAG-AAA palette pair
v0.14 flagged as the biggest accessibility unlock. Zero corpus rices ship a true
high-contrast variant; the rice now does, with documented contrast budgets and a
fixed-palette opt-out from wallpaper derivation.

### Palette schemes

- **`_shared/palette-schema.md`**: `scheme=` enum expanded — `high-contrast-dark` and
  `high-contrast-light` added with a "WCAG-AAA; opt out of matugen" note.
- **`theming/palettes.md`**:
  - New rows in dark/light catalog tables and the semantic-hues table with verified hex
    values. Dark: bg `000000` / fg `ffffff` / accent `ffff00`. Light: bg `ffffff` /
    fg `000000` / accent `0000ee`.
  - New **"High-contrast schemes"** section with:
    - Contrast budget table (every documented `fg`/`accent`/`accent2`/`muted`/`red` vs `bg`
      pair clears AAA — 21:1 / 19.6:1 / 16.7:1 / 14.6:1 / 8.2:1 on dark).
    - Opt-out from wallpaper-derivation explanation.
    - Interaction with GTK4 `prefers-contrast: more` — our `gtk4.tmpl` overrides system
      preference for our rendered surfaces.
- Removed stale "## Gaps surfaced" section (font_ui_scale shipped in 0.15, high-contrast
  ships here, M3 motion adjacent now noted inline).

### Scripts

- **`palette-from-wallpaper.sh`**: early-returns when current scheme is `high-contrast-*`.
  Keeps the fixed AAA palette intact and only updates the `wallpaper=` line so the user
  still sees their picked wallpaper behind the (still high-contrast) UI. To resume
  derivation: `rice scheme catppuccin-mocha && rice wallpaper <img>`.

### References

- **`theming/wallpaper.md`**: new "High-contrast schemes opt out of derivation" subsection
  under Dynamic theming.
- **`components/accessibility/gotchas.md`**: "no popular rice ships a high-contrast palette"
  finding flipped to "now shipped" with the dual-scheme reachability paths (interview pick
  AND `rice scheme high-contrast-dark`) and the GTK4 override note.

### Skill

- **`SKILL.md`**: preset list 12 → 14 (high-contrast-dark, high-contrast-light); bumped to
  `0.16.0`.

### Orchestrator decisions still pending

- laptop interview sub-question for OSD routing strategy.
- `lock-screen.wallpaper_strategy` schema addition.

## 0.15.0

Lands the **cross-surface font-scale** the v0.14 release flagged as pending. One palette
metadata key, every visual surface scales together — the accessibility / HiDPI knob the
corpus had as DankMaterialShell-only prior art is now a first-class rice feature.

### Cross-surface font-scale (`font_ui_scale`)

- **`_shared/palette-schema.md`**: new metadata key `font_ui_scale` (multiplier, default
  `1.0`; interview options `1.0|1.15|1.3|1.5`). Always populated; defaults to `1.0` if
  unset. Documented sizing rules show the per-surface convention.
- **`theming/palette.matugen.tmpl`**: emits `font_ui_scale=1.0` so a wallpaper-cycle
  re-render preserves the user's scale instead of dropping it.
- **`theming/fonts.md`**: "pending pattern" section flipped to **"Cross-surface
  font-scale"** with the per-surface convention (recipe-driven CSS surfaces use
  `font-size: calc(<base>px * {{font_ui_scale}})`; recipe-driven non-CSS surfaces
  multiply at generate time; quickshell exposes `Colors.fontScale` for QML).
- **`components/widgets/quickshell.tmpl`**: new `readonly property real fontScale:
  {{font_ui_scale}}` property; QML files use `font.pixelSize: <base> * Colors.fontScale`.
  Hot-reload picks it up.
- **`_shared/colors-contract.md`**: quickshell row now includes `fontScale` in the
  exported singleton names.
- **`agents/hyprland-component-writer.md`**: new coherence rule — every recipe fill scales
  font-sizes by `{{font_ui_scale}}`. CSS surfaces use `calc()`, non-CSS surfaces multiply
  at write time, QML surfaces use `Colors.fontScale`. Notes the DMS dual-knob pattern
  (`fontScale` + `dankBarFontScale`) as future per-surface override prior art.
- **`components/accessibility/gotchas.md`**: the "no shared font-scale" absence finding
  is rewritten as **"Shared font-scale variable (now exposed)"** with prior art and the
  complement to the `larger-ui` gsettings bridge.
- **`SKILL.md`**: A4 always populates `font_ui_scale`; bumped to `0.15.0`.

### Orchestrator decisions still pending
- `high-contrast-dark` / `high-contrast-light` scheme (ripple-list in `palettes.md`).
- laptop interview sub-question for OSD routing strategy.
- `lock-screen.wallpaper_strategy` schema addition.

## 0.14.0

Three-batch deep-research pass across the corpus (top ~19 community Hyprland rices on
github.com/topics/hyprland) — 22 component reference folders + 7 cross-cutting theming docs
updated against verified upstream sources. The skill, the writer + validator agents, and the
contract files are updated to leverage what landed.

### Engine scripts
- **`render-templates.sh`**: after the manifest loop, optionally writes
  `~/.config/hypr/scripts/restore-theme.sh` when `RICE_THEMING_ENGINE=matugen|wallust|wallbash`
  is set. The script re-paints the wallpaper and re-runs the theming engine on login so the
  desktop comes up matching the last rice state instead of a stale palette. Skipped on `none`
  or unset. Body per engine documented in `references/theming/engine.md`.
- **`detect-version.sh`**: emits `HYPR_HAS_EXT_BG_EFFECT_V1=1|0|unknown` — true at Hyprland
  commit `7d1e481` (May 2026, ~v0.50+) where `ext-background-effect-v1` lands. Walker's
  `ext_background_effect_blur = true` opt-in needs the protocol; on older Hyprland the only
  path is a `layerrule = blur, walker` block. The flag lets the writer + window-rules
  template branch correctly without re-parsing the version string.

### Color templates / contract
- **`components/launcher/fuzzel.tmpl`**: grows from 7 → 11 keys to match every documented
  fuzzel.ini(5) color slot. Adds `prompt` (→ `{{accent}}`), `placeholder` (→ `{{muted}}`),
  `input` (→ `{{fg}}`), `counter` (→ `{{muted}}`). No new palette schema keys.
- **`_shared/colors-contract.md`** rows brought into sync with the actual `.tmpl` content:
  - `kitty` row gains 10 chrome keys (`cursor_text_color`, `url_color`, `active_tab_*`,
    `inactive_tab_*`, `tab_bar_background`, `active_border_color`, `inactive_border_color`,
    `bell_border_color`) so themes don't fall back to kitty's gray defaults on the tab bar.
  - `gtk4` row grows from 14 → 24 keys (libadwaita 1.4+ standards: `headerbar_backdrop_color`,
    `card_fg_color`, `popover_fg_color`, `dialog_*`, `sidebar_*`, `error_color`). Prevents
    DMS's documented "white flash on window unfocus" and themes Nautilus/Loupe correctly.
  - `fuzzel` row grows from 7 → 11 keys (see above).
  - `quickshell` row: `term[16]` → `term0..term15` (individual properties — community uses
    `Colors.term3` direct, not array index), plus M3 motion tokens (`standard`,
    `standardAccel`, `standardDecel`, `emphasized`, `emphasizedAccel`, `emphasizedDecel`).

### Agents
- **`hyprland-component-writer`**: new "Cross-surface coherence" section codifies the
  corpus-validated rules every recipe fill must honour — pill `{{rounding}}` reuse,
  shared `{{accent}}`, hyprbars palette reuse, `#battery.critical → {{red}}`, per-tool
  layerrule namespace map (fuzzel→`launcher`, swaync→2 blocks, walker conditional),
  `envd =` for XDG vars, mako `urgency=critical` (not `high`), Astronaut SDDM
  `snake_case.conf` filenames.
- **`hyprland-config-validator`**: new lint rules step 6 catches the real-world breakage
  the corpus pass surfaced — fuzzel namespace, swaync dual-layer blur, blur master-gate
  dependency, hyprbars literal-hex anti-pattern, kitty chrome export gaps, `env =
  XDG_CURRENT_DESKTOP` (recommend `envd =`), invalid mako `urgency=high`, walker layerrule
  redundancy ≥0.50, Astronaut filename casing.

### References (component-level — batches 1+2)
- **Visual components** (waybar / launcher / notifications / widgets / look-feel /
  lock-screen / terminal / shell-prompt): 8 deep-research passes harvesting theming idioms,
  archetypes, battle-tested techniques, and cross-surface coherence rules from the corpus.
  Highlights: waybar `fixed-center`/`ipc`/JBM `font-feature-settings`; rofi state-selector
  `element selected.normal/urgent/active` syntax fix; quickshell `Singleton` root + M3
  motion tokens; kitty tab-bar chrome; mako `[urgency=critical]` correction; hyprlock
  matugen `hyprlock-colors.conf` archetype; look-feel locked-group color ladder; starship
  `command_timeout=500` + `⇡⇣⇕` glyphs.
- **Structural components** (monitors / input / keybinds / default-apps / env / window-rules
  / autostart / companion-daemons / plugins / utilities / login-boot / gaming / laptop /
  accessibility): 14 deep-research passes harvesting "how popular rices use this component IN
  SERVICE OF the theme". Highlights: window-rules per-tool layerrule emission with all 5
  batch-1 flags upstream-confirmed; autostart `restore-theme.sh` ownership + `dbus_propagation`
  schema; env `envd =` for XDG + Electron-Ozone non-NVIDIA split; plugins 0.55+ lua cliff;
  utilities `theming/apps.md` wlogout-path correction; accessibility three documented
  absence findings (no high-contrast palette, no shared font-scale, no motion-off profile).

### References (cross-cutting theming — batch 3)
- **`theming-architecture.md`**: documents the post-refactor `.tmpl` layout, the new
  dataflows (`restore-theme.sh`, `envd`, layerrule emission table), and cross-surface
  palette coherence (`decoration:rounding` canonical, `$accent` shared).
- **`engine.md`**: per-engine `restore-theme.sh` body table (matugen / wallust / wallbash /
  none) with the canonical guarded script, `HYPR_HAS_EXT_BG_EFFECT_V1` walker blur cliff.
  Palette-template audit confirmed clean: 0 missing exports across all 18 component
  `.tmpl`s and `gtk4.tmpl`.
- **`palettes.md`**: 4 corpus scheme-supply patterns, 26→12 / 40+→12 / `dank16` mapping
  tables, high-contrast scheme gap with the full ripple-list of files an enum would touch.
- **`fonts.md`**: per-rice font picks for 14 corpus rices, omarchy `omarchy-font-set` sweep
  as the model for the re-render path, per-app font-size unit table (rofi pt, fuzzel
  pt-suffix, kitty pt, waybar/QML px, hyprlock per-label pt), `font_ui_scale` pending
  pattern with caelestia/DMS prior art.
- **`wallpaper.md`**: daemon-by-rice table for all 19 corpus rices, Quickshell-owns-wallpaper
  architecture fork, canonical restore-script bodies per engine, lock-screen wallpaper
  decoupling.
- **`apps.md`**: per-app palette-export table resync against actual `.tmpl` content (kitty
  chrome, quickshell `term0..15`, plugins rows), default-apps ricochet table (which
  component's `.tmpl` re-themes each default-app pick), btop/cava `components/utilities/` →
  `components/terminal/` path correction.
- **`gtk-qt.md`**: cursor-coherence three-place table, toolkit footguns
  (`_JAVA_AWT_WM_NONREPARENTING`, `MOZ_DISABLE_RDD_SANDBOX`, `GSK_RENDERER=ngl`,
  `ELECTRON_OZONE_PLATFORM_HINT,auto`), default-app pairing
  (Dolphin→Kvantum, Nautilus→localsearch), `hyprctl setenv` → `hyprctl keyword env` (0.55+
  form).

### Skill
- **`SKILL.md`**: bumped to `0.14.0`. A3 documents the cross-surface coherence rules the
  writer agent enforces. A4 documents `RICE_THEMING_ENGINE` env for `restore-theme.sh`
  emission and the autostart `exec-once` wiring.

### Orchestrator decisions still pending (not in this release)
- New `scheme` enum values for `high-contrast-dark` / `high-contrast-light` (ripple-list
  in `palettes.md`).
- `font_ui_scale` metadata key with caelestia/DMS prior art (ripple to every visual
  `template.md`).
- laptop interview sub-question for OSD routing strategy (#1 cross-surface coherence miss
  in the corpus).
- `lock-screen.wallpaper_strategy` schema addition.

## 0.13.0

Corrections and hardening from an extensive real-world from-scratch build on **Hyprland 0.55.2**
(wallpaper-driven Everforest rice with an hourly matugen re-theme cycle).

### Engine scripts
- **`palette-from-wallpaper.sh`**: fixed for **matugen 4.x** — it now writes a top-level `[config]`
  table (required, else "missing field config") and passes `--prefer`/`--mode`/`--type` (headless
  matugen needs `--prefer` when an image yields multiple source colors). Overridable via
  `MATUGEN_TYPE`/`MATUGEN_MODE`/`MATUGEN_PREFER`. Without this, every wallpaper-driven theme/cycle
  silently kept the old palette.
- **`palette.matugen.tmpl`**: emits `font_ui`/`font_mono` so a re-render (e.g. a wallpaper cycle)
  no longer drops the fonts from `palette.conf`.
- **`safe-apply.sh`**: rollback no longer `rm -rf`s `~/.config/hypr` — a running Hyprland regenerates
  a STUB config the instant the dir goes empty, racing the restore and leaving a nested/stub mess. It
  now restores by overwriting backup files back over the target and pruning only the files the failed
  config added (the dir is never empty).
- **`rice-init.sh`**: derives the plugin's rice dir from the script's own location when
  `CLAUDE_PLUGIN_ROOT` is unset (was a hard abort).

### Color templates (re-theme coherence)
- **`waybar.tmpl`** now emits the full named palette (`…blue/magenta/cyan`) so per-module-hue styles
  re-theme; **`swaync.tmpl`** adds `muted`/`accent2`; **`rofi.tmpl`** switched to the
  `bg/bg-alt/fg/muted/accent/accent2/red/green` var names the theme.rasi actually imports. (Previously
  the engine emitted names the component styles didn't reference, so an `apply` broke the styling.)

### References
- **`components.md`**: waybar Nerd Font glyph rule — a linter strips 3-byte legacy-PUA glyphs
  (U+E000–U+F8FF) from `config.jsonc`, so use 4-byte Material Design icons (U+F0000+) + plain Unicode
  dots (`●`/`○`); verified glyph table; author via `python3 json.dump(ensure_ascii=False)` + re-verify.
  Far-end pill margins for the separated-pills archetype. The `$menu` vs `$dmenu` bug (`$menu -dmenu`
  is broken). swaync `backlight` widget only when a backlight device exists.
- **`config-templates.md`**: `follow_mouse` semantics corrected (`1` is focus-follows-mouse, `2` is
  detached); native **`scrolling`** layout (core in 0.53+, no plugin) + `scrolling {}` block + binds;
  `$dmenu` variable; hyprlock input field kept visible (`fade_on_empty=false`); plugin-dispatcher binds
  must be commented (they hard-error the reload).
- **`plugins.md`**: rewritten — `hyprexpo`/`hyprtrails`/`hyprscrolling` removed from the official repo
  (scrolling is native; hyprexpo via `sandwichfarm/hyprexpo`); hyprpm gotchas (root-owned
  `/var/cache/hyprpm` + internal sudo needs a TTY, `~/.local/share/hyprpm` must exist, don't chain
  enables, `hyprctl plugin load` no-root alternative, plugin dispatchers hard-error).
- **`interview.md`**: focus-model option mapping fixed; plugins catalog updated for native scrolling +
  removed plugins.
- **`theming.md` / `engine.md`**: GTK3/4 `settings.ini` + `~/.gtkrc-2.0` are required (gsettings alone
  leaves GTK3 apps light). eww SCSS uses `rgba()` not `alpha()` (grass 1-arg), no `:height "auto"`.
- **hyprland-reference `styling/`**: `eww.md`, `waybar.md`, `hyprlock.md` mirror the above.

### Agents & skill
- **`hyprland-interviewer`**: documents that `AskUserQuestion` may be disabled inside subagents — probe
  first, return `INTERVIEW=blocked`, never fabricate answers.
- **`hyprland-config-validator`**: flags uncommented plugin-dispatcher binds / plugin-layout lines as
  reload-breaking ERRORS (was wrongly treating them as inert).
- **rice `SKILL.md`**: A1 inline-interview fallback for the blocked case; A4 matugen-4.x note; A5 GTK
  settings.ini + the dynamic-wallpaper systemd-timer pattern; the fourth GTK gotcha.

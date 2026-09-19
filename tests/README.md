# tests

Plain bash test harness for the plugin. No frameworks — just `bash` + `jq` + `git`.

## Run

```bash
bash tests/run.sh                      # everything except the Docker integration test (fast)
bash tests/run.sh <substring>          # only test files matching the substring
RUN_INTEGRATION=1 bash tests/run.sh    # also build + run the Hyprland-in-Docker integration
```

Exit code: `0` if every test passed (skipped is fine), `1` otherwise.

## What's covered

| File | What it checks |
|---|---|
| `test_scripts_syntax.sh` | `bash -n` on every `.sh` the plugin ships + `shellcheck` (errors only, if installed) + `+x` bit on scripts the user invokes directly |
| `test_record_answer.sh` | `scripts/record-answer.sh` full behavior — strings, `--json` arrays/numbers/`false`/`null`/objects, nested keys, idempotent overwrite, invalid input rejection, corrupted-target rejection |
| `test_backup_path.sh` | `scripts/backup-path.sh` — file backup, dir backup (recursive), missing-path reporting, shared timestamp across multi-path calls, `~` expansion |
| `test_verify_shell.sh` | `skills/rice/scripts/verify-shell.sh` — clean rc → `ok`, broken rc → `errors`, **never sources the file** (critical safety property), shell inference from filename, missing file → error |
| `test_dotfiles.sh` | `scripts/dotfiles.sh` — bare repo init + state file, idempotency, `add` tracks files, `commit` creates a commit, stow path errors when stow is missing |
| `test_render_templates.sh` | End-to-end engine: `rice-init.sh` scaffolds, `render-templates.sh` substitutes `{{key}}` placeholders from `palette.conf`, user-override cascade wins, symlinked output is replaced (the gtk-4.0 gotcha), missing palette is reported |
| `test_metadata.sh` | `plugin.json` / `marketplace.json` parse and agree on version + name, version is semver, every `SKILL.md` has `name`+`description`, every agent has `name`+`description`+`model`+`tools`, `rice/SKILL.md` version matches `plugin.json` |
| `test_paths.sh` | Every `${CLAUDE_PLUGIN_ROOT}/...` reference and every explicit `./`/`../` ref resolves on disk — catches stale paths after renames |
| `test_lua_emit.sh` | The config-LANGUAGE decision and the emitter pair (`config-language.sh` + `emit-config.sh`): 0.55+ emits `hyprland.lua`, below emits `hyprland.conf` and no lua, both carry a `CONFIG_LANGUAGE=`/`CONFIG_LANGUAGE_RANGE=` header, an undetectable version reports both emittable languages and refuses to guess, and the stated hyprlang support window is the published 1 - 2 releases from 0.55 |
| `test_lua_install.sh` | `install-config.sh` fail-safes against a temp `HYPR_DIR`: a target holding a `hyprland.lua` refuses a hyprlang `.conf` install (naming the file and the precedence), an unwritable or non-directory target is reported and left untouched, and an absent/empty target installs without claiming a backup it did not take |
| `test_lua_migrate.sh` | `migrate-config.sh`: the offer changes nothing, `--convert` writes lua and keeps every `.conf` plus a verified backup, the plugin's own modular `source = ~/.config/hypr/*.conf` set (`skills/rice/examples/sample-config/`) converts as one unit under a scratch `HYPR_DIR`, a construct with no documented lua mapping is carried across as a marked `NOT APPLIED` comment and reported rather than refused, and the four refusals (existing `hyprland.lua`, unparseable input, an unresolvable `source =`, failed backup) each change nothing and say why |
| `test_regress_0018_F1/F2/F3.sh` | The impl-gate regression artifacts for S0018, kept in the suite so the holes they found cannot reopen: F1 the plugin's own generated `.conf` set really is offered and converted (blocking at loop 1), F2 the shadow guard holds through `safe-apply.sh` and for plain, symlinked and dangling `hyprland.lua`, F3 a `source = ~/...` line resolves against `HYPR_DIR` |
| `test_preflight.sh` | The **offline preflight** (`preflight-config.sh`) and the apply flow it guards, with a stub `Hyprland` that reproduces the contract measured in `integration/offline-check-contract.md`: a staged config with errors is refused *before* any backup or write and the errors name the **staged** paths; a split staged set is checked as a set, and the already-installed files of the same name never decide the verdict in either direction; no binary offering the check reports `unverified` (not `ok`) and falls through to the old install path unchanged; an absent/unreadable/ambiguous main config or a rejected invocation reports `uncheckable`, distinct from `errors`; every refusal leaves the target **byte-identical**; and each apply ends with exactly one, distinguishable, `SAFE_APPLY=` line |
| `test_preflight_live.sh` | The **live verdict**: `loaded-config.sh` makes the running compositor *name* the config it loaded, and `verify-config.sh --expect` reports `ok` only on a positive match. An empty `hyprctl configerrors` with no identification is `unconfirmed`, never `ok`; a mismatch names the file the compositor loaded and leaves the install standing (not rolled back); an unreachable instance is still `installed-untested`; and the bare, no-`--expect` invocation keeps its existing contract |
| `test_integration_docker.sh` | **Skipped by default.** Builds Arch + Hyprland container and starts Hyprland against a known-good generated config. Two outcomes depending on whether `/dev/dri` is available: **(live mode — dev machine with a real GPU passed through)** runs `safe-apply.sh`, asserts `SAFE_APPLY=ok` + `hyprctl configerrors` empty + no `[ERR]`/`[CRITICAL]` lines in the Hyprland log; **(parse-only mode — CI / no GPU)** Hyprland's Aquamarine backend can't init without `/dev/dri`, but its config parser still runs to completion, so the test asserts the parser accepted every line (no `[ERR] [Config Parser]`, no `Config Error:`, no `invalid keyword/field/token` in the log) before the backend failed. Parse-only mode is what runs on the GitHub Actions runner. **In both modes** it first re-derives the `Hyprland --verify-config` contract against the real binary and runs the **negative control**: a deliberately broken generated config goes through the offline check, and the build FAILS if it comes back clean. |
| `test_answers.sh` | `scripts/answers.py` - the jq-free read helper (`get`/`slice`/`list`/`has`) every generation step reads `answers.json` through |
| `test_python_bootstrap.sh` | `scripts/ensure-python.sh` - python present/absent/declined/no-pacman/failed, each its own outcome; the accepted install is recorded; and the bootstrap never invokes the interpreter it installs. **Python is not in Arch's `base`**, so the interview cannot assume it |
| `test_context_budgets.sh` | The context budgets, enforced rather than trusted: SKILL.md bodies within 500 lines / ~5k tok, reference and agent files within ~4k, a table of contents on anything over 100 lines, no research citations in the load path, and **B-6** - what ONE writer loads to author ONE surface (`common.md` + the single `tools/<tool>.md` or `looks/<archetype>.md`), across every surface including unsharded ones |
| `test_install_record.sh` | `scripts/install-record.sh` - one record per transaction, newest-first listing, same-second ordinals, prose `show`, an unwritable store reported by path with the transaction still printed, and an install refusing to run at all when the recorder is missing |
| `test_aur_bootstrap_consent.sh` | The AUR-helper build discloses before it builds: names the package, says it is a source build on this machine, shows the clone URL, and treats an unanswered prompt as a decline. A decline clones/builds/installs nothing and is a distinct outcome from a failed build |
| `test_install_no_pacman.sh` | No pacman means the package list is printed and no package manager or helper is invoked at all - reported as skipped, not failed |
| `test_firefox_profile_backup.sh` | Every Firefox profile file is backed up before it is replaced (including a `userChrome.css` this plugin wrote before); a file that cannot be backed up is not written, and the skip names the path |
| `test_pref_record.sh` | The two `user.js` preferences a config restore cannot undo are recorded against the profile's absolute path and removable via `rice prefs remove` - leaving every other line byte-identical and reporting a line changed by hand rather than deleting it |
| `test_xdg_config_home.sh` | `scripts/xdg-config.sh` is the ONE place this plugin decides where config lives (AC-1..AC-9): an explicit override wins, a relative `XDG_CONFIG_HOME` is invalid and the fallback is announced, an unwritable or undeterminable target refuses rather than falling back, and no shipped script resolves `$HOME/.config` for itself |
| `test_restore_point.sh` | Backup-before-write and one restore point per apply across all three stages a single apply writes through |
| `test_restore_command.sh` | `rice restore <id>` round-trip: every path one apply touched goes back, files the apply created are removed, and a partial failure reports the paths it could not restore |
| `test_restore_interrupt.sh` | An apply killed partway through still leaves a usable restore point - four interruption points, all four restorable |
| `test_restore_overlap.sh` | Overlapping paths inside one restore point (an apply enrolling a directory AND files inside it) restore in the documented order |
| `test_semantic_lints.sh` | The semantic lints the validator agent blocks on - the defect classes found in production shakedowns (rofi's 9-state element matrix, layer namespaces, expected binds, helper-script wiring) |
| `test_currency_citations.sh` | Every version-cliff record carries an upstream citation that resolves to a specific artifact, and no cliff is asserted outside the ledger. **Fails the build** |
| `test_currency_staleness.sh` | Staleness against the newest release is *reported*, never a build failure - upstream tagging a version is not a defect in this repo |
| `test_currency_removed_keys.sh` | `validate-removed-keys.sh` refuses a staged config that sets a key removed at the target version, before the compositor is consulted and before anything is backed up or written |
| `test_regress_0018_F1/F2/F3.sh` · `regress_0018_F4-F7.sh` · `regress_0032_F1.sh` · `regress_0037_F1/F2.sh` · `regress_0037_gate2_acceptance.sh` | Impl-gate regression artifacts, kept in the suite so the holes they found cannot reopen. The `regress_*.sh` (no `test_` prefix) files are **not** picked up by `run.sh`; they are report-only probes run by hand against a checkout. |
| `test_rice_scheme_profiles.sh` | The two documented-but-absent features: `rice scheme <name>` (swap the palette, keep the wallpaper - the documented way out of a fixed `high-contrast-*` palette) and the fourteen shipped preset profiles. Also pins each profile to the palette contract, and the docs' component / interview-group counts to what is actually on disk. |

## CI

`.github/workflows/tests.yml` runs the suite on every push + PR. Two jobs:
- **unit** — fast (~10 s); runs by default.
- **integration** — boots Hyprland headlessly in Docker; the image is cached by the
  Dockerfile + in-container-script hash so most runs pull from cache instead of rebuilding.

## What's not covered (and why)

- **End-to-end agent execution** — the agents need a Claude runtime; that's the user's `claude
  --plugin-dir …` flow, not a unit test. The metadata + frontmatter tests catch the boring
  failure mode (missing keys, wrong names).
- **`pacman` actually installing packages** — `hyprland-package-installer` is exercised
  indirectly by the integration test (which runs `pacman` to build the container image).
  Beyond that, the install flow needs a real Arch system + user confirmation, so it's left to
  manual smoke-tests.
- **Real GPU rendering** — the wlroots headless backend in `tests/integration/Dockerfile` runs
  Hyprland with the pixman software renderer, which is sufficient to exercise the config-parse
  + `hyprctl reload` path but not any actual rendering.

## Adding a test

1. Drop a `test_<thing>.sh` into this dir. It does **not** need a shebang; `run.sh` sources it.
2. Use the assertion helpers from `lib.sh`: `pass`, `fail "name" "detail"`, `skip "name"
   "reason"`, `assert_eq`, `assert_ok`, `assert_fail`, `assert_file_exists`,
   `assert_file_contains`, `assert_grep`, `mktemp_test_dir`.
3. The runner counts each `pass`/`fail`/`skip` and reports them in the summary.

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

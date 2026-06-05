# shell-prompt — validation

The only meaningful automated check is **parse-only**. Never `source` an rc to "verify it" —
sourcing executes every line (prompt-engine inits, fastfetch, history rewrites, `cd`-shadowing
zoxide aliases) and either pollutes the calling environment or has visible side effects in the
user's shell.

The plugin's `verify-shell.sh` wraps the per-shell commands below and emits
`VERIFY_SHELL=ok|errors|skipped`. Run it after **every** edit that touches a shell rc.

## Parse-test per shell

| Shell | Command | Pass | Fail |
|---|---|---|---|
| bash | `bash -n ~/.bashrc` | exit 0, no stderr | exit ≠ 0 with `syntax error: …` line/column |
| zsh  | `zsh  -n ~/.zshrc`  | exit 0, no stderr | exit ≠ 0 with `parse error near …` |
| fish | `fish --no-execute ~/.config/fish/config.fish` | exit 0, no stderr | exit ≠ 0 with file/line/character pointer |

`-n` (bash/zsh) reads the file and does a syntax-only parse without running any command.
`fish --no-execute` (also `fish -n`) does the same for fish.

## What a clean parse does and does not prove

**Does prove:**

- The managed block didn't break the rc's syntax (unbalanced `if`/`fi`, missing `end`,
  stray quote, malformed assignment).
- The sentinel insertion didn't accidentally land inside an existing heredoc / quoted string /
  `case` arm.

**Does NOT prove:**

- That the referenced tools exist (`starship`, `fastfetch`, `eza`, …). That's why every external
  invocation in `template.md` is `command -v` / `type -q` -guarded — a missing binary is a
  silent no-op, not a syntax error.
- That `STARSHIP_CONFIG` points at a readable file. Render the engine output first; if missing,
  starship logs a warning to stderr at every prompt but the shell still starts.
- That oh-my-posh's `--config` JSON is well-formed. A bad theme renders a degraded prompt but
  doesn't fail to start. Validate the theme separately with `oh-my-posh config validate
  --config <path>` if available.
- That the user's existing rc is sane outside the managed block. The parse covers the whole file.

## When the test is "skipped"

`VERIFY_SHELL=skipped` for a given shell means the shell binary is not on PATH yet:

- The user picked `shell == "fish"` but fish hasn't been installed yet (install batch hasn't
  run, or this is a Mode A dry-run before the package step).
- Output: `verify-shell.sh: fish not installed; parse-test skipped (will run after install)`.

A skipped test is not a failure — the rc can still be staged. Re-run `verify-shell.sh` after the
install step to get an actual `ok`.

## fisher / fish_plugins are not parse-tested

`~/.config/fish/fish_plugins` is plain text (one `owner/repo` per line) read by `fisher update`;
there's no shell syntax to validate. Lint check instead:

```bash
grep -vE '^([A-Za-z0-9._-]+/[A-Za-z0-9._-]+|#|$)' ~/.config/fish/fish_plugins
```

— output should be empty (matches non-`owner/repo`, non-comment, non-empty lines = malformed).
Run this in the validator's lint pass, not the parse pass.

## Rendered prompt configs — sanity checks

After the engine renders `~/.config/hypr-rice/starship.toml` /
`~/.config/hypr-rice/rice.omp.json` /
`~/.config/fish/conf.d/zz-hypr-rice-colors.fish`:

- **starship.toml**: `python -c 'import tomllib, sys; tomllib.load(open(sys.argv[1],"rb"))'
  ~/.config/hypr-rice/starship.toml` (Python ≥ 3.11). Errors out on TOML syntax.
- **rice.omp.json**: `jq empty < ~/.config/hypr-rice/rice.omp.json`. Errors out on JSON syntax.
  (Watch for trailing commas — oh-my-posh silently falls back to a default prompt if the JSON
  is invalid; the visible symptom is "my theme isn't applied" with no error message.)
- **zz-hypr-rice-colors.fish**: included in the `fish --no-execute config.fish` pass via fish's
  auto-source — i.e., parse-testing `config.fish` parses every `conf.d/*.fish` too. No separate
  step needed.

## Re-running after a re-theme

`rice apply` re-renders the prompt configs from the palette but does **not** rewrite the rc's
managed block — only `rice init` / `edit-config` does that. So `verify-shell.sh` only needs to
re-run when:

- A new shell pick changed (17a),
- A new prompt engine changed (17b),
- The fetch tool changed (17d),
- Aliases / modern-CLI selection changed.

Pure palette changes only re-render the engine-config files, which the sanity-check pass above
catches.

## Validator outputs

| Output | Meaning |
|---|---|
| `VERIFY_SHELL=ok` | Every chosen shell's rc parsed cleanly. |
| `VERIFY_SHELL=errors` | At least one parse failed. The wrapper prints the offending file and the parser's diagnostic. Re-edit and re-test before moving on. |
| `VERIFY_SHELL=skipped` | Shell isn't installed yet; re-run after the install step. |

Pipe these into the overall Mode A summary so the user sees the state per-shell.

## Cross-references

- Template the parse runs against → `template.md`
- Reload guidance after a clean parse → `reload.md`
- Engine-level config rendering (starship.toml / rice.omp.json / fish color file) →
  `../../theming/engine.md`

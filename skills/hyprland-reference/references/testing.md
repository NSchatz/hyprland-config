# Reading & Testing a Hyprland Config

Static analysis catches a lot, but the only authoritative test of "does this config work" is
loading it into Hyprland and asking the compositor. This documents the mechanisms and the safe
apply→test→rollback pattern the plugin uses.

## Reading the current config

- Main file: `~/.config/hypr/hyprland.conf` (respects `$XDG_CONFIG_HOME`).
- Resolve the full picture by following every `source=` line (and globs like
  `source = ~/.config/hypr/conf.d/*.conf`). Read the main file first, then each sourced file in
  order — later definitions override earlier ones.
- Companion daemon configs live alongside but are **not** `source=`d: `hyprlock.conf`,
  `hypridle.conf`, `hyprpaper.conf`, etc. They use their own config languages.
- Live introspection (read-only, reflects the *running* state, which may differ from the file if
  not yet reloaded):
  - `hyprctl getoption <category:name>` — current value/type of one option.
  - `hyprctl binds -j` — all active keybinds (JSON).
  - `hyprctl monitors -j`, `hyprctl clients -j`, `hyprctl layers -j`, `hyprctl workspaces -j`.
  - `hyprctl version` — installed version/commit.

## Testing that the config loads

Two checks, and they answer different questions.

### Offline, before the file goes anywhere: `Hyprland --verify-config`

`Hyprland --verify-config -c <file>` parses a config with the compositor's own parser and
exits **0** (clean) or **1** (errors), printing a `======== Config parsing result:` block.
It does not start a compositor: it needs `XDG_RUNTIME_DIR` set and nothing else. No
session, no seat, no `/dev/dri`, so it runs on a CI runner and against a file that is not
installed yet. Errors in `source =`d companions are reported against those files' own paths
and lines.

**Exit 1 is overloaded**: a bad `-c` path, a directory, or an unknown flag also exits 1,
after printing the usage banner and *no* parsing-result block. So judge by the block, not
the status. The full measured contract (every exit code, the `~`-expands-from-`$HOME`
behaviour, the lua form) is in `tests/integration/offline-check-contract.md`.

### Live, against a running compositor: reload + errors + identity

1. `hyprctl reload` — re-reads the config files from disk and applies them. It does **not** re-run
   `exec-once` entries, so it won't relaunch your bar/daemons.
2. `hyprctl configerrors` — prints the parse errors from the currently-loaded config. **Clean =
   empty output** (it prints blank/`[""]`). Any non-blank lines are real errors. Note it always
   **exits 0**, so judge by the output, not the exit code.
3. **Confirm which file it actually loaded.** An empty `configerrors` is *also* exactly what a
   config that was never parsed produces: a `hyprland.lua` shadowing your `hyprland.conf`, or a
   session started with `-c` somewhere else. No `hyprctl` command reports the config path, but
   the compositor logs `Using config: <path>` for every file it reads and re-logs them on each
   reload, so `hyprctl rollinglog` will name them.

So: reload, check `configerrors` is empty, **and** check the compositor names the file you
wrote. Steps 1 and 2 alone are not the "it works" signal; all three are.

### Testing a single option without editing files

`hyprctl keyword <name> <value>` applies one setting to the live session immediately, e.g.
`hyprctl keyword decoration:rounding 0`. Useful to preview a value before persisting it to the
file. It does not write to disk and is reverted by the next reload.

### Isolated / nested testing (advanced)

A config can be loaded in a nested Hyprland instance without disturbing the session:
`Hyprland --config /path/to/hyprland.conf` (best inside an existing session or a headless backend
via `WLR_BACKEND=headless`). Heavier and environment-dependent; the reload+configerrors approach
is preferred for the common case.

## Preflight → safe apply → test → rollback pattern

Editing a live config risks leaving the session broken. Always:

0. **Preflight the staged config offline** with `Hyprland --verify-config`, before any backup
   and any write. A config that does not parse is refused here, with `~/.config/hypr` never
   touched: no rollback to depend on, nothing to restore.
1. **Back up** the whole `~/.config/hypr` to a timestamped copy first.
2. **Apply** the change (write the file).
3. **Test**: `hyprctl reload`, then `hyprctl configerrors`, then confirm the compositor names
   the file you wrote.
4. **On errors → roll back**: restore the backup and reload again, so the session returns to the
   last-known-good state. Report the errors so they can be fixed and retried.
5. **On no running instance** → cannot live-test; rely on the offline check and say so.

The plugin implements this:

- `skills/rice/scripts/preflight-config.sh`: step 0. Copies the staged set into a sandbox
  whose `HOME` is the sandbox (so `source = ~/.config/hypr/…` resolves to the *staged*
  companions, never the installed ones) and runs the compositor's offline check against it.
  Prints `PREFLIGHT=ok|errors|unverified|uncheckable`; exit 0/1/2/3. `unverified` means this
  host has no binary offering the check, which is not `ok`.
- `skills/rice/scripts/verify-config.sh`: step 3 (reload + configerrors, plus `--expect <file>`
  for the identity check). Prints `VERIFY=ok|errors|skipped|unconfirmed`; exit 0/1/2/3.
- `skills/rice/scripts/loaded-config.sh`: the identity check on its own. Asks the running
  compositor which config it loaded. Prints `LOADED_CONFIG=<path>` or `LOADED_CONFIG=unknown`.
- `skills/rice/scripts/safe-apply.sh`: full cycle. Preflight, install a staged config, verify,
  and auto-rollback to the backup on failure. Prints
  `SAFE_APPLY=ok|preflight-failed|preflight-uncheckable|rolled-back|installed-untested|unconfirmed|…`.
- `skills/rice/scripts/config-language.sh`: step 0, and the one nobody used to do. **Which
  config language does this Hyprland read?** From 0.55 a `hyprland.lua` is loaded *instead of*
  `hyprland.conf`, so a reload of a `.conf` that is shadowed by a `.lua` reports clean while
  changing nothing. `install-config.sh` refuses that install outright rather than verifying a file
  the compositor never parsed.

Run verify after **every** change to a live config — generation, an incremental edit, or a
hand-applied fix — so a broken edit never silently persists.

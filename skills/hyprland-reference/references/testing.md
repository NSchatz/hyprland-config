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

Hyprland has **no offline whole-config validator**. The real test is a reload + error read:

1. `hyprctl reload` — re-reads the config files from disk and applies them. It does **not** re-run
   `exec-once` entries, so it won't relaunch your bar/daemons.
2. `hyprctl configerrors` — prints the parse errors from the currently-loaded config. **Clean =
   empty output** (it prints blank/`[""]`). Any non-blank lines are real errors. Note it always
   **exits 0**, so judge by the output, not the exit code.

So: reload, then check `configerrors` is empty. That is the definitive "it works" signal.

### Testing a single option without editing files

`hyprctl keyword <name> <value>` applies one setting to the live session immediately, e.g.
`hyprctl keyword decoration:rounding 0`. Useful to preview a value before persisting it to the
file. It does not write to disk and is reverted by the next reload.

### Isolated / nested testing (advanced)

A config can be loaded in a nested Hyprland instance without disturbing the session:
`Hyprland --config /path/to/hyprland.conf` (best inside an existing session or a headless backend
via `WLR_BACKEND=headless`). Heavier and environment-dependent; the reload+configerrors approach
is preferred for the common case.

## Safe apply → test → rollback pattern

Editing a live config risks leaving the session broken. Always:

1. **Back up** the whole `~/.config/hypr` to a timestamped copy first.
2. **Apply** the change (write the file).
3. **Test**: `hyprctl reload` then `hyprctl configerrors`.
4. **On errors → roll back**: restore the backup and reload again, so the session returns to the
   last-known-good state. Report the errors so they can be fixed and retried.
5. **On no running instance** → cannot live-test; rely on static validation and say so.

The plugin implements this:

- `skills/generate-config/scripts/verify-config.sh` — step 3 (reload + configerrors). Prints
  `VERIFY=ok|errors|skipped`; exit 0/1/2.
- `skills/generate-config/scripts/safe-apply.sh` — full cycle: install a staged config, verify,
  and auto-rollback to the backup on failure. Prints `SAFE_APPLY=ok|rolled-back|installed-untested|…`.

Run verify after **every** change to a live config — generation, an incremental edit, or a
hand-applied fix — so a broken edit never silently persists.

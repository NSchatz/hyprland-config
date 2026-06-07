# browser — gotchas

## userChrome.css is **dead** without `legacyUserProfileCustomizations.stylesheets`

The single biggest "I followed the recipe and nothing changed" failure. Firefox stopped
processing `userChrome.css` by default years ago; the pref is locked off until you flip
`toolkit.legacyUserProfileCustomizations.stylesheets` to `true`. `user.js` re-applies it on
every startup so a Firefox update that resets it self-heals. Without the pref every selector
in this component is dead.

Verify with `about:config` — the pref must be `true` AND the userChrome.css must live at
`<profile>/chrome/userChrome.css` (not at `<profile>/userChrome.css` — Firefox does NOT walk
the profile root for chrome stylesheets).

## Profile dir is dynamic — resolve via `profiles.ini`

`~/.mozilla/firefox/` contains one directory per profile with a random prefix:
`xxxxxxxx.default-release`, `yyyyyyyy.default-esr`, `zzzzzzzz.dev-edition-default`. The user
can't predict the prefix, and hardcoding `default-release` breaks on ESR / Developer Edition.
`firefox-bootstrap.sh` parses `profiles.ini` for the `Default=1` block and reads its `Path=`;
this is the only correct way. If the user has multiple profiles, the script bootstraps the
default — they pick a different profile via `--profile <dir>`.

## Restart hook needs `browser.startup.page = 3`

`firefox-restart.sh` does `pkill -x firefox` then relaunches. Firefox's session-restore writes
state on a **clean** exit only — `pkill` (SIGTERM) IS clean, but only if `browser.startup.page`
is set to `3` (restore previous session). With the default `1` (homepage), pkill + relaunch
opens the homepage and every tab is gone. `user.js` locks `browser.startup.page = 3` so the
restart hook never loses tabs.

Private windows are **not** part of session restore — they're dropped by design. Document
this in the interview when the user opts in to browser theming.

## pywalfox vs userChrome — pick one route, not both

**userChrome** (this component's default):
- engine-native: re-themes on `rice apply` via the manifest line + `firefox-restart.sh`
- offline, no add-on, no native-messaging host
- chrome theming only (tab bar, URL bar, menus) — web pages render as the site designed them
- pairs with named/manual palettes

**pywalfox** (`firefan8/pywalfox-native` on AUR + the Pywalfox add-on):
- driven by pywal's `~/.cache/wal/colors.json` (or matugen's equivalent if wired)
- chrome theming **plus** web-page content theming (a dark-reader-style invert + accent layer)
- live-reload: changing the palette through pywal triggers the add-on via native messaging
- needs the AUR package AND the add-on installed manually from addons.mozilla.org
- pairs with wallpaper / matugen palettes

Mixing them creates double-theming — pywalfox sets the same lwt-* properties this component
sets, but with `!important` on the add-on side. If the user wants both routes, **uninstall the
Pywalfox add-on** before applying the userChrome route, or vice versa.

## Chromium / Brave have no userChrome equivalent

Chromium's chrome theming requires either an extension (limited to the toolbar's accent) or
a `--enable-features=…` flag. There is no `<profile>/chrome/userChrome.css` equivalent.
Chromium's `Theme` API is the closest, but it's add-on-driven and inheritance from the
rice palette would require an extension we don't ship. Out of scope for v0.21.

## Zen, LibreWolf — Firefox forks with the same mechanism, mostly

LibreWolf works against this component's `userChrome.css` as-is — the profile path is
`~/.librewolf/`, but `profiles.ini` parsing + chrome/ subdir + the legacy pref are identical.
Zen Browser adds split-view and workspaces; its native chrome carries selectors this template
doesn't cover (`#zen-current-workspace-indicator`, `.zen-essentials-wrapper`, etc.). The
rest works. Both forks are documented follow-ups (see `packages.md` → "Other browsers").

## Brief flash on restart

`firefox-restart.sh` produces a ~1s blank-window flash as Firefox exits and re-launches. On
slow disks the flash can stretch to 3-4s. Users who hate the flash should:

- Skip the restart hook entirely (empty reload-cmd in the manifest line) and re-theme on next
  manual launch — adds the firefox row to `rice apply`'s "next launch" footer.
- Or run pywalfox instead, which re-themes the chrome live with no restart.

## Cross-references

- The two routes' technical detail → `template.md` (userChrome) and pywalfox docs upstream.
- The "applies on next launch" footer convention → `theming/engine.md`.
- The legacy-stylesheet pref history → Mozilla bug 1377259 (the pref's introduction in 2017).

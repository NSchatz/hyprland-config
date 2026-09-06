# browser — template

Opt-in browser theming. Most rices ship a half-themed desktop with an un-themed browser — one of
the largest on-screen surfaces. This component closes the gap with two routes:

| Route | When to pick | What it does | Pairs with |
|---|---|---|---|
| **userChrome** (default) | named / manual palettes; offline; no add-ons | Renders `<profile>/chrome/rice-colors.css` from `firefox.tmpl`, copies static `userChrome.css` + `user.js` once into the profile. Engine-native. | Catppuccin / Gruvbox / Nord / Tokyo Night palettes — anything `theming/palettes.md` ships. |
| **pywalfox** | wallpaper / matugen palettes; live + content theming | Browser-side extension + native messaging host that reads pywal's `colors.json` and re-themes the chrome AND injects a dark theme into web pages. Out-of-band relative to the engine; not driven by the rice manifest. | matugen / wallust engines, dynamic theming. |

The userChrome route is the **default** for v0.21. The pywalfox route is documented in
`gotchas.md` → "pywalfox vs userChrome" — pick it manually when the rice uses a wallpaper-driven
engine and content theming matters.

## Files this component owns

- [`firefox.tmpl`](./firefox.tmpl) — palette-only `:root{--rice-*}` block rendered to
  `<profile>/chrome/rice-colors.css` on every `rice apply`.
- [`userChrome.css`](./userChrome.css) — palette-agnostic mapping of `--rice-*` onto Firefox's
  lwt-* lightweight-theme custom properties + direct selectors. Copied verbatim into
  `<profile>/chrome/userChrome.css` once at install time. Re-themes pick up via `@import
  "rice-colors.css"`.
- [`user.js`](./user.js) — two prefs locked into the profile on every startup:
  `toolkit.legacyUserProfileCustomizations.stylesheets = true` (unlocks userChrome.css
  processing — without it, every selector here is dead) and `browser.startup.page = 3`
  (session restore — every `rice apply` invokes the restart hook, so tabs must come back).
  Both are recorded per profile when they are merged, and both come back off with
  `rice prefs remove` (see "The two preferences, and how to take them back off" below).
- `assets/scripts/firefox-bootstrap.sh` (lives in `assets/`, not `references/`) — resolves the
  default profile from `profiles.ini`, creates one via `firefox --headless --CreateProfile
  default-release` if missing, copies userChrome.css + user.js into the profile (idempotent —
  appends `@import` if the user already has a userChrome.css; merges user.js prefs by key),
  emits the resolved paths so `install.sh` can wire the manifest line.
- `assets/scripts/firefox-restart.sh` (lives in `assets/`) — the manifest's reload-cmd.
  No-op if Firefox isn't running; otherwise `pkill -x firefox`, poll for the profile lock to
  release, relaunch detached. Session restore brings tabs back.

## The two preferences, and how to take them back off

These two lines are the only thing this component writes that a restore cannot undo. Firefox
re-applies `user.js` at **every** start, and the browser's own Settings UI will not show either
value as changed (`moz-1543752`), so removing the theming files does not remove them: the lines
have to leave `user.js`. That is why the plugin records them and ships a command to remove them
rather than doing it silently.

| Preference | Set to | What it does | What removing it costs |
|---|---|---|---|
| `toolkit.legacyUserProfileCustomizations.stylesheets` | `true` | Makes Firefox read `userChrome.css` at all | **This plugin's browser theming stops working entirely.** The chrome goes back to the browser's default look; `rice-colors.css` and `userChrome.css` stay on disk but Firefox ignores them (`moz-1541233`) |
| `browser.startup.page` | `3` (restore previous session) | Brings tabs back after the `rice apply` restart hook restarts Firefox | Firefox opens its normal start page instead, so a `rice apply` that restarts the browser loses the open tabs |

**What is recorded.** When `firefox-bootstrap.sh` merges a preference it did not find in the
profile, it records the profile's absolute path and that key first, in
`<state>/hypr-rice/browser-prefs.tsv` (`$XDG_STATE_HOME`, else `~/.local/state`). A preference
that was **already** in the file is left at the user's value and is **not** recorded: the plugin
did not set it, so it does not offer to remove it. A preference it cannot record it does not set.

**How to remove them.**

```bash
rice prefs               # what was set, in which profile, and whether it is still set
rice prefs remove        # take exactly those lines back off
```

(`bash ~/.config/hypr-rice/firefox-prefs.sh remove` is the same command without the CLI, and
takes an optional profile path to limit it to one profile.)

The removal path is deliberately narrow, because `user.js` is a file the user may have made
their own since:

- it copies the file to a restorable backup **before** editing it and enrols that copy in a
  restore point, so the removal itself goes back with `rice restore <apply-id>`; a file it
  cannot back up it does not edit (`PREFS_SKIPPED=<path>`);
- it removes **only** the exact lines the record names for that profile, leaving every other
  line of the file byte-identical;
- a recorded preference whose line has been **changed by hand** since is left alone and reported
  (`PREF_CHANGED=<path> <key>`); the value the user chose is not this plugin's to delete;
- a profile file that is no longer there is reported by path (`PREFS_MISSING=<path>`), never
  re-created, and never stops the other profiles from being cleaned up;
- run twice, the second run reports `PREFS=nothing-to-remove` and touches nothing.

`rice restore <apply-id>` is **not** a substitute: it undoes one apply and is spent once used,
whereas these preferences keep re-applying at every browser start for as long as they sit in
`user.js`.

## Required render-manifest line

Emitted by SKILL.md A4.3 when `default_apps.browser == "firefox"` **and**
`browser_theming.opt_in == true`. The validator at A5 step 1 ERRORs on a missing line — see
`agents/hyprland-config-validator.md` → "Render-manifest completeness".

```
firefox <TAB> ~/.config/hypr-rice/templates/firefox.tmpl <TAB> <profile>/chrome/rice-colors.css <TAB> bash ~/.config/hypr-rice/firefox-restart.sh <TAB>
```

The 5th column is **empty** here (the reload-cmd actively restarts the browser, so this surface
re-themes live — it doesn't belong in the "next launch/lock" footer). The four `next-launch`
surfaces (gtk3, qt6ct) and the `next-lock` surface (hyprlock) get a non-empty 5th column so
`rice apply`'s footer can group them — see `theming/engine.md` → "Render-manifest format" for
the schema.

`<profile>` is the absolute path emitted by `firefox-bootstrap.sh` (e.g.
`~/.mozilla/firefox/xxxxxxxx.default-release`). install.sh substitutes it in when writing
templates.list — it's NOT a `{{var}}` in the .tmpl, because the .tmpl is palette-only.

## Substitution map (firefox.tmpl)

| Placeholder | Source key | Notes |
|---|---|---|
| `{{bg}}` | `palette.conf` `bg` | bare hex; the template prepends `#`. |
| `{{fg}}` | `palette.conf` `fg` | same. |
| `{{surface}}` | `palette.conf` `surface` | tab/url-bar background. |
| `{{muted}}` | `palette.conf` `muted` | inactive tab text; url-bar border. |
| `{{accent}}` | `palette.conf` `accent` | url-bar focus ring; menu hover. |
| `{{accent2}}` | `palette.conf` `accent2` | reserved for future toolbar cues. |
| `{{red}}` / `{{green}}` / `{{yellow}}` / `{{blue}}` / `{{magenta}}` / `{{cyan}}` | `palette.conf` `red`/… | exposed as `--rice-red` etc. for any user-added selector that wants them. |

## install.sh integration

The browser-theming install step has three parts:

1. **Bootstrap the profile.** Run
   `bash ~/.config/hypr-rice/scripts/firefox-bootstrap.sh` and capture the
   `FIREFOX_PROFILE=` / `FIREFOX_RICE_COLORS=` lines from stdout.
2. **Wire the manifest line.** Substitute the captured `FIREFOX_RICE_COLORS=` path into the
   firefox manifest line above and append to `~/.config/hypr-rice/templates.list`.
3. **Render the initial `rice-colors.css`.** Run `bash ~/.config/hypr-rice/render-templates.sh`
   (or just rely on the first `rice apply` after install).

See the "browser-theming opt-in" example block in `SKILL.md` A4.3.

## Cross-references

- The two routes' design trade-off (engine-native vs content theming) → `gotchas.md`.
- The App-Coverage row → `theming/apps.md` (`firefox` row).
- The reload semantics + footer behavior → `theming/engine.md` → "Render-manifest format" and
  the "needs-relaunch surfaces" footer.
- The manifest-completeness assertion → `agents/hyprland-config-validator.md`.

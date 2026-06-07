# browser

Opt-in Firefox chrome theming. v0.21 ships one route (userChrome — engine-native, palette-only)
and documents the other (pywalfox — wallpaper-engine + content theming). Both leave the
choice to the user; both are off by default.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions (opt in, restart hook, profile override). Gated on `default_apps.browser == "firefox"`. |
| `schema.md` | `answers.json` keys: `browser_theming.{opt_in, route, profile, restart_hook}` + gate conditions. |
| `template.md` | The full design: files this component owns, the manifest line, the install.sh integration recipe. |
| `firefox.tmpl` | Engine-rendered palette-only `:root{--rice-*}` block → `<profile>/chrome/rice-colors.css`. |
| `userChrome.css` | Palette-agnostic static mapping of `--rice-*` onto Firefox chrome (lwt-* properties + direct selectors). Copied once. |
| `user.js` | Two prefs locked: `legacyUserProfileCustomizations.stylesheets` and `browser.startup.page = 3`. |
| `gotchas.md` | The dead-without-the-pref trap, dynamic profile dirs, restart-flash, pywalfox vs userChrome, Chromium has no equivalent. |
| `packages.md` | (none — the static-file route needs no extra packages; pywalfox is opt-in AUR.) |
| `validation.md` | Parse checks for rice-colors.css, user.js shape, bootstrap-emitted paths, the two required prefs. |

## Where this component lands

- **Manifest line:** `firefox <TAB> ~/.config/hypr-rice/templates/firefox.tmpl <TAB>
  <profile>/chrome/rice-colors.css <TAB> bash ~/.config/hypr-rice/firefox-restart.sh <TAB>`
  emitted only when `browser_theming.opt_in == true` AND `default_apps.browser == "firefox"`.
- **Helper scripts:** `firefox-bootstrap.sh` (one-time, resolves profile + copies static
  files) and `firefox-restart.sh` (per-`rice apply` reload). Both ship under `assets/scripts/`
  and are copied to `~/.config/hypr-rice/scripts/` by `rice-init.sh`.
- **install.sh integration:** see `template.md` → "install.sh integration".
- **Validator assertion:** `agents/hyprland-config-validator.md` →
  "Render-manifest completeness".

## Cross-references

- The browser pick itself → `../default-apps/`.
- The Wayland env marker (`MOZ_ENABLE_WAYLAND`) → `../env/`.
- The reload semantics + the "needs-relaunch" footer → `theming/engine.md`.

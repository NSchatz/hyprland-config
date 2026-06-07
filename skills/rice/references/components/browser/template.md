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
- `assets/scripts/firefox-bootstrap.sh` (lives in `assets/`, not `references/`) — resolves the
  default profile from `profiles.ini`, creates one via `firefox --headless --CreateProfile
  default-release` if missing, copies userChrome.css + user.js into the profile (idempotent —
  appends `@import` if the user already has a userChrome.css; merges user.js prefs by key),
  emits the resolved paths so `install.sh` can wire the manifest line.
- `assets/scripts/firefox-restart.sh` (lives in `assets/`) — the manifest's reload-cmd.
  No-op if Firefox isn't running; otherwise `pkill -x firefox`, poll for the profile lock to
  release, relaunch detached. Session restore brings tabs back.

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

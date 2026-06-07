# browser — schema

The keys this component owns in `answers.json`. Empty / unset = browser theming is **off**;
the rice ships an un-themed browser, the manifest line is not emitted, and the validator
does not assert it.

## Keys

```json
{
  "browser_theming": {
    "opt_in": true,
    "route": "userChrome",
    "profile": null,
    "restart_hook": true
  }
}
```

| Key | Type | Default | Meaning |
|---|---|---|---|
| `opt_in` | bool | `false` | Master gate. Must be `true` for any manifest line, bootstrap, or validator assertion to fire. |
| `route` | enum | `"userChrome"` | One of `"userChrome"` (v0.21 default) or `"pywalfox"` (documented, not wired). Future routes (zen, librewolf, chromium-extension) will register here. |
| `profile` | string \| null | `null` | Override the auto-resolved Firefox profile. If null, `firefox-bootstrap.sh` parses `~/.mozilla/firefox/profiles.ini` and uses the `Default=1` block. Absolute path or basename (`xxxxxxxx.default-release`). |
| `restart_hook` | bool | `true` | If `true`, the manifest line's reload-cmd is `bash ~/.config/hypr-rice/firefox-restart.sh` (re-theme triggers a browser restart with session restore). If `false`, the reload-cmd is empty and the surface goes in the "applies on next launch" footer. |

## Gate conditions

| Behavior | Condition |
|---|---|
| Emit firefox manifest line | `browser_theming.opt_in == true` AND `default_apps.browser == "firefox"` |
| Run `firefox-bootstrap.sh` at install | same |
| Set 5th column to `next-launch` (footer-tracked) | `browser_theming.opt_in && !browser_theming.restart_hook` |
| Validator asserts manifest line | `browser_theming.opt_in == true` (default_apps.browser must also be firefox — if mismatched, validator WARNS rather than ERRORs because the user may be theming a non-default browser) |

## Component owners

| Owner | Reads | Writes |
|---|---|---|
| `hyprland-interviewer` | the `default_apps.browser == "firefox"` pick (component 8); offers the browser-theming opt-in as a follow-up question | `.browser_theming.opt_in`, `.browser_theming.route`, `.browser_theming.restart_hook` |
| `hyprland-component-writer` (`browser`) | `.browser_theming.*` | renders `firefox.tmpl` against the captured profile path, copies `userChrome.css` + `user.js`, appends the manifest line via the bootstrap script's emitted paths |
| `hyprland-package-installer` | `.browser_theming.opt_in && .browser_theming.route == "userChrome"` | nothing (no extra packages) — see `packages.md` |
| `hyprland-config-validator` | `.browser_theming.opt_in`, the manifest contents | ERRORs if the firefox manifest line is missing when the gate holds |

## Examples

**User picks Firefox + opts in to userChrome theming (the default path):**
```json
{
  "default_apps": { "browser": "firefox" },
  "browser_theming": {
    "opt_in": true,
    "route": "userChrome",
    "profile": null,
    "restart_hook": true
  }
}
```

**User wants browser theming on a specific (non-default) profile:**
```json
{
  "default_apps": { "browser": "firefox" },
  "browser_theming": {
    "opt_in": true,
    "route": "userChrome",
    "profile": "abc12345.dev-edition-default",
    "restart_hook": true
  }
}
```

**User opts in but hates the restart flash — accept "next launch" footer instead:**
```json
{
  "browser_theming": {
    "opt_in": true,
    "route": "userChrome",
    "restart_hook": false
  }
}
```

## What's NOT in scope for v0.21

- Per-website content theming (pywalfox would handle this; deferred).
- Chromium / Brave chrome theming (no userChrome equivalent — see `gotchas.md`).
- Zen / LibreWolf bootstrap (mechanically possible, deferred per `packages.md`).

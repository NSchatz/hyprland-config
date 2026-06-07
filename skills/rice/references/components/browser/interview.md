# browser — interview

This component's sub-questions fire **only when** `default_apps.browser == "firefox"` (the
master gate). The opt-in is presented as a follow-up to the browser pick — most users won't
notice it, the small minority who care about a coherently themed browser opt in.

## Sub-questions

### Q1: opt in to browser theming

```
Question: "Theme Firefox's chrome (tabs / URL bar / menus) from the rice palette?
           This installs a userChrome.css + a small pref overlay into your Firefox
           profile. Re-themes pick up via a brief browser restart (session restore
           brings every tab back; private windows are not restored)."
Options:
  - "Yes — apply rice palette to Firefox chrome"      → opt_in=true,  route=userChrome
  - "No — leave Firefox at its default theme"         → opt_in=false  [recommended default]
  - "Yes — but I use pywalfox / wallpaper theming"    → opt_in=true,  route=pywalfox
                                                       (route documented but not auto-wired in v0.21;
                                                        we tell the user to install pywalfox manually)
```

Default off — most users haven't asked for browser theming. The opt-in question only fires
when `default_apps.browser == "firefox"` so it doesn't appear for Chromium / Brave / Zen
pickers (who get a separate note in the gotchas).

### Q2 (only if opt_in == true): restart hook

```
Question: "When you change the rice theme, should Firefox restart automatically?
           Restart: ~1 second blank-window flash, all tabs come back via session
           restore. No restart: Firefox keeps the old palette until you close + reopen
           it; rice apply will list firefox under 'applies on next launch'."
Options:
  - "Yes — restart Firefox on each rice apply"          → restart_hook=true   [default]
  - "No — wait for the next launch"                      → restart_hook=false
```

### Q3 (only if opt_in == true): non-default profile?

Skip by default — only ask if `firefox-bootstrap.sh --dry-run` detects more than one profile
in `profiles.ini`. When asked:

```
Question: "We found N Firefox profiles. Bootstrap which one?"
Options:
  - "<default-profile-name> (current default)"           → profile=null  [default]
  - "<other-profile-name>"                               → profile="<name>"
  - …
```

## Skip rules

| Skip when… | Why |
|---|---|
| `default_apps.browser != "firefox"` | The component only handles Firefox in v0.21. Don't ask about themings the user can't apply. |
| Firefox isn't installed | The bootstrap will fail; defer until after install. The interview should still ask (so the install batch includes browser theming setup), but show an info note. |
| User declined the install batch in A5 | The bootstrap can't run without `firefox`. Manifest line is still written; bootstrap deferred to first manual `bash ~/.config/hypr-rice/scripts/firefox-bootstrap.sh`. |

## What the interviewer must NOT ask

- Don't ask for the profile path before running the bootstrap. The script resolves it from
  `profiles.ini`. If the user has only the default profile (the dominant case), Q3 doesn't
  fire at all.
- Don't ask about theme/scheme names — those come from the look-feel component upstream.
  The browser inherits whatever palette is active.
- Don't ask about `legacyUserProfileCustomizations.stylesheets` — `user.js` sets it
  unconditionally; the user doesn't need to know.

## Defaults the interviewer applies silently

| Key | Silent default | Note |
|---|---|---|
| `route` | `"userChrome"` | The only fully-wired route in v0.21. |
| `profile` | `null` | Bootstrap resolves the default. |
| `restart_hook` | `true` | The friendlier default — re-themes are immediately visible. |

## Cross-references

- The browser pick itself → `../default-apps/interview.md`.
- The interview's gating / ordering → `../../_interview-protocol.md`.
- The full schema → `schema.md`.

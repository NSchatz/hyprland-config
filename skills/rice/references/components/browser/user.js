// Installed once into <profile>/user.js by firefox-bootstrap.sh. user.js
// re-applies these prefs on every browser startup, so a Firefox update that
// flips them back to default is self-healing.
//
// 1. legacyUserProfileCustomizations.stylesheets — unlocks userChrome.css
//    + userContent.css processing. Required for any of the chrome theming
//    in this component to take effect.
// 2. browser.startup.page = 3 — restore previous session on startup. The
//    Issue-15 firefox-restart.sh reload hook pkills + relaunches; without
//    session restore the user loses every open tab on each `rice apply`.

user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.startup.page", 3);

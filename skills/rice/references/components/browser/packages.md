# browser — packages

This component installs nothing of its own — the browser itself comes from
`default-apps/packages.md` (`firefox` from `extra`, `chromium` / `brave` / `zen-browser` from
their respective channels). The userChrome route ships only static CSS + a JS pref file +
two helper scripts; no extra packages.

The **pywalfox** route — documented but not implemented here in v0.21 — would need an extra
package:

| Package | Channel | Notes |
|---|---|---|
| `pywalfox-native` | AUR | The native-messaging host. Also needs the `Pywalfox` add-on from addons.mozilla.org (installed in-browser, not via pacman). |

The user installs Pywalfox manually if they pick that route; the rice doesn't auto-install
AUR packages unless the user opts in to the install batch. See `gotchas.md` → "pywalfox vs
userChrome" for the route comparison.

## What the bootstrap script needs

`firefox-bootstrap.sh` calls Firefox with `--headless --no-remote --CreateProfile
default-release` when no `profiles.ini` is found. That requires `firefox` to be installed —
not assumed. The script bails with `ERROR: firefox not installed` if the binary is missing,
so the install batch can sequence this after `pacman -S firefox`.

## Other browsers — not in v0.21

Chromium / Brave / Zen / LibreWolf use the same `userChrome.css` mechanism in principle (Zen
is a Firefox fork; LibreWolf inherits Firefox's chrome layer; Chromium and Brave do **not**
support userChrome — chrome theming requires extensions or `--enable-features` flags). For
v0.21 the component is firefox-only. Adding Zen is a follow-up: the bootstrap script's
`profiles.ini` path becomes `~/.zen/profiles.ini`, the userChrome.css selectors are mostly
the same, but Zen's split-view + workspaces add selectors this template doesn't cover.
LibreWolf works against this template as-is — the profile path is `~/.librewolf/`.

## Cross-references

- The browser pick itself → `../default-apps/packages.md`.
- Bootstrap-script invocation → `template.md` → "install.sh integration".
- The Wayland-marker env var (`MOZ_ENABLE_WAYLAND`) → `../env/template.md`.

# vicinae - launcher

Everything this plugin knows about authoring **vicinae** for the `launcher` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template

---

## Template


Qt 6 Raycast-for-Linux. Config file is **`settings.json`** (JSONC — JSON with comments
allowed); the daemon is started via `vicinae server --replace` (typically autostarted), and
the window is controlled with `vicinae open|close|toggle`. Dmenu mode is the `vicinae dmenu`
subcommand (not a `--dmenu` flag).

Run `vicinae config default` to dump the fully-annotated default `settings.json` — that's the
authoritative key reference; the schema evolves between releases. Themes follow vicinae's own
internal format (not GTK CSS, not rasi); the engine writes a minimal theme block into
`settings.json` mapping `accent`, `bg`, `fg`, `surface` into vicinae's schema, and the user
picks built-in extensions through vicinae's own UI. **The engine themes only what vicinae
exposes** — geometry/layout knobs are largely fixed by the app.


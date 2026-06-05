# input

Keyboard, mouse, touchpad, and gestures. Lands as `~/.config/hypr/input.conf` — a single
`input {}` block (with an optional `touchpad {}` sub-block) plus a list of `gesture =` lines
(0.45+) or a `gestures {}` block (pre-0.45). Sourced from `hyprland.conf` next to the other
top-level configs.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 2a–2g, split across two `AskUserQuestion` calls (4 + 3). |
| `schema.md` | The `answers.json` keys this component owns under `input.*`. |
| `template.md` | The `input.conf` template — `input {}` block, `touchpad {}` sub-block, gesture lines (0.45+) and the pre-0.45 fallback. |
| `gotchas.md` | `follow_mouse` semantics (the `1` vs `2` confusion), gesture-keyword version gate, desktop-vs-laptop touchpad gating. |
| `packages.md` | None — input is built into Hyprland. |

## Where this component lands

- **Hyprland config:** `~/.config/hypr/input.conf`, sourced from `hyprland.conf` (see
  `components/keybinds/template.md` for the source-line block).
- **Variables block:** none — `input` doesn't own any `$var` lines in `hyprland.conf`.
- **No companion daemons:** unlike `monitors` (which can pull in `hyprpaper`) or
  `notifications` (which pulls in `mako`/`dunst`), input is pure Hyprland config; no extra
  packages get installed because of these answers.

## Related components

- [`laptop`](../laptop/) — the laptop opt-in gate. If the user answers "no laptop" there, the
  touchpad sub-questions (2f, 2g) in this component self-skip. Detection
  (`scripts/detect-version.sh` → `IS_LAPTOP`) seeds the default ordering but does **not**
  filter the question — see `_interview-protocol.md`.
- [`keybinds`](../keybinds/) — owns `hyprland.conf` (including the `source = ~/.config/hypr/input.conf` line).
- [`_shared/version-matrix.md`](../../_shared/version-matrix.md) — the 0.45+ cliff for the
  `gesture =` keyword API.

# input — gotchas

## `follow_mouse = 1` is focus-follows-mouse — NOT `2`

The single most common misread of the Hyprland input docs. The values:

| Value | Behavior |
|---|---|
| `0` | **Click to focus.** The pointer never changes focus. |
| `1` | **Focus follows mouse** — moving the pointer over a window focuses it. The Hyprland default. This is what users mean when they ask for "sloppy focus" / "focus follows mouse." |
| `2` | **Detached / loose** — the cursor can scroll and click the window it hovers, **but keyboard focus only changes on click**. Hovering does NOT refocus. This is the *opposite* of what most users mean. |
| `3` | Full-loose variant of `2` (rare). |

When the user says "focus should change as I move the mouse over a window," record
`follow_mouse = 1`. Do not record `2` unless the user explicitly describes the detached
behavior (e.g. "I want to scroll the inactive window without giving it keyboard focus").

The interview question (2d in `interview.md`) presents these in plain English to avoid the
trap; record the integer that matches the prose the user picked, not whatever number "sounds
higher / more focused."

## The `gesture =` keyword API requires Hyprland 0.45+

The 0.45 release replaced the `gestures { workspace_swipe = … }` block with a per-gesture
`gesture = FINGERS, DIRECTION, ACTION` keyword form. Branch on `hypr_version` from
`answers.json` (top-level, seeded by `scripts/detect-version.sh` — see
`_shared/version-matrix.md`):

- `≥ 0.45` → emit `gesture = …` lines (one per selected gesture). The `gestures {}` block is
  still accepted as legacy, but new configs should use the keyword form.
- `< 0.45` → emit a `gestures {}` block. Only `workspace-swipe` maps; the other four short-names
  in `input.touchpad_gestures` have no pre-0.45 equivalent and are dropped with a comment in
  `input.conf`. See `template.md` → "pre-0.45 fallback."

The validator (`hyprland-config-validator`) flags a `gesture =` line emitted against
`hypr_version < 0.45` as a parse-time error.

## Omit the `touchpad {}` sub-block entirely on desktops

The `touchpad {}` block inside `input {}` is harmless on a system with no touchpad — Hyprland
ignores it — but it's noise in `input.conf` and confuses users hand-editing later. If the user
picked "No touchpad / desktop" in 2f, omit the entire `touchpad {}` sub-block from
`input.conf`. The template uses the `has_touchpad` boolean (see `template.md`); set it to
`false` and the section drops.

Same for the gesture section: empty `input.touchpad_gestures` → no `gesture =` lines, no
`gestures {}` block.

## Touchpad detection vs gestures gating — detection ≠ filter

`scripts/detect-version.sh` (and the broader detection step) sets `IS_LAPTOP=1` / `IS_LAPTOP=0`
based on chassis. **This seeds default ordering only.** From `_interview-protocol.md`:

> Detection is for defaults, not filters. … `HAVE_<tool>=1`/`MISSING_<tool>=1` flags from
> detection are used only to annotate the install batch; they do not reorder, hide, or
> default-bias the options.

For input specifically:

- 2f (touchpad) is **always asked**. `IS_LAPTOP=1` lists "Natural scroll + tap-to-click on"
  first; `IS_LAPTOP=0` lists "No touchpad / desktop" first. Either way the user confirms.
- 2g (gestures) is gated on the **answer to 2f**, not on `IS_LAPTOP`. If the user (on a desktop)
  says they actually have a touchpad, 2g is still asked.
- If the user (on a laptop) says "no touchpad" in 2f, 2g is skipped and
  `input.touchpad_gestures` is recorded as `[]`.

## `kb_options` is comma-joined, not space-joined

Hyprland passes `kb_options` to xkb verbatim; xkb expects comma-separated tokens. The template
emits `kb_options = caps:swapescape,grp:win_space_toggle` — not space-separated. Empty array →
`kb_options =` (blank value, line still present; Hyprland accepts this).

## `repeat_rate` / `repeat_delay` defaults — only emit non-defaults

Hyprland's compiled-in defaults are `repeat_rate = 25` and `repeat_delay = 600`. When the user
picks the "Default" option in 2c, **omit both lines** from `input.conf` — don't write
`repeat_rate = 25` redundantly. Keeps the file readable and means future Hyprland default
changes flow through. The template's `non_default_repeat_*` booleans handle this.

## Mouse `sensitivity = 0` is a no-op — omit the line

Same logic: `sensitivity = 0.0` is the libinput default. The template's
`non_default_sensitivity` boolean drops the line when `mouse_sensitivity == 0.0`.

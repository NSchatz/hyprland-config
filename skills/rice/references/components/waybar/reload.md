# waybar — reload

Waybar reloads in place via `SIGUSR2` — both `config.jsonc` and `style.css` are re-read with no
restart and no flash. CSS-only edits don't even need the signal when `reload_style_on_change: true`
is in `config.jsonc` (the default — see `template.md`).

## Recipe

```bash
# 1. Validate FIRST. A malformed config.jsonc makes the bar silently fail to appear (gotchas.md).
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$HOME/.config/waybar/config.jsonc" \
  || { echo "ERROR: waybar config.jsonc is not valid JSON; not signaling" >&2; exit 1; }

# 2. Signal only if waybar is actually running. pkill returns non-zero on no match —
#    swallow it so "waybar wasn't running" isn't treated as a reload failure.
pkill -SIGUSR2 -x waybar || true
```

That's it. No restart, no `disown`, no terminal output from waybar itself.

## When `SIGUSR2` isn't enough

A handful of `config.jsonc` keys can't be re-applied in place — waybar reads them at startup only.
If any of these changed, do a hard restart instead:

| Key | Why |
|---|---|
| `position` (`top` ↔ `bottom` ↔ `left` ↔ `right`) | Layer-shell anchor is set at surface creation. |
| `exclusive` | Surface exclusivity is set at creation. |
| `mode` (`dock` ↔ `overlay`) | Layer is set at creation. |
| `gtk-layer-shell` | Initial protocol negotiation only. |
| Going from one bar to a JSON **array** of named bars (`dual`) | Surface count changes. |
| Adding `start_hidden` / `on-sigusr1` toggle wiring | Read at startup. |

Hard restart:

```bash
pkill -x waybar || true
sleep 0.2
waybar >/dev/null 2>&1 &
disown
```

This is the same shape [`autostart`](../autostart/) uses for its `exec-once`. The rice apply
script should pick the soft vs hard path based on which keys actually changed between the previous
and new `answers.json`.

## CSS-only edits

With the recipe's `"reload_style_on_change": true` in `config.jsonc`, waybar **watches**
`style.css` (and the `@import`-ed `colors.css`) and reloads CSS automatically on save. The
`SIGUSR2` call is still safe — it's idempotent and triggers the same code path. When the engine
re-themes (palette change → new `colors.css`), no signal is needed; waybar picks up the change
within ~100ms.

If `reload_style_on_change` is **off** in someone's older config, the rice writer should add it on
its next pass.

## `SIGUSR1` — visibility toggle

`pkill -SIGUSR1 -x waybar` toggles the bar's visibility. It's bound from
[`keybinds`](../keybinds/) (typically `SUPER+B`) when the user picked the `bar-toggle` extra; it's
**not** part of the reload flow. Don't conflate the two signals.

## Reload contract for the rice engine

The engine's per-component reload manifest entry for waybar looks like:

```
waybar  waybar.tmpl  ~/.config/waybar/colors.css  pkill -SIGUSR2 -x waybar || true
```

The reload command is **always** wrapped in `|| true` because waybar may legitimately not be
running yet (first apply, before the autostart fires) and that's not a failure.

## Cross-references

- The signal targets [`autostart`](../autostart/)'s `exec-once = waybar` line — there's no
  separate process manager.
- Validation that runs **before** this reload → `validation.md`.
- Reasons a soft reload can fail silently → `gotchas.md`.
- The 12-name palette `colors.css` carries → [`_shared/colors-contract.md`](../../_shared/colors-contract.md).

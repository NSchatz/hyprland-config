# notifications — interview

Four sub-questions, **one `AskUserQuestion` call** (within the ≤ 4 cap). Every sub-question is
asked — see `_interview-protocol.md`, strict no-defaulting. The `(default)` marker reorders
options; it does not authorize skipping.

The notification daemon is a dedicated group (separate from `widgets`) because the picks reach
into autostart, packages, the rice colors-file render, and downstream Hyprland blur rules. **Only
one** daemon can hold the D-Bus name — flag the choice early.

## Sub-questions

**9a. Daemon** → `mako` **(default)** · `dunst` · `swaync` · `none`. Notes the user sees:
- `mako` — Wayland-native, minimal, INI config (`~/.config/mako/config`). One file holds the
  layout + colors + per-urgency overrides. The default if no widget shell owns notifications.
- `dunst` — the maximally tweakable veteran. INI sections (`[global]`, `[urgency_low]`, …) in
  `~/.config/dunst/dunstrc`. D-Bus activatable, so `exec-once` is optional.
- `swaync` (SwayNotificationCenter) — adds a slide-out **control center** panel (DND toggle, MPRIS
  card, sliders, quick toggles). GTK app: `config.json` (behaviour + widgets array) + `style.css`
  (GTK CSS). Pair with a `custom/notification` waybar module to surface the count.
- `none` — pick this when a full widget shell (group 7 — eww/ags/quickshell/hyprpanel/turnkey)
  ships its own notification daemon. Picking `none` here means rice writes no notification config
  and adds no `exec-once`.

**9b. Position** → Top-right **(default)** · Top-center · Top-left · Bottom-right. The screen
corner toasts anchor to. Renders as `anchor` (mako), `origin` + `offset` (dunst), or
`positionX`/`positionY` (swaync).

**9c. Default timeout** → `5s` **(default)** · `3s` (snappy) · `10s` (relaxed) · `Never`
(manual dismiss only). Critical-urgency notifications **always** override this to `0` (never
auto-dismiss) — that's a styling-library invariant, not a user setting. See `styling.md`.

**9d. Behavior** *(multi-select)* — `group-by-app` **(on by default)** · `app-icons`
**(on by default)** · `dnd-bind` **(on by default — adds a `bind = $mainMod, N, exec, makoctl
mode -t do-not-disturb` / equivalent)** · `max-visible-5` (cap on-screen toasts at ~5). Every
item is offered every run.

## Gating on `none`

If 9a returns `none`, **record `daemon: "none"` and skip 9b–9d entirely** — they're moot. The
component is done; downstream writers branch on `daemon == "none"` to emit no files and no
`exec-once`. This is the only sub-question that gates the rest of the component (the strict-asking
rule allows daemon-`none` short-circuit because the subsequent picks would have nothing to write
to).

## Record paths

After the call, persist with `record-answer.sh`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" notifications.daemon mako
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" notifications.position top-right
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" notifications.timeout --json 5
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" notifications.behavior --json '["group-by-app","app-icons","dnd-bind"]'
```

`timeout` is recorded as a JSON **number** (seconds), with `0` for the "Never" pick. The
behavior array is the canonical multi-select shape used across components.

If 9a was `none`:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" notifications.daemon none
# skip 9b–9d entirely
```

## Cross-references

- Schema → `schema.md`
- Per-daemon recipes → `template.md`
- Styling-technique library (anatomy, urgency, swaync widgets) → `styling.md`
- Colors-file variable names → `../../_shared/colors-contract.md`
- The DND bind (`bind = $mainMod, N, exec, …`) → `../keybinds/template.md`
- The `exec-once = <daemon>` line → `../autostart/template.md`
- The swaync `layerrule` blur block → `../window-rules/template.md`
- The waybar `custom/notification` module → `../waybar/template.md`
- Packages → `packages.md`

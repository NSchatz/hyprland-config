# waybar — interview

Fourteen sub-questions (6a–6n) split across **four `AskUserQuestion` calls** — the
`AskUserQuestion` cap is 4, and this component sits right at the cap on all four passes. Walk every
call; never collapse them just because a wallpaper or `$ARGUMENTS` hints at an answer.
[`_interview-protocol.md`](../../_interview-protocol.md) is the source of the "strict, ask every
sub-question" rule.

The four calls are: **basics** (strategy/form/height) → **design · shape** (archetype, corner,
transparency, depth) → **design · color & state** (workspace indicator, accent strategy, accent
application, motion) → **content** (modules, grouping, clock format).

> **Design questions live here, not in `look-feel`.** Archetype / corner / transparency / accent /
> motion describe the **bar surface**, not the compositor decorations on windows.
> [`look-feel`](../look-feel/) owns gaps, window rounding, window blur, animations on windows. They
> share the palette ([`_shared/colors-contract.md`](../../_shared/colors-contract.md)), not the
> decoration knobs.

The library every option label maps onto is `styling.md` in this same folder — the seven
archetypes, the ~55-config technique catalog, and the bar-form / dock / vertical recipes.

## Strategy gate (6a)

If 6a is `full-shell` or `hyprpanel`, **stop after call 1** — the bar look is owned by
[`widgets`](../widgets/). Record `bar.strategy` and move on. The rest of this file only applies when
`bar.strategy` ∈ `{waybar, waybar+widgets}`.

## Call 1 — basics

**6a. Bar & shell strategy** — `waybar` *(default)* · `waybar+widgets` (keep waybar, add eww
floating widgets / swaync center — configured in group 7) · `full-shell` (Quickshell or AGS/Astal —
end-4/caelestia; skip the rest of this group, do group 7) · `hyprpanel` (turnkey panel, own config
model — group 7) · `none`.

**6b. Form & position** — `top` horizontal *(default)* · `bottom` (dock feel) · `vertical-left` ·
`vertical-right` · `dual` (top+bottom). Vertical and dual change the whole layout — see
`styling.md` → *Bar form*.

**6c. Height & density** — Standard ~34px *(default)* · Compact ~26–28px · Tall ~40–44px. *On
vertical bars this becomes column **width** ~32–44px.*

## Call 2 — design · shape

The look language. `styling.md` → *Archetypes* and *Battle-tested techniques* back each option.

**6d. Shape archetype** — `floating-islands` (transparent bar, three translucent rounded groups —
the dominant modern look) *(default)* · `separated-pills` (every module its own capsule) ·
`single-lozenge` (whole bar one outlined capsule) · `edge-to-edge` (flush, square, minimal) ·
`powerline` / `dock` (long tail — `styling.md` → *Powerline*, *Dock/shelf*).

**6e. Corner style** — Soft pills ~12px *(default)* · Full stadium/capsule (oversized radius, e.g.
`border-radius: 7rem`/`999px`) · Subtle ~4px · Square `0`.

**6f. Transparency** — Translucent ~0.8 + blur *(default)* · Glassy ~0.5 + blur · Frosted (low
~0.2 alpha + hairline border + drop shadow) · Opaque. *Any non-opaque pick requires the layerrule
blur block in [`window-rules`](../window-rules/) — see `gotchas.md`.*

**6g. Depth / elevation** — Flat *(default)* · Soft drop shadow (floating) · Border ring (2px
accent outline) · Inset glow.

## Call 3 — design · color & state

**6h. Workspace indicator** — Pill-fill active, tinted accent *(default)* · Underline
(`border-bottom`) · Dots (filled vs hollow glyph) · Plain numbers. (Variants in `styling.md`:
nerd-icon glyphs, opacity-only, outline-border, growing pill, gradient/skew.)

**6i. Accent strategy** — Single accent (active ws + one or two signal modules) *(default)* ·
Per-module hue (each module its own color) · Monochrome (accent only on active ws) ·
Semantic-state-only (color only on warning/critical/charging).

**6j. Accent application** — Accent as glyph/text color on a dark bar *(default)* · Accent as pill
**background** with dark text (the "inverted candy pill" look).

**6k. Motion** — Subtle: hover fades + state cues (battery-critical blink, urgent pulse, mpris
glow) *(default)* · Static (no animation) · Springy/animated (cubic-bezier overshoot, breathing
pulses).

## Call 4 — content

**6l. Modules** — *multi-select*. Sensible-set checked: `workspaces` *(on)*, `window` *(on)*,
`clock` *(on)*, `pulseaudio` *(on)*, `network` *(on)*, `cpu`, `memory`, `temperature`, `battery`
*(on if `IS_LAPTOP=1`)*, `tray` *(on)*, `mpris`, `bluetooth`, `idle_inhibitor`,
`custom/notification` *(on iff `notifications.daemon == "swaync"`)*, `updates`, `weather`. Match
on-clicks to chosen tools — `network → nm-connection-editor`, `pulseaudio → pavucontrol`,
`bluetooth → blueman-manager`. Drop the module entirely if the tool isn't installed.

**6m. Module grouping** — `inline` *(default)* · `drawer` (collapse cpu/mem/temp — and
volume/brightness — behind a `group/drawer` that reveals on hover/click; best on narrow/vertical
bars; can hold GTK sliders) · `powerline` (chained-arrow separators welding modules into one
strip).

**6n. Clock format** — `HH:MM` 24-hour + date tooltip *(default)* · 12-hour `hh:MM AM` · date
inline.

## Vertical & dual branches

- **If 6b == `vertical-left` / `vertical-right`:** prefer icon-only or two-line `\n` formats
  (`clock {:%H\n%M}`), `rotate: 90/270` on text-bearing modules, vertical sliders in drawers, and
  round only the inward edge (`border-radius: 0 6px 6px 0` for left, `6px 0 0 6px` for right). See
  `styling.md` → *Vertical bar*.
- **If 6b == `dual`:** put chrome on top (clock, tray, system, notifications) and **workspaces +
  `wlr/taskbar` + sensors** on the bottom — emitted as a JSON **array of named bars**
  (`"name": "top"` / `"bottom"`). See `styling.md` → *Dual bar*.

## Record paths

After every call, persist with `record-answer.sh`:

```bash
# Call 1
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" bar.strategy     waybar
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" bar.form         top
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" bar.height       --json 34

# Call 2
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" bar.archetype    floating-islands
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" bar.corner       rounded
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" bar.transparency translucent
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" bar.depth        flat

# Call 3
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" bar.workspace_indicator pill-fill
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" bar.accent_strategy     single
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" bar.accent_application  text
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" bar.motion              smooth

# Call 4
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" bar.modules \
  --json '["workspaces","window","clock","pulseaudio","network","cpu","memory","tray"]'
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" bar.grouping     inline
bash "$CLAUDE_PLUGIN_ROOT/scripts/record-answer.sh" "$staging/answers.json" bar.clock_format 24h-date-tooltip
```

If 6a short-circuits (`full-shell` / `hyprpanel` / `none`), only record `bar.strategy` and let the
schema's defaults stand for the rest (downstream readers branch on `strategy`).

## Cross-references

- Schema → `schema.md`
- Recipe (`config.jsonc` + `style.css`) → `template.md`
- Design library every option draws on → `styling.md`
- JSON-parse and CSS-balance rules before reload → `validation.md`
- Reload (`pkill -SIGUSR2`) → `reload.md`
- Packages → `packages.md`
- Colors contract (the 12 `@define-color` names rice writes) →
  [`_shared/colors-contract.md`](../../_shared/colors-contract.md)

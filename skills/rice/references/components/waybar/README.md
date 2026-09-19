# waybar

The status bar — `~/.config/waybar/config.jsonc` (modules + behavior) and `~/.config/waybar/style.css`
(look) plus the `colors.css` the rice engine writes. This is the **heaviest visual component** in the
interview: 4 `AskUserQuestion` calls (basics + design·shape + design·color/state + content), a
JSON-parse foot-gun (trailing commas / unbalanced braces silently kill the bar), an MDI-glyph
foot-gun, and the full ~466-line styling reference lives here in `styling.md`.

This is also where waybar's **design** lives — the archetype, corner, transparency, accent strategy
and motion are *all asked here*, not in [`look-feel`](../look-feel/). `look-feel` only owns the
compositor's own decorations (gaps, rounding, blur, animations on **windows**).

## What to read

waybar cannot shard by tool - waybar IS the tool - but its look is chosen the same way: one of
seven archetypes, named by `bar.archetype`. A writer emits ONE. Read the shared recipe set plus
**only** that archetype's file.

**Always:** `template.md` · `styling.md` · `gotchas.md` · `validation.md` · `reload.md`
**Plus exactly one** of:

| `bar.archetype` | Read |
|---|---|
| `floating-islands` (default) | [`looks/floating-islands.md`](looks/floating-islands.md) |
| `separated-pills` | [`looks/separated-pills.md`](looks/separated-pills.md) |
| `single-lozenge` | [`looks/single-lozenge.md`](looks/single-lozenge.md) |
| `edge-to-edge` | [`looks/edge-to-edge.md`](looks/edge-to-edge.md) |
| `minimal-mono` | [`looks/minimal-mono.md`](looks/minimal-mono.md) |
| `powerline` | [`looks/powerline.md`](looks/powerline.md) |
| `dock` | [`looks/dock.md`](looks/dock.md) |

**Plus, only when `bar.form` is not a single horizontal bar:**
[`forms/vertical-dual-dock.md`](forms/vertical-dual-dock.md). A standard top or bottom bar needs
none of it.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 6a–6n across **4** `AskUserQuestion` calls. The strategy gate (6a) can short-circuit to widgets/HyprPanel; otherwise walk all 14. |
| `schema.md` | The `bar.*` slice of `answers.json` — strategy, form, height, archetype, corner, transparency, workspace indicator, accent strategy/application, motion, modules. |
| `template.md` | The recipe — the default `config.jsonc` (modules, on-clicks, format strings, the MDI glyph table) and the shared `style.css` parts (workspace indicator, per-module hues, dividers). The per-archetype `style.css` skeletons live in `looks/`. References [`_shared/colors-contract.md`](../../_shared/colors-contract.md) for the 12 `@define-color` names. |
| `styling.md` | The cross-archetype design library — what you're styling, the design anatomy, every harvested technique from ~55 community configs, system-module recipes, pitfalls. Per-archetype material lives in `looks/`; bar-form material in `forms/`. |
| `gotchas.md` | JSONC parses comments but trailing commas / unbalanced braces silently kill the bar; the MDI glyph linter strip; plugin dispatchers in module on-clicks; swaync/mako daemon mutex; backlight-only-when-it-exists; layer-namespace blur cross-dep. |
| `validation.md` | What the validator runs before reload — `json.load` parse, balanced CSS braces, no plugin dispatchers, layerrule namespace match. |
| `packages.md` | `waybar` itself plus the on-click tools waybar is responsible for: `pavucontrol`, `nm-connection-editor`, `blueman-manager`. |
| `reload.md` | `pkill -SIGUSR2 waybar` (only if running, JSON-parse first). With `reload_style_on_change: true`, CSS-only edits also reload. |

## Where this component lands

- **On disk:** `~/.config/waybar/config.jsonc` + `~/.config/waybar/style.css` + the rice-emitted
  `~/.config/waybar/colors.css`.
- **Autostart:** `exec-once = waybar` lives in [`autostart`](../autostart/), not here.
- **Hyprland blur:** the `layerrule { name = blur-waybar; match:namespace = waybar; blur = true }`
  block lives in [`window-rules`](../window-rules/) but is **required** whenever this component sets
  `bar.transparency` to anything but `opaque` — see `gotchas.md`.

## Related components

- [`notifications`](../notifications/) — **D-Bus mutex**. The waybar `custom/notification` module
  drives `swaync-client`; if `bar.modules` contains it, the notification daemon **must** be
  `swaync` (not `mako`/`dunst`). The notifications component's interview captures the daemon pick;
  this component reads it back when deciding whether to emit `custom/notification`.
- [`widgets`](../widgets/) — a full widget shell (Quickshell / AGS-Astal / HyprPanel) **replaces**
  waybar. When `bar.strategy` ∈ `{full-shell, hyprpanel}`, this component collapses to question 6a
  and the whole bar look is owned by `widgets` instead.
- [`launcher`](../launcher/) — the sister floating-glass surface. Use the same archetype + corner +
  transparency answers so the launcher pill matches the bar pills visually.
- [`look-feel`](../look-feel/) — borders/rounding on **windows** use the same palette
  (`@accent`/`@accent2`) but are configured separately. The two surfaces share colors, not radii.
- [`autostart`](../autostart/) — owns the `exec-once = waybar` line.
- [`window-rules`](../window-rules/) — owns the `layerrule` block that makes translucency look right.
- [`fonts`](../../theming/fonts.md) — the Nerd Font that supplies the MDI glyphs.
- Palette wiring → [`_shared/colors-contract.md`](../../_shared/colors-contract.md) (waybar row,
  12 `@define-color` names).

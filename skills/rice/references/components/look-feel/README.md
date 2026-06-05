# look-feel

The compositor's own aesthetic — gaps, borders, rounding, blur, shadows, opacity, animations,
border colour, layout (dwindle / master / scrolling), window groups, per-app window rules, and the
optional runtime blur toggle. Owns `looknfeel.conf`.

This is the **largest** interview component (10 sub-questions, 3 calls — 4+3+3). It is also one of
the four components walked by **Mode B** (re-theming): the user is allowed to redo gaps, rounding,
blur, opacity, animations, layout etc. without rebuilding everything else. See
[`_interview-protocol.md`](../../_interview-protocol.md) for the Mode A / Mode B split.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 11a–11j across 3 `AskUserQuestion` calls (4+3+3), with `record-answer.sh` paths. |
| `schema.md` | The `look_feel.*` keys this component owns in `answers.json`, with the "who reads them" table. |
| `template.md` | The full `looknfeel.conf` body — general / decoration / animations / cursor / misc / debug / layout blocks, the scrolling block, the window-groups block (with locked-tier tints), and the per-version variants. |
| `hyprland.tmpl` | Engine color template — exports `$accent` `$accent2` `$bg` `$fg` `$surface` `$muted` as hyprlang `rgb(hex)` vars. Rendered to `~/.config/hypr/colors.conf` on every `rice apply` / wallpaper cycle / profile switch; sourced from `hyprland.conf` **before** `looknfeel.conf` so the vars are in scope. |
| `styling.md` | Visual-design library: anatomy of the knobs, archetypes ("floating signature", "no-gaps tiling", "heavy glass", "flat doctrine"), battle-tested techniques harvested from ~20 corpus rices, the tasteful-default recipe, pitfalls. |
| `gotchas.md` | Cursor-disappears-on-nouveau/NVIDIA, the `misc:vfr` → `debug:vfr` 0.55+ move, `dwindle:pseudotile` and `decoration:shadow:ignore_window` removal in 0.55+, scrolling-is-core (0.54+ — NOT 0.53), blur-needs-opacity, the "frosted" preset, vfr-vs-vrr confusion, the `background_color` pre-hyprpaper flash, `gaps_workspaces` ≠ `gaps_out`, the loud upstream group/nogroup default tints, spring-curves-are-Lua-only. |
| `packages.md` | None — looknfeel is built into Hyprland. |

## Where this component lands

- **Hyprland config:** writes `~/.config/hypr/conf.d/looknfeel.conf`, sourced from `hyprland.conf`
  after `colors.conf` (so `$accent`/`$accent2`/`$muted`/`$surface`/`$fg` are in scope).
- **Window rules:** the `look_feel.per_app_rules[]` array feeds block-form `windowrule { ... }`
  entries that the `window-rules` component actually emits — this component just collects them.
- **Keybinds:** when `look_feel.groups = true`, the `keybinds` component adds `SUPER+G` →
  `togglegroup` and `SUPER+TAB` → `changegroupactive`. When `look_feel.blur_toggle = true`, it adds
  `SUPER+SHIFT+B` → `exec, ~/.config/hypr/scripts/blur-toggle.sh` and the script ships in
  `assets/scripts/`.
- **Plugins:** the `scrolling` layout is **core** in **0.54+** (verified against
  `src/config/ConfigManager.cpp` source — the `scrolling:*` config keys are absent at v0.53.0
  and present at v0.54.0). The rice
  [`_shared/version-matrix.md`](../../_shared/version-matrix.md) currently says 0.53+ — flag in
  the changes report. Only the `hy3` / `hyprscroller` layouts are plugin-only and have to be
  gated through `components/plugins/`.

## Re-theming (Mode B)

When the user runs `rice retheme`, this component's `interview.md` is walked again from the top.
The user can change any sub-question — including the layout — and the renderer rewrites
`looknfeel.conf` without touching the other components. The palette/font/wallpaper components are
walked alongside; everything else is left alone.

## Related components

- [`window-rules`](../window-rules/) — emits the block-form `windowrule {}` entries collected in 11i.
- [`keybinds`](../keybinds/) — the `SUPER+G`/`SUPER+TAB` groups binds and the `SUPER+SHIFT+B` blur
  toggle bind.
- [`plugins`](../plugins/) — `hy3` and other plugin-only layouts (NOT `scrolling`, which is core).
- [`monitors`](../monitors/) — `workspace`-rule smart-gaps (related but separate).
- [`gaming`](../gaming/) — the "all effects off" game-mode toggle that supersedes a per-component
  switcher.
- Palette wiring → [`_shared/colors-contract.md`](../../_shared/colors-contract.md) (Hyprland row).

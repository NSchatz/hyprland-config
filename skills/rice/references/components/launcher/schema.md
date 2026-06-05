# launcher — answers.json slice

Keys this component owns under the top-level `launcher` key.

```json
{
  "launcher": {
    "tool":     "wofi | rofi | fuzzel | tofi | walker | vicinae | anyrun",
    "mode":     "drun | run-drun",
    "layout":   "centered | compact-top | fullscreen-grid | multi-column",
    "icons":    true,
    "behavior": ["fuzzy", "type-to-search", "hide-scrollbar", "close-on-focus-loss"]
  }
}
```

## Types

- `launcher.tool` — string, **required**. Enum of the seven tools. Drives every other key
  (some are no-ops for some tools — e.g. `icons:true` is silently ignored by `tofi`).
- `launcher.mode` — string, **required**. `drun` = app launcher only; `run-drun` = combined
  run+drun (rofi `modi: "drun,run"`; wofi `--show drun,run`; fuzzel `--list` mode). The
  optional window-switcher bind is captured by the `keybinds` component, not here.
- `launcher.layout` — string, **required**. Picks the geometry recipe in `template.md`.
  - `centered` — ~600px centered overlay, single column.
  - `compact-top` — narrow list anchored to the top edge.
  - `fullscreen-grid` — full screen, columned icon grid.
  - `multi-column` — centered card with a 3–7 column grid.
- `launcher.icons` — boolean, **required**. When `false`, the template omits `show-icons`,
  `allow-images`, `icons-enabled`, etc. tofi forces `false` regardless of the answer.
- `launcher.behavior` — array of strings, **required** (may be empty `[]`). Enum: `fuzzy`,
  `type-to-search`, `hide-scrollbar`, `close-on-focus-loss`. Each maps to a config key in the
  selected tool — see `template.md`.

## Who reads these keys

| Reader | Use |
|---|---|
| `hyprland-component-writer` (`launcher`) | Writes `~/.config/<tool>/{config,style,colors}` per `template.md`. |
| `hyprland-component-writer` (`keybinds`) | Writes `$menu = …` / `$dmenu = …` in `hyprland.conf` and `bind = $mainMod, R, exec, $menu` in `binds.conf`. |
| `hyprland-component-writer` (`window-rules`) | Emits `layerrule { match:namespace = <launcher-ns>; blur = true; … }` on the launcher's namespace. |
| `hyprland-package-installer` | Reads `launcher.tool` against `packages.md` and adds to the install batch. |
| Render engine | Renders `wofi/colors.css` / `rofi/colors.rasi` / fuzzel `[colors]` merge from `palette.conf`. |

## Validation

- `tool` is required and must be one of the enum values.
- `mode`, `layout`, `icons`, `behavior` are required (empty array is valid for `behavior`).
- For `tool == "tofi"`, `icons` may be `true` in the file but downstream writers force-disable
  icons (tofi is text-only by design) — don't error, just no-op.
- For `tool` ∈ {walker, vicinae, anyrun}, only the tool name + mode are wired into the install
  batch; the engine themes only what the tool exposes (see `template.md` notes).

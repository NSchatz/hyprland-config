# walker - launcher

Everything this plugin knows about authoring **walker** for the `launcher` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template

---

## Template


Walker runs as a service (`walker --gapplication-service`) for instant startup; `walker`
launches the picker, and `walker --dmenu` (or `-d`) is the dmenu mode. Config is TOML;
styling is GTK4 CSS placed in `~/.config/walker/themes/<name>/style.css`. The engine writes a
sibling `colors.css` the theme's `style.css` `@import`s — same shape as wofi.

The actual top-level sections in upstream `config.toml` (verified against the bundled default
on `abenz1267/walker`, v2.x) are **`[shell]`, `[columns]`, `[placeholders]`, `[keybinds]`,
`[providers]`** plus a flat set of top-level keys (`theme`, `close_when_open`,
`force_keyboard_focus`, `as_window`, `single_click_activation`, …). There is no `[search]`,
`[ui]`, or `[modules.drun]` section — that is **not** walker's schema.

```toml
# config.toml (excerpt — real upstream keys)
theme = "rice"                     # picks ~/.config/walker/themes/rice/style.css
close_when_open = true             ; from behavior.close-on-focus-loss
as_window = false                  ; layer-shell vs regular window
force_keyboard_focus = true

[providers.default]
# providers map to the picker's data sources (desktopapplications, calc, websearch, …);
# their full schema lives in walker's upstream docs.
```


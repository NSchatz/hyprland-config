# qt — template

The component generates two files when any Qt default app is selected (dolphin / krusader /
kdenlive / kwrite / okular) **or** when `env.qt_platformtheme == "qt6ct"` is emitted (the most
common path in the corpus — `theming/gtk-qt.md` documents why):

1. `~/.config/qt6ct/qt6ct.conf` — static (palette-agnostic), one-time writer. Sets the Qt style
   to **Fusion** with `custom_palette = true` + `color_scheme_path` pointing at the rendered
   `rice.conf`. Fusion + custom_palette is the lightest route — zero extra packages, re-themes
   from one rendered INI (vs Kvantum's `.kvconfig` / `.svg` name-matching + `kvantummanager
   --set` round-trip).
2. `~/.config/qt6ct/colors/rice.conf` — rendered from [`qt6ct.tmpl`](./qt6ct.tmpl) by the engine
   on every `rice apply`. Contains the 21-role QPalette × {active, inactive, disabled} matrix.

**Required render-manifest line** (emitted by SKILL.md A4.3 whenever the gate above holds; the
validator at A5 step 1 ERRORs if missing — see `agents/hyprland-config-validator.md` →
"Render-manifest completeness"):

```
qt6ct <TAB> ~/.config/hypr-rice/templates/qt6ct.tmpl <TAB> ~/.config/qt6ct/colors/rice.conf <TAB> :
```

`:` is the shell no-op — Qt apps re-read `rice.conf` at next launch (qt6ct has no live IPC). The
"next launch" surface group is footer-reported by `rice apply` (Issue 15.3, v0.21.0+).

## `~/.config/qt6ct/qt6ct.conf` — static writer

```ini
[Appearance]
style=Fusion
custom_palette=true
color_scheme_path={{xdg_config_home_or_default}}/qt6ct/colors/rice.conf
icon_theme=Papirus-Dark
standard_dialogs=default

[Fonts]
fixed="JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Regular"
general="Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Regular"

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
gui_effects=@Invalid()
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
stylesheets=@Invalid()
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3
```

`{{xdg_config_home_or_default}}` resolves to `$XDG_CONFIG_HOME` if set, else `$HOME/.config`.
Use a literal `$XDG_CONFIG_HOME` is **not** valid in qt6ct's INI parser — substitute at write
time. Fonts default to the rice's `font_ui` / `font_mono` families (size 10, the qt6ct default —
users adjust via the qt6ct GUI if they prefer larger).

## `~/.config/qt6ct/colors/rice.conf` — rendered from `qt6ct.tmpl`

See [`qt6ct.tmpl`](./qt6ct.tmpl) for the canonical body. Substitution map:

| Placeholder | Source key | Notes |
|---|---|---|
| `{{fg}}` | `palette.conf` `fg` | bare hex; the template prepends `#ff` for opaque #AARRGGBB. |
| `{{bg}}` | `palette.conf` `bg` | same. |
| `{{surface}}` | `palette.conf` `surface` | container/button backgrounds. |
| `{{muted}}` | `palette.conf` `muted` | disabled-state text; placeholder text. |
| `{{accent}}` | `palette.conf` `accent` | Highlight + Link. |
| `{{accent2}}` | `palette.conf` `accent2` | LinkVisited (defaults to `accent` on the manual path). |

The 21 QPalette roles in upstream Qt order: WindowText, Button, Light, Midlight, Dark, Mid,
Text, BrightText, ButtonText, Base, Window, Shadow, Highlight, HighlightedText, Link,
LinkVisited, AlternateBase, NoRole, ToolTipBase, ToolTipText, PlaceholderText. NoRole is always
fully transparent (`#00000000`) — it's a Qt enum filler, not a paintable role.

## Why Fusion + custom_palette over Kvantum

`theming/gtk-qt.md` documents the full Kvantum route (`style=kvantum` in qt6ct.conf,
`kvantummanager --set <theme>`, folder-name == theme-name constraint, SVG fidelity). It's the
right call when the user wants content-aware SVG theming (a Catppuccin-shaped scrollbar
gradient, say). For palette-cycling defaults it's overkill:

- Kvantum needs a Kvantum theme installed for every rice scheme (3+ extra packages, often AUR);
  Fusion is built into Qt6.
- Kvantum's theme switch is `kvantummanager --set` → reads `~/.config/Kvantum/kvantum.kvconfig`
  → matches a `<name>/<name>.kvconfig` folder. Fusion's switch is "rewrite one INI." No subprocess,
  no folder-name dance.
- Kvantum themes are color-scheme-agnostic; the Catppuccin Kvantum theme paints Catppuccin even
  on a Nord rice unless you swap the Kvantum theme too. Fusion + custom_palette inherits the
  rice palette directly.

Default to Fusion. Kvantum stays documented in `theming/gtk-qt.md` for the SVG-fidelity case.

## Cross-references

- The two Qt routes (Fusion + custom_palette vs Kvantum SVG) → `theming/gtk-qt.md`.
- The App-Coverage table row → `theming/apps.md` (`qt6ct` row).
- The env var that points Qt at qt6ct → `components/env/template.md` (`qt_theme` gate).
- The manifest-completeness assertion → `agents/hyprland-config-validator.md`.

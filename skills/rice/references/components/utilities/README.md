# utilities

The small tools and pop-up menus that make a Hyprland config feel *finished* — screenshots, screen
recording, OCR, clipboard history, color picker, emoji picker, power menu, Wi-Fi/Bluetooth menus,
night-light toggle. Every popular rice (JaKooLit, HyDE, Omarchy, gh0stzk) ships these as first-class
features; a generator easily skips them, which is what this component exists to prevent.

These ship as **plain shell scripts** in this skill's `assets/scripts/`. They are *not* themed —
they read no colors, render no template. Install is **`cp` + `chmod +x`**, not a palette render.
Their keybinds get emitted into `binds.conf` (owned by the `keybinds` component); their autostart
prerequisites (cliphist watchers, nm-applet, blueman-applet) get emitted into `autostart.conf`
(owned by the `autostart` component).

A few selections are **a bind, not a script** — clipboard history is a one-liner pipe through
`$dmenu`; emoji is `bemoji`; calculator is `rofi -show calc`; wlogout is its own binary. Those
still get represented as items in `utilities.selected`, and the writer agent knows whether to emit
a script copy or just a bind.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Group 18's single multi-select call, with corpus-frequency ordering and the pre-checked defaults. |
| `schema.md` | The `utilities.selected` array — recognized string values. |
| `template.md` | The script → deps → bind map, the bind-only tools (clipboard, emoji, calculator, wlogout), and the **wlogout `layout` + `style.css` recipe** when the user picked the wlogout flavor. Notes the auto-detect runtime behavior. |
| `styling.md` | How the corpus styles wlogout (6-button grid, icon source paths, blur layerrule, `logout_dialog` namespace). The only themed surface in this component. |
| `gotchas.md` | Wi-Fi/Bluetooth tray-vs-rofi tradeoff, 2025-2026 tool defaults (satty, wl-screenrec, hyprshot/grimblast), cliphist watcher location, OCR language packs, wlogout layer-namespace footguns. |
| `packages.md` | The full utility dependency map walked by the installer agent. |
| `wlogout.tmpl` | Engine color template — renders `~/.config/wlogout/colors.css` (`@define-color bg/fg/accent/surface`). The user's `style.css` `@import`s it. |

## Where this component lands

- **Scripts:** `~/.config/hypr/scripts/<name>.sh` (mode `0755`). Copy verbatim from
  `${CLAUDE_PLUGIN_ROOT}/skills/rice/assets/scripts/`. No template substitution.
- **Binds:** appended to `~/.config/hypr/binds.conf` — see `template.md` for the exact lines. The
  `keybinds` component owns the file; this component contributes the script-bind block.
- **Autostart entries:** `~/.config/hypr/autostart.conf` — owned by `autostart`, but several
  picks here require an autostart entry there (cliphist watchers ×2 for clipboard, `nm-applet
  --indicator` for wifi-applet, `blueman-applet` for bluetooth-applet).
- **wlogout (when picked):** `~/.config/wlogout/layout` + `~/.config/wlogout/style.css` written by
  the writer agent from `template.md`; `~/.config/wlogout/colors.css` rendered by the engine from
  `wlogout.tmpl` and `@import`ed by `style.css`. Icons resolve via the upstream
  `/usr/share/wlogout/icons/` fallback chain in `background-image: image(url("…"))`.

## Related components

- [`keybinds`](../keybinds/) — owns `binds.conf`; the script binds emitted here land there.
- [`autostart`](../autostart/) — runs the watchers and tray applets these scripts/binds depend on.
- [`launcher`](../launcher/) — defines `$menu` and `$dmenu`; the clipboard/calculator/emoji binds
  reference `$dmenu` (never `$menu` — see `gotchas.md`).
- [`accessibility`](../accessibility/) — night-light is offered there too; both groups bind the
  same `hyprsunset` toggle.
- [`window-rules`](../window-rules/) — owns the `layerrule = blur, logout_dialog` line that lets
  the wlogout overlay show a translucent backdrop instead of an opaque sheet (see `gotchas.md`).
- [`waybar`](../waybar/) — when the user picks the rofi power-menu flavor, the rofi prompt reuses
  waybar's `colors.css` via `@import` in most corpus rices (`JaKooLit/Hyprland-Dots`,
  `binnewbs/arch-hyprland`); the launcher component handles that wiring.

## Shipped scripts inventory

These live in `${CLAUDE_PLUGIN_ROOT}/skills/rice/assets/scripts/` and ship as-is:

| Script | Owned by |
|---|---|
| `screenshot.sh` | this component |
| `screenrecord.sh` | this component |
| `ocr.sh` | this component |
| `colorpicker.sh` | this component |
| `powermenu.sh` | this component |
| `keybind-cheatsheet.sh` | `keybinds` |
| `blur-toggle.sh` | `look-feel` |
| `gamemode.sh` | `gaming` |
| `theme-switch.sh` | `theming/` |

This component is concerned only with the first five (and the bind-only tools below).

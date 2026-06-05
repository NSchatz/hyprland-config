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
| `template.md` | The script → deps → bind map, plus the bind-only tools (clipboard, emoji, calculator, wlogout). Notes the auto-detect runtime behavior. |
| `gotchas.md` | Wi-Fi/Bluetooth tray-vs-rofi tradeoff, 2025-2026 tool defaults (satty, wl-screenrec, hyprshot/grimblast), cliphist watcher location, OCR language packs. |
| `packages.md` | The full utility dependency map walked by the installer agent. |

## Where this component lands

- **Scripts:** `~/.config/hypr/scripts/<name>.sh` (mode `0755`). Copy verbatim from
  `${CLAUDE_PLUGIN_ROOT}/skills/rice/assets/scripts/`. No template substitution.
- **Binds:** appended to `~/.config/hypr/binds.conf` — see `template.md` for the exact lines. The
  `keybinds` component owns the file; this component contributes the script-bind block.
- **Autostart entries:** `~/.config/hypr/autostart.conf` — owned by `autostart`, but several
  picks here require an autostart entry there (cliphist watchers ×2 for clipboard, `nm-applet
  --indicator` for wifi-applet, `blueman-applet` for bluetooth-applet).

## Related components

- [`keybinds`](../keybinds/) — owns `binds.conf`; the script binds emitted here land there.
- [`autostart`](../autostart/) — runs the watchers and tray applets these scripts/binds depend on.
- [`launcher`](../launcher/) — defines `$menu` and `$dmenu`; the clipboard/calculator/emoji binds
  reference `$dmenu` (never `$menu` — see `gotchas.md`).
- [`accessibility`](../accessibility/) — night-light is offered there too; both groups bind the
  same `hyprsunset` toggle.

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

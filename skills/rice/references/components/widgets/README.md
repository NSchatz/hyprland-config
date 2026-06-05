# widgets

The **desktop widget shell** beyond the bar — dashboards, control centers, sidebars, OSDs (volume /
brightness), music / now-playing cards, notification centers, calendar panels, power menus,
workspace overviews. This is the surface that turns a working Hyprland into a *rice*.

This is an **opt-in component**: the interview opens with a gate ("none / just waybar" vs. a real
widget system). On "none" the rest of the component is skipped and `widgets.system = "none"` is
recorded. On any other pick the interview walks 7b–7d (which widgets, look, motion / density), the
chosen shell's template line is registered with the rice engine, and `rice apply` re-themes it on
every theme switch.

Pick one of: **eww** (yuck + SCSS — floating widgets next to waybar), **AGS / Astal** (TS/JS + GTK
+ SCSS — batteries-included services), **Quickshell** (QML — the modern, animation-rich shells;
live window previews), **HyprPanel** (turnkey AGS panel, GUI-configured; archived 2026-04 but
still usable), or a **turnkey pre-built shell** (end-4, caelestia, Noctalia, DankMaterialShell).

**A full shell replaces waybar.** Quickshell / AGS / HyprPanel / a turnkey shell own their own bar
— running waybar alongside means two bars fighting for the top edge. The waybar `exec-once` has to
go. A full shell also typically owns notifications (AGS `Notifd`, Quickshell `Notifications`) —
group 9 (notifications) must be set to `none` to avoid the D-Bus name conflict.

## Files in this folder

| File | What it holds |
|---|---|
| `interview.md` | Sub-questions 7a (system gate), 7a-bis (turnkey shell), 7b (which widgets), 7c (look), 7d (motion / density). |
| `schema.md` | The `widgets.{system, turnkey, enabled, look, motion}` slice of `answers.json`. |
| `template.md` | Per-shell wiring: eww (yuck + scss), AGS (TS/JS + scss), Quickshell (QML); how the rice template (`eww.tmpl` / `ags.tmpl` / `quickshell.tmpl`) feeds each. |
| `styling.md` | The concatenated design library — cross-cutting widget archetypes (from `hyprland-reference/styling/widgets.md`) plus the three per-toolkit references (eww / AGS / Quickshell). |
| `gotchas.md` | Full-shell-replaces-waybar, HyprPanel→matugen path, notifications conflict, eww `grass`-SCSS quirks, heavy shell build times. |
| `packages.md` | `eww` / `aylurs-gtk-shell` (AGS CLI) / `quickshell` / `hyprpanel` AUR packages, plus `matugen` for the Material-You path. |
| `reload.md` | Per-shell reload hooks (eww `eww reload`, AGS file-monitor + `resetCss`, Quickshell hot-reload on save, HyprPanel GUI-driven). |
| `validation.md` | yuck parses (`eww` linter), AGS TS compiles, Quickshell QML parses (`qmllint`). |

## Where this component lands

- **eww** → `~/.config/eww/eww.yuck` + `~/.config/eww/eww.scss` + `~/.config/eww/colors.scss`
  (rendered by the rice engine from `eww.tmpl`).
- **AGS / Astal** → `~/.config/ags/` (TS project) + `~/.config/ags/style.scss` +
  `~/.config/ags/colors.scss` (from `ags.tmpl`).
- **Quickshell** → `~/.config/quickshell/<name>/shell.qml` + `~/.config/quickshell/<name>/Colors.qml`
  (from `quickshell.tmpl`).
- **HyprPanel** → `~/.config/hyprpanel/` (its own JSON); themed via the GUI / matugen, **not** the
  rice engine.
- **Turnkey shells** (end-4, caelestia, Noctalia, DankMaterialShell) → the project's own install
  script lays out its config; the rice engine *does not* hand-theme them. Drive their colors via
  **matugen** on the chosen wallpaper.

The rice engine registers one line in the render manifest for the picked shell (see
`theming/engine.md` → "Widget-shell theming") so `rice apply` regenerates the colors file on every
theme switch. No engine line is registered for HyprPanel or a turnkey shell — those own their own
theming.

## Related components

- [`waybar`](../waybar/) — **replaced** by a full shell. Drop the waybar `exec-once` when
  `widgets.system` is `ags` / `quickshell` / `hyprpanel` / `turnkey`. eww is the only widget pick
  that pairs *with* waybar rather than replacing it.
- [`notifications`](../notifications/) — set to `none` when a full shell owns notifications (AGS
  `Notifd`, Quickshell `Notifications`, DankMaterialShell's built-in). Two daemons fighting for
  `org.freedesktop.Notifications` means dropped or duplicated notifications.
- [`keybinds`](../keybinds/) — widget toggle binds (open the dashboard, the launcher, the power
  menu, the cheatsheet, the overview) land here, not in this folder. Reference the shell's IPC
  (e.g. `eww open --toggle dashboard`, `qs ipc call ...`, `astal -t ...`) from keybinds.
- [`launcher`](../launcher/) — a full shell typically ships its own launcher. If you keep a
  separate rofi/wofi/fuzzel, the shell's built-in launcher is still there — pick one and only bind
  the one you want.
- [`lock-screen`](../lock-screen/) — Quickshell shells (caelestia, Noctalia, DankMaterialShell) can
  *be* the lock screen via `Quickshell.Wayland.SessionLock`; if the picked shell owns the lock,
  drop hyprlock from the lock-screen component.
- [`theming/engine.md`](../../theming/engine.md) — the rice engine's "Widget-shell theming"
  section. Defines how `eww.tmpl` / `ags.tmpl` / `quickshell.tmpl` get registered and reloaded.
- [`_shared/colors-contract.md`](../../_shared/colors-contract.md) — the canonical variable names
  each shell's colors file exports (eww, ags, quickshell rows).

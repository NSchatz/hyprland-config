# Styling Reference Library

How to make a Hyprland desktop **look good** — the cross-cutting design layer (coherence, accent
discipline, spacing, shape, transparency, typography) that makes a configured desktop add up to a
single designed system instead of a pile of independently-pretty windows.

**Per-surface styling moved to the component folders** under
`rice/references/components/<x>/styling.md`. Each visual component (waybar, launcher,
notifications, terminal, lock-screen, widgets, shell-prompt, look-feel) now owns its own styling
recipe alongside its interview slice, template, gotchas, and packages. The styling library here
shrinks to just the cross-cutting principles below.

## Pages

| Page | Covers |
|------|--------|
| [`design-principles.md`](design-principles.md) | **Start here.** Coherence rules, the aesthetic archetypes, wallpaper-driven theming, a coherence checklist. The cross-cutting layer every per-component styling.md assumes. |

## Per-component styling pointers

| Surface | Where the styling reference now lives |
|---|---|
| Hyprland decoration (gaps, borders, blur, shadow, animations) | [`../../../rice/references/components/look-feel/styling.md`](../../../rice/references/components/look-feel/styling.md) |
| Status bar (waybar) | [`../../../rice/references/components/waybar/styling.md`](../../../rice/references/components/waybar/styling.md) |
| Launcher (wofi / rofi / fuzzel) | [`../../../rice/references/components/launcher/styling.md`](../../../rice/references/components/launcher/styling.md) |
| Notifications (mako / dunst / swaync) | [`../../../rice/references/components/notifications/styling.md`](../../../rice/references/components/notifications/styling.md) |
| Terminal (kitty / alacritty / foot / wezterm / ghostty) | [`../../../rice/references/components/terminal/styling.md`](../../../rice/references/components/terminal/styling.md) |
| Lock screen (hyprlock) | [`../../../rice/references/components/lock-screen/styling.md`](../../../rice/references/components/lock-screen/styling.md) |
| Widget shells (eww / AGS-Astal / Quickshell — design + per-toolkit) | [`../../../rice/references/components/widgets/styling.md`](../../../rice/references/components/widgets/styling.md) |
| Shell & prompt (btop / cava / fastfetch / starship — Nerd Font glyphs) | [`../../../rice/references/components/shell-prompt/styling.md`](../../../rice/references/components/shell-prompt/styling.md) |
| GTK / Qt / icons / cursors / fonts (toolkit consistency) | [`../../../rice/references/theming/gtk-qt.md`](../../../rice/references/theming/gtk-qt.md) |

Every recipe is built on the plugin's **rice palette contract** — see
[`../../../rice/references/_shared/palette-schema.md`](../../../rice/references/_shared/palette-schema.md)
for the canonical keys (`bg fg surface muted cursor accent accent2 red green yellow blue magenta
cyan color0..color15`, plus `font_ui` / `font_mono`).

## Who reads this

- **`rice`** — for tasteful structural + palette defaults when building from scratch.
- **`edit-config`** — for the *layout/structure* of any surface when editing an existing config.

These are design references, not syntax authorities — for the exact, current option names defer to
the sibling `hyprland-reference` files (`sections.md`, `window-rules.md`, `deprecations.md`,
`ecosystem.md`, `keybindings.md`).

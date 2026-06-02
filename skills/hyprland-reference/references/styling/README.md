# Styling Reference Library

How to make a Hyprland desktop **look good** — not the config *syntax* (that's the rest of
`hyprland-reference`), but the *visual design* of every surface the eye touches. Each page surveys
how the community actually styles a component (HyDE, end-4/dots-hyprland, JaKooLit, ml4w, the
Catppuccin/Gruvbox/Nord/Tokyo Night/Rosé Pine ecosystems, r/unixporn) and distills it into a
palette-driven, copy-pasteable recipe.

**Read [`design-principles.md`](design-principles.md) first** — it's the cross-cutting layer
(coherence, accent discipline, spacing, shape, transparency, typography) that makes the per-app
pages add up to a single designed system instead of a pile of independently-pretty windows.

Every recipe is built on the plugin's **rice palette contract** (`~/.config/hypr-rice/palette.conf`,
see `rice/references/engine.md`): keys `bg fg surface muted cursor accent accent2 red green
yellow blue magenta cyan color0..color15`, plus `font_ui` / `font_mono`. Recipes show colors as
`{{key}}` placeholders (so they drop straight into the rice templates) **and** as a worked
Catppuccin Mocha example.

## Pages

| Page | Covers |
|------|--------|
| [`design-principles.md`](design-principles.md) | **Start here.** Coherence rules, the aesthetic archetypes, wallpaper-driven theming, a coherence checklist. |
| [`hyprland-decoration.md`](hyprland-decoration.md) | The compositor look: gaps, borders, gradient `col.active_border`, rounding, blur, shadow, animations/beziers. |
| [`waybar.md`](waybar.md) | The status bar: `config.jsonc` layout + `style.css`, the floating-island vs edge-to-edge looks, pill modules, states. |
| [`launchers.md`](launchers.md) | wofi / rofi / fuzzel / tofi: the centered floating panel, the selection highlight, blur. |
| [`notifications.md`](notifications.md) | mako / dunst / swaync: the accent-bordered card, urgency colors, the control center. |
| [`terminals.md`](terminals.md) | kitty / alacritty / foot / wezterm / ghostty: the 16-color palette, font, padding, opacity + blur. |
| [`hyprlock.md`](hyprlock.md) | The lock screen: blurred background, clock label, the accent-outlined input pill (literal hex — no `$vars`). |
| [`gtk-qt.md`](gtk-qt.md) | App windows: GTK/libadwaita + Qt themes, icons, cursors, fonts, Kvantum — toolkit consistency. |
| [`tui-and-prompt.md`](tui-and-prompt.md) | btop / cava / fastfetch / starship: matching the scheme inside the terminal; Nerd Font glyphs. |

## Who reads this

- **`rice`** — for tasteful structural + palette defaults when building from scratch, and for how to
  color each surface (the recipes assume its rice palette contract).
- **`desktop-shell`** — for the *layout/structure* of the bar, launcher, and notifications.

These are design references, not syntax authorities — for the exact, current option names defer to
the sibling `hyprland-reference` files (`sections.md`, `window-rules.md`, `deprecations.md`,
`ecosystem.md`).

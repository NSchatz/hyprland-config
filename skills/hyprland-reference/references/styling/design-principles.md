# Desktop Design Principles & Aesthetic Survey

A good Hyprland rice is not the sum of well-styled apps — it is **coherence**: one palette, one
font system, one shape language, and one transparency policy applied across every surface the eye
touches. The per-app pages in this directory tell you *how* to style each component; this page is
the cross-cutting layer that makes those components read as a single designed system instead of a
pile of independently-pretty windows. Get coherence right and a restrained setup looks better than
a flashy incoherent one.

## The coherence rules

These are the rules that hold whether you want minimal mono or maximal glass. Each has a "why" and
concrete guidance.

### One palette everywhere

The single biggest determinant of a coherent desktop is that **every app draws from one palette**.
A waybar that's Tokyo Night next to a Gruvbox terminal next to a stock-blue GTK file picker reads
as broken no matter how nice each piece is on its own. The fix is the *rice model*: keep one source
of truth and render it into every app's config.

This plugin's source of truth is **`~/.config/hypr-rice/palette.conf`** — plain `KEY=hex` lines
(no `#`) consumed by templates and re-applied with one command (`rice apply`). The palette contract:

```
bg fg surface muted cursor          # neutrals: window/bar bg, default text, panels, dim text, cursor
accent accent2                      # the one (or two) brand colors used for focus/selection/active
red green yellow blue magenta cyan  # semantic / named colors
color0 .. color15                   # the base16 ramp (terminal + anything wanting 16 slots)
```

Plus metadata: `scheme`, `wallpaper`, `font_ui`, `font_mono`. Apps that support an include
(Hyprland `source=`, kitty `include`, waybar/wofi `@import`) read a generated colors file; apps
that don't (mako, dunst) get the colors folded into their config when it's written. **Re-theming is
then one edit + one command, and nothing drifts out of sync.** This is exactly the model HyDE
(wallust), ML4W (wallust), and end-4/illogical-impulse (matugen) use — a generator feeds one
palette, templates fan it out.

### Accent discipline — the 60-30-10 rule

Borrowed from interior and UI design: roughly **60% dominant** (your `bg`), **30% secondary**
(`surface` — panels, bar, inactive elements), **10% accent** (`accent`, the pop). The point is not
exact ratios; it's that **one accent does one job** — focus, selection, the active workspace, the
active bar module, the cursor in a prompt — *consistently everywhere*. If yellow means "active"
in waybar it should mean "active" at the Hyprland border, in the launcher's selected row, and in
the notification's accent line. Two or three accents competing for attention, or an accent that
means different things in different apps, is the most common way a rice looks "busy" or amateur.
Pick one (optionally a second `accent2` for a secondary state), and reserve the named semantic
colors (`red`/`green`/`yellow`) strictly for status meaning (urgent, success, warning).

### Contrast & readability

Pretty is worthless if you can't read it. Practical rules:

- **Never use pure `#000000` bg or `#ffffff` fg.** Pure black with glow/blur smears; pure white on
  dark is harsh and causes halation. Every serious community palette agrees: Catppuccin Mocha's base
  is `#1e1e2e`, Tokyo Night sits around `#1a1b26`, Nord's darkest is `#2e3440`, Gruvbox `#282828`.
  Foregrounds are off-white (`#cdd6f4`, `#c0caf5`, `#eceff4`). Follow them.
- **Aim for WCAG-ish body contrast** (~4.5:1 fg-on-bg). Dark themes especially tend to fail on
  *muted* text — make sure `muted`/`color8` is still legible against `bg`, not a barely-there gray.
- **`color0` vs `color8`** (the two "blacks" in the base16 ramp) and `color7` vs `color15` (the two
  "whites") should be distinguishable — TUIs use the bright variants for emphasis, and if they
  collapse to the same value you lose that signal.
- **Light themes need the inverse discipline:** off-white bg (`#eff1f5`, not `#fff`), genuinely
  dark text, and accents that stay saturated enough to read on a bright field.

### A spacing scale

Spacing is a system, not a per-widget guess. Pick a base unit (commonly 4 or 8 px) and derive
everything from it. The desktop-specific version: **relate Hyprland gaps to waybar margins to
launcher padding** so whitespace feels rhythmic across the screen rather than arbitrary.

- Hyprland `general:gaps_in` / `gaps_out` set the window grid's breathing room.
- A floating bar's `margin` should harmonize with `gaps_out` (e.g. bar margin ≈ outer gap) so the
  bar sits *inside* the same rhythm as the windows, not on a different grid.
- Launcher, notification, and module padding should be multiples of the same base unit.

Tight (gaps 0–4) reads sleek/minimal; generous (gaps 8–16, floating bar) reads airy/modern. Either
works — *mixing scales randomly* is what looks off.

### Consistent shape

Decide on **one corner-radius language** and apply it to windows, bar modules, the launcher,
notifications, input fields, and tooltips. Hyprland `decoration:rounding` sets window corners;
match (or deliberately scale) it in waybar CSS `border-radius`, launcher theme radius, and
notification radius. The choice itself is an aesthetic lever: `rounding = 0` reads sharp/technical
(common in mono/minimal rices), `8–12` reads soft/modern, `16+` plus a floating bar reads like the
"floating islands" / pill look (HyDE, JaKooLit, end-4). What you must avoid is a 12px window next to
a square bar next to a 20px launcher — pick a radius and commit.

### Transparency + blur as a system

Glass is the signature of the modern Hyprland look, and the single fastest way to make a desktop
look cheap is to apply it inconsistently. Rules:

- **Pick one opacity level** (e.g. ~0.85–0.95 for surfaces) and reuse it. Don't have a 0.7 bar over
  a 0.95 terminal over an opaque launcher.
- **Every transparent surface must be blurred**, or the wallpaper bleeds through as visual noise.
  In Hyprland that means: window transparency via `decoration:active_opacity`/`inactive_opacity`
  (and per-app `windowrule = opacity …`) **with `decoration:blur:enabled = true`**, *and* a matching
  `layerrule` blur for every translucent layer-shell surface (bar, launcher, notifications).
  On Hyprland 0.54+ the single-line form `layerrule = blur, waybar` is rejected — use the block form:

  ```
  layerrule {
      name = blur-waybar
      match:namespace = waybar
      blur = true
  }
  ```
  (the `name` + `match:namespace` keys are required on 0.54.x; see `hyprland-decoration.md` and
  `../window-rules.md`. Also typical namespaces: `wofi`/`rofi`, `notifications`,
  `swaync-control-center`, `gtk-layer-shell`.)
- **Decide opaque-vs-glass once and globally.** A fully opaque flat rice is perfectly coherent; a
  fully glass rice is coherent. A rice where half the surfaces are glass and half are opaque, for no
  semantic reason, is the incoherent one. If you go opaque, turn blur off and skip the layerrules.

### Typography

Two fonts, chosen once:

- **One UI/sans font** for bar, launcher, notifications, GTK/Qt apps (e.g. Inter, Roboto, Cantarell,
  Noto Sans, JetBrains Sans).
- **One monospace Nerd Font** for terminal, prompt, fetch, and any bar/editor element showing glyphs.
  **A Nerd Font is effectively mandatory** — the bar's workspace/battery/network icons, the
  starship/powerline prompt, the fastfetch/neofetch logo, and notification icons are all glyphs from
  the Nerd Font patch set; without it you get tofu boxes (`□`). Popular picks: JetBrainsMono Nerd
  Font, FiraCode Nerd Font, CaskaydiaCove (Cascadia Code) Nerd Font.
- **Keep sizes consistent** — one base UI size, one mono size, scaled by your spacing logic. Mixing
  five sizes across bar modules is as noisy as mixing five accents.

## Aesthetic archetypes

The recognizable "looks" people build are mostly combinations of *palette character* + *shape/
transparency* + *animation energy*. Pick one as a starting target; they're achievable with this
plugin by choosing the scheme + the shape/blur knobs above.

| Archetype | Palette character | Typical bar / shape / transparency | Animation energy | Exemplified by |
|---|---|---|---|---|
| **Catppuccin pastel soft-glass** | Mid-contrast pastels on muted dark base (`#1e1e2e`); 13 soft accents (Mauve, Lavender, Blue…) | Floating rounded bar, generous gaps, light glass + blur | Smooth, gentle | Catppuccin ecosystem; very common on r/unixporn |
| **Tokyo Night neon-on-dark** | Deep blue-black base, vivid neon blue/purple/cyan accents | Can go either flat or glass; accents pop hard against dark | Snappy, vivid | Tokyo Night ecosystem |
| **Gruvbox retro-warm** | Warm low-blue base (`#282828`), browns/oranges/greens, earthy | Often flatter, opaque or low-transparency, square-ish | Calm, minimal | Gruvbox / gruvbox-material |
| **Nord muted-cool** | Arctic: cool desaturated blues (Frost) + dim accents (Aurora) on Polar Night | Flat, calm, often opaque; low-contrast on purpose | Restrained | Nord ecosystem |
| **Rosé Pine** | Muted "soho" rose/gold/pine on warm-dark base; cozy, low-saturation | Soft rounded, light glass | Gentle | Rosé Pine ecosystem |
| **Material You / dynamic** | Palette *derived from the wallpaper* (Material Design 3); tonal, auto-harmonized | Highly animated QML shell, heavy glass, mobile-OS feel | Fluid, elaborate | end-4/illogical-impulse (matugen + Quickshell) |
| **Minimal mono / "less is more"** | One bg, one fg, near-monochrome, maybe a single accent | `rounding=0` or tiny, thin/flat bar, opaque, tiny gaps | Minimal/instant | many bespoke r/unixporn mono rices |
| **Maximalist floating-islands** | Bold accent, full glass, big radius | Pill/island bar modules, big gaps, blur everywhere, widgets/sidebars | Lots of bezier motion | HyDE, JaKooLit, ML4W |

Notes on the heavyweight dotfile projects (useful reference points, not requirements):

- **HyDE** (`prasanthrangan/hyprdots`, now HyDE-Project) — wallust-driven dynamic theming, a theme
  switcher, polished floating waybar; the canonical "batteries-included aesthetic" rice.
- **JaKooLit/Hyprland-Dots** — many swappable waybar styles (default "Neon Circuit" cyberpunk), an
  animations menu, bezier-curve workspace transitions; multi-distro installers.
- **ML4W** (`mylinuxforwork/dotfiles`) — GUI settings apps to tune gaps/blur/shadows/borders and
  swap waybar themes; wallust for terminal colors.
- **end-4/dots-hyprland (illogical-impulse)** — Material-You-via-matugen, has moved entirely to a
  **Quickshell** (QML/Qt6) shell (away from waybar) for animated bar/sidebars/widgets; the most
  "mobile-OS"-feeling rice and the showcase for wallpaper-driven theming.

## Wallpaper-driven theming

Instead of a named scheme, derive the whole palette from the current wallpaper so colors and image
always agree. Three tools dominate, all of which this plugin supports as a *source* for the one
`palette.conf`:

- **matugen** — generates **Material You (Material Design 3)** schemes (and base16) from an image,
  with light/dark modes and adjustable contrast. Its templating engine themes effectively unlimited
  apps and runs `post_hook`s to reload them. This is the modern, tonally-harmonized choice and what
  end-4 uses. Map `primary→accent`, `secondary→accent2`, surfaces/neutrals→`bg/surface/muted`,
  `on_surface→fg`, and the extended palette → `color0..15`.
- **wallust** — fast Rust pywal successor; emits a pywal-compatible **16-color** scheme that maps
  straight onto `color0..15`/`bg`/`fg` (derive `accent` from a chosen `colorN`). Used by HyDE/ML4W.
- **pywal** — the original; extracts a 16-color terminal scheme and pushes it to many apps. Largely
  superseded by wallust (speed) and matugen (tonal quality), but the lineage everyone learned from.

**When dynamic shines:** you change wallpapers often and want everything to follow automatically;
you want a *unique* palette rather than the (lovely but ubiquitous) Catppuccin/Gruvbox look.
**When named schemes win:** you want guaranteed, hand-tuned contrast and semantic-color stability,
or a specific recognizable identity. Either way the discipline is the same — **one wallpaper → one
palette → every app**, never per-app extraction (matugen for some, a hardcoded scheme for others)
which reintroduces exactly the drift the rice model exists to prevent. (matugen can additionally
theme the long tail of apps it ships templates for, using the *same* wallpaper, while the engine
owns the core.)

## A coherence checklist

Audit a desktop against this — most "something's off but I can't say what" problems are one of these:

- [ ] **One palette** — every app reads from `palette.conf` (no app still on its stock/default colors).
- [ ] **One accent** — the same color marks focus / selection / active across Hyprland borders,
      waybar, launcher, and notifications; it isn't doing three different jobs.
- [ ] **Semantic colors reserved** — red/green/yellow only mean status, not decoration.
- [ ] **Contrast passes** — no pure `#000`/`#fff`; `muted`/`color8` text is actually readable on `bg`.
- [ ] **One radius** — windows, bar modules, launcher, notifications, inputs share a corner language.
- [ ] **One opacity level**, and **every transparent surface is blurred** (window blur on **and** a
      `layerrule` blur block for each translucent layer: bar, launcher, notifications).
- [ ] **No random opaque/glass mix** — the transparency decision is global and intentional.
- [ ] **One Nerd Font** for mono/glyphs (no tofu in bar/prompt/fetch), one UI font, consistent sizes.
- [ ] **One spacing scale** — bar margin harmonizes with `gaps_out`; paddings are multiples of a base unit.
- [ ] **Re-theming is one command** — changing scheme/wallpaper updates everything, nothing drifts.

## See also

Per-app styling pages in this `styling/` directory:

- [`waybar.md`](waybar.md) — bar layout, modules, CSS, transparency/blur, fonts.
- [`launchers.md`](launchers.md) — wofi / rofi / fuzzel theming.
- [`notifications.md`](notifications.md) — mako / dunst / swaync styling.
- [`terminals.md`](terminals.md) — kitty / foot / alacritty colors and fonts.
- [`hyprland-decoration.md`](hyprland-decoration.md) — rounding, gaps, blur, borders, shadows, opacity.
- [`hyprlock.md`](hyprlock.md) — lock screen styling consistent with the palette.
- [`gtk-qt.md`](gtk-qt.md) — GTK/Qt/libadwaita, cursor, icons so toolkit apps match.
- [`tui-and-prompt.md`](tui-and-prompt.md) — starship prompt, fetch, TUI/base16 colors.

## Sources

- r/unixporn ricing conventions & color-scheme popularity — namishh, *The Ricing Guide*: <https://namishh.com/blog/ricing>
- *10 Hyprland Dotfiles to Transform Your Linux Desktop* — It's FOSS: <https://itsfoss.com/best-hyprland-dotfiles/>
- HyDE / hyprdots (wallust, theme switcher): <https://github.com/prasanthrangan/hyprdots> and <https://github.com/HyDE-Project>
- JaKooLit/Hyprland-Dots (waybar styles, animations menu): <https://github.com/JaKooLit/Hyprland-Dots> and its [waybar wiki](https://github.com/JaKooLit/Hyprland-Dots/wiki/Customizing_waybar)
- ML4W dotfiles (settings apps, waybar themes, wallust): <https://github.com/mylinuxforwork/dotfiles> and <https://mylinuxforwork.github.io/dotfiles/customization/waybar>
- end-4/dots-hyprland — illogical-impulse, Material You + Quickshell: <https://github.com/end-4/dots-hyprland>, wiki <https://end-4.github.io/dots-hyprland-wiki/en/>, [Quickshell UI system](https://deepwiki.com/end-4/dots-hyprland/3-quickshell-ui-system)
- Catppuccin palette & flavor philosophy (pastel, mid-contrast): <https://catppuccin.com/palette/>
- Nord palette (Polar Night / Snow Storm / Frost / Aurora, arctic/muted): <https://www.nordtheme.com/docs/colors-and-palettes>
- Tokyo Night / Gruvbox / Rosé Pine character — *Colorschemes for the Discerning Developer*: <https://nathan-long.com/blog/colorschemes-for-the-discerning-developer/>
- matugen (Material You + base16 generation, templating, post-hooks): <https://github.com/InioX/matugen>
- pywal (wallpaper → 16-color scheme, app propagation): <https://pywal.com/>
- 60-30-10 color rule for UI: UX Planet <https://uxplanet.org/the-60-30-10-rule-a-foolproof-way-to-choose-colors-for-your-ui-design-d15625e56d25> and NN/g, *Using Color to Enhance Your Design*: <https://www.nngroup.com/articles/color-enhance-design/>
- Preconfigured Hyprland setups — Hyprland Wiki: <https://wiki.hypr.land/Getting-Started/Preconfigured-setups/>
</content>
</invoke>

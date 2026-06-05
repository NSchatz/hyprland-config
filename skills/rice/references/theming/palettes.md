# Named Palettes

The 12 schemes the interview presents. Each maps to the palette contract documented in
[`_shared/palette-schema.md`](../_shared/palette-schema.md) (the key list — `bg`, `fg`, `surface`,
`muted`, `cursor`, `accent`, `accent2`, the semantic hues, `color0..15`). Hex is `RRGGBB` (without
`#`); apps add their own wrapper (`#`, `rgb(…)`, two-digit alpha suffix) per the
[colors contract](../_shared/colors-contract.md).

Each scheme also ships 6–8 curated **accent variants** in `../../assets/accents.tsv`. List them with
`rice accents <scheme>`; swap with `rice accent <name|hex>` (`--pin` to keep across re-themes). The
`accent` shown below is a sensible default — the user can override.

For `color0..15`, Catppuccin Mocha's full mapping is given as the reference pattern. For other
schemes, map `color1..6` = `red green yellow blue magenta cyan`, `color0`=bg-ish, `color7/15`=fg-ish,
`color8`=`muted`, bright `9..14` ≈ the same hues (mode-aware).

## How the corpus ships schemes

Cross-referenced against the corpus (`.research/corpus.md`), the rices fall into four scheme-supply
patterns. Knowing which pattern a user came from helps the interview surface a coherent default.

| Pattern | Rices | Default scheme | Fallback bank |
|---|---|---|---|
| **Matugen-only (no fallback bank)** | end-4, mylinuxforwork, dusky, Ax-Shell, binnewbs, koeqaife/HyprYou (matugen-like) | derived from wallpaper at install | none — image required (HyprYou ships a default tonal image) |
| **Matugen + curated theme bank** | HyprPanel (`themes/*.json`), DankMaterialShell (matugen-orchestrated) | matugen (auto) | HyprPanel: catppuccin × {mocha/macchiato/frappe/latte} × {plain/split/vivid}, cyberpunk, dracula, everforest, gruvbox, monochrome, nord, one_dark, rose_pine + rose_pine_moon, tokyo_night + tokyo_night_moon (× 3 variants each ≈ 42 JSONs) |
| **Wallust (16-color extraction)** | JaKooLit | wallust `dark16` from wallpaper | static kitty-themes bank (hundreds of files: 3024, Catppuccin, Solarized, Dracula, …); GTK/SDDM driven separately |
| **Hand-rolled scheme JSONs** | noctalia-shell (`Assets/ColorScheme/*.json`), caelestia, HyDE (wallbash `.dcol`) | named | noctalia: Ayu, Catppuccin, Dracula, Eldritch, Gruvbox, Kanagawa, Noctalia-default, Nord, Rosepine, Tokyo-Night. HyDE-gallery: 200+ named themes (Catppuccin Mocha, Dracula, Decay Green, Edge Runner, …) |
| **Single-theme** | linuxmobile (Rose Pine), Matt-FTW (Catppuccin), flickowoa (theme.conf bank) | one theme | swap by editing `theme.conf` / file include |

Takeaways:

- The 12 schemes we ship cover every named theme the matugen-bank rices ship except `cyberpunk`,
  `monochrome`, `one_dark`, and the Catppuccin/Rosé Pine/Tokyo Night `_split`/`_vivid`/`_moon`
  variants. Adding `tokyo-night-moon` and `rose-pine-moon` would line up with HyprPanel's bank — flag
  for the orchestrator.
- HyDE's wallbash is **not** a named-scheme system — it derives every theme from a wallpaper using
  its own HSV-curve engine (`wallbashCustomCurve` in `Configs/.config/hyde/hyde.conf`). Importing a
  HyDE rice means picking the wallpaper-generated path, not a named scheme.
- JaKooLit's static kitty bank (`config/kitty/kitty-themes/*.conf`) is **terminal-only** — it does
  not re-theme the bar/launcher/notification surfaces, so a user who has been "using nord on kitty"
  via JaKooLit is still wallust-driven everywhere else.

## Core palette catalog (dark schemes)

| Scheme | bg | fg | surface | muted | cursor | accent | accent2 |
|---|---|---|---|---|---|---|---|
| catppuccin-mocha | `1e1e2e` | `cdd6f4` | `313244` | `6c7086` | `f5e0dc` | `cba6f7` (mauve) | `89b4fa` (blue) |
| catppuccin-frappe | `303446` | `c6d0f5` | `414559` | `737994` | `f2d5cf` | `ca9ee6` (mauve) | `8caaee` (blue) |
| catppuccin-macchiato | `24273a` | `cad3f5` | `363a4f` | `6e738d` | `f4dbd6` | `c6a0f6` (mauve) | `8aadf4` (blue) |
| gruvbox | `282828` | `ebdbb2` | `3c3836` | `928374` | `ebdbb2` | `fabd2f` (yellow) | `83a598` (blue) |
| nord | `2e3440` | `d8dee9` | `3b4252` | `4c566a` | `eceff4` | `88c0d0` (frost) | `5e81ac` |
| tokyo-night | `1a1b26` | `c0caf5` | `24283b` | `565f89` | `c0caf5` | `7aa2f7` (blue) | `bb9af7` (purple) |
| rose-pine | `191724` | `e0def4` | `1f1d2e` | `6e6a86` | `ebbcba` | `c4a7e7` (iris) | `31748f` (pine) |
| dracula | `282a36` | `f8f8f2` | `44475a` | `6272a4` | `f8f8f2` | `bd93f9` (purple) | `ff79c6` (pink) |
| everforest | `2d353b` | `d3c6aa` | `3d484d` | `7a8478` | `d3c6aa` | `a7c080` (green) | `83c092` (aqua) |
| kanagawa | `1f1f28` | `dcd7ba` | `2a2a37` | `727169` | `dcd7ba` | `7e9cd8` (crystalBlue) | `957fb8` (oniViolet) |
| solarized-dark | `002b36` | `839496` | `073642` | `586e75` | `93a1a1` | `268bd2` (blue) | `2aa198` (cyan) |

## Light scheme

| Scheme | bg | fg | surface | muted | cursor | accent | accent2 |
|---|---|---|---|---|---|---|---|
| catppuccin-latte | `eff1f5` | `4c4f69` | `ccd0da` | `9ca0b0` | `dc8a78` | `8839ef` (mauve) | `1e66f5` (blue) |

Light schemes need GTK `color-scheme = prefer-light` (see
[`theming-architecture.md`](theming-architecture.md) → "Per-surface dark/light handling"). A
`solarized-light` variant swaps the base tones (`bg=fdf6e3`, `fg=657b83`, `surface=eee8d5`,
`muted=93a1a1`) and likewise sets `prefer-light`.

## Semantic hues (red / green / yellow / blue / magenta / cyan)

| Scheme | red | green | yellow | blue | magenta | cyan |
|---|---|---|---|---|---|---|
| catppuccin-mocha | `f38ba8` | `a6e3a1` | `f9e2af` | `89b4fa` | `f5c2e7` | `94e2d5` |
| catppuccin-frappe | `e78284` | `a6d189` | `e5c890` | `8caaee` | `f4b8e4` | `81c8be` |
| catppuccin-macchiato | `ed8796` | `a6da95` | `eed49f` | `8aadf4` | `f5bde6` | `8bd5ca` |
| catppuccin-latte | `d20f39` | `40a02b` | `df8e1d` | `1e66f5` | `ea76cb` | `179299` |
| gruvbox | `cc241d` | `98971a` | `d79921` | `458588` | `b16286` | `689d6a` |
| nord | `bf616a` | `a3be8c` | `ebcb8b` | `81a1c1` | `b48ead` | `8fbcbb` |
| tokyo-night | `f7768e` | `9ece6a` | `e0af68` | `7aa2f7` | `bb9af7` | `7dcfff` |
| rose-pine | `eb6f92` | `31748f` | `f6c177` | `9ccfd8` | `c4a7e7` | `9ccfd8` |
| dracula | `ff5555` | `50fa7b` | `f1fa8c` | `bd93f9` | `ff79c6` | `8be9fd` |
| everforest | `e67e80` | `a7c080` | `dbbc7f` | `7fbbb3` | `d699b6` | `83c092` |
| kanagawa | `e46876` | `98bb6c` | `e6c384` | `7e9cd8` | `957fb8` | `6a9589` |
| solarized-dark | `dc322f` | `859900` | `b58900` | `268bd2` | `d33682` | `2aa198` |

Notes:

- **Dracula** has no pure blue — purple stands in for `blue`. Bright variants exist for terminal
  use (`ff6e6e`/`69ff94`/`ffffa5`/`d6acff`/`ff92df`/`a4ffff`).
- **Gruvbox** bright variants: red `fb4934`, green `b8bb26`, yellow `fabd2f`, blue `83a598`,
  magenta `d3869b`, cyan `8ec07c`.
- **Rosé Pine**'s named roles: `love`/`gold`/`pine`/`foam`/`iris`/`rose` map to red/yellow/green-ish/
  cyan/magenta/cursor.
- **Solarized** intentionally repurposes "bright" ANSI slots as the base0x tonal greys + violet
  (`6c71c4`) and orange (`cb4b16`) — a deliberate low-contrast design (Ethan Schoonover). Do not
  rebrighten on the dark variant.

## Mapping richer scheme catalogs onto the 12-key contract

Several upstream scheme systems ship more named tokens than our 12-key contract. The mapping
strategy below is what the corpus rices actually do (cross-checked against the noctalia /
DankMaterialShell / HyprPanel JSONs).

### Catppuccin (26 named colors → 12 keys)

Catppuccin's palette is `rosewater sky sapphire blue lavender mauve red maroon peach yellow green
teal flamingo pink + base mantle crust + text subtext0 subtext1 surface0 surface1 surface2 overlay0
overlay1 overlay2`. The corpus collapse:

| Catppuccin token | Our key |
|---|---|
| `base` | `bg` |
| `text` | `fg` |
| `surface0` (or `surface1` for cards) | `surface` |
| `overlay0` / `overlay1` | `muted` |
| `rosewater` | `cursor` |
| `mauve` (or `blue` on accent2 swap) | `accent` |
| `blue` | `accent2` |
| `red`/`green`/`yellow`/`blue`/`pink`/`teal` | `red green yellow blue magenta cyan` |
| `surface1` | `color0` (ANSI black) |
| `subtext0` | `color7` (ANSI white) |
| `surface2` | `color8` (ANSI bright-black) |
| `subtext1` | `color15` (ANSI bright-white) |

Mantle/crust/peach/maroon/flamingo/lavender/sapphire/sky/overlay2 are dropped — apps that want them
re-derive via CSS `alpha()`/`color-mix()` from the kept tokens (noctalia: `mPrimary` opaqued for
focus rings; waybar: `alpha(@accent, 0.4)` for hover).

### Material You / Material 3 (40+ M3 roles → 12 keys)

DankMaterialShell's `matugen/templates/*` is the canonical mapping for M3 → our contract (the
template in our tree, `palette.matugen.tmpl`, already follows it):

| M3 role | Our key |
|---|---|
| `surface` (or `surface_container_low`) | `bg` |
| `on_surface` | `fg` |
| `surface_container` (or `surface_container_high`) | `surface` |
| `outline` | `muted`, `color8` |
| `primary` | `accent`, `cursor` |
| `secondary` | `accent2`, `yellow` |
| `tertiary` | `green`, `magenta` |
| `error` | `red` |
| `on_surface_variant` | `color7` |
| `on_surface` | `color15` |

ANSI `color1..6` becomes lossy because M3 has only 3 "named" hues (primary/secondary/tertiary) plus
error. **DankMaterialShell's workaround**: it injects a separate `dank16` namespace into matugen's
import data at runtime (`generateDank16Variants` in `core/internal/matugen/`), letting templates
write `{{dank16.color3.default.hex}}` for ANSI cells and `{{colors.primary.default.hex}}` for
M3 roles. Our `palette.matugen.tmpl` currently duplicates `error/tertiary/secondary` across the ANSI
slots — this is the "MD3 → ANSI is **approximate**" caveat (already flagged in `wallpaper.md`).
If the orchestrator wants terminal-accurate matugen output, the path is to adopt a `dank16`-style
sidecar generator. **Flagged for theming-architecture.md**, not a key change.

### Wallust / pywal (true 16 colors)

Wallust extracts `color0..15` directly from the wallpaper (palette modes `dark`, `dark16`,
`harddark`, `harddark16`, `softdark`, `softdark16`, `light`, `light16`, `softlight`, `softlight16`).
Trivial map: `color0..15` straight through, `bg=background`, `fg=foreground`, `cursor=cursor`,
`accent=color4` (or `color5`), `accent2=color6`. Named hues are derived (`red=color1`, etc.) — see
`palette-from-wallpaper.sh` and JaKooLit's `wallust/templates/colors-waybar.css`.

### Noctalia / hand-rolled JSON

Noctalia's JSON shape is M3-flavored (`mPrimary mOnPrimary mSecondary … mOutline mShadow mHover`)
plus a nested `terminal.{normal,bright}.{black red green yellow blue magenta cyan white}` and
`terminal.{background,foreground,cursor}` block. That **already separates** UI roles from ANSI cells
the way DMS's `dank16` does — a clean reference design for any future matugen sidecar work.

## Catppuccin Mocha — full `color0..15` reference

Use this as the template for the other schemes (map `color1..6` = `red green yellow blue magenta
cyan`; `color8` = `muted`; bright `9..14` ≈ same hues at higher luminance):

```
color0  45475a   color1  f38ba8   color2  a6e3a1   color3  f9e2af
color4  89b4fa   color5  f5c2e7   color6  94e2d5   color7  bac2de
color8  585b70   color9  f38ba8   color10 a6e3a1   color11 f9e2af
color12 89b4fa   color13 f5c2e7   color14 94e2d5   color15 a6adc8
```

## Matching GTK / icon / cursor themes per scheme

When theming GTK/Qt, prefer an installed theme that matches the scheme; otherwise apply the
`gtk.css` color overrides and keep the user's current theme. Common matches (install separately —
many are AUR):

| Scheme | GTK theme (pkg) | Icon theme | Cursor theme |
|---|---|---|---|
| catppuccin-* | `catppuccin-gtk-theme-*` (AUR) | Papirus / Papirus-Dark + `papirus-folders -C <accent>` | catppuccin-cursors-* (AUR) |
| gruvbox | `gruvbox-gtk-theme` (AUR) | Papirus-Dark | Bibata-Modern-Classic |
| nord | `nordic-theme` / `arc` (AUR) | Papirus-Dark | Nordzy-cursors (AUR) |
| tokyo-night | `tokyonight-gtk-theme` (AUR) | Papirus-Dark | Bibata-Modern-Classic |
| rose-pine | `rose-pine-gtk-theme` (AUR) | Papirus | rose-pine-cursor (AUR) |
| dracula | `dracula-gtk-theme` (AUR) | Papirus-Dark (`dracula-icons` AUR) | Bibata-Modern-Classic |
| everforest | `everforest-gtk-theme-git` (AUR) | Papirus-Dark / Everforest-icons | Bibata-Modern-Classic |
| kanagawa | `kanagawa-gtk-theme-git` (AUR) | Papirus-Dark | Bibata-Modern-Classic |
| solarized-* | `solarized-gtk-theme` / `gnome-solarized` | Papirus / Papirus-Dark | Bibata-Modern-Classic |

If the matching theme isn't installed, add its package to the install batch (the component's
`packages.md`) so it lands at A5. The lighter alternative — applying colors via `gtk.css` overrides
— is still valid when the user wants a smaller footprint or the AUR theme is murrine-dependent.

## Caveat — murrine-dependent AUR themes

Several full GTK themes (notably `everforest-gtk-theme-git` and other Fausto-Korpsvart family
themes) `depends=gtk-engine-murrine`, which on current Arch pulls in AUR `gtk2` (GTK2 was dropped
from the repos). That builds GTK2 from a giant source clone which often fails on HTTP/2, and `yay`
rolls the whole thing back. **murrine is GTK2-only** — skip the package and build the theme from
SCSS with `sassc` (`themes/build.sh` + `install.sh -d ~/.local/share/themes -c dark -t <accent>
--libadwaita`), copying the repo's `icons/` for matching folder colors.

Full recipe + the `GTK_THEME`-env / cursor gotchas → see
[`theming-architecture.md`](theming-architecture.md) → "GTK gotchas".

## Gaps surfaced by the deep-research pass

These are findings the orchestrator should triage — not changes this doc made unilaterally.

### No high-contrast scheme exists in any corpus rice

The accessibility deep-research agent surveyed all 19 corpus rices and confirmed **none** ships a
high-contrast palette. The matugen-bank rices (HyprPanel, DMS, end-4, ML4W, dusky) optimize for
Material You aesthetic contrast (~3.5–4.5:1, AA only for large text); the static-scheme rices ship
the upstream theme as-published — Catppuccin Mocha hits ~5–6:1 (AA body, not AAA), Gruvbox ~7:1
(AAA only between the darkest and lightest tokens), Tokyo Night ~4.5:1.

A `high-contrast-dark` / `high-contrast-light` scheme entry would need:
- Forced **WCAG-AAA** contrast (≥ 7:1 normal text, ≥ 4.5:1 large text) on every `fg`-vs-`bg` and
  `accent`-vs-`bg` pairing. The other 12 schemes' `muted` token typically drops below 4.5:1 against
  `bg` — that token would have to be deliberately brightened or removed for the high-contrast
  variant.
- A **fixed accent** (e.g. pure `ffff00` for dark, `0000ff` for light) that doesn't drift across
  wallpapers — i.e. the scheme must **opt out of the matugen path** (`scheme=high-contrast-*` means
  `rice wallpaper` should skip `palette-from-wallpaper.sh` and keep the fixed palette).
- A note that GTK4 / libadwaita already exposes its own AccessibleHighContrast preference; setting
  ours overrides any system one for our rendered components.

**Flagged for orchestrator decision** — adding a new `scheme` enum value ripples into:
- `_shared/palette-schema.md` (the `scheme=` comment lists the legal values),
- `palettes.md` (a new row in the catalog table),
- `components/widgets/interview.md` (the palette-pick AskUserQuestion list),
- `wallpaper.md` (an `any`-bucket wallpaper for high-contrast, or skip-wallpaper note),
- `palette-from-wallpaper.sh` (must early-return when `scheme=high-contrast-*`).

### Adjacent: no `font_ui_scale` metadata key

Accessibility agent also noted no rice exposes a shared per-rice font-scale knob (DMS's settings
.json has one but it's local to DMS). Not a palette key — `font_ui` already carries the size — but
calling it out here so the next pass on `fonts.md` can decide whether to add `font_ui_scale` as a
multiplier metadata key alongside `font_ui` / `font_mono`.

### Adjacent: Material 3 motion curves are not colors

Widgets agent observed that M3 ships standard motion curves (standard/emphasized/accel/decel) which
DMS and noctalia bake into their shells. Not palette keys — but if `palettes.md` ever expands to "what
comes with each scheme", they belong in [`theming-architecture.md`](theming-architecture.md), not
here.

## Cross-references

- Palette key list and `palette.conf` schema → [`_shared/palette-schema.md`](../_shared/palette-schema.md).
- Per-component colors variable names → [`_shared/colors-contract.md`](../_shared/colors-contract.md).
- Wallpapers tagged per scheme → [`wallpaper.md`](wallpaper.md) → "Curated theme wallpapers".
- Matugen MD3 mapping and the `dank16` sidecar pattern → [`wallpaper.md`](wallpaper.md) → "Dynamic
  theming"; the engine template is [`palette.matugen.tmpl`](palette.matugen.tmpl).
- The interview asks the palette pick at component 12 (see
  [`_interview-protocol.md`](../_interview-protocol.md) → "Components walked").

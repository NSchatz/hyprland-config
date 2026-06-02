# Named Palettes

Each scheme is mapped to the palette contract from `theming.md`. Hex is `RRGGBB` (add `#`/`rgba`
per app). Pick one accent (the listed `accent` is a sensible default — let the user override). Each
scheme also ships **6–8 curated accent variants** in `../assets/accents.tsv`; list them with
`rice accents <scheme>` and swap with `rice accent <name|hex>` (`--pin` to keep it across re-themes).
For terminal `color0..15`, Catppuccin Mocha's full mapping is given as the reference pattern;
for others, map `color1..6` = `red green yellow blue magenta cyan`, `color0`=bg-ish, `color7/15`=fg-ish,
`color8` = `muted`, and bright `9..14` ≈ the same hues.

## Catppuccin Mocha (dark)

| Role | Hex | | Role | Hex |
|---|---|---|---|---|
| bg | 1e1e2e | | accent | cba6f7 (mauve) |
| fg | cdd6f4 | | accent2 | 89b4fa (blue) |
| surface | 313244 | | red | f38ba8 |
| muted | 6c7086 | | green | a6e3a1 |
| cursor | f5e0dc | | yellow | f9e2af |
| | | | blue | 89b4fa |
| | | | magenta | f5c2e7 |
| | | | cyan | 94e2d5 |

Terminal 16: `color0 45475a` `1 f38ba8` `2 a6e3a1` `3 f9e2af` `4 89b4fa` `5 f5c2e7` `6 94e2d5`
`7 bac2de` `8 585b70` `9 f38ba8` `10 a6e3a1` `11 f9e2af` `12 89b4fa` `13 f5c2e7` `14 94e2d5`
`15 a6adc8`.

## Catppuccin Latte (light)

bg `eff1f5` · fg `4c4f69` · surface `ccd0da` · muted `9ca0b0` · accent `8839ef` (mauve) ·
accent2 `1e66f5` (blue) · red `d20f39` · green `40a02b` · yellow `df8e1d` · blue `1e66f5` ·
magenta `ea76cb` · cyan `179299`. Set GTK `color-scheme` to `prefer-light`.

## Gruvbox (dark, medium)

bg `282828` · fg `ebdbb2` · surface `3c3836` · muted `928374` · accent `fabd2f` (yellow) ·
accent2 `83a598` (blue) · red `cc241d` · green `98971a` · yellow `d79921` · blue `458588` ·
magenta `b16286` · cyan `689d6a`. Bright: red `fb4934` green `b8bb26` yellow `fabd2f`
blue `83a598` magenta `d3869b` cyan `8ec07c`.

## Nord

bg `2e3440` · fg `d8dee9` · surface `3b4252` · muted `4c566a` · accent `88c0d0` (frost) ·
accent2 `5e81ac` · red `bf616a` · green `a3be8c` · yellow `ebcb8b` · blue `81a1c1` ·
magenta `b48ead` · cyan `8fbcbb` · white `e5e9f0`.

## Tokyo Night (Night)

bg `1a1b26` · fg `c0caf5` · surface `24283b` · muted `565f89` · accent `7aa2f7` (blue) ·
accent2 `bb9af7` (purple) · red `f7768e` · green `9ece6a` · yellow `e0af68` · blue `7aa2f7` ·
magenta `bb9af7` · cyan `7dcfff`.

## Rosé Pine

bg `191724` · fg `e0def4` · surface `1f1d2e` · muted `6e6a86` · accent `c4a7e7` (iris) ·
accent2 `31748f` (pine) · red `eb6f92` (love) · green `31748f` (pine) · yellow `f6c177` (gold) ·
blue `9ccfd8` (foam) · magenta `c4a7e7` (iris) · cyan `9ccfd8` (foam) · rose `ebbcba`.

## Catppuccin Frappé (dark, warmer)

bg `303446` · fg `c6d0f5` · surface `414559` · muted `737994` · cursor `f2d5cf` ·
accent `ca9ee6` (mauve) · accent2 `8caaee` (blue) · red `e78284` · green `a6d189` ·
yellow `e5c890` · blue `8caaee` · magenta `f4b8e4` (pink) · cyan `81c8be` (teal).

## Catppuccin Macchiato (dark)

bg `24273a` · fg `cad3f5` · surface `363a4f` · muted `6e738d` · cursor `f4dbd6` ·
accent `c6a0f6` (mauve) · accent2 `8aadf4` (blue) · red `ed8796` · green `a6da95` ·
yellow `eed49f` · blue `8aadf4` · magenta `f5bde6` (pink) · cyan `8bd5ca` (teal).

## Dracula

bg `282a36` · fg `f8f8f2` · surface `44475a` · muted `6272a4` (comment) · accent `bd93f9` (purple) ·
accent2 `ff79c6` (pink) · red `ff5555` · green `50fa7b` · yellow `f1fa8c` · blue `bd93f9`
(Dracula has no pure blue — purple stands in) · magenta `ff79c6` · cyan `8be9fd`. Bright variants
exist (`ff6e6e`/`69ff94`/`ffffa5`/`d6acff`/`ff92df`/`a4ffff`).

## Everforest (dark, medium)

bg `2d353b` · fg `d3c6aa` · surface `3d484d` · muted `7a8478` · accent `a7c080` (green) ·
accent2 `83c092` (aqua) · red `e67e80` · green `a7c080` · yellow `dbbc7f` · blue `7fbbb3` ·
magenta `d699b6` · cyan `83c092`. Soft, low-contrast forest palette (sainnhe/everforest).

## Kanagawa (Wave)

bg `1f1f28` · fg `dcd7ba` · surface `2a2a37` · muted `727169` · accent `7e9cd8` (crystalBlue) ·
accent2 `957fb8` (oniViolet) · red `e46876` (waveRed) · green `98bb6c` (springGreen) ·
yellow `e6c384` (carpYellow) · blue `7e9cd8` · magenta `957fb8` · cyan `6a9589` (waveAqua).
Muted "Great Wave" ink palette (rebelot/kanagawa.nvim).

## Solarized Dark

bg `002b36` (base03) · fg `839496` (base0) · surface `073642` (base02) · muted `586e75` (base01) ·
accent `268bd2` (blue) · accent2 `2aa198` (cyan) · red `dc322f` · green `859900` · yellow `b58900` ·
blue `268bd2` · magenta `d33682` · cyan `2aa198` · violet `6c71c4` · orange `cb4b16`. Note: Solarized's
"bright" ANSI slots are intentionally repurposed as the base0x tonal greys + violet/orange, not lighter
hues — a deliberate low-contrast design (Ethan Schoonover). A `solarized-light` swaps the base tones
(bg `fdf6e3`, fg `657b83`) and needs GTK `color-scheme = prefer-light`.

---

## Matching GTK / icon / cursor themes per scheme

When theming GTK/Qt, prefer an installed theme that matches the scheme; otherwise just apply the
gtk.css color overrides and keep the user's current theme. Common matches (install separately):

| Scheme        | GTK theme (pkg)                     | Cursor / icons                          |
|---------------|-------------------------------------|-----------------------------------------|
| Catppuccin    | `catppuccin-gtk-theme-*` (AUR)      | catppuccin-cursors-*; Papirus(-Dark)    |
| Gruvbox       | `gruvbox-gtk-theme` (AUR)           | Bibata; Papirus-Dark                    |
| Nord          | `nordic-theme`/`arc` (AUR)          | Nordzy-cursors; Papirus-Dark            |
| Tokyo Night   | `tokyonight-gtk-theme` (AUR)        | Bibata; Papirus-Dark                    |
| Rosé Pine     | `rose-pine-gtk-theme` (AUR)         | rose-pine-cursor; Papirus               |
| Dracula       | `dracula-gtk-theme` (AUR)           | Bibata; Papirus-Dark (dracula-icons)    |
| Everforest    | `everforest-gtk-theme-git` (AUR)    | Bibata; Papirus-Dark                    |
| Kanagawa      | `kanagawa-gtk-theme-git` (AUR)      | Bibata; Papirus-Dark                    |
| Solarized     | `solarized-gtk-theme`/`gnome-solarized` | Bibata; Papirus(-Dark)              |

If the matching theme isn't installed, do not install it — apply colors via `gtk.css` overrides
and tell the user the package if they want the full theme.

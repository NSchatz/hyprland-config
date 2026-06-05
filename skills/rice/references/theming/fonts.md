# Fonts

Fonts are a first-class theming choice — **present them to the user**, don't silently pick. Three
roles cover every surface:

- **UI / sans** — GTK app text, document UI, hyprlock greetings, launcher prompts. E.g. Inter,
  Cantarell, Noto Sans, Adwaita Sans, Rubik, Google Sans Flex.
- **Monospace** — terminal, code, the bar, the prompt. Use a **Nerd Font** here so glyph icons
  render.
- **Nerd Font** — a base monospace font patched with icon glyphs (powerline / Font Awesome /
  Material) used by the **status bar, fetch tools, the shell prompt, and notifications**. Without
  one, those glyphs show as tofu boxes (▯).

The interview asks the font picks at component 13 (see
[`_interview-protocol.md`](../_interview-protocol.md) → "Components walked"). The picks land in
`palette.conf` as `font_ui = Inter 11` and `font_mono = JetBrainsMono Nerd Font 11` (family **and**
size — see [`_shared/palette-schema.md`](../_shared/palette-schema.md) → "Metadata keys").

> A rice's **terminal monospace** is an *independent* pick from `font_mono`: the rice writes
> `font_mono` into the bar, prompt, notifications, and widgets; the terminal emulator's own
> `font_family` (`components/terminal/template.md`) is whatever the user chose for ANSI text and
> may differ (e.g. JetBrains Mono NF in the bar but Maple Mono NF in kitty per `Matt-FTW/dotfiles`).
> Most rices use one mono everywhere for coherence — but the contract allows the split.

## Detection

`scripts/detect-theme-tools.sh` emits:

```
HAVE_NERD_FONT=1                  # any Nerd Font is installed
MISSING_NERD_FONT=1               # none found
FONT_MONO=JetBrainsMono Nerd Font,Hack Nerd Font,…
FONT_SANS=Inter,Cantarell,Noto Sans,…
```

Use those values to **populate the menu with real choices** — prefer an already-installed Nerd
Font as the monospace default; offer to install one (and recommend a universal-fallback —
**JetBrainsMono Nerd Font** is the safe pick) only if `MISSING_NERD_FONT=1`. Direct queries:

```bash
fc-list : family | sort -u            # every installed family
fc-list :spacing=100 -f "%{family[0]}\n" | sort -u   # monospace only (omarchy's filter)
```

The `:spacing=100` filter is what `basecamp/omarchy bin/omarchy-font-list` uses to populate its
monospace-only picker — `100` is fontconfig's "mono" spacing constant, so it cleanly excludes UI
sans families from the mono menu without name-pattern matching.

Detection seeds the option **order** (matching pick is listed first) — it does not skip the
question. The user is always shown the catalog and picks consciously (per
[`_interview-protocol.md`](../_interview-protocol.md) → "Strict — ask every question").

## Catalog (suggest packages; do not auto-install)

### Monospace / Nerd Fonts

| Family (use in config) | Arch package | Corpus rices that ship it as default |
|---|---|---|
| JetBrainsMono Nerd Font | `ttf-jetbrains-mono-nerd` | omarchy, HyDE, ML4W, end-4 (lock/term), JaKooLit (terminal alt), most |
| JetBrainsMono Nerd Font **Propo** | `ttf-jetbrains-mono-nerd` | binnewbs (proportional spacing in waybar) |
| FiraCode Nerd Font | `ttf-firacode-nerd` | JaKooLit alt |
| CaskaydiaCove Nerd Font (Cascadia) | `ttf-cascadia-code-nerd` | HyDE (kitty), caelestia (`CaskaydiaCove NF`) |
| Hack Nerd Font | `ttf-hack-nerd` | — |
| Iosevka (+ FontAwesome glyphs) | `ttf-iosevka` + `otf-font-awesome` | linuxmobile (no Nerd Font; pulls FA directly) |
| Maple Mono NF | `ttf-maple-font` | Matt-FTW (bar + notifications) |
| Commit Mono Nerd Font | `ttf-commit-mono-nerd` (AUR) | dusky `01_mechabar_h` |
| FantasqueSansM Nerd Font Mono | `ttf-fantasque-sans-mono` (Nerd patched) | JaKooLit (kitty) |
| Fira Code | `ttf-fira-code` (+ Nerd Symbols Only as fallback) | DankMaterialShell `monoFontFamily` |
| JetBrains Mono NF / NFM | `ttf-jetbrains-mono-nerd` | end-4 (`JetBrains Mono NF`), binnewbs hyprlock |
| Victor Mono Bold Italic | `ttf-victor-mono-nerd` | end-4 hyprlock display |
| (plain, no glyphs) JetBrains Mono | `ttf-jetbrains-mono` | dev work without bar/prompt icons |

### UI / sans

| Family | Arch package | Corpus rices |
|---|---|---|
| Inter | `inter-font` | many; widget-shell default |
| Inter Variable | `inter-font` | DankMaterialShell `fontFamily` |
| Cantarell | `cantarell-fonts` | GNOME default |
| Noto Sans | `noto-fonts` | broad coverage |
| Adwaita Sans | (ships with GTK) | binnewbs hyprlock clock |
| Fira Sans | `ttf-fira-sans` | ML4W default (rofi + waybar) |
| Space Grotesk | `ttf-space-grotesk` | end-4 (`expressive`) |
| Lexend | `ttf-lexend` | readability-tuned |
| Rubik | `ttf-rubik` | caelestia `sans` + `clock` default |
| Google Sans Flex | (manual; Google webfont) | end-4 (`main`, `numbers`, `title`); fuzzel + hyprlock |
| Readex Pro | `ttf-readex-pro` | end-4 (`reading`) |
| Atkinson Hyperlegible Next | `ttf-atkinson-hyperlegible` | dusky `02_reminiscent_h` (a11y-tuned) |
| Liberation Sans | `ttf-liberation` | omarchy `sans-serif` fontconfig alias |

### Material-You / Quickshell icon fonts

| Family | Source | Used by |
|---|---|---|
| Material Symbols Rounded | Google webfont (`woff2`/`ttf`) | end-4 (`iconNerd`/`font_material_symbols`), DankMaterialShell (`MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf` bundled in `quickshell/assets/fonts/material-design-icons/`), caelestia (`material` family) |
| Tabler Icons | `ttf-tabler-icons` (or vendored) | noctalia (`Assets/Fonts/tabler/noctalia-tabler-icons.ttf`), Ax-Shell (`assets/fonts/tabler-icons/tabler-icons.ttf`) |

> These are **separate** from the rice's monospace Nerd Font — Material You shells use the M3 icon
> font for chrome glyphs and a Nerd Font (or none) for terminal/code surfaces. Quickshell singletons
> wire them as a third family alongside `fontUi`/`fontMono`.

### Fallback / glyph add-ons

| Family | Arch package | Use |
|---|---|---|
| Noto Color Emoji | `noto-fonts-emoji` | universal emoji fallback |
| Font Awesome 6/7 | `otf-font-awesome` | waybar icon classes; ml4w lists 6 **and** 7 (`"Font Awesome 7 Free", "Font Awesome 7 Brands", "Font Awesome 6 Free", "Font Awesome 6 Brands"`) so unchanged config keeps working across an FA major-version bump |
| Nerd Fonts Symbols Only | `ttf-nerd-fonts-symbols` / `-mono` | symbol fallback **without** changing text font (the rice that wants Iosevka or Fira Code body + Nerd-style icons uses this — linuxmobile's `FontAwesome` slot is the analogue) |
| Noto Sans CJK | `noto-fonts-cjk` | CJK fallback in waybar (`linuxmobile` lists it explicitly in the `font-family` chain) |

The exact family **string** to use in configs is the `fc-list` family name (e.g. `JetBrainsMono
Nerd Font` — not the package name `ttf-jetbrains-mono-nerd`). The detect script's `FONT_MONO=` /
`FONT_SANS=` lines already give usable strings.

## Family vs size split (and how consumers handle it)

`palette.conf` stores the **full descriptor** with a trailing size — `font_ui = Inter 11`,
`font_mono = JetBrainsMono Nerd Font 11`. Consumers split it:

- **GTK / gsettings / `settings.ini` / hyprlock** want the **full descriptor** (`Inter 11`).
- **kitty `font_family`, waybar `font-family`, QML `font.family`, fontconfig aliases** want **just
  the family** — the engine's render strips the trailing integer (and optional `Bold`/`Italic`)
  before writing.

Per-app **size unit** is *not* uniform — the engine's renderer normalises the integer from
`font_ui`/`font_mono` to whatever unit the target app expects:

| App | Size unit | Example |
|---|---|---|
| rofi (`*{font:…}`) | **point** | `JetBrainsMono Nerd Font 11` |
| fuzzel (`font=`) | **point** (suffixed `:size=`) | `JetBrainsMono Nerd Font:size=11` (and supports `:weight=medium`, see end-4) |
| foot (`font=`) | **point** (suffixed `:size=`) | `JetBrainsMono Nerd Font:size=11` |
| kitty (`font_size`) | **point** (`pt`, separate line from `font_family`) | `font_size 11.0` |
| waybar (`font-size`) | **px** (GTK CSS) | `font-size: 13px;` |
| QML (`font.pixelSize`) | **px** | `font.pixelSize: 14` |
| hyprlock (per-label `font_size`) | **integer pt at logical resolution** | `font_size = 64` for clock display |

This is why a literal `11` value can mean two different visual sizes across surfaces — coherence
needs the engine to keep waybar `px` ≈ 1.4× the rofi/kitty `pt` (the GTK→CSS `px` vs typographic
`pt` ratio at 96 dpi). The rice doesn't expose this knob today — it ships one px size for GTK
surfaces and one pt size for terminal/launcher surfaces.

The widget shells (`eww`, `ags`, `quickshell`) need the bare family too — see
[`components/widgets/template.md`](../components/widgets/template.md) → "Fonts".

## Real-world pairings (what the big rices ship)

One UI sans + one monospace Nerd Font is the universal pattern; the Nerd side supplies all the
bar/prompt/fetch glyphs. Material-You shells add a third **icon font** (Material Symbols Rounded
or Tabler Icons) for chrome glyphs. Cite when recommending:

| Rice | UI / sans | Mono / Nerd | Icon font (M3 shells only) | Source |
|---|---|---|---|---|
| **omarchy** | Liberation Sans (fontconfig `sans-serif`) | **JetBrainsMono Nerd Font** (fontconfig `monospace`) | — | `config/fontconfig/fonts.conf` |
| **HyDE** | theme-driven (`fc-list` at runtime) | **CaskaydiaCove Nerd Font Mono** (kitty); JetBrainsMono NF (waybar) | — | `Configs/.config/{kitty,waybar}/…` |
| **JaKooLit** | Noto Sans | **FantasqueSansM Nerd Font Mono** (kitty); JetBrainsMono Nerd Font (waybar `97%`) | — | `config/{kitty,waybar/…}` |
| **ml4w** | Fira Sans (rofi `Fira Sans 11`; waybar `Fira Sans Semibold` + FA 6+7 chain) | JetBrainsMono Nerd Font (term) | — | `dotfiles/.config/{rofi,waybar,kitty}/…` |
| **Matt-FTW** | — (mono everywhere) | **Maple Mono NF** (waybar + swaync + rofi `Maple Mono NF 10.5`); kitty `JetBrains Maple Mono` with explicit `bold_font`/`italic_font`/`bold_italic_font` Maple variants | — | `.config/{waybar,swaync,rofi,kitty,hypr}/…` |
| **dusky** (mechabar) | sans-serif fallback | **Commit Mono Nerd Font** bold 16px | — | `.config/waybar/01_mechabar_h/style.css` |
| **dusky** (reminiscent) | **Atkinson Hyperlegible Next** (a11y-tuned) | JetBrainsMono NF fallback | — | `.config/waybar/02_reminiscent_h/style.css` |
| **binnewbs** | Adwaita Sans (hyprlock clock) | **JetBrainsMono Nerd Font Propo** waybar; `JetBrainsMono NFM` hyprlock input | — | `.config/{waybar/style/islands.css, hypr/hyprlock.conf}` |
| **linuxmobile** | — | Iosevka + FontAwesome + Noto Sans CJK (chained — **not** a Nerd Font) | — | `.config/waybar/style.css` |
| **end-4** (quickshell) | **Google Sans Flex** (`main`, `numbers`, `title`, `clock` in matugen template), Readex Pro (`reading`), Space Grotesk (`expressive`) | **JetBrains Mono NF** (`monospace`, `iconNerd`) | **Material Symbols Rounded** (`$font_material_symbols` in hyprlock matugen template) | `dots/.config/quickshell/ii/modules/common/Config.qml`, `hyprlock/colors.conf` |
| **caelestia** (quickshell) | **Rubik** (`sans` + `clock`) | **CaskaydiaCove NF** | **Material Symbols Rounded** (`material`) | `plugin/src/Caelestia/Config/appearanceconfig.hpp` |
| **DankMaterialShell** | **Inter Variable** (`fontFamily`) | **Fira Code** (`monoFontFamily`) | **Material Symbols Rounded** (bundled `MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf` variable font) | `quickshell/Common/SettingsData.qml` |
| **noctalia** | empty string defaults (user-picked via FontService `loadFontsViaFcList()`) | (same) | **Tabler Icons** (vendored `noctalia-tabler-icons.ttf`) | `Services/System/FontService.qml`, `Assets/settings-default.json` |
| **Ax-Shell** | (matugen-driven) | — | **Tabler Icons** (vendored) | `assets/fonts/tabler-icons/` |
| **SDDM** (catppuccin, sugar-candy) | Noto Sans | — (login) | — | `Source/arcs/Sddm_Candy.tar.gz` |

**JetBrainsMono Nerd Font is the single most common mono** across surveyed Waybar rices (omarchy,
HyDE, ML4W, end-4 kitty/term, JaKooLit, binnewbs) — the safe universal-fallback recommendation
when `MISSING_NERD_FONT=1`. **Material-You Quickshell shells** (end-4, caelestia, DMS) all settle
on **Material Symbols Rounded** as the chrome icon font (not a Nerd Font for the bar/widgets);
**Tabler Icons** is the second-tier choice (noctalia, Ax-Shell).

Tasteful pairings drawn from the corpus:

- **omarchy / safe universal**: Inter + JetBrainsMono Nerd Font
- **Material You (Quickshell)**: Inter Variable + Fira Code + Material Symbols Rounded (DMS), or
  Google Sans Flex + JetBrains Mono NF + Material Symbols Rounded (end-4), or
  Rubik + CaskaydiaCove NF + Material Symbols Rounded (caelestia)
- **Cozy / writerly**: Readex Pro + Maple Mono NF (Matt-FTW echo)
- **Accessibility-leaning**: Atkinson Hyperlegible Next + JetBrainsMono Nerd Font (dusky
  reminiscent echo) or Lexend + JetBrainsMono Nerd Font

## JetBrainsMono `font-feature-settings` (waybar bar)

JBM ships **stylistic sets** that materially change the bar's look. Both `binnewbs` (`islands.css`)
and the rice's `components/waybar/template.md` ship the same line in the bar's `*{}` rule:

```css
font-feature-settings: '"zero", "ss01", "ss02", "ss03", "ss04", "ss05", "cv31"';
```

- `zero` — slashed/dotted zero (distinguishes `0` from `O`).
- `ss01-ss05` — JBM stylistic sets (`ss02` is the "old style l", `ss03` cursive italics, etc.).
- `cv31` — character variant (alt asterisk).
- `calt` — contextual alternates (ligatures); usually on by default.

**Recommended default** when `font_mono` family contains `JetBrains` (the rice's template ships
this gated on JBM). Harmless on other Nerd Fonts (CSS silently ignores unknown features), so the
rice can emit it unconditionally; it just becomes a no-op on Maple/Cascadia/FiraCode. See
`components/waybar/template.md` → JetBrains font-feature note.

## nwg-look "97%/98%" font-size coherence hack

JaKooLit (`config/waybar/style/[WALLUST] ML4W-modern.css`) and binnewbs
(`.config/waybar/style/islands.css`) both ship `font-size: 97%;` / `98%;` with the inline comment
*"set font-size to 100% if font scaling is set to 1.00 using nwg-look"*. This is the corpus's
de-facto workaround for the absence of a shared `font_ui_scale`: the waybar CSS percentage is
authored against the assumption that **nwg-look's GTK text-scaling-factor is non-1.0** (commonly
1.03 or 1.04 after the nwg-look post-install hooks bump it). At default GTK scaling, the waybar
bar would render slightly too large — so the bar's CSS compensates with `97-98%`.

The rice ships `font-size: 13px;` (absolute) by default precisely to avoid this scale-coupling
trap. The percentage form is documented here for users who want JaKooLit/binnewbs's "scale-with-GTK"
behaviour.

## `font_ui_scale` — pending pattern (orchestrator decision)

No rice in the corpus exposes a **shared font-scale variable** that every visual surface's font
config derives from. waybar `font-size`, rofi/fuzzel `font:`, kitty `font_size`, hyprlock
per-label `font_size`, swaync CSS — each is hard-coded per app. GTK `text-scaling-factor` (the
gsettings key the `larger-ui` accessibility helper flips) only reaches xsettings-aware GTK apps;
waybar's GTK CSS reads `font-size: 13px;` directly and ignores the bridge.

**If a future `font_ui_scale: 1.0|1.25|1.5` metadata key ever lands in
`_shared/palette-schema.md`**, every visual `.tmpl` would need to multiply its default font-size
by it before rendering — and waybar would need to switch from `font-size: 13px;` to
`font-size: calc(13px * <scale>);` (GTK CSS supports `calc()` with px). DankMaterialShell already
proves the per-surface form scales (`fontScale: 1.0` + `dankBarFontScale: 1.0` — a second knob for
the bar alone), and caelestia's `FontSize` token bundle carries a `scale` property that multiplies
every named size (`small`/`normal`/`large`/`extraLarge`/`huge`).

Today the rice ships **per-surface absolute sizes** and the `larger-ui` helper bumps only the
monitor scale + GTK text-scaling-factor. See
`components/accessibility/gotchas.md` → "No shared font-scale variable across surfaces" — that
gotcha is the canonical "flag for orchestrator" entry.

## fontconfig generic-alias trick (omarchy)

Map the generic family aliases in `~/.config/fontconfig/fonts.conf` so every app inherits the
rice's fonts without per-app wiring:

```xml
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="family" qual="any"><string>monospace</string></test>
    <edit name="family" mode="append" binding="same">
      <string>JetBrainsMono Nerd Font</string>
    </edit>
  </match>
  <match target="pattern">
    <test name="family" qual="any"><string>sans-serif</string></test>
    <edit name="family" mode="assign" binding="strong">
      <string>Liberation Sans</string>
    </edit>
  </match>
  <alias><family>emoji</family>
    <prefer><family>Noto Color Emoji</family></prefer></alias>
</fontconfig>
```

omarchy's `config/fontconfig/fonts.conf` is the canonical example: `monospace → JetBrainsMono Nerd
Font` (`mode="append" binding="same"` to coexist with system mono), `sans-serif → Liberation Sans`
(`mode="assign" binding="strong"` to override). The `match`-based form catches apps that don't
honor `<alias>` (looking at you, some Electron and Qt builds).

## Cross-surface font-set sweep (the omarchy `omarchy-font-set` pattern)

omarchy ships `bin/omarchy-font-set <family>` that updates **every** surface in one shot:

| Surface | Sweep mechanism |
|---|---|
| alacritty (`~/.config/alacritty/alacritty.toml`) | `sed -i 's/family = "…"/family = "<f>"/g'` |
| kitty (`~/.config/kitty/kitty.conf`) | `sed -i 's/^font_family .*/font_family <f>/g'` + `pkill -USR1 kitty` (live reload) |
| ghostty (`~/.config/ghostty/config`) | `sed -i 's/font-family = "…"/font-family = "<f>"/g'` + `pkill -SIGUSR2 ghostty` |
| foot (`~/.config/foot/foot.ini`) | `sed -i 's/^font=.*/font=<f>:size=9/g'` |
| hyprlock (`~/.config/hypr/hyprlock.conf`) | `sed -i 's/font_family = .*/font_family = <f>/g'` |
| waybar (`~/.config/waybar/style.css`) | `sed -i "s/font-family: .*/font-family: '<f>';/g"` + `omarchy-restart-waybar` |
| swayosd (`~/.config/swayosd/style.css`) | same as waybar + `omarchy-restart-swayosd` |
| fontconfig (`~/.config/fontconfig/fonts.conf`) | `xmlstarlet ed -L -u '//match…/edit/string' -v "<f>"` |
| post-hook | `omarchy-hook font-set "$f"` (user-extension point in `config/omarchy/hooks/font-set.d/`) |

**This is the model for our rice's `font_mono` change path**: re-rendering the `.tmpl`s already
covers waybar/launcher/notifications/widgets/lock-screen/terminal because every visual surface's
config sources the family from a templated colors/font file the engine owns. omarchy's sed-based
sweep is the *manual* equivalent of our render-everything-and-reload — we already win this
comparison.

omarchy also surfaces a UX detail worth copying: **ghostty + foot don't live-reload font** ("You
must restart Ghostty/Foot to see font change" `notify-send` shown after the sweep). The rice's
reload catalog should note these two as restart-required on a font change.

## Per-app font wiring

The interview pick lands in `palette.conf`; the engine writes the family into each surface's
config the first time it's wired:

| Surface | Where the family goes | How |
|---|---|---|
| GTK (live) | `gsettings org.gnome.desktop.interface font-name` / `monospace-font-name` | full descriptor (`Inter 11`) |
| GTK3 / GTK4 `settings.ini` | `gtk-font-name=<UI Font> <size>` | full descriptor — see [theming-architecture.md](theming-architecture.md) |
| kitty | `font_family <Nerd Font>` + `font_size <n>` in `kitty.conf` | family only; optional explicit `bold_font` / `italic_font` / `bold_italic_font` for per-style fonts (Matt-FTW pattern) |
| waybar | `* { font-family: "<Nerd Font>", "Symbols Nerd Font", sans-serif; }` in `style.css` | family only; chain a symbol fallback + `sans-serif` |
| alacritty | `font.normal.family = "<Nerd Font>"` | family only |
| foot | `font=<Nerd Font>:size=<n>` in `foot.ini` | family + size in one string |
| hyprlock | `$font = <UI Font>` then `font_family = $font` per label; size is per-label `font_size = N` | family only; large for clock (64-173 px), small (13-20 px) for input |
| QML (Quickshell) | `font.family: "<Nerd Font>"` via the rendered `Colors.qml` singleton; size on `font.pixelSize` per widget | family only; M3 shells additionally expose `fontMaterial`/`iconNerd` for the icon font |
| GTK4 / libadwaita | `gtk-font-name` in `~/.config/gtk-4.0/settings.ini` | full descriptor |
| fastfetch / neofetch / starship | inherit the terminal's monospace | (no config — just set the terminal) |

Live `gsettings` apply (writes through to running GTK apps):

```bash
gsettings set org.gnome.desktop.interface font-name           'Inter 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11'
```

Reload signals: kitty `kill -SIGUSR1 $(pidof kitty)`, waybar `killall -SIGUSR2 waybar`, ghostty
`pkill -SIGUSR2 ghostty`, foot/alacritty **none — restart required**. The full reload-command
catalog is in [`theming-architecture.md`](theming-architecture.md) → "Apply + reload".

### hyprlock two-font split (corpus pattern)

The corpus is consistent: hyprlock uses **two** font picks, one large UI sans for the clock
display and one mono for the input/status row.

- **binnewbs**: `Adwaita Sans` (clock, `font_size=112`) + `JetBrainsMono NFM` (input, `font_size=18`).
- **end-4** (matugen-rendered): `$font_family_clock = Google Sans Flex Medium` (clock) +
  `$font_family = Google Sans Flex Medium` (everything else) + `$font_material_symbols = Material
  Symbols Rounded` (for chrome glyph labels).
- **JaKooLit**: `Victor Mono Bold Italic` (clock display) + `JetBrainsMono Nerd Font ExtraBold`
  (smaller labels) — both display-typographic picks.
- **Matt-FTW**: `Maple Mono NF` mono everywhere (no split).

Rice template (`components/lock-screen/template.md`) currently emits a single `$font`. Users who
want the dual-font shape can post-edit; consider exposing a `font_clock_family` if a future round
of theming makes this a first-class choice.

## Cursor size

Cursor *theme* is a GTK setting (see [`theming-architecture.md`](theming-architecture.md) →
"Cursor"). Cursor *size* applies live with:

```bash
hyprctl setcursor <Theme> <size>
```

…and persists via `XCURSOR_SIZE` / `HYPRCURSOR_SIZE` in `~/.config/hypr/env.conf` plus
`gtk-cursor-theme-size=<n>` in `~/.config/gtk-{3,4}.0/settings.ini`.

## Glyph rendering depends on the terminal/bar font

`MISSING_NERD_FONT=1` → bar, fetch tools, and the prompt show tofu boxes. Tell the user to install
one of the Nerd Fonts from the catalog above before applying — the GTK `monospace-font-name`
covers apps that honor fontconfig, but the bar/terminal pull their font directly from their own
config.

Two corpus-attested workarounds when the user wants a non-Nerd body font:

1. **Chain Nerd Symbols Only after the body font**: `font-family: "Iosevka", "Symbols Nerd Font
   Mono", "FontAwesome", sans-serif;` — keeps the chosen body font visible while filling icons
   from the symbol layer. `linuxmobile` does exactly this (`Iosevka, FontAwesome, Noto Sans CJK`).
2. **Material Symbols Rounded for non-Waybar shells**: end-4/caelestia/DMS bypass Nerd-Font icons
   in the bar entirely — chrome glyphs come from `Material Symbols Rounded`, leaving the mono
   slot free for non-Nerd choices (Fira Code, JetBrains Mono plain). This only works in shells
   that author every glyph against the M3 icon set; Waybar can't reach it that cleanly.

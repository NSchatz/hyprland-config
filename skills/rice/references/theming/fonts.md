# Fonts

Fonts are a first-class theming choice — **present them to the user**, don't silently pick. Three
roles cover every surface:

- **UI / sans** — GTK app text, document UI, hyprlock greetings. E.g. Inter, Cantarell, Noto Sans,
  Adwaita Sans.
- **Monospace** — terminal, code, the bar. Use a **Nerd Font** here so glyph icons render.
- **Nerd Font** — a base monospace font patched with icon glyphs (powerline / Font Awesome /
  Material) used by the **status bar, fetch tools, the shell prompt, and notifications**. Without
  one, those glyphs show as tofu boxes (▯).

The interview asks the font picks at component 13 (see
[`_interview-protocol.md`](../_interview-protocol.md) → "Components walked"). The picks land in
`palette.conf` as `font_ui = Inter 11` and `font_mono = JetBrainsMono Nerd Font 11` (family **and**
size — see [`_shared/palette-schema.md`](../_shared/palette-schema.md) → "Metadata keys").

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
**JetBrainsMono Nerd Font** is the safe pick) only if `MISSING_NERD_FONT=1`. Direct query:
`fc-list : family | sort -u`.

Detection seeds the option **order** (matching pick is listed first) — it does not skip the
question. The user is always shown the catalog and picks consciously (per
[`_interview-protocol.md`](../_interview-protocol.md) → "Strict — ask every question").

## Catalog (suggest packages; do not auto-install)

### Monospace / Nerd Fonts

| Family (use in config) | Arch package |
|---|---|
| JetBrainsMono Nerd Font | `ttf-jetbrains-mono-nerd` |
| FiraCode Nerd Font | `ttf-firacode-nerd` |
| CaskaydiaCove Nerd Font (Cascadia) | `ttf-cascadia-code-nerd` |
| Hack Nerd Font | `ttf-hack-nerd` |
| Iosevka Nerd Font | `ttf-iosevka-nerd` |
| Maple Mono NF | `ttf-maple-font` |
| (plain, no glyphs) JetBrains Mono | `ttf-jetbrains-mono` |

### UI / sans

| Family | Arch package | Notes |
|---|---|---|
| Inter | `inter-font` | popular modern UI font |
| Cantarell | `cantarell-fonts` | GNOME default |
| Noto Sans | `noto-fonts` | broad coverage |
| Adwaita Sans | (ships with GTK) | default on many systems |
| Fira Sans | `ttf-fira-sans` | ml4w default |
| Space Grotesk | `space-grotesk` | geometric/modern |
| Lexend | `ttf-lexend` | readability-tuned |

### Fallback / glyph add-ons

| Family | Arch package | Use |
|---|---|---|
| Noto Color Emoji | `noto-fonts-emoji` | universal emoji fallback |
| Font Awesome | `otf-font-awesome` | waybar icon classes |
| Nerd Fonts Symbols Only | `ttf-nerd-fonts-symbols` / `-mono` | symbol fallback **without** changing text font |

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

The widget shells (`eww`, `ags`, `quickshell`) need the bare family too — see
[`components/widgets/template.md`](../components/widgets/template.md) → "Fonts".

## Real-world pairings (what the big rices ship)

One UI sans + one monospace Nerd Font is the universal pattern; the Nerd side supplies all the
bar/prompt/fetch glyphs. Cite when recommending:

| Rice | UI / sans | Mono / Nerd |
|---|---|---|
| **omarchy** | Liberation Sans (fontconfig `sans-serif`) | **JetBrainsMono Nerd Font** (fontconfig `monospace`) |
| **HyDE** | theme-driven (resolved at runtime via `fc-list`) | **JetBrainsMono Nerd Font** (de-facto default) |
| **JaKooLit** | Noto Sans | **JetBrainsMono Nerd Font** (+ Fira Code, Fantasque/Victor Mono) |
| **ml4w** | Fira Sans (rofi UI) | JetBrainsMono Nerd Font |
| **Matt-FTW** | — | **Maple Mono NF** |
| **end-4** (quickshell) | Google Sans Flex / Readex Pro / Space Grotesk | JetBrains Mono NF + Material Symbols Rounded |
| **SDDM** (catppuccin, sugar-candy) | Noto Sans | — (login) |

**JetBrainsMono Nerd Font is the single most common mono** across every surveyed rice — the safe
universal-fallback recommendation when `MISSING_NERD_FONT=1`. Tasteful pairings: *Inter + JetBrainsMono
NF* (universal), *Space Grotesk + JetBrains Mono NF* (geometric), *Readex Pro + Maple Mono NF* (cozy).

## fontconfig generic-alias trick (omarchy)

Map the generic family aliases in `~/.config/fontconfig/fonts.conf` so every app inherits the
rice's fonts without per-app wiring:

```xml
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias><family>monospace</family>
    <prefer><family>JetBrainsMono Nerd Font</family></prefer></alias>
  <alias><family>sans-serif</family>
    <prefer><family>Inter</family></prefer></alias>
  <alias><family>emoji</family>
    <prefer><family>Noto Color Emoji</family></prefer></alias>
</fontconfig>
```

## Per-app font wiring

The interview pick lands in `palette.conf`; the engine writes the family into each surface's
config the first time it's wired:

| Surface | Where the family goes | How |
|---|---|---|
| GTK (live) | `gsettings org.gnome.desktop.interface font-name` / `monospace-font-name` | full descriptor (`Inter 11`) |
| GTK3 / GTK4 `settings.ini` | `gtk-font-name=<UI Font> <size>` | full descriptor — see [theming-architecture.md](theming-architecture.md) |
| kitty | `font_family <Nerd Font>` + `font_size <n>` in `kitty.conf` | family only |
| waybar | `* { font-family: "<Nerd Font>", sans-serif; }` in `style.css` | family only |
| alacritty | `font.normal.family = "<Nerd Font>"` | family only |
| foot | `font=<Nerd Font>:size=<n>` in `foot.ini` | family + size in one string |
| hyprlock | `font_family = <UI Font>` in `~/.config/hypr/hyprlock.conf` | family only |
| QML (Quickshell) | `font.family: "<Nerd Font>"` via the rendered `Colors.qml` | family only |
| GTK4 / libadwaita | `gtk-font-name` in `~/.config/gtk-4.0/settings.ini` | full descriptor |
| fastfetch / neofetch / starship | inherit the terminal's monospace | (no config — just set the terminal) |

Live `gsettings` apply (writes through to running GTK apps):

```bash
gsettings set org.gnome.desktop.interface font-name           'Inter 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11'
```

Reload signals: kitty `kill -SIGUSR1 $(pidof kitty)`, waybar `killall -SIGUSR2 waybar`. The full
reload-command catalog is in [`theming-architecture.md`](theming-architecture.md) → "Apply +
reload".

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

# Fonts

Fonts are a first-class theming choice — **present them to the user**, don't silently pick. Three
roles:

- **UI / sans** — GTK app text, document UI. (e.g. Inter, Cantarell, Noto Sans, Adwaita Sans.)
- **Monospace** — terminal, code, the bar. Use a **Nerd Font** here so glyph icons render.
- **Nerd Font** — a base monospace font patched with icon glyphs () used by the **status bar,
  fetch tools, the shell prompt (starship), and notifications**. Without one, those glyphs show as
  tofu boxes (▯). JetBrainsMono Nerd Font, FiraCode Nerd Font, CaskaydiaCove (Cascadia) are common.

## Detecting what's installed

`detect-theme-tools.sh` reports `HAVE_NERD_FONT=1`/`MISSING_NERD_FONT=1`, plus `FONT_MONO=…` and
`FONT_SANS=…` lines listing installed base families. Use those to **present real choices** —
prefer an already-installed Nerd Font as the monospace default; offer to install one (suggest the
package) only if none exists. Direct query: `fc-list : family | sort -u`.

## Catalog (suggest packages; do not auto-install)

**Monospace / Nerd Fonts**

| Family (use in config)        | Arch package                  |
|-------------------------------|-------------------------------|
| JetBrainsMono Nerd Font       | `ttf-jetbrains-mono-nerd`     |
| FiraCode Nerd Font            | `ttf-firacode-nerd`           |
| CaskaydiaCove Nerd Font (Cascadia) | `ttf-cascadia-code-nerd` |
| Hack Nerd Font                | `ttf-hack-nerd`               |
| Iosevka Nerd Font             | `ttf-iosevka-nerd`            |
| (plain, no glyphs) JetBrains Mono | `ttf-jetbrains-mono`      |

**UI / sans**

| Family        | Arch package        | Notes                         |
|---------------|---------------------|-------------------------------|
| Inter         | `inter-font`        | popular modern UI font        |
| Cantarell     | `cantarell-fonts`   | GNOME default                 |
| Noto Sans     | `noto-fonts`        | broad coverage                |
| Adwaita Sans  | (ships with GTK)    | default on many systems       |

The exact family **string** to put in configs is the `fc-list` family name (e.g.
`JetBrainsMono Nerd Font`, not the package name). The detect script's `FONT_MONO=`/`FONT_SANS=`
lines already give usable strings.

## Real-world pairings (what the big rices ship)

One UI sans + one monospace Nerd Font is the universal pattern; the Nerd side supplies all the
bar/prompt/fetch glyphs. What the surveyed rices actually use (cite when recommending):

| Rice | UI / sans | Mono / Nerd | 
|------|-----------|-------------|
| **omarchy** | Liberation Sans (fontconfig `sans-serif`) | **JetBrainsMono Nerd Font** (fontconfig `monospace`) |
| **HyDE** | theme-driven (resolved at runtime via `fc-list`) | **JetBrainsMono Nerd Font** (de-facto default) |
| **JaKooLit** | Noto Sans | **JetBrainsMono Nerd Font** (+ Fira Code, Fantasque/Victor Mono) |
| **ml4w** | Fira Sans (rofi UI) | JetBrainsMono Nerd Font |
| **Matt-FTW** | — | **Maple Mono NF** |
| **end-4** (quickshell) | Google Sans Flex / Readex Pro / Space Grotesk | JetBrains Mono NF + Material Symbols Rounded |
| **SDDM** (catppuccin, sugar-candy) | Noto Sans | — (login) |

**JetBrainsMono Nerd Font is the single most common mono** across every surveyed rice — a safe
default. Tasteful pairings: *Inter or Noto Sans + JetBrainsMono NF* (universal), *Space Grotesk +
JetBrains Mono NF* (geometric/modern), *Rubik/Readex Pro + Maple Mono NF* (cozy/rounded). Login
screens default to Noto Sans.

**fontconfig default-family trick** (omarchy): map the generic aliases in
`~/.config/fontconfig/fonts.conf` so every app inherits the rice's fonts —
`<alias><family>monospace</family><prefer><family>JetBrainsMono Nerd Font</family></prefer></alias>`
(likewise `sans-serif` → your UI font, and `emoji` → `Noto Color Emoji` as universal fallback).

**More Arch packages:** `ttf-maple-font` (Maple Mono NF), `ttf-nerd-fonts-symbols` /
`ttf-nerd-fonts-symbols-mono` (symbol-only fallback — glyphs without changing the text font),
`otf-font-awesome` (waybar icons), `noto-fonts-emoji` (`Noto Color Emoji`), `ttf-lexend`,
`space-grotesk` (UI alternates).

## Applying a font across surfaces

Pick one **UI font** + size and one **monospace/Nerd font** + size, then:

```bash
# GTK / general UI font + monospace font (applies live to GTK apps)
gsettings set org.gnome.desktop.interface font-name            '<UI Font> <size>'    # e.g. 'Inter 11'
gsettings set org.gnome.desktop.interface monospace-font-name  '<Nerd Font> <size>'  # e.g. 'JetBrainsMono Nerd Font 11'
```

- **GTK3 settings.ini** (`~/.config/gtk-3.0/settings.ini`): `gtk-font-name=<UI Font> <size>`.
- **kitty** (`~/.config/kitty/kitty.conf`): `font_family <Nerd Font>` and `font_size <size>`
  (e.g. `font_family JetBrainsMono Nerd Font`). Reload running: `kill -SIGUSR1 $(pidof kitty)`.
- **waybar** (`style.css`): `* { font-family: "<Nerd Font>", sans-serif; }` so module glyphs
  render. Reload: `killall -SIGUSR2 waybar`.
- **alacritty/foot**: `font.normal.family` / `font=<Nerd Font>:size=<n>` respectively.
- **fastfetch/neofetch & the shell prompt**: use whatever font the terminal is set to — set the
  terminal's monospace to a Nerd Font and their glyphs/logos render correctly.

Glyph rendering in the bar/fetch/prompt depends on the **terminal/bar font being a Nerd Font**;
the GTK `monospace-font-name` covers apps that honor it. If `MISSING_NERD_FONT`, tell the user to
install one (table above) — glyph-heavy bars/prompts will otherwise show boxes.

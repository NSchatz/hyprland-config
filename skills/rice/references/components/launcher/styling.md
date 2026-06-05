# Styling Launchers (wofi / rofi / fuzzel / tofi)

The four common Wayland launchers all chase the same look — a centered, floating, rounded panel with a search field on top, a scrollable result list, and one strongly-accented selection bar. Only the *mechanism* differs: wofi is GTK CSS, rofi is its own RASI language, and fuzzel/tofi are flat INI files.

## What you're styling

| Launcher | Config file(s) | Styling language | Preview |
|---|---|---|---|
| **wofi** | `~/.config/wofi/config` (behavior) + `~/.config/wofi/style.css` (look) | GTK3 **CSS** (`#window`, `#input`, `#entry`…) | `wofi --show drun` |
| **rofi** | `~/.config/rofi/config.rasi` + a theme `.rasi` (e.g. `~/.config/rofi/theme.rasi`) | **RASI** (CSS-like box model with `@import`/`@theme`) | `rofi -show drun` or `rofi -show drun -theme theme.rasi` |
| **fuzzel** | `~/.config/fuzzel/fuzzel.ini` | **INI** (`[main]`, `[colors]`, `[border]`) | `fuzzel` (re-reads file on each launch) |
| **tofi** | `~/.config/tofi/config` (or any `*.tofi` via `--config`) | **INI**-ish `key = value` | `tofi-drun \| sh` / `tofi-run \| sh` |

All four re-read their config on launch, so the edit→preview loop is just "save, run again." rofi has the nicest live workflow: `rofi -show drun -theme ./mytheme.rasi` lets you iterate on a theme without touching `config.rasi`.

## Design anatomy — the knobs that change the look

These concepts map across all four; only the key names change.

- **Panel geometry** — width + number of rows + centered anchoring is what produces the "floating box" feeling.
  - wofi: `width`/`height` in `config` (px or `%`), `location=center`.
  - rofi: `window { width: 800px; }`, `listview { lines: 10; columns: 1; }`.
  - fuzzel: `width=` (in **characters**, default 30), `lines=` (default 15), `anchor=center`, `x-margin`/`y-margin`.
  - tofi: `width`/`height` (px or `%`), `anchor = center`, `num-results`.
- **Shape** — corner radius + a thin border. A 1–2px border in the accent color reads as "designed"; a fat 8–12px border reads as a frame.
  - wofi/rofi: `border-radius` + `border`. rofi border is `border: 2px;` on `window`.
  - fuzzel: `[border] radius=` and `width=`.
  - tofi: `corner-radius`, `border-width`, `outline-width` (a second outer ring — usually set to 0).
- **Padding** — interior breathing room. Missing padding is the #1 thing that makes a launcher look cheap. Aim for ~8–20px.
- **The prompt / search field** — the `> ` glyph, the typed text, and the placeholder. Color the prompt with the accent or a muted tone; keep input text at full `fg`.
- **Entry rows** — per-row padding and spacing. Optional zebra striping (wofi `#entry:nth-child(even)`).
- **The SELECTION highlight** — *the highest-impact element.* This is the bar (or text) marking the focused result. Make it the accent: a filled accent background with contrasting text, OR accent-colored text on a subtle surface fill. Everything else can be quiet; this should not be.
- **Icons** — app icons next to entries.
  - wofi: needs `allow_images=true` + `image_size=` in `config` (underscores — wofi rejects hyphenated keys silently); `drun` mode supplies icons.
  - rofi: `configuration { icon-theme: "Papirus"; show-icons: true; }` and `element-icon { size: 24px; }`.
  - fuzzel: icons on by default (`icons-enabled=yes`, `icon-theme=`, `image-size-ratio=`).
  - tofi: no app icons (text-only by design).
- **Typography** — a clean UI font (Inter, Cantarell, Noto Sans) for labels; a mono font (JetBrainsMono) for a dmenu feel. Use a **Nerd Font** if your prompt/labels include glyph icons.
- **Transparency / blur** — translucent background + Hyprland blur is the signature "frosted glass" look. Set the background alpha below `ff`, then add a Hyprland `layerrule` blur on the launcher's namespace (see Pitfalls). wofi blur needs the layerrule; fuzzel/rofi-wayland honor it too.

## How the community styles it

- **Centered blurred pastel panel (Catppuccin)** — the dominant r/unixporn look. Translucent base background (`1e1e2edd`), 1px accent border (mauve `cba6f7`), radius ~12–16px, generous padding. Selection = a subtle surface fill (`585b70`) with the *match* substring colored mauve; prompt in a muted blue. Ports exist for every launcher: [catppuccin/rofi](https://github.com/catppuccin/rofi), [catppuccin/fuzzel](https://github.com/catppuccin/fuzzel), [catppuccin/tofi](https://github.com/catppuccin/tofi), and community wofi themes like [alxndr13/wofi-catppuccin](https://github.com/alxndr13/wofi-catppuccin) / [quantumfate/wofi](https://github.com/quantumfate/wofi).
- **adi1090x rofi "launchers/applets"** — the big, polished rofi set ([adi1090x/rofi](https://github.com/adi1090x/rofi)). Characteristic values: `window { width: 800px; border-radius: 20px; }`, a 1- or 2-column `listview` with `lines: 10`, rounded `element { border-radius: 20px; padding: 5px 10px; }`, and a fully-filled accent `element selected`. Colors live in a shared `colors.rasi` you swap out. This is the source of the "pill-shaped rows" aesthetic.
- **Minimal dmenu-like (fuzzel / tofi)** — flat, fast, often a single accent. fuzzel default is already tasteful (radius 10, 1px border, ~40px horizontal pad). tofi minimal themes use a small box (`width=640 height=24` for a single-line bar, or a centered box with `num-results=5`), `border-width=4` in the accent, `corner-radius` 0–8, selection via `selection-color` only.
- **Accent-bordered floating box** — opaque (or lightly translucent) surface background, a bold 2px accent border, mid radius (10–16px), and an accent-filled selection. Reads as "intentional" without relying on blur. Common in [HyDE](https://github.com/HyDE-Project/HyDE), [JaKooLit](https://github.com/JaKooLit/Hyprland-Dots), and [ml4w](https://github.com/mylinuxforwork/dotfiles) rofi setups.
- **Material 3 token launcher (matugen rices)** — the look ML4W, dusky, and binnewbs all ship: a 47-key M3 token dump (`primary`, `on-primary`, `surface-container-low`, `inverse-surface`, …) emitted by matugen, layouts then reference `@primary`/`@on-surface` directly. Selection = `@primary` background + `@on-primary` text; border = `@outline`. The aesthetic is recognisably "Material You" — high-contrast tonal surfaces, rounded `2em` corners, no skeuomorphism. ML4W extends it with a wallpaper `imagebox` beside the list ([config.rasi](https://github.com/mylinuxforwork/dotfiles/blob/HEAD/dotfiles/.config/rofi/config.rasi)).
- **Wallpaper-as-search-panel** — `imagebox { background-image: url("~/.config/rofi/.current_wallpaper", width); }` paints the inputbar area with the current wallpaper, often beside (ML4W, binnewbs) or behind (JaKooLit `KooL_style-1`) the result list. The rice rewrites a `current_wallpaper.rasi` (or symlinks `.current_wallpaper`) on wallpaper change so the launcher tracks blur + theme together.

## Battle-tested techniques (from real launcher themes)

Concrete, reusable moves harvested from real launcher theme files across the big collections and
rices. Each is attributed and quoted close to verbatim — swap literal hexes for the rice keys.
Grouped by what they buy you.

**Theming workflow — split palette from layout.** This is the single most reusable idiom; every
polished collection does it.
- *rofi: tiny `*{}` color block + reusable layout* (adi1090x, catppuccin/rofi, lr-tech): each theme file is **only** a color block (`* { background-colour: …; selected-normal-background: …; }`) that `@import`s a shared layout `.rasi`. lr-tech's `rounded-template.rasi` is reused by ~10 variants that each supply just an 8-name `bg0..bg3 / fg0..fg3` block. Re-theming = swap one file.
- *rofi: `@theme` indirection for wallpaper-generated palettes* (HyDE): layouts reference `@main-bg`/`@select-bg` from a `theme.rasi` regenerated per wallpaper (`@theme "~/.config/rofi/theme.rasi"`), so all styles re-skin from one machine-written file.
- *fuzzel/tofi: `include=` a colors-only file* (catppuccin/fuzzel, vaelixd, caelestia): keep geometry in `fuzzel.ini` `[main]`, colors in a separate `[colors]` file pulled via `include=`. caelestia points `include` at a `current.ini` **symlink** so the whole desktop reskins at once. catppuccin/fuzzel ships pure `[colors]` files (4 flavors × 14 accents) meant to be `include`d.

**Structure & shape.**
- *Two launcher shapes.* Vertical pill list — `listview { columns: 1 }` + rounded `element { border-radius: 16px }` — or icon grid — `listview { columns: 5–7 }` + `element { orientation: vertical }` + a large `element-icon { size: 72px }` (adi1090x type-3, JaKooLit). 
- *Fullscreen launcher.* rofi: `window { fullscreen: true }` + `listview { columns: 5; lines: 5 }` with **percentage icon size** `element-icon { size: 5% }` so it scales to the screen (JaKooLit `KooL_style-3-FullScreen`). tofi: `width = 100%; height = 100%` + `padding-left = 35%; padding-top = 35%` centers a short list over a dimmed overlay (`background-color = #000A`) (philj56 `fullscreen` theme).
- *Spotlight bar* (lr-tech `spotlight-*`): narrow centered `window { width: 640 }`, a large input font, a search glyph as an inputbar child (`inputbar { children: [icon-search, entry] }`), results dropping below behind a hairline top border (`listview { border: 1px 0 0 }`).
- *Floating top-drop card* (lr-tech `rounded-*`): `window { location: north; border-radius: 24px; padding: 12px }` detaches the launcher from the top edge as a rounded card.
- *Full-height wallpaper sidebar* (HyDE `style_1`): `mainbox { orientation: horizontal; children: ["dummywall","listbox"] }` puts a blurred `wall.blur` image panel beside the list; `entry { enabled: false }` hides search-as-you-type for a clean icon+label column.
- *wofi: transparent window, opaque rounded card* (alxndr13, quantumfate): `window { background-color: transparent }` + an opaque rounded `#outer-box` so the card floats and the compositor blur shows through the gap.

**Selection highlight — three idioms.**
- *Solid accent fill + contrasting text* (adi1090x, JaKooLit, lr-tech rounded): `element selected { background-color: @accent; text-color: @bg }` — the highest-contrast, most-copied highlight.
- *Translucent tinted overlay* (caelestia, adi1090x): the accent at partial alpha — `selection=d19a6687` (~53%) in fuzzel, or rofi `element selected { background-color: white / 5% }` — a soft highlight instead of a solid bar.
- *Accent outline ring* (quantumfate wofi): `#entry:selected { border: 0.11em solid @accent }` rings the focused row rather than filling it; pair with `#text:selected { background: transparent }` so you don't get a doubled highlight.

**Color details.**
- *fuzzel: only the background carries alpha.* The 11 `[colors]` keys are `RRGGBBAA`; convention is `background=…dd` (~87%) and everything else `…ff`. Set `match` **and** `selection-match` to the accent so typed/matched letters glow (catppuccin/fuzzel).
- *tofi: distinct accents per role* (catppuccin/tofi): `prompt-color = #f38ba8` (red), `selection-color = #f9e2af` (yellow) — themes well with as few as four keys (text/prompt/selection/background).
- *rofi: `white/NN%` color algebra* (JaKooLit): alpha-blended literals like `background-color: black/90%`, `border-color: white/30%` for instant translucency without defining vars.
- *wofi zebra rows* (alxndr13): `#entry:nth-child(even) { background-color: <surface-alt> }` for readable striping; a focus glow via `#input:focus { box-shadow: … rgba(accent) }`.

**Sizing & translucency.**
- *`em`/`%` over px for DPI independence* (catppuccin/rofi `size: 1.0000em`, HyDE `width: 63em` / icon `size: 2.8em`, wofi `border: 0.16em`): geometry scales with the configured font size/DPI instead of breaking on a HiDPI monitor.
- *True compositor blur* (adi1090x): `window { transparency: "real" }` in rofi (plus the Hyprland `layerrule` blur on the `rofi` namespace) — without `transparency: "real"`, rofi composites its own opaque background and the layerrule has nothing translucent to blur.
- *fuzzel placement & dismissal* (vaelixd, chikobara): `layer = overlay` to float above Hyprland layers, `exit-on-keyboard-focus-loss = yes` for click-away dismiss, `anchor = top-left` + `x-margin`/`y-margin` for corner (not centered) placement; remember fuzzel `width` is in **characters**, not px.
- *tofi two-ring frame* (philj56 `dos`): `outline-width` is the thin inner line, `border-width` the thick outer band — set `outline-width = 0` for a single clean ring; `hide-cursor = true` for a kiosk/overlay feel.

**Behavior tuning that feels native.**
- *Single-click activation in rofi* (dusky `.config/rofi/config.rasi`, Matt-FTW `.config/rofi/style.rasi`): rofi's default is double-click — feels broken to anyone reaching for the mouse. Set `me-select-entry: ""; me-accept-entry: "MousePrimary";` to map single click to activate. **You must clear `me-select-entry` first**: `MousePrimary` is bound there by default and rofi refuses to bind the same event twice.
- *Frecency-aware fuzzy search in rofi* (dusky): `sort: true; sorting-method: "fzf"; matching: "fuzzy";` — sorts by match quality with launch history breaking ties (PowerToys/Albert style). Pair with `drun-match-fields: "name,generic,exec,keywords"` (drop the default `categories` so Firefox stops matching every Network/WebBrowser query just because its `.desktop` lists those categories — dusky comment, verbatim). Rofi already maintains `~/.cache/rofi3.druncache` launch counts; these three options actually consult it.
- *Hover-to-select* (JaKooLit, Matt-FTW): `hover-select: true;` highlights rows on mouse-over without changing keyboard selection — feels closer to GNOME's overview / spotlight.
- *walker as a service* (upstream `abenz1267/walker/resources/config.toml`): when the daemon is up (`walker --gapplication-service`), `close_when_open = true` makes the same `walker` invocation toggle the window. `click_to_close = true` adds click-outside-to-dismiss. New flat keys in v2.x: `selection_wrap`, `disable_mouse`, `keybind_symbols`, `resume_last_query`, `single_click_activation`.
- *walker compositor blur* (upstream `resources/config.toml`): `ext_background_effect_blur = true` requests the compositor to blur behind the wrapper via `ext-background-effect-v1` — Hyprland supports the protocol, so this replaces the wofi-style `layerrule blur` for walker.

**Palette-token approaches — pick one strategy and propagate.**
- *Material 3 token dump* (ML4W `dotfiles/.config/matugen/templates/rofi-colors.rasi`, dusky `.config/matugen/templates/rofi-colors.rasi`, binnewbs `.config/matugen/templates/rofi-colors.rasi`): the matugen-driven rices ship a 47-key `* {}` block of M3 tokens (`primary`, `on-primary`, `surface-container-low`, `inverse-surface`, `outline-variant`, …) sourced from `matugen.colors.*`. Layouts then reference `@primary` / `@on-surface` directly — perfectly consistent across rofi, gtk, and the bar. Downside: requires matugen and locks you into Material 3 semantics.
- *ANSI-16 + `background`/`foreground` dump* (JaKooLit `config/rofi/wallust/colors-rofi.rasi`): the wallust template emits `color0..color15` + `background`/`foreground`/`border-color` + the rofi-native quad `normal-background / selected-normal-background / urgent-background / active-background` (with foreground pairs). Layouts then reference `@color12` (accent), `@color11` (secondary), `@color13` (urgent). Downside: 16-color terminology bleeds into the launcher CSS.
- *Hybrid (HyDE wallbash)* (`Configs/.config/hyde/wallbash/Wall-Dcol/rofi.dcol`): emits just six semantic names (`main-bg`, `main-fg`, `main-br`, `main-ex`, `select-bg`, `select-fg`) — middle ground between M3's 47 and wallust's 16. Each value is `#<wallbash_pry1>E6` (the `E6` suffix is the alpha; `<wallbash_pry1>` is the wallpaper-derived primary).
- *Disable rofi's default theme before loading yours* (binnewbs `.config/rofi/config.rasi`): `@theme "/dev/null"` at the top of `config.rasi` nullifies the built-in theme so `@import "colors.rasi"` doesn't inherit stale defaults. Without this, rofi merges your theme on top of the system theme and unset properties can come from the wrong place.

**Gradient and image fills (rofi-only).**
- *Linear gradient as a value* (Matt-FTW `.config/rofi/theme/catppuccin-macchiato.rasi`): rofi RASI accepts `linear-gradient()` as an image/color value. Define once — `selected: linear-gradient(to right, #363A4FFF, #B7BDF869);` — then use as `background-image: @selected;` on `element selected.normal`. **Use `background-image`, not `background-color`**: gradients are images in RASI, and `background-color` will silently no-op.
- *Wallpaper inside the launcher* (JaKooLit `KooL_style-1.rasi`, ML4W `config.rasi`): `imagebox { background-image: url("~/.config/rofi/.current_wallpaper", width); }` paints the search panel with the live wallpaper. Pair with a `current_wallpaper.rasi` symlink the rice rewrites on wallpaper change so blur, theme, and the launcher fill all change at once.

## Tasteful default recipe

Each uses the plugin's rice keys (`bg fg surface muted accent accent2 color0..15 font_ui font_mono`, hex **without** `#`). Shown twice: a `{{placeholder}}` template form and a worked **Catppuccin Mocha** example (`bg 1e1e2e`, `fg cdd6f4`, `surface 313244`, `muted 6c7086`, `accent cba6f7`, `accent2 89b4fa`, `font_ui Inter`, `font_mono JetBrainsMono Nerd Font`). Selection = accent; subtle border = accent. This plugin's rice renders `wofi/colors.css` and `rofi/colors.rasi` — `@import` those so re-theming Just Works.

### wofi — `~/.config/wofi/style.css`

```css
@import "colors.css";   /* rendered by the rice: defines @bg @fg @accent ... */

window {
  margin: 0;
  background-color: rgba(30, 30, 46, 0.92);  /* {{bg}} at ~0.92 */
  border-radius: 14px;
  border: 1px solid @accent;                 /* #{{accent}} */
  font-family: "Inter", sans-serif;          /* {{font_ui}} */
  font-size: 14px;
}
#input {
  margin: 10px;
  padding: 8px 12px;
  border-radius: 10px;
  border: none;
  background-color: @surface;                 /* #{{surface}} */
  color: @fg;
}
#inner-box  { margin: 6px; }
#outer-box  { padding: 8px; }
#entry      { padding: 6px 10px; border-radius: 8px; }
#entry image { -gtk-icon-transform: none; }
#text       { color: @fg; }
#entry:selected      { background-color: @accent; }   /* the highlight */
#entry:selected #text { color: @bg; }                 /* contrast on accent */
```

Companion `~/.config/wofi/config`: `allow_images=true`, `image_size=24`, `location=center`, `width=600`, `height=400`, `insensitive=true`. All wofi config keys use **underscores**, never hyphens — `allow-images` is silently ignored.

### rofi — `~/.config/rofi/theme.rasi`

```rasi
@import "colors.rasi"   /* rendered by the rice: * { accent: ...; bg: ...; } */

* {
  bg:      #1e1e2e;   /* {{bg}}      */
  bg-alt:  #313244;   /* {{surface}} */
  fg:      #cdd6f4;   /* {{fg}}      */
  accent:  #cba6f7;   /* {{accent}}  */
  muted:   #6c7086;   /* {{muted}}   */
}
window {
  width: 700px;
  border-radius: 14px;
  border: 1px solid;
  border-color: @accent;
  background-color: @bg;
  padding: 12px;
}
inputbar { spacing: 8px; padding: 8px; margin: 0 0 8px 0;
           background-color: @bg-alt; border-radius: 10px; }
prompt  { text-color: @accent; }
entry   { text-color: @fg; placeholder: "Search…"; placeholder-color: @muted; }
listview { lines: 8; columns: 1; spacing: 4px; scrollbar: false; }
element  { padding: 7px 10px; border-radius: 8px; }
element-icon { size: 22px; }
element selected { background-color: @accent; text-color: @bg; }  /* highlight */
element selected normal.normal { background-color: @accent; text-color: @bg; }
```

Companion `~/.config/rofi/config.rasi`: `configuration { modi: "drun"; show-icons: true; icon-theme: "Papirus"; }` then `@theme "~/.config/rofi/theme.rasi"`.

### fuzzel — `~/.config/fuzzel/fuzzel.ini`

Fuzzel colors are **`RRGGBBAA` hex, no `#`**. Append an alpha pair to any rice color: `{{bg}}ee` → `1e1e2eee`.

```ini
[main]
font=Inter:size=13          ; {{font_ui}}
prompt=">   "
icon-theme=Papirus
icons-enabled=yes
width=32
lines=12
horizontal-pad=20
vertical-pad=12
inner-pad=8
layer=overlay

[colors]
background=1e1e2eee          ; {{bg}} + ee alpha
text=cdd6f4ff               ; {{fg}}
prompt=cba6f7ff             ; {{accent}}
placeholder=6c7086ff        ; {{muted}}
input=cdd6f4ff              ; {{fg}}
match=cba6f7ff              ; {{accent}}  (matched substring)
selection=cba6f7ff          ; {{accent}}  — the highlight bar
selection-text=1e1e2eff     ; {{bg}}      — text on the highlight
selection-match=1e1e2eff    ; {{bg}}
border=cba6f7ff             ; {{accent}}
counter=6c7086ff            ; {{muted}}

[border]
width=1
radius=14
```

### tofi — `~/.config/tofi/config`

Tofi colors here take a leading `#`. Centered box, single accent.

```ini
anchor = center
width = 640
height = 320
horizontal = false
font = "Inter"                 # {{font_ui}}; or a Nerd Font path
font-size = 14
num-results = 7

background-color = #1e1e2eee   # {{bg}} + alpha
outline-width = 0
border-width = 2
border-color = #cba6f7         # {{accent}}
corner-radius = 12
padding-top = 16
padding-bottom = 16
padding-left = 18
padding-right = 18

prompt-text = ">  "
prompt-color = #cba6f7         # {{accent}}
text-color = #cdd6f4           # {{fg}}
result-spacing = 6

selection-color = #cba6f7            # {{accent}} — the highlight (text)
selection-background = #31324480     # {{surface}} + soft alpha
```

## Pitfalls

- **wofi blur needs a Hyprland layer rule.** A translucent `#window` alone is just see-through, not frosted. On Hyprland 0.54 use the **block form** (the single-line `layerrule = blur, wofi` is rejected with `invalid field blur: missing a value`):
  ```
  layerrule {
      name = blur-wofi
      match:namespace = wofi
      blur = true
      ignore_alpha = 0.2
  }
  ```
  Add matching blocks per launcher. **The default layer-shell namespaces differ from the binary name**:
  - wofi → `wofi`
  - rofi → `rofi`
  - tofi → `tofi`
  - **fuzzel → `launcher`** (not `fuzzel` — see [`fuzzel.ini(5)` `namespace`](https://man.archlinux.org/man/fuzzel.ini.5.en), default `launcher`; confirmed by end-4/dots-hyprland `dots/.config/hypr/hyprland/rules.lua` which targets `namespace = "launcher"` for fuzzel blur)
  - walker → `walker`
  - anyrun → `anyrun`
  - vicinae → Qt window, not layer-shell (blur via window opacity rule, not layerrule)
  If you need fuzzel to advertise a different name (e.g. for `no_screen_share`), set `namespace=fuzzel` in `[main]` and match that. Global blur must be on: `decoration { blur { enabled = true } }`.
- **Use upstream rofi ≥ 2.0 — the rofi-wayland AUR fork is obsolete.** Rofi 2.0.0 (2025-09-01) merged lbonn's Wayland port into mainline; the Arch `extra/rofi` package now `Provides: rofi-wayland` and `Replaces: rofi-wayland`, and auto-selects the xcb or wayland backend at runtime. If you're on a stale rofi (< 2.0) it still runs through XWayland on Hyprland (no layer-shell, so blur/anchoring via layerrule won't apply) — `pacman -Syu rofi` to fix. Some X-only features (fine monitor selection, certain positioning) are still unavailable in Wayland mode.
- **fuzzel alpha is `RRGGBBAA`, not `RGB`/`#RGB`.** No leading `#`, and you **must** include the two alpha digits — `1e1e2e` is invalid; write `1e1e2eff` (opaque) or `1e1e2eee` (translucent).
- **Over-transparent text → unreadable.** Keep `text`/`selection-text` near full alpha (`…ff`). Only the *background* should be translucent; thin text at 60% over a blurred wallpaper disappears.
- **No padding → cramped.** Always set `horizontal-pad`/`vertical-pad` (fuzzel), `padding` (wofi/rofi), or `padding-*` (tofi). A launcher with zero padding looks broken even with perfect colors.
- **Missing icon theme.** `show-icons`/`allow-images` with no installed icon theme yields blank or generic squares. Install e.g. Papirus and name it exactly (`icon-theme` is case-sensitive in fuzzel).
- **rofi `element selected` doesn't take.** rofi splits selection by row state — also set `element selected normal.normal { … }` (and `urgent`/`active` variants if used) or the highlight won't apply to drun rows.

## Sources

- fuzzel.ini(5) — Arch manual: <https://man.archlinux.org/man/fuzzel.ini.5.en>
- rofi-theme(5) — Arch manual: <https://man.archlinux.org/man/rofi-theme.5.en>
- rofi-theme(5) markdown (upstream): <https://github.com/davatorium/rofi/blob/next/doc/rofi-theme.5.markdown>
- tofi config reference: <https://github.com/philj56/tofi/blob/master/doc/config>
- adi1090x/rofi (launchers/applets collection): <https://github.com/adi1090x/rofi>
- adi1090x type-1 launcher style: <https://github.com/adi1090x/rofi/blob/master/files/launchers/type-1/style-1.rasi>
- catppuccin/rofi: <https://github.com/catppuccin/rofi>
- catppuccin/fuzzel: <https://github.com/catppuccin/fuzzel>
- catppuccin/tofi: <https://github.com/catppuccin/tofi>
- alxndr13/wofi-catppuccin: <https://github.com/alxndr13/wofi-catppuccin>
- quantumfate/wofi (Catppuccin): <https://github.com/quantumfate/wofi>
- wofi(5) styling: <https://manpages.ubuntu.com/manpages/questing/man5/wofi.5.html>
- rofi-wayland fork (lbonn / in0ni): <https://github.com/in0ni/rofi-wayland>
- HyDE: <https://github.com/HyDE-Project/HyDE> · JaKooLit Hyprland-Dots: <https://github.com/JaKooLit/Hyprland-Dots> · ml4w dotfiles: <https://github.com/mylinuxforwork/dotfiles>
- Hyprland layer-rule blur for launchers: <https://github.com/hyprwm/Hyprland/issues/8408>

**Theme corpus read for the techniques catalog** (each theme file read directly):
- adi1090x/rofi — `files/launchers/type-1/style-1.rasi` (pill list), `type-3/style-3.rasi` (icon grid), `files/colors/*.rasi` (shared palette): <https://github.com/adi1090x/rofi>
- catppuccin/rofi — `catppuccin-default.rasi` layout + `themes/catppuccin-mocha.rasi` (26-name palette, `em` icon sizing): <https://github.com/catppuccin/rofi>
- lr-tech/rofi-themes-collection — `spotlight-*`, `rounded-template.rasi` + variants, `windows11-*`: <https://github.com/lr-tech/rofi-themes-collection>
- HyDE-Project/HyDE — `Configs/.config/rofi/theme.rasi` (generated palette) + `Configs/.local/share/hyde/rofi/themes/style_1.rasi` (wallpaper sidebar): <https://github.com/HyDE-Project/HyDE>
- JaKooLit/Hyprland-Dots — `config/rofi/themes/KooL_style-*.rasi` (`white/NN%` algebra, fullscreen `%`-icon grid): <https://github.com/JaKooLit/Hyprland-Dots>
- quantumfate/wofi (`src/mocha/style.css`, outline-ring selection) and alxndr13/wofi-catppuccin (`style.css`, zebra rows + focus glow): <https://github.com/quantumfate/wofi> · <https://github.com/alxndr13/wofi-catppuccin>
- catppuccin/fuzzel, catppuccin/tofi, philj56/tofi `themes/*` (fullscreen/dos two-ring), and real `fuzzel.ini`s from vaelixd/niri-dotfiles, caelestia-dots, chikobara/dotfiles (`include=` colors split, `layer=overlay`).
- end-4/dots-hyprland — `dots/.config/fuzzel/fuzzel.ini` (`include="…/fuzzel_theme.ini"` + `[border]` + `[dmenu] exit-immediately-if-empty=yes`), `dots/.config/matugen/templates/fuzzel/fuzzel_theme.ini` (matugen-driven `[colors]` block, 7 keys), `dots/.config/hypr/hyprland/rules.lua` (`namespace = "launcher"` for fuzzel blur — confirms fuzzel's default layer namespace).
- dusklinux/dusky — `.config/rofi/config.rasi` (verbose comments documenting the `sort + sorting-method:"fzf" + matching:"fuzzy"` frecency idiom, the `me-select-entry`/`me-accept-entry` single-click setup, and the `drun-match-fields` "drop categories" trick), `.config/matugen/templates/rofi-colors.rasi` (47-key M3 token dump).
- mylinuxforwork/dotfiles — `dotfiles/.config/rofi/config.rasi` (split `imagebox`/`listbox` with wallpaper-fill imagebox, M3 `@primary`/`@on-surface` references) + `dotfiles/.config/rofi/config-compact.rasi` (top-drop ML4W variant), `dotfiles/.config/matugen/templates/rofi-colors.rasi` (47-key M3 dump, same shape as dusky/binnewbs).
- binnewbs/arch-hyprland — `.config/rofi/config.rasi` (`@theme "/dev/null"` idiom to nullify rofi's default theme before `@import "colors.rasi"`), `.config/matugen/templates/rofi-colors.rasi` (47-key M3 dump).
- Matt-FTW/dotfiles — `.config/rofi/theme/catppuccin-macchiato.rasi` (rofi `linear-gradient()` as a value, used via `background-image: @selected;`), `.config/rofi/style.rasi` (modi `[ MousePrimary, MouseSecondary, MouseDPrimary ]` array for `me-accept-entry`).
- abenz1267/walker — `resources/config.toml` (upstream default; confirms `[shell]`/`[columns]`/`[placeholders]`/`[keybinds]`/`[providers]` sections plus 20+ flat keys including `ext_background_effect_blur` for `ext-background-effect-v1` compositor blur).
- prasanthrangan/hyprdots — `Configs/.config/hyde/wallbash/Wall-Dcol/rofi.dcol` (six-name semantic palette `main-bg`/`main-fg`/`main-br`/`main-ex`/`select-bg`/`select-fg`, `#<wallbash_pry1>E6` value syntax), `Configs/.config/hypr/windowrules.conf` (uses the pre-0.54 single-line `layerrule = blur,rofi` form — broken on current Hyprland; see `gotchas.md`).

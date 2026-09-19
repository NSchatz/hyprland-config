# launcher - common

Cross-tool content for the `launcher` surface: what holds no matter which tool was picked.
Read this **plus** the one `tools/<your-tool>.md` the interview selected.

## Contents

- Template
- Validation
- Gotchas
- Reload

---

## Template


Per-tool config + style recipes. The engine **always** writes a colors file the tool's style
`@import`s/`include`s — never hardcode hex in the style file. The canonical var names are
fixed by `_shared/colors-contract.md`; the rice templates in `skills/rice/references/components/launcher/{wofi,rofi,
fuzzel}.tmpl` render those names from `palette.conf`.

The deep styling catalog — selection idioms, blur, `em`/`%` sizing, layout variants — lives in
`styling.md`. This file is the minimum viable recipe per tool, sufficient for the engine.

## Hyprland variables emitted (by `keybinds` component)

```ini
$menu  = {{menu_invocation}}     # e.g. wofi --show drun
$dmenu = {{dmenu_invocation}}    # e.g. wofi --dmenu   — NEVER `$menu --dmenu`
```

Per-tool invocations:

| tool    | `$menu`                       | `$dmenu`                              |
|---|---|---|
| wofi    | `wofi --show drun`            | `wofi --dmenu`                        |
| rofi    | `rofi -show drun`             | `rofi -dmenu`                         |
| fuzzel  | `fuzzel`                      | `fuzzel --dmenu`                      |
| tofi    | `tofi-drun \| sh`             | `tofi`                                |
| walker  | `walker`                      | `walker --dmenu` (also `-d`)          |
| vicinae | `vicinae toggle`              | `vicinae dmenu` (subcommand, no `--`) |
| anyrun  | `anyrun`                      | `anyrun --plugins libstdin.so`        |

Notes on the less-obvious ones:
- **walker** needs its service running for the `walker` command to be instant
  (`walker --gapplication-service` in `companion-daemons`). `--dmenu` / `-d` are first-class
  flags (verified in walker ≥ 2.3).
- **vicinae** runs as a persistent daemon (`vicinae server --replace`, typically autostarted).
  Window control is via the IPC subcommands `vicinae open` / `close` / `toggle`. dmenu mode
  is invoked as a subcommand (`vicinae dmenu`), not a flag.
- **anyrun has no dedicated `--dmenu` flag** — its dmenu-style picker is the `libstdin.so`
  plugin, invoked via `anyrun --plugins libstdin.so` (which then reads stdin).

## Briefer recipes (engine themes only what the tool exposes)

## Colors contract

| File written by engine | Format | Var names |
|---|---|---|
| `~/.config/wofi/colors.css` | CSS `@define-color` | `bg fg surface accent` |
| `~/.config/rofi/colors.rasi` | rasi `* { name: #hex; }` | `bg bg-alt fg muted accent accent2 red green` |
| `~/.config/fuzzel/fuzzel.ini` `[colors]` | `key=RRGGBBAA` (no `#`) | `background text match selection selection-text selection-match border` |
| `~/.config/tofi/colors.tofi` (sourced) | leading-`#` hex | `background-color border-color prompt-color text-color selection-color selection-background` |
| `~/.config/walker/colors.css` | CSS `@define-color` | `bg fg surface accent` |
| `~/.config/anyrun/colors.css` | CSS `@define-color` | `bg fg surface accent` |

See `_shared/colors-contract.md` — these names ARE the contract.

---

## Styling


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
- **rofi `element selected` alone doesn't take on drun rows.** rofi splits selection by row state using the `{visible-modifier}.{state}` syntax (`rofi-theme(5)`: visible ∈ `normal|selected|alternate`, state ∈ `normal|urgent|active`). The community form is `element selected.normal { … }` (period, not space) — set all three of `selected.normal`/`selected.urgent`/`selected.active` or the highlight won't apply to drun rows that rofi has marked active/urgent.

## Provenance

Citations for this file live at `.research/sources/components-launcher-styling.md` (repo root), kept out of
the load path on purpose. Read them when reviewing a recommendation, not when
authoring a config.

---

## Validation


The validator runs once after the writer emits files but before reload. Launcher configs are
loose by nature (every tool parses lenient-INI / RASI / CSS) — the goal is to catch the
silent-fail cases, not lint style. Run the checks below; on any failure, emit a clear diagnostic
and stop the rice pipeline.

## CSS balanced-braces helper (shared across wofi/walker/anyrun style files)

```bash
# Returns 0 if balanced, nonzero otherwise.
balanced_braces() { awk 'BEGIN{d=0}{for(i=1;i<=length($0);i++){c=substr($0,i,1);
  if(c=="{")d++; else if(c=="}"){d--; if(d<0)exit 1}}} END{exit (d!=0)}' "$1"; }
```

## What's NOT validated

- Color **contrast** is not checked — fully unreadable text (text alpha at `00`, accent =
  background) is a styling bug, not a parse error.
- Icon-theme availability — if `Papirus` isn't installed, the launcher just shows blank icons.
  The validator could warn (`gtk-update-icon-cache -l` against installed themes), but it's not
  fatal.
- Whether the launcher's namespace matches a `layerrule` — that's the `window-rules`
  component's validation.

---

## Gotchas


## `$menu` and `$dmenu` are DIFFERENT invocations — never compose

`$menu` runs in **mode** form (drun / run / window-switcher); `$dmenu` runs as a stdin/stdout
pipe for ad-hoc pickers (clipboard, emoji, calculator). They are not the same command with a
flag — they are separate invocations defined as separate variables in `hyprland.conf`:

```ini
$menu  = rofi -show drun        # NOT "rofi -dmenu", NOT "wofi --dmenu"
$dmenu = rofi -dmenu            # NOT "$menu -dmenu"
```

Composing `$menu -dmenu` (e.g. a clipboard-history bind written as `cliphist list | $menu
-dmenu | …`) produces conflicting flags and the picker silently fails to open. Every utility
that pipes into a picker (`cliphist`, `wofi-emoji`, `qalc | $dmenu`, …) must call `$dmenu`,
not `$menu`. Full discussion in `../keybinds/gotchas.md` — the keybinds component owns the
`$menu`/`$dmenu` variables and the binds that consume them; this rule is stated once there,
this is the launcher-side cross-reference.

## Use repo `rofi` (≥ 2.0) — the `rofi-wayland` AUR fork is now obsolete

Historically `rofi` in the Arch repos was X-only and the AUR `rofi-wayland` (lbonn's fork)
was required for native layer-shell on Hyprland. **That changed with rofi 2.0.0 (released
2025-09-01)**: the lbonn Wayland port was merged into mainline, and the Arch `extra/rofi`
package now `Provides: rofi-wayland` and `Replaces: rofi-wayland`. Install **`rofi`** from
the official repo — it auto-selects xcb or wayland backend at runtime.

`packages.md` now points the `rofi` answer at the repo `rofi` package. If you still have
`rofi-wayland` from AUR installed, the repo rofi will pull it out via the `Replaces:`
metadata on next upgrade.

Symptoms of the *old* X-only rofi (pre-2.0, no longer applicable on a current Arch system):
no blur even with a correct `layerrule` block, off positioning on multi-monitor, some
monitor flags failing. If you see these on Hyprland today, you're probably on a stale
rofi — `pacman -Syu rofi` to get ≥ 2.0.

## Other tool quirks

- **wofi blur needs a `layerrule` block.** A translucent `#window` alone is just see-through.
  Hyprland 0.54+ requires the **block form** (`layerrule { name = blur-wofi; match:namespace =
  wofi; blur = true; ignore_alpha = 0.2 }`) — the single-line `layerrule = blur, wofi` is
  rejected with `invalid field blur: missing a value` (see `_shared/version-matrix.md`, 0.54
  cliff). The block lives in `../window-rules/template.md`. Global blur must be on too.
- **Several popular rices still ship the pre-0.54 single-line `layerrule = blur,rofi` form**
  (HyDE `Configs/.config/hypr/windowrules.conf` HEAD, as of this research pass). On Hyprland
  0.54+ that line is **rejected** at parse time and the whole reload fails. If a user copies a
  layerrule block from these rices and pastes into a recent Hyprland config they'll see
  `invalid field blur: missing a value` — point them at the block form or the modern
  single-line form `layerrule = blur on, match:namespace rofi`. This is the same 0.54 cliff
  documented in `_shared/version-matrix.md`, and the rice's `window-rules/template.md` already
  branches on version, but call it out specifically for launchers because community templates
  for them are particularly stale.
- **rofi `element selected` alone doesn't take on drun rows.** Rofi's state syntax is
  `{visible}.{state}` per `rofi-theme(5)` (visible ∈ `normal|selected|alternate`, state ∈
  `normal|urgent|active`). Set **all three** of `element selected.normal`,
  `element selected.urgent`, and `element selected.active` or the highlight won't apply to
  drun rows rofi has flagged active/urgent. The community form is dot-joined
  (`selected.normal`), not space-joined — HyDE, JaKooLit, ML4W, dusky, Matt-FTW, binnewbs all
  use this form. The recipe in `template.md` covers all three states.
- **fuzzel `width` is in characters, not pixels.** `width=32` is ~32 character columns wide,
  not 32px. Themes pulled from the internet often look weird because of this.
- **tofi has no app icons.** Text-only by design. `launcher.icons = true` against `tool =
  tofi` is silently coerced to `false` by the writer (see `schema.md`).
- **walker as a service.** Walker is fastest when its background service is autostarted —
  `companion-daemons` should include `walker --gapplication-service` when the launcher pick is
  walker. The picker bind then opens instantly.
- **walker compositor blur uses `ext-background-effect-v1`, not Hyprland `layerrule`.**
  Walker has its own opt-in flat key in `config.toml`: `ext_background_effect_blur = true`
  (verified against upstream `abenz1267/walker/resources/config.toml` HEAD). When the
  compositor implements the protocol (Hyprland does), walker requests blur behind its wrapper
  directly and you don't need a `layerrule = blur, walker` block. A `layerrule` for `walker`
  still works (its namespace IS `walker`), but the upstream-supported route is the flat key.
- **vicinae themes only what it exposes.** The engine writes a small theme block inside
  `~/.config/vicinae/settings.json` (JSONC — JSON with comments) for vicinae's internal
  colors; geometry/extension layout is largely fixed by the app. Don't promise full palette
  coherence on every surface. The daemon is `vicinae server --replace`; window control is
  `vicinae open|close|toggle`; dmenu mode is the `vicinae dmenu` subcommand, not a `--dmenu`
  flag.
- **anyrun plugins live in `~/.config/anyrun/`.** Selecting plugins is a separate step
  (`utilities`/`plugins` components); the launcher template just installs anyrun and writes the
  base `config.ron`. Anyrun has **no `--dmenu` flag** — the dmenu picker is the `libstdin.so`
  plugin (`anyrun --plugins libstdin.so`). All anyrun config keys are `snake_case`
  (`hide_icons`, `close_on_click`, `show_results_immediately`, …).
- **wofi config keys are underscore-only.** `allow_images`, `close_on_focus_loss`,
  `image_size`, `hide_scroll`, `gtk_dark`, `key_expand`. A hyphenated key (`allow-images`,
  `close-on-focus-loss`) is silently ignored and the option falls back to the default —
  every released wofi-styling guide that hyphenates is wrong, see `man 5 wofi`.
- **walker config has its own schema.** Top-level sections are `[shell]`, `[columns]`,
  `[placeholders]`, `[keybinds]`, `[providers]` plus flat keys (`theme`, `close_when_open`,
  `as_window`, `force_keyboard_focus`, …). It does **not** use `[search]`/`[ui]`/`[modules.*]`
  — anything written under those names is silently ignored. The picker dmenu flag is
  `walker --dmenu` (also `-d`).

---

## Reload


**Launchers are stateless.** They are launched fresh on every `$menu` / `$dmenu` invocation,
read their config from disk, render, and exit. There is no long-running launcher process to
signal, and no D-Bus reload endpoint. **Config changes apply on the next launch — no reload
needed.**

This is true for every launcher this component covers:

| Tool | Process model | When changes apply |
|---|---|---|
| wofi | Spawn → render → exit on selection/escape. | Next `wofi --show drun`. |
| rofi | Spawn → render → exit. | Next `rofi -show drun`. |
| fuzzel | Spawn → render → exit. | Next `fuzzel`. |
| tofi | Spawn → render → exit. | Next `tofi-drun \| sh`. |
| walker | Spawn picker OR pre-started service (`walker --gapplication-service`). | Next picker invocation; **see below** for the service case. |
| vicinae | Tray/service + popup. | Next popup — vicinae re-reads on each open. |
| anyrun | Spawn → render → exit. | Next `anyrun`. |

## Engine `render-manifest` rows

The render manifest's per-component reload column is `:` (no-op) for every launcher row, since
there's nothing to signal. The engine still **renders the colors file and the style file** every
time — the no-op only applies to the post-render hook.

```
wofi    wofi.tmpl     ~/.config/wofi/colors.css       :
rofi    rofi.tmpl     ~/.config/rofi/colors.rasi      :
fuzzel  fuzzel.tmpl   ~/.config/fuzzel/fuzzel.ini     :   # merged section, not replaced
```

(The actual manifest assembly lives in `theming/engine.md`; this file just documents that the
hook column is `:` for launchers.)

## The walker service exception

Walker has a service mode (`walker --gapplication-service`) for instant startup. The service
keeps a warm GTK process around and the picker invocation (`walker`) connects via a UNIX
socket. The service re-reads its config on each picker invocation, so even in service mode,
**no signal is needed** — changes apply on the next popup.

If walker's service is hung after a config edit (rare; usually a config parse error),
restart with:

```bash
systemctl --user restart walker.service     # if the user set up a user unit
# or, if autostarted by Hyprland:
pkill -x walker && walker --gapplication-service &
```

This is failure-recovery, not the normal flow — the validation pass in `validation.md` should
catch the parse error before reload runs.

## What this component does NOT reload

- The `$menu` / `$dmenu` variables in `hyprland.conf` change → `hyprctl reload` is needed, but
  that's the **hyprland** component's reload, not this one.
- The `layerrule` blur block in `window-rules` change → `hyprctl reload`, again not here.
- The colors file is written by the rice engine → the engine's renderer handles it; the
  launcher's no-op reload hook means we don't double-fire anything.

## Cross-references

- Render manifest line format → `theming/engine.md`.
- Hyprland reload semantics → `hyprctl reload` (Hyprland topic files share the standard reload
  mechanism, no per-component `reload.md`).


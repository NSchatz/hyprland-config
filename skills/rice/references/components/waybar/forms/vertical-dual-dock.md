# waybar forms - vertical, dual and dock

Read this **only** when `bar.form` is not a single horizontal bar. A standard top or
bottom bar needs none of it.

## Contents

- Bar form: orientation, vertical & multi-bar
- Vertical / dual / dock emission

---

## Bar form — orientation, vertical & multi-bar

Everything above is a *top horizontal* bar. Waybar also does **bottom**, **vertical** (a narrow left/right column), and **multiple bars at once** — these change layout, not just CSS. Pick the form first (it gates the archetype): horizontal islands don't translate to a 32px-wide column, and a dual-bar splits modules across two `config` objects.

**Vertical bar** (`position: "left"` or `"right"`; the niri/ultrawide favorite — saatvik333, Sudhboi, gdots, Pipshag_kitties, EviLuci). Set a **`width`** instead of height (≈ `32`–`44`), and rethink every wide module:
- **Read direction.** Two strategies: go **icon-only** (saatvik333 — drop text labels, size glyphs with Pango `<span size='14pt'>`), or **`rotate` text modules** so labels read down the column — `"rotate": 90` (or `270`) on `clock`, `network`, `mpris`, `cpu` (Sudhboi, gdots, Pipshag_kitties). `rotate` is a **module-config** key, not CSS.
- **Stacked formats.** Replace one-line formats with newlines: `"format": "{:%H\n%M}"` for the clock, `"{capacity}\n{icon}"` for battery — no rotation needed.
- **Vertical sliders.** `pulseaudio/slider` / `backlight/slider` with `"orientation": "vertical"`; style `trough { min-width: 8px; min-height: 70px; border-radius: 8px; }`, `highlight { background: @accent; }`, hide the knob `slider { opacity: 0; }`. Usually revealed inside a `group/drawer` (`"orientation": "inherit"` so the drawer flows vertically too).
- **Edge-hugging shape.** Round only the inward corners — left bar `border-radius: 0 6px 6px 0`, right bar `6px 0 0 6px` (Sudhboi). A left-edge **`box-shadow: inset 2px 0 @accent`** "color spine" replaces the horizontal underline as the active marker.
- Workspaces become a vertical stack of dots/numbers; `min-height` (not `min-width`) gives them size.

**Dual bar — top + bottom** (Bwc9876, EviLuci-old, kamlendras, qoheniac). `config.jsonc` becomes a **JSON array of bar objects**, each with a `"name"`. The consistent split: **top = chrome** (clock, tray, system stats, notifications, privacy, media) · **bottom = workspaces + `wlr/taskbar` + sensors**.
```jsonc
[
  { "name": "top",    "position": "top",    "mode": "dock", "exclusive": true,
    "modules-center": ["clock"], "modules-right": ["tray", "network", "pulseaudio", "battery"] },
  { "name": "bottom", "position": "bottom", "mode": "dock", "exclusive": true,
    "modules-left": ["hyprland/workspaces"], "modules-center": ["wlr/taskbar"],
    "modules-right": ["cpu", "memory", "temperature"] }
]
```
Target a single bar from one stylesheet via its name: `window#waybar.top { … }`, `.bottom#workspaces { … }` (Lynndroid21 also toggles extra bars with `"start_hidden": true` + `"on-sigusr1": "toggle"`).

**Dock / shelf & OS-mimic recipes.**
- **ChromeOS shelf** (cxOrz): `{"position":"bottom","height":48}`, `window#waybar { border-radius: 24px 24px 0 0; background: alpha(@bg,0.80); }`. Group clock+audio+net+bt+battery into one "status pill" by rounding only the first (`18px 0 0 18px`) and last (`0 18px 18px 0`) member. Active workspace morphs a `min-width:20px;border-radius:4px` bar into a `min-width:8px;border-radius:50%;background:@accent` dot (label `font-size: 0`).
- **macOS Sequoia** (kamlendras): the look is ~80% **frosted-white translucency + compositor blur**, not heavy CSS. `window#waybar { background: rgba(255,255,255,0.5); color: #000; }` + the `layerrule … blur = true` block. A slim top **menu bar** (`height:24`) whose left side is `custom/launcher` 🔍 (Spotlight → wofi `drun`) followed by plain-text `custom/text*` modules printing **"File" "Edit" "View" "Help"** (`"exec":"echo File"`, each with an on-click app), and `hyprland/window` rewriting an empty class → **"Finder"**. A bottom bar is the **Dock**: `wlr/taskbar` `icon-size:36`. Workspace = neutral-gray tab `border-bottom: 3px solid white` on `.focused`; Apple easing `transition: all .25s cubic-bezier(0.165,0.84,0.44,1)`; color reserved for alerts only.
- **Windows 10 taskbar** (TheFrankyDoll): `{"position":"bottom","mode":"dock","height":41}`, square corners, `wlr/taskbar` with window title+icon (`min-width:130px`) and an underline-active (`border-bottom:3px solid white`, urgent = `dashed`), a Windows-logo `custom/os_button` launcher, and the **reveal-on-critical** trick (`#temperature{font-size:0;color:transparent}` → `.critical{font-size:initial}`).

---

## Vertical / dual / dock — the other forms

These restructure `config.jsonc` enough that they get their own recipe blocks in `styling.md`:

- **Vertical** — `"position": "left"`, `width` ≈ 32–44, `rotate: 90/270`, two-line clock formats,
  vertical sliders in drawers, edge-hugging asymmetric `border-radius`.
- **Dual** — `config.jsonc` is a JSON **array** of two named bar objects (`top`/`bottom`); CSS
  targets each via `window#waybar.top { ... }` / `.bottom#workspaces { ... }`.
- **Dock / ChromeOS-shelf / macOS / Win10** — `position: bottom`, `wlr/taskbar` as the actual dock,
  `border-radius: 24px 24px 0 0`, status-pill grouping via first/last-child rounding.

For each form, read `styling.md` → *Bar form* and adapt the relevant section above.


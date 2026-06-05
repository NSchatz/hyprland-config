# default-apps — template

This component doesn't own its own `.conf` file. Its outputs are two `$var` lines that the
**hyprland** component's `hyprland.conf` template injects into the variables block. Keep them
together with `$terminal`/`$menu`/`$dmenu` so a user reading the top of `hyprland.conf` sees every
app variable in one place.

## Lines emitted into `hyprland.conf`

```ini
$browser     = {{browser}}
{{#if files}}$fileManager = {{files}}{{/if}}
```

- `{{browser}}` ← `default_apps.browser` from `answers.json`.
- `{{files}}` ← `default_apps.files` from `answers.json`; **omit the line entirely** when null.

The fully-stitched variables block in `hyprland.conf` (with all components feeding it) is in
`components/keybinds/template.md` — that component owns `hyprland.conf` because the bulk of the
file is its workload (the bind table).

## Lines emitted into `binds.conf` (cross-reference)

Owned by the `keybinds` component, but listed here so it's clear where default-apps land:

```ini
bind = $mainMod, B, exec, $browser
{{#if files}}bind = $mainMod, E, exec, $fileManager{{/if}}
```

## Lines emitted into `env.conf` (cross-reference)

When `browser == "firefox"`, the `env` component adds:

```ini
env = MOZ_ENABLE_WAYLAND,1
```

This is a **no-op on Firefox 121+** (Wayland default since Dec 2023). Kept as a documentation
marker / safety net for older Firefox builds; do **not** describe it as "required for Wayland
Firefox" in any user-facing copy. Setting it to `0` (not done here) would force XWayland. See
[`../env/gotchas.md`](../env/gotchas.md) → "MOZ_ENABLE_WAYLAND".

When `browser` is `chromium` / `brave` (or any Electron app is in scope), the `env` component's
`env = ELECTRON_OZONE_PLATFORM_HINT,auto` line is what enables native Wayland — no per-browser
flag in `$browser`.

## What does NOT belong here

- The terminal emulator. That's `components/terminal/` (themed, gets a colors file).
- The launcher invocation (`$menu` / `$dmenu`). That's `components/launcher/`.

## Variable-name choice (vs the corpus)

We emit **`$browser`** and **`$fileManager`** — same names as the upstream Hyprland wiki's
"Sensible defaults" snippet. The corpus is split:

- `$fileManager` — caelestia (calls it `$fileExplorer`), dusky, binnewbs.
- `$file` — HyDE (`Configs/.config/hypr/keybindings.conf`).
- `$files` — JaKooLit, Matt-FTW (as `$file-manager`), linuxmobile.

Stick with `$browser` + `$fileManager`. They're the wiki-canonical names and match the
`bind = $mainMod, E, exec, $fileManager` example most users will paste in from search results.
Do not rename to `$file` to save four characters — the rename breaks copy-paste against the wiki.

## Theming linkage (what re-themes when this component changes)

The default-app picks are mostly **structural** — they don't drive a `.tmpl` in this folder.
But the **picks determine which other component templates need to be rendered**:

| If `default_apps.files ==` | Then re-theming relies on | Owned by |
|---|---|---|
| `thunar` / `nautilus` / `nemo` / `pcmanfm` | GTK3 + GTK4 matugen output (`gtk-3.0` / `gtk-4.0`) | `theming/gtk-qt.md`, engine |
| `dolphin` | Kvantum theme (`QT_STYLE_OVERRIDE=kvantum` + `kvantum.kvconfig`) | `theming/gtk-qt.md` |
| `yazi` (TUI, recorded as `null` here) | `~/.config/yazi/theme.toml` — currently not generated | flag (see `gotchas.md`) |

| If `default_apps.browser ==` | Then re-theming relies on | Owned by |
|---|---|---|
| `firefox` | Firefox is **not** auto-themed. Chrome stays default. (To match: userChrome / pywalfox add-on layer — out of scope for v0.13.) | (none) |
| `chromium` / `brave` / `zen-browser` | Same — chrome stays default unless a userChrome.css is generated separately. Dank and noctalia ship matugen browser templates; we do not. | (none) |

If you pick a Qt6 file manager (Dolphin) but skip Kvantum, the file manager renders Breeze
regardless of palette — flag this in the interview when the user picks Dolphin (see
`gotchas.md`).

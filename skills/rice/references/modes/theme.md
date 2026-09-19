# Modes B, C and D - theme, profiles, wallpaper

Three requests, one engine. B resolves a palette and renders it everywhere; C snapshots
and switches named palettes; D sets the wallpaper and optionally regenerates the palette
from it. All three rewrite `palette.conf` and end in `rice apply`.

## Contents

- Mode B - theme every surface from one palette
- Mode C - named profiles & the override cascade
- Mode D - wallpaper (+ dynamic theming)

---

## Mode B — Theme every surface from one palette

Apply one coherent palette across the whole desktop: **one normalized palette → render per-app color
files → reload each app** (see `../theming/theming-architecture.md`, and the per-app contracts
in `../_shared/colors-contract.md`). Use only current syntax (defer to hyprland-reference).
For *how* each surface should look — where the accent goes, contrast, transparency, the archetypes —
read each visual component's `styling.md` plus `hyprland-reference/references/styling/design-principles.md`.

### B1. Choose the palette source & fonts (always ask)

Run the `look-feel` component's interview inline (`../components/look-feel/interview.md`
— palette source → scheme/wallpaper/manual, accent, light/dark; UI font; monospace/Nerd font; plus
the wallpaper sub-questions). One component is light enough to run inline, but **still record each
answer** via `record-answer.sh` into `~/.config/hypr-rice/answers.json` — that way a later A-mode
build (or a profile save) can replay exactly what was chosen. The named-scheme catalog is
`../theming/palettes.md`; for the wallpaper source, `scripts/palette-from-wallpaper.sh`
produces the palette when matugen/wallust is present. Resolve every answer into the **palette
contract** (`../_shared/palette-schema.md`) as bare `RRGGBB`. Don't pick a scheme or fonts
silently — present them.

### B2. Choose surfaces (default: all installed)

Default to every surface whose app is installed/running: Hyprland + hyprlock, waybar, mako/dunst/swaync,
wofi/rofi, kitty/terminal, GTK (3+4), Qt, cursor/icons/fonts. Skip (and note) absent apps.

### B3. Prefer the engine (reproducible)

For a real rice, drive the **engine** rather than writing each file ad hoc — it makes the theme
reproducible, re-applyable, and version-controllable (see `../theming/engine.md`):

1. `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/rice-init.sh"` (scaffold/refresh, idempotent).
2. Resolve the palette and write `~/.config/hypr-rice/palette.conf` (the source of truth).
3. Ensure each app reads its colors file (one-time wiring: `source=`/`@import`/`include`).
4. Back up first: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" <paths being changed>`.
5. `bash ~/.config/hypr-rice/rice apply` (renders every template + reloads running apps). Apply fonts
   across `gsettings` (`font-name`/`monospace-font-name`), GTK `settings.ini`, kitty `font_family`,
   waybar `font-family` per `../theming/fonts.md`. For the cursor, also `hyprctl setcursor <Cursor> <size>`.

**GTK theming has four engine-breaking gotchas** — (1) a session `GTK_THEME=` (default under uwsm —
`~/.config/uwsm/env`) that silently defeats the re-theme until the env is fixed and live-propagated;
(2) "folder color is the icon theme, not the GTK theme" (set a scheme-matched `icon-theme` too); (3) a
root-owned `gtk-4.0/gtk.css` symlink that render hits as *Permission denied* (now handled by
`render-templates.sh`); and (4) **`gsettings` alone does NOT theme GTK3 apps** (nm-connection-editor,
etc.) on Wayland — they fall back to the default *light* theme unless you also write
`~/.config/gtk-3.0/settings.ini` **and** `~/.config/gtk-4.0/settings.ini` (`gtk-theme-name=Adwaita-dark`,
`gtk-application-prefer-dark-theme=1`, `gtk-icon-theme-name`, `gtk-font-name`, `gtk-cursor-theme-name/size`)
plus `~/.gtkrc-2.0` for GTK2. (libadwaita follows `color-scheme=prefer-dark` via the portal but still
wants the settings.ini; changes apply only to newly-launched apps.) Full detail, the propagation
commands, and the murrine-needs-`sassc` build note live in **`../theming/gtk-qt.md`**.

For one-off, non-engine theming, each visual component's `template.md` plus the per-app color
contracts in `../_shared/colors-contract.md` and `scripts/apply-theme.sh` (reloads running
apps + cursor) remain valid.

### B4. Verify & report

Confirm the Hyprland color file still parses:
`bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/verify-config.sh"`. `VERIFY=ok` → done; `VERIFY=errors`
→ restore the Hyprland files from the backup, reload, report. Summarize source/scheme, surfaces
themed, files written, backups, reload/verify results, and any package to install for more.

---

## Mode C — Named profiles & the override cascade

A **profile** is a snapshot of `palette.conf` (palette + scheme + wallpaper + fonts) at
`~/.config/hypr-rice/profiles/<name>.conf`. Fourteen presets ship: `catppuccin-mocha`,
`catppuccin-frappe`, `catppuccin-macchiato`, `catppuccin-latte` (light), `gruvbox`, `nord`,
`tokyo-night`, `rose-pine`, `dracula`, `everforest`, `kanagawa`, `solarized-dark`,
`high-contrast-dark` (WCAG-AAA), `high-contrast-light` (WCAG-AAA).

1. Ensure the engine exists: `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/rice-init.sh"` (also
   installs the presets without clobbering customized ones).
2. Act via the `rice` CLI:
   - **List:** `bash ~/.config/hypr-rice/rice themes`
   - **Switch/apply:** `bash ~/.config/hypr-rice/rice theme <name>` (loads that palette + its recorded
     wallpaper, renders every template, reloads apps).
   - **Save current:** `bash ~/.config/hypr-rice/rice save <name>`.
   - **Re-apply current:** `bash ~/.config/hypr-rice/rice apply`.
   Back up `palette.conf` before a switch if the current state isn't saved
   (`bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" ~/.config/hypr-rice/palette.conf`).
3. **User-override layer** (pins that survive every theme/wallpaper change): write `KEY=hex` lines into
   `~/.config/hypr-rice/palette.user.conf` — the render overlays it *after* the profile/generated
   palette (`generated/profile → user`), then `rice apply`. Switching a profile does **not** clear it
   (overrides are intentionally persistent; remove a line + `rice apply` to drop one).
4. Verify (`verify-config.sh`) and report: profile applied, wallpaper, apps reloaded, active overrides.

Profiles version-control well — committing `~/.config/hypr-rice/` (see the **dotfiles** skill)
captures every saved rice and the current state.

---

## Mode D — Wallpaper (+ dynamic theming)

Set the wallpaper and optionally re-theme the whole desktop from it — the canonical rice front door
("change wallpaper, the desktop follows"). Read `../theming/wallpaper.md`.

1. Ensure the engine exists: `bash "${CLAUDE_PLUGIN_ROOT}/skills/rice/scripts/rice-init.sh"`.
2. Resolve the image. If the user has a file, use it (common dir `~/Pictures/wallpapers`). If they
   don't — or want one that suits their scheme — offer the **curated theme catalog**:
   `bash ~/.config/hypr-rice/rice wallpapers [scheme]` lists matching downloadable wallpapers (the
   chosen scheme's set + a few theme-agnostic `any` ones); present them with `AskUserQuestion`, then
   `bash ~/.config/hypr-rice/rice get-wallpaper <scheme> <number|name> --set` curl-downloads the pick
   to `~/Pictures/wallpapers/` and applies it (keeping the current palette — no re-theme). Then:
   - **Wallpaper only:** `bash ~/.config/hypr-rice/rice wallpaper '<image>' --no-theme`
   - **Wallpaper + dynamic theme:** `bash ~/.config/hypr-rice/rice wallpaper '<image>'` — sets it,
     regenerates `palette.conf` from it (matugen/wallust/pywal), renders every template, reloads apps.
   Back up first if overwriting: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-path.sh" ~/.config/hypr/hyprpaper.conf ~/.config/hypr-rice/palette.conf`.
   If no generator is installed you can still set the wallpaper; for dynamic theming fall back to a
   named/manual palette and suggest `matugen` (recommended) or `wallust`. matugen's Material-You →
   ANSI `color0..15` mapping is approximate; wallust/pywal give a true 16-color scheme.
3. **Cycling (optional):** `rice random [dir]` (random pick + re-theme). To automate without Claude,
   set up a **systemd user timer** or a Hyprland `exec-once` loop — see `../theming/wallpaper.md`; tell the user
   the cadence and how to stop it. Set the transition look once via `SWWW_TRANSITION_TYPE`/`_FPS` env.
4. Verify (`verify-config.sh`) and report: wallpaper + backend, whether/how the palette regenerated,
   apps reloaded, backups, any package to install. The wallpaper path is recorded in `palette.conf`,
   so profiles/version-control reproduce it.

---

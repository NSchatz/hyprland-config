# The Rice Engine

A self-contained theming engine the plugin scaffolds into `~/.config/hypr-rice/`. One palette is
the source of truth; templates render it into every app's config; one command re-applies and
reloads. It keeps working **without** the plugin (the `rice` CLI), so it can be version-controlled
and automated. This is the matugen/wallust/HyDE model, owned by the user.

## Where this lives in the new tree

The engine's contracts and per-surface wiring are split across several places — this file is the
architecture; the slices live elsewhere:

- **Palette schema** (the `KEY=hex` set in `palette.conf`, metadata keys, render flow) →
  [`_shared/palette-schema.md`](../_shared/palette-schema.md).
- **Per-app colors contract** (which variable names each component's colors file exports) →
  [`_shared/colors-contract.md`](../_shared/colors-contract.md).
- **Widget-shell theming** (eww, AGS/Astal, Quickshell, HyprPanel) →
  [`components/widgets/template.md`](../components/widgets/template.md) + `widgets/styling.md`.
- **Shell & prompt theming** (fish colors, starship, oh-my-posh) →
  [`components/shell-prompt/template.md`](../components/shell-prompt/template.md) +
  `shell-prompt/styling.md`.
- **Per-surface reload mechanics, GTK gotchas, cursor, Qt** →
  [`theming-architecture.md`](theming-architecture.md).
- **Palette catalog** (the 12 named schemes) → [`palettes.md`](palettes.md).
- **Fonts** → [`fonts.md`](fonts.md).
- **Wallpaper backends + dynamic theming** → [`wallpaper.md`](wallpaper.md).
- **Long-tail apps via matugen** → [`apps.md`](apps.md).

## Layout (`~/.config/hypr-rice/`)

```
palette.conf       # source of truth: KEY=hex (+ scheme, wallpaper, fonts). Also the rice "state".
templates/         # <app>.tmpl files using {{key}} placeholders (user-editable)
templates.list     # manifest: name <TAB> template <TAB> output <TAB> reload-cmd
render-templates.sh# the render engine (palette.conf -> outputs -> reload)
rice               # the CLI: `rice apply`, `rice palette`, …
profiles/          # saved theme profiles (rice skill)
wallpapers.tsv     # curated theme-tagged wallpaper catalog (copied from the plugin)
```

Scaffold/refresh it with `scripts/rice-init.sh` (idempotent — never clobbers `palette.conf`,
`templates.list`, or user-edited templates unless `--force`).

The palette-key list itself (which keys are required, hex format, metadata fields, sizing rules)
lives in [`_shared/palette-schema.md`](../_shared/palette-schema.md). This file does not restate
it.

## Render flow

`rice apply` → `render-templates.sh`:

1. Loads `palette.conf` into shell variables (`bg=...`, `accent=...`, `font_ui=...`, …).
2. For each manifest line: substitute `{{key}}` in the template → write the output file.
3. Run the app's reload hook (guarded — a no-op if the app isn't running).

Re-theming = rewrite `palette.conf` and `rice apply`. Adding an app = drop a `<name>.tmpl` in
`templates/` and add a TAB-separated manifest line; no code changes.

## Manifest format (`templates.list`)

TAB-separated, four fields per line. Empty `reload-cmd` is valid (the app picks colors up on
launch, or hot-reloads on file save).

```
name<TAB>template-path<TAB>output-path<TAB>reload-cmd
```

Example (real tabs between fields):

```
hyprland   ~/.config/hypr-rice/templates/hyprland.tmpl   ~/.config/hypr/colors.conf      hyprctl reload
kitty      ~/.config/hypr-rice/templates/kitty.tmpl      ~/.config/kitty/colors.conf     kill -SIGUSR1 $(pidof kitty)
waybar     ~/.config/hypr-rice/templates/waybar.tmpl     ~/.config/waybar/colors.css     killall -SIGUSR2 waybar
```

Reload commands are always guarded — `render-templates.sh` checks `pidof`/`pgrep` (or uses `|| true`)
so the line is a no-op when the app isn't running. The per-app reload command catalog is in
[`theming-architecture.md`](theming-architecture.md) → "Apply + reload".

## Wiring each app (one-time)

The render writes a **separate colors file**; wire the app to read it once and the wiring survives
every re-theme:

| App | One-time wiring |
|---|---|
| Hyprland | `source = ~/.config/hypr/colors.conf` in `hyprland.conf` |
| kitty | `include colors.conf` in `kitty.conf` |
| waybar | `@import "colors.css";` at the top of `style.css` |
| wofi | `@import "colors.css";` in `style.css` |
| rofi | `@import "colors.rasi"` from the theme |
| gtk4 | the output **is** `~/.config/gtk-4.0/gtk.css` |

Apps without an include mechanism (mako, dunst) are not in the default manifest — their config is
written whole (by rice generate or `edit-config`), which folds the colors in. Templates for them
ship in `templates/` for manual use.

For the widget-shell wiring (eww `@import`, AGS `@use`, Quickshell `Colors.qml` singleton) see
[`components/widgets/template.md`](../components/widgets/template.md). For prompt wiring
(`STARSHIP_CONFIG`, `oh-my-posh init`, fish `conf.d/`) see
[`components/shell-prompt/template.md`](../components/shell-prompt/template.md). The four GTK
gotchas around `gtk-4.0/gtk.css` (symlink, `--libadwaita`, `GTK_THEME` env, `settings.ini` vs
gsettings) are in [`theming-architecture.md`](theming-architecture.md) → "GTK gotchas".

### Surfaces whose reload is `hyprctl reload`, not file-watch

Three engine-rendered surfaces are read by Hyprland itself (not by an external daemon), so a
re-render only takes effect after `hyprctl reload`:

- `~/.config/hypr/colors.conf` — the palette `source`d from `hyprland.conf`.
- `~/.config/hypr/env.conf` — `env =` and **`envd =`** lines. The env component now emits
  `envd = XDG_CURRENT_DESKTOP,Hyprland` (D-Bus push variant) instead of `env =`; see
  [`components/env/template.md`](../components/env/template.md). The `envd` distinction matters
  only for legacy `.conf` configs — on Hyprland 0.55+ Lua, `hl.env()` does the systemd/D-Bus
  push automatically unless `HYPRLAND_NO_SD_VARS=1` — but in either case the **var doesn't
  appear in the session until Hyprland re-parses the file**. Changing the rendered palette can
  affect `env.conf` only when the engine writes derived env (currently it doesn't); changing
  anything that re-emits `env.conf` (a fonts pick that gates `GDK_SCALE`, a cursor-theme swap
  that updates `XCURSOR_THEME`/`HYPRCURSOR_THEME`) requires the `hyprctl reload`. A re-rendered
  `env.conf` without a reload is a silent "the change didn't take" bug — render-templates.sh's
  reload-cmd for any env-emitting template must be `hyprctl reload`.
- `~/.config/hypr/autostart.conf` — `exec-once` lines. `hyprctl reload` re-parses the file but
  **does NOT re-execute** existing `exec-once` directives (see `components/autostart/gotchas.md`);
  only newly-added lines fire, and only at the next session start. The engine's restore-script
  hook below works around this by writing a self-contained script invoked from `exec-once` —
  changes to the script body take effect on the next login, not on the next `rice apply`.

## Palette sources → `palette.conf`

- **Named / manual** — the rice skill writes `palette.conf` directly from
  [`palettes.md`](palettes.md) (or user hex).
- **Wallpaper-generated (matugen / wallust)** — use the generator to *produce* the palette; the
  engine renders everything else. See [`wallpaper.md`](wallpaper.md) → "Dynamic theming" for the
  matugen MD3 → contract map (`primary→accent`, `surface→bg`, …) and the wallust 16-color map.

The wallpaper path goes into `palette.conf` as `wallpaper=…`.

## Theme-restore on login (engine-generated script)

When `theming.engine` is `matugen` / `wallust` / `wallbash`, the rice engine **generates a
self-contained restore script** at `~/.config/hypr/scripts/restore-theme.sh` on every `rice
apply`/wallpaper-pick. The autostart component schedules it via a single `exec-once` line — see
[`components/autostart/template.md`](../components/autostart/template.md) → "Theme-restore on
login". This file documents the **script body** the engine writes; autostart only writes the
`exec-once = ~/.config/hypr/scripts/restore-theme.sh` invocation.

Why a generated script (not an inline `exec-once`): the line must encode the *current* wallpaper
path **and** the engine-specific re-apply command, both of which change on every theme swap.
Writing a one-line script that the autostart entry calls means autostart never needs to be
re-rendered — only the script body changes.

### Script body per engine

The body is small and dispatches on `theming.engine`. The wallpaper-daemon detection mirrors
`autostart`'s `SWWW_DAEMON_BIN` (so `awww`-on-Codeberg is handled).

| `theming.engine` | Script body (`~/.config/hypr/scripts/restore-theme.sh`) |
|---|---|
| `matugen` | `swww img "$wp" && matugen --prefer image image "$wp"` — re-paint, then regenerate every template via the matugen post-hook chain. `--prefer image` is required when matugen runs headless (no portal); see `wallpaper.md` → "matugen `--prefer` for headless multi-source". |
| `wallust` | `swww img "$wp" && wallust run -s "$wp"` — `-s` skips setting the wallpaper (already set by `swww img`); wallust's `[templates.*]` entries fire the per-app `post_hook` reloads. |
| `wallbash` (HyDE) | `swww img "$wp" && ~/.local/share/bin/swwwallpaper.sh -s "$wp"` — HyDE's `swwwallpaper.sh` is the wallbash regenerator (despite the name, it covers the wallbash-template path). On a non-HyDE wallbash install, point at the user's regenerator. |
| `none` | **No script generated.** `has_restore_script = false` upstream; no `exec-once` is emitted. |

Where `$wp` is the wallpaper path read from `~/.config/hypr-rice/palette.conf` (the
`wallpaper=…` line — `state` itself) at script-run time. The script reads it dynamically so a
re-rendered script (after the user picks a different wallpaper) doesn't go stale until the next
login.

### Canonical script body

The engine writes a guarded script:

```sh
#!/usr/bin/env bash
# Generated by hypr-rice. Re-applies the wallpaper and re-runs the theming engine
# on login so the desktop comes up matching the last rice state, not a stale palette.
set -e
wp=$(awk -F= '$1=="wallpaper"{print $2}' "$HOME/.config/hypr-rice/palette.conf")
[ -n "$wp" ] && [ -f "$wp" ] || exit 0          # no wallpaper persisted yet — first login
swww_bin=$(command -v awww-daemon >/dev/null && echo awww || echo swww)
# wait up to ~2s for the wallpaper daemon (started by the line above in autostart.conf)
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -x "${swww_bin}-daemon" >/dev/null && break
  sleep 0.2
done
"$swww_bin" img "$wp" || true
# Engine-specific re-apply — exactly one of the following branches is emitted at generate time:
{{engine_reapply_cmd}}    # matugen / wallust / swwwallpaper.sh (see table above)
```

Make it executable on write (`chmod 0755`). The `pgrep` loop is necessary because the autostart
line orders `exec-once = swww-daemon` immediately before `exec-once = ~/.config/hypr/scripts/restore-theme.sh`,
but `swww img` against a not-yet-listening daemon errors out — see `wallpaper.md` → "Cycling"
and `autostart/gotchas.md` for the corpus citations.

### Corpus citations

- **end-4/dots-hyprland** `dots/.config/hypr/custom/scripts/__restore_video_wallpaper.sh` is
  generated on every wallpaper switch by `switchwall.sh`; the body is a short `mpvpaper`/`swww
  img` re-applier scheduled from `exec-once`.
- **ML4W** `dotfiles/.config/ml4w/scripts/ml4w-autostart` reads `~/.config/ml4w/cache/current_wallpaper`
  and re-applies via `awww img` (ML4W has switched to `awww`) — same pattern, different
  daemon and cache path.
- **HyDE** `Configs/.config/hypr/hyprland.conf` ships `exec-once = $scrPath/swwwallpaper.sh`;
  `swwwallpaper.sh` re-runs the wallbash regen and `swww img` in one shot. The "single script
  that re-applies on login" pattern is universal across the corpus — only the engine differs.

### Why the engine owns the body, not autostart

The autostart component is engine-agnostic — it doesn't know whether the rice uses matugen,
wallust, or wallbash; it just emits the `exec-once` gate. The script body is engine-specific
(matugen needs `--prefer image`, wallust needs `-s`, wallbash needs the HyDE regenerator) and
must be rewritten on every `rice apply` (the wallpaper path may have changed). That places
authoring squarely with the engine — `render-templates.sh` writes the script as part of `rice
apply`, alongside the per-component template renders.

## Cross-engine version cliff: walker blur via `ext-background-effect-v1`

The engine does **not** render walker's `config.toml`, but a re-theme that toggles a launcher's
blur is engine-adjacent: walker's `ext_background_effect_blur = true` opt-in asks the compositor
to draw blur behind walker's surface via the **`ext-background-effect-v1`** Wayland protocol
(see `components/companion-daemons/gotchas.md` and `components/launcher/gotchas.md`). Hyprland
implemented the server side in
[`hyprwm/Hyprland@7d1e481`](https://github.com/hyprwm/Hyprland/commit/7d1e481) (**May 2026 / ~v0.50+**;
"protocols: implement ext-background-effect-v1 protocol"). On older Hyprland the flag silently
no-ops and the only path to a blurred walker is a `layerrule = blur, walker` block (rendered by
the `look-feel` component).

This is the boundary for **engine-controlled launcher blur** vs **rule-controlled launcher
blur**. If the rice's `theming.engine` decision exposes a "blur the launcher" knob, the engine
must check the Hyprland version and either: (a) toggle the launcher's own flag (≥0.50) or (b)
emit a `layerrule = blur, <namespace>` line for the `look-feel` template to fold in (<0.50). It's
the only theming-side decision that depends on a compositor protocol cliff. Detection lives in
`scripts/detect-version.sh`; consumers branch on `HYPR_HAS_EXT_BG_EFFECT_V1` rather than parsing
the version string.

## State & reproducibility

`palette.conf` records the current `scheme`, `wallpaper`, and fonts — it *is* the rice state.
Saving a profile snapshots it; version-controlling `~/.config/hypr-rice/` (and the rendered app
configs) in git makes the whole rice reproducible. See the dotfiles skill.

### Profiles are palette-only — structural look stays in the live config

`rice save <name>` snapshots **only** `palette.conf`. It does **not** capture structural look:
`~/.config/hypr/looknfeel.conf` (gaps, borders, decoration radius, animation curves),
`~/.config/waybar/style.css` (archetype CSS), `~/.config/hypr/hyprlock.conf` non-color blocks
(layout, font_size), `~/.config/eww/eww.scss` selectors. Those files are owned by their
components, not the engine, and they don't change on a re-theme.

The consequence: `rice theme dracula` swaps the palette + wallpaper but does **not** restore the
floating-pill archetype if you switched to edge-to-edge in between. If you want full snapshots
of structural look, the dotfiles skill is the right tool — it version-controls the whole config
tree and `git stash` / `git checkout` give you the same effect across both palette and structure.

Two reasons the engine stops at the palette boundary:

1. Structural files are component-owned. A profile that overwrote `waybar/style.css` would race
   with the waybar component-writer on the next interview re-run.
2. Most users adjust structure once and palette-cycle daily. Snapshotting structure on every
   `rice save` would expand profile size 20× for no daily-flow benefit.

`rice save --full` is not on the roadmap for v0.20.0; revisit if a real user reports the need.

## CLI

```
rice apply              # render all + reload
rice apply --no-reload  # render only
rice palette            # show current palette
rice templates          # show the manifest
rice wallpaper <img>    # set wallpaper -> regenerate palette -> re-render -> reload
rice random [dir]       # pick a random wallpaper and re-theme
rice wallpapers [scheme]# list the curated catalog
rice get-wallpaper …    # download + optionally apply a curated wallpaper
rice accents <scheme>   # list curated accent variants for a scheme
rice accent <name|hex>  # swap accent (--pin to keep across re-themes)
```

Because `rice` is self-contained, it can be bound to a key, run on wallpaper change, or invoked by
a systemd unit — the desktop re-themes without Claude in the loop. The cycler patterns (systemd
user timer, Hyprland `exec-once` loop) are in [`wallpaper.md`](wallpaper.md) → "Cycling".

# Changelog

## 0.16.0

Lands `high-contrast-dark` and `high-contrast-light` schemes — the WCAG-AAA palette pair
v0.14 flagged as the biggest accessibility unlock. Zero corpus rices ship a true
high-contrast variant; the rice now does, with documented contrast budgets and a
fixed-palette opt-out from wallpaper derivation.

### Palette schemes

- **`_shared/palette-schema.md`**: `scheme=` enum expanded — `high-contrast-dark` and
  `high-contrast-light` added with a "WCAG-AAA; opt out of matugen" note.
- **`theming/palettes.md`**:
  - New rows in dark/light catalog tables and the semantic-hues table with verified hex
    values. Dark: bg `000000` / fg `ffffff` / accent `ffff00`. Light: bg `ffffff` /
    fg `000000` / accent `0000ee`.
  - New **"High-contrast schemes"** section with:
    - Contrast budget table (every documented `fg`/`accent`/`accent2`/`muted`/`red` vs `bg`
      pair clears AAA — 21:1 / 19.6:1 / 16.7:1 / 14.6:1 / 8.2:1 on dark).
    - Opt-out from wallpaper-derivation explanation.
    - Interaction with GTK4 `prefers-contrast: more` — our `gtk4.tmpl` overrides system
      preference for our rendered surfaces.
- Removed stale "## Gaps surfaced" section (font_ui_scale shipped in 0.15, high-contrast
  ships here, M3 motion adjacent now noted inline).

### Scripts

- **`palette-from-wallpaper.sh`**: early-returns when current scheme is `high-contrast-*`.
  Keeps the fixed AAA palette intact and only updates the `wallpaper=` line so the user
  still sees their picked wallpaper behind the (still high-contrast) UI. To resume
  derivation: `rice scheme catppuccin-mocha && rice wallpaper <img>`.

### References

- **`theming/wallpaper.md`**: new "High-contrast schemes opt out of derivation" subsection
  under Dynamic theming.
- **`components/accessibility/gotchas.md`**: "no popular rice ships a high-contrast palette"
  finding flipped to "now shipped" with the dual-scheme reachability paths (interview pick
  AND `rice scheme high-contrast-dark`) and the GTK4 override note.

### Skill

- **`SKILL.md`**: preset list 12 → 14 (high-contrast-dark, high-contrast-light); bumped to
  `0.16.0`.

### Orchestrator decisions still pending

- laptop interview sub-question for OSD routing strategy.
- `lock-screen.wallpaper_strategy` schema addition.

## 0.15.0

Lands the **cross-surface font-scale** the v0.14 release flagged as pending. One palette
metadata key, every visual surface scales together — the accessibility / HiDPI knob the
corpus had as DankMaterialShell-only prior art is now a first-class rice feature.

### Cross-surface font-scale (`font_ui_scale`)

- **`_shared/palette-schema.md`**: new metadata key `font_ui_scale` (multiplier, default
  `1.0`; interview options `1.0|1.15|1.3|1.5`). Always populated; defaults to `1.0` if
  unset. Documented sizing rules show the per-surface convention.
- **`theming/palette.matugen.tmpl`**: emits `font_ui_scale=1.0` so a wallpaper-cycle
  re-render preserves the user's scale instead of dropping it.
- **`theming/fonts.md`**: "pending pattern" section flipped to **"Cross-surface
  font-scale"** with the per-surface convention (recipe-driven CSS surfaces use
  `font-size: calc(<base>px * {{font_ui_scale}})`; recipe-driven non-CSS surfaces
  multiply at generate time; quickshell exposes `Colors.fontScale` for QML).
- **`components/widgets/quickshell.tmpl`**: new `readonly property real fontScale:
  {{font_ui_scale}}` property; QML files use `font.pixelSize: <base> * Colors.fontScale`.
  Hot-reload picks it up.
- **`_shared/colors-contract.md`**: quickshell row now includes `fontScale` in the
  exported singleton names.
- **`agents/hyprland-component-writer.md`**: new coherence rule — every recipe fill scales
  font-sizes by `{{font_ui_scale}}`. CSS surfaces use `calc()`, non-CSS surfaces multiply
  at write time, QML surfaces use `Colors.fontScale`. Notes the DMS dual-knob pattern
  (`fontScale` + `dankBarFontScale`) as future per-surface override prior art.
- **`components/accessibility/gotchas.md`**: the "no shared font-scale" absence finding
  is rewritten as **"Shared font-scale variable (now exposed)"** with prior art and the
  complement to the `larger-ui` gsettings bridge.
- **`SKILL.md`**: A4 always populates `font_ui_scale`; bumped to `0.15.0`.

### Orchestrator decisions still pending
- `high-contrast-dark` / `high-contrast-light` scheme (ripple-list in `palettes.md`).
- laptop interview sub-question for OSD routing strategy.
- `lock-screen.wallpaper_strategy` schema addition.

## 0.14.0

Three-batch deep-research pass across the corpus (top ~19 community Hyprland rices on
github.com/topics/hyprland) — 22 component reference folders + 7 cross-cutting theming docs
updated against verified upstream sources. The skill, the writer + validator agents, and the
contract files are updated to leverage what landed.

### Engine scripts
- **`render-templates.sh`**: after the manifest loop, optionally writes
  `~/.config/hypr/scripts/restore-theme.sh` when `RICE_THEMING_ENGINE=matugen|wallust|wallbash`
  is set. The script re-paints the wallpaper and re-runs the theming engine on login so the
  desktop comes up matching the last rice state instead of a stale palette. Skipped on `none`
  or unset. Body per engine documented in `references/theming/engine.md`.
- **`detect-version.sh`**: emits `HYPR_HAS_EXT_BG_EFFECT_V1=1|0|unknown` — true at Hyprland
  commit `7d1e481` (May 2026, ~v0.50+) where `ext-background-effect-v1` lands. Walker's
  `ext_background_effect_blur = true` opt-in needs the protocol; on older Hyprland the only
  path is a `layerrule = blur, walker` block. The flag lets the writer + window-rules
  template branch correctly without re-parsing the version string.

### Color templates / contract
- **`components/launcher/fuzzel.tmpl`**: grows from 7 → 11 keys to match every documented
  fuzzel.ini(5) color slot. Adds `prompt` (→ `{{accent}}`), `placeholder` (→ `{{muted}}`),
  `input` (→ `{{fg}}`), `counter` (→ `{{muted}}`). No new palette schema keys.
- **`_shared/colors-contract.md`** rows brought into sync with the actual `.tmpl` content:
  - `kitty` row gains 10 chrome keys (`cursor_text_color`, `url_color`, `active_tab_*`,
    `inactive_tab_*`, `tab_bar_background`, `active_border_color`, `inactive_border_color`,
    `bell_border_color`) so themes don't fall back to kitty's gray defaults on the tab bar.
  - `gtk4` row grows from 14 → 24 keys (libadwaita 1.4+ standards: `headerbar_backdrop_color`,
    `card_fg_color`, `popover_fg_color`, `dialog_*`, `sidebar_*`, `error_color`). Prevents
    DMS's documented "white flash on window unfocus" and themes Nautilus/Loupe correctly.
  - `fuzzel` row grows from 7 → 11 keys (see above).
  - `quickshell` row: `term[16]` → `term0..term15` (individual properties — community uses
    `Colors.term3` direct, not array index), plus M3 motion tokens (`standard`,
    `standardAccel`, `standardDecel`, `emphasized`, `emphasizedAccel`, `emphasizedDecel`).

### Agents
- **`hyprland-component-writer`**: new "Cross-surface coherence" section codifies the
  corpus-validated rules every recipe fill must honour — pill `{{rounding}}` reuse,
  shared `{{accent}}`, hyprbars palette reuse, `#battery.critical → {{red}}`, per-tool
  layerrule namespace map (fuzzel→`launcher`, swaync→2 blocks, walker conditional),
  `envd =` for XDG vars, mako `urgency=critical` (not `high`), Astronaut SDDM
  `snake_case.conf` filenames.
- **`hyprland-config-validator`**: new lint rules step 6 catches the real-world breakage
  the corpus pass surfaced — fuzzel namespace, swaync dual-layer blur, blur master-gate
  dependency, hyprbars literal-hex anti-pattern, kitty chrome export gaps, `env =
  XDG_CURRENT_DESKTOP` (recommend `envd =`), invalid mako `urgency=high`, walker layerrule
  redundancy ≥0.50, Astronaut filename casing.

### References (component-level — batches 1+2)
- **Visual components** (waybar / launcher / notifications / widgets / look-feel /
  lock-screen / terminal / shell-prompt): 8 deep-research passes harvesting theming idioms,
  archetypes, battle-tested techniques, and cross-surface coherence rules from the corpus.
  Highlights: waybar `fixed-center`/`ipc`/JBM `font-feature-settings`; rofi state-selector
  `element selected.normal/urgent/active` syntax fix; quickshell `Singleton` root + M3
  motion tokens; kitty tab-bar chrome; mako `[urgency=critical]` correction; hyprlock
  matugen `hyprlock-colors.conf` archetype; look-feel locked-group color ladder; starship
  `command_timeout=500` + `⇡⇣⇕` glyphs.
- **Structural components** (monitors / input / keybinds / default-apps / env / window-rules
  / autostart / companion-daemons / plugins / utilities / login-boot / gaming / laptop /
  accessibility): 14 deep-research passes harvesting "how popular rices use this component IN
  SERVICE OF the theme". Highlights: window-rules per-tool layerrule emission with all 5
  batch-1 flags upstream-confirmed; autostart `restore-theme.sh` ownership + `dbus_propagation`
  schema; env `envd =` for XDG + Electron-Ozone non-NVIDIA split; plugins 0.55+ lua cliff;
  utilities `theming/apps.md` wlogout-path correction; accessibility three documented
  absence findings (no high-contrast palette, no shared font-scale, no motion-off profile).

### References (cross-cutting theming — batch 3)
- **`theming-architecture.md`**: documents the post-refactor `.tmpl` layout, the new
  dataflows (`restore-theme.sh`, `envd`, layerrule emission table), and cross-surface
  palette coherence (`decoration:rounding` canonical, `$accent` shared).
- **`engine.md`**: per-engine `restore-theme.sh` body table (matugen / wallust / wallbash /
  none) with the canonical guarded script, `HYPR_HAS_EXT_BG_EFFECT_V1` walker blur cliff.
  Palette-template audit confirmed clean: 0 missing exports across all 18 component
  `.tmpl`s and `gtk4.tmpl`.
- **`palettes.md`**: 4 corpus scheme-supply patterns, 26→12 / 40+→12 / `dank16` mapping
  tables, high-contrast scheme gap with the full ripple-list of files an enum would touch.
- **`fonts.md`**: per-rice font picks for 14 corpus rices, omarchy `omarchy-font-set` sweep
  as the model for the re-render path, per-app font-size unit table (rofi pt, fuzzel
  pt-suffix, kitty pt, waybar/QML px, hyprlock per-label pt), `font_ui_scale` pending
  pattern with caelestia/DMS prior art.
- **`wallpaper.md`**: daemon-by-rice table for all 19 corpus rices, Quickshell-owns-wallpaper
  architecture fork, canonical restore-script bodies per engine, lock-screen wallpaper
  decoupling.
- **`apps.md`**: per-app palette-export table resync against actual `.tmpl` content (kitty
  chrome, quickshell `term0..15`, plugins rows), default-apps ricochet table (which
  component's `.tmpl` re-themes each default-app pick), btop/cava `components/utilities/` →
  `components/terminal/` path correction.
- **`gtk-qt.md`**: cursor-coherence three-place table, toolkit footguns
  (`_JAVA_AWT_WM_NONREPARENTING`, `MOZ_DISABLE_RDD_SANDBOX`, `GSK_RENDERER=ngl`,
  `ELECTRON_OZONE_PLATFORM_HINT,auto`), default-app pairing
  (Dolphin→Kvantum, Nautilus→localsearch), `hyprctl setenv` → `hyprctl keyword env` (0.55+
  form).

### Skill
- **`SKILL.md`**: bumped to `0.14.0`. A3 documents the cross-surface coherence rules the
  writer agent enforces. A4 documents `RICE_THEMING_ENGINE` env for `restore-theme.sh`
  emission and the autostart `exec-once` wiring.

### Orchestrator decisions still pending (not in this release)
- New `scheme` enum values for `high-contrast-dark` / `high-contrast-light` (ripple-list
  in `palettes.md`).
- `font_ui_scale` metadata key with caelestia/DMS prior art (ripple to every visual
  `template.md`).
- laptop interview sub-question for OSD routing strategy (#1 cross-surface coherence miss
  in the corpus).
- `lock-screen.wallpaper_strategy` schema addition.

## 0.13.0

Corrections and hardening from an extensive real-world from-scratch build on **Hyprland 0.55.2**
(wallpaper-driven Everforest rice with an hourly matugen re-theme cycle).

### Engine scripts
- **`palette-from-wallpaper.sh`**: fixed for **matugen 4.x** — it now writes a top-level `[config]`
  table (required, else "missing field config") and passes `--prefer`/`--mode`/`--type` (headless
  matugen needs `--prefer` when an image yields multiple source colors). Overridable via
  `MATUGEN_TYPE`/`MATUGEN_MODE`/`MATUGEN_PREFER`. Without this, every wallpaper-driven theme/cycle
  silently kept the old palette.
- **`palette.matugen.tmpl`**: emits `font_ui`/`font_mono` so a re-render (e.g. a wallpaper cycle)
  no longer drops the fonts from `palette.conf`.
- **`safe-apply.sh`**: rollback no longer `rm -rf`s `~/.config/hypr` — a running Hyprland regenerates
  a STUB config the instant the dir goes empty, racing the restore and leaving a nested/stub mess. It
  now restores by overwriting backup files back over the target and pruning only the files the failed
  config added (the dir is never empty).
- **`rice-init.sh`**: derives the plugin's rice dir from the script's own location when
  `CLAUDE_PLUGIN_ROOT` is unset (was a hard abort).

### Color templates (re-theme coherence)
- **`waybar.tmpl`** now emits the full named palette (`…blue/magenta/cyan`) so per-module-hue styles
  re-theme; **`swaync.tmpl`** adds `muted`/`accent2`; **`rofi.tmpl`** switched to the
  `bg/bg-alt/fg/muted/accent/accent2/red/green` var names the theme.rasi actually imports. (Previously
  the engine emitted names the component styles didn't reference, so an `apply` broke the styling.)

### References
- **`components.md`**: waybar Nerd Font glyph rule — a linter strips 3-byte legacy-PUA glyphs
  (U+E000–U+F8FF) from `config.jsonc`, so use 4-byte Material Design icons (U+F0000+) + plain Unicode
  dots (`●`/`○`); verified glyph table; author via `python3 json.dump(ensure_ascii=False)` + re-verify.
  Far-end pill margins for the separated-pills archetype. The `$menu` vs `$dmenu` bug (`$menu -dmenu`
  is broken). swaync `backlight` widget only when a backlight device exists.
- **`config-templates.md`**: `follow_mouse` semantics corrected (`1` is focus-follows-mouse, `2` is
  detached); native **`scrolling`** layout (core in 0.53+, no plugin) + `scrolling {}` block + binds;
  `$dmenu` variable; hyprlock input field kept visible (`fade_on_empty=false`); plugin-dispatcher binds
  must be commented (they hard-error the reload).
- **`plugins.md`**: rewritten — `hyprexpo`/`hyprtrails`/`hyprscrolling` removed from the official repo
  (scrolling is native; hyprexpo via `sandwichfarm/hyprexpo`); hyprpm gotchas (root-owned
  `/var/cache/hyprpm` + internal sudo needs a TTY, `~/.local/share/hyprpm` must exist, don't chain
  enables, `hyprctl plugin load` no-root alternative, plugin dispatchers hard-error).
- **`interview.md`**: focus-model option mapping fixed; plugins catalog updated for native scrolling +
  removed plugins.
- **`theming.md` / `engine.md`**: GTK3/4 `settings.ini` + `~/.gtkrc-2.0` are required (gsettings alone
  leaves GTK3 apps light). eww SCSS uses `rgba()` not `alpha()` (grass 1-arg), no `:height "auto"`.
- **hyprland-reference `styling/`**: `eww.md`, `waybar.md`, `hyprlock.md` mirror the above.

### Agents & skill
- **`hyprland-interviewer`**: documents that `AskUserQuestion` may be disabled inside subagents — probe
  first, return `INTERVIEW=blocked`, never fabricate answers.
- **`hyprland-config-validator`**: flags uncommented plugin-dispatcher binds / plugin-layout lines as
  reload-breaking ERRORS (was wrongly treating them as inert).
- **rice `SKILL.md`**: A1 inline-interview fallback for the blocked case; A4 matugen-4.x note; A5 GTK
  settings.ini + the dynamic-wallpaper systemd-timer pattern; the fourth GTK gotcha.

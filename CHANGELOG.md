# Changelog

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

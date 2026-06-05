# launcher — gotchas

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

## fuzzel hex is `RRGGBBAA` with no `#` — alpha pair is mandatory

The `[colors]` section in `fuzzel.ini` uses bare 8-digit hex: `1e1e2eff` opaque, `1e1e2eee`
translucent. **No leading `#`, and the alpha pair is not optional** — `1e1e2e` parses as
"invalid color" and the launcher fails silently or with a bare-bones unstyled fallback. The
engine renders this via `fuzzel.tmpl` with the suffix already attached:

```ini
background={{bg}}f2
text={{fg}}ff
selection={{accent}}ff
```

so the `{{accent}}ff` form is correct — see `_shared/colors-contract.md`. If you hand-edit a
fuzzel theme, remember to append the two-digit alpha.

The other launchers wrap differently — `_shared/colors-contract.md` lists the per-tool wrap
rules in one place.

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
- **rofi `element selected` doesn't take by itself.** Rofi splits selection by row state; the
  highlight needs both `element selected { … }` AND `element selected normal.normal { … }` or
  the accent doesn't apply to drun rows. Recipe in `template.md` does both.
- **fuzzel `width` is in characters, not pixels.** `width=32` is ~32 character columns wide,
  not 32px. Themes pulled from the internet often look weird because of this.
- **tofi has no app icons.** Text-only by design. `launcher.icons = true` against `tool =
  tofi` is silently coerced to `false` by the writer (see `schema.md`).
- **walker as a service.** Walker is fastest when its background service is autostarted —
  `companion-daemons` should include `walker --gapplication-service` when the launcher pick is
  walker. The picker bind then opens instantly.
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

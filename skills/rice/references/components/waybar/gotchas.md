# waybar — gotchas

## A bad `config.jsonc` makes the bar silently fail to appear

Waybar **does** accept JSONC: the man page (`waybar(5)`) opens with *"The configuration uses the
JSONC file format and is named config or config.jsonc"*, the shipped default
[`resources/config.jsonc`](https://github.com/Alexays/Waybar/blob/master/resources/config.jsonc)
is full of `//` comments, and the parser
([`include/util/json.hpp`](https://github.com/Alexays/Waybar/blob/master/include/util/json.hpp))
uses jsoncpp's `CharReaderBuilder` with default settings — and jsoncpp defaults `allowComments` to
`true`. So `//` and `/* … */` are fine; **trailing commas, an unmatched brace, an unescaped quote
in a `format` string, or a stray non-comment garbage line** are what kill the bar — and they kill
it *silently*: no surface, no placeholder, just a one-line stderr message most users never see and
an immediate exit.

**Rule.** Emit `config.jsonc` from a Python `json.dump(…)` (strict-JSON output by construction —
no trailing commas, no unbalanced braces) and **validate before writing it to disk**:

```bash
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$staging/config.jsonc" \
  || { echo "ERROR: waybar config.jsonc is not valid JSON"; exit 1; }
```

`json.load` rejects `//` comments — which is what we want for *our* generated file, even though
waybar itself would accept them. Hand-authored sibling files (e.g. user overrides) may keep
comments; only the writer's own output is held to strict-JSON. The `validation.md` step runs the
same check before any `pkill -SIGUSR2`.

## MDI glyphs only — a linter silently strips legacy private-use glyphs

A formatter/linter (in the user's editor, in `prettier`, in a pre-commit hook — anything that
re-encodes the file) **strips 3-byte legacy-PUA glyphs** in the range **U+E000–U+F8FF** (the classic
FontAwesome / Devicons set used by countless old waybar configs) and leaves the `"format"` string
**empty**. The bar then renders modules with no icon, no error, no log line — the user just sees
text-only modules and assumes the font is broken.

**Rule.** Use **4-byte Material Design Icons (U+F0000+)** for module icons and **plain Unicode**
(filled `●` U+25CF, hollow `○` U+25CB, U+25xx Geometric Shapes generally) for workspace dots — see
`template.md` for the verified glyph table. **Author `config.jsonc` via Python:**

```python
import json
json.dump(obj, open(path, "w"), ensure_ascii=False, indent=2)
```

Heredocs and `echo > file` mangle UTF-8 sequences across locales. Re-verify after writing:

```bash
# fail if any "format" landed empty after lint
python3 -c '
import json, re, sys
d = json.load(open(sys.argv[1]))
def walk(o):
  if isinstance(o, dict):
    for k, v in o.items():
      if k.startswith("format") and isinstance(v, str) and not v.strip(): yield (k, v)
      if k.startswith("format") and isinstance(v, str) and re.search(r"[-]", v): yield (k, v)
      yield from walk(v)
  elif isinstance(o, list):
    for x in o: yield from walk(x)
for k, v in walk(d): print("BAD", k, repr(v))
' "$staging/config.jsonc"
```

Confirm the chosen Nerd Font actually covers each codepoint with:

```bash
fc-query --format='%{charset}\n' /usr/share/fonts/.../JetBrainsMonoNerdFont-Regular.ttf | head
```

## Plugin dispatchers in `on-click` — same hard-error rule as `binds.conf`

A waybar module's `on-click` (or `on-click-right` / `on-scroll-up` / …) is an arbitrary shell
command, but if the user puts a Hyprland dispatcher there — e.g.
`"on-click": "hyprctl dispatch hyprexpo:expo toggle"` — it will fail every time `hyprexpo` isn't
loaded. The validator's plugin-dispatcher rule
([`_shared/dispatchers.md`](../../_shared/dispatchers.md)) applies here too: keep plugin
dispatchers **out** of `on-click` unless the plugin is enabled in
[`components/plugins/`](../plugins/). If a user wants a workspace-overview button, gate it on
`plugins.enabled && "hyprexpo" in plugins.selected`.

## swaync overlap — the daemon must match the module

If `bar.modules` contains `custom/notification`, the chosen `notifications.daemon` **must** be
`swaync`. The module shells out to `swaync-client -swb` for its JSON state; with `mako` or `dunst`
running instead, the module shows a permanent zero badge and the toggle does nothing. The schema
validator asserts this; the writer drops the module silently if the daemon is wrong. Cross-ref:
[`components/notifications/schema.md`](../notifications/schema.md).

D-Bus-wise only **one** notification daemon can own `org.freedesktop.Notifications` at a time —
that's enforced by the `notifications` component, not here, but it's why this mutex matters.

## `backlight` module only when a backlight device exists

Including `"backlight"` in `modules-right` on a desktop with no monitor backlight (or on a laptop
where the kernel driver isn't exposing one) makes the module render `N/A` and log a warning
forever. Gate it on `/sys/class/backlight/*` being non-empty:

```bash
if compgen -G "/sys/class/backlight/*" > /dev/null; then
  bar_modules+=("backlight")
fi
```

Same shape applies to `battery` (gate on `/sys/class/power_supply/BAT*`) — though the laptop-detect
already drives that pick upstream.

## Translucency requires the `layerrule` blur block — and the namespace must match

Any `bar.transparency` other than `opaque` looks **muddy** without compositor blur. The blur lives
in [`window-rules`](../window-rules/) (not here), but this component's chosen transparency is the
trigger. On Hyprland **0.54+** the `layerrule` is the **block form** (the single-line `layerrule =
blur, waybar` is rejected at parse and fails the entire reload — see
[`_shared/version-matrix.md`](../../_shared/version-matrix.md)):

```conf
layerrule {
  name = blur-waybar
  match:namespace = waybar
  blur = true
  ignore_alpha = 0.1
}
```

The `match:namespace` must equal waybar's own layer namespace. Confirm with `hyprctl layers` (look
for `namespace: waybar`). Known quirk: blur sometimes doesn't apply until the first window opens on
that workspace (Hyprland #6130). The validator (`validation.md`) cross-checks that **if**
`bar.transparency != opaque`, **then** a matching `layerrule` block exists in `window-rules`'s
emitted file.

## Wrong active-workspace class — `.active`, not `.focused`

Hyprland uses `button.active`. Sway uses `button.focused`. Many community styles copied from Sway
configs use `.focused`; on Hyprland that selector silently no-ops and the active workspace looks
unstyled. The recipe in `template.md` uses `.active`; if you adapt from a Sway example, swap it.

**Real-world reproducer:** ML4W's default `themes/default/style.css` still ships
`#workspaces button.focused { background-color: #64727D; box-shadow: inset 0 -3px #ffffff; }`
(forked from the upstream Waybar Sway sample). On Hyprland that rule has done nothing for years;
nobody has noticed because the bar still functions. Re-check any style.css adapted from ML4W
themes for the same forked-from-Sway selector.

## Foreign palette name vocabularies — Catppuccin / Material You don't drop in

Two popular waybar-styling conventions ship completely different `@define-color` namesets from
the rice engine's:

- **Catppuccin** (`catppuccin/waybar` mocha.css): 26 names — `@rosewater @flamingo @pink @mauve
  @red @maroon @peach @yellow @green @teal @sky @sapphire @blue @lavender @text @subtext1 @subtext0
  @overlay2 @overlay1 @overlay0 @surface2 @surface1 @surface0 @base @mantle @crust`.
- **Material You via matugen** (ml4w, binnewbs, dusky default template): 40+ names —
  `@primary @on_primary @primary_container @on_primary_container @primary_fixed @primary_fixed_dim
  @secondary … @surface_container_low @surface_container @surface_container_high
  @surface_container_highest @on_surface @on_surface_variant @error @on_error … @outline
  @outline_variant @inverse_*`.

The rice engine emits **12 names** — `@bg @fg @surface @muted @accent @accent2 @red @green
@yellow @blue @magenta @cyan` (see [`_shared/colors-contract.md`](../../_shared/colors-contract.md)).
Dropping a Catppuccin port `style.css` or an ML4W matugen style into our `~/.config/waybar/` will
**silently un-theme** every selector that references the foreign names — GTK CSS no-ops on unknown
`@define-color`. The rice path forward is to keep referencing our 12 keys and let the engine's
named-scheme catalog (`theming/palettes.md`) supply Catppuccin hexes when the user picks Catppuccin
as their scheme; do NOT `@import` a third-party `mocha.css`.

## Nerd Font fallback isn't guaranteed — list one explicitly

ML4W's default style sets `font-family: "Fira Sans Semibold", "Font Awesome 7 Free", "Font Awesome 7
Brands", "Font Awesome 6 Free", "Font Awesome 6 Brands", FontAwesome, Roboto, Helvetica, Arial,
sans-serif;` — no Nerd Font at all. It relies on FontAwesome stepping in for `format` glyphs. That
only works when `otf-font-awesome` is installed AND the glyph being requested is in FontAwesome's
codepoint set — every MDI glyph (the U+F0xxx range our template uses) will tofu-box because
FontAwesome doesn't cover it. **Always list a Nerd Font first** and `"Symbols Nerd Font"` (the
plain glyph-only fallback) second; the recipe in `template.md` does both. Verify post-install with
`fc-list | grep -i nerd`.

## Do not clobber the user's `UserModules` / `user-style.css` override

JaKooLit, HyDE, and ml4w all ship a dedicated user-override file (`UserModules` /
`~/.config/waybar/themes/<name>/style-custom.css` / HyDE's `user-style.css`) that the rice author
edits instead of the managed config. If we overwrite a sibling `~/.config/waybar/UserModules`,
`style-custom.css`, or `user-style.css` we silently destroy the user's customizations. The writer
must:

1. Detect any of those overrides existing before any write.
2. Leave them in place untouched.
3. Surface the existence to the user so they can re-apply if needed.

Same logic as the symlink rule above; this is the override-file flavour of it.

## Editing through a symlink (HyDE / JaKooLit / ml4w)

If the user's existing `~/.config/waybar/config.jsonc` is a **symlink** into a dotfiles manager's
layouts directory (HyDE, JaKooLit, ml4w all do this), overwriting it edits the dotfile in place and
gets clobbered on the next theme-switch. Detect with `[ -L ~/.config/waybar/config.jsonc ]`; if
true, write to `user-style.css` / a sibling theme dir, or surface the conflict to the user before
overwriting.

## Reload, don't restart, for CSS edits

`pkill -SIGUSR2 waybar` re-reads both `config.jsonc` and `style.css` in place. A full restart is
only needed when `position` / `exclusive` / `gtk-layer-shell` changes. With
`reload_style_on_change: true` in `config.jsonc`, CSS edits also re-trigger on save without the
signal. See `reload.md` for the exact recipe (JSON-parse first, signal second).

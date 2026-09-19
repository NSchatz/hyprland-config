# fuzzel - launcher

Everything this plugin knows about authoring **fuzzel** for the `launcher` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template
- Styling
- Validation
- Gotchas

---

## Template


The engine writes the colors **inline** into `fuzzel.ini` `[colors]` (merge-time render).
Fuzzel does in fact support `include=<abs-path-or-~/relative>` per `fuzzel.ini(5)` and the
community usually splits colors into a separate file that gets included (end-4 uses
`include="~/.config/fuzzel/fuzzel_theme.ini"`; catppuccin/fuzzel ships pure `[colors]` files
intended to be included; caelestia points include at a `current.ini` symlink). The rice's
current engine wiring merges instead — switch to `include=` is a one-manifest-line change if a
future engine pass wants the split. The colors block exports
`background text match selection selection-text selection-match border` per
`_shared/colors-contract.md` — that's the 7-key subset the rice covers. Fuzzel's full
upstream set is 11 (`+prompt placeholder input counter`); recipe extension flagged in the
research report, not added unilaterally. Hex values are **`RRGGBBAA` without `#`** — see
`gotchas.md`.

```ini
[main]
font=Inter:size=13                ; {{fonts.ui_family}} : size = {{fonts.ui_size}}
prompt=">   "
icon-theme=Papirus
icons-enabled=yes                  ; from icons=true; "no" when false
width=32                           ; characters, not px (gotchas.md)
lines=12                           ; layout=fullscreen-grid: 24+; compact-top: 6
horizontal-pad=20
vertical-pad=12
inner-pad=8
layer=overlay                      ; floats above Hyprland layers
exit-on-keyboard-focus-loss=yes    ; from behavior.close-on-focus-loss
match-mode=fuzzy                   ; from behavior.fuzzy — valid values: exact|fzf|fuzzy (default fzf)

[colors]
background={{bg}}f2                ; rendered from fuzzel.tmpl
text={{fg}}ff
match={{accent}}ff
selection={{accent}}ff
selection-text={{bg}}ff
selection-match={{accent2}}ff
border={{accent}}ff

[border]
width=1
radius=14
```

---

## Styling


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

---

## Validation


- **INI parse + `[colors]` section present.** fuzzel doesn't ship a `-validate` flag, so the
  validator uses a Python INI parser (already in the image):

  ```bash
  python3 -c '
  import configparser, sys
  c = configparser.ConfigParser()
  c.read("/home/u/.config/fuzzel/fuzzel.ini")
  for s in ("main","colors","border"):
      assert s in c, f"missing [{s}]"
  '
  ```

- **Color values are `RRGGBBAA` (8 hex chars, no `#`).** This is the most common silent-fail
  (see `gotchas.md`):

  ```bash
  awk '/^\[colors\]/{c=1;next} /^\[/{c=0} c && /=/ {
         split($0,a,"="); v=a[2]; gsub(/[ \t]/,"",v);
         if (v !~ /^[0-9a-fA-F]{8}$/) {
           print FILENAME ":" NR ": bad color (need RRGGBBAA, no #): " $0; bad=1 } }
       END { exit bad }' ~/.config/fuzzel/fuzzel.ini
  ```

- **Required color names present.** The seven contract names from `_shared/colors-contract.md`:

  ```bash
  for k in background text match selection selection-text selection-match border; do
    grep -qE "^$k=" ~/.config/fuzzel/fuzzel.ini \
      || { echo "error: fuzzel.ini [colors] missing $k"; exit 1; }
  done
  ```

---

## Gotchas


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

**Aside: fuzzel DOES support `include=`** (per `fuzzel.ini(5)`: "Absolute path to configuration
file to import. The import file has its own section scope … the path must be an absolute path,
or start with `~/`. Multiple include directives are allowed, but only one path per directive.
Nested imports are allowed."). The current engine renders the `[colors]` block inline because
that's how the manifest is wired (one input → one output, merge-time), but every popular
fuzzel rice that researched did use `include=`: end-4 (`include="~/.config/fuzzel/fuzzel_theme.ini"`),
caelestia (a `current.ini` symlink), catppuccin/fuzzel themes are explicitly designed as
`include`-targets. If the engine ever wants to ship colors as a separate file the user can
swap, `include=` is the supported route — it's not a merge-time-or-bust constraint of
fuzzel's parser.

## fuzzel's default layer-shell namespace is `launcher`, not `fuzzel`

A standing trap when wiring blur. The fuzzel binary advertises its layer-shell surface under
the **namespace `launcher`** by default — not `fuzzel`. From `fuzzel.ini(5)`
(<https://man.archlinux.org/man/fuzzel.ini.5.en>):

```
namespace
    Namespace for the spawned layer shell surface. Useful for blocking fuzzel
    out from screencasts in your compositor if it shows sensitive information.
    Default: launcher
```

Confirmed in the wild: end-4/dots-hyprland's `dots/.config/hypr/hyprland/rules.lua` (HEAD)
contains:

```lua
hl.layer_rule({ match = { namespace = "launcher" }, blur = true})
hl.layer_rule({ match = { namespace = "launcher" }, ignore_alpha = 0.5})
```

…and that's the rule that actually blurs the fuzzel popup. A `layerrule` that targets
`fuzzel` matches nothing and the popup renders flat. Either:

1. **Match the default**: `layerrule { match:namespace = launcher; blur = true; ignore_alpha = 0.2 }` — works out of the box.
2. **Or override** in `~/.config/fuzzel/fuzzel.ini` `[main]`: `namespace=fuzzel` — then your `match:namespace = fuzzel` rule works (rofi/wofi/walker/anyrun do match their binary name; fuzzel is the odd one out).

The rice's `window-rules/template.md` should emit the `launcher` form when `launcher.tool ==
fuzzel`. Cross-reference: `../../window-rules/`.

(Default namespaces by tool, all confirmed against current upstream or live rices: wofi →
`wofi`, rofi → `rofi`, fuzzel → `launcher`, tofi → no `namespace` knob, surface name is
`tofi`, walker → `walker`, anyrun → `anyrun`, vicinae → Qt window, not layer-shell.)


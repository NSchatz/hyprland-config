# foot - terminal

Everything this plugin knows about authoring **foot** for the `terminal` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template
- Validation
- Gotchas

---

## Template


foot **does** support `include=<abs path>` (top-level / [main]; absolute path or `~/`-prefixed,
nested imports OK — see `foot.ini(5)`). However the rice engine still **merges** the `[colors]`
block into `foot.ini` in-place (similar to `mako`/`fuzzel`) so that dual `[colors-dark]` /
`[colors-light]` blocks can coexist with the rest of the user's edits without an extra file.
Hex is bare `RRGGBB`, **no `#`**.

Important: `alpha=` and `blur=` are **colors-section keys**, NOT `[main]` keys. Per
`foot.ini(5)` they're documented under `[colors-dark]` / `[colors-light]` (or the legacy single
`[colors]`). Putting them in `[main]` silently no-ops — foot drops unknown top-level keys
without a warning. See `gotchas.md` "foot `alpha` and `blur` live in `[colors-*]`."

```ini
# Top-level `key=value` pairs live in the implicit [main] section.
font={{font_mono}}:size={{font_size}}
pad={{padding}}x{{padding}} center
# dpi-aware=no honors the literal font size= on fractional-scaled outputs (end-4 default).
dpi-aware=no
# Keep bold text in the regular palette instead of jumping to bright (catppuccin discipline).
bold-text-in-bright=no

[scrollback]
{{#if extras.scrollback-10k}}lines=10000{{/if}}

[cursor]
# block | beam | underline | hollow
style={{cursor.shape}}
{{#if cursor.blink}}blink=yes{{else}}blink=no{{/if}}

[bell]
# foot has no `bell=none` under [main]; bell lives in its own section.
{{#if extras.bell-off}}system=no
urgent=no
visual=no{{/if}}

# Single-mode colors block. For dual light/dark, replace [colors] with two
# [colors-dark] / [colors-light] blocks, each carrying its own alpha= / blur=
# and palette (catppuccin/foot is the canonical example; fufexan/dotfiles
# foot.nix is the nix-managed worked example).
[colors]
alpha={{opacity}}
foreground={{fg}}
background={{bg}}
regular0={{color0}}  regular1={{color1}}  regular2={{color2}}  regular3={{color3}}
regular4={{color4}}  regular5={{color5}}  regular6={{color6}}  regular7={{color7}}
bright0={{color8}}   bright1={{color9}}   bright2={{color10}}  bright3={{color11}}
bright4={{color12}}  bright5={{color13}}  bright6={{color14}}  bright7={{color15}}
```

---

## Validation


foot's INI parser also rejects trailing `# comment` on `key=value` lines under `[main]` / `[cursor]`
/ `[bell]` — comments must live on their own line. Same lint as kitty, scoped to the foot config:

```bash
if grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*=[^#]*[[:space:]]+#' \
     "$HOME/.config/foot/foot.ini"; then
  echo "ERROR: foot.ini has trailing inline comments on key=value lines" >&2
  exit 1
fi
```

---

## Gotchas


The rice engine's per-emulator colors writer branches on this. kitty/alacritty/wezterm/ghostty get
`#1e1e2e`; foot's `[colors]` block takes `1e1e2e` (no `#`, alpha lives in `alpha=` not in the hex).
Easy to get wrong by reusing kitty's writer for foot — foot then silently rejects every color.

## foot `cursor=` is `<text> <cursor-bg>`, not `<cursor-bg> <text>`

Per `foot.ini(5)`: *"Two space separated RRGGBB values specifying the foreground (text) and
background (cursor) colors for the cursor."* — text comes first, cursor fill second.
catppuccin/foot mocha: `cursor=11111b f5e0dc` (crust as text-on-cursor, rosewater as cursor
fill). DankMaterialShell's matugen foot template uses the same shape:
`cursor = {background} {primary}`. Getting the order wrong gives you an accent-on-accent cursor
that's invisible whenever the cursor sits on a glyph. The plugin's `foot.ini` template does
NOT currently emit a `cursor=` line — it relies on foot's default of inverse-of-cell — but if
the user adds one, text comes first.

## foot `alpha` and `blur` live in `[colors-*]`, not `[main]`

`foot.ini(5)` documents `alpha`, `blur`, `foreground`, `background`, `regular0..7`, `bright0..7`,
`dim0..7`, `selection-foreground`, `selection-background` all inside the `[colors-dark]` /
`[colors-light]` sections (or the legacy `[colors]` section). Putting `alpha=0.85` or
`blur=yes` under `[main]` silently no-ops — foot drops unknown top-level keys without a warning.

`blur=yes` is foot's server-side blur hint (read by KDE/Sway compositors). On Hyprland the
actual blur still comes from `decoration { blur { ... } }`; foot's `blur=yes` is a no-op
visual-wise on Hyprland but harmless. Reference: fufexan's nix-managed `foot.nix` sets
`colors-dark.alpha=0.9 blur=yes`, both inside the colors block — that's the right shape.

The plugin's template puts `alpha=` under the right block — `[colors]` is the legacy single-mode
form that still works for "dark only." If the user wants dual light/dark, the foot template
needs both `[colors-dark]` and `[colors-light]` blocks each with their own `alpha=`.

## foot bell config is in `[bell]`, not `[main]`

Stale snippets put `bell=none` under `[main]`; foot silently drops unknown keys, so the bell
stays on. The real keys live in their own section (`foot.ini(5)`):

```ini
[bell]
system=no       # default yes — ring the system bell
urgent=no       # default no  — signal urgency to the compositor
visual=no       # default no  — flash the terminal window
notify=no       # default no  — emit a desktop notification
command=        # default empty — run a command on BEL
```

To silence the bell completely, set `system=no` (the others default off). There is **no
`bell=none`** shortcut.

## foot cursor `style` values

`[cursor] style` accepts `block | beam | underline | hollow` — exactly four values per
`foot.ini(5)`. `bar` (alacritty/ghostty's name for beam) is **not** a valid foot value.


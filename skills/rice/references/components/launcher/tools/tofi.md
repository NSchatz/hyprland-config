# tofi - launcher

Everything this plugin knows about authoring **tofi** for the `launcher` surface:
what to emit, how to style it, how to validate it, what bites, and how to reload it.

Read this file **and** `../common.md`. Do not read the other tools in `tools/`.

## Contents

- Template
- Styling
- Validation

---

## Template


INI-ish `key = value`. Colors take a leading `#`. Forced text-only (no app icons). Worth offering
when the user wants a fast, minimal picker.

```ini
anchor = center
width = 640
height = 320
font = "Inter"                   ; {{fonts.ui_family}}
font-size = 14
num-results = 7

background-color = #{{bg}}ee
border-width = 2
border-color = #{{accent}}
corner-radius = 12
padding-top = 16
padding-bottom = 16
padding-left = 18
padding-right = 18

prompt-text = ">  "
prompt-color = #{{accent}}
text-color = #{{fg}}
selection-color = #{{accent}}
selection-background = #{{surface}}80
```

---

## Styling


Tofi colors here take a leading `#`. Centered box, single accent.

```ini
anchor = center
width = 640
height = 320
horizontal = false
font = "Inter"                 # {{font_ui}}; or a Nerd Font path
font-size = 14
num-results = 7

background-color = #1e1e2eee   # {{bg}} + alpha
outline-width = 0
border-width = 2
border-color = #cba6f7         # {{accent}}
corner-radius = 12
padding-top = 16
padding-bottom = 16
padding-left = 18
padding-right = 18

prompt-text = ">  "
prompt-color = #cba6f7         # {{accent}}
text-color = #cdd6f4           # {{fg}}
result-spacing = 6

selection-color = #cba6f7            # {{accent}} — the highlight (text)
selection-background = #31324480     # {{surface}} + soft alpha
```

---

## Validation


- **tofi `config`** — INI-lenient; sanity check key/value lines. tofi accepts colors with
  or without a leading `#` (RGB / RGBA / RRGGBB / RRGGBBAA all valid).
- **walker `config.toml`** — `python3 -c 'import tomllib; tomllib.load(open(p,"rb"))'`.
- **vicinae `settings.json`** — JSONC (JSON with comments), so plain `jq` rejects valid
  files. Strip comments before validating, e.g.
  `sed -E 's://[^"]*$::; /\/\*/,/\*\//d' settings.json | jq -e . >/dev/null`,
  or use `vicinae config default` to compare keys against the running daemon's schema.
- **anyrun `config.ron`** — RON syntax. There's no shell-quick checker; on a parse error
  anyrun logs to stderr at launch. The validator can lightly check balanced `()`/`{}`/`[]`.


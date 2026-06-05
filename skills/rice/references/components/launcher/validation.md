# launcher — validation

The validator runs once after the writer emits files but before reload. Launcher configs are
loose by nature (every tool parses lenient-INI / RASI / CSS) — the goal is to catch the
silent-fail cases, not lint style. Run the checks below; on any failure, emit a clear diagnostic
and stop the rice pipeline.

## wofi — `~/.config/wofi/config` + `style.css`

- **`config` parse (line-based, lenient).** wofi accepts `key=value` lines and `#` / `;`
  comments. No native dry-run, so the validator uses a shell check:

  ```bash
  awk 'NF && $1 !~ /^[#;]/ && $0 !~ /^[A-Za-z_][A-Za-z0-9_]*=.*/ {
         print FILENAME ":" NR ": not key=value: " $0; bad=1 }
       END { exit bad }' ~/.config/wofi/config
  ```

  Empty lines and comment lines are skipped; everything else must match `KEY=value`. A
  malformed line doesn't crash wofi — it's silently ignored — so the lint catches the
  silent-fail.

- **`style.css` balanced braces + `@import "colors.css"` present.**

  ```bash
  awk 'BEGIN{d=0} { for(i=1;i<=length($0);i++){ c=substr($0,i,1);
        if(c=="{")d++; else if(c=="}"){ d--; if(d<0){print "unbalanced"; exit 1 } } }
       } END { exit (d!=0) }' ~/.config/wofi/style.css
  grep -q '@import.*"colors\.css"' ~/.config/wofi/style.css \
    || echo "warn: style.css does not @import colors.css — engine themes won't apply"
  ```

- **`colors.css` defines the required vars.** The four-name contract:

  ```bash
  for v in bg fg surface accent; do
    grep -q "@define-color *$v " ~/.config/wofi/colors.css \
      || { echo "error: colors.css missing @define-color $v"; exit 1; }
  done
  ```

## rofi — `~/.config/rofi/config.rasi` + `theme.rasi` + `colors.rasi`

- **`config.rasi` and `theme.rasi` parse.** rofi has a built-in dry-parser:

  ```bash
  rofi -no-config -dump-config -theme ~/.config/rofi/theme.rasi >/dev/null
  rofi -dump-config >/dev/null
  ```

  Any RASI error (unknown var, missing brace, unterminated string) prints to stderr and exits
  non-zero. **A failing `theme.rasi` makes rofi silently fall back to the default theme — the
  launcher opens but completely un-themed**, which is the worst case to catch late.

- **`colors.rasi` defines the required vars.** The contract from `_shared/colors-contract.md`:

  ```bash
  for v in bg bg-alt fg muted accent accent2 red green; do
    grep -qE "^\s*$v\s*:" ~/.config/rofi/colors.rasi \
      || { echo "error: colors.rasi missing var: $v"; exit 1; }
  done
  ```

- **`theme.rasi` references only known vars.** Quick check that no `@unknown` slips through:

  ```bash
  rofi -dump-theme -theme ~/.config/rofi/theme.rasi 2>&1 | \
    grep -E 'unable to resolve|unknown' && exit 1 || true
  ```

## fuzzel — `~/.config/fuzzel/fuzzel.ini`

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

## tofi / walker / vicinae / anyrun

- **tofi `config`** — INI-lenient; sanity check key/value lines. tofi accepts colors with
  or without a leading `#` (RGB / RGBA / RRGGBB / RRGGBBAA all valid).
- **walker `config.toml`** — `python3 -c 'import tomllib; tomllib.load(open(p,"rb"))'`.
- **vicinae `settings.json`** — JSONC (JSON with comments), so plain `jq` rejects valid
  files. Strip comments before validating, e.g.
  `sed -E 's://[^"]*$::; /\/\*/,/\*\//d' settings.json | jq -e . >/dev/null`,
  or use `vicinae config default` to compare keys against the running daemon's schema.
- **anyrun `config.ron`** — RON syntax. There's no shell-quick checker; on a parse error
  anyrun logs to stderr at launch. The validator can lightly check balanced `()`/`{}`/`[]`.

## CSS balanced-braces helper (shared across wofi/walker/anyrun style files)

```bash
# Returns 0 if balanced, nonzero otherwise.
balanced_braces() { awk 'BEGIN{d=0}{for(i=1;i<=length($0);i++){c=substr($0,i,1);
  if(c=="{")d++; else if(c=="}"){d--; if(d<0)exit 1}}} END{exit (d!=0)}' "$1"; }
```

## What's NOT validated

- Color **contrast** is not checked — fully unreadable text (text alpha at `00`, accent =
  background) is a styling bug, not a parse error.
- Icon-theme availability — if `Papirus` isn't installed, the launcher just shows blank icons.
  The validator could warn (`gtk-update-icon-cache -l` against installed themes), but it's not
  fatal.
- Whether the launcher's namespace matches a `layerrule` — that's the `window-rules`
  component's validation.

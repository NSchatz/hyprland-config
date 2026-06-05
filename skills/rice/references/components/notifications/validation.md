# notifications — validation

Parse + sanity checks the writer (or `validate.sh`) runs on the emitted files **before** the
reload hook fires. A bad config crashes the daemon at startup, which silently drops every toast
the user sees — so catch parse errors at generate-time.

## mako — `~/.config/mako/config`

mako uses an INI-like grammar: top-level `key=value` lines, plus `[criteria]` sections (e.g.
`[urgency=critical]`, `[mode=do-not-disturb]`). Valid `urgency` values are `low`, `normal`,
`critical` (the freedesktop spec's three levels — **not** `high`). Validate:

```bash
# 1. file exists and is readable
test -r "$HOME/.config/mako/config" || die "mako config missing"

# 2. parse check — mako has no --check flag, but `makoctl reload` is the parse step.
#    Skip if mako isn't running (it's still safe — see reload.md).
if pgrep -x mako > /dev/null; then
  makoctl reload 2>&1 | tee /tmp/mako-reload.log
  ! grep -qE 'parse|invalid|error' /tmp/mako-reload.log || die "mako parse error"
fi

# 3. INI line shape — every non-blank, non-comment, non-section line is key=value
awk '
  /^[[:space:]]*$/ || /^[[:space:]]*#/ || /^\[.*\]$/ { next }
  !/^[a-zA-Z][a-zA-Z0-9_-]*=/ { print "bad mako line: " $0; bad=1 }
  END { exit bad }
' "$HOME/.config/mako/config"

# 4. colors are wrapped #RRGGBB or #RRGGBBAA — not the rice {{var}} placeholders
!  grep -qE '#\{\{|\{\{[a-z]+\}\}' "$HOME/.config/mako/config" \
   || die "unrendered template var in mako config"
```

Common parse failures: stray brace `{}` instead of `[criteria]`, `border-color: …` (CSS colon)
instead of `border-color=…`, hex without the leading `#`.

## dunst — `~/.config/dunst/dunstrc`

dunst INI is **section-scoped** with **indented** `key = value` lines under each section. Validate:

```bash
test -r "$HOME/.config/dunst/dunstrc" || die "dunstrc missing"

# 1. dunst has no standalone --check / --syntax flag. `dunst -print` prints
#    received notifications, NOT a parse check (common confusion). The reliable
#    parse path is dunstctl reload — it exits non-zero on a bad config when the
#    daemon is running. On a fresh install with no daemon yet, fall through to
#    the awk shape-check below.
if pgrep -x dunst > /dev/null; then
  dunstctl reload 2>&1 | tee /tmp/dunst-reload.log
  ! grep -qiE 'error|invalid|parse' /tmp/dunst-reload.log || die "dunst parse error"
fi

# 2. every line is either a section header, a comment, blank, or "key = value"
awk '
  /^[[:space:]]*$/ || /^[[:space:]]*#/ || /^\[[a-zA-Z_0-9]+\]$/ { next }
  !/^[[:space:]]+[a-zA-Z][a-zA-Z0-9_]*[[:space:]]*=/ { print "bad dunst line: " $0; bad=1 }
  END { exit bad }
' "$HOME/.config/dunst/dunstrc"

# 3. NO legacy `geometry = "..."` (modern split form only)
!  grep -qE '^[[:space:]]*geometry[[:space:]]*=' "$HOME/.config/dunst/dunstrc" \
   || die "legacy geometry= key — use width/height/origin/offset"

# 4. critical urgency has timeout = 0 (the styling invariant)
awk '
  /^\[urgency_critical\]/ { in_crit=1; next }
  /^\[/ { in_crit=0 }
  in_crit && /^[[:space:]]*timeout[[:space:]]*=[[:space:]]*0[[:space:]]*$/ { ok=1 }
  END { exit !ok }
' "$HOME/.config/dunst/dunstrc" \
  || die "[urgency_critical] must have timeout = 0"

# 5. no unrendered rice template vars
!  grep -qE '\{\{[a-z]+\}\}' "$HOME/.config/dunst/dunstrc" \
   || die "unrendered template var in dunstrc"
```

dunst's most common parse failure is mixing the legacy `geometry` string with the split form —
the parser accepts both but the result is undefined. The legacy-check above forbids `geometry =`
outright.

## swaync — `config.json` + `style.css`

Two files, two parsers.

### `config.json` — JSON

```bash
test -r "$HOME/.config/swaync/config.json" || die "swaync config.json missing"

# 1. it's valid JSON
jq . "$HOME/.config/swaync/config.json" > /dev/null || die "swaync config.json: bad JSON"

# 2. required keys present
jq -e '.positionX and .positionY and (.timeout|type=="number")' \
   "$HOME/.config/swaync/config.json" > /dev/null \
  || die "swaync config.json: missing positionX/positionY/timeout"

# 3. widgets is an array of strings
jq -e '(.widgets|type=="array") and ([.widgets[]|type=="string"]|all)' \
   "$HOME/.config/swaync/config.json" > /dev/null \
  || die "swaync config.json: widgets must be array of strings"

# 4. backlight widget only when /sys/class/backlight has a device
if jq -e '.widgets | index("backlight")' \
     "$HOME/.config/swaync/config.json" > /dev/null; then
  compgen -G "/sys/class/backlight/*" > /dev/null \
    || die "swaync 'backlight' widget present but no backlight device — drop it"
fi
```

### `style.css` — GTK CSS

GTK doesn't ship a standalone CSS validator, but **balanced braces** + **balanced
parens** + **no unresolved `@var`** catches 95% of breakage:

```bash
test -r "$HOME/.config/swaync/style.css" || die "swaync style.css missing"

# 1. balanced braces
opens=$(grep -o '{' "$HOME/.config/swaync/style.css" | wc -l)
closes=$(grep -o '}' "$HOME/.config/swaync/style.css" | wc -l)
[ "$opens" -eq "$closes" ] || die "swaync style.css: unbalanced { } ($opens vs $closes)"

# 2. balanced parens (for alpha(), rgba(), etc.)
po=$(grep -o '(' "$HOME/.config/swaync/style.css" | wc -l)
pc=$(grep -o ')' "$HOME/.config/swaync/style.css" | wc -l)
[ "$po" -eq "$pc" ] || die "swaync style.css: unbalanced ( ) ($po vs $pc)"

# 3. every @name used is either an @import, @define-color, or @keyframes,
#    or a name imported via colors.css. Hard-list known-good names; flag others.
awk '
  /@import/ || /@define-color/ || /@keyframes/ { next }
  match($0, /@[a-zA-Z][a-zA-Z0-9_-]*/) {
    n = substr($0, RSTART+1, RLENGTH-1)
    if (n !~ /^(bg|fg|surface|muted|accent|accent2|red|theme_[a-z_]+)$/)
      { print "unknown @var: " n; bad=1 }
  }
  END { exit bad }
' "$HOME/.config/swaync/style.css"

# 4. no inline hex (must reference @vars from colors.css)
!  grep -qE '#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?' "$HOME/.config/swaync/style.css" \
   || die "swaync style.css contains inline hex — must use @vars from colors.css"

# 5. no unrendered rice template vars
!  grep -qE '\{\{[a-z]+\}\}' "$HOME/.config/swaync/style.css" \
   || die "unrendered template var in swaync style.css"

# 6. live check — `swaync-client -rs` reports CSS errors to stderr
if pgrep -x swaync > /dev/null; then
  swaync-client -rs 2>&1 | tee /tmp/swaync-reload.log
  ! grep -qiE 'error|warning' /tmp/swaync-reload.log || die "swaync style.css runtime error"
fi
```

## Cross-references

- Per-daemon recipes → `template.md`
- Reload hooks (where the parse check is wedged in) → `reload.md`
- Color-var contract (the `@var` names the swaync `style.css` may reference) →
  `../../_shared/colors-contract.md`

# waybar — validation

The validator runs **before** any reload (`reload.md`) and before the install batch commits its
files. Each check is cheap, has a `python3` / `grep` one-liner, and corresponds to a documented
gotcha (`gotchas.md`).

## Checks

### 1. `config.jsonc` parses as strict JSON

Waybar will silently fail to appear if the JSON is malformed. Reject before signaling.

```bash
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$out/waybar/config.jsonc" \
  || { echo "ERROR: config.jsonc is not valid JSON" >&2; exit 1; }
```

Waybar's parser actually accepts JSONC (`//` and `/* … */` comments — the shipped default config
uses them), but the renderer still emits **strict JSON** because `python3 -m json.tool` /
`json.load` reject comments and trailing commas, giving us a free integrity check at write time.
See `gotchas.md` → *A bad `config.jsonc` makes the bar silently fail*.

### 2. No empty `"format*"` fields (MDI-glyph-strip guard)

The linter rule from `gotchas.md` → *MDI glyphs only* leaves stripped formats blank. Fail the
build if any survives:

```bash
python3 - "$out/waybar/config.jsonc" <<'PY'
import json, re, sys
bad = []
def walk(o, path=()):
    if isinstance(o, dict):
        for k, v in o.items():
            np = path + (k,)
            if k.startswith("format") and isinstance(v, str):
                if not v.strip(): bad.append((np, "empty"))
                # any char in legacy PUA U+E000..U+F8FF is a stripped-glyph time bomb
                if any(0xE000 <= ord(c) <= 0xF8FF for c in v): bad.append((np, "legacy-PUA"))
            walk(v, np)
    elif isinstance(o, list):
        for i, x in enumerate(o): walk(x, path + (i,))
walk(json.load(open(sys.argv[1])))
if bad:
    for p, why in bad: print("FAIL", why, "/".join(map(str, p)))
    sys.exit(1)
PY
```

### 3. `style.css` opens with `@import "colors.css";`

The rice engine writes `colors.css` independently; without the `@import` the bar renders
unthemed.

```bash
head -1 "$out/waybar/style.css" | grep -qE '^@import "colors\.css";' \
  || { echo "ERROR: style.css must open with @import \"colors.css\";" >&2; exit 1; }
```

### 4. `style.css` references only the 12 contract names

Any `@color-name` other than the 12 names ([`_shared/colors-contract.md`](../../_shared/colors-contract.md))
silently un-themes that surface. Allow `alpha(@name, …)` / `shade(@name, …)` / `mix(@a, @b, …)`.

```bash
python3 - "$out/waybar/style.css" <<'PY'
import re, sys
ALLOWED = {"bg","fg","surface","muted","accent","accent2","red","green","yellow","blue","magenta","cyan"}
css = open(sys.argv[1]).read()
used = set(m.group(1) for m in re.finditer(r"@([A-Za-z_][A-Za-z0-9_-]*)", css))
# strip CSS rule keywords like @import / @keyframes / @media
used -= {"import","keyframes","media","define-color","supports","font-face"}
extra = used - ALLOWED
if extra:
    print("FAIL: undefined color vars:", sorted(extra)); sys.exit(1)
PY
```

### 5. Balanced CSS braces

A missing `}` silently truncates the rest of the stylesheet (GTK CSS doesn't error loudly).

```bash
python3 -c "
import sys
s = open(sys.argv[1]).read()
o, c = s.count('{'), s.count('}')
sys.exit(0 if o == c else (print(f'FAIL: {o} {{ vs {c} }}') or 1))
" "$out/waybar/style.css"
```

### 6. No plugin dispatchers in `on-click` (and friends)

Same rule as `binds.conf` — see [`_shared/dispatchers.md`](../../_shared/dispatchers.md) (the
plugin-dispatcher list). Reject any `on-click*` / `on-scroll*` whose command shells out to a known
plugin-only dispatcher unless the plugin is enabled.

```bash
PLUGIN_DISPATCH='hyprexpo:|hy3:|split-workspace:|scroller:|pyprland'
jq -r '.. | objects | to_entries[] | select(.key|test("^on-(click|scroll)")) | .value' \
  "$out/waybar/config.jsonc" \
  | grep -E "$PLUGIN_DISPATCH" \
  && { echo "ERROR: waybar on-click uses a plugin-only dispatcher; gate on plugins.enabled" >&2; exit 1; } || true
```

### 7. Translucency demands the matching `layerrule` blur block

If `bar.transparency != opaque`, the [`window-rules`](../window-rules/) component's emitted
`window-rules.conf` **must** contain a `layerrule` block with `match:namespace = waybar` and
`blur = true`. The validator cross-reads both:

```bash
trans=$(jq -r .bar.transparency answers.json)
if [ "$trans" != "opaque" ]; then
  grep -Pzq '(?s)layerrule\s*\{[^}]*match:namespace\s*=\s*waybar[^}]*blur\s*=\s*true' \
    "$out/hypr/conf.d/window-rules.conf" \
    || { echo "ERROR: bar.transparency=$trans requires layerrule blur block for namespace=waybar" >&2; exit 1; }
fi
```

### 8. `custom/notification` ↔ `notifications.daemon` mutex

If the bar's `modules` list contains `custom/notification`, the chosen notification daemon must be
`swaync`:

```bash
if jq -e '.bar.modules // [] | index("custom/notification")' answers.json >/dev/null; then
  daemon=$(jq -r .notifications.daemon answers.json)
  [ "$daemon" = "swaync" ] || { echo "ERROR: custom/notification requires notifications.daemon=swaync (got $daemon)" >&2; exit 1; }
fi
```

### 9. `backlight` module gated on real hardware

```bash
if jq -e '.bar.modules // [] | index("backlight")' answers.json >/dev/null; then
  compgen -G "/sys/class/backlight/*" >/dev/null \
    || { echo "WARN: bar.modules includes 'backlight' but no /sys/class/backlight/* exists; drop it" >&2; }
fi
```

## Order of operations on reload

1. Run checks 1–6 against the **staged** files in `$out/waybar/`.
2. Run checks 7–9 against `answers.json` + already-emitted sibling files.
3. **Only on all-pass:** copy to `~/.config/waybar/` and signal (`reload.md`).

A failed validation aborts the rice apply — no partial writes, no reload signal.

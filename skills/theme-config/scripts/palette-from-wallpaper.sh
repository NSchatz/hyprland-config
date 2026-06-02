#!/usr/bin/env bash
# Generate ~/.config/hypr-rice/palette.conf from a wallpaper, using an installed generator.
# Order of preference: matugen (Material You) > wallust / pywal (16-color, pywal-compatible JSON).
# Best-effort: on failure it keeps the existing palette and reports.
#
# Usage: palette-from-wallpaper.sh <image>
set -uo pipefail

RICE_DIR="${RICE_DIR:-$HOME/.config/hypr-rice}"
img="${1:-}"
[ -n "$img" ] || { echo "ERROR: usage: palette-from-wallpaper.sh <image>" >&2; exit 2; }
case "$img" in "~"*) img="${HOME}${img#\~}";; esac
[ -f "$img" ] || { echo "ERROR: no such image: $img" >&2; exit 2; }
pal="$RICE_DIR/palette.conf"

# --- matugen (Material You): render palette.conf via matugen's own template, then strip '#'. ---
if command -v matugen >/dev/null 2>&1; then
    tmpl="$RICE_DIR/templates/palette.matugen.tmpl"
    if [ -f "$tmpl" ]; then
        tmpcfg="$(mktemp)"; out="$RICE_DIR/.palette.matugen.out"
        printf "[templates.palette]\ninput_path = '%s'\noutput_path = '%s'\n" "$tmpl" "$out" > "$tmpcfg"
        if matugen --config "$tmpcfg" image "$img" >/dev/null 2>&1 && [ -f "$out" ]; then
            sed 's/=#/=/' "$out" > "$pal.new"
            printf 'wallpaper=%s\n' "$img" >> "$pal.new"
            mv "$pal.new" "$pal"; rm -f "$tmpcfg" "$out"
            echo "PALETTE=ok (matugen)"; exit 0
        fi
        rm -f "$tmpcfg" "$out"
        echo "PALETTE_WARN: matugen run failed, trying pywal/wallust" >&2
    fi
fi

# --- wallust / pywal: both write a pywal-schema colors.json we can map. ---
ran=""
if command -v wallust >/dev/null 2>&1; then wallust run "$img" >/dev/null 2>&1 && ran=wallust; fi
if [ -z "$ran" ] && command -v wal >/dev/null 2>&1; then wal -n -s -t -e -i "$img" >/dev/null 2>&1 && ran=pywal; fi

json=""
for c in "$HOME/.cache/wal/colors.json" "$HOME/.cache/wallust/colors.json"; do
    [ -f "$c" ] && json="$c" && break
done

if [ -n "$json" ] && command -v python3 >/dev/null 2>&1; then
    if python3 - "$json" "$img" "$pal" <<'PY'
import json, sys
data = json.load(open(sys.argv[1])); img = sys.argv[2]; out = sys.argv[3]
sp = data.get("special", {}); co = data.get("colors", {})
def h(x): return (x or "").lstrip("#")
L = ["scheme=wallpaper",
     f"bg={h(sp.get('background'))}",
     f"fg={h(sp.get('foreground'))}",
     f"cursor={h(sp.get('cursor') or sp.get('foreground'))}"]
for i in range(16):
    L.append(f"color{i}={h(co.get('color'+str(i)))}")
L += [f"red={h(co.get('color1'))}", f"green={h(co.get('color2'))}",
      f"yellow={h(co.get('color3'))}", f"blue={h(co.get('color4'))}",
      f"magenta={h(co.get('color5'))}", f"cyan={h(co.get('color6'))}",
      f"accent={h(co.get('color4'))}", f"accent2={h(co.get('color5'))}",
      f"surface={h(co.get('color8') or sp.get('background'))}",
      f"muted={h(co.get('color8'))}", f"wallpaper={img}"]
open(out, "w").write("\n".join(L) + "\n")
PY
    then echo "PALETTE=ok ($ran json)"; exit 0; fi
fi

echo "PALETTE=skipped (no generator produced a palette; install matugen or wallust). Existing palette kept." >&2
exit 3

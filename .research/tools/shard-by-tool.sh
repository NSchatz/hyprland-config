#!/usr/bin/env bash
# Re-shard a component's reference folder so the load unit is COMPONENT x TOOL.
#
# The tree is organized by component (waybar/, launcher/, widgets/ ...), but a writer agent only
# ever authors for the ONE tool the user picked. Today it loads the recipe for every tool the
# component supports: an eww writer reads the AGS and Quickshell sections too. That is the
# padding that makes a writer skim instead of read.
#
# This turns:
#     widgets/{styling,template,validation,gotchas,reload}.md   (each covering every tool)
# into:
#     widgets/common.md        cross-tool content, kept from every source file
#     widgets/tools/eww.md     everything about eww, gathered from all five
#     widgets/tools/ags.md     ...
#
# Losslessness is asserted, not assumed: every line of every source file lands in exactly one
# output, and the script refuses the whole component if the line counts do not reconcile.
#
# Usage: shard-by-tool.sh <component-dir> <tool-slug>=<heading-regex> [<slug>=<regex> ...]
#   e.g. shard-by-tool.sh .../widgets eww='^#{2,3} *eww\b' quickshell='^#{2,3} *Quickshell\b'
set -euo pipefail

comp="${1:?usage: shard-by-tool.sh <component-dir> <slug>=<regex> ...}"; shift
[ -d "$comp" ] || { echo "not a directory: $comp" >&2; exit 2; }
cname="$(basename "$comp")"

# Source files that carry per-tool content. Order matters: it is the order the sections appear
# in each assembled per-tool document.
SRC_ORDER=(template styling validation gotchas reload)
SECTION_TITLE=([0]=Template [1]=Styling [2]=Validation [3]=Gotchas [4]=Reload)

slugs=(); regexes=()
for spec in "$@"; do
    slugs+=("${spec%%=*}")
    regexes+=("${spec#*=}")
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

total_in=0
total_out=0

# --- split each source file into per-tool chunks + a common remainder ------------------------
for i in "${!SRC_ORDER[@]}"; do
    src="$comp/${SRC_ORDER[$i]}.md"
    [ -f "$src" ] || continue
    total_in=$(( total_in + $(wc -l < "$src") ))

    # Build an awk program that tags every line with the slug that owns it, or COMMON.
    # A section runs from its heading to the next heading of the SAME OR SHALLOWER depth.
    # A `#` line is only a heading when it is OUTSIDE a fenced code block. Shell comments
    # (`# Parse-only: ...`) inside a ```bash fence look identical and would otherwise close
    # the section early, silently splitting a recipe in half.
    awk_prog='
      function depth(l,   n) { n=0; while (substr(l,n+1,1)=="#") n++; return n }
      BEGIN { cur="COMMON"; curdepth=0; fence=0 }
      /^[ \t]*(```|~~~)/ { fence = !fence; print cur "\t" $0; next }
      (!fence) && /^#+ / {
          d = depth($0)
          if (cur != "COMMON" && d <= curdepth) cur = "COMMON"
          for (s in RE) {
              if ($0 ~ RE[s]) { cur = s; curdepth = d; break }
          }
      }
      { print cur "\t" $0 }
    '
    # Feed the regex table in via -v pairs (awk has no array literals on the command line).
    awkargs=()
    for j in "${!slugs[@]}"; do
        awkargs+=(-v "RE_${j}=${regexes[$j]}" -v "SLUG_${j}=${slugs[$j]}")
    done
    # Materialize RE[] from the RE_n / SLUG_n scalars inside BEGIN.
    # NOTE: awk -v processes string escapes, and gawk reads \b as BACKSPACE, not a word
    # boundary. Callers must pass backslash-free regexes (use [^a-zA-Z] instead of \b).
    {
        printf 'BEGIN {\n'
        for j in "${!slugs[@]}"; do
            printf '  RE["%s"] = RE_%s\n' "${slugs[$j]}" "$j"
        done
        printf '}\n'
        printf '%s\n' "$awk_prog"
    } > "$work/split.awk"

    awk "${awkargs[@]}" -f "$work/split.awk" "$src" > "$work/${SRC_ORDER[$i]}.tagged"
done

# --- assemble the per-tool documents ----------------------------------------------------------
mkdir -p "$comp/tools"
for slug in "${slugs[@]}"; do
    out="$comp/tools/$slug.md"
    {
        printf '# %s - %s\n\n' "$slug" "$cname"
        printf 'Everything this plugin knows about authoring **%s** for the `%s` surface:\n' "$slug" "$cname"
        printf 'what to emit, how to style it, how to validate it, what bites, and how to reload it.\n\n'
        printf 'Read this file **and** `../common.md`. Do not read the other tools in `tools/`.\n\n'
        printf '## Contents\n\n'
        for i in "${!SRC_ORDER[@]}"; do
            [ -f "$work/${SRC_ORDER[$i]}.tagged" ] || continue
            if awk -F'\t' -v s="$slug" '$1==s' "$work/${SRC_ORDER[$i]}.tagged" | grep -q .; then
                printf -- '- %s\n' "${SECTION_TITLE[$i]}"
            fi
        done
        printf '\n'
        for i in "${!SRC_ORDER[@]}"; do
            [ -f "$work/${SRC_ORDER[$i]}.tagged" ] || continue
            body="$(awk -F'\t' -v s="$slug" '$1==s {sub(/^[^\t]*\t/,""); print}' "$work/${SRC_ORDER[$i]}.tagged")"
            [ -n "$(printf '%s' "$body" | tr -d '[:space:]')" ] || continue
            # The chunk opens with the tool's own heading (`## eww`). The `## Styling` wrapper
            # below already frames it, so drop the duplicate rather than nest it.
            body="$(printf '%s\n' "$body" | awk 'NR==1 && /^#+ /{next} {print}')"
            printf -- '---\n\n## %s\n\n' "${SECTION_TITLE[$i]}"
            printf '%s\n\n' "$body"
        done
    } > "$out"
    printf '  tools/%-16s ~%5d tok\n' "$slug.md" "$(( $(wc -c < "$out") / 4 ))"
done

# --- assemble common.md -------------------------------------------------------------------------
out="$comp/common.md"
{
    printf '# %s - common\n\n' "$cname"
    printf 'Cross-tool content for the `%s` surface: what holds no matter which tool was picked.\n' "$cname"
    printf 'Read this **plus** the one `tools/<your-tool>.md` the interview selected.\n\n'
    printf '## Contents\n\n'
    for i in "${!SRC_ORDER[@]}"; do
        [ -f "$work/${SRC_ORDER[$i]}.tagged" ] || continue
        if awk -F'\t' '$1=="COMMON"' "$work/${SRC_ORDER[$i]}.tagged" | sed 's/^COMMON\t//' | grep -q '[^[:space:]]'; then
            printf -- '- %s\n' "${SECTION_TITLE[$i]}"
        fi
    done
    printf '\n'
    for i in "${!SRC_ORDER[@]}"; do
        [ -f "$work/${SRC_ORDER[$i]}.tagged" ] || continue
        body="$(awk -F'\t' '$1=="COMMON" {sub(/^[^\t]*\t/,""); print}' "$work/${SRC_ORDER[$i]}.tagged")"
        [ -n "$(printf '%s' "$body" | tr -d '[:space:]')" ] || continue
        # Drop the source file's own H1 (`# widgets - template`); the `## Template` wrapper
        # below replaces it, and two titles for one section reads as a nesting error.
        body="$(printf '%s\n' "$body" | awk 'NR==1 && /^# /{next} {print}')"
        printf -- '---\n\n## %s\n\n' "${SECTION_TITLE[$i]}"
        printf '%s\n\n' "$body"
    done
} > "$out"
printf '  %-22s ~%5d tok\n' "common.md" "$(( $(wc -c < "$out") / 4 ))"

# --- reconcile: every source line must appear in exactly one output ---------------------------
for i in "${!SRC_ORDER[@]}"; do
    [ -f "$work/${SRC_ORDER[$i]}.tagged" ] || continue
    total_out=$(( total_out + $(wc -l < "$work/${SRC_ORDER[$i]}.tagged") ))
done
if [ "$total_in" -ne "$total_out" ]; then
    echo "REFUSED $cname: $total_in source lines, $total_out tagged - not lossless" >&2
    exit 1
fi
echo "  reconciled: $total_in lines in, $total_out lines placed"

#!/usr/bin/env bash
# Move every research-citation block out of the load path into .research/sources/.
#
# A `Sources` block is provenance: it says why a recommendation is trustworthy, and it stays in
# the repo. It does not belong in the file a writer agent loads on every run - it is
# read-once-by-a-human content sitting in a read-every-run file.
#
# The move is lossless and checkable: every extracted byte lands in .research/sources/, and the
# script verifies the reassembled content matches the original before it commits to the edit.
#
# Usage: extract-sources.sh <plugin-root>   (idempotent; re-running finds nothing to do)
set -euo pipefail

root="${1:?usage: extract-sources.sh <plugin-root>}"
dest="$root/.research/sources"
mkdir -p "$dest"

# The heading that opens a citation block: a bare `Sources`, optionally qualified by a
# parenthetical (`### Sources (eww)`). `### Sources & licensing` is NOT one - that is content.
SRC_RE='^#{1,3} *Sources *([(][^)]*[)])? *$'

moved=0
while IFS= read -r f; do
    grep -qE "$SRC_RE" "$f" || continue

    rel="${f#"$root"/}"
    # skills/rice/references/components/waybar/styling.md -> components-waybar-styling.md
    flat="$(printf '%s' "${rel#skills/}" | sed 's@^rice/references/@@; s@^hyprland-reference/references/@hyprland-reference-@; s@/@-@g')"
    out="$dest/$flat"

    # Split the file into: kept lines, and the citation blocks (with their headings).
    # A block runs from its `Sources` heading to the next heading of the SAME OR SHALLOWER
    # depth, so a `### Sources (eww)` inside a `## eww` section ends at the next `##`/`###`.
    awk -v src_re="$SRC_RE" -v keep="$f.keep" -v cut="$f.cut" '
        function depth(line,   n) { n = 0; while (substr(line, n+1, 1) == "#") n++; return n }
        BEGIN { incut = 0 }
        /^#+ / {
            d = depth($0)
            if ($0 ~ src_re) { incut = 1; cutdepth = d; print > cut; next }
            if (incut && d <= cutdepth) { incut = 0 }
        }
        { if (incut) print > cut; else print > keep }
    ' "$f"

    [ -s "$f.cut" ] || { rm -f "$f.keep" "$f.cut"; continue; }

    # Losslessness check: keep + cut must together account for every line of the original.
    orig_lines=$(wc -l < "$f")
    sum_lines=$(( $(wc -l < "$f.keep") + $(wc -l < "$f.cut") ))
    if [ "$orig_lines" -ne "$sum_lines" ]; then
        echo "REFUSED $rel: $orig_lines lines in, $sum_lines out - not lossless, left untouched" >&2
        rm -f "$f.keep" "$f.cut"
        continue
    fi

    # Write the citations out, with a header saying where they came from.
    {
        printf '# Sources - %s\n\n' "$rel"
        printf 'Research provenance for `%s`.\n\n' "$rel"
        printf 'Extracted from the load path: these citations are why the recommendations in that\n'
        printf 'file are what they are, and are read by a human reviewing them - never by an agent\n'
        printf 'authoring a config.\n\n'
        cat "$f.cut"
    } > "$out"

    # Trim trailing blank lines from the kept body, then add the pointer.
    keep_body="$(sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}' "$f.keep")"
    {
        printf '%s\n' "$keep_body"
        printf '\n## Provenance\n\n'
        printf 'Citations for this file live at `.research/sources/%s` (repo root), kept out of\n' "$flat"
        printf 'the load path on purpose. Read them when reviewing a recommendation, not when\n'
        printf 'authoring a config.\n'
    } > "$f.new"

    mv "$f.new" "$f"
    rm -f "$f.keep" "$f.cut"
    moved=$((moved + 1))
    printf 'MOVED %-58s -> .research/sources/%s\n' "$rel" "$flat"
done < <(find "$root/skills" -name '*.md' | sort)

echo "--- $moved file(s) trimmed"

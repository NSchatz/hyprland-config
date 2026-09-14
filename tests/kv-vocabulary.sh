#!/usr/bin/env bash
# Print the KEY=value narration vocabulary of every in-scope script, one row per emission site.
#
# Usage:  bash tests/kv-vocabulary.sh [<plugin-root>]
# Output: <relative path>\t<stream>\t<KEY>=<literal value or the placeholder below>, sorted.
#
# The value column keeps the LITERAL text a site emits after `KEY=`. A value that starts with a
# shell expansion or a printf conversion has no literal text, so it is recorded as the placeholder
# `<expr>`: the key and the literal half of the vocabulary are what a caller parses, and those are
# what this table pins.
#
# `tests/kv-baseline.txt` is this table captured from the tree BEFORE the exit-code work of
# S0138 began. `tests/test_exit_codes.sh` re-runs this scanner and fails on any row the baseline
# has and the tree no longer does, which is what makes AC-13 able to fail.
set -uo pipefail

KV_EXPR_PLACEHOLDER='<expr>'

# The scanned set: the rice CLI plus every .sh directly under scripts/ or skills/rice/scripts/.
# That is a superset of the in-scope command surface - it includes the two sourced-only libraries
# (xdg-config.sh, version-ledger.sh) on purpose, because a library's emissions are printed by the
# callers that source it. assets/scripts/* are desktop assets the user copies onto their own
# machine and binds to keys, not this plugin's command surface, and are not scanned.
kv_inscope_files() {
    local root="$1"
    {
        [ -f "$root/skills/rice/assets/rice" ] && printf '%s\n' "$root/skills/rice/assets/rice"
        find "$root/scripts" -maxdepth 1 -type f -name '*.sh' -print 2>/dev/null
        find "$root/skills/rice/scripts" -maxdepth 1 -type f -name '*.sh' -print 2>/dev/null
    } | sort
}

kv_scan() {
    local root="$1" f rel stream hit key val
    local -a files
    mapfile -t files < <(kv_inscope_files "$root")
    for f in "${files[@]}"; do
        rel="${f#"$root"/}"
        while IFS= read -r line; do
            # A site that redirects to fd 2 is narration, not data; recorded so a stream move shows.
            case "$line" in
                *'>&2'*) stream=stderr ;;
                *)       stream=stdout ;;
            esac
            # Every `echo`/`printf` whose first word is a literal KEY=. The value is taken up to
            # the first quote, expansion, printf conversion or backslash escape.
            while read -r hit; do
                [ -n "$hit" ] || continue
                key="${hit%%=*}"
                key="${key##*[!A-Z0-9_]}"
                val="${hit#*=}"
                [ -n "$val" ] || val="$KV_EXPR_PLACEHOLDER"
                printf '%s\t%s\t%s=%s\n' "$rel" "$stream" "$key" "$val"
            done < <(printf '%s\n' "$line" \
                | grep -oE "(echo|printf)([[:space:]]+--)?[[:space:]]+['\"]?[A-Z][A-Z0-9_]*=[^\"'\$%\\\\]*" \
                | sed -E "s/^(echo|printf)([[:space:]]+--)?[[:space:]]+['\"]?//")
        done < "$f"
    done | LC_ALL=C sort -u
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    kv_scan "$root"
fi

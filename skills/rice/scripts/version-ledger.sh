#!/usr/bin/env bash
# Read the VERSION-CLIFF LEDGER - `references/_shared/version-matrix.md` - offline.
#
# One parser, shared by the two programs that enforce the ledger's contract:
#   scripts/currency-check.sh        citations, out-of-ledger cliffs, staleness
#   scripts/validate-removed-keys.sh the removed-key set a generated config is
#                                    checked against
#
# Sourcing this file defines the helpers WITHOUT running anything, so both
# programs share ONE definition of what a record is, what a citation must
# resolve to, and where the ledger lives. Nothing here touches the network and
# nothing here needs a Hyprland binary or a running compositor.
#
# The format these helpers parse is declared, in prose, in the ledger itself
# under "Version-cliff record format". That section is the contract; this file
# is only its reader.

# Field separator for every multi-column line these helpers emit. NOT a tab:
# bash's `read` treats tab as IFS whitespace and COLLAPSES a run of them, so an
# empty cell in the middle of a row - exactly the shape of an uncited record -
# would silently shift every field after it. US (0x1f) is not IFS whitespace and
# cannot appear in a markdown table cell.
LEDGER_FS=$'\x1f'

# The two tables that ARE the ledger, plus the derived one, by heading text.
LEDGER_HEADING_HYPRLAND="Version cliffs that components branch on"
LEDGER_HEADING_EXTERNAL="External (non-Hyprland) version cliffs that matter"
LEDGER_HEADING_REMOVED="Removed keys"
LEDGER_HEADING_METADATA="Ledger metadata"

# `ledger_default_path [<plugin-root>]` - where the ledger lives.
ledger_default_path() {
    local root="${1:-}"
    if [ -z "$root" ]; then
        root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
    fi
    printf '%s/skills/rice/references/_shared/version-matrix.md\n' "$root"
}

# `ledger_scan_roots <plugin-root>` - the reference-layer directories the
# currency check is CONFIGURED to scan. A missing one is an error, never a
# silent skip: that is the whole point of naming them here.
ledger_scan_roots() {
    printf '%s/skills/rice/references\n' "$1"
    printf '%s/skills/hyprland-reference/references\n' "$1"
}

# `_ledger_table <file> <heading-substring>` - every row of the markdown table
# under that `## ` heading, as TSV. First line out is the header row.
_ledger_table() {
    awk -v want="$2" -v fs="$LEDGER_FS" '
        function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s); return s }
        /^##[ \t]/ { inh = (index($0, want) > 0) ? 1 : 0; next }
        !inh { next }
        /^\|/ {
            line = $0
            probe = line
            gsub(/[|:\- \t]/, "", probe)
            if (probe == "") next
            sub(/^[ \t]*\|/, "", line)
            sub(/\|[ \t]*$/, "", line)
            n = split(line, cells, "|")
            out = ""
            for (i = 1; i <= n; i++) out = out (i > 1 ? fs : "") trim(cells[i])
            print out
        }
    ' "$1"
}

# `_ledger_col <header-line> <column-name>` - 1-based index of that column.
_ledger_col() {
    printf '%s\n' "$1" | awk -F"$LEDGER_FS" -v want="$2" '
        { for (i = 1; i <= NF; i++) if (tolower($i) == tolower(want)) { print i; exit } }'
}

# `_ledger_select <file> <heading> <col...>` - the named columns of every data
# row, TSV, in file order. Returns 1 when the table or a column is missing.
_ledger_select() {
    local file="$1" heading="$2"; shift 2
    local tbl hdr idx="" c
    tbl="$(_ledger_table "$file" "$heading")" || return 1
    [ -n "$tbl" ] || return 1
    hdr="$(printf '%s\n' "$tbl" | head -n1)"
    for c in "$@"; do
        local i
        i="$(_ledger_col "$hdr" "$c")"
        [ -n "$i" ] || return 1
        idx="${idx:+$idx,}$i"
    done
    printf '%s\n' "$tbl" | tail -n +2 | awk -F"$LEDGER_FS" -v idx="$idx" -v fs="$LEDGER_FS" '
        BEGIN { n = split(idx, want, ",") }
        {
            out = ""
            for (i = 1; i <= n; i++) out = out (i > 1 ? fs : "") $(want[i])
            print out
        }'
}

# `ledger_cliff_records <file>` - the ledger proper: one line per version-cliff
# record, `<table>\t<cliff>\t<source-cell>\t<what-changed>`. `<table>` is
# `hyprland` or `external`.
ledger_cliff_records() {
    local file="$1"
    _ledger_select "$file" "$LEDGER_HEADING_HYPRLAND" "Cliff" "Source" "What changed" \
        | awk -v fs="$LEDGER_FS" '{ print "hyprland" fs $0 }' || return 1
    _ledger_select "$file" "$LEDGER_HEADING_EXTERNAL" "Cliff" "Source" "What changed" \
        | awk -v fs="$LEDGER_FS" '{ print "external" fs $0 }' || return 1
}

# `ledger_removed_keys <file>` - `<key>\t<removed-at>\t<replacement>\t<source>`.
ledger_removed_keys() {
    _ledger_select "$1" "$LEDGER_HEADING_REMOVED" "Key" "Removed at" "Replacement" "Source" \
        | sed 's/`//g'
}

# `ledger_metadata <file> <field>` - the Value cell of that metadata row.
ledger_metadata() {
    _ledger_select "$1" "$LEDGER_HEADING_METADATA" "Field" "Value" 2>/dev/null \
        | sed 's/`//g' \
        | awk -F"$LEDGER_FS" -v want="$2" '$1 == want { print $2; exit }'
}

# `ledger_metadata_source <file> <field>` - the Source cell of that row.
ledger_metadata_source() {
    _ledger_select "$1" "$LEDGER_HEADING_METADATA" "Field" "Source" 2>/dev/null \
        | sed 's/`//g' \
        | awk -F"$LEDGER_FS" -v want="$2" '$1 == want { print $2; exit }'
}

# `ledger_newest_release <file>` - the newest upstream release the ledger has
# been reconciled against, as a bare `x.y.z`. Empty when the row is absent or
# holds no version: the caller decides what to do about that, and every caller
# in this repo refuses rather than assuming one.
ledger_newest_release() {
    ledger_metadata "$1" "newest-release" \
        | grep -oE 'v?[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 | sed 's/^v//'
}

# `ledger_support_floor <file>` - the oldest Hyprland the rice targets.
ledger_support_floor() {
    ledger_metadata "$1" "support-floor" \
        | grep -oE 'v?[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 | sed 's/^v//'
}

# `ledger_hyprland_cliffs <file>` - every Hyprland cliff version the ledger
# RECORDS, as bare `x.y`, one per line.
ledger_hyprland_cliffs() {
    ledger_cliff_records "$1" \
        | awk -F"$LEDGER_FS" '$1 == "hyprland" { print $2 }' \
        | grep -oE '[0-9]+\.[0-9]+' | sort -u -t. -k1,1n -k2,2n
}

# `ledger_external_projects <file>` - the project names the external table
# records, lowercased. A version token on a line naming one of these belongs to
# THAT project, not to Hyprland.
ledger_external_projects() {
    ledger_cliff_records "$1" \
        | awk -F"$LEDGER_FS" '$1 == "external" { print $2 }' \
        | sed -e 's/\*\*//g' -e 's/`//g' \
        | awk '{ print tolower($1) }' | sort -u
}

# `ledger_vercmp <a> <b>` - prints -1, 0 or 1. Pads to three components, so
# `0.55` and `0.55.0` compare equal.
ledger_vercmp() {
    local a="${1#v}" b="${2#v}"
    local ai bi i
    IFS=. read -r -a ai <<< "$a"
    IFS=. read -r -a bi <<< "$b"
    for i in 0 1 2; do
        local x="${ai[$i]:-0}" y="${bi[$i]:-0}"
        case "$x" in ''|*[!0-9]*) x=0 ;; esac
        case "$y" in ''|*[!0-9]*) y=0 ;; esac
        if [ "$x" -lt "$y" ]; then printf -- '-1\n'; return 0; fi
        if [ "$x" -gt "$y" ]; then printf '1\n'; return 0; fi
    done
    printf '0\n'
}

# `ledger_supported_targets <file>` - one target version per minor release from
# the support floor up to the newest release the ledger knows, plus that newest
# release itself. This is "every version the plugin claims to support",
# enumerated from the ledger rather than hard-coded anywhere.
ledger_supported_targets() {
    local file="$1" floor newest fmin nmin n
    floor="$(ledger_support_floor "$file")"
    newest="$(ledger_newest_release "$file")"
    [ -n "$floor" ] && [ -n "$newest" ] || return 1
    fmin="${floor#*.}"; fmin="${fmin%%.*}"
    nmin="${newest#*.}"; nmin="${nmin%%.*}"
    case "$fmin" in ''|*[!0-9]*) return 1 ;; esac
    case "$nmin" in ''|*[!0-9]*) return 1 ;; esac
    n="$fmin"
    while [ "$n" -le "$nmin" ]; do
        printf '0.%s.0\n' "$n"
        n=$((n + 1))
    done
    printf '%s\n' "$newest"
}

# `ledger_citation_urls <cell>` - every http(s) URL in a Source cell.
ledger_citation_urls() {
    printf '%s\n' "$1" | grep -oE 'https?://[^ )>"]+' || true
}

# `ledger_citation_problem <cell>` - "" when the cell is a citation this repo
# accepts, otherwise a one-word reason. The rule, from the ledger's own format
# section: an https URL naming a SPECIFIC upstream artifact. Two non-empty path
# segments, three on github.com, because `github.com/<owner>/<repo>` names a
# project and not the thing that introduced the cliff.
ledger_citation_problem() {
    local cell="$1" urls url host path segs
    urls="$(ledger_citation_urls "$cell")"
    if [ -z "$urls" ]; then
        printf 'no-citation\n'
        return 0
    fi
    while IFS= read -r url; do
        [ -n "$url" ] || continue
        case "$url" in
            https://*) ;;
            *) printf 'not-https:%s\n' "$url"; return 0 ;;
        esac
        host="${url#https://}"
        path="${host#*/}"
        host="${host%%/*}"
        if [ "$path" = "$host" ]; then path=""; fi
        segs="$(printf '%s\n' "$path" | tr '/' '\n' | grep -c '.')"
        case "$host" in
            github.com) [ "$segs" -ge 3 ] || { printf 'not-an-artifact:%s\n' "$url"; return 0; } ;;
            *)          [ "$segs" -ge 2 ] || { printf 'not-an-artifact:%s\n' "$url"; return 0; } ;;
        esac
    done <<< "$urls"
    printf '\n'
}

# `ledger_record_release <source-cell> <what-changed-cell>` - the newest
# HYPRLAND release this record was confirmed against: the newest release tag it
# cites, or the newest `vX.Y.Z` its own text names when it verified itself
# against a source tree rather than a release page. Empty when the record makes
# no Hyprland-release claim at all (every external record).
ledger_record_release() {
    { printf '%s\n' "$1" | grep -oE 'github\.com/hyprwm/Hyprland/(releases/tag|commit|pull)/[^ )>"]+' \
        | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' || true
      printf '%s\n' "$2" | grep -oE '\bv[0-9]+\.[0-9]+\.[0-9]+' || true
    } | sed 's/^v//' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n1
}

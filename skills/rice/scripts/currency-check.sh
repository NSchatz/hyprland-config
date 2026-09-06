#!/usr/bin/env bash
# Is the reference layer's version-cliff ledger CITED, and how far has it fallen
# behind upstream?
#
# The plugin's reference layer is a pile of claims about someone else's software.
# This check gives those claims two properties they otherwise cannot have:
#   1. every version-cliff record NAMES the upstream that decided it, and
#   2. the repo can say which records have not been confirmed against the newest
#      Hyprland release.
#
# It is OFFLINE and deterministic. It never fetches anything: the newest release
# is an INPUT, supplied on the command line or read from the ledger's own
# metadata row. It needs no Hyprland binary and no running compositor.
#
# Usage:
#   currency-check.sh [--root DIR] [--ledger FILE] [--newest-release VER]
#
#   --root DIR             plugin root to scan (default: this script's plugin)
#   --ledger FILE          the version-cliff ledger (default: <root>'s matrix)
#   --newest-release VER   the newest upstream Hyprland release, e.g. 0.56.2.
#                          Overrides the ledger's `newest-release` metadata row.
#
# Env: HYPR_NEWEST_RELEASE  same as --newest-release.
#
# Output (KEY=value lines, the convention every script here follows):
#   CURRENCY_LEDGER=<path>
#   CURRENCY_ROOT=<path>
#   CURRENCY_SCANNED=<n>                files read from the reference layer
#   CURRENCY_RECORDS=<n>                version-cliff records found in the ledger
#   CURRENCY_REMOVED_KEY_RECORDS=<n>    rows of the derived removed-key table
#   CURRENCY_NEWEST_RELEASE=<x.y.z|unknown>
#   CURRENCY_NEWEST_RELEASE_SOURCE=<supplied|ledger|none>
#   UNREADABLE=<path>                   one per file/dir named but not readable
#   UNCITED=<file> | <record> | <claim>
#   UNRESOLVABLE=<file> | <record> | <claim> | <reason>
#   UNLEDGERED_CLIFF=<file>:<line> | <version>+ | <text>
#   STALE=<file> | <record> | <claim> | last confirmed against <v> | newest is <v>
#   STALE_CLAIM=<file>:<line> | names <v> | newest is <v> | <text>
#   CURRENCY_UNCITED=<n>  CURRENCY_UNRESOLVABLE=<n>  CURRENCY_UNLEDGERED=<n>
#   CURRENCY_STALE=<n>
#   CURRENCY=<ok|defects|undetermined-newest-release|no-records|unreadable>
#
# Exit codes, in precedence order (the first that applies wins):
#   5  a file or directory the check is CONFIGURED to scan is missing/unreadable
#   4  the ledger matched ZERO version-cliff records - a check that has stopped
#      matching anything must never read as a clean pass
#   3  the newest release was neither supplied nor readable from the repo
#   2  bad usage
#   1  repo-owned defects: an uncited record, an unresolvable citation, or a
#      cliff asserted outside the ledger that the ledger does not record
#   0  clean. STALENESS ALONE NEVER FAILS: it is reported and the build goes on,
#      because upstream shipping a release is not a defect in this repo.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=version-ledger.sh
source "$here/version-ledger.sh"

root="$(cd "$here/../../.." && pwd)"
ledger=""
newest="${HYPR_NEWEST_RELEASE:-}"
newest_source="none"
[ -n "$newest" ] && newest_source="supplied"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)
            [ "$#" -ge 2 ] || { echo "ERROR: --root needs a value" >&2; exit 2; }
            root="$2"; shift 2 ;;
        --ledger)
            [ "$#" -ge 2 ] || { echo "ERROR: --ledger needs a value" >&2; exit 2; }
            ledger="$2"; shift 2 ;;
        --newest-release)
            [ "$#" -ge 2 ] || { echo "ERROR: --newest-release needs a value" >&2; exit 2; }
            newest="${2#v}"; newest_source="supplied"; shift 2 ;;
        -h|--help)
            sed -n '2,60p' "$0"; exit 0 ;;
        *)
            echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
    esac
done

[ -n "$ledger" ] || ledger="$(ledger_default_path "$root")"

echo "CURRENCY_ROOT=${root}"
echo "CURRENCY_LEDGER=${ledger}"

unreadable=0
name_unreadable() {
    echo "UNREADABLE=$1"
    echo "ERROR: $2" >&2
    unreadable=$((unreadable + 1))
}

if [ ! -f "$ledger" ] || [ ! -r "$ledger" ]; then
    name_unreadable "$ledger" "the version-cliff ledger '$ledger' is missing or unreadable"
    echo "CURRENCY=unreadable"
    exit 5
fi

# --- The files this check is CONFIGURED to scan -----------------------------------------------
# Named, not discovered by luck: a configured directory that has gone missing is
# an error, because "found nothing to scan" and "scanned and found nothing" are
# the same clean report to anyone reading the output.
scan_files=()
while IFS= read -r dir; do
    if [ ! -d "$dir" ] || [ ! -r "$dir" ]; then
        name_unreadable "$dir" "the reference directory '$dir' is missing or unreadable"
        continue
    fi
    while IFS= read -r f; do
        if [ ! -r "$f" ]; then
            name_unreadable "$f" "the reference file '$f' cannot be read"
            continue
        fi
        scan_files+=("$f")
    done < <(find "$dir" \( -type f -o -type l \) \( -name '*.md' -o -name '*.tmpl' \) -print | sort)
done < <(ledger_scan_roots "$root")

echo "CURRENCY_SCANNED=${#scan_files[@]}"

if [ "$unreadable" -gt 0 ]; then
    echo "CURRENCY=unreadable"
    exit 5
fi

# --- The records ------------------------------------------------------------------------------
records="$(ledger_cliff_records "$ledger" 2>/dev/null || true)"
record_count="$(printf '%s' "$records" | grep -c . || true)"
removed_rows="$(ledger_removed_keys "$ledger" 2>/dev/null || true)"
removed_count="$(printf '%s' "$removed_rows" | grep -c . || true)"
echo "CURRENCY_RECORDS=${record_count}"
echo "CURRENCY_REMOVED_KEY_RECORDS=${removed_count}"

if [ "$record_count" -eq 0 ]; then
    echo "ERROR: the ledger '$ledger' matched ZERO version-cliff records. Either the ledger is empty or its record format changed under this check; a check that matches nothing is not a clean reference layer." >&2
    echo "CURRENCY=no-records"
    exit 4
fi

# --- The newest release: supplied, or read from the repo, or REFUSE ----------------------------
if [ -z "$newest" ]; then
    newest="$(ledger_newest_release "$ledger")"
    [ -n "$newest" ] && newest_source="ledger"
fi
if [ -z "$newest" ]; then
    echo "CURRENCY_NEWEST_RELEASE=unknown"
    echo "CURRENCY_NEWEST_RELEASE_SOURCE=none"
    echo "ERROR: the newest Hyprland release was neither supplied (--newest-release / HYPR_NEWEST_RELEASE) nor readable from the ledger's 'newest-release' metadata row in '$ledger'. Staleness cannot be measured, and this check will NOT report the reference layer current on the strength of not knowing." >&2
    echo "CURRENCY=undetermined-newest-release"
    exit 3
fi
echo "CURRENCY_NEWEST_RELEASE=${newest}"
echo "CURRENCY_NEWEST_RELEASE_SOURCE=${newest_source}"

# `claim_text <cell>` - the record's own identifying text, flattened for a report line.
claim_text() {
    printf '%s\n' "$1" \
        | sed -e 's/\[\([^]]*\)\](\([^)]*\))/\1/g' -e 's/[*`]//g' \
        | tr -s ' \t' ' ' | cut -c1-90
}

ledger_rel="${ledger#"$root"/}"

uncited=0
unresolvable=0
unledgered=0
stale=0

# --- Citations: every record names a resolvable upstream artifact ------------------------------
check_citation() {   # <record-id> <source-cell> <claim-cell>
    local id="$1" src="$2" claim="$3" problem
    problem="$(ledger_citation_problem "$src")"
    case "$problem" in
        "") return 0 ;;
        no-citation)
            echo "UNCITED=${ledger_rel} | ${id} | $(claim_text "$claim")"
            uncited=$((uncited + 1)) ;;
        *)
            echo "UNRESOLVABLE=${ledger_rel} | ${id} | $(claim_text "$claim") | ${problem}"
            unresolvable=$((unresolvable + 1)) ;;
    esac
}

while IFS="$LEDGER_FS" read -r table cliff src changed; do
    [ -n "${cliff:-}" ] || continue
    check_citation "$(claim_text "$cliff")" "$src" "$changed"
done <<< "$records"

while IFS="$LEDGER_FS" read -r key removed_at replacement src; do
    [ -n "${key:-}" ] || continue
    check_citation "removed-key ${key}" "$src" "removed at ${removed_at}; use ${replacement}"
done <<< "$removed_rows"

# --- The single-source rule: no cliff introduced outside the ledger ----------------------------
floor="$(ledger_support_floor "$ledger")"
[ -n "$floor" ] || floor="0.0"
recorded="$(ledger_hyprland_cliffs "$ledger")"
projects="$(ledger_external_projects "$ledger")"

is_recorded_cliff() {
    printf '%s\n' "$recorded" | grep -qxF "$1"
}
names_external_project() {   # <line>
    local lower p
    lower="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        case "$lower" in *"$p"*) return 0 ;; esac
    done <<< "$projects"
    return 1
}

for f in ${scan_files[@]+"${scan_files[@]}"}; do
    [ "$f" = "$ledger" ] && continue
    rel="${f#"$root"/}"
    while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        lno="${hit%%:*}"
        text="${hit#*:}"
        names_external_project "$text" && continue
        while IFS= read -r ver; do
            [ -n "$ver" ] || continue
            [ "$(ledger_vercmp "$ver" "$floor")" = "1" ] || continue
            is_recorded_cliff "$ver" && continue
            echo "UNLEDGERED_CLIFF=${rel}:${lno} | ${ver}+ | $(claim_text "$text")"
            unledgered=$((unledgered + 1))
        done < <(printf '%s\n' "$text" | grep -oE '(^|[^0-9.])0\.[0-9]+\+' \
                 | sed -e 's/^[^0-9]*//' -e 's/+$//' | sort -u)
    done < <(grep -nE '(^|[^0-9.])0\.[0-9]+\+' "$f" || true)
done

# --- Staleness: reported, never fatal on its own -----------------------------------------------
# A Hyprland cliff record is STALE when the newest release it was confirmed
# against is older than the newest release upstream has shipped. That is not a
# defect in this repo - it is the repo knowing it has fallen behind, which is
# the whole point. External records make no claim about a Hyprland release and
# are not measured against one.
while IFS="$LEDGER_FS" read -r table cliff src changed; do
    [ "${table:-}" = "hyprland" ] || continue
    confirmed="$(ledger_record_release "$src" "$changed")"
    [ -n "$confirmed" ] || continue
    [ "$(ledger_vercmp "$confirmed" "$newest")" = "-1" ] || continue
    echo "STALE=${ledger_rel} | $(claim_text "$cliff") | $(claim_text "$changed") | last confirmed against v${confirmed} | newest is v${newest}"
    stale=$((stale + 1))
done <<< "$records"

# Prose that asserts which release is the newest one. `deprecations.md` carried
# exactly this shape of sentence for four releases with nothing to catch it.
for f in ${scan_files[@]+"${scan_files[@]}"}; do
    rel="${f#"$root"/}"
    while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        lno="${hit%%:*}"
        text="${hit#*:}"
        while IFS= read -r ver; do
            [ -n "$ver" ] || continue
            ver="${ver#v}"
            [ "$(ledger_vercmp "$ver" "$newest")" = "-1" ] || continue
            echo "STALE_CLAIM=${rel}:${lno} | names v${ver} | newest is v${newest} | $(claim_text "$text")"
            stale=$((stale + 1))
        done < <(printf '%s\n' "$text" | grep -oE '\bv?0\.[0-9]+(\.[0-9]+)?\b' | sort -u)
    done < <(grep -niE 'latest stable|latest upstream|newest (upstream )?release|current(ly)? the newest' "$f" || true)
done

echo "CURRENCY_UNCITED=${uncited}"
echo "CURRENCY_UNRESOLVABLE=${unresolvable}"
echo "CURRENCY_UNLEDGERED=${unledgered}"
echo "CURRENCY_STALE=${stale}"

if [ "$((uncited + unresolvable + unledgered))" -gt 0 ]; then
    echo "The defects above are owned by THIS repo: a record with no upstream behind it, a citation that does not resolve to an artifact, or a cliff asserted where nothing records it. Fix them in ${ledger_rel} or in the file named."
    echo "CURRENCY=defects"
    exit 1
fi

echo "CURRENCY=ok (${record_count} version-cliff records, all cited; ${stale} claim(s) not yet confirmed against v${newest})"
exit 0

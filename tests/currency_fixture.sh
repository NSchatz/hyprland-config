#!/usr/bin/env bash
# Fixture builders shared by tests/test_currency_citations.sh and
# tests/test_currency_staleness.sh. Not a test file: `tests/run.sh` only
# discovers `test_*.sh`, so this is sourced explicitly by the files that use it.
#
# The point of a synthetic ledger rather than a copy of the shipped one is that
# every negative case below (an uncited row, a citation that names only a
# project, a ledger with no records at all) has to be constructed. Mutating the
# real file with sed would make the tests depend on its current wording; these
# fixtures depend only on the FORMAT the ledger declares.

CURRENCY_CHECK="$PLUGIN_ROOT/skills/rice/scripts/currency-check.sh"
SHIPPED_LEDGER="$PLUGIN_ROOT/skills/rice/references/_shared/version-matrix.md"

# `fix_ledger <path> [<extra-cliff-row>...]` - a format-valid ledger with one
# Hyprland record, one external record, one removed-key row and both metadata
# rows. Extra rows are appended to the Hyprland cliff table verbatim.
fix_ledger() {
    local out="$1"; shift
    mkdir -p "$(dirname "$out")"
    cat > "$out" <<'HEAD'
# Fixture version matrix

## Version-cliff record format

A version-cliff record is one row of the two cliff tables below.

## Ledger metadata

| Field | Value | Source |
|---|---|---|
| `newest-release` | v0.56.2 (published 2026-08-05) | [v0.56.2](https://github.com/hyprwm/Hyprland/releases/tag/v0.56.2) |
| `support-floor` | 0.50 | [v0.50.0](https://github.com/hyprwm/Hyprland/releases/tag/v0.50.0) |

## Version cliffs that components branch on

| Cliff | What changed | Components affected | Source |
|---|---|---|---|
| **0.55+** | `misc:vfr` was reclassified to `debug:vfr`. | `look-feel`. | [v0.55.0](https://github.com/hyprwm/Hyprland/releases/tag/v0.55.0) |
HEAD
    local row
    for row in "$@"; do printf '%s\n' "$row" >> "$out"; done
    cat >> "$out" <<'TAIL'

## External (non-Hyprland) version cliffs that matter

| Cliff | What changed | Components affected | Source |
|---|---|---|---|
| **hyprpaper 0.8.0** | Config syntax hard break. | `companion-daemons`. | [hyprpaper v0.8.0](https://github.com/hyprwm/hyprpaper/releases/tag/v0.8.0) |

## Removed keys (validate-removed-keys.sh reads this table and nothing else)

| Key | Removed at | Replacement | Source |
|---|---|---|---|
| `misc:vfr` | 0.55 | `debug:vfr` | [v0.55.0](https://github.com/hyprwm/Hyprland/releases/tag/v0.55.0) |
TAIL
}

# `fix_root <dir> [<extra-cliff-row>...]` - a whole fixture plugin root: the two
# reference directories the check is configured to scan, plus a ledger.
fix_root() {
    local d="$1"; shift
    mkdir -p "$d/skills/rice/references/components" \
             "$d/skills/hyprland-reference/references"
    fix_ledger "$d/skills/rice/references/_shared/version-matrix.md" "$@"
    printf '# a component file that REFERENCES the 0.55+ cliff\n\nOn 0.55+ emit `debug:vfr`.\n' \
        > "$d/skills/rice/references/components/look-feel.md"
    printf '# a reference file with no cliff assertion at all\n' \
        > "$d/skills/hyprland-reference/references/notes.md"
}

# `fix_run <root> [args...]` - run the currency check against a fixture root.
# Leaves the combined output in FIX_OUT and the exit code in FIX_RC. Not called
# in a command substitution, so both survive into the caller's shell.
FIX_OUT=""
FIX_RC=0
fix_run() {
    local d="$1"; shift
    FIX_OUT="$(bash "$CURRENCY_CHECK" --root "$d" "$@" 2>&1)"
    FIX_RC=$?
}

# `fix_has <needle>` / `fix_grep <extended-regex>` - assertions against FIX_OUT.
fix_has()  { printf '%s\n' "$FIX_OUT" | grep -qF "$1"; }
fix_grep() { printf '%s\n' "$FIX_OUT" | grep -qE "$1"; }
fix_count() { printf '%s\n' "$FIX_OUT" | grep -cE "$1"; }

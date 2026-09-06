#!/usr/bin/env bash
# S0040-hyprland-config-currency-8 - CITATION COVERAGE (acceptance group A).
#
# Grades:
#   A1  WHEN the reference layer records a version cliff THE SYSTEM SHALL cite the
#       upstream release, wiki page or commit that introduced it
#   A2  ... SHALL name, by file and by the record's own identifying text, every
#       version-cliff record carrying no upstream citation, and SHALL exit non-zero
#       whenever that list is non-empty
#   A3  ... over the reference layer as shipped SHALL find no fewer version-cliff
#       records than the 25 present at pin 03d2558, and report zero of them uncited
#   A4  IF a reference file outside the ledger asserts a Hyprland version cliff the
#       ledger does not record THEN report it and exit non-zero
#   A5  IF a record's upstream cannot be named at all THEN fail rather than accept
#       it, and the shipped layer SHALL contain no such record
#   A6  WHEN a citation is recorded it SHALL resolve to a specific upstream
#       artifact, and a citation naming only a version number or a bare project
#       name SHALL fail the check
#
# Everything here runs OFFLINE against committed files. The check never fetches.

# shellcheck source=currency_fixture.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/currency_fixture.sh"

tmp="$(mktemp_test_dir currency-cite)"

# ---------------------------------------------------------------------------------------------
# A1 / A3 - the SHIPPED reference layer: every record cited, and no fewer than 25 of them
# ---------------------------------------------------------------------------------------------
FIX_OUT="$(bash "$CURRENCY_CHECK" 2>&1)"; FIX_RC=$?

assert_eq "0" "$FIX_RC" "A1: the shipped reference layer passes the currency check"

records="$(printf '%s\n' "$FIX_OUT" | sed -n 's/^CURRENCY_RECORDS=//p' | head -n1)"
if [ -n "$records" ] && [ "$records" -ge 25 ] 2>/dev/null; then
    pass "A3: the check finds no fewer than 25 version-cliff records (found $records)"
else
    fail "A3: the check finds no fewer than 25 version-cliff records" "CURRENCY_RECORDS=$records
$FIX_OUT"
fi

assert_eq "0" "$(printf '%s\n' "$FIX_OUT" | sed -n 's/^CURRENCY_UNCITED=//p' | head -n1)" \
    "A3: zero shipped records are uncited"
assert_eq "0" "$(printf '%s\n' "$FIX_OUT" | sed -n 's/^CURRENCY_UNRESOLVABLE=//p' | head -n1)" \
    "A1: zero shipped citations fail to resolve to an upstream artifact"
assert_eq "0" "$(printf '%s\n' "$FIX_OUT" | sed -n 's/^CURRENCY_UNLEDGERED=//p' | head -n1)" \
    "A4: zero cliffs are asserted outside the ledger in the shipped tree"

# A1, at the source: every Source cell of both cliff tables actually holds a URL.
# The check is the enforcement; this is the independent read of the file itself, so
# a check that silently stopped matching Source cells cannot pass this too.
bad_cells=""
while IFS= read -r line; do
    case "$line" in
        '|'*'|') ;;
        *) continue ;;
    esac
    case "$line" in
        *'---'*) continue ;;
        '| Cliff |'*) continue ;;   # the two cliff tables' header row
        '| Key |'*) continue ;;     # the derived removed-key table's header row
    esac
    case "$line" in
        *'https://'*) ;;
        *) bad_cells+="$line"$'\n' ;;
    esac
done < <(awk '/^## Version cliffs that components branch on/,/^## Quick decision flow/' "$SHIPPED_LEDGER")
if [ -z "$bad_cells" ]; then
    pass "A1: every row of the shipped ledger tables carries an https citation"
else
    fail "A1: a shipped ledger row carries no https citation" "$bad_cells"
fi

# A5, on the shipped tree: the one record that admitted it could not be sourced
# ("kernel 6.8 ... rumored; couldn't verify primary source") is GONE, not parked.
if grep -q "couldn't verify primary source" "$SHIPPED_LEDGER"; then
    fail "A5: the shipped ledger still parks a record that admits it has no source" \
         "$(grep -n "couldn't verify primary source" "$SHIPPED_LEDGER")"
else
    pass "A5: no shipped record admits it could not name its upstream"
fi
if grep -qE '^\| \*\*kernel 6\.8\*\*' "$SHIPPED_LEDGER"; then
    fail "A5: the unsourceable 'kernel 6.8' row is still in the ledger"
else
    pass "A5: the unsourceable 'kernel 6.8' row is not in the ledger"
fi

# ---------------------------------------------------------------------------------------------
# A2 / A5 - an UNCITED record is named by file and by its own text, and fails the check
# ---------------------------------------------------------------------------------------------
d="$tmp/uncited"
fix_root "$d" \
    '| **0.56+** | The lua config is auto-generated on first start. | `install-config.sh`. |  |' \
    '| **0.54+** | `layerrule` moved to the block form. | `window-rules`. |  |'
fix_run "$d"

if [ "$FIX_RC" -ne 0 ]; then
    pass "A2: the check exits non-zero while the uncited list is non-empty (exit $FIX_RC)"
else
    fail "A2: the check exits non-zero while the uncited list is non-empty" "$FIX_OUT"
fi
assert_eq "2" "$(fix_count '^UNCITED=')" "A2: BOTH uncited records are reported, not just the first"
if fix_grep '^UNCITED=.*version-matrix\.md \| 0\.56\+ \|.*auto-generated'; then
    pass "A2: an uncited record is named by file AND by its own identifying text"
else
    fail "A2: an uncited record is named by file AND by its own identifying text" "$FIX_OUT"
fi
if fix_grep '^UNCITED=.*\| 0\.54\+ \|.*layerrule'; then
    pass "A2: the second uncited record is named the same way"
else
    fail "A2: the second uncited record is named the same way" "$FIX_OUT"
fi
if fix_grep '^CURRENCY=ok'; then
    fail "A5: a ledger with an unnameable upstream is NOT reported clean" "$FIX_OUT"
else
    pass "A5: a ledger with an unnameable upstream is not reported clean"
fi

# The same shape one level down: the derived removed-key table is a claim too.
d="$tmp/uncited-removed"
fix_root "$d"
sed -i 's#^| `misc:vfr` | 0.55 | `debug:vfr` |.*$#| `misc:vfr` | 0.55 | `debug:vfr` |  |#' \
    "$d/skills/rice/references/_shared/version-matrix.md"
fix_run "$d"
if [ "$FIX_RC" -ne 0 ] && fix_grep '^UNCITED=.*removed-key misc:vfr'; then
    pass "A2: an uncited removed-key row is reported and fails too"
else
    fail "A2: an uncited removed-key row is reported and fails too" "rc=$FIX_RC
$FIX_OUT"
fi

# ---------------------------------------------------------------------------------------------
# A6 - a citation must RESOLVE to a specific artifact
# ---------------------------------------------------------------------------------------------
# (a) a bare version number is not a citation
d="$tmp/bare-version"
fix_root "$d" '| **0.56+** | The lua config is auto-generated on first start. | `install-config.sh`. | v0.56.0 |'
fix_run "$d"
if [ "$FIX_RC" -ne 0 ] && fix_grep '^UNCITED=.*0\.56\+'; then
    pass "A6: a Source cell holding only a version number fails the check"
else
    fail "A6: a Source cell holding only a version number fails the check" "rc=$FIX_RC
$FIX_OUT"
fi

# (b) a bare project name / repository root is not an artifact
d="$tmp/bare-project"
fix_root "$d" '| **0.56+** | The lua config is auto-generated on first start. | `install-config.sh`. | [Hyprland](https://github.com/hyprwm/Hyprland) |'
fix_run "$d"
if [ "$FIX_RC" -ne 0 ] && fix_grep '^UNRESOLVABLE=.*0\.56\+.*not-an-artifact:https://github\.com/hyprwm/Hyprland'; then
    pass "A6: a citation naming only the project repository fails the check"
else
    fail "A6: a citation naming only the project repository fails the check" "rc=$FIX_RC
$FIX_OUT"
fi

# (c) a bare site root is not an artifact either
d="$tmp/bare-site"
fix_root "$d" '| **0.56+** | The lua config is auto-generated on first start. | `install-config.sh`. | [hypr.land](https://hypr.land/) |'
fix_run "$d"
if [ "$FIX_RC" -ne 0 ] && fix_grep '^UNRESOLVABLE=.*not-an-artifact:https://hypr\.land/'; then
    pass "A6: a citation naming only a site root fails the check"
else
    fail "A6: a citation naming only a site root fails the check" "rc=$FIX_RC
$FIX_OUT"
fi

# (d) the shapes that DO resolve: a release tag, a commit, a pull request, a wiki page.
d="$tmp/resolvable"
fix_root "$d" \
    '| **0.56+** | Release tag. | `x`. | [v0.56.0](https://github.com/hyprwm/Hyprland/releases/tag/v0.56.0) |' \
    '| **0.53+** | A commit. | `x`. | [commit](https://github.com/hyprwm/Hyprland/commit/7d1e481) |' \
    '| **0.54+** | A pull request. | `x`. | [PR #6608](https://github.com/hyprwm/Hyprland/pull/6608) |' \
    '| **0.51+** | A wiki page. | `x`. | [wiki](https://wiki.hypr.land/Configuring/Start/) |'
fix_run "$d"
assert_eq "0" "$FIX_RC" "A6: release tag, commit, pull request and wiki page all resolve"
assert_eq "0" "$(fix_count '^UNRESOLVABLE=')" "A6: none of the four resolvable shapes is reported"

# ---------------------------------------------------------------------------------------------
# A4 - the single-source rule: no component file may introduce a cliff the ledger lacks
# ---------------------------------------------------------------------------------------------
d="$tmp/unledgered"
fix_root "$d"
printf '# a component that invents a cliff\n\nOn 0.99+ the `foo` key is removed.\n' \
    > "$d/skills/rice/references/components/rogue.md"
fix_run "$d"
if [ "$FIX_RC" -ne 0 ]; then
    pass "A4: a cliff asserted outside the ledger fails the check (exit $FIX_RC)"
else
    fail "A4: a cliff asserted outside the ledger fails the check" "$FIX_OUT"
fi
if fix_grep '^UNLEDGERED_CLIFF=skills/rice/references/components/rogue\.md:3 \| 0\.99\+ \|.*foo'; then
    pass "A4: the assertion is reported by file, line, version and its own text"
else
    fail "A4: the assertion is reported by file, line, version and its own text" "$FIX_OUT"
fi

# A file that REFERENCES a recorded cliff is fine - that is the whole point of the rule.
d="$tmp/referenced"
fix_root "$d"
printf '# a component that references a RECORDED cliff\n\nOn 0.55+ emit `debug:vfr` instead.\n' \
    > "$d/skills/rice/references/components/fine.md"
fix_run "$d"
assert_eq "0" "$FIX_RC" "A4: referencing a cliff the ledger DOES record is not a defect"

# ... and three shapes that are deliberately not cliff assertions, so ordinary prose
# does not have to be rewritten to satisfy the rule.
d="$tmp/not-cliffs"
fix_root "$d"
printf '# prose that names versions without asserting a Hyprland cliff\n\n' > "$d/skills/rice/references/components/prose.md"
printf -- '- dunst 1.10+ rounds any subset of corners.\n' >> "$d/skills/rice/references/components/prose.md"
printf -- '- the blur subcategory is the modern form (0.40+), below our floor.\n' >> "$d/skills/rice/references/components/prose.md"
printf -- '- hyprpaper 0.8+ uses a wallpaper block.\n' >> "$d/skills/rice/references/components/prose.md"
fix_run "$d"
assert_eq "0" "$FIX_RC" "A4: another project's version, a sub-floor version and an external project's version are not cliff assertions"
assert_eq "0" "$(fix_count '^UNLEDGERED_CLIFF=')" "A4: none of the three is reported as an uncited cliff"

rm -rf "$tmp"

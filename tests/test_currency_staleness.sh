#!/usr/bin/env bash
# S0040-hyprland-config-currency-8 - STALENESS REPORTING (acceptance group B).
#
# Grades:
#   B1  WHEN a new Hyprland release ships THE SYSTEM SHALL have a repeatable check
#       that reports which reference claims are older than that release
#   B2  ... SHALL list every reference claim whose newest cited release is older
#       than it, naming the claim and the release it was last confirmed against
#   B3  WHEN the check runs with no network reachable it SHALL still produce its
#       full report from the release supplied to it, rather than failing or
#       reporting the reference layer clean
#   B4  IF the newest release is neither supplied nor readable from a committed
#       artifact THEN report that it could not be determined and exit non-zero,
#       and never report the reference layer current
#   B5  IF the check finds ZERO version-cliff records THEN exit non-zero
#   B6  IF a file the check is configured to scan is missing or unreadable THEN
#       name it and exit non-zero rather than skipping it silently
#   B7  WHEN CI runs it SHALL run the currency check, failing the build on an
#       uncited or unresolvable citation while reporting staleness without
#       failing the build on staleness alone

# shellcheck source=currency_fixture.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/currency_fixture.sh"

tmp="$(mktemp_test_dir currency-stale)"

# ---------------------------------------------------------------------------------------------
# B1 / B2 - a new release ships: which claims have not been confirmed against it?
# ---------------------------------------------------------------------------------------------
d="$tmp/stale"
fix_root "$d" \
    '| **0.54+** | `layerrule` moved to the block form. | `window-rules`. | [v0.54.0](https://github.com/hyprwm/Hyprland/releases/tag/v0.54.0) |' \
    '| **0.56+** | The lua config is auto-generated on first start. | `install-config.sh`. | [v0.56.0](https://github.com/hyprwm/Hyprland/releases/tag/v0.56.0) |'

# Nothing has shipped since 0.56.0: only the two older claims are behind it.
fix_run "$d" --newest-release 0.56.0
assert_eq "0" "$FIX_RC" "B1: staleness alone never fails the check"
assert_eq "2" "$(fix_count '^STALE=')" "B1: two claims are behind v0.56.0"
if fix_grep '^STALE=.*\| 0\.55\+ \|.*misc:vfr.*\| last confirmed against v0\.55\.0 \| newest is v0\.56\.0'; then
    pass "B2: a stale claim names itself AND the release it was last confirmed against"
else
    fail "B2: a stale claim names itself AND the release it was last confirmed against" "$FIX_OUT"
fi
if fix_grep '^STALE=.*\| 0\.56\+ \|'; then
    fail "B2: a claim confirmed against the newest release is NOT reported stale" "$FIX_OUT"
else
    pass "B2: a claim confirmed against the newest release is not reported stale"
fi

# Now upstream ships 0.56.2. The SAME ledger, a newer input, one more stale claim -
# which is the whole "repeatable check" property B1 asks for.
fix_run "$d" --newest-release 0.56.2
assert_eq "3" "$(fix_count '^STALE=')" "B1: a newer release moves one more claim into the report"
if fix_grep '^STALE=.*\| 0\.56\+ \|.*last confirmed against v0\.56\.0 \| newest is v0\.56\.2'; then
    pass "B1: the claim that was current at v0.56.0 is reported once v0.56.2 ships"
else
    fail "B1: the claim that was current at v0.56.0 is reported once v0.56.2 ships" "$FIX_OUT"
fi
assert_eq "0" "$FIX_RC" "B1: and the build still passes on staleness alone"

# The shipped reference layer, against the release the ledger itself records.
FIX_OUT="$(bash "$CURRENCY_CHECK" 2>&1)"; FIX_RC=$?
stale_n="$(printf '%s\n' "$FIX_OUT" | sed -n 's/^CURRENCY_STALE=//p' | head -n1)"
if [ -n "$stale_n" ] && [ "$stale_n" -gt 0 ] 2>/dev/null; then
    pass "B2: the shipped reference layer reports $stale_n claim(s) behind the newest release"
else
    fail "B2: the shipped reference layer reports its stale claims" "CURRENCY_STALE=$stale_n
$FIX_OUT"
fi
assert_eq "0" "$FIX_RC" "B1: and the shipped tree still exits 0 with those reports"

# Prose that asserts which release is newest is a claim too. This is the exact shape
# `deprecations.md` carried for four releases with nothing in the repo to catch it.
d="$tmp/prose"
fix_root "$d"
printf '# stale prose\n\nHyprland 0.55 (latest stable upstream; this machine runs 0.54.3).\n' \
    > "$d/skills/hyprland-reference/references/deprecations.md"
fix_run "$d" --newest-release 0.56.2
if fix_grep '^STALE_CLAIM=skills/hyprland-reference/references/deprecations\.md:3 \| names v0\.55 \| newest is v0\.56\.2'; then
    pass "B2: prose claiming an older release is the latest is reported, by file and line"
else
    fail "B2: prose claiming an older release is the latest is reported, by file and line" "$FIX_OUT"
fi
assert_eq "0" "$FIX_RC" "B2: and that report does not fail the build either"

# ---------------------------------------------------------------------------------------------
# B3 - no network reachable: the full report still comes out of the supplied release
# ---------------------------------------------------------------------------------------------
# Static half: nothing in the currency path can reach the network at all.
netref=""
for s in version-ledger.sh currency-check.sh validate-removed-keys.sh; do
    hit="$(grep -nE '\b(curl|wget|nc|ping|ssh|scp|nslookup|dig|http_proxy)\b' \
           "$PLUGIN_ROOT/skills/rice/scripts/$s" || true)"
    [ -n "$hit" ] && netref+="$s: $hit"$'\n'
done
if [ -z "$netref" ]; then
    pass "B3: no script in the currency path names a network client"
else
    fail "B3: a script in the currency path names a network client" "$netref"
fi

# Dynamic half: put SABOTAGE clients on PATH ahead of everything. If the check
# reached for one, it would get a loud failure instead of an answer.
sabotage="$tmp/sabotage"; mkdir -p "$sabotage"
for bin in curl wget nc ping getent host dig; do
    printf '#!/usr/bin/env bash\necho "SABOTAGE: %s was invoked" >&2\nexit 99\n' "$bin" > "$sabotage/$bin"
    chmod +x "$sabotage/$bin"
done
d="$tmp/offline"
fix_root "$d" \
    '| **0.54+** | `layerrule` moved to the block form. | `window-rules`. | [v0.54.0](https://github.com/hyprwm/Hyprland/releases/tag/v0.54.0) |'
online="$(bash "$CURRENCY_CHECK" --root "$d" --newest-release 0.56.2 2>&1)"; orc=$?
offline="$(PATH="$sabotage:$PATH" http_proxy=http://127.0.0.1:1 https_proxy=http://127.0.0.1:1 \
           bash "$CURRENCY_CHECK" --root "$d" --newest-release 0.56.2 2>&1)"; frc=$?
assert_eq "$orc" "$frc" "B3: the exit code is identical with every network client sabotaged"
assert_eq "$online" "$offline" "B3: the full report is byte-identical with no network reachable"
if printf '%s\n' "$offline" | grep -q 'SABOTAGE'; then
    fail "B3: the check invoked a network client" "$offline"
else
    pass "B3: no network client was invoked"
fi
if printf '%s\n' "$offline" | grep -qc '^STALE=' >/dev/null && \
   [ "$(printf '%s\n' "$offline" | grep -c '^STALE=')" -eq 2 ]; then
    pass "B3: offline, it still produces the staleness report rather than reporting the layer clean"
else
    fail "B3: offline, it still produces the staleness report" "$offline"
fi

# ---------------------------------------------------------------------------------------------
# B4 - the newest release is neither supplied nor readable: REFUSE, never "current"
# ---------------------------------------------------------------------------------------------
d="$tmp/no-newest"
fix_root "$d"
ledger="$d/skills/rice/references/_shared/version-matrix.md"
sed -i '/^| `newest-release` |/d' "$ledger"
fix_run "$d"
if [ "$FIX_RC" -ne 0 ]; then
    pass "B4: an undeterminable newest release exits non-zero (exit $FIX_RC)"
else
    fail "B4: an undeterminable newest release exits non-zero" "$FIX_OUT"
fi
if fix_has "CURRENCY_NEWEST_RELEASE=unknown" && fix_has "CURRENCY=undetermined-newest-release"; then
    pass "B4: it says it could not determine the newest release"
else
    fail "B4: it says it could not determine the newest release" "$FIX_OUT"
fi
if fix_grep '^CURRENCY=ok'; then
    fail "B4: it must NOT report the reference layer current" "$FIX_OUT"
else
    pass "B4: it does not report the reference layer current"
fi
# ... and supplying the release on the command line is the way through.
fix_run "$d" --newest-release 0.56.2
assert_eq "0" "$FIX_RC" "B4: supplying the release on the command line resolves it"
assert_eq "supplied" "$(printf '%s\n' "$FIX_OUT" | sed -n 's/^CURRENCY_NEWEST_RELEASE_SOURCE=//p')" \
    "B4: the report says where the newest release came from"

# The committed artifact is the other route, and the shipped repo uses it.
FIX_OUT="$(bash "$CURRENCY_CHECK" 2>&1)"
assert_eq "ledger" "$(printf '%s\n' "$FIX_OUT" | sed -n 's/^CURRENCY_NEWEST_RELEASE_SOURCE=//p')" \
    "B4: with nothing supplied, the newest release is read from a committed artifact"

# ---------------------------------------------------------------------------------------------
# B5 - zero records matched is a FAILURE, never a clean pass
# ---------------------------------------------------------------------------------------------
d="$tmp/no-records"
fix_root "$d"
ledger="$d/skills/rice/references/_shared/version-matrix.md"
sed -i -e '/^| \*\*0\.55+\*\* |/d' -e '/^| \*\*hyprpaper 0\.8\.0\*\* |/d' "$ledger"
fix_run "$d"
if [ "$FIX_RC" -ne 0 ]; then
    pass "B5: a ledger matching zero version-cliff records exits non-zero (exit $FIX_RC)"
else
    fail "B5: a ledger matching zero version-cliff records exits non-zero" "$FIX_OUT"
fi
assert_eq "0" "$(printf '%s\n' "$FIX_OUT" | sed -n 's/^CURRENCY_RECORDS=//p')" \
    "B5: it reports the zero it found rather than staying quiet"
if fix_has "CURRENCY=no-records"; then
    pass "B5: the verdict names the reason"
else
    fail "B5: the verdict names the reason" "$FIX_OUT"
fi
if fix_grep '^CURRENCY=ok'; then
    fail "B5: a check that has stopped matching anything must not read as a clean pass" "$FIX_OUT"
else
    pass "B5: a check that has stopped matching anything does not read as a clean pass"
fi

# ---------------------------------------------------------------------------------------------
# B6 - a configured file or directory that cannot be read is NAMED, never skipped
# ---------------------------------------------------------------------------------------------
# (a) a configured scan directory has gone missing
d="$tmp/missing-dir"
fix_root "$d"
rm -rf "$d/skills/hyprland-reference/references"
fix_run "$d"
if [ "$FIX_RC" -ne 0 ] && fix_grep '^UNREADABLE=.*skills/hyprland-reference/references'; then
    pass "B6: a missing configured scan directory is named and fails the check"
else
    fail "B6: a missing configured scan directory is named and fails the check" "rc=$FIX_RC
$FIX_OUT"
fi

# (b) the ledger itself is gone
d="$tmp/missing-ledger"
fix_root "$d"
rm -f "$d/skills/rice/references/_shared/version-matrix.md"
fix_run "$d"
if [ "$FIX_RC" -ne 0 ] && fix_grep '^UNREADABLE=.*version-matrix\.md'; then
    pass "B6: a missing ledger is named and fails the check"
else
    fail "B6: a missing ledger is named and fails the check" "rc=$FIX_RC
$FIX_OUT"
fi

# (c) a scanned file that exists but cannot be read
d="$tmp/unreadable-file"
fix_root "$d"
unreadable="$d/skills/rice/references/components/locked.md"
printf '# locked\n' > "$unreadable"
chmod 000 "$unreadable"
if [ "$(id -u)" -eq 0 ] || [ -r "$unreadable" ]; then
    skip "B6: an unreadable scanned file is named and fails the check" "running as root; mode 000 is still readable"
else
    fix_run "$d"
    if [ "$FIX_RC" -ne 0 ] && fix_grep '^UNREADABLE=.*locked\.md'; then
        pass "B6: an unreadable scanned file is named and fails the check"
    else
        fail "B6: an unreadable scanned file is named and fails the check" "rc=$FIX_RC
$FIX_OUT"
    fi
fi
chmod 644 "$unreadable"

# ---------------------------------------------------------------------------------------------
# B7 - CI runs it, and gets the two behaviours the criterion separates
# ---------------------------------------------------------------------------------------------
wf="$PLUGIN_ROOT/.github/workflows/tests.yml"
assert_file_contains "$wf" "skills/rice/scripts/currency-check.sh" \
    "B7: CI runs the currency check on every push and pull request"
assert_file_contains "$wf" "bash tests/run.sh" \
    "B7: CI also runs the suite, which discovers the three currency test files"
if grep -qE '^\s*(push|pull_request):' "$wf"; then
    pass "B7: the workflow carrying it is triggered by push and pull_request"
else
    fail "B7: the workflow carrying it is triggered by push and pull_request" "$(sed -n '1,12p' "$wf")"
fi
# tests/run.sh discovers `test_*.sh` at depth 1: the three graded files are all there.
for t in test_currency_citations.sh test_currency_staleness.sh test_currency_removed_keys.sh; do
    assert_file_exists "$PLUGIN_ROOT/tests/$t" "B7: $t is discoverable by tests/run.sh"
done

# The build FAILS on an uncited or unresolvable citation ...
d="$tmp/ci-citation"
fix_root "$d" '| **0.56+** | An uncited record. | `x`. |  |'
fix_run "$d"
if [ "$FIX_RC" -ne 0 ] && fix_has "CURRENCY=defects"; then
    pass "B7: an uncited citation fails the build"
else
    fail "B7: an uncited citation fails the build" "rc=$FIX_RC
$FIX_OUT"
fi
d="$tmp/ci-unresolvable"
fix_root "$d" '| **0.56+** | A citation that names a project, not an artifact. | `x`. | [Hyprland](https://github.com/hyprwm/Hyprland) |'
fix_run "$d"
if [ "$FIX_RC" -ne 0 ] && fix_has "CURRENCY=defects"; then
    pass "B7: an unresolvable citation fails the build"
else
    fail "B7: an unresolvable citation fails the build" "rc=$FIX_RC
$FIX_OUT"
fi

# ... and does NOT fail on staleness alone, however far behind the layer is.
d="$tmp/ci-stale-only"
fix_root "$d"
fix_run "$d" --newest-release 9.99.9
assert_eq "0" "$FIX_RC" "B7: staleness alone does not fail the build"
if [ "$(fix_count '^STALE=')" -gt 0 ]; then
    pass "B7: and the staleness is still reported while the build passes"
else
    fail "B7: and the staleness is still reported while the build passes" "$FIX_OUT"
fi

rm -rf "$tmp"

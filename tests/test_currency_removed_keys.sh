#!/usr/bin/env bash
# S0040-hyprland-config-currency-8 - GENERATION-TIME VALIDATION (acceptance group C).
#
# Grades:
#   C1  WHEN a config is generated for a detected version THE SYSTEM SHALL emit only
#       keys valid at that version and SHALL fail its own validation if it emits one
#       documented as removed - naming the key, the file and the version that removed
#       it, and never reporting the generation successful
#   C2  WHEN generation-time validation fails THE SYSTEM SHALL install nothing and
#       leave the resolved config directory BYTE-IDENTICAL
#   C3  WHEN it runs on a host with no Hyprland binary and no running compositor it
#       SHALL still reach a verdict, distinct from and independent of the existing
#       uncheckable-preflight outcome
#   C4  IF the target version cannot be determined THEN it SHALL NOT report a pass,
#       and SHALL say the target is unknown rather than assuming one
#   C5  WHEN a key is still valid at the target THE SYSTEM SHALL pass it
#   C6  WHEN the shipped baseline is generated for every version the plugin claims to
#       support it SHALL pass removed-key validation for each of them

RS="$PLUGIN_ROOT/skills/rice/scripts"
VRK="$RS/validate-removed-keys.sh"
tmp="$(mktemp_test_dir currency-rk)"

nobin="$tmp/nobin"; mkdir -p "$nobin"
NOBIN_PATH="$nobin:/usr/bin:/bin"
have_real_hypr=0
if PATH="/usr/bin:/bin" command -v Hyprland >/dev/null 2>&1 \
   || PATH="/usr/bin:/bin" command -v hyprctl >/dev/null 2>&1; then
    have_real_hypr=1
fi

# `fingerprint <dir>` / `siblings <dir>` - the same byte-level snapshot the preflight
# suite uses. Two equal fingerprints mean the refusal really changed nothing.
fingerprint() {
    local d="$1"
    [ -d "$d" ] || { echo "ABSENT"; return; }
    ( cd "$d" && find . -mindepth 1 -printf '%y %m %p\n' | sort
      find . -type f -exec sha256sum {} \; 2>/dev/null | sort )
}
siblings() { ( cd "$(dirname "$1")" && ls -A | sort ); }
outcome() { printf '%s\n' "$1" | grep -oE '^SAFE_APPLY=[a-z-]+' | sed 's/^SAFE_APPLY=//'; }

# The shipped sample config is the honest fixture for the whole group: it declares
# "Target version: 0.54.x" and carries `dwindle { pseudotile = true }`, which is
# valid there and a hard parse error from 0.55. Nothing here is invented.
sample="$tmp/sample"; mkdir -p "$sample"
cp "$PLUGIN_ROOT"/skills/rice/examples/sample-config/*.conf "$sample/"

# ---------------------------------------------------------------------------------------------
# C5 - version-aware, not a blanket ban: the key PASSES at a target where it is valid
# ---------------------------------------------------------------------------------------------
out="$(bash "$VRK" "$sample" --version 0.54.3 2>&1)"; rc=$?
assert_eq "0" "$rc" "C5: a key still valid at the target passes (dwindle:pseudotile on 0.54.3)"
if printf '%s\n' "$out" | grep -q '^REMOVED_KEYS=ok'; then
    pass "C5: the verdict is ok, not a blanket ban on every key any release removed"
else
    fail "C5: the verdict is ok" "$out"
fi
if printf '%s\n' "$out" | grep -q '^REMOVED_KEY='; then
    fail "C5: nothing is reported against a valid target" "$out"
else
    pass "C5: nothing is reported against a valid target"
fi

# ---------------------------------------------------------------------------------------------
# C1 - the same config, one release later: fail, and name key, file and removing release
# ---------------------------------------------------------------------------------------------
out="$(bash "$VRK" "$sample" --version 0.55.0 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
    pass "C1: a removed key fails the validation (exit $rc)"
else
    fail "C1: a removed key fails the validation" "$out"
fi
if printf '%s\n' "$out" | grep -qE '^REMOVED_KEY=dwindle:pseudotile \| .*/looknfeel\.conf:[0-9]+ \| removed at 0\.55'; then
    pass "C1: the report names the KEY, the FILE and line, and the VERSION that removed it"
else
    fail "C1: the report names the key, the file and the removing version" "$out"
fi
if printf '%s\n' "$out" | grep -qE '^REMOVED_KEYS=(ok|found)'; then
    assert_eq "found" "$(printf '%s\n' "$out" | sed -n 's/^REMOVED_KEYS=\([a-z-]*\).*/\1/p' | head -n1)" \
        "C1: the generation is NOT reported successful"
else
    fail "C1: the verdict line is present" "$out"
fi

# A lua config is checked the same way - the removed-key set is a key space, not a syntax.
lua="$tmp/lua"; mkdir -p "$lua"
printf 'hl.config({\n    misc = {\n        vfr = true,\n    },\n})\n' > "$lua/hyprland.lua"
out="$(bash "$VRK" "$lua" --version 0.56.2 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -qE '^REMOVED_KEY=misc:vfr \| .*/hyprland\.lua:3 \| removed at 0\.55'; then
    pass "C1: a removed key nested in a lua config is found and named the same way"
else
    fail "C1: a removed key nested in a lua config is found and named the same way" "rc=$rc
$out"
fi

# ---------------------------------------------------------------------------------------------
# C4 - the target cannot be determined: say so, and never claim a pass
# ---------------------------------------------------------------------------------------------
if [ "$have_real_hypr" -eq 1 ]; then
    skip "C4: an undeterminable target version is not a pass" "a real Hyprland is installed on this host"
    skip "C4: it says the target version is unknown"          "a real Hyprland is installed on this host"
    skip "C4: it does not assume a target"                    "a real Hyprland is installed on this host"
else
    out="$(env -u HYPR_VERSION PATH="$NOBIN_PATH" bash "$VRK" "$sample" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        pass "C4: an undeterminable target version is not a pass (exit $rc)"
    else
        fail "C4: an undeterminable target version is not a pass" "$out"
    fi
    if printf '%s\n' "$out" | grep -q '^REMOVED_KEYS=unknown-target-version' \
       && printf '%s\n' "$out" | grep -q '^REMOVED_KEYS_TARGET=unknown'; then
        pass "C4: it says the target version is unknown"
    else
        fail "C4: it says the target version is unknown" "$out"
    fi
    if printf '%s\n' "$out" | grep -qE '^REMOVED_KEYS=ok|^REMOVED_KEYS_TARGET=[0-9]'; then
        fail "C4: it must not assume a target or report a pass it did not perform" "$out"
    else
        pass "C4: it does not assume a target"
    fi
fi

# ---------------------------------------------------------------------------------------------
# C3 - no Hyprland binary, no running compositor: a verdict is still REACHED
# ---------------------------------------------------------------------------------------------
if [ "$have_real_hypr" -eq 1 ]; then
    skip "C3: a verdict is reached with no compositor available" "a real Hyprland is installed on this host"
else
    out="$(PATH="$NOBIN_PATH" bash "$VRK" "$sample" --version 0.55.0 2>&1)"; rc=$?
    if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q '^REMOVED_KEYS=found'; then
        pass "C3: a verdict is reached with no Hyprland binary and no running compositor"
    else
        fail "C3: a verdict is reached with no compositor available" "rc=$rc
$out"
    fi
    # The compositor-backed nets can only shrug on the same host, which is the point:
    # this check is the one that still answers.
    pf="$(PATH="$NOBIN_PATH" bash "$RS/preflight-config.sh" "$sample" 2>&1)"; pfrc=$?
    if [ "$pfrc" -eq 2 ] && printf '%s\n' "$pf" | grep -q '^PREFLIGHT=unverified'; then
        pass "C3: the compositor's own offline check can only say 'unverified' on that host"
    else
        fail "C3: the compositor's own offline check can only say 'unverified' on that host" "rc=$pfrc
$pf"
    fi
fi

# The outcome word is DISTINCT from both preflight outcomes, in the script's own docs
# and in a real run.
doc="$(sed -n 's/^#[[:space:]]*SAFE_APPLY=\([a-z-]*\).*/\1/p' "$RS/safe-apply.sh")"
for w in removed-keys-failed preflight-failed preflight-uncheckable; do
    if printf '%s\n' "$doc" | grep -qxF "$w"; then
        pass "C3: safe-apply documents the distinct outcome '$w'"
    else
        fail "C3: safe-apply documents the distinct outcome '$w'" "$doc"
    fi
done
dupes="$(printf '%s\n' "$doc" | sort | uniq -d)"
if [ -z "$dupes" ]; then
    pass "C3: every documented SAFE_APPLY outcome word is still distinct"
else
    fail "C3: every documented SAFE_APPLY outcome word is still distinct" "$dupes"
fi

# ---------------------------------------------------------------------------------------------
# C1 + C2 - through the whole apply flow: refuse, install nothing, change nothing
# ---------------------------------------------------------------------------------------------
target="$tmp/target"; mkdir -p "$target"
printf 'SENTINEL - the user config nobody may touch\n' > "$target/hyprland.conf"
printf 'monitor = , preferred, auto, 1\n' > "$target/monitors.conf"
before="$(fingerprint "$target")"; before_sib="$(siblings "$target")"

out="$(PATH="$NOBIN_PATH" HYPR_VERSION=0.55.0 HYPR_DIR="$target" \
       bash "$RS/safe-apply.sh" "$sample" 2>&1)"; rc=$?

assert_eq "removed-keys-failed" "$(outcome "$out")" \
    "C1: safe-apply refuses with its own outcome word"
if [ "$rc" -ne 0 ]; then
    pass "C1: safe-apply exits non-zero when the staged config carries a removed key"
else
    fail "C1: safe-apply exits non-zero when the staged config carries a removed key" "rc=0
$out"
fi
if printf '%s\n' "$out" | grep -q '^REMOVED_KEY=dwindle:pseudotile'; then
    pass "C1: the apply output names the offending key"
else
    fail "C1: the apply output names the offending key" "$out"
fi
assert_eq "$before" "$(fingerprint "$target")" \
    "C2: the resolved config directory is BYTE-IDENTICAL after the refusal"
assert_eq "$before_sib" "$(siblings "$target")" \
    "C2: no backup was taken for a run that refused"
if printf '%s\n' "$out" | grep -qE '^(INSTALLED=|BACKUP=|DONE=ok|SAFE_APPLY=ok)'; then
    fail "C2: nothing was installed" "$out"
else
    pass "C2: nothing was installed (no INSTALLED=/BACKUP=/DONE=ok/SAFE_APPLY=ok lines)"
fi
if [ "$(printf '%s\n' "$out" | grep -c '^SAFE_APPLY=')" -eq 1 ]; then
    pass "C1: the refusal ends with exactly one terminal outcome line"
else
    fail "C1: the refusal ends with exactly one terminal outcome line" "$out"
fi

# The mirror case: the SAME staged set, a target where the key is valid, and the apply
# is no longer blocked by this check. A validation that wrongly refuses locks a user
# out of their own config, so this direction matters as much as the refusal.
t2="$tmp/target-054"; mkdir -p "$t2"
printf 'OLD\n' > "$t2/hyprland.conf"
out="$(PATH="$NOBIN_PATH" HYPR_VERSION=0.54.3 HYPR_DIR="$t2" \
       bash "$RS/safe-apply.sh" "$sample" 2>&1)"
if [ "$(outcome "$out")" != "removed-keys-failed" ] \
   && printf '%s\n' "$out" | grep -q '^REMOVED_KEYS=ok'; then
    pass "C5: the same staged set applies for a target where the key is valid"
else
    fail "C5: the same staged set applies for a target where the key is valid" "$out"
fi

# ---------------------------------------------------------------------------------------------
# C6 - the shipped baseline, for EVERY version the plugin claims to support
# ---------------------------------------------------------------------------------------------
mapfile -t targets < <(bash "$VRK" --supported-targets)
if [ "${#targets[@]}" -ge 2 ]; then
    pass "C6: the supported targets are enumerated from the ledger (${targets[*]})"
else
    fail "C6: the supported targets are enumerated from the ledger" "${targets[*]-none}"
fi
# The list must actually span the ledger's floor to its newest release, or "every
# version the plugin claims to support" is whatever the list happens to hold.
if [ "${targets[0]}" = "0.50.0" ] && [ "${targets[${#targets[@]}-1]}" = "0.56.2" ]; then
    pass "C6: the list runs from the ledger's support floor to its newest release"
else
    fail "C6: the list runs from the ledger's support floor to its newest release" "${targets[*]}"
fi

bad=""
for t in "${targets[@]}"; do
    st="$tmp/emit-$t"
    eo="$(HYPR_VERSION="$t" bash "$RS/emit-config.sh" "$st" 2>&1)"; erc=$?
    if [ "$erc" -ne 0 ]; then
        bad+="$t: emit-config.sh exited $erc"$'\n'"$eo"$'\n'
        continue
    fi
    vo="$(bash "$VRK" "$st" --version "$t" 2>&1)"; vrc=$?
    if [ "$vrc" -ne 0 ]; then
        bad+="$t: validate-removed-keys.sh exited $vrc"$'\n'"$vo"$'\n'
    fi
done
if [ -z "$bad" ]; then
    pass "C6: the shipped baseline passes removed-key validation for all ${#targets[@]} supported targets"
else
    fail "C6: the shipped baseline passes removed-key validation for every supported target" "$bad"
fi

# The removed-key set is DERIVED from the ledger the currency check reads, not a
# second copy that can drift away from it.
rules="$(bash "$VRK" "$sample" --version 0.54.3 2>&1 | sed -n 's/^REMOVED_KEYS_RULES=//p')"
if [ -n "$rules" ] && [ "$rules" -gt 0 ] 2>/dev/null; then
    pass "C6: the validator reads $rules removed-key rule(s) out of the version-cliff ledger"
else
    fail "C6: the validator reads its rules out of the version-cliff ledger" "REMOVED_KEYS_RULES=$rules"
fi
assert_eq "$PLUGIN_ROOT/skills/rice/references/_shared/version-matrix.md" \
    "$(bash "$VRK" "$sample" --version 0.54.3 2>&1 | sed -n 's/^REMOVED_KEYS_LEDGER=//p')" \
    "C6: and the ledger it reads is the one the currency check enforces"

# A ledger with no rules is uncheckable, never a pass: a validator that has lost its
# rules would otherwise wave every config through.
empty="$tmp/empty-ledger.md"
awk '/^## /{ inr = ($0 ~ /^## Removed keys/) }
     inr && /^\|/ && $0 !~ /^\| Key \|/ && $0 !~ /^\|-/ { next }
     { print }' \
    "$PLUGIN_ROOT/skills/rice/references/_shared/version-matrix.md" > "$empty"
out="$(bash "$VRK" "$sample" --version 0.55.0 --ledger "$empty" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q '^REMOVED_KEYS=uncheckable'; then
    pass "C6: a ledger declaring zero removed keys is uncheckable, not a pass"
else
    fail "C6: a ledger declaring zero removed keys is uncheckable, not a pass" "rc=$rc
$out"
fi

rm -rf "$tmp"

#!/usr/bin/env bash
# Integration test: build an Arch+Hyprland container, mount the plugin into it, start Hyprland
# headlessly, run safe-apply.sh against a known-good staging config, and assert the live
# `hyprctl reload` + `configerrors` checks pass AND the Hyprland log has no ERR/CRITICAL lines.
#
# This is expensive — the image build is several minutes and ~1 GB the first time. The test
# **skips** by default unless either:
#   - the image `hyprland-config-test` already exists locally, or
#   - the env var RUN_INTEGRATION=1 is set (CI sets this; locally it's opt-in).
# Set RUN_INTEGRATION_REBUILD=1 to force a rebuild even when the image is cached.

if ! command -v docker >/dev/null 2>&1; then
    skip "integration: docker missing" "docker not installed"
    return 0
fi

image="hyprland-config-test"

# Decide whether to run. Image cached → run. RUN_INTEGRATION=1 → build + run. Otherwise → skip.
have_image=0
if docker image inspect "$image" >/dev/null 2>&1; then
    have_image=1
fi
if [ "$have_image" -eq 0 ] && [ -z "${RUN_INTEGRATION:-}" ]; then
    skip "integration: docker image not built" "set RUN_INTEGRATION=1 to build + run (slow)"
    return 0
fi

# Build (or rebuild if forced). Output goes to a captured log so a failure surfaces cleanly.
if [ "$have_image" -eq 0 ] || [ -n "${RUN_INTEGRATION_REBUILD:-}" ]; then
    build_log="$(mktemp -t hypr-integration-build.XXXXXX.log)"
    if docker build -t "$image" "$PLUGIN_ROOT/tests/integration" >"$build_log" 2>&1; then
        pass "docker image builds"
    else
        fail "docker image builds" "$(tail -n 80 "$build_log")"
        rm -f "$build_log"
        return 0
    fi
    rm -f "$build_log"
else
    pass "docker image already cached"
fi

# Run the in-container test. The plugin is mounted read-only so the container can't accidentally
# modify the repo. tmpfs for /tmp keeps cleanup tidy.
run_log="$(mktemp -t hypr-integration-run.XXXXXX.log)"

# --tmpfs is fine; --privileged is intentionally NOT used — the wlroots headless backend works
# without it, and avoiding it is the point.
docker run --rm \
    -v "$PLUGIN_ROOT:/plugin:ro" \
    -v "$PLUGIN_ROOT/tests/integration/run-in-container.sh:/home/tester/run.sh:ro" \
    --tmpfs /tmp:exec,mode=1777 \
    "$image" \
    bash /home/tester/run.sh \
    >"$run_log" 2>&1
rc=$?

# Always show the container's last-50 output on completion so the log monitoring the user asked
# for actually surfaces.
{
    echo
    echo "  ── container stdout (tail) ──"
    tail -n 50 "$run_log" | sed 's/^/    /'
    echo "  ── end container stdout ──"
} >&2

# ---------------------------------------------------------------------------------------------
# S0028 AC-4 - the offline check, and the NEGATIVE CONTROL that keeps it honest.
#
# Asserted FIRST and unconditionally: the container prints this block before it tries to
# start Hyprland, so it reports in both the live and the parse-only mode, and it is exactly
# the evidence the roadmap's open question asks for (does `--verify-config` complete with no
# session and no /dev/dri?).
# ---------------------------------------------------------------------------------------------
marker_value() { sed -n "s/^$1=//p" "$run_log" | tail -n1; }

if grep -q '^OFFLINE_CHECK=done' "$run_log"; then
    pass "offline check ran inside the container"
else
    fail "offline check ran inside the container" "no OFFLINE_CHECK=done marker; see $run_log"
fi

# The contract, re-derived every run rather than trusted:
#   a clean config           -> exit 0, and it really parsed (marker present)
#   a broken config          -> exit 1, and it really parsed (marker present)
#   a rejected invocation    -> exit 1, and it did NOT parse (marker absent)
# The third row is the whole reason exit status alone cannot be the verdict.
assert_eq "0"   "$(marker_value OFFLINE_CONTRACT_CLEAN_RC)"      "AC-4: --verify-config exits 0 on a clean config, with no session and no /dev/dri"
assert_eq "yes" "$(marker_value OFFLINE_CONTRACT_CLEAN_MARKER)"  "AC-4: a clean config really reached the parser"
assert_eq "1"   "$(marker_value OFFLINE_CONTRACT_BROKEN_RC)"     "AC-4: --verify-config exits 1 on a broken config"
assert_eq "yes" "$(marker_value OFFLINE_CONTRACT_BROKEN_MARKER)" "AC-4: a broken config really reached the parser"
assert_eq "1"   "$(marker_value OFFLINE_CONTRACT_REJECT_RC)"     "AC-4: a rejected invocation also exits 1 (why exit status alone cannot be the verdict)"
assert_eq "no"  "$(marker_value OFFLINE_CONTRACT_REJECT_MARKER)" "AC-4: a rejected invocation never reaches the parser (the discriminator holds)"

# The property the preflight's sandbox rests on, measured against the real binary.
assert_eq "1"   "$(marker_value OFFLINE_CONTRACT_SOURCE_RC)" \
    'AC-4: an error in a sourced companion fails the offline check'
assert_eq "yes" "$(marker_value OFFLINE_CONTRACT_SOURCE_NAMES_COMPANION)" \
    'AC-4: ~ in a source= line expands from $HOME and the companion is named (the sandbox premise)'

assert_eq "ok" "$(marker_value OFFLINE_CHECK_GOOD)" \
    "AC-4: the plugin's preflight passes the known-good generated config"

# THE negative control. If a deliberately broken generated config is reported clean, the
# preflight is worthless and this build must go red.
bad_verdict="$(marker_value OFFLINE_CHECK_BAD)"
case "$bad_verdict" in
    errors)
        pass "AC-4: a deliberately broken generated config is reported as errors" ;;
    ok)
        fail "AC-4: a deliberately broken generated config was reported CLEAN" \
             "OFFLINE_CHECK_BAD=ok - the offline check is not checking anything. See $run_log" ;;
    *)
        fail "AC-4: a deliberately broken generated config is reported as errors" \
             "OFFLINE_CHECK_BAD=${bad_verdict:-<missing>}; see $run_log" ;;
esac
assert_eq "yes" "$(marker_value OFFLINE_CHECK_BAD_NAMES_STAGED)" \
    "AC-4: the error is surfaced against the staged companion that carries it"

assert_eq "preflight-failed" "$(marker_value PREFLIGHT_REFUSED_INSTALL)" \
    "AC-4: safe-apply refuses the broken config with its own outcome word"
assert_eq "yes" "$(marker_value PREFLIGHT_TARGET_UNCHANGED)" \
    "AC-4: the refused apply left the target byte-identical"

# Two possible success modes the container reports via INTEGRATION_PHASE:
#   "config-parse-ok-backend-cannot-init-on-ci" — Hyprland's parser accepted the config,
#       backend then failed (CI has no /dev/dri). Live `hyprctl reload` is unreachable here.
#   anything else, ending in INTEGRATION=ok — Hyprland came up and safe-apply.sh ran.
parse_only_mode=0
if grep -q '^INTEGRATION_PHASE=config-parse-ok-backend-cannot-init-on-ci' "$run_log"; then
    parse_only_mode=1
fi

if [ "$rc" -eq 0 ] && grep -q '^INTEGRATION=ok' "$run_log"; then
    if [ "$parse_only_mode" -eq 1 ]; then
        pass "Hyprland parse-only mode: config accepted by Hyprland's own parser (no /dev/dri on CI)"
    else
        pass "Hyprland live mode: SAFE_APPLY=ok, configerrors empty, no log ERR/CRITICAL"
    fi
else
    fail "Hyprland headless integration" "container exit $rc; see full log at $run_log"
    return 0
fi

# The remaining cross-checks only apply when Hyprland actually came up. In parse-only mode
# safe-apply / configerrors / live log don't exist.
if [ "$parse_only_mode" -eq 1 ]; then
    skip "safe-apply.sh reports SAFE_APPLY=ok" "parse-only mode (no live Hyprland on CI)"
    skip "hyprctl configerrors is empty"        "parse-only mode (no live Hyprland on CI)"
    skip "Hyprland log has no ERR/CRITICAL lines" "parse-only mode (backend init errors are expected here)"
else
    # Confirm the safe-apply verdict line landed.
    if grep -q '^SAFE_APPLY=ok' "$run_log"; then
        pass "safe-apply.sh reports SAFE_APPLY=ok"
    else
        fail "safe-apply.sh reports SAFE_APPLY=ok" "$(grep -E '^SAFE_APPLY=|^VERIFY=|^INSTALLED=' "$run_log")"
    fi
    # Confirm hyprctl configerrors was empty.
    if grep -q '^----- hyprctl configerrors -----$' "$run_log" \
       && [ "$(awk '/^----- hyprctl configerrors -----$/{f=1;next} /^-----/{f=0} f' "$run_log" | grep -vE '^\(none\)$|^$' | wc -l)" -eq 0 ]; then
        pass "hyprctl configerrors is empty"
    else
        fail "hyprctl configerrors is empty" "$(awk '/^----- hyprctl configerrors -----$/{f=1;next} /^-----/{f=0} f' "$run_log")"
    fi
    # Confirm no ERR/CRITICAL lines in the Hyprland log.
    log_errs="$(awk '/^----- Hyprland log errors/{f=1;next} /^-----/{f=0} f' "$run_log" | grep -vE '^\(none\)$|^$' || true)"
    if [ -z "$log_errs" ]; then
        pass "Hyprland log has no ERR/CRITICAL lines"
    else
        fail "Hyprland log has no ERR/CRITICAL lines" "$log_errs"
    fi
fi

# Leave the run log around on failure so the user can inspect; clean up on success.
if [ "$TESTS_FAILED" -eq 0 ]; then
    rm -f "$run_log"
else
    echo "  full container log: $run_log" >&2
fi

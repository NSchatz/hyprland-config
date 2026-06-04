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

#!/usr/bin/env bash
# Visual regression: build the sway-headless container, render several rice presets, take per-
# preset screenshots of waybar / wofi / mako / kitty, and assert the manifest is non-trivial.
#
# Like test_integration_docker.sh this is opt-in (skipped unless docker is available AND either
# the image is cached or RUN_VISUAL=1 is set). The screenshots themselves are written to
# tests/visual/output/ inside the workspace, which CI then uploads as a build artifact so a
# reviewer can download and inspect each preset side-by-side from the workflow run page.

if ! command -v docker >/dev/null 2>&1; then
    skip "visual: docker missing" "docker not installed"
    return 0
fi

image="hyprland-config-visual"
out_host="$PLUGIN_ROOT/tests/visual/output"

have_image=0
if docker image inspect "$image" >/dev/null 2>&1; then
    have_image=1
fi
if [ "$have_image" -eq 0 ] && [ -z "${RUN_VISUAL:-}" ]; then
    skip "visual: docker image not built" "set RUN_VISUAL=1 to build + run (slow first run)"
    return 0
fi

# Build (or rebuild).
if [ "$have_image" -eq 0 ] || [ -n "${RUN_VISUAL_REBUILD:-}" ]; then
    build_log="$(mktemp -t hypr-visual-build.XXXXXX.log)"
    if docker build -t "$image" "$PLUGIN_ROOT/tests/visual" >"$build_log" 2>&1; then
        pass "visual docker image builds"
    else
        fail "visual docker image builds" "$(tail -n 80 "$build_log")"
        rm -f "$build_log"
        return 0
    fi
    rm -f "$build_log"
else
    pass "visual docker image already cached"
fi

# Fresh output dir each run so stale artifacts don't bleed.
rm -rf "$out_host"
mkdir -p "$out_host"

run_log="$(mktemp -t hypr-visual-run.XXXXXX.log)"

# Mount the plugin read-only, the screenshot script too, and the output dir read-write so the
# container can drop PNGs the orchestrator (and CI artifact upload) can read.
docker run --rm \
    -v "$PLUGIN_ROOT:/plugin:ro" \
    -v "$PLUGIN_ROOT/tests/visual/run-screenshots.sh:/root/run.sh:ro" \
    -v "$out_host:/screenshots" \
    --tmpfs /tmp:exec,mode=1777 \
    "$image" \
    bash /root/run.sh \
    >"$run_log" 2>&1
rc=$?

# Surface the last 50 lines so the workflow log shows the user what the in-container script saw
# (per the "all logs need to be monitored" rule).
{
    echo
    echo "  ── visual container stdout (tail) ──"
    tail -n 50 "$run_log" | sed 's/^/    /'
    echo "  ── end visual container stdout ──"
} >&2

if [ "$rc" -ne 0 ] || ! grep -q '^VISUAL=ok' "$run_log"; then
    fail "visual run: VISUAL=ok" "container exit $rc; full log at $run_log"
    return 0
fi
pass "visual run: VISUAL=ok"

# Assert the manifest exists.
if [ ! -f "$out_host/manifest.json" ]; then
    fail "manifest.json written" "missing"; return 0
fi
pass "manifest.json written"

# Manifest may legitimately be empty: the visual test now consumes the committed
# tests/agent-eval/generated/<fixture>/ dirs (i.e. real agent output). If nothing has been
# generated yet, the run-script writes a manifest with a `skipped_reason` and exits clean.
# Treat that as a skip, not a fail — the user populates fixtures locally via /regression-eval.
if command -v jq >/dev/null 2>&1; then
    skipped_reason="$(jq -r '.skipped_reason // empty' "$out_host/manifest.json")"
    shot_count="$(jq '.shots | length' "$out_host/manifest.json")"
    preset_count="$(jq '.presets | length' "$out_host/manifest.json")"
else
    skipped_reason="$(grep -oE '"skipped_reason"[[:space:]]*:[[:space:]]*"[^"]+"' "$out_host/manifest.json" | head -1 | sed 's/.*: *"//; s/"$//')"
    shot_count="$(grep -oE '"[^"]+\.png"' "$out_host/manifest.json" | wc -l)"
    preset_count="0"
fi

if [ -n "$skipped_reason" ]; then
    skip "visual: scene render" "$skipped_reason — run /regression-eval locally to populate tests/agent-eval/generated/"
    rm -f "$run_log"
    return 0
fi

# Real run: expect at minimum 3 shots per populated preset (waybar + terminal + desktop are
# the always-present surfaces — wofi/notification can drop out without failing the suite).
min_expected=$((preset_count * 3))
if [ "$shot_count" -ge "$min_expected" ]; then
    pass "manifest has ${shot_count} screenshots across ${preset_count} preset(s)"
else
    fail "manifest has ≥${min_expected} screenshots" "got $shot_count across $preset_count preset(s)"
fi

# Every preset that DID get screenshotted must have a waybar.png — that's the headline surface
# and confirms the fixture's waybar config was picked up.
missing_waybar=()
while IFS= read -r preset_dir; do
    preset="$(basename "$preset_dir")"
    [ -f "$preset_dir/waybar.png" ] || missing_waybar+=("$preset")
done < <(find "$out_host" -mindepth 1 -maxdepth 1 -type d | sort)

if [ "${#missing_waybar[@]}" -eq 0 ]; then
    pass "every populated preset has a waybar.png"
else
    detail=""
    for p in "${missing_waybar[@]}"; do detail+="$p"$'\n'; done
    fail "every populated preset has a waybar.png" "$detail"
fi

# Sanity check: the screenshots are non-trivially-sized PNG files (a 0-byte file would mean
# grim ran but captured nothing).
tiny_files=()
while IFS= read -r png; do
    size="$(stat -c %s "$png" 2>/dev/null || stat -f %z "$png" 2>/dev/null || echo 0)"
    if [ "$size" -lt 1024 ]; then
        tiny_files+=("$png ($size bytes)")
    fi
done < <(find "$out_host" -type f -name '*.png' | sort)

if [ "${#tiny_files[@]}" -eq 0 ]; then
    pass "no near-empty PNGs (all > 1 KB)"
else
    detail=""
    for t in "${tiny_files[@]}"; do detail+="$t"$'\n'; done
    fail "${#tiny_files[@]} suspiciously small PNGs" "$detail"
fi

echo "  screenshots in: $out_host" >&2

# Keep the run log on failure for inspection.
if [ "$TESTS_FAILED" -eq 0 ]; then
    rm -f "$run_log"
else
    echo "  full container log: $run_log" >&2
fi

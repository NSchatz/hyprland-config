#!/usr/bin/env bash
# Runs INSIDE the test container (built from tests/integration/Dockerfile). Starts Hyprland
# headlessly, runs the plugin's safe-apply flow against a known-good staging config, and prints
# a structured verdict the orchestrator outside parses. Also tails the Hyprland log and reports
# any ERROR/CRITICAL lines so a "config loads cleanly but Hyprland complains" regression is
# caught.
#
# The orchestrator passes the plugin in via /plugin (read-only mount).
set -uo pipefail

PLUGIN_ROOT="/plugin"
STAGING="/tmp/staging"
LOG_DIR="$XDG_RUNTIME_DIR/hypr"
mkdir -p "$STAGING"

# Make sure XDG_RUNTIME_DIR exists with the perms Hyprland insists on (0700 owned by current
# user). The Dockerfile creates this dir, but the orchestrator mounts a fresh tmpfs over /tmp at
# run time which wipes it — so re-create here.
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Hyprland writes crash reports under $XDG_CACHE_HOME/hyprland/crashReports — without that dir
# the crash reporter itself errors out ("failed to mkdir() crash report directory"), masking the
# real crash. Create it ahead of time so any actual Hyprland crash leaves a readable artifact.
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/hyprland/crashReports"

# ----- 1. Compose a minimal, known-good Hyprland config in the staging dir ------------------
# Modular layout matching what the rice skill generates.
cat > "$STAGING/hyprland.conf" <<'EOF'
# Test config — minimal but realistic shape.
$mainMod = SUPER
$accent  = rgba(cba6f7ee)
$accent2 = rgba(89b4faee)

source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/input.conf
source = ~/.config/hypr/looknfeel.conf
source = ~/.config/hypr/binds.conf
EOF

cat > "$STAGING/monitors.conf" <<'EOF'
# Headless backend exposes a virtual output named HEADLESS-1; a catch-all is safest for tests.
monitor = , preferred, auto, 1
EOF

cat > "$STAGING/input.conf" <<'EOF'
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = no
    }
}
EOF

cat > "$STAGING/looknfeel.conf" <<'EOF'
general {
    gaps_in = 5
    gaps_out = 20
    border_size = 2
    col.active_border = $accent $accent2 45deg
    layout = dwindle
}
decoration {
    rounding = 10
    blur {
        enabled = true
        size = 6
        passes = 2
    }
}
animations {
    enabled = yes
}
EOF

cat > "$STAGING/binds.conf" <<'EOF'
bind = $mainMod, Q, exec, kitty
bind = $mainMod, C, killactive
bind = $mainMod, M, exit
bind = $mainMod, R, exec, wofi --show drun
EOF

# ----- 1b. The OFFLINE check, against the real Hyprland binary -------------------------------
# This block is the evidence for the phase's open question ("does `Hyprland --verify-config`
# run with no session and no GPU?") and the NEGATIVE CONTROL that keeps the answer honest: a
# deliberately broken generated config is put through the same check, and the build FAILS if
# it comes back clean. A preflight that says `ok` to everything is worse than no preflight,
# because it buys a refusal you cannot get.
#
# It runs BEFORE Hyprland is started, so it reports in both of the container's modes - the
# live one and the parse-only one CI actually reaches.
echo "INTEGRATION_PHASE=offline-check"

MARKER='======== Config parsing result:'
GOOD="/tmp/preflight-good"
BAD="/tmp/preflight-bad"
rm -rf "$GOOD" "$BAD"
mkdir -p "$GOOD" "$BAD"
cp "$STAGING"/*.conf "$GOOD/"
cp "$STAGING"/*.conf "$BAD/"

# The deliberate break: a real, non-existent option inside a real category, planted in a
# SOURCED COMPANION rather than the main config, so the control also proves the check sees
# the whole staged set and not just the file it was pointed at.
cat >> "$BAD/looknfeel.conf" <<'EOF'

general {
    not_a_real_option_here = 3
}
EOF

# `contract <label> <expected-to-parse> <args...>` - the raw binary, so the recorded
# contract in tests/integration/offline-check-contract.md is re-derived every CI run
# rather than trusted.
contract() {
    local label="$1"; shift
    local out rc marker
    out="$("$@" 2>&1)"; rc=$?
    if printf '%s\n' "$out" | grep -qF "$MARKER"; then marker=yes; else marker=no; fi
    echo "OFFLINE_CONTRACT_${label}_RC=${rc}"
    echo "OFFLINE_CONTRACT_${label}_MARKER=${marker}"
}

# Self-contained files, so these three rows measure the flag's contract and nothing else.
# (A generated main config is NOT self-contained - it sources its companions by install
# path - which is exactly why the preflight builds a sandbox rather than pointing the
# binary at the staging dir. That property gets its own row below.)
CONTRACT="/tmp/offline-contract"
rm -rf "$CONTRACT"; mkdir -p "$CONTRACT"
printf 'general {\n    gaps_in = 5\n}\n'                  > "$CONTRACT/clean.conf"
printf 'general {\n    not_a_real_option_here = 3\n}\n'   > "$CONTRACT/broken.conf"

contract CLEAN  Hyprland --verify-config -c "$CONTRACT/clean.conf"
contract BROKEN Hyprland --verify-config -c "$CONTRACT/broken.conf"
contract REJECT Hyprland --verify-config -c "/tmp/definitely-not-a-config-file.conf"

# The property the preflight's sandbox rests on: hyprlang expands `~` in a `source =` line
# from $HOME, and an error in a sourced companion is reported against THAT companion's own
# path. Pointing HOME at a mirror of the staged set is what makes the check hermetic, so if
# this ever stops being true the sandbox stops isolating and this row goes red.
SRCPROBE="/tmp/offline-source-probe"
rm -rf "$SRCPROBE"; mkdir -p "$SRCPROBE/.config/hypr"
printf 'source = ~/.config/hypr/companion.conf\n'       > "$SRCPROBE/.config/hypr/hyprland.conf"
printf 'general {\n    not_a_real_option_here = 3\n}\n' > "$SRCPROBE/.config/hypr/companion.conf"
src_out="$(HOME="$SRCPROBE" Hyprland --verify-config -c "$SRCPROBE/.config/hypr/hyprland.conf" 2>&1)"
echo "OFFLINE_CONTRACT_SOURCE_RC=$?"
if printf '%s\n' "$src_out" | grep -q "$SRCPROBE/.config/hypr/companion.conf"; then
    echo "OFFLINE_CONTRACT_SOURCE_NAMES_COMPANION=yes"
else
    echo "OFFLINE_CONTRACT_SOURCE_NAMES_COMPANION=no"
fi

# Now the plugin's own preflight, which is what the apply flow actually calls.
pf_good="$(bash "$PLUGIN_ROOT/skills/rice/scripts/preflight-config.sh" "$GOOD" 2>&1)"
echo "OFFLINE_CHECK_GOOD=$(printf '%s\n' "$pf_good" | grep -oE '^PREFLIGHT=[a-z-]+' | sed 's/^PREFLIGHT=//' | tail -n1)"

pf_bad="$(bash "$PLUGIN_ROOT/skills/rice/scripts/preflight-config.sh" "$BAD" 2>&1)"
echo "OFFLINE_CHECK_BAD=$(printf '%s\n' "$pf_bad" | grep -oE '^PREFLIGHT=[a-z-]+' | sed 's/^PREFLIGHT=//' | tail -n1)"
if printf '%s\n' "$pf_bad" | grep -q "^PREFLIGHT_ERROR=.*${BAD}/looknfeel.conf"; then
    echo "OFFLINE_CHECK_BAD_NAMES_STAGED=yes"
else
    echo "OFFLINE_CHECK_BAD_NAMES_STAGED=no"
fi
echo "----- preflight (deliberately broken config) -----"
printf '%s\n' "$pf_bad"
echo "----- end preflight (deliberately broken config) -----"

# And the whole apply flow against that broken config, into a scratch target seeded with a
# sentinel: the refusal has to leave it byte-identical.
PF_TARGET="/tmp/preflight-target"
rm -rf "$PF_TARGET"; mkdir -p "$PF_TARGET"
printf 'SENTINEL - must survive a refused apply\n' > "$PF_TARGET/hyprland.conf"
pf_before="$(find "$PF_TARGET" -type f -exec sha256sum {} \; | sort)"
sa_bad="$(HYPR_DIR="$PF_TARGET" bash "$PLUGIN_ROOT/skills/rice/scripts/safe-apply.sh" "$BAD" 2>&1)"
echo "PREFLIGHT_REFUSED_INSTALL=$(printf '%s\n' "$sa_bad" | grep -oE '^SAFE_APPLY=[a-z-]+' | sed 's/^SAFE_APPLY=//' | tail -n1)"
pf_after="$(find "$PF_TARGET" -type f -exec sha256sum {} \; | sort)"
if [ "$pf_before" = "$pf_after" ]; then
    echo "PREFLIGHT_TARGET_UNCHANGED=yes"
else
    echo "PREFLIGHT_TARGET_UNCHANGED=no"
fi
echo "OFFLINE_CHECK=done"

# ----- 2. Start Hyprland headlessly in the background ---------------------------------------
echo "INTEGRATION_PHASE=starting-hyprland"

# Hyprland needs SOME config to even start; seed the target with a copy of the staging files so
# the first launch succeeds. safe-apply.sh will then re-install on top and live-test the reload.
mkdir -p "$HOME/.config/hypr"
cp "$STAGING"/* "$HOME/.config/hypr/"

# Log goes to $XDG_RUNTIME_DIR/hypr/<INSTANCE>/hyprland.log under normal launches; with
# HYPRLAND_LOG_STDOUT we also get it on stdout, which is easier to capture.
HYPR_LOG="/tmp/hyprland-stdout.log"
HYPRLAND_LOG_STDOUT=1 Hyprland > "$HYPR_LOG" 2>&1 &
HYPR_PID=$!

# Wait for the socket to come up. Hyprland prints its instance sig to the log; hyprctl picks it
# up via $HYPRLAND_INSTANCE_SIGNATURE in the env, or by looking under $XDG_RUNTIME_DIR/hypr/.
deadline=$(( $(date +%s) + 30 ))
ready=0
while [ "$(date +%s)" -lt "$deadline" ]; do
    if hyprctl version >/dev/null 2>&1; then
        ready=1; break
    fi
    sleep 0.5
done

if [ "$ready" -ne 1 ]; then
    # Hyprland's backend (Aquamarine) requires a real DRM/GPU device in most builds — on a CI
    # runner with no /dev/dri, the backend crashes during creation even though config parsing
    # finished cleanly. That's still useful: if Hyprland's own parser accepted our generated
    # config, every `source=` resolved, no deprecated syntax tripped a parse error, and no
    # `bind=`/`monitor=` line was rejected, the test is meaningful — we just can't drive
    # `hyprctl reload` against a live instance.
    #
    # Treat "config parsed cleanly, then backend failed at CBackend::create()" as a PASS for
    # the config-correctness part. Real `hyprctl reload` validation only happens on a developer
    # machine with a real Hyprland session (the safe-apply.sh flow is exercised manually there).
    echo "INTEGRATION_PHASE=hyprland-backend-failed"
    echo "----- Hyprland version / runtime info -----"
    Hyprland --version 2>&1 | head -n 20 || true
    echo "----- Hyprland stdout/stderr (full) -----"
    cat "$HYPR_LOG" || true
    echo "----- Hyprland file log (if any) -----"
    find "$XDG_RUNTIME_DIR/hypr" -name 'hyprland.log' -exec echo "::: {} :::" \; -exec cat {} \; 2>/dev/null || true
    echo "----- Hyprland crash reports (if any) -----"
    find "${XDG_CACHE_HOME:-$HOME/.cache}/hyprland" -name 'hyprlandCrashReport*.txt' \
        -exec echo "::: {} :::" \; -exec cat {} \; 2>/dev/null || true

    # Decide: did config parsing succeed before the crash? Hyprland always logs every parse
    # error with "[ERR] [Config Parser]" or "Config Error" in the log. Absence of those means
    # the config was accepted.
    parse_errors="$(grep -E '\[ERR\][[:space:]]*\[Config Parser\]|Config Error:|invalid keyword|invalid field|invalid token' "$HYPR_LOG" 2>/dev/null || true)"
    if [ -z "$parse_errors" ] \
       && grep -q 'Creating the ConfigManager' "$HYPR_LOG" 2>/dev/null \
       && grep -qE 'CBackend::create\(\) failed|CCompositor\(\) failed|Cannot open backend' "$HYPR_LOG" 2>/dev/null; then
        # Backend failed but parse was clean — that's the expected CI signature. Pass.
        # Force a leading newline because Hyprland's last stdout line (the CRIT/throw output)
        # often lacks a trailing newline, which would otherwise glue our phase marker to it and
        # break the orchestrator's `grep -q '^INTEGRATION_PHASE=...'` match.
        printf '\n'
        echo "INTEGRATION_PHASE=config-parse-ok-backend-cannot-init-on-ci"
        echo "INTEGRATION=ok (config parsed cleanly; backend cannot init without /dev/dri — expected on CI)"
        exit 0
    fi

    echo "INTEGRATION_PHASE=parse-or-startup-failure"
    if [ -n "$parse_errors" ]; then
        echo "----- Hyprland config parse errors -----"
        printf '%s\n' "$parse_errors"
    fi
    echo "INTEGRATION=failed (hyprland did not become ready in 30s)"
    exit 2
fi
echo "INTEGRATION_PHASE=hyprland-ready"

# Note the Hyprland file log location so we can tail it after safe-apply.
HYPR_FILE_LOG=""
if [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
    HYPR_FILE_LOG="$(find "$XDG_RUNTIME_DIR/hypr" -name 'hyprland.log' -printf '%T@ %p\n' 2>/dev/null \
                     | sort -nr | head -n1 | cut -d' ' -f2-)"
fi

# ----- 3. Run safe-apply on the staging dir -------------------------------------------------
echo "INTEGRATION_PHASE=safe-apply"
sa_out="$(bash "$PLUGIN_ROOT/skills/rice/scripts/safe-apply.sh" "$STAGING" 2>&1)"; sa_rc=$?
echo "$sa_out"
sa_verdict="$(printf '%s\n' "$sa_out" | grep -oE 'SAFE_APPLY=[a-z-]+' | tail -n1)"

# ----- 4. Read live errors via hyprctl ------------------------------------------------------
errs="$(hyprctl configerrors 2>/dev/null | sed '/^[[:space:]]*$/d')"
echo "INTEGRATION_PHASE=hyprctl-configerrors"
echo "----- hyprctl configerrors -----"
printf '%s\n' "${errs:-(none)}"

# ----- 5. Scan Hyprland's own log for ERROR / CRITICAL lines --------------------------------
# The compositor will load a syntactically-valid config that still triggers runtime warnings
# (missing fonts, unknown dispatchers, etc.). This catches those.
echo "INTEGRATION_PHASE=hyprland-log-scan"
log_errors=""
if [ -n "$HYPR_FILE_LOG" ] && [ -f "$HYPR_FILE_LOG" ]; then
    log_errors="$(grep -E '\[(ERR|CRITICAL)\]|^Critical:' "$HYPR_FILE_LOG" || true)"
fi
# Also scan the stdout capture in case the file log wasn't created.
log_errors_stdout="$(grep -E '\[(ERR|CRITICAL)\]|^Critical:' "$HYPR_LOG" || true)"
{
    echo "----- Hyprland log errors (file: ${HYPR_FILE_LOG:-none}) -----"
    printf '%s\n' "${log_errors:-(none)}"
    echo "----- Hyprland log errors (stdout) -----"
    printf '%s\n' "${log_errors_stdout:-(none)}"
}

# ----- 6. Verdict --------------------------------------------------------------------------
# All three must be clean: safe-apply ok, no live errs, no log errors.
verdict="ok"
reasons=()
if [ "$sa_verdict" != "SAFE_APPLY=ok" ]; then
    verdict="failed"; reasons+=("safe-apply: $sa_verdict")
fi
if [ -n "$errs" ]; then
    verdict="failed"; reasons+=("hyprctl configerrors not empty")
fi
if [ -n "$log_errors" ] || [ -n "$log_errors_stdout" ]; then
    verdict="failed"; reasons+=("Hyprland log contains ERR/CRITICAL lines")
fi

# Clean shutdown — best-effort, the orchestrator removes the container regardless.
hyprctl dispatch exit >/dev/null 2>&1 || true
sleep 0.5
kill "$HYPR_PID" 2>/dev/null || true
wait "$HYPR_PID" 2>/dev/null || true

if [ "$verdict" = "ok" ]; then
    echo "INTEGRATION=ok"
    exit 0
fi
echo "INTEGRATION=failed"
for r in "${reasons[@]}"; do echo "  reason: $r"; done
echo "----- safe-apply full output -----"
printf '%s\n' "$sa_out"
echo "----- Hyprland stdout full -----"
cat "$HYPR_LOG" || true
[ -n "$HYPR_FILE_LOG" ] && { echo "----- Hyprland file log full -----"; cat "$HYPR_FILE_LOG" || true; }
exit 1

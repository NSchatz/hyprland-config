#!/usr/bin/env bash
# S0028-hyprland-config-preflight-5 - the LIVE verdict: does the compositor confirm it
# loaded the file this plugin wrote?
#
# Grades AC-3, AC-8 and AC-9. Driven with a stub `hyprctl` (and a stub `Hyprland` so the
# preflight ahead of the install is satisfied), because the `unit` job runs on a bare
# ubuntu-latest with neither binary installed.
#
# The failure this closes is not a crash. `hyprctl configerrors` printing nothing is ALSO
# exactly what a config that was never parsed produces - a `hyprland.lua` shadowing the
# `hyprland.conf` we just wrote, or an instance started with `-c` pointing somewhere else.
# So an empty error list on its own must never buy a `live`/`ok` verdict.

RS="$PLUGIN_ROOT/skills/rice/scripts"
tmp="$(mktemp_test_dir preflight-live)"
stubbin="$tmp/bin"; mkdir -p "$stubbin"

# A Hyprland that always verifies clean - this file is not about the offline check.
cat > "$stubbin/Hyprland" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
[ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "XDG_RUNTIME_DIR is not set!" >&2; exit 134; }
case "${1:-}" in
    --help|-h)
        printf 'usage: Hyprland [arg [...]].\n\nArguments:\n'
        printf '    --config FILE       -c FILE  - Specify config file to use\n'
        printf '    --verify-config              - Do not run Hyprland, only print if the config has any errors\n'
        exit 0 ;;
esac
printf '\n\n======== Config parsing result:\n\nconfig ok\n'
exit 0
STUB

# A hyprctl driven entirely by env:
#   STUB_HYPRCTL_DEAD=1         no running instance
#   STUB_HYPRCTL_ERRORS=<text>  what `configerrors` prints
#   STUB_HYPRCTL_LOADED=<path>  the config the rolling log says was loaded
#   STUB_HYPRCTL_NOLOG=1        `rollinglog` works but names no config at all
cat > "$stubbin/hyprctl" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
if [ -n "${STUB_HYPRCTL_DEAD:-}" ]; then
    echo "Couldn't connect to the Hyprland socket" >&2
    exit 1
fi
case "${1:-}" in
    version)      echo "Hyprland 0.56.2 built from branch v0.56.2"; exit 0 ;;
    reload)       exit 0 ;;
    configerrors) printf '%s' "${STUB_HYPRCTL_ERRORS:-}"; [ -n "${STUB_HYPRCTL_ERRORS:-}" ] && echo; exit 0 ;;
    rollinglog)
        echo "[LOG] Creating the ConfigManager!"
        if [ -z "${STUB_HYPRCTL_NOLOG:-}" ] && [ -n "${STUB_HYPRCTL_LOADED:-}" ]; then
            echo "Using config: ${STUB_HYPRCTL_LOADED}"
        fi
        echo "[LOG] Hyprland init finished."
        exit 0 ;;
    systeminfo)   echo "Hyprland 0.56.2"; exit 0 ;;
    *)            echo "invalid command"; exit 1 ;;
esac
STUB

chmod +x "$stubbin/Hyprland" "$stubbin/hyprctl"
STUB_PATH="$stubbin:/usr/bin:/bin"

stage="$tmp/stage"; mkdir -p "$stage"
printf 'general {\n    gaps_in = 5\n}\n' > "$stage/hyprland.conf"

outcome()   { printf '%s\n' "$1" | grep -oE '^SAFE_APPLY=[a-z-]+' | sed 's/^SAFE_APPLY=//'; }
verdict()   { printf '%s\n' "$1" | grep -oE '^VERIFY=[a-z-]+'     | sed 's/^VERIFY=//'; }

# ---------------------------------------------------------------------------------------------
# loaded-config.sh - the thing that makes the compositor NAME the file
# ---------------------------------------------------------------------------------------------
out="$(PATH="$STUB_PATH" STUB_HYPRCTL_LOADED=/home/u/.config/hypr/hyprland.conf bash "$RS/loaded-config.sh" 2>&1)"; rc=$?
assert_eq "0" "$rc" "loaded-config: a running instance that names its config exits 0"
assert_eq "LOADED_CONFIG=/home/u/.config/hypr/hyprland.conf" \
    "$(printf '%s\n' "$out" | grep '^LOADED_CONFIG=' | head -n1)" \
    "loaded-config: reports the path the compositor logged"
assert_eq "LOADED_CONFIG_SOURCE=rollinglog" "$(printf '%s\n' "$out" | grep '^LOADED_CONFIG_SOURCE=')" \
    "loaded-config: names the route it used"

out="$(PATH="$STUB_PATH" STUB_HYPRCTL_DEAD=1 bash "$RS/loaded-config.sh" 2>&1)"; rc=$?
assert_eq "2" "$rc" "loaded-config: no running instance exits 2"

out="$(PATH="$STUB_PATH" STUB_HYPRCTL_NOLOG=1 XDG_RUNTIME_DIR="$tmp/empty-runtime" bash "$RS/loaded-config.sh" 2>&1)"; rc=$?
assert_eq "3" "$rc" "loaded-config: a running instance that names nothing exits 3 (unknown, never a guess)"
if printf '%s\n' "$out" | grep -q '^LOADED_CONFIG=unknown$'; then
    pass "loaded-config: an unidentifiable config is reported as unknown"
else
    fail "loaded-config: an unidentifiable config is reported as unknown" "$out"
fi

# ---------------------------------------------------------------------------------------------
# AC-3 - `live` requires a POSITIVE match, never an empty error list on its own
# ---------------------------------------------------------------------------------------------
want="/home/u/.config/hypr/hyprland.conf"

out="$(PATH="$STUB_PATH" STUB_HYPRCTL_LOADED="$want" bash "$RS/verify-config.sh" --expect "$want" 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-3: a confirmed match verifies ok"
assert_eq "ok" "$(verdict "$out")" "AC-3: a confirmed match reports VERIFY=ok"
if printf '%s\n' "$out" | grep -q "^CONFIRMED_CONFIG=${want}$"; then
    pass "AC-3: the confirmed file is named in the output"
else
    fail "AC-3: the confirmed file is named in the output" "$out"
fi

# The heart of AC-3: errors are empty, and that alone buys NOTHING.
out="$(PATH="$STUB_PATH" STUB_HYPRCTL_NOLOG=1 XDG_RUNTIME_DIR="$tmp/empty-runtime" \
       bash "$RS/verify-config.sh" --expect "$want" 2>&1)"; rc=$?
assert_eq "3" "$rc" "AC-3: an empty error list with NO identification is not ok (exit 3)"
assert_eq "unconfirmed" "$(verdict "$out")" \
    "AC-3: an empty error list with no identification reports VERIFY=unconfirmed"

# ... and the read-only/no-expect mode keeps its existing meaning, so the callers that
# only ask "does the current config parse" (edit-config, reset-config, the validator
# agent) are untouched.
out="$(PATH="$STUB_PATH" STUB_HYPRCTL_NOLOG=1 bash "$RS/verify-config.sh" 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-3: without --expect, verify-config keeps its existing contract"
assert_eq "ok" "$(verdict "$out")" "AC-3: without --expect, a clean reload still reports VERIFY=ok"

# Parse errors still win over identification - they are the more actionable verdict and
# they are what drives the rollback.
out="$(PATH="$STUB_PATH" STUB_HYPRCTL_ERRORS="Config error in file /x at line 1: nope" \
       STUB_HYPRCTL_LOADED="$want" bash "$RS/verify-config.sh" --expect "$want" 2>&1)"; rc=$?
assert_eq "1" "$rc" "AC-3: parse errors still report VERIFY=errors, ahead of the identity check"

# ---------------------------------------------------------------------------------------------
# AC-8 - no reachable instance => installed but untested, and never live
# ---------------------------------------------------------------------------------------------
out="$(PATH="$STUB_PATH" STUB_HYPRCTL_DEAD=1 bash "$RS/verify-config.sh" --expect "$want" 2>&1)"; rc=$?
assert_eq "2" "$rc" "AC-8: an unreachable compositor is skipped (exit 2), not failed"
assert_eq "skipped" "$(verdict "$out")" "AC-8: an unreachable compositor reports VERIFY=skipped"

t8="$tmp/t8"; mkdir -p "$t8"; printf 'OLD\n' > "$t8/hyprland.conf"
out="$(PATH="$STUB_PATH" STUB_HYPRCTL_DEAD=1 HYPR_DIR="$t8" bash "$RS/safe-apply.sh" "$stage" 2>&1)"; rc=$?
assert_eq "installed-untested" "$(outcome "$out")" \
    "AC-8: an apply with no reachable instance reports installed-untested"
if printf '%s\n' "$out" | grep -qE '^SAFE_APPLY=ok'; then
    fail "AC-8: an untested install is never reported as live/ok" "$out"
else
    pass "AC-8: an untested install is never reported as live/ok"
fi
if [ -f "$t8/hyprland.conf" ] && grep -q 'gaps_in' "$t8/hyprland.conf"; then
    pass "AC-8: the config was still installed (untested is not refused)"
else
    fail "AC-8: the config was still installed (untested is not refused)" "$(ls -A "$t8")"
fi

# ---------------------------------------------------------------------------------------------
# AC-9 - the compositor names a DIFFERENT file => not live, name it, report unconfirmed
# ---------------------------------------------------------------------------------------------
shadow="/home/u/.config/hypr/hyprland.lua"
out="$(PATH="$STUB_PATH" STUB_HYPRCTL_LOADED="$shadow" bash "$RS/verify-config.sh" --expect "$want" 2>&1)"; rc=$?
assert_eq "3" "$rc" "AC-9: a mismatch is unconfirmed (exit 3)"
assert_eq "unconfirmed" "$(verdict "$out")" "AC-9: a mismatch reports VERIFY=unconfirmed"
if printf '%s\n' "$out" | grep -q "^LOADED_CONFIG=${shadow}$"; then
    pass "AC-9: the file the compositor actually loaded is NAMED"
else
    fail "AC-9: the file the compositor actually loaded is NAMED" "$out"
fi
if printf '%s\n' "$out" | grep -q "^EXPECTED_CONFIG=${want}$"; then
    pass "AC-9: the file the plugin wrote is named beside it"
else
    fail "AC-9: the file the plugin wrote is named beside it" "$out"
fi

# The same mismatch through the whole apply flow. The install happened and stays: the
# config is not what is broken, so rolling back would be the wrong remedy. But it is
# NOT live, and the outcome word has to say so.
t9="$tmp/t9"; mkdir -p "$t9"; printf 'OLD\n' > "$t9/hyprland.conf"
out="$(PATH="$STUB_PATH" STUB_HYPRCTL_LOADED="$t9/hyprland.lua" HYPR_DIR="$t9" \
       bash "$RS/safe-apply.sh" "$stage" 2>&1)"; rc=$?
assert_eq "unconfirmed" "$(outcome "$out")" "AC-9: an apply the compositor did not confirm reports unconfirmed"
if printf '%s\n' "$out" | grep -q "^LOADED_CONFIG=${t9}/hyprland.lua$"; then
    pass "AC-9: the apply output names the file the compositor loaded"
else
    fail "AC-9: the apply output names the file the compositor loaded" "$out"
fi
if [ "$rc" -ne 0 ]; then
    pass "AC-9: an unconfirmed apply exits non-zero"
else
    fail "AC-9: an unconfirmed apply exits non-zero" "rc=0
$out"
fi
if grep -q 'gaps_in' "$t9/hyprland.conf" 2>/dev/null; then
    pass "AC-9: the install stands (unconfirmed is not a rollback)"
else
    fail "AC-9: the install stands (unconfirmed is not a rollback)" "$(cat "$t9/hyprland.conf" 2>/dev/null)"
fi
if printf '%s\n' "$out" | grep -q '^SAFE_APPLY=rolled-back'; then
    fail "AC-9: an unconfirmed install is not rolled back" "$out"
else
    pass "AC-9: an unconfirmed install is not rolled back"
fi

# And the positive control: the compositor confirms the exact file, so `ok` is earned.
t9b="$tmp/t9b"; mkdir -p "$t9b"; printf 'OLD\n' > "$t9b/hyprland.conf"
out="$(PATH="$STUB_PATH" STUB_HYPRCTL_LOADED="$t9b/hyprland.conf" HYPR_DIR="$t9b" \
       bash "$RS/safe-apply.sh" "$stage" 2>&1)"; rc=$?
assert_eq "ok" "$(outcome "$out")" "AC-3: an apply the compositor confirms reports ok"
assert_eq "0" "$rc" "AC-3: a confirmed apply exits 0"

rm -rf "$tmp"

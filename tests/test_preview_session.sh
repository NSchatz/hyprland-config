# The preview session record: the lock that keeps it to one VM, and the orphan case.
#
# No VM is started. Liveness is a pidfile, so the test can drive "the VM died" directly, which
# is the case that matters: a RECORD that outlives its VM. That is not a corner - it is what a
# crash, an OOM kill or a reboot leaves behind, and it matters because a preview also owns a
# disk overlay, a VNC display number and a forwarded port. If the record went away with the
# process, those would stay claimed with nothing pointing at them.

if ! command -v python3 >/dev/null 2>&1; then
    skip "preview session" "python3 missing"
    return 0
fi

tmp="$(mktemp_test_dir preview-session)"
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

# HOME goes with XDG_CONFIG_HOME: a `~/.config/...` path resolves against the config base, so
# an inherited value would send this test's writes outside its sandbox.
unset XDG_CONFIG_HOME XDG_STATE_HOME
export HOME="$tmp/home"
mkdir -p "$HOME"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
export RICE_PREVIEW_DIR="$tmp/state/preview"
export RICE_PREVIEW_CACHE="$tmp/cache"
mkdir -p "$RICE_PREVIEW_CACHE"
PIDFILE="$RICE_PREVIEW_CACHE/qemu.pid"

cli() { PYTHONPATH="$PLUGIN_ROOT/scripts" python3 -m ricelib.preview.previewcli "$@" 2>&1; }
marker() { printf '%s\n' "$1" | grep -oE '^PREVIEW=[a-z-]+' | tail -n1; }

# ---------------------------------------------------------------------------------------
# Nothing running, nothing recorded.
# ---------------------------------------------------------------------------------------
out="$(cli status)"; rc=$?
assert_eq "0" "$rc" "status exits 0 when there is no preview"
assert_eq "PREVIEW=none" "$(marker "$out")" "status reports no preview"

# ---------------------------------------------------------------------------------------
# The record round-trips, and honours RICE_PREVIEW_DIR.
# ---------------------------------------------------------------------------------------
PYTHONPATH="$PLUGIN_ROOT/scripts" python3 - >/dev/null 2>&1 <<'PY'
from ricelib.preview import session as ss
rec = ss.Session(id="20260919-120000", overlay="/tmp/overlay.qcow2",
                 source="/tmp/hypr-gen-1", staging="/tmp/hypr-gen-1", size="1280x800",
                 display=11, ssh_port=22222, created="2026-09-19T12:00:00Z")
assert ss.save(rec), "save failed"
back = ss.load()
assert back is not None and back.id == rec.id, "round trip lost the record"
assert back.display == 11 and back.ssh_port == 22222, "round trip lost the connection details"
PY
assert_eq "0" "$?" "the session record round-trips through disk"
assert_file_exists "$RICE_PREVIEW_DIR/session.json" \
    "RICE_PREVIEW_DIR decides where the record lives"

# ---------------------------------------------------------------------------------------
# THE ORPHAN. The record is on disk and no VM is running.
# ---------------------------------------------------------------------------------------
rm -f "$PIDFILE"
out="$(cli status)"; rc=$?
assert_eq "1" "$rc" "status exits non-zero on an orphaned record"
assert_eq "PREVIEW=stopped" "$(marker "$out")" \
    "an orphaned record is reported as stopped, not as nothing"
assert_eq "127.0.0.1:5911" "$(printf '%s\n' "$out" | sed -n 's/^PREVIEW_VNC=//p')" \
    "the orphan still reports the display it claimed"

# A pidfile naming a process that is not running must read as not running, not as running.
echo 999999 > "$PIDFILE"
assert_eq "PREVIEW=stopped" "$(marker "$(cli status)")" \
    "a stale pidfile reads as stopped"

# ---------------------------------------------------------------------------------------
# A live pid means running.
# ---------------------------------------------------------------------------------------
sleep 30 &
live=$!
echo "$live" > "$PIDFILE"
out="$(cli status)"; rc=$?
assert_eq "0" "$rc" "status exits 0 while a preview is running"
assert_eq "PREVIEW=running" "$(marker "$out")" "a live pid reads as running"

# ---------------------------------------------------------------------------------------
# THE LOCK. One preview at a time.
# ---------------------------------------------------------------------------------------
out="$(cli start)"; rc=$?
assert_eq "3" "$rc" "start refuses while a preview is already running"
assert_eq "PREVIEW=refused-already-running" "$(marker "$out")" "the refusal names its reason"

# ---------------------------------------------------------------------------------------
# Stop clears it, discards the overlay, and is idempotent.
# ---------------------------------------------------------------------------------------
touch "$tmp/overlay.qcow2"
PYTHONPATH="$PLUGIN_ROOT/scripts" python3 - >/dev/null 2>&1 <<PY
from ricelib.preview import session as ss
rec = ss.load(); rec.overlay = "$tmp/overlay.qcow2"; ss.save(rec)
PY
out="$(cli stop)"; rc=$?
assert_eq "0" "$rc" "stop exits 0"
assert_eq "PREVIEW=stopped" "$(marker "$out")" "stop reports what it did"
if [ -e "$RICE_PREVIEW_DIR/session.json" ]; then
    fail "stop clears the record" "session.json still exists after stop"
else
    pass "stop clears the record"
fi
if [ -e "$tmp/overlay.qcow2" ]; then
    fail "stop discards the throwaway overlay" "the overlay survived stop"
else
    pass "stop discards the throwaway overlay"
fi
kill "$live" 2>/dev/null

out="$(cli stop)"; rc=$?
assert_eq "0" "$rc" "stop is idempotent"
assert_eq "PREVIEW=none" "$(marker "$out")" "a second stop reports there was nothing to stop"

# ---------------------------------------------------------------------------------------
# A corrupt record reads as no record rather than wedging the feature shut.
# ---------------------------------------------------------------------------------------
mkdir -p "$RICE_PREVIEW_DIR"
printf '{ this is not json' > "$RICE_PREVIEW_DIR/session.json"
out="$(cli status)"; rc=$?
assert_eq "0" "$rc" "a corrupt record does not wedge status"
assert_eq "PREVIEW=none" "$(marker "$out")" "a corrupt record reads as no record"

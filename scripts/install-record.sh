#!/usr/bin/env bash
# The install record: what this plugin put on the machine, left ON the machine.
#
# A package install is the one thing this plugin does that a config restore cannot undo - the
# packages stay. Until now the only account of a transaction was a verdict line in a chat
# transcript, which is gone the moment the session is. This file is the durable half: every
# transaction leaves a record naming every package installed, every one already present, every
# one that failed (with the one-line reason the install reported) and every AUR helper built
# from source, and the user can read it back later without knowing where it is stored.
#
# It records. It never installs and never removes anything: what to do about what is in the
# record is the user's call.
#
# Usage:
#   install-record.sh record [--route <name>] [--helper <name>] [--label <text>]
#                                     read a transaction on stdin and persist it
#   install-record.sh list            list the recorded transactions, newest first
#   install-record.sh show <id>       print one recorded transaction in full
#   install-record.sh where           print the directory the records live in
#
# `record` reads TAB-separated lines on stdin:
#   <status> <tab> <package> [<tab> <origin> [<tab> <note>]]
# status is one of:
#   installed           this transaction installed it
#   present             it was already there and was left alone
#   failed              it did not install; <note> carries the one-line reason
#   built-from-source   built here from source rather than installed from a repository;
#                       <origin> is the URL it was cloned from
# origin is `repo`, `aur`, a URL, or empty. Unknown statuses are reported and dropped.
#
# Output (stdout, this repo's KEY=value convention):
#   the whole transaction, one line per package, always - whether or not it could be persisted
#   INSTALL_RECORD=<path>       the file it was written to     (only when it really was)
#   INSTALL_RECORD_ID=<id>      the identifier `show` takes    (only when it really was)
#   INSTALL_RECORD=unwritten    when the record could not be written; the failure and the path
#                               it tried are on stderr, and the install is NOT reported recorded
#   INSTALL_RECORD=empty        nothing was installed, already present or failed, so there was
#                               no transaction to record and nothing was written
#
# Exit codes:
#   0  recorded (or nothing to record)
#   2  usage error
#   3  `show` was given an identifier with no record
#   5  there was a transaction but it could not be written where it belongs
#
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/installrecord.py). This file locates the package
# and hands off; `rice installs` and install-packages.sh invoke it by this name.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

libdir=""
for c in "$here" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -f "$c/ricelib/installrecord.py" ]; then libdir="$c"; break; fi
done
if [ -z "$libdir" ]; then
    echo "ERROR: the ricelib package was not found (looked next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, and in \$RICE_DIR)." >&2
    echo "INSTALL_RECORD=unwritten" >&2
    exit 5
fi

# An install that leaves no record is the thing this component exists to prevent, so a missing
# interpreter is reported as an unwritten record rather than passed over.
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required to write an install record and is not installed." >&2
    echo "ERROR: install with: sudo pacman -S --needed python" >&2
    echo "INSTALL_RECORD=unwritten" >&2
    exit 5
fi

PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.installrecord "$@"

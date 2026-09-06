#!/usr/bin/env bash
# regress_0037_F1 - S0037-hyprland-config-install-7, impl gate ordinal 1, finding F1.
#
# RUN AGAINST A CHECKOUT OF `sdd/S0037-hyprland-config-install-7`; it exits 2 (inconclusive) on a
# tree that has no scripts/install-record.sh.
#
# Acceptance criterion under test (work/specs/S0037-hyprland-config-install-7/spec.md):
#   "WHEN a user asks what a past install put on the machine THE SYSTEM SHALL list the recorded
#    installs newest first ..."
#
# `ir_new_id` mints <YYYYmmdd-HHMMSS> and, when a record already exists for that second, suffixes
# it: <base>, then <base>-1. `ir_list` orders with `find ... | sort -r` on the FILE NAME, and
# "<base>.tsv" sorts AFTER "<base>-1.tsv" in a descending sort, so the OLDER record is listed
# first whenever two transactions land in the same second (two quick re-runs of an idempotent
# install.sh, or a scripted install followed straight away by an ad-hoc one).
#
# Standalone: no test harness needed.  bash tests/regress_0037_F1.sh   (exit 0 = criterion holds)

set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
IR="$(cd "$here/.." && pwd)/scripts/install-record.sh"

if [ ! -f "$IR" ]; then
    echo "INCONCLUSIVE: $IR does not exist - run this against the S0037 branch tree" >&2
    exit 2
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/regress0037F1.XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"; mkdir -p "$HOME"
unset XDG_STATE_HOME RICE_DIR 2>/dev/null || true

attempt=0
id1=""; id2=""; store=""
while [ "$attempt" -lt 5 ]; do
    attempt=$((attempt + 1))
    store="$tmp/store$attempt"
    o1="$(printf 'installed\tfirst-package\trepo\t\n' \
          | RICE_INSTALL_RECORD_DIR="$store" bash "$IR" record --route install.sh 2>&1)"
    o2="$(printf 'installed\tsecond-package\trepo\t\n' \
          | RICE_INSTALL_RECORD_DIR="$store" bash "$IR" record --route package-list 2>&1)"
    id1="$(printf '%s\n' "$o1" | sed -n 's/^INSTALL_RECORD_ID=//p' | head -n1)"
    id2="$(printf '%s\n' "$o2" | sed -n 's/^INSTALL_RECORD_ID=//p' | head -n1)"
    # Both records landed in the same second when the second one carries the -N suffix.
    case "$id2" in
        "$id1"-*) break ;;
        *) id1=""; id2="" ;;
    esac
done

if [ -z "$id2" ]; then
    echo "INCONCLUSIVE: could not land two records in the same second after $attempt attempts" >&2
    exit 2
fi

echo "record written first (older): $id1"
echo "record written second (newer): $id2"

listing="$(RICE_INSTALL_RECORD_DIR="$store" bash "$IR" list 2>&1)"
first_listed="$(printf '%s\n' "$listing" | head -n1 | cut -f1)"
echo "--- install-record.sh list ---"
printf '%s\n' "$listing"
echo "------------------------------"

if [ "$first_listed" = "$id2" ]; then
    echo "PASS: the newest record is listed first"
    exit 0
fi
echo "FAIL: the listing is NOT newest first."
echo "      newest record is $id2 but the listing leads with $first_listed"
exit 1

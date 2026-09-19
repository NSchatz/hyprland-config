#!/usr/bin/env bash
# Make Python available BEFORE anything needs it, or say plainly that it is not.
#
# Why this exists, and why it is bash.
#
# This plugin's generation path reads and writes `answers.json` through `scripts/answers.py` and
# `scripts/record-answer.py`. Those run during the interview - long before `install.sh` exists,
# let alone runs. The reference layer claimed `pacman` pulls in `python3` as a base dependency.
# It does not:
#
#   - `base` (the meta-package that defines a minimal install) depends on 28 packages:
#     archlinux-keyring bash bzip2 coreutils file filesystem findutils gawk gcc-libs gettext
#     glibc grep gzip iproute2 iputils licenses pacman pciutils procps-ng psmisc sed shadow
#     systemd systemd-sysvcompat tar util-linux xz. Python is not among them.
#   - `pacman` lists python only as a CHECK dependency - used to run its own test suite, never
#     installed on a user's machine.
#
# So on a genuinely minimal Arch install - the exact case the generation path was written for -
# `python3` can be absent and the interview cannot record a single answer. This script is the
# bootstrap that makes "everything downstream is Python" true, and it is written in bash because
# bash IS in `base`. It is the one place that cannot assume the interpreter it is installing.
#
# It is NOT a silent install. Packages are the one thing this plugin does that a restore cannot
# undo, so this asks first and records what it did, exactly like every other install here.
#
# Usage:
#   ensure-python.sh                 ask before installing if python3 is missing
#   ensure-python.sh --assume-yes    install without prompting (caller already confirmed)
#   ensure-python.sh --assume-no     never install; just report
#   ensure-python.sh --check         report only, install nothing, exit 1 if missing
#
# Output ends with exactly one of:
#   PYTHON=present    <path>         already installed; nothing was done
#   PYTHON=installed  <path>         installed just now, and recorded
#   PYTHON=declined                  missing, the user said no; nothing was installed
#   PYTHON=missing                   missing and this host cannot install it (no pacman)
#   PYTHON=failed                    the install was attempted and did not succeed
set -uo pipefail

PKG="python"
assume=""
check_only=0
for a in "$@"; do
    case "$a" in
        --assume-yes) assume="y" ;;
        --assume-no)  assume="n" ;;
        --check)      check_only=1 ;;
        *) echo "ERROR: unknown option: $a" >&2; exit 2 ;;
    esac
done

here="$(cd "$(dirname "$0")" && pwd)"

# Already there? Say so and stop. Idempotent by construction: re-running is a no-op.
if py="$(command -v python3 2>/dev/null)" && [ -n "$py" ] && "$py" -c 'import sys' >/dev/null 2>&1; then
    echo "PYTHON=present $py"
    exit 0
fi

echo "PYTHON_MISSING=1"
printf 'python3 is not installed on this machine.\n'
printf 'This plugin records every interview answer to answers.json through a Python helper, so the\n'
printf 'interview cannot start without it. Python is NOT part of Arch'"'"'s `base` meta-package, so a\n'
printf 'minimal install genuinely may not have it.\n'

if [ "$check_only" -eq 1 ]; then
    echo "PYTHON=missing"
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    printf 'No pacman on this host, so this script will not try to install it. Install python 3 with\n'
    printf 'your own package manager and re-run.\n'
    echo "PYTHON=missing"
    exit 1
fi

answer="$assume"
if [ -z "$answer" ]; then
    printf 'Install it now with: sudo pacman -S --needed %s\n' "$PKG"
    printf 'Install python now? [y/N] '
    if ! IFS= read -r answer; then answer=""; fi
    printf '\n'
fi

case "$answer" in
    y|Y|yes|YES)
        ;;
    *)
        printf 'Nothing was installed. The interview cannot run until python3 is available.\n'
        echo "PYTHON=declined"
        exit 4 ;;
esac

if ! sudo pacman -S --needed --noconfirm "$PKG"; then
    printf 'The install did not succeed. Nothing else has been changed.\n'
    echo "PYTHON=failed"
    exit 1
fi

py="$(command -v python3 2>/dev/null)"
if [ -z "$py" ]; then
    printf 'pacman reported success but python3 is still not on PATH.\n'
    echo "PYTHON=failed"
    exit 1
fi

# Record it. A package this plugin put on the machine that no record mentions is the exact gap
# install-record.sh exists to close, and a bootstrap is not an exception to that.
recorder=""
for c in "$here/install-record.sh" "${CLAUDE_PLUGIN_ROOT:-}/scripts/install-record.sh"; do
    [ -n "$c" ] && [ -f "$c" ] && { recorder="$c"; break; }
done
if [ -n "$recorder" ]; then
    printf 'installed\t%s\trepo\tbootstrap: required before the interview can record answers\n' "$PKG" \
        | bash "$recorder" record --route ensure-python || \
        printf 'NOTE: python was installed but the record could not be written.\n'
else
    printf 'NOTE: python was installed but no install recorder was found to record it.\n'
fi

echo "PYTHON=installed $py"
exit 0

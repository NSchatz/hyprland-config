#!/usr/bin/env bash
# Install a package list on Arch, and leave a record of what that did.
#
# This is the ONE routing implementation. The generated `install.sh` calls it with the list the
# interview resolved, and the installer agent calls it with an ad-hoc list; both therefore leave
# the same record, in the same place, in the same form. A record only one route writes is a
# record a user cannot rely on, so this file refuses to install at all when it cannot find the
# recorder (scripts/install-record.sh).
#
# It installs exactly the packages it is given. It never upgrades the system, never removes a
# package, and never enables a service.
#
# Usage:
#   install-packages.sh [options] <pkg> [<pkg> ...]
#
# Options:
#   --route <name>    what to record this transaction as (default: package-list; the generated
#                     script passes install.sh)
#   --label <text>    a free-text note stored with the record
#   --helper <h>      force the AUR helper (paru | yay)
#   --noconfirm       pass --noconfirm to pacman and to the AUR helper
#   --assume-yes      answer the AUR-helper build confirmation with yes, without prompting
#   --assume-no       answer it with no (the fail-safe for an unattended run)
#
# Output (stdout, this repo's KEY=value convention):
#   PACKAGES=<the list>, then one line per package  - always, before anything is installed
#   AUR_BUILD_REQUIRED=<pkg> + the disclosure       - before any clone or build
#   AUR_BOOTSTRAP=built|declined|failed|not-needed
#   the install record's own transaction print + INSTALL_RECORD= line
#   INSTALL=ok | partial | failed | declined-aur-build | skipped (non-arch)
#
# Exit codes:
#   0  ok, partial, or skipped (non-arch)
#   1  failed, or the transaction could not be recorded
#   2  usage error, or the install record component is missing (nothing was installed)
#   4  the AUR-helper build was declined; nothing was cloned, built or installed from the AUR
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/installpackages.py).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
libdir=""
for c in "$here" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -f "$c/ricelib/installpackages.py" ]; then libdir="$c"; break; fi
done
if [ -z "$libdir" ]; then
    echo "ERROR: the ricelib package was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in \$RICE_DIR." >&2
    echo "INSTALL=failed"; exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required and is not installed (sudo pacman -S --needed python)." >&2
    echo "ERROR: nothing was installed." >&2
    echo "INSTALL=failed"; exit 2
fi
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.installpackages "$@"

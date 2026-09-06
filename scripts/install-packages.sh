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

# The AUR helper this bootstraps, and where it comes from. `paru`, not `paru-bin`: the prebuilt
# binary links against a specific libalpm.so and breaks on the next pacman bump.
AUR_HELPER_PKG="paru"
AUR_HELPER_URL="https://aur.archlinux.org/paru.git"

route="package-list"
label=""
forced_helper=""
noconfirm=0
assume=""
pkgs=()

while [ "$#" -gt 0 ]; do
    opt="$1"; shift
    case "$opt" in
        --route)      route="${1:-}";         [ "$#" -gt 0 ] && shift ;;
        --label)      label="${1:-}";         [ "$#" -gt 0 ] && shift ;;
        --helper)     forced_helper="${1:-}"; [ "$#" -gt 0 ] && shift ;;
        --noconfirm)  noconfirm=1 ;;
        --assume-yes) assume="yes" ;;
        --assume-no)  assume="no" ;;
        -h|--help)    sed -n '2,40p' "$0"; exit 0 ;;
        --) while [ "$#" -gt 0 ]; do pkgs+=("$1"); shift; done ;;
        -*) echo "ERROR: unknown option '$opt' (try: install-packages.sh --help)" >&2; exit 2 ;;
        *)  pkgs+=("$opt") ;;
    esac
done

if [ "${#pkgs[@]}" -eq 0 ]; then
    echo "ERROR: usage: install-packages.sh [options] <pkg> [<pkg> ...]" >&2
    exit 2
fi

# The recorder. Without it this script does not install: an install nobody can look up
# afterwards is the defect this whole path exists to close.
rice_dir="${RICE_DIR:-}"
if [ -z "$rice_dir" ] && [ -f "$here/xdg-config.sh" ]; then
    # shellcheck source=xdg-config.sh
    . "$here/xdg-config.sh"
    rice_dir="$(xdg_config_path hypr-rice)" || rice_dir=""
fi
RECORDER=""
for c in "$here/install-record.sh" \
         "${CLAUDE_PLUGIN_ROOT:-}/scripts/install-record.sh" \
         "${rice_dir:+$rice_dir/install-record.sh}"; do
    if [ -n "$c" ] && [ -f "$c" ]; then RECORDER="$c"; break; fi
done
if [ -z "$RECORDER" ]; then
    echo "ERROR: the install record component (install-record.sh) was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in the rice directory." >&2
    echo "ERROR: nothing was installed. An install that leaves no record is exactly what this path refuses to do - re-run rice-init.sh." >&2
    echo "INSTALL=failed"
    exit 2
fi

# The transaction, built up as the install runs and handed to the recorder at the end.
txn="$(mktemp "${TMPDIR:-/tmp}/hypr-rice-install.XXXXXX")" || {
    echo "ERROR: no writable temporary directory; refusing to install without somewhere to build the transaction." >&2
    echo "INSTALL=failed"
    exit 1
}
cleanup() { rm -f "$txn" 2>/dev/null; }
trap cleanup EXIT

txn_add() {  # <status> <package> <origin> <note>
    printf '%s\t%s\t%s\t%s\n' "${1:-}" "${2:-}" "${3:-}" "${4:-}" >> "$txn"
}

# --- the list, printed before anything happens ------------------------------------------------
echo "PACKAGES=${pkgs[*]}"
for p in "${pkgs[@]}"; do printf '  %s\n' "$p"; done

# --- no pacman: print the list, install nothing ------------------------------------------------
if ! command -v pacman >/dev/null 2>&1; then
    echo "PACMAN=absent"
    echo "This host has no pacman, so nothing was installed: no package manager and no AUR helper was invoked."
    echo "The list above is what an Arch host would install; install the equivalents with your own package manager."
    # Nothing was installed, nothing was already present, nothing failed. There was no
    # transaction, so there is no record: a record here would invent a history.
    echo "INSTALL=skipped (non-arch)"
    exit 0
fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        echo "ERROR: pacman needs root and neither sudo nor a root shell is available." >&2
        echo "INSTALL=failed"
        exit 1
    fi
fi

pac_noconfirm=()
[ "$noconfirm" -eq 1 ] && pac_noconfirm=(--noconfirm)

# `reason_for <package> <output>` - the one-line reason the install reported for a package.
reason_for() {
    local p="${1:-}" out="${2:-}" line
    line="$(printf '%s\n' "$out" | grep -F -- "$p" | grep -iE 'error|failed|not found|conflict|unable' | head -n1)"
    [ -z "$line" ] && line="$(printf '%s\n' "$out" | grep -iE '^(error|==> ERROR)' | head -n1)"
    [ -z "$line" ] && line="the install reported no error but the package is not installed afterwards"
    printf '%s\n' "$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
}

installed_now() { pacman -Qq "$1" >/dev/null 2>&1; }

# --- partition: already present / repo / AUR ---------------------------------------------------
present=(); repo=(); aur=()
for p in "${pkgs[@]}"; do
    if installed_now "$p"; then
        present+=("$p")
        txn_add present "$p" "-" "already installed; left alone"
    elif pacman -Si "$p" >/dev/null 2>&1; then
        repo+=("$p")
    else
        aur+=("$p")
    fi
done

n_installed=0; n_failed=0

# --- repo bucket ------------------------------------------------------------------------------
if [ "${#repo[@]}" -gt 0 ]; then
    echo "REPO_PACKAGES=${repo[*]}"
    out="$($SUDO pacman -S --needed "${pac_noconfirm[@]}" "${repo[@]}" 2>&1)"
    printf '%s\n' "$out"
    for p in "${repo[@]}"; do
        if installed_now "$p"; then
            txn_add installed "$p" "repo" ""
            n_installed=$((n_installed + 1))
        else
            txn_add failed "$p" "repo" "$(reason_for "$p" "$out")"
            n_failed=$((n_failed + 1))
        fi
    done
fi

# --- AUR bucket --------------------------------------------------------------------------------
declined=0
helper=""
helper_works() {
    local h="${1:-}"
    [ -n "$h" ] || return 1
    command -v "$h" >/dev/null 2>&1 || return 1
    "$h" --version >/dev/null 2>&1 || return 1
    return 0
}

if [ "${#aur[@]}" -gt 0 ]; then
    echo "AUR_PACKAGES=${aur[*]}"
    for h in ${forced_helper:-} paru yay; do
        if helper_works "$h"; then helper="$h"; break; fi
    done

    if [ -z "$helper" ]; then
        # DISCLOSE BEFORE BUILDING. The user authorised installing packages, not compiling a
        # package manager they did not know they were missing - so name what is about to be
        # built, say that it is a source build on this machine, and show where it is cloned
        # from, all before anything is cloned or built.
        echo "AUR_BUILD_REQUIRED=$AUR_HELPER_PKG"
        printf 'These packages are not in the Arch repositories and need an AUR helper, and no working helper is installed:\n'
        for p in "${aur[@]}"; do printf '  %s\n' "$p"; done
        printf 'To install them, %s would be BUILT FROM SOURCE on this machine (git clone, then makepkg -si).\n' "$AUR_HELPER_PKG"
        printf 'AUR_BUILD_PACKAGE=%s\n' "$AUR_HELPER_PKG"
        printf 'AUR_BUILD_URL=%s\n' "$AUR_HELPER_URL"
        printf 'Nothing has been cloned, built or installed from the AUR yet.\n'

        answer="$assume"
        if [ -z "$answer" ]; then
            printf 'Build %s from source now? [y/N] ' "$AUR_HELPER_PKG"
            if ! IFS= read -r answer; then answer=""; fi
            printf '\n'
        fi
        case "$answer" in
            y|Y|yes|Yes|YES) answer="yes" ;;
            *)               answer="no"  ;;
        esac

        if [ "$answer" = "no" ]; then
            # Declined: clone nothing, build nothing, install no AUR package. This is its own
            # outcome, not a failed build.
            declined=1
            echo "AUR_BOOTSTRAP=declined"
            echo "Nothing was cloned and nothing was built. The AUR packages above were not installed."
            for p in "${aur[@]}"; do
                txn_add failed "$p" "aur" "not installed: the $AUR_HELPER_PKG source build was declined, so there is no AUR helper"
                n_failed=$((n_failed + 1))
            done
        else
            echo "AUR_BOOTSTRAP=building"
            $SUDO pacman -S --needed "${pac_noconfirm[@]}" base-devel git rust >/dev/null 2>&1
            build_tmp="$(mktemp -d "${TMPDIR:-/tmp}/hypr-rice-aur.XXXXXX")" || build_tmp=""
            build_ok=0
            if [ -n "$build_tmp" ] && git clone "$AUR_HELPER_URL" "$build_tmp/$AUR_HELPER_PKG" >/dev/null 2>&1; then
                ( cd "$build_tmp/$AUR_HELPER_PKG" && makepkg -si --noconfirm ) >/dev/null 2>&1
                helper_works "$AUR_HELPER_PKG" && build_ok=1
            fi
            [ -n "$build_tmp" ] && rm -rf "$build_tmp" 2>/dev/null
            if [ "$build_ok" -eq 1 ]; then
                helper="$AUR_HELPER_PKG"
                echo "AUR_BOOTSTRAP=built"
                txn_add built-from-source "$AUR_HELPER_PKG" "$AUR_HELPER_URL" "built here with makepkg -si"
            else
                echo "AUR_BOOTSTRAP=failed"
                for p in "${aur[@]}"; do
                    txn_add failed "$p" "aur" "not installed: the $AUR_HELPER_PKG source build failed, so there is no AUR helper"
                    n_failed=$((n_failed + 1))
                done
            fi
        fi
    else
        echo "AUR_HELPER=$helper"
    fi

    # AUR packages install ONE AT A TIME: one aborted build must not take the rest with it.
    if [ -n "$helper" ]; then
        for p in "${aur[@]}"; do
            out="$("$helper" -S --needed "${pac_noconfirm[@]}" "$p" 2>&1)"
            printf '%s\n' "$out"
            if installed_now "$p"; then
                txn_add installed "$p" "aur" ""
                n_installed=$((n_installed + 1))
            else
                txn_add failed "$p" "aur" "$(reason_for "$p" "$out")"
                n_failed=$((n_failed + 1))
            fi
        done
    fi
else
    echo "AUR_BOOTSTRAP=not-needed"
fi

# --- record it ---------------------------------------------------------------------------------
record_rc=0
rec_args=(record --route "$route" --helper "${helper:-none}")
[ -n "$label" ] && rec_args+=(--label "$label")
"$RECORDER" "${rec_args[@]}" < "$txn" || record_rc=$?

# --- verdict ------------------------------------------------------------------------------------
if [ "$declined" -eq 1 ]; then
    echo "INSTALL=declined-aur-build"
    exit 4
fi
if [ "$record_rc" -ne 0 ]; then
    # The packages landed, but the account of them did not. Do not call that a clean install.
    echo "INSTALL=partial (the packages above were installed, but the record was not written)"
    exit 1
fi
if [ "$n_failed" -gt 0 ] && [ "$n_installed" -eq 0 ] && [ "${#present[@]}" -eq 0 ]; then
    echo "INSTALL=failed"
    exit 1
fi
if [ "$n_failed" -gt 0 ]; then
    echo "INSTALL=partial"
    exit 0
fi
echo "INSTALL=ok"
exit 0

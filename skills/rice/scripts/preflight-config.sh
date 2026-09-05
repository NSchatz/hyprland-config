#!/usr/bin/env bash
# Verify a STAGED Hyprland config with the compositor's own offline parser, BEFORE
# a byte of it reaches the user's machine.
#
# Usage: preflight-config.sh <staging-dir>
#   <staging-dir>  Directory of generated config files: a hyprlang set (a main
#                  `hyprland.conf` plus other `*.conf`) or a lua set (a main
#                  `hyprland.lua` plus other `*.lua`). Same input as
#                  install-config.sh.
#
# This NEVER reads, and never depends on, the install target. The staged set is
# copied into a throwaway sandbox whose HOME is the sandbox, so the
# `source = ~/.config/hypr/<file>` lines the generator writes resolve to the
# STAGED companions rather than to whatever is installed on the machine. The
# verdict is therefore about the files in <staging-dir> and nothing else.
#
# Output (KEY=value lines, the convention every script here follows):
#   PREFLIGHT_BIN=<path of the compositor binary used>
#   PREFLIGHT_MAIN=<staged main config>
#   STAGED=<file>                 (one line per staged file that was checked)
#   PREFLIGHT_ERROR=<message>     (one line per parse error, naming STAGED paths)
#   PREFLIGHT_REASON=<slug>       (why it could not check / could not verify)
#   PREFLIGHT=<ok|errors|unverified|uncheckable>
#
# The four verdicts, and what each one means for the caller:
#   ok           the compositor parsed the staged set and found no errors.
#   errors       the compositor parsed the staged set and REPORTED ERRORS.
#                Do not install.
#   unverified   no compositor binary offering the offline check is on this host,
#                so nothing was proven either way. NOT the same as `ok`: the
#                caller carries on to install + live-test + rollback.
#   uncheckable  the check could not be run against the staged files at all - the
#                staged main config is missing/unreadable/ambiguous, or the
#                compositor rejected the invocation before parsing anything.
#                Refuse: a config nobody could check is not a config anyone
#                should install.
#
# Exit: 0 ok, 1 errors, 2 unverified, 3 uncheckable, 4 bad usage.
#
# The contract this relies on is MEASURED, not assumed - see
# `tests/integration/offline-check-contract.md` for the exact invocations, exit
# codes and output shapes, recorded against Hyprland 0.56.2 in the repo's own
# integration container.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=config-language.sh
source "$here/config-language.sh"

# Hyprland prints this line, verbatim, whenever it actually got as far as parsing
# a config. Its ABSENCE is how "you invoked me wrong" is told apart from "your
# config has errors" - both of which exit 1.
PARSE_MARKER='======== Config parsing result:'

staging="${1:-}"
if [ -z "$staging" ]; then
    echo "ERROR: usage: preflight-config.sh <staging-dir>" >&2
    exit 4
fi

uncheckable() {
    echo "ERROR: $1" >&2
    echo "PREFLIGHT_REASON=$2"
    echo "PREFLIGHT=uncheckable"
    exit 3
}

if [ ! -d "$staging" ]; then
    uncheckable "staging dir '$staging' does not exist" "staging-dir-missing"
fi
staging="$(cd "$staging" && pwd -P)" || uncheckable "staging dir '$staging' is unreadable" "staging-dir-unreadable"

# --- Which language did the generator stage? (same rule as install-config.sh) -----------------
shopt -s nullglob
has_conf=0; has_lua=0
[ -e "$staging/hyprland.conf" ] && has_conf=1
[ -e "$staging/hyprland.lua" ]  && has_lua=1

if [ "$has_conf" -eq 1 ] && [ "$has_lua" -eq 1 ]; then
    uncheckable "staging dir '$staging' holds BOTH a hyprland.lua and a hyprland.conf, so there is no single main config to check" \
                "ambiguous-staging"
fi
if [ "$has_lua" -eq 1 ]; then
    language="lua"
    staged_files=("$staging"/*.lua)
elif [ "$has_conf" -eq 1 ]; then
    language="hyprlang"
    staged_files=("$staging"/*.conf)
else
    uncheckable "staging dir '$staging' has no main config (no hyprland.lua and no hyprland.conf)" \
                "no-main-config"
fi

main_name="$(config_lang_file "$language")"
staged_main="$staging/$main_name"
if [ ! -f "$staged_main" ]; then
    uncheckable "staged main config '$staged_main' is not a regular file" "staged-main-not-a-file"
fi
if [ ! -r "$staged_main" ]; then
    uncheckable "staged main config '$staged_main' cannot be read" "staged-main-unreadable"
fi

# --- Is there a compositor binary that OFFERS the offline check? ------------------------------
# `command -v` is how detect-version.sh finds both entry points, so a stub on PATH
# exercises every branch below.
hypr_bin="$(command -v Hyprland 2>/dev/null || true)"
unverified() {
    echo "PREFLIGHT_REASON=$1"
    echo "PREFLIGHT=unverified ($2)"
    exit 2
}
if [ -z "$hypr_bin" ]; then
    unverified "no-compositor-binary" \
        "no Hyprland binary on PATH; the staged config was NOT checked - it is unverified, not verified"
fi

# The sandbox has to exist before the binary is run AT ALL: Hyprland aborts at the
# top of main() when XDG_RUNTIME_DIR is unset, before it parses a single argument,
# so even `--help` needs one.
sandbox="$(mktemp -d "${TMPDIR:-/tmp}/hypr-preflight.XXXXXX")" || {
    echo "ERROR: could not create a sandbox directory" >&2
    echo "PREFLIGHT_REASON=no-sandbox"
    echo "PREFLIGHT=uncheckable"
    exit 3
}
cleanup() { rm -rf "$sandbox"; }
trap cleanup EXIT

sandbox_home="$sandbox/home"
sandbox_run="$sandbox/run"
mirror="$sandbox_home/.config/hypr"
mkdir -p "$mirror" "$sandbox_run" "$sandbox/cache" || {
    echo "ERROR: could not populate the sandbox under '$sandbox'" >&2
    echo "PREFLIGHT_REASON=no-sandbox"
    echo "PREFLIGHT=uncheckable"
    exit 3
}
chmod 700 "$sandbox_run"

# `run_hypr <args...>` - the binary, with every path it touches pointed inside the
# sandbox. HOME is the load-bearing one: hyprlang expands `~` in a `source =` line
# from $HOME, which is what makes the staged companions - and not the installed
# ones - the files that decide the verdict.
run_hypr() {
    HOME="$sandbox_home" \
    XDG_RUNTIME_DIR="$sandbox_run" \
    XDG_CACHE_HOME="$sandbox/cache" \
    XDG_CONFIG_HOME="$sandbox_home/.config" \
        "$hypr_bin" "$@" 2>&1
}

if ! run_hypr --help | grep -q -- '--verify-config'; then
    unverified "no-offline-check" \
        "'$hypr_bin' does not offer --verify-config; the staged config was NOT checked - it is unverified, not verified"
fi

echo "PREFLIGHT_BIN=${hypr_bin}"
echo "PREFLIGHT_MAIN=${staged_main}"

# --- Mirror the staged SET into the sandbox ---------------------------------------------------
for f in ${staged_files[@]+"${staged_files[@]}"}; do
    if ! cp -f "$f" "$mirror/"; then
        uncheckable "staged file '$f' could not be read into the sandbox" "staged-file-unreadable"
    fi
    echo "STAGED=$(basename "$f")"
done

mirror_main="$mirror/$main_name"
mirror_real="$(cd "$mirror" && pwd -P)"

# --- Run the compositor's own offline check ---------------------------------------------------
out="$(run_hypr --verify-config -c "$mirror_main")"
rc=$?

# Fold the sandbox back onto the staging dir so every path the user reads is a path
# they can open. Both spellings: the mirror as we built it, and its canonical form
# (Hyprland canonicalizes the -c argument).
report="$(printf '%s\n' "$out" \
    | sed -e "s|${mirror_real}/|${staging}/|g" -e "s|${mirror}/|${staging}/|g")"

# The marker is the whole discriminator. No marker => the binary never parsed
# anything: a rejected invocation, a missing runtime dir, an abort. Exit 1 alone
# cannot tell that from a config with errors, and treating it as "your config is
# broken" would turn every packaging change into a false refusal.
if ! printf '%s\n' "$report" | grep -qF "$PARSE_MARKER"; then
    printf '%s\n' "$report" | sed 's/^/  /' >&2
    uncheckable "'$hypr_bin' did not parse the staged config (exit $rc, no parsing result reported); the invocation was rejected before any parsing happened" \
                "invocation-rejected"
fi

# Everything below the marker is the parser's own verdict.
body="$(printf '%s\n' "$report" | sed -n "/$(printf '%s' "$PARSE_MARKER" | sed 's/[][\.*^$/]/\\&/g')/,\$p" \
        | tail -n +2 | sed '/^[[:space:]]*$/d')"

# An unreadable file reaches the parser and comes back as a parse result, but it is
# not a config that was checked and found wanting - nothing was checked.
if printf '%s\n' "$body" | grep -qF 'File failed to open'; then
    uncheckable "'$staged_main' reached the parser but could not be opened" "staged-main-unreadable"
fi

if [ "$rc" -eq 0 ] && printf '%s\n' "$body" | grep -qxF 'config ok'; then
    echo "PREFLIGHT=ok (the compositor's own offline check parsed the staged config with no errors)"
    exit 0
fi

while IFS= read -r line; do
    [ -n "$line" ] && echo "PREFLIGHT_ERROR=${line}"
done <<< "$body"
echo "The errors above are in the STAGED files under ${staging}; nothing has been installed."
echo "PREFLIGHT=errors"
exit 1

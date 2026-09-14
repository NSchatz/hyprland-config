#!/usr/bin/env bash
# Syntax-check a shell rc file WITHOUT executing it - the "test after every change" step for
# shell configs. Never sources the file (so it can't run side effects); only parses it.
#
# Usage:
#   verify-shell.sh <rcfile> [bash|zsh|fish]
#   Shell is inferred from the filename if not given.
#
# Example:
#   verify-shell.sh ~/.bashrc
#
# Options: -h, --help, help
# Subcommands: none
#
# Output:
#   VERIFY_SHELL=ok (<shell>)
#   VERIFY_SHELL=errors (<shell>)   followed by the parser output
#   VERIFY_SHELL=skipped (<shell> not installed)
#   VERIFY_SHELL=error (...)        bad usage / missing file
#
# Exit codes:
#   0  ok: the rc file parses
#   1  verdict: the rc file has parse errors
#   2  usage: no rcfile given, or a shell name this script cannot use
#   3  capability: the interpreter for that shell is not installed, so nothing was parsed
#   5  input: the rc file it was given is missing
set -uo pipefail

case "${1:-}" in   # [cli-parser]
    -h|--help|help)
        sed -n '2,${/^#/!q;s/^#\{1,2\} \{0,1\}//p}' "$0"
        exit 0 ;;   # rc=ok
esac

f="${1:-}"
if [ -z "$f" ]; then
    echo "VERIFY_SHELL=error (usage: verify-shell.sh <rcfile> [shell])"; exit 2   # rc=usage
fi
case "$f" in "~"*) f="${HOME}${f#\~}";; esac
if [ ! -f "$f" ]; then
    echo "VERIFY_SHELL=error (no such file: $f)"; exit 5   # rc=input
fi

shell="${2:-}"
if [ -z "$shell" ]; then
    case "$f" in
        *.zshrc|*.zshenv|*.zprofile|*zsh*) shell=zsh ;;
        *config.fish|*.fish|*fish*)        shell=fish ;;
        *)                                  shell=bash ;;
    esac
fi

case "$shell" in
    bash)
        out="$(bash -n "$f" 2>&1)"; rc=$? ;;
    zsh)
        if ! command -v zsh >/dev/null 2>&1; then
            # Nothing was parsed: the verdict is absent, not negative. A caller that reads this
            # as "the rc file is fine" would be reading a check that never ran.
            echo "VERIFY_SHELL=skipped (zsh not installed)"; exit 3   # rc=capability
        fi
        out="$(zsh -n "$f" 2>&1)"; rc=$? ;;
    fish)
        if ! command -v fish >/dev/null 2>&1; then
            echo "VERIFY_SHELL=skipped (fish not installed)"; exit 3   # rc=capability
        fi
        # fish parses without running when given --no-execute
        out="$(fish --no-execute "$f" 2>&1)"; rc=$? ;;
    *)
        echo "VERIFY_SHELL=error (unknown shell: $shell)"; exit 2 ;;   # rc=usage
esac

if [ "$rc" -eq 0 ]; then
    echo "VERIFY_SHELL=ok ($shell)"
    exit 0   # rc=ok
fi
echo "VERIFY_SHELL=errors ($shell)"
printf '%s\n' "$out"
exit 1   # rc=verdict

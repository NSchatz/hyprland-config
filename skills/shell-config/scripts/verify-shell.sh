#!/usr/bin/env bash
# Syntax-check a shell rc file WITHOUT executing it — the "test after every change" step for
# shell configs. Never sources the file (so it can't run side effects); only parses it.
#
# Usage: verify-shell.sh <rcfile> [bash|zsh|fish]
#   Shell is inferred from the filename if not given.
#
# Output:
#   VERIFY_SHELL=ok (<shell>)
#   VERIFY_SHELL=errors (<shell>)   followed by the parser output
#   VERIFY_SHELL=skipped (<shell> not installed)
#   VERIFY_SHELL=error (...)        bad usage / missing file
# Exit: 0 ok, 1 errors, 2 skipped/usage.
set -uo pipefail

f="${1:-}"
if [ -z "$f" ]; then
    echo "VERIFY_SHELL=error (usage: verify-shell.sh <rcfile> [shell])"; exit 2
fi
case "$f" in "~"*) f="${HOME}${f#\~}";; esac
if [ ! -f "$f" ]; then
    echo "VERIFY_SHELL=error (no such file: $f)"; exit 2
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
            echo "VERIFY_SHELL=skipped (zsh not installed)"; exit 2
        fi
        out="$(zsh -n "$f" 2>&1)"; rc=$? ;;
    fish)
        if ! command -v fish >/dev/null 2>&1; then
            echo "VERIFY_SHELL=skipped (fish not installed)"; exit 2
        fi
        # fish parses without running when given --no-execute
        out="$(fish --no-execute "$f" 2>&1)"; rc=$? ;;
    *)
        echo "VERIFY_SHELL=error (unknown shell: $shell)"; exit 2 ;;
esac

if [ "$rc" -eq 0 ]; then
    echo "VERIFY_SHELL=ok ($shell)"
    exit 0
fi
echo "VERIFY_SHELL=errors ($shell)"
printf '%s\n' "$out"
exit 1

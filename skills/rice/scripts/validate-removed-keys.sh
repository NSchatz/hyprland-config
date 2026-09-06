#!/usr/bin/env bash
# Does this GENERATED config carry a key the reference layer documents as
# REMOVED at the target version?
#
# A key removed upstream is not a warning on the machine it lands on: it is a
# hard parse error that fails the whole reload. This check is static, offline,
# and reads the same version-cliff ledger the currency check reads - the
# `Removed keys` table of `references/_shared/version-matrix.md`. It needs NO
# Hyprland binary and NO running compositor, so it reaches a verdict on hosts
# where `preflight-config.sh` can only say `unverified` and `verify-config.sh`
# can only say `skipped`. It sits BESIDE those, never instead of them.
#
# Usage:
#   validate-removed-keys.sh <staging-dir> [--version VER] [--ledger FILE] [--root DIR]
#   validate-removed-keys.sh --supported-targets [--ledger FILE] [--root DIR]
#
#   <staging-dir>        the generated set (same input as install-config.sh)
#   --version VER        the TARGET Hyprland version. Overrides detection.
#   --supported-targets  print every version the plugin claims to support, one
#                        per line, enumerated from the ledger.
#
# Env: HYPR_VERSION  same as --version (and what detect-version.sh emits).
#
# Output (KEY=value lines, the convention every script here follows):
#   REMOVED_KEYS_LEDGER=<path>
#   REMOVED_KEYS_TARGET=<x.y.z|unknown>
#   REMOVED_KEYS_TARGET_SOURCE=<supplied|detected|none>
#   REMOVED_KEYS_RULES=<n>            removed-key rows read from the ledger
#   REMOVED_KEYS_CHECKED=<file>       one per staged file actually scanned
#   REMOVED_KEY=<key> | <file>:<line> | removed at <ver> | use <replacement>
#   REMOVED_KEYS=<ok|found|unknown-target-version|uncheckable>
#
# The four verdicts:
#   ok                      every staged file was scanned and no key removed at
#                           or before the target appears in any of them.
#   found                   at least one does. The REMOVED_KEY= lines name the
#                           key, the file and line, and the release that removed
#                           it. Do not install.
#   unknown-target-version  the target version could not be determined. NOTHING
#                           was validated and this is NOT a pass: the check
#                           refuses to invent a target, exactly as
#                           config-language.sh refuses to invent a language.
#   uncheckable             the staged set or the ledger could not be read, so
#                           no verdict was reached about anything.
#
# Exit: 0 ok, 1 removed keys found, 2 bad usage / uncheckable,
#       3 the target version is unknown.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=version-ledger.sh
source "$here/version-ledger.sh"

root="$(cd "$here/../../.." && pwd)"
ledger=""
staging=""
version="${HYPR_VERSION:-}"
version_source="none"
[ -n "$version" ] && version_source="supplied"
list_targets=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --version)
            [ "$#" -ge 2 ] || { echo "ERROR: --version needs a value" >&2; exit 2; }
            version="$2"; version_source="supplied"; shift 2 ;;
        --ledger)
            [ "$#" -ge 2 ] || { echo "ERROR: --ledger needs a value" >&2; exit 2; }
            ledger="$2"; shift 2 ;;
        --root)
            [ "$#" -ge 2 ] || { echo "ERROR: --root needs a value" >&2; exit 2; }
            root="$2"; shift 2 ;;
        --supported-targets)
            list_targets=1; shift ;;
        -h|--help)
            sed -n '2,50p' "$0"; exit 0 ;;
        -*)
            echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
        *)
            if [ -n "$staging" ]; then
                echo "ERROR: unexpected extra argument: $1" >&2; exit 2
            fi
            staging="$1"; shift ;;
    esac
done

[ -n "$ledger" ] || ledger="$(ledger_default_path "$root")"

uncheckable() {
    echo "ERROR: $1" >&2
    echo "REMOVED_KEYS=uncheckable"
    exit 2
}

if [ ! -f "$ledger" ] || [ ! -r "$ledger" ]; then
    uncheckable "the version-cliff ledger '$ledger' is missing or unreadable, so there is no removed-key set to check against"
fi

if [ "$list_targets" -eq 1 ]; then
    if ! ledger_supported_targets "$ledger"; then
        uncheckable "the ledger '$ledger' does not declare both a support-floor and a newest-release, so the supported targets cannot be enumerated"
    fi
    exit 0
fi

if [ -z "$staging" ]; then
    echo "ERROR: usage: validate-removed-keys.sh <staging-dir> [--version VER]" >&2
    exit 2
fi
if [ ! -d "$staging" ] || [ ! -r "$staging" ]; then
    uncheckable "staging dir '$staging' does not exist or cannot be read"
fi

echo "REMOVED_KEYS_LEDGER=${ledger}"

rules="$(ledger_removed_keys "$ledger" 2>/dev/null || true)"
rule_count="$(printf '%s' "$rules" | grep -c . || true)"
echo "REMOVED_KEYS_RULES=${rule_count}"
if [ "$rule_count" -eq 0 ]; then
    uncheckable "the ledger '$ledger' declares ZERO removed keys. A validator with no rules would pass everything; that is not a verdict"
fi

# --- The TARGET version. Detected, supplied, or REFUSED - never assumed. -----------------------
if [ -z "$version" ] && [ -f "$here/detect-version.sh" ]; then
    version="$(bash "$here/detect-version.sh" 2>/dev/null | sed -n 's/^HYPR_VERSION=//p' | head -n1)"
    [ -n "$version" ] && [ "$version" != "unknown" ] && version_source="detected"
fi
case "${version:-}" in
    ""|unknown|UNKNOWN) version=""; version_source="none" ;;
esac

if [ -z "$version" ]; then
    echo "REMOVED_KEYS_TARGET=unknown"
    echo "REMOVED_KEYS_TARGET_SOURCE=none"
    echo "ERROR: the target Hyprland version could not be determined (no --version, no HYPR_VERSION, and detect-version.sh found neither hyprctl nor Hyprland). Whether a key is removed depends entirely on the target, so NOTHING was validated here. This is not a pass: supply the target with --version <x.y.z> or HYPR_VERSION=<x.y.z>." >&2
    echo "REMOVED_KEYS=unknown-target-version"
    exit 3
fi
echo "REMOVED_KEYS_TARGET=${version}"
echo "REMOVED_KEYS_TARGET_SOURCE=${version_source}"

# --- The staged set ---------------------------------------------------------------------------
staged=()
while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ ! -r "$f" ]; then
        uncheckable "staged file '$f' cannot be read, so the staged set was not checked"
    fi
    staged+=("$f")
done < <(find "$staging" \( -type f -o -type l \) \( -name '*.conf' -o -name '*.lua' \) -print | sort)

if [ "${#staged[@]}" -eq 0 ]; then
    uncheckable "staging dir '$staging' holds no *.conf and no *.lua files, so there was nothing to validate"
fi

# `config_key_paths <file> <conf|lua>` - every `<block>:<...>:<key>` a config
# file sets, with the line it is set on. One scanner for both languages: they
# differ only in the comment marker and in whether a block is written `name {`
# (hyprlang) or `name = {` (lua), and the pass below handles both.
config_key_paths() {
    awk -v lang="$2" '
        function push(name) { depth++; stack[depth] = name }
        function pop() { if (depth > 0) { delete stack[depth]; depth-- } }
        function keypath(leaf,   i, p) {
            p = ""
            for (i = 1; i <= depth; i++) if (stack[i] != "") p = p stack[i] ":"
            return p leaf
        }
        function flush() {
            if (awaiting && pending != "") print pending_line "\t" keypath(pending)
            pending = ""; awaiting = 0; buf = ""
        }
        BEGIN { depth = 0; pending = ""; buf = ""; awaiting = 0; pending_line = 0 }
        {
            line = $0
            if (lang == "lua") { sub(/--.*$/, "", line) } else { sub(/#.*$/, "", line) }
            n = length(line)
            for (i = 1; i <= n; i++) {
                c = substr(line, i, 1)
                if (c ~ /[A-Za-z0-9_.:-]/) { buf = buf c; continue }
                if (c == "=") { pending = buf; pending_line = FNR; buf = ""; awaiting = 1; continue }
                if (c == "{") {
                    push(pending != "" ? pending : buf)
                    pending = ""; buf = ""; awaiting = 0
                    continue
                }
                if (c == "}") { flush(); pop(); continue }
                if (c == "," || c == ";") { flush(); continue }
                if (c == " " || c == "\t") { continue }
                if (awaiting) { continue }
                buf = ""
            }
            flush()
        }
        END { flush() }
    ' "$1"
}

found=0
for f in ${staged[@]+"${staged[@]}"}; do
    echo "REMOVED_KEYS_CHECKED=${f}"
    case "$f" in
        *.lua) lang="lua" ;;
        *)     lang="conf" ;;
    esac
    paths="$(config_key_paths "$f" "$lang")"
    [ -n "$paths" ] || continue
    while IFS="$LEDGER_FS" read -r key removed_at replacement _src; do
        [ -n "${key:-}" ] || continue
        # Version-aware, not a blanket ban: a key removed at 0.55 is perfectly
        # valid on a 0.54 target and must pass there.
        [ "$(ledger_vercmp "$version" "$removed_at")" = "-1" ] && continue
        while IFS=$'\t' read -r lno path; do
            [ "$path" = "$key" ] || continue
            echo "REMOVED_KEY=${key} | ${f}:${lno} | removed at ${removed_at} | use ${replacement}"
            found=$((found + 1))
        done <<< "$paths"
    done <<< "$rules"
done

if [ "$found" -gt 0 ]; then
    echo "The generated config above targets Hyprland ${version}, where each key named is a hard parse error. Nothing has been installed."
    echo "REMOVED_KEYS=found"
    exit 1
fi

echo "REMOVED_KEYS=ok (${#staged[@]} staged file(s) checked against ${rule_count} removed-key rule(s) for target ${version})"
exit 0

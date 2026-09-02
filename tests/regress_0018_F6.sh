#!/usr/bin/env bash
# S0018 impl-gate loop 2 - MUTATION check on a throwaway COPY of the tree.
# Does each shipped test actually fail when the behaviour it names regresses?
# The real checkout is never touched: every mutation is applied to a copy under
# a scratch dir.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base="$(mktemp -d "${TMPDIR:-/tmp}/regress0018F6.XXXXXX")"

# `mutate <name> <filter> <sed-target-file> <sed-expr...>`
run_mutant() {
    local name="$1" filter="$2" file="$3"; shift 3
    local copy="$base/$name"
    mkdir -p "$copy"
    cp -a "$ROOT"/. "$copy"/ 2>/dev/null
    rm -rf "$copy/.git"
    local e
    for e in "$@"; do
        sed -i "$e" "$copy/$file"
    done
    echo
    echo "######## MUTANT: $name  (filter: $filter) ########"
    echo "--- diff of the mutation:"
    diff -u "$ROOT/$file" "$copy/$file" | sed -n '1,40p'
    echo "--- suite result on the mutant:"
    ( cd "$copy" && bash tests/run.sh "$filter" 2>&1 | grep -E '✗|passed|failed' | head -25 )
    echo "--- run.sh exit: ${PIPESTATUS[0]}"
}

# 1. Drop the dangling-symlink arm of the shadow guard (what F2 case 3 pins).
run_mutant m1_symlink_guard regress_0018_F2 skills/rice/scripts/config-language.sh \
    's/^    \[ -e "\${1:-}" \] || \[ -L "\${1:-}" \]$/    [ -e "${1:-}" ]/'

# 2. Remove the HYPR_DIR rebase of a `source = ~\/...` line (what F3 pins).
run_mutant m2_source_rebase regress_0018_F3 skills/rice/scripts/migrate-config.sh \
    's/^    if \[ -n "\$home_config_dir" \] \&\& \[ "\$target" != "\$home_config_dir" \]; then$/    if false; then/'

# 3. Make an unmappable-but-parseable construct a parse error again (what F1 pins).
run_mutant m3_unmapped_is_error regress_0018_F1 skills/rice/scripts/migrate-config.sh \
    's/^    UNMAPPED+=("\${in}:\${lineno}: \${why}: \${text}")$/    PARSE_ERRORS+=("${in}:${lineno}: ${why}: ${text}")/'

# 4. Delete the shadow check entirely (what AC-1 pins in test_lua_install.sh).
run_mutant m4_no_shadow_check lua_install skills/rice/scripts/install-config.sh \
    's/^if \[ "\$language" = "hyprlang" \] \&\& config_lang_present "\$target\/hyprland.lua"; then$/if false; then/'

# 5. Assume lua when the version is unknown (what AC-5 pins in test_lua_emit.sh).
run_mutant m5_assume_lua lua_emit skills/rice/scripts/config-language.sh \
    's/^        ""|unknown|UNKNOWN) printf '"'"'unknown\\n'"'"'; return 0 ;;$/        ""|unknown|UNKNOWN) printf '"'"'lua\\n'"'"'; return 0 ;;/'

# 6. Drop the provenance header from the emitted configs (what AC-3 pins).
run_mutant m6_no_provenance lua_emit skills/rice/scripts/emit-config.sh \
    's/^    config_lang_provenance hyprlang$/    true/' \
    's/^    config_lang_provenance lua$/    true/'

# 7. Delete the .conf after converting it (what AC-4 forbids).
run_mutant m7_delete_conf lua_migrate skills/rice/scripts/migrate-config.sh \
    's/^    echo "KEPT=\${CONVERTED_FROM\[\$i\]}"$/    rm -f "${CONVERTED_FROM[$i]}"; echo "KEPT=${CONVERTED_FROM[$i]}"/'

echo
echo "scratch=$base"

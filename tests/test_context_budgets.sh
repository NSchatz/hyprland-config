#!/usr/bin/env bash
# Context budgets - every file that can be LOADED INTO A MODEL'S CONTEXT has a ceiling, and
# the ceiling is enforced here rather than trusted.
#
# Why this is a test and not a style note: this plugin's output quality degrades when the
# authoring context is padded. A component-writer that loads 39k tokens of reference to emit
# one 200-line config is not reading carefully; it is skimming. Anthropic's own skill-authoring
# guidance puts a SKILL.md body under 500 lines and warns that a file referenced past the first
# level gets PARTIALLY read (head -100) rather than read whole - which is how a writer ends up
# acting on half a recipe.
#
# The budgets below are the contract. They are deliberately checkable offline and deliberately
# boring: bytes/4 as a token proxy, lines, and the presence of a table of contents.
#
# Scope: only files a model READS. Executed scripts (scripts/*.sh, skills/*/scripts/*.sh) are
# EXEMPT - they run through bash and cost nothing but their stdout. Tests are exempt for the
# same reason. Templates (.tmpl) are rendered, not read. That exemption is the whole reason
# "move it into a script" is a legitimate answer to an over-budget file.
#
# Grades:
#   B-1  a SKILL.md body stays under 500 lines and 5000 tokens
#   B-2  a reference/agent .md stays under its token ceiling
#   B-3  a .md over 100 lines carries a table of contents, so a partial read still sees scope
#   B-4  research citations do not sit in the load path
#   B-5  the budget file itself lists every known exception, so a waiver is visible

# ---- the contract ---------------------------------------------------------------------------
SKILL_MAX_LINES=500
SKILL_MAX_TOK=5000
REF_MAX_TOK=4000
AGENT_MAX_TOK=4000
TOC_MIN_LINES=100
# What ONE writer agent loads to author ONE surface: the component's common.md plus the single
# tools/<tool>.md its pick names. This is the number that actually governs output quality - a
# per-file ceiling can be met by a component that still makes an agent read five files.
SURFACE_MAX_TOK=12000

# Token proxy: bytes/4. Crude, stable, and needs no tokenizer on the box.
tok() { echo $(( $(wc -c < "$1") / 4 )); }
lines() { wc -l < "$1"; }
rel() { printf '%s' "${1#"$PLUGIN_ROOT"/}"; }

# Files granted an explicit, reasoned waiver. A waiver is a decision, so it is written down
# here with its reason and shows up in the summary - never a silent pass.
# Format: "<repo-relative path>|<reason>"
BUDGET_WAIVERS=(
)

is_waived() {
    local p="$1"
    for w in "${BUDGET_WAIVERS[@]}"; do
        [ "${w%%|*}" = "$p" ] && return 0
    done
    return 1
}

# ---- B-1  SKILL.md bodies -------------------------------------------------------------------
over_skill=()
while IFS= read -r f; do
    r="$(rel "$f")"
    l="$(lines "$f")"; t="$(tok "$f")"
    if [ "$l" -gt "$SKILL_MAX_LINES" ] || [ "$t" -gt "$SKILL_MAX_TOK" ]; then
        is_waived "$r" || over_skill+=("$r (${l} lines, ~${t} tok)")
    fi
done < <(find "$PLUGIN_ROOT/skills" -name 'SKILL.md' | sort)

if [ "${#over_skill[@]}" -eq 0 ]; then
    pass "B-1: every SKILL.md is within ${SKILL_MAX_LINES} lines / ~${SKILL_MAX_TOK} tok"
else
    fail "B-1: every SKILL.md is within ${SKILL_MAX_LINES} lines / ~${SKILL_MAX_TOK} tok" \
        "$(printf '%s\n' "${over_skill[@]}")"
fi

# ---- B-2  reference files -------------------------------------------------------------------
over_ref=()
while IFS= read -r f; do
    r="$(rel "$f")"
    t="$(tok "$f")"
    if [ "$t" -gt "$REF_MAX_TOK" ]; then
        is_waived "$r" || over_ref+=("$r (~${t} tok, over by $((t - REF_MAX_TOK)))")
    fi
    # `common.md` is a deliberate aggregate: it is never read alone, only paired with one
    # tools/<tool>.md. B-6 governs that pair, which is the load that actually happens.
done < <(find "$PLUGIN_ROOT/skills" -name '*.md' ! -name 'SKILL.md' ! -name 'common.md' | sort)

if [ "${#over_ref[@]}" -eq 0 ]; then
    pass "B-2: every reference .md is within ~${REF_MAX_TOK} tok"
else
    fail "B-2: every reference .md is within ~${REF_MAX_TOK} tok ($((${#over_ref[@]})) over)" \
        "$(printf '%s\n' "${over_ref[@]}")"
fi

# ---- B-2b  agent prompts --------------------------------------------------------------------
over_agent=()
while IFS= read -r f; do
    r="$(rel "$f")"
    t="$(tok "$f")"
    if [ "$t" -gt "$AGENT_MAX_TOK" ]; then
        is_waived "$r" || over_agent+=("$r (~${t} tok)")
    fi
done < <(find "$PLUGIN_ROOT/agents" -name '*.md' | sort)

if [ "${#over_agent[@]}" -eq 0 ]; then
    pass "B-2b: every agent prompt is within ~${AGENT_MAX_TOK} tok"
else
    fail "B-2b: every agent prompt is within ~${AGENT_MAX_TOK} tok" \
        "$(printf '%s\n' "${over_agent[@]}")"
fi

# ---- B-3  table of contents on anything long enough to be partially read --------------------
# A file past ~100 lines can be previewed rather than read whole. Without a contents block the
# preview hides the scope of what was skipped, and the reader does not know it read half.
no_toc=()
while IFS= read -r f; do
    r="$(rel "$f")"
    [ "$(lines "$f")" -gt "$TOC_MIN_LINES" ] || continue
    is_waived "$r" && continue
    grep -qiE '^#{1,3} *(contents|table of contents|in this file)' "$f" || no_toc+=("$r ($(lines "$f") lines)")
done < <(find "$PLUGIN_ROOT/skills" "$PLUGIN_ROOT/agents" -name '*.md' | sort)

if [ "${#no_toc[@]}" -eq 0 ]; then
    pass "B-3: every .md over ${TOC_MIN_LINES} lines has a table of contents"
else
    fail "B-3: every .md over ${TOC_MIN_LINES} lines has a table of contents ($((${#no_toc[@]})) without)" \
        "$(printf '%s\n' "${no_toc[@]}" | head -40)"
fi

# ---- B-4  citations are not in the load path -------------------------------------------------
# Research provenance is why a recommendation is trustworthy, and it belongs in the repo. It
# does not belong in the file a writer agent loads to emit a config: it is read-once-by-a-human
# content sitting in a read-every-run file.
with_sources=()
while IFS= read -r f; do
    r="$(rel "$f")"
    is_waived "$r" && continue
    # A bare `Sources` heading, optionally qualified by a parenthetical (`### Sources (eww)`).
    # NOT `### Sources & licensing`, which is content about licensing, not a citation block.
    grep -qE '^#{1,3} *Sources *(\([^)]*\))? *$' "$f" && with_sources+=("$r")
done < <(find "$PLUGIN_ROOT/skills" -name '*.md' | sort)

if [ "${#with_sources[@]}" -eq 0 ]; then
    pass "B-4: no load-path reference carries an inline Sources section"
else
    src_tok=0
    for f in "${with_sources[@]}"; do
        n="$(awk '/^#{1,3} *Sources *(\([^)]*\))? *$/{f=1;next} /^#{1,3} /{f=0} f' "$PLUGIN_ROOT/$f" | wc -c)"
        src_tok=$(( src_tok + n / 4 ))
    done
    fail "B-4: no load-path reference carries an inline Sources section ($((${#with_sources[@]})) files, ~${src_tok} tok)" \
        "$(printf '%s\n' "${with_sources[@]}" | head -40)"
fi

# ---- B-6  what ONE writer loads for ONE surface ----------------------------------------------
# For every component sharded by tool, the real load is common.md + the single tools/<tool>.md
# the interview selected. Measure the worst case (the largest tool file) - that is the writer
# that has the least room left for the answers, the palette and its own reasoning.
over_surface=()
checked_surfaces=0
while IFS= read -r toolsdir; do
    comp="$(dirname "$toolsdir")"
    cname="$(basename "$comp")"
    # The shared half of the pair is `common.md` where a component has one; where it does not
    # (waybar keeps its flat recipe set beside looks/), the shared half IS that flat set. Not
    # accounting for it is how waybar measured as 1.5k while really costing 19k.
    common_tok=0
    if [ -f "$comp/common.md" ]; then
        common_tok="$(tok "$comp/common.md")"
    else
        for f in template styling validation gotchas reload; do
            [ -f "$comp/$f.md" ] && common_tok=$(( common_tok + $(tok "$comp/$f.md") ))
        done
    fi
    worst=0; worst_name=""
    for tf in "$toolsdir"/*.md; do
        [ -f "$tf" ] || continue
        t="$(tok "$tf")"
        if [ "$t" -gt "$worst" ]; then worst="$t"; worst_name="$(basename "$tf" .md)"; fi
    done
    [ "$worst" -gt 0 ] || continue
    checked_surfaces=$((checked_surfaces + 1))
    total=$(( common_tok + worst ))
    if [ "$total" -gt "$SURFACE_MAX_TOK" ] && ! is_waived "surface:$cname"; then
        over_surface+=("$cname (worst: $worst_name) ~${total} tok = common ${common_tok} + tool ${worst}, over by $((total - SURFACE_MAX_TOK))")
    fi
done < <(find "$PLUGIN_ROOT/skills" -type d -name 'tools' -o -type d -name 'looks' | sort)

# Surfaces with no variant dir at all: the writer reads the component's flat recipe set. These
# are measured too - a surface that is merely unsharded must not also be unmeasured, which is
# how waybar sat at 21k without the gate noticing.
while IFS= read -r comp; do
    cname="$(basename "$comp")"
    [ -d "$comp/tools" ] || [ -d "$comp/looks" ] && continue
    flat=0
    for f in template styling validation gotchas reload; do
        [ -f "$comp/$f.md" ] && flat=$(( flat + $(tok "$comp/$f.md") ))
    done
    [ "$flat" -gt 0 ] || continue
    checked_surfaces=$((checked_surfaces + 1))
    if [ "$flat" -gt "$SURFACE_MAX_TOK" ] && ! is_waived "surface:$cname"; then
        over_surface+=("$cname (unsharded) ~${flat} tok flat recipe set, over by $((flat - SURFACE_MAX_TOK))")
    fi
done < <(find "$PLUGIN_ROOT/skills/rice/references/components" -mindepth 1 -maxdepth 1 -type d | sort)

if [ "$checked_surfaces" -eq 0 ]; then
    skip "B-6: per-surface writer load" "no tool-sharded components found"
elif [ "${#over_surface[@]}" -eq 0 ]; then
    pass "B-6: every sharded surface loads within ~${SURFACE_MAX_TOK} tok (${checked_surfaces} checked, worst case each)"
else
    fail "B-6: every sharded surface loads within ~${SURFACE_MAX_TOK} tok (${checked_surfaces} checked)" \
        "$(printf '%s\n' "${over_surface[@]}")"
fi

# ---- B-5  waivers are visible ----------------------------------------------------------------
if [ "${#BUDGET_WAIVERS[@]}" -eq 0 ]; then
    pass "B-5: no budget waivers are in force"
else
    for w in "${BUDGET_WAIVERS[@]}"; do
        p="${w%%|*}"; why="${w#*|}"
        if [ -e "$PLUGIN_ROOT/$p" ]; then
            skip "B-5: waived $p" "$why"
        else
            fail "B-5: waiver names a file that exists" "stale waiver: $p"
        fi
    done
fi

# ---- B-7  markdown structural integrity ------------------------------------------------------
# Every fenced code block is closed. An odd number of fence markers means a block was cut in
# half, which renders the rest of the file as code and makes a heading parser believe it is
# inside a fence from there on - the file then looks like it has one section when it has seven.
#
# This is not hypothetical: a refactor that removed moved blocks by matching line CONTENT rather
# than line POSITION deleted every ```css fence that also appeared inside a moved block, taking
# waybar/styling.md from 26 fence markers to 1. Nothing failed at the time.
unbalanced=()
while IFS= read -r f; do
    # `grep -c` prints 0 AND exits 1 when there are no matches, so a `|| echo 0` fallback
    # appends a second zero and breaks the arithmetic below - which silently passed this check.
    n="$(grep -c '^```' "$f" 2>/dev/null)" || true
    [ -n "$n" ] || n=0
    if [ $((n % 2)) -ne 0 ]; then
        unbalanced+=("$(rel "$f") ($n fence markers)")
    fi
done < <(find "$PLUGIN_ROOT/skills" "$PLUGIN_ROOT/agents" -name '*.md' | sort)

if [ "${#unbalanced[@]}" -eq 0 ]; then
    pass "B-7: every markdown file closes its code fences"
else
    fail "B-7: every markdown file closes its code fences" "$(printf '%s\n' "${unbalanced[@]}")"
fi

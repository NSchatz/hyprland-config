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
#   B-2  a reference file stays under a HARD ceiling; the soft budget is reported, not failed
#   B-3  a .md over 100 lines carries a table of contents, so a partial read still sees scope
#   B-4  research citations do not sit in the load path
#   B-5  the budget file itself lists every known exception, so a waiver is visible

# ---- the contract ---------------------------------------------------------------------------
SKILL_MAX_LINES=500
SKILL_MAX_TOK=5000
# Two ceilings for reference files, on purpose. B-6 measures what an agent actually LOADS for a
# task, and that is the number that governs output quality. A per-file ceiling measures something
# weaker - file size in isolation - so chasing it would mean splitting reference tables that are
# looked up, not read end to end (`version-matrix.md`, `palettes.md`, `deprecations.md`) and are
# doing no harm. So: over the soft budget is REPORTED, over the hard one FAILS, because a single
# file past ~8k cannot be read whole alongside anything else.
REF_SOFT_TOK=4000
# The hard ceiling is tied to SURFACE_MAX_TOK below, on purpose rather than picked: no SINGLE
# file may cost more than an entire surface is budgeted to load. That catches a file which has
# grown pathologically (widgets/styling.md was 20,349 tok before it was sharded) without
# demanding that a mature design library be chopped up for its own sake.
REF_HARD_TOK=12000
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
    # These four surfaces were measured against a shard and the shard does not pay. Recording
    # that here, with the number, is the point: a gate that stays red forever teaches people to
    # ignore it, which is the same reason the currency check REPORTS staleness instead of
    # failing on it. Each of these is revisited when its content changes, not before.
    "surface:waybar|19,714 tok. Sharded by bar.archetype into looks/ (-10%). The rest is
     'Battle-tested techniques' (4,485) and 'Design anatomy' - the attributed catalog of
     concrete moves that keeps generated bars from looking stock. Sharding it away wins the
     budget and loses the point."
    "surface:shell-prompt|17,150 tok. Measured against a shell x prompt-engine shard: a
     fish+starship+fastfetch writer would load 15,092 (-12%) at the cost of a four-file routing
     rule (common + shell + engine + fetch) that is easy to get wrong. Not worth the trade."
    "surface:look-feel|15,466 tok. No shard axis: this is the Hyprland decoration recipe and
     every writer needs gaps, borders, rounding, blur and animations. Only the layout blocks
     (~59 lines) are answer-selected, which is not enough to shard on."
    "surface:keybinds|12,619 tok, 619 over. Same: the bind table and dispatcher catalog are
     needed whole. Not worth a shard for 5%."
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
over_hard=()
while IFS= read -r f; do
    r="$(rel "$f")"
    t="$(tok "$f")"
    is_waived "$r" && continue
    if [ "$t" -gt "$REF_HARD_TOK" ]; then
        over_hard+=("$r (~${t} tok, over the HARD ceiling by $((t - REF_HARD_TOK)))")
    elif [ "$t" -gt "$REF_SOFT_TOK" ]; then
        over_ref+=("$r (~${t} tok)")
    fi
    # `common.md` is a deliberate aggregate: it is never read alone, only paired with one
    # tools/<tool>.md. B-6 governs that pair, which is the load that actually happens.
done < <(find "$PLUGIN_ROOT/skills" -name '*.md' ! -name 'SKILL.md' ! -name 'common.md' | sort)

if [ "${#over_hard[@]}" -eq 0 ]; then
    pass "B-2: no reference .md exceeds the hard ceiling (~${REF_HARD_TOK} tok)"
else
    fail "B-2: no reference .md exceeds the hard ceiling (~${REF_HARD_TOK} tok)" \
        "$(printf '%s\n' "${over_hard[@]}")"
fi
if [ "${#over_ref[@]}" -gt 0 ]; then
    skip "B-2: $((${#over_ref[@]})) reference file(s) over the ~${REF_SOFT_TOK} tok soft budget" \
        "reported, not failed - B-6 governs the load that matters"
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
        p="${w%%|*}"; why="$(printf '%s' "${w#*|}" | tr -s ' \n' ' ')"
        case "$p" in
            surface:*)
                # A surface waiver names a component directory, not a file.
                sname="${p#surface:}"
                if [ -d "$PLUGIN_ROOT/skills/rice/references/components/$sname" ]; then
                    skip "B-5: waived surface $sname" "$why"
                else
                    fail "B-5: waiver names a surface that exists" "stale waiver: $p"
                fi ;;
            *)
                if [ -e "$PLUGIN_ROOT/$p" ]; then
                    skip "B-5: waived $p" "$why"
                else
                    fail "B-5: waiver names a file that exists" "stale waiver: $p"
                fi ;;
        esac
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

# The exit-code vocabulary (S0138-hyprland-config-exit-code-vocabulary).
#
# One table for every command this plugin ships, stated in CLAUDE.md and in each command's own
# --help. This file is what makes the table binding rather than decorative: it re-derives the
# set of statuses each script can return from the script itself, compares that against the set
# its help documents, and runs the unhappy paths for real.
#
# No shebang: tests/run.sh sources this file. Helpers come from tests/lib.sh.

source "$PLUGIN_ROOT/tests/kv-vocabulary.sh"

EC_TMP="$(mktemp_test_dir exit-codes)"

# ---------------------------------------------------------------------------------------------
# The table, and the set it binds
# ---------------------------------------------------------------------------------------------

# `ec_class_of <code>` - the class name the table gives that number. The one place the mapping
# lives in this harness; every check below reads it.
ec_class_of() {
    case "${1:-}" in
        0) echo ok ;;
        1) echo verdict ;;
        2) echo usage ;;
        3) echo capability ;;
        4) echo refusal ;;
        5) echo input ;;
        6) echo partial ;;
        *) echo "" ;;
    esac
}

# Sourced-only libraries: they define helpers, terminate nothing, and their CLI-guarded blocks
# are not a command surface this table binds. Enumerated rather than derived, so adding a script
# puts it IN scope by default and dropping one out is a visible decision.
EC_SOURCED_ONLY=(
    "scripts/xdg-config.sh"
    "skills/rice/scripts/version-ledger.sh"
)

# `ec_inscope` - every command the table binds, as paths relative to the plugin root.
ec_inscope() {
    local f rel skip s
    while IFS= read -r f; do
        rel="${f#"$PLUGIN_ROOT"/}"
        skip=0
        for s in "${EC_SOURCED_ONLY[@]}"; do [ "$rel" = "$s" ] && skip=1; done
        [ "$skip" -eq 1 ] || printf '%s\n' "$rel"
    done < <(kv_inscope_files "$PLUGIN_ROOT")
}

mapfile -t EC_SCRIPTS < <(ec_inscope)

if [ "${#EC_SCRIPTS[@]}" -lt 25 ]; then
    fail "AC-8: the in-scope command set was found" "only ${#EC_SCRIPTS[@]} scripts resolved under $PLUGIN_ROOT"
    return 0
fi
pass "AC-8: the in-scope command set resolves (${#EC_SCRIPTS[@]} commands, ${#EC_SOURCED_ONLY[@]} sourced-only libraries excluded)"

# ---------------------------------------------------------------------------------------------
# The source scanner: every DELIBERATE termination, with the class its author declared
# ---------------------------------------------------------------------------------------------
# Prints `<line-no> <TAB> <code> <TAB> <declared class or ->` for each shell-level `exit <n>`.
# Skipped: comment lines, here-document bodies (a generated script's `exit` is that script's),
# and any line tagged `# rc=embedded`, which is how an awk or python program's own exit is
# declared to belong to that program.
ec_sites() {
    awk '
        BEGIN { hd = "" }
        {
            line = $0
            if (hd != "") {
                t = line; sub(/^[ \t]+/, "", t)
                if (t == hd) hd = ""
                next
            }
            if (match(line, /<<-?[ \t]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*/)) {
                w = substr(line, RSTART, RLENGTH)
                sub(/^<<-?[ \t]*["'"'"']?/, "", w)
                hd = w
            }
            t = line; sub(/^[ \t]+/, "", t)
            if (t ~ /^#/) next
            if (line ~ /#[ \t]*rc=embedded/) next

            tag = "-"
            if (match(line, /#[ \t]*rc=[a-z]+/)) {
                tag = substr(line, RSTART, RLENGTH)
                sub(/^#[ \t]*rc=/, "", tag)
            }
            rest = line
            while (match(rest, /(^|[^[:alnum:]_])exit[ \t]+[0-9]+/)) {
                m = substr(rest, RSTART, RLENGTH)
                sub(/^.*exit[ \t]+/, "", m)
                printf "%d\t%s\t%s\n", NR, m, tag
                rest = substr(rest, RSTART + RLENGTH)
            }
        }
    ' "$1"
}

# `ec_codes <file>` - the sorted, unique set of statuses that file can return by its own decision.
ec_codes() { ec_sites "$1" | cut -f2 | sort -u | tr '\n' ' ' | sed 's/ $//'; }

# ---------------------------------------------------------------------------------------------
# AC-14 / F4: every deliberate termination declares its class, and the class matches the number
# ---------------------------------------------------------------------------------------------
untagged=""; mismatched=""; out_of_range=""; total_sites=0
for rel in "${EC_SCRIPTS[@]}"; do
    while IFS=$'\t' read -r lno code tag; do
        [ -n "${code:-}" ] || continue
        total_sites=$((total_sites + 1))
        want="$(ec_class_of "$code")"
        if [ -z "$want" ]; then
            out_of_range+="$rel:$lno exit $code"$'\n'
            continue
        fi
        if [ "$tag" = "-" ]; then
            untagged+="$rel:$lno exit $code"$'\n'
        elif [ "$tag" != "$want" ]; then
            mismatched+="$rel:$lno exit $code is tagged '$tag', but the table calls $code '$want'"$'\n'
        fi
    done < <(ec_sites "$PLUGIN_ROOT/$rel")
done

if [ -z "$untagged" ]; then
    pass "AC-14: every deliberate termination declares its class ($total_sites sites)"
else
    fail "AC-14: every deliberate termination declares its class" "$untagged"
fi

# This is what lets AC-4's "1 for no other reason" fail: the class is declared independently of
# the number, so a site that moves to 1 without being a verdict reds here.
if [ -z "$mismatched" ]; then
    pass "AC-4: every declared class agrees with the number the table gives it"
else
    fail "AC-4: every declared class agrees with the number the table gives it" "$mismatched"
fi

# AC-8: 0 to 6 and no other. 126, 127 and 128+N stay the shell's.
if [ -z "$out_of_range" ]; then
    pass "AC-8: every deliberate termination is in 0 to 6"
else
    fail "AC-8: every deliberate termination is in 0 to 6" "$out_of_range"
fi

# AC-4, the other direction: exactly the sites tagged `verdict` are the ones that exit 1.
verdict_bad=""
for rel in "${EC_SCRIPTS[@]}"; do
    while IFS=$'\t' read -r lno code tag; do
        [ -n "${code:-}" ] || continue
        if [ "$tag" = "verdict" ] && [ "$code" != "1" ]; then
            verdict_bad+="$rel:$lno is tagged verdict but exits $code"$'\n'
        fi
        if [ "$code" = "1" ] && [ "$tag" != "verdict" ]; then
            verdict_bad+="$rel:$lno exits 1 but is tagged '$tag', so 1 would mean something other than a negative verdict"$'\n'
        fi
    done < <(ec_sites "$PLUGIN_ROOT/$rel")
done
if [ -z "$verdict_bad" ]; then
    pass "AC-4: 1 is returned for a negative verdict and for no other reason"
else
    fail "AC-4: 1 is returned for a negative verdict and for no other reason" "$verdict_bad"
fi

# ---------------------------------------------------------------------------------------------
# AC-1 / AC-9: help is complete, and it agrees with the code in both directions
# ---------------------------------------------------------------------------------------------
# A scratch HOME so a help invocation can never read or write a real config directory.
ec_home="$EC_TMP/home"; mkdir -p "$ec_home/.config"

# Writes the help to $EC_TMP/help.out and sets EC_HELP_RC. Not a command substitution: that
# would run in a subshell and lose the status this check is about.
ec_help() {  # ec_help <relative script> <flag>
    HOME="$ec_home" XDG_CONFIG_HOME="$ec_home/.config" \
    RICE_DIR="$ec_home/.config/hypr-rice" HYPR_DIR="$ec_home/.config/hypr" \
        bash "$PLUGIN_ROOT/$1" "$2" >"$EC_TMP/help.out" 2>/dev/null
    EC_HELP_RC=$?
}

# `ec_documented_codes <help text>` - the statuses the help states, from its Exit codes block.
ec_documented_codes() {
    printf '%s\n' "$1" | sed -n 's/^[[:space:]]\{1,\}\([0-6]\)[[:space:]]\{1,\}[a-z]\{1,\}:.*/\1/p' \
        | sort -u | tr '\n' ' ' | sed 's/ $//'
}

# `ec_documented_classes <help text>` - the same block's class words, keyed by code.
ec_documented_classes() {
    printf '%s\n' "$1" | sed -n 's/^[[:space:]]\{1,\}\([0-6]\)[[:space:]]\{1,\}\([a-z]\{1,\}\):.*/\1 \2/p' | sort -u
}

help_rc_bad=""; help_shape_bad=""; help_disagrees=""; help_class_bad=""
for rel in "${EC_SCRIPTS[@]}"; do
    for flag in -h --help help; do
        ec_help "$rel" "$flag"
        [ "$EC_HELP_RC" -eq 0 ] || help_rc_bad+="$rel $flag exited $EC_HELP_RC"$'\n'
    done
    ec_help "$rel" --help; text="$(cat "$EC_TMP/help.out")"
    for needle in 'Usage:' 'Example:' 'Options:' 'Exit codes'; do
        printf '%s\n' "$text" | grep -q "$needle" || help_shape_bad+="$rel: --help has no '$needle' line"$'\n'
    done

    documented="$(ec_documented_codes "$text")"
    derived="$(ec_codes "$PLUGIN_ROOT/$rel")"
    if [ "$documented" != "$derived" ]; then
        help_disagrees+="$rel: help documents [$documented], the script can return [$derived]"$'\n'
    fi

    while read -r code class; do
        [ -n "${code:-}" ] || continue
        want="$(ec_class_of "$code")"
        [ "$class" = "$want" ] || help_class_bad+="$rel: help calls $code '$class'; the table calls it '$want'"$'\n'
    done < <(ec_documented_classes "$text")
done

if [ -z "$help_rc_bad" ]; then
    pass "AC-1: -h, --help and help each exit 0 on every command (${#EC_SCRIPTS[@]} commands)"
else
    fail "AC-1: -h, --help and help each exit 0 on every command" "$help_rc_bad"
fi
if [ -z "$help_shape_bad" ]; then
    pass "AC-1: every help states a usage line, a runnable example, its options and its exit codes"
else
    fail "AC-1: every help states a usage line, a runnable example, its options and its exit codes" "$help_shape_bad"
fi
if [ -z "$help_disagrees" ]; then
    pass "AC-9: no command can return a status its help omits, or documents one it cannot return"
else
    fail "AC-9: no command can return a status its help omits, or documents one it cannot return" "$help_disagrees"
fi
if [ -z "$help_class_bad" ]; then
    pass "AC-9: every help names each code by the class the table gives it"
else
    fail "AC-9: every help names each code by the class the table gives it" "$help_class_bad"
fi

# ---------------------------------------------------------------------------------------------
# AC-1: help names each option and subcommand the script's own argument parser matches
# ---------------------------------------------------------------------------------------------
# The parser is marked in the source with `# [cli-parser]` on its `case`. This reads that block's
# arm labels (globs excluded - they match anything and name nothing) and compares them against
# the Options:/Subcommands: lines of the help, failing on either direction unmatched.
ec_parser_labels() {
    awk '
        BEGIN { hd = ""; sp = 0 }
        {
            line = $0
            # A here-document body belongs to whatever it is written into, not to this parser.
            if (hd != "") {
                t = line; sub(/^[ \t]+/, "", t)
                if (t == hd) hd = ""
                next
            }
            if (match(line, /<<-?[ \t]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*/)) {
                w = substr(line, RSTART, RLENGTH)
                sub(/^<<-?[ \t]*["'"'"']?/, "", w)
                hd = w
                next
            }
            t = line; sub(/^[ \t]+/, "", t)
            if (t ~ /^#/) next

            tmp = line; nopen  = gsub(/case[ \t]+[^ \t]+[ \t]+in([ \t]|;|$)/, "&", tmp)
            tmp = line; nclose = gsub(/(^|[ \t;])esac([ \t;]|$)/, "&", tmp)
            if (nopen > 0 || nclose > 0) {
                marked = (line ~ /\[cli-parser\]/) ? 1 : 0
                for (i = 0; i < nopen; i++)  { sp++; stack[sp] = marked }
                for (i = 0; i < nclose; i++) { if (sp > 0) sp-- }
                next
            }
            # Arm labels are collected only inside a case explicitly marked as the parser, at
            # that case`s own nesting level: a nested unmarked case matches VALUES, not options.
            if (sp == 0 || stack[sp] != 1) next
            # A label is a run of label characters ending in `)`. Anything with a space, a
            # semicolon or an expansion in it is a line of the arm`s body, not its label.
            if (!match(t, /^\(?["'"'"'A-Za-z0-9_.:+@|-]*\)/)) next
            lbl = substr(t, RSTART, RLENGTH)
            gsub(/[()]/, "", lbl)
            if (lbl ~ /[*?[]/) next
            if (lbl == "") next
            n = split(lbl, parts, "|")
            for (i = 1; i <= n; i++) {
                p = parts[i]
                gsub(/^[ \t]+|[ \t]+$/, "", p)
                gsub(/^["'"'"']|["'"'"']$/, "", p)
                if (p != "") print p
            }
        }
    ' "$1" | sort -u
}

# `ec_declared_labels <help text>` - the first word of each comma-separated item on the
# Options: and Subcommands: lines. `none` declares an empty set.
ec_declared_labels() {
    printf '%s\n' "$1" \
        | sed -n -e 's/^[[:space:]]*Options:[[:space:]]*//p' -e 's/^[[:space:]]*Subcommands:[[:space:]]*//p' \
        | tr ',' '\n' \
        | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); if ($1 != "" && $1 != "none") print $1 }' \
        | sort -u
}

label_bad=""
for rel in "${EC_SCRIPTS[@]}"; do
    ec_help "$rel" --help; text="$(cat "$EC_TMP/help.out")"
    parsed="$(ec_parser_labels "$PLUGIN_ROOT/$rel")"
    declared="$(ec_declared_labels "$text")"
    missing="$(comm -23 <(printf '%s\n' "$parsed") <(printf '%s\n' "$declared") | tr '\n' ' ')"
    extra="$(comm -13 <(printf '%s\n' "$parsed") <(printf '%s\n' "$declared") | tr '\n' ' ')"
    [ -z "${missing// /}" ] || label_bad+="$rel: the parser matches [$missing] and the help does not name them"$'\n'
    [ -z "${extra// /}" ]   || label_bad+="$rel: the help names [$extra] and the parser does not match them"$'\n'
done
if [ -z "$label_bad" ]; then
    pass "AC-1: every help names exactly the options and subcommands its own parser matches"
else
    fail "AC-1: every help names exactly the options and subcommands its own parser matches" "$label_bad"
fi

# ---------------------------------------------------------------------------------------------
# AC-2: a usage error exits 2, says so on stderr, and writes nothing
# ---------------------------------------------------------------------------------------------
ec_target="$EC_TMP/usage-target"; mkdir -p "$ec_target"
printf 'before\n' > "$ec_target/hyprland.conf"
ec_before="$(cd "$ec_target" && find . -type f -exec cksum {} + | sort)"

EC_ERR="$EC_TMP/stderr.out"
ec_run() {  # ec_run <relative script> <args...>; sets EC_RC, stderr lands in $EC_ERR
    local rel="$1"; shift
    HOME="$ec_home" XDG_CONFIG_HOME="$ec_home/.config" \
    RICE_DIR="$ec_home/.config/hypr-rice" HYPR_DIR="$ec_target" \
        bash "$PLUGIN_ROOT/$rel" "$@" >/dev/null 2>"$EC_ERR"
    EC_RC=$?
}

ec_run skills/rice/scripts/install-config.sh --bogus-option
assert_eq "2" "$EC_RC" "AC-2: an option install-config.sh does not have is a usage error"

ec_run skills/rice/scripts/verify-config.sh --expect
assert_eq "2" "$EC_RC" "AC-2: an option missing its argument is a usage error"
assert_grep 'ERROR' "$EC_ERR" "AC-2: the usage error is written to stderr"

ec_run skills/rice/assets/rice not-a-subcommand
assert_eq "2" "$EC_RC" "AC-2: an unknown rice subcommand is a usage error"

ec_run scripts/dotfiles.sh not-a-subcommand
assert_eq "2" "$EC_RC" "AC-2: an unknown dotfiles.sh subcommand is a usage error"
assert_grep 'unknown command' "$EC_ERR" "AC-2: the unknown subcommand is named on stderr"

ec_run scripts/record-answer.sh
assert_eq "2" "$EC_RC" "AC-2: record-answer.sh with no arguments is a usage error (it used to be 1)"

ec_after="$(cd "$ec_target" && find . -type f -exec cksum {} + | sort)"
assert_eq "$ec_before" "$ec_after" "AC-2: not one usage error wrote to any target path"

# ---------------------------------------------------------------------------------------------
# AC-3: an absent capability exits 3, and is never 0, 1 or 4
# ---------------------------------------------------------------------------------------------
ec_nobin="$EC_TMP/nobin"; mkdir -p "$ec_nobin"
ec_stage="$EC_TMP/stage"; mkdir -p "$ec_stage"
printf 'general {\n    gaps_in = 5\n}\n' > "$ec_stage/hyprland.conf"

out="$(PATH="$ec_nobin:/usr/bin:/bin" HOME="$ec_home" \
       bash "$PLUGIN_ROOT/skills/rice/scripts/preflight-config.sh" "$ec_stage" 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s\n' "$out" | grep -q '^PREFLIGHT=unverified'; then
    pass "AC-3: no binary offering the offline check is 'unverified' and exit 3, not a verdict"
else
    fail "AC-3: no binary offering the offline check is 'unverified' and exit 3, not a verdict" "rc=$rc
$out"
fi
case "$rc" in
    0|1|4) fail "AC-3: a missing capability is never 0, 1 or 4" "preflight-config.sh returned $rc" ;;
    *)     pass "AC-3: a missing capability is never 0, 1 or 4" ;;
esac

out="$(PATH="$ec_nobin:/usr/bin:/bin" HOME="$ec_home" \
       bash "$PLUGIN_ROOT/skills/rice/scripts/loaded-config.sh" 2>&1)"; rc=$?
assert_eq "3" "$rc" "AC-3: no running compositor to ask is an absent capability, not a verdict"

out="$(PATH="$ec_nobin:/usr/bin:/bin" HOME="$ec_home" \
       bash "$PLUGIN_ROOT/skills/rice/scripts/verify-config.sh" 2>&1)"; rc=$?
assert_eq "3" "$rc" "AC-3: verify-config.sh with no compositor is 3, so a check that never ran is not a pass"
if printf '%s\n' "$out" | grep -q '^VERIFY=skipped'; then
    pass "AC-3: the missing capability is named, not just numbered"
else
    fail "AC-3: the missing capability is named, not just numbered" "$out"
fi

printf '# no zsh on this PATH\n' > "$EC_TMP/rc.zshrc"
out="$(PATH="$ec_nobin:/usr/bin:/bin" bash "$PLUGIN_ROOT/skills/rice/scripts/verify-shell.sh" "$EC_TMP/rc.zshrc" zsh 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] || command -v zsh >/dev/null 2>&1; then
    pass "AC-3: an uninstalled shell interpreter is an absent capability (3), not a usage error (2)"
else
    fail "AC-3: an uninstalled shell interpreter is an absent capability (3), not a usage error (2)" "rc=$rc
$out"
fi

# The rice CLI resolves its components out of $RICE_DIR at runtime: a component that is not
# there is an absent capability, never a defective input.
ec_ricedir="$EC_TMP/ricedir"; mkdir -p "$ec_ricedir"
out="$(RICE_DIR="$ec_ricedir" HOME="$ec_home" bash "$PLUGIN_ROOT/skills/rice/assets/rice" restore --list 2>&1)"; rc=$?
assert_eq "3" "$rc" "AC-3/AC-11: a rice component missing from \$RICE_DIR is 3, not 5"

# ---------------------------------------------------------------------------------------------
# AC-4: a negative verdict exits 1
# ---------------------------------------------------------------------------------------------
printf 'if [ 1 = 1 ; then\n' > "$EC_TMP/broken.bashrc"
out="$(bash "$PLUGIN_ROOT/skills/rice/scripts/verify-shell.sh" "$EC_TMP/broken.bashrc" 2>&1)"; rc=$?
assert_eq "1" "$rc" "AC-4: a shell rc with parse errors is a negative verdict"
printf 'export PATH="$PATH"\n' > "$EC_TMP/clean.bashrc"
out="$(bash "$PLUGIN_ROOT/skills/rice/scripts/verify-shell.sh" "$EC_TMP/clean.bashrc" 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-4: a clean shell rc is 0, so 1 really does mean the answer was no"

out="$(RICE_DIR="$ec_ricedir" HOME="$ec_home" bash "$PLUGIN_ROOT/scripts/rice-restore.sh" no-such-apply-id 2>&1)"; rc=$?
assert_eq "1" "$rc" "AC-4: an identifier with no restore point under it is a negative verdict"

# ---------------------------------------------------------------------------------------------
# AC-5: a refusal exits 4, leaves every target byte-identical, and is never 1 or 3
# ---------------------------------------------------------------------------------------------
ec_shadow="$EC_TMP/shadowed"; mkdir -p "$ec_shadow"
printf 'return {}\n' > "$ec_shadow/hyprland.lua"
ec_shadow_before="$(cd "$ec_shadow" && find . -type f -exec cksum {} + | sort)"
out="$(HYPR_DIR="$ec_shadow" HOME="$ec_home" bash "$PLUGIN_ROOT/skills/rice/scripts/install-config.sh" "$ec_stage" 2>&1)"; rc=$?
assert_eq "4" "$rc" "AC-5: a target holding a file it will not overwrite is a refusal"
case "$rc" in
    1|3) fail "AC-5: a refusal is never 1 or 3" "install-config.sh returned $rc" ;;
    *)   pass "AC-5: a refusal is never 1 or 3, so a caller retrying on 3 never retries a refusal" ;;
esac
ec_shadow_after="$(cd "$ec_shadow" && find . -type f -exec cksum {} + | sort)"
assert_eq "$ec_shadow_before" "$ec_shadow_after" "AC-5: the refused target is byte-identical afterwards"

ec_unwritable="$EC_TMP/unwritable"; mkdir -p "$ec_unwritable"
printf 'old\n' > "$ec_unwritable/hyprland.conf"
chmod 500 "$ec_unwritable"
if [ "$(id -u)" -eq 0 ] || [ -w "$ec_unwritable" ]; then
    skip "AC-5: an unwritable target is a refusal" "running as root; mode 500 is still writable"
else
    out="$(HYPR_DIR="$ec_unwritable" HOME="$ec_home" bash "$PLUGIN_ROOT/skills/rice/scripts/install-config.sh" "$ec_stage" 2>&1)"; rc=$?
    assert_eq "4" "$rc" "AC-5: an unwritable target is a refusal, not a verdict about the staged config"
fi
chmod 700 "$ec_unwritable"

# ---------------------------------------------------------------------------------------------
# AC-6: a defective input exits 5, distinct from a missing capability and from a verdict
# ---------------------------------------------------------------------------------------------
out="$(bash "$PLUGIN_ROOT/skills/rice/scripts/verify-shell.sh" "$EC_TMP/no-such-rc-file" 2>&1)"; rc=$?
assert_eq "5" "$rc" "AC-6: an rc file that is not there is a defective input, not a verdict"

ec_empty="$EC_TMP/empty-stage"; mkdir -p "$ec_empty"
out="$(HOME="$ec_home" bash "$PLUGIN_ROOT/skills/rice/scripts/preflight-config.sh" "$ec_empty" 2>&1)"; rc=$?
if [ "$rc" -eq 5 ] && printf '%s\n' "$out" | grep -q '^PREFLIGHT=uncheckable'; then
    pass "AC-6/F3: 'uncheckable' is a defective input (5), kept apart from 'unverified' (3)"
else
    fail "AC-6/F3: 'uncheckable' is a defective input (5), kept apart from 'unverified' (3)" "rc=$rc
$out"
fi

printf 'not json at all\n' > "$EC_TMP/corrupt.json"
out="$(bash "$PLUGIN_ROOT/scripts/record-answer.sh" "$EC_TMP/corrupt.json" a.b c 2>&1)"; rc=$?
assert_eq "5" "$rc" "AC-6: a corrupt answers file is a defective input (it used to be 2)"

# ---------------------------------------------------------------------------------------------
# AC-7: half-finished work exits 6 and names on stderr what it did and what it did not
# ---------------------------------------------------------------------------------------------
ec_state="$EC_TMP/restore-state"
ec_apply="20260101-000000"
mkdir -p "$ec_state/$ec_apply"
printf 'gone\n' > "$EC_TMP/target-a"
printf 'gone\n' > "$EC_TMP/target-b"
printf 'kept\n' > "$EC_TMP/target-b.bak.$ec_apply"
printf 'file\t%s\t%s\n' "$EC_TMP/target-a" "$EC_TMP/no-such-backup" >  "$ec_state/$ec_apply/entries.tsv"
printf 'file\t%s\t%s\n' "$EC_TMP/target-b" "$EC_TMP/target-b.bak.$ec_apply" >> "$ec_state/$ec_apply/entries.tsv"
out="$(RICE_RESTORE_DIR="$ec_state" HOME="$ec_home" bash "$PLUGIN_ROOT/scripts/rice-restore.sh" "$ec_apply" 2>"$EC_TMP/partial.err")"; rc=$?
assert_eq "6" "$rc" "AC-7: a restore that put some files back and not others is 6, not a verdict"
if grep -q 'PARTIAL' "$EC_TMP/partial.err"; then
    pass "AC-7: the partial restore names on stderr what it did and what it did not"
else
    fail "AC-7: the partial restore names on stderr what it did and what it did not" "$(cat "$EC_TMP/partial.err")"
fi
assert_file_contains "$EC_TMP/target-b" "kept" "AC-7: the half that could be restored really was"

# ---------------------------------------------------------------------------------------------
# AC-10: the harness's own contract
# ---------------------------------------------------------------------------------------------
ec_runner="$EC_TMP/runner"; mkdir -p "$ec_runner/tests"
cp "$PLUGIN_ROOT/tests/run.sh" "$PLUGIN_ROOT/tests/lib.sh" "$ec_runner/tests/"

printf 'pass "a green one"\n' > "$ec_runner/tests/test_green.sh"
( cd "$ec_runner" && bash tests/run.sh >/dev/null 2>&1 ); rc=$?
assert_eq "0" "$rc" "AC-10: run.sh exits 0 when every test passed"

printf 'fail "a red one" "on purpose"\n' > "$ec_runner/tests/test_red.sh"
( cd "$ec_runner" && bash tests/run.sh >/dev/null 2>&1 ); rc=$?
assert_eq "1" "$rc" "AC-10: run.sh exits 1 when any test failed"
rm -f "$ec_runner/tests/test_red.sh"

printf 'skip "a skipped one" "no reason"\n' > "$ec_runner/tests/test_skipped.sh"
( cd "$ec_runner" && bash tests/run.sh >/dev/null 2>&1 ); rc=$?
assert_eq "0" "$rc" "AC-10: a skipped test is still a pass"

( cd "$ec_runner" && bash tests/run.sh matches-no-test-file >/dev/null 2>&1 ); rc=$?
assert_eq "2" "$rc" "AC-10: a filter that matches no test file exits 2, never a clean 0"

ec_bare="$EC_TMP/bare"; mkdir -p "$ec_bare/tests"
cp "$PLUGIN_ROOT/tests/run.sh" "$PLUGIN_ROOT/tests/lib.sh" "$ec_bare/tests/"
( cd "$ec_bare" && bash tests/run.sh >/dev/null 2>&1 ); rc=$?
assert_eq "5" "$rc" "AC-10: a tests directory with no test file in it exits 5"

# The way this repo's CI invokes it. The new 2 must never fire for a caller this item may not
# edit, so the `integration` filter has to keep matching and keep exiting 0 on a clean tree.
( cd "$PLUGIN_ROOT" && bash tests/run.sh integration >/dev/null 2>&1 ); rc=$?
assert_eq "0" "$rc" "AC-10: 'bash tests/run.sh integration', which .github/workflows/tests.yml runs, still exits 0"

# The workflow's third invocation, verbatim. AC-13 pins that file byte-identical, so every code
# this item moved has to leave the command it runs exiting 0 on a clean tree.
( cd "$PLUGIN_ROOT" && bash skills/rice/scripts/currency-check.sh >/dev/null 2>&1 ); rc=$?
assert_eq "0" "$rc" "AC-10: 'bash skills/rice/scripts/currency-check.sh', which the same workflow runs, still exits 0"

# ---------------------------------------------------------------------------------------------
# AC-11: the CLI a user actually types
# ---------------------------------------------------------------------------------------------
ec_norice="$EC_TMP/norice"; mkdir -p "$ec_norice"
out="$(HOME= XDG_CONFIG_HOME=relative RICE_DIR= bash "$PLUGIN_ROOT/skills/rice/assets/rice" palette 2>&1)"; rc=$?
if [ "$rc" -eq 4 ] && printf '%s\n' "$out" | grep -q '^RICE=refused-no-config-dir'; then
    pass "AC-11: rice with no config directory prints RICE=refused-no-config-dir and exits 4"
else
    fail "AC-11: rice with no config directory prints RICE=refused-no-config-dir and exits 4" "rc=$rc
$out"
fi

ec_lonely="$EC_TMP/lonely"; mkdir -p "$ec_lonely"
cp "$PLUGIN_ROOT/skills/rice/assets/rice" "$ec_lonely/rice"
out="$(CLAUDE_PLUGIN_ROOT=/nonexistent HOME="$ec_home" bash "$ec_lonely/rice" palette 2>&1)"; rc=$?
assert_eq "3" "$rc" "AC-11: rice that cannot find the config-path library beside it exits 3"

out="$(RICE_DIR="$ec_ricedir" HOME="$ec_home" bash "$PLUGIN_ROOT/skills/rice/assets/rice" no-such-subcommand 2>&1)"; rc=$?
assert_eq "2" "$rc" "AC-11: rice given an unknown subcommand exits 2"

# A catalog it cannot reach is 3; a selector that matched nothing in a catalog it CAN read is 1.
cp "$PLUGIN_ROOT/skills/rice/assets/wallpapers.tsv" "$ec_ricedir/wallpapers.tsv"
out="$(RICE_DIR="$ec_ricedir" HOME="$ec_home" bash "$PLUGIN_ROOT/skills/rice/assets/rice" get-wallpaper nord definitely-not-a-wallpaper-name 2>&1)"; rc=$?
assert_eq "1" "$rc" "AC-11: a selector matching no catalog entry is a negative verdict (1)"
rm -f "$ec_ricedir/wallpapers.tsv"
out="$(RICE_DIR="$ec_ricedir" HOME="$ec_home" bash "$PLUGIN_ROOT/skills/rice/assets/rice" wallpapers 2>&1)"; rc=$?
assert_eq "3" "$rc" "AC-11: a catalog the CLI cannot reach is an absent capability (3), not a verdict"

# ---------------------------------------------------------------------------------------------
# AC-13: the KEY=value narration vocabulary is unchanged, measured against the pinned baseline
# ---------------------------------------------------------------------------------------------
ec_baseline="$PLUGIN_ROOT/tests/kv-baseline.txt"
if [ ! -s "$ec_baseline" ]; then
    fail "AC-13: the pre-change KEY=value baseline is committed beside the harness" "missing or empty: $ec_baseline"
else
    kv_scan "$PLUGIN_ROOT" > "$EC_TMP/kv-now.txt"
    lost="$(comm -23 <(LC_ALL=C sort -u "$ec_baseline") <(LC_ALL=C sort -u "$EC_TMP/kv-now.txt"))"
    if [ -z "$lost" ]; then
        pass "AC-13: every KEY=value line the baseline recorded is still emitted, unchanged ($(wc -l < "$ec_baseline") rows)"
    else
        fail "AC-13: every KEY=value line the baseline recorded is still emitted, unchanged" "$lost"
    fi
    gained="$(comm -13 <(LC_ALL=C sort -u "$ec_baseline") <(LC_ALL=C sort -u "$EC_TMP/kv-now.txt"))"
    if [ -z "$gained" ]; then
        pass "AC-13: no KEY=value line was added to the narration layer either"
    else
        fail "AC-13: no KEY=value line was added to the narration layer either" "$gained"
    fi
fi

# AC-13, the other half: nothing outside scripts/, skills/, tests/ and CLAUDE.md moved a byte.
if git -C "$PLUGIN_ROOT" rev-parse --verify --quiet origin/main >/dev/null 2>&1; then
    outside="$(git -C "$PLUGIN_ROOT" diff --name-only origin/main...HEAD \
               | grep -vE '^(scripts/|skills/|tests/|CLAUDE\.md$)' || true)"
    if [ -z "$outside" ]; then
        pass "AC-13: no file outside scripts/, skills/, tests/ and CLAUDE.md changed"
    else
        fail "AC-13: no file outside scripts/, skills/, tests/ and CLAUDE.md changed" "$outside"
    fi
else
    skip "AC-13: no file outside scripts/, skills/, tests/ and CLAUDE.md changed" "origin/main is not fetched here"
fi

rm -rf "$EC_TMP"

#!/usr/bin/env bash
# S0028-hyprland-config-preflight-5 - the OFFLINE preflight and the apply flow it guards.
#
# Grades AC-1, AC-2, AC-5, AC-6, AC-7 and AC-10. Everything here runs with STUB
# `Hyprland` and `hyprctl` binaries on PATH, because the `unit` job in
# `.github/workflows/tests.yml` is a bare ubuntu-latest with neither installed.
# The stub reproduces the contract MEASURED against Hyprland 0.56.2 in the repo's
# own container - see `tests/integration/offline-check-contract.md`. The real
# binary is exercised by the integration job.
#
# The property under every refusal below is the same one: the user's config
# directory is BYTE-IDENTICAL afterwards.

RS="$PLUGIN_ROOT/skills/rice/scripts"
tmp="$(mktemp_test_dir preflight)"

# ---------------------------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------------------------

# `write_hypr_stub <dir>` - a `Hyprland` that reproduces the measured contract:
#   * aborts when XDG_RUNTIME_DIR is unset, before parsing any argument
#   * `--help` lists the flags (STUB_HYPR_NO_OFFLINE=1 drops --verify-config)
#   * `--verify-config -c FILE` walks FILE and every `source =` it names, expanding
#     `~` from $HOME, and reports one error per BREAK_ME line
#   * prints `======== Config parsing result:` whenever it actually parsed, and
#     never when it rejected the invocation
#   * STUB_HYPR_REJECT=1 rejects the invocation after --help still works
write_hypr_stub() {
    mkdir -p "$1"
    cat > "$1/Hyprland" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    echo "Critical error thrown: XDG_RUNTIME_DIR is not set!" >&2
    exit 134
fi
usage() {
    printf 'usage: Hyprland [arg [...]].\n\n'
    printf 'Arguments:\n'
    printf '    --help              -h       - Show this message again\n'
    printf '    --config FILE       -c FILE  - Specify config file to use\n'
    if [ -z "${STUB_HYPR_NO_OFFLINE:-}" ]; then
        printf '    --verify-config              - Do not run Hyprland, only print if the config has any errors\n'
    fi
    printf '    --version           -v       - Print this binary'"'"'s version\n'
}
cfg=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h)        usage; exit 0 ;;
        --version|-v)     echo "Hyprland 0.56.2 built from branch v0.56.2"; exit 0 ;;
        --verify-config)  shift ;;
        -c|--config)      cfg="${2:-}"; shift 2 ;;
        *) printf "[ ERROR ] Unknown option '%s' !\n" "$1" >&2; usage; exit 1 ;;
    esac
done
if [ -n "${STUB_HYPR_REJECT:-}" ]; then
    printf "[ ERROR ] (main.cpp:136) | Config file '%s' is invalid: rejected by the stub!\n" "$cfg" >&2
    usage
    exit 1
fi
if [ ! -f "$cfg" ]; then
    printf "[ ERROR ] (main.cpp:136) | Config file '%s' is invalid: cannot make canonical path!\n" "$cfg" >&2
    usage
    exit 1
fi
errors=()
scan() {
    local p="$1" n=0 line val t
    while IFS= read -r line || [ -n "$line" ]; do
        n=$((n + 1))
        case "$line" in
            BREAK_ME*)
                errors+=("Config error in file $p at line $n: config option <general:not_a_real_option_here> does not exist.") ;;
            source*=*)
                val="${line#*=}"
                val="${val# }"
                case "$val" in
                    '~/'*) t="${HOME:-}/${val#\~/}" ;;
                    /*)    t="$val" ;;
                    *)     t="$(dirname "$p")/$val" ;;
                esac
                if [ -f "$t" ]; then
                    scan "$t"
                else
                    errors+=("Config error in file $p at line $n: source= globbing error: found no match")
                fi ;;
        esac
    done < "$p"
}
if ! scan "$cfg" 2>/dev/null; then
    printf '\n\n======== Config parsing result:\n\nFile failed to open\n'
    exit 1
fi
printf '\n\n======== Config parsing result:\n\n'
if [ "${#errors[@]}" -eq 0 ]; then
    echo "config ok"
    exit 0
fi
for e in "${errors[@]}"; do echo "$e"; done
exit 1
STUB
    chmod +x "$1/Hyprland"
}

# `write_hyprctl_stub <dir>` - a `hyprctl` driven by env:
#   STUB_HYPRCTL_DEAD=1        no running instance (`version` fails)
#   STUB_HYPRCTL_ERRORS=<text> what `configerrors` prints
#   STUB_HYPRCTL_LOADED=<path> what `rollinglog` says the compositor loaded
#                              (unset => the log names nothing)
write_hyprctl_stub() {
    mkdir -p "$1"
    cat > "$1/hyprctl" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
if [ -n "${STUB_HYPRCTL_DEAD:-}" ]; then
    echo "Couldn't connect to the Hyprland socket" >&2
    exit 1
fi
case "${1:-}" in
    version)      echo "Hyprland 0.56.2 built from branch v0.56.2"; exit 0 ;;
    reload)       exit 0 ;;
    configerrors) printf '%s' "${STUB_HYPRCTL_ERRORS:-}"; [ -n "${STUB_HYPRCTL_ERRORS:-}" ] && echo; exit 0 ;;
    rollinglog)
        echo "[LOG] Creating the ConfigManager!"
        if [ -n "${STUB_HYPRCTL_LOADED:-}" ]; then
            echo "Using config: ${STUB_HYPRCTL_LOADED}"
            echo "Using config: ${STUB_HYPRCTL_LOADED}"
        fi
        echo "[LOG] Hyprland init finished."
        exit 0 ;;
    systeminfo)   echo "Hyprland 0.56.2"; exit 0 ;;
    *)            echo "invalid command"; exit 1 ;;
esac
STUB
    chmod +x "$1/hyprctl"
}

stubbin="$tmp/bin"
write_hypr_stub "$stubbin"
write_hyprctl_stub "$stubbin"
nobin="$tmp/nobin"; mkdir -p "$nobin"

# PATH with the stubs first. Nothing here ever calls the host's real compositor.
STUB_PATH="$stubbin:/usr/bin:/bin"

# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------

# `fingerprint <dir>` - a byte-level snapshot of a directory: every path, mode and
# content hash. Two equal fingerprints mean the refusal really changed nothing.
fingerprint() {
    local d="$1"
    [ -d "$d" ] || { echo "ABSENT"; return; }
    ( cd "$d" && find . -mindepth 1 -printf '%y %m %p\n' | sort
      find . -type f -exec sha256sum {} \; 2>/dev/null | sort )
}

# `siblings <dir>` - what sits BESIDE the target (a `.bak.` would mean a backup was
# taken, which a refusal must never do).
siblings() { ( cd "$(dirname "$1")" && ls -A | sort ); }

stage_good() {
    mkdir -p "$1"
    printf 'general {\n    gaps_in = 5\n}\nbind = SUPER, Q, killactive\n' > "$1/hyprland.conf"
}
stage_broken() {
    mkdir -p "$1"
    printf 'general {\n    gaps_in = 5\n}\nBREAK_ME = 1\n' > "$1/hyprland.conf"
}
# A modular set shaped like the one the rice flow generates: the main config sources
# its companions through `~/.config/hypr/...`, i.e. by INSTALL path, not staging path.
stage_split() {
    local d="$1" companion_broken="$2"
    mkdir -p "$d"
    printf 'general {\n    gaps_in = 5\n}\nsource = ~/.config/hypr/monitors.conf\n' > "$d/hyprland.conf"
    if [ "$companion_broken" = "broken" ]; then
        printf 'monitor = , preferred, auto, 1\nBREAK_ME = 1\n' > "$d/monitors.conf"
    else
        printf 'monitor = , preferred, auto, 1\n' > "$d/monitors.conf"
    fi
}

# `last_line <text>` / `outcome <text>` - the terminal line and its outcome word.
last_line() { printf '%s\n' "$1" | sed '/^[[:space:]]*$/d' | tail -n1; }
outcome()   { printf '%s\n' "$1" | grep -oE '^SAFE_APPLY=[a-z-]+' | sed 's/^SAFE_APPLY=//'; }

# `run_preflight <staging> [env...]`
pf() { PATH="$STUB_PATH" bash "$RS/preflight-config.sh" "$@" 2>&1; }

# ---------------------------------------------------------------------------------------------
# AC-1 / AC-2 - a staged config with errors is REFUSED, and the errors name the STAGED files
# ---------------------------------------------------------------------------------------------
section_dir="$tmp/ac1"; mkdir -p "$section_dir"

stage_good "$section_dir/stage-ok"
out="$(pf "$section_dir/stage-ok")"; rc=$?
assert_eq "0" "$rc" "AC-1: a clean staged config verifies (exit 0)"
if printf '%s\n' "$out" | grep -q '^PREFLIGHT=ok'; then
    pass "AC-1: a clean staged config reports PREFLIGHT=ok"
else
    fail "AC-1: a clean staged config reports PREFLIGHT=ok" "$out"
fi

stage_broken "$section_dir/stage-bad"
out="$(pf "$section_dir/stage-bad")"; rc=$?
assert_eq "1" "$rc" "AC-1: a staged config with errors exits 1"
if printf '%s\n' "$out" | grep -q '^PREFLIGHT=errors$'; then
    pass "AC-1: a staged config with errors reports PREFLIGHT=errors"
else
    fail "AC-1: a staged config with errors reports PREFLIGHT=errors" "$out"
fi

# AC-2: the errors are surfaced AGAINST THE STAGED FILES - the user has to be able to
# open the path in the message. A sandbox path would be useless to them.
if printf '%s\n' "$out" | grep -q "^PREFLIGHT_ERROR=.*${section_dir}/stage-bad/hyprland.conf"; then
    pass "AC-2: the error names the staged file's real path"
else
    fail "AC-2: the error names the staged file's real path" "$out"
fi
if printf '%s\n' "$out" | grep -q 'hypr-preflight\.'; then
    fail "AC-2: no sandbox path leaks into the report" "$out"
else
    pass "AC-2: no sandbox path leaks into the report"
fi

# AC-1 + AC-2 through the whole apply flow: refuse BEFORE any backup or write.
target="$tmp/ac1/target"; mkdir -p "$target"
printf 'SENTINEL - the user config nobody may touch\n' > "$target/hyprland.conf"
printf 'monitor = , preferred, auto, 1\n' > "$target/monitors.conf"
before="$(fingerprint "$target")"; before_sib="$(siblings "$target")"
out="$(PATH="$STUB_PATH" STUB_HYPRCTL_DEAD=1 HYPR_DIR="$target" bash "$RS/safe-apply.sh" "$section_dir/stage-bad" 2>&1)"; rc=$?
after="$(fingerprint "$target")"; after_sib="$(siblings "$target")"

assert_eq "preflight-failed" "$(outcome "$out")" "AC-1: safe-apply refuses with its own outcome word"
if [ "$rc" -ne 0 ]; then
    pass "AC-1: safe-apply exits non-zero on a failed preflight"
else
    fail "AC-1: safe-apply exits non-zero on a failed preflight" "rc=0
$out"
fi
assert_eq "$before" "$after" "AC-2: the target directory is BYTE-IDENTICAL after the refusal"
assert_eq "$before_sib" "$after_sib" "AC-2: no backup was taken for a run that refused"
if printf '%s\n' "$out" | grep -qE '^(INSTALLED=|BACKUP=|DONE=ok)'; then
    fail "AC-1: nothing was installed" "$out"
else
    pass "AC-1: nothing was installed (no INSTALLED=/BACKUP=/DONE=ok lines)"
fi

# ---------------------------------------------------------------------------------------------
# AC-5 - a SPLIT staged config is checked as a set, and the INSTALLED files never decide it
# ---------------------------------------------------------------------------------------------
ac5="$tmp/ac5"; mkdir -p "$ac5"

# The install target holds a same-named companion. Whatever is in it must be irrelevant.
installed="$ac5/installed"; mkdir -p "$installed"
export HOME_BACKUP="${HOME:-}"

stage_split "$ac5/stage-companion-broken" broken
out="$(pf "$ac5/stage-companion-broken")"; rc=$?
assert_eq "1" "$rc" "AC-5: an error in a staged COMPANION fails the check (not only the main config)"
if printf '%s\n' "$out" | grep -q "^PREFLIGHT_ERROR=.*${ac5}/stage-companion-broken/monitors.conf"; then
    pass "AC-5: the error names the staged COMPANION, monitors.conf"
else
    fail "AC-5: the error names the staged COMPANION, monitors.conf" "$out"
fi
if printf '%s\n' "$out" | grep -q '^STAGED=monitors.conf$'; then
    pass "AC-5: the companion is reported as part of the checked set"
else
    fail "AC-5: the companion is reported as part of the checked set" "$out"
fi

# The decisive pair. Same staged main config, same `source = ~/.config/hypr/monitors.conf`
# line, and a real `$HOME/.config/hypr/monitors.conf` planted on the machine. The verdict
# must follow the STAGED copy in both directions.
fake_home="$ac5/home"; mkdir -p "$fake_home/.config/hypr"

stage_split "$ac5/stage-clean" clean
printf 'monitor = , preferred, auto, 1\nBREAK_ME = 1\n' > "$fake_home/.config/hypr/monitors.conf"
out="$(PATH="$STUB_PATH" HOME="$fake_home" bash "$RS/preflight-config.sh" "$ac5/stage-clean" 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-5: a BROKEN already-installed companion does NOT decide the verdict"

stage_split "$ac5/stage-dirty" broken
printf 'monitor = , preferred, auto, 1\n' > "$fake_home/.config/hypr/monitors.conf"
out="$(PATH="$STUB_PATH" HOME="$fake_home" bash "$RS/preflight-config.sh" "$ac5/stage-dirty" 2>&1)"; rc=$?
assert_eq "1" "$rc" "AC-5: a CLEAN already-installed companion does NOT mask a broken staged one"
if printf '%s\n' "$out" | grep -q "^PREFLIGHT_ERROR=.*${ac5}/stage-dirty/monitors.conf"; then
    pass "AC-5: the verdict is reported against the staged companion, not the installed one"
else
    fail "AC-5: the verdict is reported against the staged companion, not the installed one" "$out"
fi
if printf '%s\n' "$out" | grep -q "${fake_home}/.config/hypr/monitors.conf"; then
    fail "AC-5: the installed companion is never named in the report" "$out"
else
    pass "AC-5: the installed companion is never named in the report"
fi

# ---------------------------------------------------------------------------------------------
# AC-6 - no compositor binary offering the offline check => UNVERIFIED, and the old path runs
# ---------------------------------------------------------------------------------------------
ac6="$tmp/ac6"; mkdir -p "$ac6"
stage_good "$ac6/stage"

if PATH="/usr/bin:/bin" command -v Hyprland >/dev/null 2>&1; then
    skip "AC-6: no compositor binary => unverified" "a real Hyprland is installed on this host"
    skip "AC-6: unverified is not ok"               "a real Hyprland is installed on this host"
    skip "AC-6: the install path still runs"        "a real Hyprland is installed on this host"
else
    out="$(PATH="$nobin:/usr/bin:/bin" bash "$RS/preflight-config.sh" "$ac6/stage" 2>&1)"; rc=$?
    assert_eq "2" "$rc" "AC-6: no compositor binary => unverified (exit 2)"
    if printf '%s\n' "$out" | grep -q '^PREFLIGHT=unverified'; then
        pass "AC-6: unverified is reported, and it is not 'ok'"
    else
        fail "AC-6: unverified is reported, and it is not 'ok'" "$out"
    fi

    # ... and the existing install / live-test / rollback path runs with its behaviour
    # unchanged. With no hyprctl either, that is the pre-existing `installed-untested`.
    t6="$ac6/target"; mkdir -p "$t6"; printf 'OLD\n' > "$t6/hyprland.conf"
    out="$(PATH="$nobin:/usr/bin:/bin" HYPR_DIR="$t6" bash "$RS/safe-apply.sh" "$ac6/stage" 2>&1)"; rc=$?
    if [ "$(outcome "$out")" = "installed-untested" ] \
       && printf '%s\n' "$out" | grep -q '^INSTALLED=hyprland.conf$' \
       && printf '%s\n' "$out" | grep -q '^BACKUP=/'; then
        pass "AC-6: the install path still runs unchanged (installed + backed up)"
    else
        fail "AC-6: the install path still runs unchanged (installed + backed up)" "rc=$rc
$out"
    fi
fi

# The other half of AC-6: a binary that IS there but does not offer the check.
out="$(PATH="$STUB_PATH" STUB_HYPR_NO_OFFLINE=1 bash "$RS/preflight-config.sh" "$ac6/stage" 2>&1)"; rc=$?
assert_eq "2" "$rc" "AC-6: a compositor without --verify-config => unverified, not verified"
if printf '%s\n' "$out" | grep -q '^PREFLIGHT_REASON=no-offline-check$'; then
    pass "AC-6: the reason names the missing offline check"
else
    fail "AC-6: the reason names the missing offline check" "$out"
fi

# ---------------------------------------------------------------------------------------------
# AC-7 - the check could not be RUN: refuse, leave the target alone, and say so DISTINCTLY
# ---------------------------------------------------------------------------------------------
ac7="$tmp/ac7"; mkdir -p "$ac7"

# (a) no main config in staging
mkdir -p "$ac7/stage-nomain"; printf 'x = 1\n' > "$ac7/stage-nomain/other.conf"
out="$(pf "$ac7/stage-nomain")"; rc=$?
assert_eq "3" "$rc" "AC-7: an absent staged main config is uncheckable (exit 3)"
assert_eq "no-main-config" "$(printf '%s\n' "$out" | sed -n 's/^PREFLIGHT_REASON=//p')" \
    "AC-7: the reason for an absent main config is named"

# (b) unreadable main config
mkdir -p "$ac7/stage-unread"; stage_good "$ac7/stage-unread"
chmod 000 "$ac7/stage-unread/hyprland.conf"
if [ "$(id -u)" -eq 0 ] || [ -r "$ac7/stage-unread/hyprland.conf" ]; then
    skip "AC-7: an unreadable staged main config is uncheckable" "running as root; mode 000 is still readable"
else
    out="$(pf "$ac7/stage-unread")"; rc=$?
    assert_eq "3" "$rc" "AC-7: an unreadable staged main config is uncheckable (exit 3)"
fi
chmod 644 "$ac7/stage-unread/hyprland.conf"

# (c) the compositor rejects the invocation before parsing anything. Exit 1 is the SAME
#     code it uses for "your config has errors", so only the absence of a parsing result
#     tells them apart - and getting this wrong turns a packaging change into a refusal
#     that blames the user's config.
stage_good "$ac7/stage"
out="$(PATH="$STUB_PATH" STUB_HYPR_REJECT=1 bash "$RS/preflight-config.sh" "$ac7/stage" 2>&1)"; rc=$?
assert_eq "3" "$rc" "AC-7: a rejected invocation is uncheckable (exit 3), not errors (exit 1)"
assert_eq "invocation-rejected" "$(printf '%s\n' "$out" | sed -n 's/^PREFLIGHT_REASON=//p')" \
    "AC-7: a rejected invocation is named as such"
if printf '%s\n' "$out" | grep -q '^PREFLIGHT=errors'; then
    fail "AC-7: a rejected invocation is NOT reported as a config with errors" "$out"
else
    pass "AC-7: a rejected invocation is NOT reported as a config with errors"
fi

# (d) all of it through the apply flow: refuse, target untouched, distinct outcome word.
t7="$ac7/target"; mkdir -p "$t7"
printf 'SENTINEL\n' > "$t7/hyprland.conf"
before="$(fingerprint "$t7")"; before_sib="$(siblings "$t7")"
out="$(PATH="$STUB_PATH" STUB_HYPR_REJECT=1 STUB_HYPRCTL_DEAD=1 HYPR_DIR="$t7" \
       bash "$RS/safe-apply.sh" "$ac7/stage" 2>&1)"; rc=$?
assert_eq "preflight-uncheckable" "$(outcome "$out")" \
    "AC-7: safe-apply reports 'preflight-uncheckable', distinct from 'preflight-failed'"
assert_eq "$before" "$(fingerprint "$t7")" "AC-7: the target is BYTE-IDENTICAL after an uncheckable refusal"
assert_eq "$before_sib" "$(siblings "$t7")" "AC-7: no backup was taken for an uncheckable refusal"
if [ "$rc" -ne 0 ]; then
    pass "AC-7: safe-apply exits non-zero when the check could not be run"
else
    fail "AC-7: safe-apply exits non-zero when the check could not be run" "rc=0
$out"
fi

# ---------------------------------------------------------------------------------------------
# AC-10 - exactly ONE terminal outcome line, and every outcome distinguishable
# ---------------------------------------------------------------------------------------------
ac10="$tmp/ac10"; mkdir -p "$ac10"
stage_good "$ac10/stage-ok"
stage_broken "$ac10/stage-bad"

words=()
runs=()

# `drive <label> <target-seed> <staging> <env...>` - run one apply and record its outcome.
# Leaves the output in DRIVE_OUT. NOT called in a command substitution: the arrays it
# appends to have to survive into this shell.
DRIVE_OUT=""
drive() {
    local label="$1" seed="$2" staging="$3"; shift 3
    local d="$ac10/t-$label"; mkdir -p "$d"
    [ "$seed" = "empty" ] || printf '%s\n' "$seed" > "$d/hyprland.conf"
    DRIVE_OUT="$(env PATH="$STUB_PATH" HYPR_DIR="$d" "$@" bash "$RS/safe-apply.sh" "$staging" 2>&1)"
    runs+=("$label"$'\x1f'"$DRIVE_OUT")
    words+=("$(outcome "$DRIVE_OUT")")
}

installed_main_of() { echo "$ac10/t-$1/hyprland.conf"; }

drive pf-failed  'SENTINEL' "$ac10/stage-bad" STUB_HYPRCTL_DEAD=1
o_pf_failed="$DRIVE_OUT"
drive pf-unchk   'SENTINEL' "$ac10/stage-ok"  STUB_HYPR_REJECT=1 STUB_HYPRCTL_DEAD=1
o_pf_unchk="$DRIVE_OUT"
drive untested   'OLD'      "$ac10/stage-ok"  STUB_HYPRCTL_DEAD=1
o_untested="$DRIVE_OUT"
drive live-ok    'OLD'      "$ac10/stage-ok"  STUB_HYPRCTL_LOADED="$(installed_main_of live-ok)"
o_ok="$DRIVE_OUT"
drive unconfirmed 'OLD'     "$ac10/stage-ok"  STUB_HYPRCTL_LOADED="$ac10/t-unconfirmed/hyprland.lua"
o_unconf="$DRIVE_OUT"
drive rolled-back 'OLD'     "$ac10/stage-ok"  STUB_HYPRCTL_ERRORS="Config error in file /x at line 1: nope" \
                                              STUB_HYPRCTL_LOADED="$(installed_main_of rolled-back)"
o_rolled="$DRIVE_OUT"

# A refusal from install-config.sh, which must keep its EXISTING word.
d_ref="$ac10/t-refused"; mkdir -p "$d_ref"
printf -- '-- a lua config that shadows any .conf\n' > "$d_ref/hyprland.lua"
o_refused="$(PATH="$STUB_PATH" STUB_HYPRCTL_DEAD=1 HYPR_DIR="$d_ref" bash "$RS/safe-apply.sh" "$ac10/stage-ok" 2>&1)"
runs+=("refused"$'\x1f'"$o_refused")
words+=("$(outcome "$o_refused")")

# One terminal line per run, and it is the LAST line.
bad_terminal=""
for r in "${runs[@]}"; do
    label="${r%%$'\x1f'*}"; body="${r#*$'\x1f'}"
    n="$(printf '%s\n' "$body" | grep -c '^SAFE_APPLY=')"
    if [ "$n" -ne 1 ]; then
        bad_terminal+="$label: $n SAFE_APPLY= lines"$'\n'
        continue
    fi
    case "$(last_line "$body")" in
        SAFE_APPLY=*) ;;
        *) bad_terminal+="$label: the terminal line is not the SAFE_APPLY= line"$'\n' ;;
    esac
done
if [ -z "$bad_terminal" ]; then
    pass "AC-10: every apply ends with exactly one SAFE_APPLY= line, and it is the last line (${#runs[@]} runs)"
else
    fail "AC-10: every apply ends with exactly one terminal outcome line" "$bad_terminal"
fi

# The seven reachable outcomes are pairwise distinct.
dupes="$(printf '%s\n' "${words[@]}" | sort | uniq -d)"
if [ -z "$dupes" ] && [ "${#words[@]}" -eq 7 ]; then
    pass "AC-10: the seven reachable outcomes are pairwise distinct ($(printf '%s ' "${words[@]}"))"
else
    fail "AC-10: the reachable outcomes are pairwise distinct" "words: ${words[*]}
duplicated: $dupes"
fi

# Named, so a regression that collapses two of them is a failing test and not a shrug.
assert_eq "preflight-failed"      "$(outcome "$o_pf_failed")" "AC-10: an offline-check refusal says preflight-failed"
assert_eq "preflight-uncheckable" "$(outcome "$o_pf_unchk")"  "AC-10: an unrunnable offline check says preflight-uncheckable"
assert_eq "refused"               "$(outcome "$o_refused")"   "AC-10: an install refusal keeps its existing word"
assert_eq "rolled-back"           "$(outcome "$o_rolled")"    "AC-10: a rollback keeps its existing word"
assert_eq "unconfirmed"           "$(outcome "$o_unconf")"    "AC-10: an unconfirmed live install has its own word"
assert_eq "ok"                    "$(outcome "$o_ok")"        "AC-10: a success keeps its existing word"
assert_eq "installed-untested"    "$(outcome "$o_untested")"  "AC-10: installed-untested keeps its existing word"

# Every outcome word the script's own header documents must be unique, including the two
# that are not reachable from here (install-failed, errors-no-backup).
doc_words="$(sed -n 's/^#[[:space:]]*SAFE_APPLY=\([a-z-]*\).*/\1/p' "$RS/safe-apply.sh")"
doc_n="$(printf '%s\n' "$doc_words" | grep -c .)"
doc_u="$(printf '%s\n' "$doc_words" | sort -u | grep -c .)"
if [ "$doc_n" -eq "$doc_u" ] && [ "$doc_n" -ge 9 ]; then
    pass "AC-10: all $doc_n documented SAFE_APPLY= outcome words are distinct"
else
    fail "AC-10: all documented SAFE_APPLY= outcome words are distinct" "$doc_n documented, $doc_u unique:
$doc_words"
fi

rm -rf "$tmp"

#!/usr/bin/env bash
# S0032-hyprland-config-xdg-6 - write where the platform says the config lives.
#
# Grades AC-1 to AC-9. AC-10 is the suite itself (`bash tests/run.sh` with
# XDG_CONFIG_HOME pointed at a temporary directory), so what this file owes AC-10 is
# that every path it touches is inside its own tempdir - which is why HOME,
# XDG_CONFIG_HOME, RICE_RESTORE_DIR and the cwd are all re-pointed for every run below.
#
# Everything runs with PATH=/usr/bin:/bin (plus a stub dir where a stub is the point):
# the `unit` job in .github/workflows/tests.yml is a bare ubuntu-latest with neither
# Hyprland nor hyprctl installed, so no assertion here may depend on a compositor.
#
# The property under every refusal below is the one the spec's blast radius names:
# after a refusal, every config directory on the machine is byte-identical.

RS="$PLUGIN_ROOT/skills/rice/scripts"
PS="$PLUGIN_ROOT/scripts"
tmp="$(mktemp_test_dir xdg-config-home)"

# This file must never inherit a config location from the machine running it.
unset XDG_CONFIG_HOME HYPR_DIR HYPR_BACKUP_DIR RICE_DIR RICE_APPLY_ID RICE_THEMING_ENGINE
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
BIN_PATH="/usr/bin:/bin"

# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------

# `mk_stage <dir>` - the smallest staging set install-config.sh / safe-apply.sh accept.
mk_stage() {
    mkdir -p "$1"
    printf -- '-- CONFIG_LANGUAGE=lua\nhl.config({ general = { gaps_in = 3 } })\n' > "$1/hyprland.lua"
}

# `field <KEY> <output>` - the value of the first `KEY=` line, this repo's output convention.
field() {
    printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -n1
}

assert_out_has() {   # <needle> <output> <name>
    if printf '%s\n' "$2" | grep -qF -- "$1"; then
        pass "$3"
    else
        fail "$3" "missing: $1
--- output ---
$2"
    fi
}

assert_absent() {    # <path> <name>
    if [ ! -e "$1" ]; then pass "$2"; else fail "$2" "exists but must not: $1"; fi
}

# `fingerprint <dir>` - enough to prove a directory is byte-identical afterwards.
fingerprint() {
    local d="${1:-}"
    if [ ! -e "$d" ]; then printf 'ABSENT\n'; return 0; fi
    ( cd "$d" 2>/dev/null && find . | sort
      cd "$d" 2>/dev/null && find . -type f -print0 2>/dev/null | xargs -0 -r cksum 2>/dev/null | sort )
}

is_root=0
[ "$(id -u)" -eq 0 ] && is_root=1

# =============================================================================================
# AC-1  WHEN XDG_CONFIG_HOME is set to an absolute path THE SYSTEM SHALL resolve every config
#       target it writes beneath that path rather than beneath $HOME/.config
# =============================================================================================
a1="$tmp/ac1"; h="$a1/home"; x="$a1/xdg"
mkdir -p "$h" "$x"
mk_stage "$a1/stage"

out="$(HOME="$h" XDG_CONFIG_HOME="$x" PATH="$BIN_PATH" bash "$RS/install-config.sh" "$a1/stage" 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-1: install-config.sh installs under an absolute XDG_CONFIG_HOME"
assert_eq "$x/hypr" "$(field TARGET "$out")" "AC-1: install-config.sh resolves TARGET beneath XDG_CONFIG_HOME"
assert_file_exists "$x/hypr/hyprland.lua" "AC-1: the config file landed beneath XDG_CONFIG_HOME"
assert_absent "$h/.config" "AC-1: nothing was written beneath \$HOME/.config"

out="$(HOME="$h" XDG_CONFIG_HOME="$x" PATH="$BIN_PATH" bash "$RS/backup-config.sh" 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-1: backup-config.sh runs"
assert_eq "$x/hypr" "$(field TARGET "$out")" "AC-1: backup-config.sh backs up the XDG target, not \$HOME/.config"
assert_absent "$h/.config" "AC-1: the backup did not create \$HOME/.config"

out="$(HOME="$h" XDG_CONFIG_HOME="$x" PATH="$BIN_PATH" bash "$RS/migrate-config.sh" 2>&1)"; rc=$?
assert_eq "$x/hypr" "$(field TARGET "$out")" "AC-1: migrate-config.sh resolves TARGET beneath XDG_CONFIG_HOME"

out="$(HOME="$h" XDG_CONFIG_HOME="$x" HYPR_VERSION=0.56.2 PATH="$BIN_PATH" bash "$RS/reset-config.sh" 2>&1)"; rc=$?
assert_eq "$x/hypr" "$(field TARGET "$out")" "AC-1: reset-config.sh wipes and rewrites the XDG target"
assert_file_exists "$x/hypr/hyprland.lua" "AC-1: reset-config.sh wrote the bare config beneath XDG_CONFIG_HOME"
assert_absent "$h/.config" "AC-1: the reset did not create \$HOME/.config"

# safe-apply drives the whole path (preflight -> install -> verify) in one process. With no
# Hyprland and no hyprctl it reports installed-untested, which is the point: the TARGET it
# relays and the directory it installed into are the same one every other script resolved.
mk_stage "$a1/stage2"
out="$(HOME="$h" XDG_CONFIG_HOME="$x" PATH="$BIN_PATH" bash "$RS/safe-apply.sh" "$a1/stage2" 2>&1)"; rc=$?
assert_eq "$x/hypr" "$(field TARGET "$out")" "AC-1: safe-apply.sh's whole path resolves one XDG target"
assert_absent "$h/.config" "AC-1: the full apply path never touched \$HOME/.config"

# =============================================================================================
# AC-2  IF XDG_CONFIG_HOME is unset or empty THEN THE SYSTEM SHALL use $HOME/.config
# =============================================================================================
a2="$tmp/ac2"; h="$a2/home"
mkdir -p "$h"
mk_stage "$a2/stage"

out="$( unset XDG_CONFIG_HOME; HOME="$h" PATH="$BIN_PATH" bash "$RS/install-config.sh" "$a2/stage" 2>&1 )"; rc=$?
assert_eq "0" "$rc" "AC-2: install-config.sh runs with XDG_CONFIG_HOME unset"
assert_eq "$h/.config/hypr" "$(field TARGET "$out")" "AC-2: unset XDG_CONFIG_HOME resolves \$HOME/.config"
assert_file_exists "$h/.config/hypr/hyprland.lua" "AC-2: the config landed under \$HOME/.config"

h="$a2/home-empty"; mkdir -p "$h"
mk_stage "$a2/stage2"
out="$(HOME="$h" XDG_CONFIG_HOME="" PATH="$BIN_PATH" bash "$RS/install-config.sh" "$a2/stage2" 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-2: install-config.sh runs with XDG_CONFIG_HOME empty"
assert_eq "$h/.config/hypr" "$(field TARGET "$out")" "AC-2: empty XDG_CONFIG_HOME resolves \$HOME/.config"
assert_file_exists "$h/.config/hypr/hyprland.lua" "AC-2: the config landed under \$HOME/.config (empty value)"

out="$(HOME="$h" XDG_CONFIG_HOME="" PATH="$BIN_PATH" bash "$RS/backup-config.sh" 2>&1)"
assert_eq "$h/.config/hypr" "$(field TARGET "$out")" "AC-2: backup-config.sh agrees on the default"
out="$(HOME="$h" XDG_CONFIG_HOME="" HYPR_VERSION=0.56.2 PATH="$BIN_PATH" bash "$RS/reset-config.sh" 2>&1)"
assert_eq "$h/.config/hypr" "$(field TARGET "$out")" "AC-2: reset-config.sh agrees on the default"

# =============================================================================================
# AC-3  IF XDG_CONFIG_HOME is set to a relative path THEN THE SYSTEM SHALL treat it as invalid
#       and SHALL fall back to $HOME/.config rather than writing beneath the working directory
# =============================================================================================
a3="$tmp/ac3"; h="$a3/home"; cwd="$a3/cwd"
mkdir -p "$h" "$cwd"
mk_stage "$a3/stage"

out="$( cd "$cwd" && HOME="$h" XDG_CONFIG_HOME="relative/cfg" PATH="$BIN_PATH" \
        bash "$RS/install-config.sh" "$a3/stage" 2>&1 )"; rc=$?
assert_eq "0" "$rc" "AC-3: a relative XDG_CONFIG_HOME does not abort the install"
assert_eq "$h/.config/hypr" "$(field TARGET "$out")" "AC-3: a relative XDG_CONFIG_HOME falls back to \$HOME/.config"
assert_file_exists "$h/.config/hypr/hyprland.lua" "AC-3: the config landed under the fallback"
assert_absent "$cwd/relative" "AC-3: nothing was written beneath the working directory"

# `./cfg` and a bare `cfg` are both relative; neither may be honoured.
h="$a3/home2"; mkdir -p "$h"
mk_stage "$a3/stage2"
out="$( cd "$cwd" && HOME="$h" XDG_CONFIG_HOME="./dotslash" PATH="$BIN_PATH" \
        bash "$RS/install-config.sh" "$a3/stage2" 2>&1 )"
assert_eq "$h/.config/hypr" "$(field TARGET "$out")" "AC-3: a './'-prefixed relative value is invalid too"
assert_absent "$cwd/dotslash" "AC-3: nothing was written beneath the working directory (./ form)"

# Every script in the apply path must agree, or a backup and a wipe name different dirs.
out="$( cd "$cwd" && HOME="$h" XDG_CONFIG_HOME="relative/cfg" PATH="$BIN_PATH" bash "$RS/backup-config.sh" 2>&1 )"
assert_eq "$h/.config/hypr" "$(field TARGET "$out")" "AC-3: backup-config.sh falls back the same way"
out="$( cd "$cwd" && HOME="$h" XDG_CONFIG_HOME="relative/cfg" HYPR_VERSION=0.56.2 PATH="$BIN_PATH" bash "$RS/reset-config.sh" 2>&1 )"
assert_eq "$h/.config/hypr" "$(field TARGET "$out")" "AC-3: reset-config.sh falls back the same way"
out="$( cd "$cwd" && HOME="$h" XDG_CONFIG_HOME="relative/cfg" PATH="$BIN_PATH" bash "$RS/migrate-config.sh" 2>&1 )"
assert_eq "$h/.config/hypr" "$(field TARGET "$out")" "AC-3: migrate-config.sh falls back the same way"

# =============================================================================================
# AC-4  WHEN the plugin reports where it installed a config THE SYSTEM SHALL print the resolved
#       absolute target path
# =============================================================================================
a4="$tmp/ac4"; h="$a4/home"; x="$a4/xdg"
mkdir -p "$h" "$x"
mk_stage "$a4/stage"

reported=""
missing=""
for pair in "install-config.sh $a4/stage" "backup-config.sh" "migrate-config.sh" "reset-config.sh"; do
    # shellcheck disable=SC2086
    set -- $pair
    s="$1"; shift
    o="$(HOME="$h" XDG_CONFIG_HOME="$x" HYPR_VERSION=0.56.2 PATH="$BIN_PATH" bash "$RS/$s" "$@" 2>&1)"
    t="$(field TARGET "$o")"
    case "$t" in
        /*) reported="$reported $s" ;;
        *)  missing="$missing $s(got:'${t}')" ;;
    esac
done
if [ -z "$missing" ]; then
    pass "AC-4: every write-reporting script prints an absolute TARGET= ($reported)"
else
    fail "AC-4: every write-reporting script prints an absolute TARGET=" "no absolute TARGET= from:$missing"
fi

# safe-apply.sh parses install-config.sh's TARGET= line to build the file it asks the
# compositor to confirm. That contract is load-bearing between two scripts, not cosmetic.
mk_stage "$a4/stage2"
out="$(HOME="$h" XDG_CONFIG_HOME="$x" PATH="$BIN_PATH" bash "$RS/safe-apply.sh" "$a4/stage2" 2>&1)"
assert_eq "$x/hypr" "$(field TARGET "$out")" "AC-4: safe-apply.sh still parses install-config.sh's TARGET= line"

# A refusal reports the resolved path too - a user told "refused" without being told WHERE
# cannot act on it.
a4r="$tmp/ac4r"; hr="$a4r/home"; xr="$a4r/xdg"
mkdir -p "$hr" "$xr/hypr"
printf -- 'hl.config({})\n' > "$xr/hypr/hyprland.lua"     # shadows a hyprlang install
mkdir -p "$a4r/stage"
printf 'general {\n    gaps_in = 5\n}\n' > "$a4r/stage/hyprland.conf"
out="$(HOME="$hr" XDG_CONFIG_HOME="$xr" PATH="$BIN_PATH" bash "$RS/install-config.sh" "$a4r/stage" 2>&1)"; rc=$?
assert_eq "3" "$rc" "AC-4: a shadowed install is refused"
assert_eq "$xr/hypr" "$(field TARGET "$out")" "AC-4: the refusal names the resolved absolute target"

# =============================================================================================
# AC-5  WHEN an explicit config-directory override is set in the environment THE SYSTEM SHALL
#       write beneath that override and SHALL ignore XDG_CONFIG_HOME, whatever value it holds
# =============================================================================================
a5="$tmp/ac5"; h="$a5/home"; x="$a5/xdg"
mkdir -p "$h" "$x"
mk_stage "$a5/stage"

out="$(HOME="$h" XDG_CONFIG_HOME="$x" HYPR_DIR="$a5/explicit" PATH="$BIN_PATH" \
       bash "$RS/install-config.sh" "$a5/stage" 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-5: HYPR_DIR install runs"
assert_eq "$a5/explicit" "$(field TARGET "$out")" "AC-5: HYPR_DIR wins over an absolute XDG_CONFIG_HOME"
assert_file_exists "$a5/explicit/hyprland.lua" "AC-5: the config landed in the override"
assert_absent "$x/hypr" "AC-5: XDG_CONFIG_HOME was ignored entirely"
assert_absent "$h/.config" "AC-5: \$HOME/.config was ignored entirely"

# ... whatever value XDG_CONFIG_HOME holds: relative, and empty.
mk_stage "$a5/stage2"
out="$(HOME="$h" XDG_CONFIG_HOME="nonsense/rel" HYPR_DIR="$a5/explicit2" PATH="$BIN_PATH" \
       bash "$RS/install-config.sh" "$a5/stage2" 2>&1)"
assert_eq "$a5/explicit2" "$(field TARGET "$out")" "AC-5: HYPR_DIR wins over a relative XDG_CONFIG_HOME"
mk_stage "$a5/stage3"
out="$(HOME="$h" XDG_CONFIG_HOME="" HYPR_DIR="$a5/explicit3" PATH="$BIN_PATH" \
       bash "$RS/install-config.sh" "$a5/stage3" 2>&1)"
assert_eq "$a5/explicit3" "$(field TARGET "$out")" "AC-5: HYPR_DIR wins over an empty XDG_CONFIG_HOME"

# The same for the themed side: RICE_DIR is the rice state directory's explicit override.
out="$(HOME="$h" XDG_CONFIG_HOME="$x" RICE_DIR="$a5/rice" PATH="$BIN_PATH" \
       bash "$RS/rice-init.sh" 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-5: rice-init.sh runs with an explicit RICE_DIR"
assert_eq "$a5/rice" "$(field RICE_DIR "$out")" "AC-5: RICE_DIR wins over an absolute XDG_CONFIG_HOME"
assert_file_exists "$a5/rice/palette.conf" "AC-5: the rice state landed in the override"
assert_absent "$x/hypr-rice" "AC-5: XDG_CONFIG_HOME was ignored for the rice state dir too"

# =============================================================================================
# AC-6  IF a value supplied for XDG_CONFIG_HOME is rejected as invalid THEN THE SYSTEM SHALL
#       name the rejected value and the absolute path it fell back to, on its own output,
#       rather than falling back silently
# =============================================================================================
a6="$tmp/ac6"; h="$a6/home"
mkdir -p "$h"
mk_stage "$a6/stage"

out="$(HOME="$h" XDG_CONFIG_HOME="oops/relative" PATH="$BIN_PATH" bash "$RS/install-config.sh" "$a6/stage" 2>&1)"
assert_eq "oops/relative" "$(field XDG_CONFIG_HOME_IGNORED "$out")" \
    "AC-6: the rejected value is named on the output"
assert_out_has "$h/.config" "$out" "AC-6: the absolute path it fell back to is named on the output"
if printf '%s\n' "$out" | grep -q '^CONFIG_BASE=/'; then
    pass "AC-6: the fallback is reported as an absolute path"
else
    fail "AC-6: the fallback is reported as an absolute path" "$out"
fi

# Not silent anywhere on the apply path: whichever script the user ran, they are told.
for s in backup-config.sh reset-config.sh migrate-config.sh; do
    o="$(HOME="$h" XDG_CONFIG_HOME="oops/relative" HYPR_VERSION=0.56.2 PATH="$BIN_PATH" bash "$RS/$s" 2>&1)"
    assert_eq "oops/relative" "$(field XDG_CONFIG_HOME_IGNORED "$o")" \
        "AC-6: $s names the rejected value rather than falling back silently"
done

# An ACCEPTED value is not reported as ignored - the notice means something.
o="$(HOME="$h" XDG_CONFIG_HOME="$a6/good" PATH="$BIN_PATH" bash "$RS/backup-config.sh" 2>&1)"
if printf '%s\n' "$o" | grep -q 'XDG_CONFIG_HOME_IGNORED='; then
    fail "AC-6: an absolute value is not reported as ignored" "$o"
else
    pass "AC-6: an absolute value is not reported as ignored"
fi

# =============================================================================================
# AC-7  WHEN XDG_CONFIG_HOME is set to an absolute path and a themed, non-hypr surface is
#       written THE SYSTEM SHALL resolve that surface's destination beneath that path too, and
#       SHALL leave the cache and runtime destinations resolving exactly as they do today
# =============================================================================================
a7="$tmp/ac7"; h="$a7/home"; x="$a7/xdg"
mkdir -p "$h" "$x"
wp="$a7/wall.png"; printf 'PNG\n' > "$wp"

# A `magick` stub: the pre-baked lock blur is the one CACHE destination this pass writes, and
# it has to keep resolving under $HOME/.cache. Without a stub the step self-skips and proves
# nothing.
stub="$a7/stubs"; mkdir -p "$stub"
cat > "$stub/magick" <<'STUB'
#!/usr/bin/env bash
out="${*: -1}"
printf 'BLURRED\n' > "$out"
STUB
chmod +x "$stub/magick"

out="$(HOME="$h" XDG_CONFIG_HOME="$x" PATH="$BIN_PATH" bash "$RS/rice-init.sh" 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-7: rice-init.sh scaffolds under an absolute XDG_CONFIG_HOME"
assert_eq "$x/hypr-rice" "$(field RICE_DIR "$out")" "AC-7: the rice state directory resolves beneath XDG_CONFIG_HOME"
assert_file_exists "$x/hypr-rice/palette.conf" "AC-7: the rice state landed beneath XDG_CONFIG_HOME"
assert_absent "$h/.config/hypr-rice" "AC-7: the rice state did NOT land under \$HOME/.config"

printf 'wallpaper=%s\n' "$wp" >> "$x/hypr-rice/palette.conf"
out="$(HOME="$h" XDG_CONFIG_HOME="$x" RICE_RESTORE_DIR="$a7/state/restore" RICE_LOCK_BLUR=pre-baked \
       PATH="$stub:$BIN_PATH" bash "$RS/render-templates.sh" --no-reload 2>&1)"; rc=$?
assert_eq "0" "$rc" "AC-7: the render pass runs"
assert_file_exists "$x/waybar/colors.css" "AC-7: a themed non-hypr surface resolves beneath XDG_CONFIG_HOME"
assert_file_exists "$x/kitty/colors.conf" "AC-7: every themed surface follows, not just one"
assert_file_exists "$x/hypr/colors.conf"  "AC-7: the hypr surface follows too"
assert_absent "$h/.config/waybar" "AC-7: the themed surface did NOT land under \$HOME/.config"
assert_absent "$h/.config" "AC-7: the render pass created no \$HOME/.config at all"

# The cache destination is XDG_CACHE_HOME's business, not this phase's: unchanged.
assert_file_exists "$h/.cache/hypr-rice/lock-blur.png" "AC-7: the lock-blur cache still resolves under \$HOME/.cache"
assert_absent "$x/hypr-rice/lock-blur.png" "AC-7: the cache did NOT move under XDG_CONFIG_HOME"
assert_absent "$x/.cache" "AC-7: no cache tree appeared beneath XDG_CONFIG_HOME"

# The one script that SETS XDG_CONFIG_HOME (preflight's throwaway sandbox) is out of this
# phase's scope and must stay a sandbox assignment, never a read of the user's value.
if grep -q 'XDG_CONFIG_HOME="\$sandbox_home/.config"' "$RS/preflight-config.sh"; then
    pass "AC-7: preflight's sandbox assignment is untouched (it configures a check, it is not a read)"
else
    fail "AC-7: preflight's sandbox assignment is untouched" "preflight-config.sh no longer sets XDG_CONFIG_HOME for its sandbox"
fi

# =============================================================================================
# AC-8  IF XDG_CONFIG_HOME is unset or empty AND HOME is also unset or empty THEN THE SYSTEM
#       SHALL refuse the operation, report that it cannot determine a config directory, and
#       write nothing, rather than resolving a path beneath the filesystem root or beneath the
#       working directory
# =============================================================================================
a8="$tmp/ac8"; cwd="$a8/cwd"
mkdir -p "$cwd"
mk_stage "$a8/stage"

# install-config.sh
out="$( cd "$cwd" && unset HOME XDG_CONFIG_HOME; PATH="$BIN_PATH" bash "$RS/install-config.sh" "$a8/stage" 2>&1 )"; rc=$?
if [ "$rc" -ne 0 ]; then pass "AC-8: install-config.sh refuses with no HOME and no XDG_CONFIG_HOME"
else fail "AC-8: install-config.sh refuses with no HOME and no XDG_CONFIG_HOME" "rc=0
$out"; fi
assert_out_has "CONFIG_DIR=unresolved" "$out" "AC-8: install-config.sh reports it cannot determine a config directory"
assert_absent "$cwd/.config" "AC-8: install-config.sh wrote nothing beneath the working directory"

# The same answer from every script that writes, not just the one the user happened to run.
for pair in "backup-config.sh" "reset-config.sh" "migrate-config.sh"; do
    o="$( cd "$cwd" && unset HOME XDG_CONFIG_HOME; HYPR_VERSION=0.56.2 PATH="$BIN_PATH" bash "$RS/$pair" 2>&1 )"; orc=$?
    if [ "$orc" -ne 0 ] && printf '%s\n' "$o" | grep -q 'CONFIG_DIR=unresolved'; then
        pass "AC-8: $pair refuses and says why"
    else
        fail "AC-8: $pair refuses and says why" "rc=$orc
$o"
    fi
done
o="$( cd "$cwd" && unset HOME XDG_CONFIG_HOME; PATH="$BIN_PATH" bash "$RS/safe-apply.sh" "$a8/stage" 2>&1 )"; orc=$?
if [ "$orc" -ne 0 ] && printf '%s\n' "$o" | grep -q 'SAFE_APPLY=no-config-dir'; then
    pass "AC-8: safe-apply.sh refuses before the preflight, backup or install"
else
    fail "AC-8: safe-apply.sh refuses before the preflight, backup or install" "rc=$orc
$o"
fi
o="$( cd "$cwd" && unset HOME XDG_CONFIG_HOME; PATH="$BIN_PATH" bash "$RS/render-templates.sh" 2>&1 )"; orc=$?
if [ "$orc" -ne 0 ] && printf '%s\n' "$o" | grep -q 'CONFIG_DIR=unresolved'; then
    pass "AC-8: render-templates.sh refuses rather than rendering into an unknown place"
else
    fail "AC-8: render-templates.sh refuses rather than rendering into an unknown place" "rc=$orc
$o"
fi

assert_absent "$cwd/.config" "AC-8: no script wrote a config tree beneath the working directory"
assert_absent "/.config"     "AC-8: no script resolved a path beneath the filesystem root"

# An EMPTY HOME is the same case as an unset one.
o="$( cd "$cwd" && HOME="" XDG_CONFIG_HOME="" PATH="$BIN_PATH" bash "$RS/install-config.sh" "$a8/stage" 2>&1 )"; orc=$?
if [ "$orc" -ne 0 ] && printf '%s\n' "$o" | grep -q 'CONFIG_DIR=unresolved'; then
    pass "AC-8: an empty HOME with an empty XDG_CONFIG_HOME refuses too"
else
    fail "AC-8: an empty HOME with an empty XDG_CONFIG_HOME refuses too" "rc=$orc
$o"
fi

# A relative XDG_CONFIG_HOME with no HOME leaves nothing to fall back TO - still a refusal,
# never a write beneath the working directory.
o="$( cd "$cwd" && unset HOME; XDG_CONFIG_HOME="rel/ative" PATH="$BIN_PATH" bash "$RS/install-config.sh" "$a8/stage" 2>&1 )"; orc=$?
if [ "$orc" -ne 0 ] && printf '%s\n' "$o" | grep -q 'CONFIG_DIR=unresolved'; then
    pass "AC-8: a relative XDG_CONFIG_HOME with no HOME refuses instead of using the cwd"
else
    fail "AC-8: a relative XDG_CONFIG_HOME with no HOME refuses instead of using the cwd" "rc=$orc
$o"
fi
assert_absent "$cwd/rel" "AC-8: still nothing beneath the working directory"

# The explicit override still works with no HOME and no XDG_CONFIG_HOME - refusing THAT would
# be a regression, not a fail-safe.
mk_stage "$a8/stage2"
o="$( cd "$cwd" && unset HOME XDG_CONFIG_HOME; HYPR_DIR="$a8/explicit" PATH="$BIN_PATH" bash "$RS/install-config.sh" "$a8/stage2" 2>&1 )"; orc=$?
assert_eq "0" "$orc" "AC-8: an explicit HYPR_DIR still installs with neither HOME nor XDG_CONFIG_HOME"
assert_file_exists "$a8/explicit/hyprland.lua" "AC-8: the override was honoured"

# =============================================================================================
# AC-9  IF the resolved config directory exists but cannot be written by the invoking user THEN
#       THE SYSTEM SHALL report the resolved absolute path and the failure, SHALL NOT fall back
#       to any other directory, and SHALL leave every config directory on the machine
#       byte-identical to what it was
# =============================================================================================
if [ "$is_root" -eq 1 ]; then
    skip "AC-9: unwritable resolved config dir" "running as root; permission bits do not bind"
else
    a9="$tmp/ac9"; h="$a9/home"; x="$a9/xdg"
    mkdir -p "$h" "$x/hypr"
    printf -- 'hl.config({ general = { gaps_in = 1 } })\n' > "$x/hypr/hyprland.lua"
    mk_stage "$a9/stage"
    chmod 500 "$x/hypr"
    before="$(fingerprint "$x/hypr")"

    out="$(HOME="$h" XDG_CONFIG_HOME="$x" PATH="$BIN_PATH" bash "$RS/install-config.sh" "$a9/stage" 2>&1)"; rc=$?
    assert_eq "4" "$rc" "AC-9: install-config.sh refuses an unwritable resolved target"
    assert_eq "$x/hypr" "$(field TARGET "$out")" "AC-9: the refusal names the resolved absolute path"
    assert_out_has "REFUSED=target-not-writable" "$out" "AC-9: the refusal names the failure"
    assert_eq "$before" "$(fingerprint "$x/hypr")" "AC-9: the resolved config dir is byte-identical afterwards"
    assert_absent "$h/.config" "AC-9: it did NOT fall back to \$HOME/.config"

    out="$(HOME="$h" XDG_CONFIG_HOME="$x" HYPR_VERSION=0.56.2 PATH="$BIN_PATH" bash "$RS/reset-config.sh" 2>&1)"; rc=$?
    assert_eq "4" "$rc" "AC-9: reset-config.sh refuses an unwritable resolved target rather than half-wiping it"
    assert_eq "$x/hypr" "$(field TARGET "$out")" "AC-9: the reset refusal names the resolved absolute path"
    assert_out_has "RESET=refused-target-not-writable" "$out" "AC-9: the reset refusal names the failure"
    assert_eq "$before" "$(fingerprint "$x/hypr")" "AC-9: the config dir is byte-identical after the refused reset"
    assert_absent "$h/.config" "AC-9: the refused reset did NOT fall back to \$HOME/.config"

    mk_stage "$a9/stage2"
    out="$(HOME="$h" XDG_CONFIG_HOME="$x" PATH="$BIN_PATH" bash "$RS/safe-apply.sh" "$a9/stage2" 2>&1)"; rc=$?
    assert_out_has "SAFE_APPLY=refused" "$out" "AC-9: the whole apply path refuses rather than reporting success"
    assert_eq "$before" "$(fingerprint "$x/hypr")" "AC-9: the config dir is byte-identical after the refused apply"
    assert_absent "$h/.config" "AC-9: the refused apply did NOT fall back to \$HOME/.config"

    chmod 700 "$x/hypr"
fi

# =============================================================================================
# The invariant behind all nine: ONE decision, not five. A shipped script that spells
# $HOME/.config for itself has re-opened the split-resolution failure the spec names as the
# irreversible one (a backup taken from directory A while a wipe empties directory B). Every
# deliberate exception carries an `XDG-OK` marker saying why.
#
# The same rule for the STATE root ($HOME/.local/state, answered once by restore-point.sh's
# rp_state_root): a second spelling is how a record gets written where `rice installs` and
# `rice prefs` do not look. One scan, both bases, so neither can drift unnoticed.
# =============================================================================================
mapfile -t shipped < <(
    find "$PLUGIN_ROOT" -type f \( -name '*.sh' -o -name 'rice' \) \
        -not -path '*/tests/*' -not -path '*/.git/*' \
        -not -path '*/scripts/xdg-config.sh' \
    | sort
)
scan_base() {   # <extended-regex> -> every unmarked, non-comment hit, one per line
    local pattern="$1" f line body found=""
    for f in "${shipped[@]}"; do
        while IFS= read -r line; do
            case "$line" in
                *XDG-OK*) continue ;;
            esac
            # Comments describing the rule are prose, not a resolution.
            body="${line#*:}"
            case "$(printf '%s' "$body" | sed 's/^[[:space:]]*//')" in
                '#'*) continue ;;
            esac
            found+="$f: $line"$'\n'
        done < <(grep -nE "$pattern" "$f" || true)
    done
    printf '%s' "$found"
}

unmarked="$(scan_base '\$\{?HOME[:}-]*\}?/\.config')"
if [ -z "$unmarked" ]; then
    pass "one decision: no shipped script resolves \$HOME/.config on its own (${#shipped[@]} scanned)"
else
    fail "one decision: no shipped script resolves \$HOME/.config on its own" "$unmarked"
fi

unmarked="$(scan_base '\$\{?HOME[:}-]*\}?/\.local/state')"
if [ -z "$unmarked" ]; then
    pass "one decision: no shipped script resolves \$HOME/.local/state on its own (${#shipped[@]} scanned)"
else
    fail "one decision: no shipped script resolves \$HOME/.local/state on its own" "$unmarked"
fi

# The marker is an exception, not a licence. The deliberate state-root spellings are
# rp_state_root (the decision itself) and the two library-missing fallbacks that mirror it word
# for word; a marked line anywhere else is a fourth state root wearing a permission slip.
stray=""
while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    case "${hit%%:*}" in
        */scripts/restore-point.sh|*/scripts/install-record.sh|*/scripts/firefox-prefs.sh) continue ;;
    esac
    stray+="$hit"$'\n'
done < <(grep -rn '\.local/state.*XDG-OK' --include='*.sh' --include='rice' "$PLUGIN_ROOT" 2>/dev/null \
         | grep -v '/tests/' || true)
if [ -z "$stray" ]; then
    pass "one decision: only rp_state_root and its two library-missing fallbacks carry an XDG-OK marker"
else
    fail "one decision: only rp_state_root and its two library-missing fallbacks carry an XDG-OK marker" "$stray"
fi

rm -rf "$tmp"

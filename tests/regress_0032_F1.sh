#!/usr/bin/env bash
# S0032-hyprland-config-xdg-6 impl-gate probes (refuter, report-only).
#
# Five things the shipped suite does not execute:
#
#  A. Acceptance criterion 10's own trigger. The graded route (`bash tests/run.sh`)
#     inherits whatever XDG_CONFIG_HOME the invoking shell holds, so running it bare
#     never exercises "with XDG_CONFIG_HOME pointed at a temporary directory". This
#     runs the whole suite once with HOME and XDG_CONFIG_HOME both pointed at fresh
#     temporary directories and grades both obligations.
#  B. The installed rice engine WITHOUT the plugin, under an absolute XDG_CONFIG_HOME.
#     Every engine script now hard-refuses (exit 2) when it cannot find the shared
#     config-path library, and rice-init.sh is the only thing that puts a copy beside
#     them.
#  C. migrate-config.sh --convert under an absolute XDG_CONFIG_HOME, including a
#     `source = ~/.config/hypr/...` line, which resolves through the separate
#     home_config_dir rule.
#  D. safe-apply.sh with a RELATIVE XDG_CONFIG_HOME: the invalid-value notice is
#     printed on the same stdout channel safe-apply parses install-config.sh's
#     `TARGET=` line from.
#  E. The blast radius the spec names: backup-config.sh and reset-config.sh must
#     resolve ONE directory, so the backup a reset takes is of the tree it wipes.
#
# Standalone: bash tests/regress_0032_F1.sh   (set S0032_SKIP_SUITE=1 to skip A)
# Exit 0 = all hold, 1 = something failed.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
RS="$root/skills/rice/scripts"
fails=0

ok()  { echo "PASS $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }

# --- A. criterion 10 with the trigger it names -------------------------------------
if [ -z "${S0032_SKIP_SUITE:-}" ]; then
    tmpA="$(mktemp -d /tmp/regress-0032-A.XXXXXX)"
    mkdir -p "$tmpA/xdg" "$tmpA/home"
    outA="$(HOME="$tmpA/home" XDG_CONFIG_HOME="$tmpA/xdg" bash "$root/tests/run.sh" 2>&1)"; rcA=$?
    if [ "$rcA" -eq 0 ]; then
        ok "AC-10: full suite exits 0 with XDG_CONFIG_HOME at a temporary directory"
    else
        bad "AC-10: full suite exits 0 with XDG_CONFIG_HOME at a temporary directory (exit $rcA)"
        printf '%s\n' "$outA" | grep -E '✗|Failed in:|^  - ' | head -40
    fi
    printf '%s\n' "$outA" | grep -A1 'Summary' | tail -1
    if [ ! -e "$tmpA/home/.config" ]; then
        ok "AC-10: \$HOME/.config was left untouched (never created)"
    else
        bad "AC-10: \$HOME/.config was written to"
        find "$tmpA/home/.config" | head -30
    fi
    rm -rf "$tmpA"
fi

# --- B. the installed engine, no plugin, absolute XDG_CONFIG_HOME -------------------
tmpB="$(mktemp -d /tmp/regress-0032-B.XXXXXX)"
mkdir -p "$tmpB/xdg" "$tmpB/home" "$tmpB/plugin"
cp -a "$root/." "$tmpB/plugin/"
outB="$(HOME="$tmpB/home" XDG_CONFIG_HOME="$tmpB/xdg" \
        bash "$tmpB/plugin/skills/rice/scripts/rice-init.sh" 2>&1)"; rcB=$?
if [ "$rcB" -eq 0 ]; then ok "rice-init.sh scaffolds under XDG (rc 0)"; else bad "rice-init.sh rc=$rcB
$outB"; fi

RD="$tmpB/xdg/hypr-rice"
rm -rf "$tmpB/plugin"    # the plugin is now gone; the installed engine must stand alone
for s in rice render-templates.sh set-wallpaper.sh palette-from-wallpaper.sh \
         firefox-bootstrap.sh xdg-config.sh restore-point.sh rice-restore.sh backup-path.sh; do
    if [ -f "$RD/$s" ]; then ok "installed: $s"; else bad "installed: $s (missing from $RD)"; fi
done
o="$(cd "$tmpB" && HOME="$tmpB/home" XDG_CONFIG_HOME="$tmpB/xdg" bash "$RD/rice" help 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! printf '%s\n' "$o" | grep -q 'config-path library'; then
    ok "installed rice CLI runs with the plugin gone"
else
    bad "installed rice CLI (rc=$rc)
$o"
fi
o="$(cd "$tmpB" && HOME="$tmpB/home" XDG_CONFIG_HOME="$tmpB/xdg" \
     bash "$RD/render-templates.sh" --no-reload 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then ok "installed render engine runs with the plugin gone"; else bad "installed render engine (rc=$rc)
$o"; fi
if [ -f "$tmpB/xdg/waybar/colors.css" ]; then
    ok "installed render engine writes beneath XDG_CONFIG_HOME"
else
    bad "installed render engine did not write \$XDG_CONFIG_HOME/waybar/colors.css"
fi
if [ ! -e "$tmpB/home/.config" ]; then
    ok "installed render engine created no \$HOME/.config"
else
    bad "installed render engine created \$HOME/.config"; find "$tmpB/home/.config" | head -20
fi
rm -rf "$tmpB"

# --- C. migrate-config.sh --convert under an absolute XDG_CONFIG_HOME ---------------
tmpC="$(mktemp -d /tmp/regress-0032-C.XXXXXX)"
mkdir -p "$tmpC/xdg/hypr" "$tmpC/home"
printf 'general {\n    gaps_in = 4\n}\nsource = ~/.config/hypr/env.conf\n' > "$tmpC/xdg/hypr/hyprland.conf"
printf 'env = XCURSOR_SIZE,24\n' > "$tmpC/xdg/hypr/env.conf"
o="$(HOME="$tmpC/home" XDG_CONFIG_HOME="$tmpC/xdg" PATH=/usr/bin:/bin \
     bash "$RS/migrate-config.sh" --convert 2>&1)"
t="$(printf '%s\n' "$o" | sed -n 's/^TARGET=//p' | head -1)"
if [ "$t" = "$tmpC/xdg/hypr" ]; then ok "migrate --convert targets the XDG dir"
else bad "migrate --convert TARGET='$t' (expected $tmpC/xdg/hypr)
$o"; fi
if printf '%s\n' "$o" | grep -q 'MIGRATE=refused-unresolvable-source'; then
    bad "migrate --convert cannot resolve a 'source = ~/.config/hypr/...' line under XDG
$o"
else
    ok "migrate --convert resolves a 'source = ~/.config/hypr/...' line under XDG"
fi
if [ ! -e "$tmpC/home/.config" ]; then ok "migrate --convert created no \$HOME/.config"
else bad "migrate --convert created \$HOME/.config"; fi
rm -rf "$tmpC"

# --- D. safe-apply.sh with a RELATIVE XDG_CONFIG_HOME -------------------------------
tmpD="$(mktemp -d /tmp/regress-0032-D.XXXXXX)"
mkdir -p "$tmpD/home" "$tmpD/cwd" "$tmpD/stage"
printf -- '-- CONFIG_LANGUAGE=lua\nhl.config({ general = { gaps_in = 3 } })\n' > "$tmpD/stage/hyprland.lua"
o="$(cd "$tmpD/cwd" && HOME="$tmpD/home" XDG_CONFIG_HOME="rel/ative" PATH=/usr/bin:/bin \
     bash "$RS/safe-apply.sh" "$tmpD/stage" 2>&1)"
t="$(printf '%s\n' "$o" | sed -n 's/^TARGET=//p' | head -1)"
if [ "$t" = "$tmpD/home/.config/hypr" ]; then
    ok "safe-apply still parses an absolute TARGET= with the invalid-value notice on the same channel"
else
    bad "safe-apply TARGET='$t' (expected $tmpD/home/.config/hypr)
$o"
fi
if printf '%s\n' "$o" | grep -q '^XDG_CONFIG_HOME_IGNORED=rel/ative'; then
    ok "safe-apply relays the rejected value"
else
    bad "safe-apply did not relay XDG_CONFIG_HOME_IGNORED=
$o"
fi
if [ ! -e "$tmpD/cwd/rel" ]; then ok "safe-apply wrote nothing beneath the working directory"
else bad "safe-apply wrote beneath the working directory"; fi
rm -rf "$tmpD"

# --- E. the blast radius: one directory for the backup and the wipe -----------------
tmpE="$(mktemp -d /tmp/regress-0032-E.XXXXXX)"
mkdir -p "$tmpE/home" "$tmpE/xdg/hypr"
printf 'general { gaps_in = 9 }\n' > "$tmpE/xdg/hypr/hyprland.conf"
ob="$(HOME="$tmpE/home" XDG_CONFIG_HOME="$tmpE/xdg" PATH=/usr/bin:/bin bash "$RS/backup-config.sh" 2>&1)"
bt="$(printf '%s\n' "$ob" | sed -n 's/^TARGET=//p' | head -1)"
bk="$(printf '%s\n' "$ob" | sed -n 's/^BACKUP=//p' | head -1)"
orr="$(HOME="$tmpE/home" XDG_CONFIG_HOME="$tmpE/xdg" HYPR_VERSION=0.56.2 PATH=/usr/bin:/bin bash "$RS/reset-config.sh" 2>&1)"
rt="$(printf '%s\n' "$orr" | sed -n 's/^TARGET=//p' | head -1)"
if [ -n "$bt" ] && [ "$bt" = "$rt" ]; then
    ok "backup and reset resolve ONE directory ($bt)"
else
    bad "split resolution: backup TARGET='$bt' vs reset TARGET='$rt'
--- backup ---
$ob
--- reset ---
$orr"
fi
case "$bk" in
    "$tmpE/xdg/hypr".bak.*) ok "the backup was taken from the directory the reset wipes" ;;
    *) bad "backup landed at '$bk', not beside $tmpE/xdg/hypr" ;;
esac
if grep -q 'gaps_in = 9' "$bk/hyprland.conf" 2>/dev/null; then
    ok "the backup holds the pre-reset content"
else
    bad "the backup does not hold the pre-reset content ($bk)"
fi
if [ ! -e "$tmpE/home/.config" ]; then ok "the backup/reset pair created no \$HOME/.config"
else bad "the backup/reset pair created \$HOME/.config"; fi
rm -rf "$tmpE"

echo "---"
if [ "$fails" -eq 0 ]; then echo "ALL PROBES PASSED"; exit 0; fi
echo "$fails PROBE(S) FAILED"; exit 1

#!/usr/bin/env bash
# Backup-before-write and one restore point per apply, across all three stages a single apply
# writes through: the render pipeline's template pass, the browser theming step, and a shell-rc
# edit. Covers: every existing output copied to a timestamped backup before it is overwritten
# and every file of one apply sharing one identifier (AC1); a pre-existing output no previous
# apply wrote backed up on first touch, with what it replaced recorded (AC3); the Firefox
# profile files enrolled under that same apply id (AC5); a shell rc file backed up, sharing the
# apply's id inside an apply and getting its own restore point standalone (AC6); and the
# fail-safe when a backup or its restore-point entry cannot be written - the surface is NOT
# rendered, the reason is reported, and the rest of the manifest is unaffected (AC10, including
# a brand-new output with no prior content, per verdict-spec-2 F6).
#
# The Hyprland config dir is out of scope for this mechanism by construction: this file asserts
# that a manifest line pointing into it is never enrolled and never gets a sidecar here.

tmp="$(mktemp_test_dir restore-point)"
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

export HOME="$tmp"
export RICE_DIR="$HOME/.config/hypr-rice"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
export RICE_RESTORE_DIR="$tmp/state/restore"
unset RICE_APPLY_ID

RP="$PLUGIN_ROOT/scripts/restore-point.sh"
BACKUP="$PLUGIN_ROOT/scripts/backup-path.sh"
FFBOOT="$PLUGIN_ROOT/skills/rice/assets/scripts/firefox-bootstrap.sh"

assert_file_exists "$RP"     "scripts/restore-point.sh present"
assert_file_exists "$PLUGIN_ROOT/scripts/rice-restore.sh" "scripts/rice-restore.sh present"

# Scaffold the engine into the sandboxed HOME.
bash "$PLUGIN_ROOT/skills/rice/scripts/rice-init.sh" >/dev/null 2>&1
assert_file_exists "$RICE_DIR/restore-point.sh" "rice-init installs the restore-point library into RICE_DIR"
assert_file_exists "$RICE_DIR/rice-restore.sh"  "rice-init installs the restore command into RICE_DIR"

# The user-facing single command, through the engine's own CLI (no plugin needed).
cliout="$(bash "$RICE_DIR/rice" restore --list 2>&1)"; clirc=$?
assert_eq "0" "$clirc" "AC2: 'rice restore --list' runs from the installed engine"
cliout="$(bash "$RICE_DIR/rice" restore no-such-apply 2>&1)"; clirc=$?
assert_eq "3" "$clirc" "AC8: 'rice restore <unknown>' reports nothing to restore, not success"

# --- AC1 / AC3: render over a directory of known-content files ------------------------------
# Three outputs exist with content no rice ever wrote; two do not exist at all.
mkdir -p "$HOME/.config/kitty" "$HOME/.config/waybar" "$HOME/.config/rofi" "$tmp/orig"
for pair in "kitty/colors.conf" "waybar/colors.css" "rofi/colors.rasi"; do
    printf 'hand-written %s, never produced by an apply\n' "$pair" > "$HOME/.config/$pair"
    mkdir -p "$tmp/orig/$(dirname "$pair")"
    cp -a "$HOME/.config/$pair" "$tmp/orig/$pair"
done

out="$(bash "$RICE_DIR/render-templates.sh" --no-reload 2>&1)"
apply_id="$(printf '%s\n' "$out" | sed -n 's/^RESTORE_POINT=\([^ ]*\).*/\1/p' | head -n1)"
if [ -n "$apply_id" ]; then
    pass "AC2: the render offers the way back (RESTORE_POINT=$apply_id)"
else
    fail "AC2: the render offers the way back" "no RESTORE_POINT= line in: $out"
fi

point="$RICE_RESTORE_DIR/$apply_id"
assert_file_exists "$point/entries.tsv" "AC1: the apply left one restore point"

# Every pre-existing output was copied to a backup carrying THIS apply's id, and the copy holds
# what was there before (AC1 + AC3: "back it up and record what it replaced").
backed_up_ok=1
for pair in "kitty/colors.conf" "waybar/colors.css" "rofi/colors.rasi"; do
    b="$HOME/.config/${pair}.bak.${apply_id}"
    if [ ! -f "$b" ] || ! cmp -s "$b" "$tmp/orig/$pair"; then
        backed_up_ok=0
        detail="$b"
    fi
done
if [ "$backed_up_ok" -eq 1 ]; then
    pass "AC1/AC3: every pre-existing output was copied to <path>.bak.<apply-id> before the write"
else
    fail "AC1/AC3: every pre-existing output was copied to <path>.bak.<apply-id>" "missing or wrong: ${detail:-?}"
fi

# ...and the outputs really were overwritten (otherwise the backup proves nothing).
if grep -q 'cba6f7' "$HOME/.config/waybar/colors.css" 2>/dev/null; then
    pass "AC1: the render did overwrite the pre-existing output"
else
    fail "AC1: the render did overwrite the pre-existing output" "waybar/colors.css has no rendered accent"
fi

# One apply, one timestamp: every sidecar this apply wrote carries the same id.
ids="$(find "$HOME/.config" -name '*.bak.*' -type f | sed 's/.*\.bak\.//' | sort -u | tr '\n' ' ')"
assert_eq "$apply_id " "$ids" "AC1: every file written in one apply shares one timestamp"

# What it replaced is recorded, per path, with the kind of entry restoring needs.
if awk -F'\t' '$1=="file" && $2 ~ /kitty\/colors\.conf$/ && $3 ~ /\.bak\./ {found=1} END{exit !found}' "$point/entries.tsv"; then
    pass "AC3: the restore point records what each overwritten path replaced"
else
    fail "AC3: the restore point records what each overwritten path replaced" "$(cat "$point/entries.tsv")"
fi
if awk -F'\t' '$1=="new" && $2 ~ /wofi\/colors\.css$/ {found=1} END{exit !found}' "$point/entries.tsv"; then
    pass "AC7: a path the apply created is recorded as created (so a restore can remove it)"
else
    fail "AC7: a path the apply created is recorded as created" "$(cat "$point/entries.tsv")"
fi

# --- Boundary: the Hyprland config dir is never a covered surface ---------------------------
# The default manifest renders hyprland/colors.conf into it. It must be written exactly as
# before this item: no enrolment, no sidecar, no restore-point entry of any kind.
# Both assertions read the LEDGER, never that directory: the ledger records every path this
# mechanism enrols (column 2) and every backup copy it writes (column 3), so "absent from both
# columns" is the whole proof, and no test here has to go looking inside it.
excluded_dir="$HOME/.config/hypr/"                                                   # RP_EXCLUDE
if awk -F'\t' -v h="$excluded_dir" 'index($2, h) == 1 {found=1} END{exit !found}' "$point/entries.tsv"; then
    fail "boundary: the Hyprland config dir is never enrolled" "$(cat "$point/entries.tsv")"
else
    pass "boundary: no path in the Hyprland config dir is enrolled in the restore point"
fi
if awk -F'\t' -v h="$excluded_dir" 'index($3, h) == 1 {found=1} END{exit !found}' "$point/entries.tsv"; then
    fail "boundary: no backup sidecar is written into the Hyprland config dir" "$(cat "$point/entries.tsv")"
else
    pass "boundary: this mechanism wrote no backup sidecar into the Hyprland config dir"
fi
if printf '%s\n' "$out" | grep -q '^RENDERED hyprland '; then
    pass "boundary: the excluded surface still renders exactly as before, just unenrolled"
else
    fail "boundary: the excluded surface still renders" "$out"
fi

# --- AC5: the browser theming step joins the SAME apply -------------------------------------
export RICE_APPLY_ID="apply-two"
mkdir -p "$tmp/bin"
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/firefox"
chmod +x "$tmp/bin/firefox"
PATH="$tmp/bin:$PATH"; export PATH

profile="$HOME/.mozilla/firefox/abcd1234.default-release"
mkdir -p "$profile/chrome" "$HOME/.mozilla/firefox"
printf '[Profile0]\nName=default-release\nIsRelative=1\nPath=abcd1234.default-release\nDefault=1\n' \
    > "$HOME/.mozilla/firefox/profiles.ini"
printf '/* the user wrote this themselves */\n' > "$profile/chrome/userChrome.css"
cp -a "$profile/chrome/userChrome.css" "$tmp/orig-userChrome.css"

export FIREFOX_ASSETS_DIR="$tmp/ffassets"
mkdir -p "$FIREFOX_ASSETS_DIR"
printf '/* shipped userChrome */\n' > "$FIREFOX_ASSETS_DIR/userChrome.css"
printf 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n' > "$FIREFOX_ASSETS_DIR/user.js"

# Stage 1 of the same apply: the render pass, under the same exported id.
bash "$RICE_DIR/render-templates.sh" --no-reload >/dev/null 2>&1
# Stage 2: the browser theming step.
ffout="$(bash "$FFBOOT" 2>&1)"
point2="$RICE_RESTORE_DIR/apply-two"

if [ -f "$profile/chrome/userChrome.css.bak.apply-two" ] && \
   cmp -s "$profile/chrome/userChrome.css.bak.apply-two" "$tmp/orig-userChrome.css"; then
    pass "AC5: the Firefox profile file is backed up before the browser step overwrites it"
else
    fail "AC5: the Firefox profile file is backed up before the browser step overwrites it" "$ffout"
fi
if awk -F'\t' '$2 ~ /chrome\/userChrome\.css$/ {c++} $2 ~ /\/user\.js$/ {j++} END{exit !(c && j)}' "$point2/entries.tsv" 2>/dev/null; then
    pass "AC5: both Firefox profile files are enrolled in the apply's restore point"
else
    fail "AC5: both Firefox profile files are enrolled in the apply's restore point" "$(cat "$point2/entries.tsv" 2>/dev/null)"
fi
# Same apply id as the render surfaces => restoring that apply restores the profile file with
# everything else it touched.
if awk -F'\t' '$2 ~ /waybar\/colors\.css$/ {found=1} END{exit !found}' "$point2/entries.tsv" 2>/dev/null; then
    pass "AC5: the profile file shares one restore point with the render pass of the same apply"
else
    fail "AC5: the profile file shares one restore point with the render pass" "$(cat "$point2/entries.tsv" 2>/dev/null)"
fi
# The ad-hoc epoch-stamped backup the browser step used to write is gone: one shape, one id.
odd="$(find "$profile/chrome" -name 'userChrome.css.bak.*' ! -name '*.bak.apply-two' | head -n1)"
if [ -z "$odd" ]; then
    pass "AC5: no second backup shape beside the apply's own"
else
    fail "AC5: no second backup shape beside the apply's own" "$odd"
fi

# --- AC6: a shell rc edit inside an apply shares its id -------------------------------------
printf 'export PATH="$HOME/bin:$PATH"\n' > "$HOME/.bashrc"
cp -a "$HOME/.bashrc" "$tmp/orig-bashrc"
bout="$(bash "$BACKUP" "$HOME/.bashrc" 2>&1)"
printf '\n# >>> hyprland-config managed >>>\neval "$(starship init bash)"\n' >> "$HOME/.bashrc"
if [ -f "$HOME/.bashrc.bak.apply-two" ] && cmp -s "$HOME/.bashrc.bak.apply-two" "$tmp/orig-bashrc"; then
    pass "AC6: a shell rc edit made during an apply is backed up under that apply's id"
else
    fail "AC6: a shell rc edit made during an apply is backed up under that apply's id" "$bout"
fi
if awk -F'\t' '$2 ~ /\.bashrc$/ {found=1} END{exit !found}' "$point2/entries.tsv"; then
    pass "AC6: the shell rc file joins the apply's single restore point"
else
    fail "AC6: the shell rc file joins the apply's single restore point" "$(cat "$point2/entries.tsv")"
fi

# --- AC6: a standalone shell rc edit gets its own restore point -----------------------------
unset RICE_APPLY_ID
printf 'setopt AUTO_CD\n' > "$HOME/.zshrc"
cp -a "$HOME/.zshrc" "$tmp/orig-zshrc"
zout="$(bash "$BACKUP" "$HOME/.zshrc" 2>&1)"
own_id="$(printf '%s\n' "$zout" | sed -n 's/^RESTORE_POINT=//p' | head -n1)"
printf 'alias ll="ls -al"\n' >> "$HOME/.zshrc"
if [ -n "$own_id" ] && [ "$own_id" != "apply-two" ] && [ -s "$RICE_RESTORE_DIR/$own_id/entries.tsv" ]; then
    pass "AC6: a standalone shell rc edit gets its own restore point ($own_id)"
else
    fail "AC6: a standalone shell rc edit gets its own restore point" "$zout"
fi
rout="$(bash "$PLUGIN_ROOT/scripts/rice-restore.sh" "$own_id" 2>&1)"; rrc=$?
assert_eq "0" "$rrc" "AC6: the standalone restore point restores on its own"
if cmp -s "$HOME/.zshrc" "$tmp/orig-zshrc"; then
    pass "AC6: the standalone restore put the rc file back byte-for-byte"
else
    fail "AC6: the standalone restore put the rc file back byte-for-byte" "$rout"
fi
# ...and it did not touch the theming apply's point.
if [ -s "$point2/entries.tsv" ]; then
    pass "AC6: restoring the standalone edit left the theming apply's restore point alone"
else
    fail "AC6: restoring the standalone edit left the theming apply's restore point alone" "point2 is gone"
fi

# --- AC10: a backup that cannot be written means the surface is not rendered ----------------
# A hand-built manifest so the failure is scoped to one surface and the rest of the manifest is
# observable.
mkdir -p "$tmp/tpl" "$HOME/.config/appa" "$HOME/.config/appb"
printf 'accent={{accent}}\n' > "$tmp/tpl/a.tmpl"
printf 'accent={{accent}}\n' > "$tmp/tpl/b.tmpl"
printf 'accent={{accent}}\n' > "$tmp/tpl/c.tmpl"
printf 'accent=ff0000\n' > "$tmp/pal.conf"
{
    printf 'appa\t%s/tpl/a.tmpl\t%s/.config/appa/colors.conf\t\n' "$tmp" "$HOME"
    printf 'appb\t%s/tpl/b.tmpl\t%s/.config/appb/colors.conf\t\n' "$tmp" "$HOME"
    printf 'appc\t%s/tpl/c.tmpl\t%s/.config/appc/new.conf\t\n' "$tmp" "$HOME"
} > "$tmp/manifest.list"

printf 'PRECIOUS A\n' > "$HOME/.config/appa/colors.conf"
printf 'PRECIOUS B\n' > "$HOME/.config/appb/colors.conf"

export RICE_APPLY_ID="apply-ro"
chmod 500 "$HOME/.config/appa"       # the sidecar backup cannot be created here
if [ "$(id -u)" -eq 0 ]; then
    skip "AC10: unwritable backup destination" "running as root ignores the permission bits"
else
    roout="$(bash "$RICE_DIR/render-templates.sh" --no-reload "$tmp/pal.conf" "$tmp/manifest.list" 2>&1)"
    chmod 700 "$HOME/.config/appa"
    if printf '%s\n' "$roout" | grep -q '^RENDER_SKIPPED appa'; then
        pass "AC10: the surface whose backup failed is reported as skipped, with the reason"
    else
        fail "AC10: the surface whose backup failed is reported as skipped" "$roout"
    fi
    assert_eq "PRECIOUS A" "$(cat "$HOME/.config/appa/colors.conf")" "AC10: the un-backed-up output was NOT overwritten"
    assert_eq "accent=ff0000" "$(cat "$HOME/.config/appb/colors.conf")" "AC10: the rest of the manifest still rendered"
    assert_file_exists "$HOME/.config/appc/new.conf" "AC10: the rest of the manifest still rendered (new surface)"
fi

# --- AC10 + F6: a brand-new output whose restore-point entry cannot be written --------------
# Nothing is being overwritten here, so the narrow reading of AC10 would render it anyway and
# leave a file no restore could ever remove. The bookkeeping IS the backup for such a path, so
# the surface is skipped exactly like any other AC10 case.
rm -rf "$HOME/.config/appc"
export RICE_APPLY_ID="apply-nobook"
mkdir -p "$RICE_RESTORE_DIR/apply-nobook"
chmod 500 "$RICE_RESTORE_DIR/apply-nobook"
if [ "$(id -u)" -eq 0 ]; then
    skip "AC10/F6: unwritable restore point for a brand-new output" "running as root ignores the permission bits"
else
    nbout="$(bash "$RICE_DIR/render-templates.sh" --no-reload "$tmp/pal.conf" "$tmp/manifest.list" 2>&1)"
    chmod 700 "$RICE_RESTORE_DIR/apply-nobook"
    if printf '%s\n' "$nbout" | grep -q '^RENDER_SKIPPED appc'; then
        pass "AC10/F6: a new output whose restore-point entry cannot be written is skipped and reported"
    else
        fail "AC10/F6: a new output whose restore-point entry cannot be written is skipped" "$nbout"
    fi
    if [ ! -e "$HOME/.config/appc/new.conf" ]; then
        pass "AC10/F6: no untrackable file is left on disk when its restore-point entry failed"
    else
        fail "AC10/F6: no untrackable file is left on disk when its restore-point entry failed" "appc/new.conf exists"
    fi
    assert_eq "PRECIOUS A" "$(cat "$HOME/.config/appa/colors.conf")" "AC10/F6: existing outputs were left alone too"
fi
unset RICE_APPLY_ID

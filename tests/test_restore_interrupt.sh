#!/usr/bin/env bash
# An apply killed partway through leaves a usable restore point (AC4). Four interruption points,
# all four of the shapes the criterion names:
#   A. during the first stage      - killed mid-manifest, inside the render pass itself
#   B. between stages              - the render pass completed, the next stage never started
#   C. during a later stage        - killed mid-browser-theming, after the render pass completed
#   D. during the last stage       - killed mid-shell-rc edit, after render + browser completed
# In every case the restore point must cover every surface already written by EVERY stage
# completed so far, not only the stage that was in progress.

tmp="$(mktemp_test_dir restore-interrupt)"
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

# XDG_CONFIG_HOME goes with HOME: a `~/.config/...` path now resolves under the config base,
# so an inherited value would send this test's writes outside its sandbox.
unset XDG_CONFIG_HOME
export HOME="$tmp"
export RICE_DIR="$HOME/.config/hypr-rice"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
export RICE_RESTORE_DIR="$tmp/state/restore"
unset RICE_APPLY_ID

RESTORE="$PLUGIN_ROOT/scripts/rice-restore.sh"
BACKUP="$PLUGIN_ROOT/scripts/backup-path.sh"
FFBOOT="$PLUGIN_ROOT/skills/rice/assets/scripts/firefox-bootstrap.sh"
bash "$PLUGIN_ROOT/skills/rice/scripts/rice-init.sh" >/dev/null 2>&1

mkdir -p "$tmp/tpl" "$tmp/orig" "$HOME/.config/app1" "$HOME/.config/app2" "$HOME/.config/app3"
printf 'accent={{accent}}\n' > "$tmp/tpl/x.tmpl"
printf 'accent=ff0000\n'     > "$tmp/pal.conf"

seed_surfaces() {
    local n
    for n in 1 2 3; do
        printf 'ORIGINAL app%s content\n' "$n" > "$HOME/.config/app$n/colors.conf"
        cp -a "$HOME/.config/app$n/colors.conf" "$tmp/orig/app$n"
    done
}

# --- A. killed mid-manifest, inside the render pass -----------------------------------------
# app2's reload hook kills the engine, so app3 is never reached: an apply that dies with two of
# three surfaces already overwritten.
seed_surfaces
{
    printf 'app1\t%s/tpl/x.tmpl\t%s/.config/app1/colors.conf\t:\n' "$tmp" "$HOME"
    printf 'app2\t%s/tpl/x.tmpl\t%s/.config/app2/colors.conf\tkill -9 $$\n' "$tmp" "$HOME"
    printf 'app3\t%s/tpl/x.tmpl\t%s/.config/app3/colors.conf\t:\n' "$tmp" "$HOME"
} > "$tmp/kill.list"

RICE_APPLY_ID="apply-killed" bash "$RICE_DIR/render-templates.sh" "$tmp/pal.conf" "$tmp/kill.list" >/dev/null 2>&1
krc=$?
if [ "$krc" -ge 128 ]; then
    pass "AC4: the render pass really was killed mid-manifest (signal, rc $krc)"
else
    fail "AC4: the render pass really was killed mid-manifest" "rc $krc"
fi
assert_eq "accent=ff0000" "$(cat "$HOME/.config/app1/colors.conf")" "AC4: the surfaces before the kill were written"
assert_eq "ORIGINAL app3 content" "$(cat "$HOME/.config/app3/colors.conf")" "AC4: the surface after the kill was not reached"

# The point exists even though the killed apply never got to announce it, and it is listed.
if bash "$RESTORE" --list | grep -q '^apply-killed'; then
    pass "AC4: the interrupted apply's restore point is on disk and discoverable (rice restore --list)"
else
    fail "AC4: the interrupted apply's restore point is discoverable" "$(bash "$RESTORE" --list)"
fi

kout="$(bash "$RESTORE" apply-killed 2>&1)"; krc=$?
assert_eq "0" "$krc" "AC4: the partial restore point restores cleanly"
if cmp -s "$HOME/.config/app1/colors.conf" "$tmp/orig/app1" && \
   cmp -s "$HOME/.config/app2/colors.conf" "$tmp/orig/app2"; then
    pass "AC4: every surface already written before the interruption is back to its prior state"
else
    fail "AC4: every surface already written before the interruption is back" "$kout"
fi

# --- B. killed between stages ---------------------------------------------------------------
seed_surfaces
{
    printf 'app1\t%s/tpl/x.tmpl\t%s/.config/app1/colors.conf\t\n' "$tmp" "$HOME"
    printf 'app2\t%s/tpl/x.tmpl\t%s/.config/app2/colors.conf\t\n' "$tmp" "$HOME"
    printf 'app3\t%s/tpl/x.tmpl\t%s/.config/app3/colors.conf\t\n' "$tmp" "$HOME"
} > "$tmp/manifest.list"
export RICE_APPLY_ID="apply-between"
bash "$RICE_DIR/render-templates.sh" --no-reload "$tmp/pal.conf" "$tmp/manifest.list" >/dev/null 2>&1
printf '#!/usr/bin/env bash\nkill -9 $$\n' > "$tmp/next-stage.sh"
bash "$tmp/next-stage.sh" >/dev/null 2>&1
bout="$(bash "$RESTORE" apply-between 2>&1)"; brc=$?
assert_eq "0" "$brc" "AC4: an apply that died between stages still restores"
ok=1
for n in 1 2 3; do cmp -s "$HOME/.config/app$n/colors.conf" "$tmp/orig/app$n" || ok=0; done
if [ "$ok" -eq 1 ]; then
    pass "AC4: every surface from the completed stage is back to its prior state"
else
    fail "AC4: every surface from the completed stage is back to its prior state" "$bout"
fi

# --- C. killed mid-browser-theming, after the render pass completed -------------------------
mkdir -p "$tmp/bin"
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/firefox"
chmod +x "$tmp/bin/firefox"
PATH="$tmp/bin:$PATH"; export PATH
profile="$HOME/.mozilla/firefox/abcd1234.default-release"
mkdir -p "$profile/chrome"
printf '[Profile0]\nName=default-release\nIsRelative=1\nPath=abcd1234.default-release\nDefault=1\n' \
    > "$HOME/.mozilla/firefox/profiles.ini"
export FIREFOX_ASSETS_DIR="$tmp/ffassets"
mkdir -p "$FIREFOX_ASSETS_DIR"
printf '/* shipped userChrome */\n' > "$FIREFOX_ASSETS_DIR/userChrome.css"

seed_surfaces
printf '/* the user wrote this themselves */\n' > "$profile/chrome/userChrome.css"
cp -a "$profile/chrome/userChrome.css" "$tmp/orig-userChrome.css"
rm -f "$profile/user.js"

export RICE_APPLY_ID="apply-midbrowser"
bash "$RICE_DIR/render-templates.sh" --no-reload "$tmp/pal.conf" "$tmp/manifest.list" >/dev/null 2>&1   # stage 1 completes

# A profile whose user.js merge has thousands of prefs to walk takes seconds, so the step can be
# killed while it is mid-stage: one profile file already rewritten, the second only part-written.
prefs=5000
awk -v n="$prefs" 'BEGIN { for (i = 1; i <= n; i++) printf "user_pref(\"rice.test.%d\", true);\n", i }' \
    > "$FIREFOX_ASSETS_DIR/user.js"
bash "$FFBOOT" >/dev/null 2>&1 &
ffpid=$!
reached=0
for _ in $(seq 1 200); do
    if [ -e "$profile/user.js" ]; then reached=1; break; fi
    sleep 0.05
done
kill -9 "$ffpid" 2>/dev/null
wait "$ffpid" 2>/dev/null
written="$(wc -l < "$profile/user.js" 2>/dev/null | tr -d ' ')"
if [ "$reached" -eq 1 ] && [ "${written:-0}" -lt "$prefs" ]; then
    pass "AC4: the browser theming step was killed with the stage half done ($written/$prefs prefs merged)"
else
    fail "AC4: the browser theming step was killed with the stage half done" "reached=$reached written=${written:-none}/$prefs"
fi
point="$RICE_RESTORE_DIR/apply-midbrowser"
if awk -F'\t' '$2 ~ /app1\/colors\.conf$/ {r=1} $2 ~ /userChrome\.css$/ {b=1} END{exit !(r && b)}' "$point/entries.tsv"; then
    pass "AC4: the point covers the completed render stage AND the interrupted browser stage"
else
    fail "AC4: the point covers both stages" "$(cat "$point/entries.tsv")"
fi
cout="$(bash "$RESTORE" apply-midbrowser 2>&1)"; crc=$?
assert_eq "0" "$crc" "AC4: the mid-browser restore point restores cleanly"
ok=1
for n in 1 2 3; do cmp -s "$HOME/.config/app$n/colors.conf" "$tmp/orig/app$n" || ok=0; done
if [ "$ok" -eq 1 ]; then
    pass "AC4: the earlier stage's surfaces are restored, not only the stage in progress"
else
    fail "AC4: the earlier stage's surfaces are restored" "$cout"
fi
if cmp -s "$profile/chrome/userChrome.css" "$tmp/orig-userChrome.css"; then
    pass "AC4: the profile file the interrupted stage had already rewritten is back"
else
    fail "AC4: the profile file the interrupted stage had already rewritten is back" "$cout"
fi
if [ ! -e "$profile/user.js" ]; then
    pass "AC4/AC7: the profile file that stage created before dying is removed"
else
    fail "AC4/AC7: the profile file that stage created before dying is removed" "$cout"
fi

# --- D. killed mid-shell-rc edit, after render and browser stages completed -----------------
seed_surfaces
printf 'export PATH="$HOME/bin:$PATH"\n' > "$HOME/.bashrc"
cp -a "$HOME/.bashrc" "$tmp/orig-bashrc"
printf '/* the user wrote this themselves */\n' > "$profile/chrome/userChrome.css"
printf 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n' > "$FIREFOX_ASSETS_DIR/user.js"
rm -f "$profile/user.js"

export RICE_APPLY_ID="apply-midrc"
bash "$RICE_DIR/render-templates.sh" --no-reload "$tmp/pal.conf" "$tmp/manifest.list" >/dev/null 2>&1  # stage 1
bash "$FFBOOT" >/dev/null 2>&1                                                                         # stage 2

cat > "$tmp/stage3.sh" <<'STAGE3'
#!/usr/bin/env bash
# The config-editing flow: back the rc file up, start writing the managed block, die partway.
bash "$BACKUP_SH" "$HOME/.bashrc" >/dev/null 2>&1
printf '\n# >>> hyprland-config managed >>>\neval "$(starship' >> "$HOME/.bashrc"
kill -9 $$
printf 'init bash)"\n# <<< hyprland-config managed <<<\n' >> "$HOME/.bashrc"
STAGE3
BACKUP_SH="$BACKUP" bash "$tmp/stage3.sh" >/dev/null 2>&1
if ! cmp -s "$HOME/.bashrc" "$tmp/orig-bashrc"; then
    pass "AC4: the shell-rc stage died with a half-written edit on disk"
else
    fail "AC4: the shell-rc stage died with a half-written edit on disk" "the rc file is unchanged"
fi
point="$RICE_RESTORE_DIR/apply-midrc"
if awk -F'\t' '$2 ~ /app1\/colors\.conf$/ {r=1} $2 ~ /userChrome\.css$/ {b=1} $2 ~ /\.bashrc$/ {s=1} END{exit !(r && b && s)}' "$point/entries.tsv"; then
    pass "AC4: one point covers all three stages of the apply that died in the last one"
else
    fail "AC4: one point covers all three stages" "$(cat "$point/entries.tsv")"
fi
dout="$(bash "$RESTORE" apply-midrc 2>&1)"; drc=$?
assert_eq "0" "$drc" "AC4: the mid-shell-rc restore point restores cleanly"
ok=1
for n in 1 2 3; do cmp -s "$HOME/.config/app$n/colors.conf" "$tmp/orig/app$n" || ok=0; done
if [ "$ok" -eq 1 ] && cmp -s "$profile/chrome/userChrome.css" "$tmp/orig-userChrome.css"; then
    pass "AC4: both completed stages are restored, not only the stage that was in progress"
else
    fail "AC4: both completed stages are restored" "$dout"
fi
if cmp -s "$HOME/.bashrc" "$tmp/orig-bashrc"; then
    pass "AC4: the half-written shell rc file is back to its prior state byte-for-byte"
else
    fail "AC4: the half-written shell rc file is back to its prior state" "$dout"
fi
unset RICE_APPLY_ID

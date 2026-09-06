#!/usr/bin/env bash
# Impl-gate ordinal 2, independent probe of the five inherited roadmap assertions.
#
# Report-only artifact: written by the refuter, NOT part of `bash tests/run.sh` (that harness
# discovers tests/test_*.sh only). It exists so the pass on the five phase assertions rests on
# commands a reader can re-run, with stubs built here rather than borrowed from the implementer's
# own test files.
#
#   A1  a package install writes a record naming installed / already present / failed, and leaves
#       it on the machine
#   A2  an AUR helper built from source is named, with its URL, and confirmed BEFORE any build
#   A3  a userChrome.css this plugin wrote before is backed up before it is replaced
#   A4  the preferences merged into user.js are recorded and have a documented removal path
#   A5  no pacman means the list is printed and nothing is installed
#
# Exit 0 when all five hold, 1 when any fails, 2 when the tree is not the one under review or the
# host actually has pacman (A5 is unprobeable there).
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IR="$REPO/scripts/install-record.sh"
IP="$REPO/scripts/install-packages.sh"
FP="$REPO/scripts/firefox-prefs.sh"
FFBOOT="$REPO/skills/rice/assets/scripts/firefox-bootstrap.sh"
BROWSER="$REPO/skills/rice/references/components/browser"
for f in "$IR" "$IP" "$FP" "$FFBOOT"; do
    [ -f "$f" ] || { echo "INCONCLUSIVE: $f is not in this tree"; exit 2; }
done
command -v pacman >/dev/null 2>&1 && { echo "INCONCLUSIVE: this host has pacman"; exit 2; }

rc=0
ok()   { printf 'PASS  %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; rc=1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/regress0037g2.XXXXXX")"
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT
BIN="/usr/bin:/bin"
unset XDG_CONFIG_HOME XDG_STATE_HOME RICE_DIR RICE_APPLY_ID RICE_INSTALL_RECORD_DIR RICE_PREF_RECORD
export CLAUDE_PLUGIN_ROOT="$REPO"

# ---- my own Arch stubs, written here -------------------------------------------------------
stubs="$tmp/stubs"; mkdir -p "$stubs"
: > "$stubs/.log"; : > "$stubs/.have"
printf 'waybar\nkitty\n' > "$stubs/.repo"
printf 'kitty\n' > "$stubs/.have"
cat > "$stubs/pacman" <<'S'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"; printf 'pacman %s\n' "$*" >> "$d/.log"
case "${1:-}" in
  -Qq) grep -Fxq -- "${2:-}" "$d/.have" && exit 0; exit 1 ;;
  -Si) grep -Fxq -- "${2:-}" "$d/.repo" && exit 0; exit 1 ;;
  -S)  for a in "$@"; do case "$a" in -*) continue;; esac
         if [ "$a" = "ghost-pkg" ]; then echo "error: target not found: $a"; else
           grep -Fxq -- "$a" "$d/.have" || printf '%s\n' "$a" >> "$d/.have"; fi
       done; exit 0 ;;
esac
exit 0
S
cat > "$stubs/sudo" <<'S'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"; printf 'sudo %s\n' "$*" >> "$d/.log"; exec "$@"
S
cat > "$stubs/git" <<'S'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"; printf 'git %s\n' "$*" >> "$d/.log"
[ "${1:-}" = clone ] && mkdir -p "${3:-}"; exit 0
S
cat > "$stubs/makepkg" <<'S'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")" && pwd)"; printf 'makepkg %s\n' "$*" >> "$d/.log"; exit 0
S
chmod +x "$stubs/pacman" "$stubs/sudo" "$stubs/git" "$stubs/makepkg"

# ============================================================================================
# A1 - the record
# ============================================================================================
export HOME="$tmp/h1"; mkdir -p "$HOME"
out="$(PATH="$stubs:$BIN" bash "$IP" --route install.sh --noconfirm --assume-no waybar kitty ghost-pkg 2>&1)"
recp="$(printf '%s\n' "$out" | sed -n 's/^INSTALL_RECORD=//p' | head -n1)"
if [ -n "$recp" ] && [ -f "$recp" ]; then ok "A1 the install left a record at $recp"
else bad "A1 no record file was left"; printf '%s\n' "$out"; fi
body="$(grep -v '^#' "$recp" 2>/dev/null)"
printf '%s\n' "$body" | grep -q "^installed\swaybar" && ok "A1 waybar recorded as installed" || bad "A1 waybar not recorded as installed"
printf '%s\n' "$body" | grep -q "^present\skitty"    && ok "A1 kitty recorded as already present" || bad "A1 kitty not recorded as present"
printf '%s\n' "$body" | grep -q "^failed\sghost-pkg" && ok "A1 ghost-pkg recorded as failed" || bad "A1 ghost-pkg not recorded as failed"
printf '%s\n' "$body" | grep -q "^failed\sghost-pkg\s[^ ]*\s.\+" && ok "A1 the failure carries a reason" || bad "A1 the failure carries no reason"
case "$recp" in "$HOME/.local/state/hypr-rice/installs/"*) ok "A1 the record is under the state root" ;;
                *) bad "A1 the record is not under the state root: $recp" ;; esac
# it survives the process that wrote it
lst="$(PATH="$BIN" bash "$IR" list 2>&1)"
printf '%s\n' "$lst" | grep -q "$(basename "$recp" .tsv)" && ok "A1 the record is listed back later" || bad "A1 the record is not listed back"

# ============================================================================================
# A2 - the AUR build disclosure and its confirmation
# ============================================================================================
export HOME="$tmp/h2"; mkdir -p "$HOME"
: > "$stubs/.log"; printf 'kitty\n' > "$stubs/.have"
out="$(printf 'n\n' | PATH="$stubs:$BIN" bash "$IP" --route install.sh --noconfirm some-aur-pkg 2>&1)"; arc=$?
printf '%s\n' "$out" | grep -q 'AUR_BUILD_PACKAGE=paru' && ok "A2 the disclosure names the package it would build" || bad "A2 the disclosure does not name the package"
printf '%s\n' "$out" | grep -q 'AUR_BUILD_URL=https://aur.archlinux.org/paru.git' && ok "A2 the disclosure shows the clone URL" || bad "A2 the disclosure shows no URL"
printf '%s\n' "$out" | grep -qi 'BUILT FROM SOURCE on this machine' && ok "A2 it says it would be built from source here" || bad "A2 it does not say it is a source build"
printf '%s\n' "$out" | grep -q 'Nothing has been cloned, built or installed from the AUR yet' && ok "A2 the disclosure precedes any clone" || bad "A2 no before-the-clone statement"
grep -q '^git clone' "$stubs/.log" && bad "A2 a decline still cloned" || ok "A2 a decline cloned nothing"
grep -q '^makepkg' "$stubs/.log" && bad "A2 a decline still built" || ok "A2 a decline built nothing"
printf '%s\n' "$out" | grep -q 'AUR_BOOTSTRAP=declined' && ok "A2 a decline is reported as a decline" || bad "A2 a decline is not reported distinctly"
[ "$arc" = "4" ] && ok "A2 a decline has its own exit status (4), not a failure's" || bad "A2 decline exit status was $arc"
# an unanswered prompt is a decline, never an assumed yes
: > "$stubs/.log"
out="$(PATH="$stubs:$BIN" bash "$IP" --route install.sh --noconfirm some-aur-pkg </dev/null 2>&1)"; arc=$?
grep -qE '^(git clone|makepkg)' "$stubs/.log" && bad "A2 an unanswered prompt built anyway" || ok "A2 an unanswered prompt builds nothing"
[ "$arc" = "4" ] && ok "A2 an unanswered prompt is a decline" || bad "A2 an unanswered prompt exit was $arc"

# ============================================================================================
# A5 - no pacman (this host has none; no stub dir is on PATH here)
# ============================================================================================
export HOME="$tmp/h5"; mkdir -p "$HOME"
out="$(PATH="$BIN" bash "$IP" --route install.sh waybar wofi mako 2>&1)"; nrc=$?
printf '%s\n' "$out" | grep -q 'PACKAGES=waybar wofi mako' && ok "A5 the package list is printed" || bad "A5 the list was not printed"
printf '%s\n' "$out" | grep -q 'PACMAN=absent' && ok "A5 the missing pacman is named" || bad "A5 pacman absence not reported"
printf '%s\n' "$out" | grep -q 'INSTALL=skipped (non-arch)' && ok "A5 the outcome reads as skipped, not failed" || bad "A5 the outcome is not 'skipped (non-arch)'"
[ "$nrc" = "0" ] && ok "A5 a non-Arch host is not an error exit" || bad "A5 exit was $nrc"
if [ -n "$(find "$HOME/.local/state" -name '*.tsv' 2>/dev/null)" ]; then
    bad "A5 a record was written although nothing was installed"
else ok "A5 nothing was installed and no record invents one"; fi

# ============================================================================================
# A3 / A4 - the browser profile: backup before replacement, and the recorded prefs' removal path
# ============================================================================================
export HOME="$tmp/h3"; mkdir -p "$HOME"
export RICE_DIR="$HOME/.config/hypr-rice"
export RICE_RESTORE_DIR="$tmp/h3state/restore"
export FIREFOX_ASSETS_DIR="$BROWSER"
ffstub="$tmp/ffstub"; mkdir -p "$ffstub"
printf '#!/usr/bin/env bash\nexit 0\n' > "$ffstub/firefox"; chmod +x "$ffstub/firefox"
prof="$HOME/.mozilla/firefox/p1.default-release"; mkdir -p "$prof/chrome"
printf '[Profile0]\nName=default\nIsRelative=1\nPath=p1.default-release\nDefault=1\n' \
    > "$HOME/.mozilla/firefox/profiles.ini"
# a userChrome.css THIS PLUGIN wrote before (it names its own rendered colors file)
printf '@import "rice-colors.css";\n/* and a tweak I added later */\n' > "$prof/chrome/userChrome.css"
printf 'user_pref("privacy.donottrackheader.enabled", true);\n' > "$prof/user.js"
cp "$prof/chrome/userChrome.css" "$tmp/uc.before"
cp "$prof/user.js" "$tmp/uj.before"

out="$(PATH="$ffstub:$BIN" bash "$FFBOOT" 2>&1)"
aid="$(printf '%s\n' "$out" | sed -n 's/^RESTORE_POINT=//p' | head -n1)"
if [ -n "$aid" ] && [ -f "$prof/chrome/userChrome.css.bak.$aid" ] && \
   cmp -s "$prof/chrome/userChrome.css.bak.$aid" "$tmp/uc.before"; then
    ok "A3 the previously-written userChrome.css was backed up before it was replaced"
else
    bad "A3 no restorable backup of the previously-written userChrome.css"
fi
if [ -f "$prof/user.js.bak.$aid" ] && cmp -s "$prof/user.js.bak.$aid" "$tmp/uj.before"; then
    ok "A3 user.js was backed up before the preference merge"
else bad "A3 no restorable backup of user.js"; fi

prefrec="$HOME/.local/state/hypr-rice/browser-prefs.tsv"
if [ -s "$prefrec" ]; then ok "A4 the merged preferences were recorded"; else bad "A4 nothing was recorded"; fi
grep -q "toolkit.legacyUserProfileCustomizations.stylesheets" "$prefrec" \
    && ok "A4 the theming preference is in the record" || bad "A4 the theming preference is not recorded"
grep -q "privacy.donottrackheader.enabled" "$prefrec" \
    && bad "A4 a preference the plugin did not set was recorded" \
    || ok "A4 a preference already in the file is not recorded"
cp "$prof/user.js" "$tmp/uj.merged"
out="$(PATH="$BIN" bash "$FP" remove 2>&1)"; prc=$?
[ "$prc" = "0" ] && ok "A4 the documented removal path runs" || bad "A4 removal exit was $prc"
grep -q "toolkit.legacyUserProfileCustomizations.stylesheets" "$prof/user.js" \
    && bad "A4 the theming preference is still in user.js after removal" \
    || ok "A4 the theming preference is gone, so Firefox stops re-applying it"
printf 'user_pref("privacy.donottrackheader.enabled", true);\n' > "$tmp/uj.expected"
cmp -s "$prof/user.js" "$tmp/uj.expected" \
    && ok "A4 every other line of user.js is byte-identical" \
    || { bad "A4 user.js was not left byte-identical"; diff "$tmp/uj.expected" "$prof/user.js"; }
rid="$(printf '%s\n' "$out" | sed -n 's/^RESTORE_POINT=//p' | head -n1)"
if [ -n "$rid" ] && [ -f "$prof/user.js.bak.$rid" ] && cmp -s "$prof/user.js.bak.$rid" "$tmp/uj.merged"; then
    ok "A4 the removal backed the file up before editing it"
else bad "A4 the removal took no restorable backup"; fi
# documented removal path, in the documents
grep -q 'rice prefs remove' "$BROWSER/template.md" && ok "A4 the component doc names the removal command" || bad "A4 the component doc does not"
grep -q 'rice prefs remove' "$REPO/README.md" && ok "A4 the README names the removal command" || bad "A4 the README does not"

echo
[ "$rc" -eq 0 ] && echo "ALL FIVE ASSERTIONS HOLD" || echo "AT LEAST ONE ASSERTION FAILED"
exit "$rc"

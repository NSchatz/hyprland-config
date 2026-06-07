#!/usr/bin/env bash
# Regression tests for the semantic lints the validator agent now blocks. These mirror the
# defect classes the hyprland-config 0.19 release closed:
#   - defect #3:  no `rgb($var)` / `rgba($var)` / `#$var` double-wrap in shipped templates
#   - defect #4:  the rofi recipe declares the global `*` block + the full 9-state matrix
#   - defect #8:  no literal `swww-daemon` outside the binary registry
#   - defects #11/#14: `_shared/namespaces.md` covers every namespace any template matches
#   - defects #12/#17: `_shared/expected-binds.md` declares every cross-component bind
#
# We don't drive the validator agent itself here (it's an LLM tool) — we lint the *templates*
# the validator agent ships to enforce. Catching the regression in the templates is the
# point.

rice_refs="$PLUGIN_ROOT/skills/rice/references"
rice_assets="$PLUGIN_ROOT/skills/rice/assets"
shared="$rice_refs/_shared"

# --- defect #3 — no rgb($var) double-wrap in look-feel recipe ---
# The look-feel template documents the recipe writers use; if `background_color = rgb($bg)` is
# back, the looknfeel.conf shipped to disk will fail Hyprland's "invalid color" parser. Only
# the gotcha/docs are allowed to mention the antipattern (in quoted code blocks); the recipe
# body must NOT emit it.
looknfeel="$rice_refs/components/look-feel/template.md"
if grep -nE '^\s*[a-zA-Z_.]+\s*=\s*rgba?\(\$[a-zA-Z_]+\s*\)' "$looknfeel" >/dev/null; then
    fail "defect #3: look-feel template emits rgb(\$var) — double-wrap reintroduced"
else
    pass "defect #3: look-feel template has no rgb(\$var) emissions"
fi

# --- defect #4 — rofi theme has the required global `*` + full element-state matrix ---
launcher="$rice_refs/components/launcher/template.md"
required=(
    '^\* \{'
    'mainbox'
    'listview'
    'element-text'
    'element-icon'
    'element normal\.normal'
    'element normal\.urgent'
    'element normal\.active'
    'element alternate\.normal'
    'element alternate\.urgent'
    'element alternate\.active'
    'element selected\.normal'
    'element selected\.urgent'
    'element selected\.active'
)
missing=()
for r in "${required[@]}"; do
    grep -qE "$r" "$launcher" || missing+=("$r")
done
if [ "${#missing[@]}" -eq 0 ]; then
    pass "defect #4: rofi recipe declares global * + full 9-state element matrix"
else
    fail "defect #4: rofi recipe missing selectors: ${missing[*]}"
fi

# Validator lint mirror — launcher/validation.md must enforce the same set.
val="$rice_refs/components/launcher/validation.md"
if grep -qE 'element selected\.active' "$val" \
   && grep -qE 'element alternate\.normal' "$val" \
   && grep -qE 'element normal\.urgent' "$val"; then
    pass "defect #4: launcher validation.md lints the full 9-state matrix"
else
    fail "defect #4: launcher validation.md does not enforce the element-state matrix"
fi

# --- defect #8 — no literal `exec-once = swww-daemon` / `exec-once = awww-daemon` in any
# template file. The actual hazard is a writer emitting the hard-coded binary into
# `autostart.conf`; prose explanation of the upstream patterns inside template.md docs is
# fine. The autostart template's emission block must use `{{swww_daemon_bin}}` or the
# agnostic `sh -c …` launcher.
template_files=()
while IFS= read -r p; do template_files+=("$p"); done < <(find "$rice_refs" -name 'template.md' -o -name '*.tmpl')
swww_offenders=""
for tpl in "${template_files[@]}"; do
    out="$(grep -nE '^\s*exec-once\s*=\s*(swww-daemon|awww-daemon)\b' "$tpl" 2>/dev/null \
        | grep -vE 'sh -c|command -v (swww-daemon|awww-daemon)' || true)"
    [ -n "$out" ] && swww_offenders+="$tpl: $out"$'\n'
done
if [ -z "$swww_offenders" ]; then
    pass "defect #8: no literal 'exec-once = swww-daemon' / 'exec-once = awww-daemon' in writer templates"
else
    fail "defect #8: literal SWWW binary on an exec-once line in a template" "$swww_offenders"
fi

# --- defects #11/#14 — namespaces registry exists and references the writers ---
assert_file_exists "$shared/namespaces.md" "_shared/namespaces.md registry exists"
if grep -qE '^\| `eww-\.\*`' "$shared/namespaces.md" \
   && grep -qE '^\| `swayosd`' "$shared/namespaces.md" \
   && grep -qE '^\| `quickshell:\*`' "$shared/namespaces.md"; then
    pass "namespaces.md: eww-.*, swayosd, quickshell:* all declared"
else
    fail "namespaces.md: missing one of eww-.*, swayosd, quickshell:*"
fi

# window-rules template references the eww and swayosd namespaces
wr="$rice_refs/components/window-rules/template.md"
if grep -qE 'match:namespace\s*=\s*\^eww-\.\*\$' "$wr"; then
    pass "defect #11: window-rules template matches ^eww-.*\$ (not bare eww)"
else
    fail "defect #11: window-rules template does not match ^eww-.*\$"
fi
if grep -qE 'match:namespace\s*=\s*swayosd' "$wr"; then
    pass "defect #14: window-rules template matches swayosd namespace"
else
    fail "defect #14: window-rules template missing swayosd namespace match"
fi

# --- defects #12/#17 — expected-binds registry exists and binds are wired ---
assert_file_exists "$shared/expected-binds.md" "_shared/expected-binds.md registry exists"
if grep -qE 'eww open --toggle dashboard' "$shared/expected-binds.md" \
   && grep -qE 'custom/power' "$shared/expected-binds.md"; then
    pass "expected-binds: declares eww toggle + waybar custom/power"
else
    fail "expected-binds.md: missing eww toggle or custom/power module declaration"
fi

# keybinds template emits the eww toggle binds
kb="$rice_refs/components/keybinds/template.md"
if grep -qE 'eww open --toggle dashboard' "$kb"; then
    pass "defect #12: keybinds template emits eww dashboard toggle"
else
    fail "defect #12: keybinds template missing eww dashboard toggle"
fi

# waybar template references the custom/power module
wb="$rice_refs/components/waybar/template.md"
if grep -qE '"custom/power"' "$wb" && grep -qE 'powermenu\.sh' "$wb"; then
    pass "defect #17: waybar template emits custom/power wired to powermenu.sh"
else
    fail "defect #17: waybar template missing custom/power module"
fi

# --- helper-scripts registry covers the eww data scripts ---
assert_file_exists "$shared/helper-scripts.md" "_shared/helper-scripts.md registry exists"
for s in sysinfo audio player toggles; do
    assert_file_exists "$rice_assets/scripts/eww/$s" "defect #10: eww/$s ships under assets/scripts/eww/"
    grep -qE "^\| eww widgets *\| \`$s\`" "$shared/helper-scripts.md" \
        && pass "helper-scripts.md declares eww/$s" \
        || fail "helper-scripts.md does not declare eww/$s"
done

# --- binaries registry exists with the SWWW row ---
assert_file_exists "$shared/binaries.md" "_shared/binaries.md registry exists"
if grep -qE 'swww-daemon.*awww-daemon' "$shared/binaries.md" \
   && grep -qE 'sh -c .*command -v swww-daemon' "$shared/binaries.md"; then
    pass "binaries.md: SWWW row + agnostic launcher declared"
else
    fail "binaries.md: SWWW row or agnostic launcher missing"
fi

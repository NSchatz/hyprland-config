#!/usr/bin/env bash
# The `rice scheme` escape hatch, and the preset profiles the docs say ship.
#
# Both of these were documented-but-absent, found by auditing the docs against the shipped
# assets rather than by anything failing:
#
#   - `rice scheme <name>` is cited in palettes.md, wallpaper.md and accessibility/gotchas.md as
#     the way OUT of a high-contrast palette. The CLI had no such subcommand, so the documented
#     escape hatch did not exist.
#   - `high-contrast-dark` / `high-contrast-light` are described as shipped presets (SKILL.md's
#     "Fourteen presets ship", the full hex tables in palettes.md, the `scheme` enum in
#     palette-schema.md), but assets/profiles/ held 12 files and neither of them. `rice themes`
#     could not list them and `rice theme high-contrast-dark` failed. A WCAG-AAA accessibility
#     feature that is announced and absent is worse than one that was never claimed.
#
# Grades:
#   S-1  every scheme the docs name as a shipped preset has a profile on disk
#   S-2  each shipped profile satisfies the palette contract (every required key, bare RRGGBB)
#   S-3  `rice scheme <name>` swaps the palette and KEEPS the wallpaper
#   S-4  `rice scheme` with no argument reports usage and the current scheme, and changes nothing
#   S-5  `rice scheme <unknown>` refuses and changes nothing
#   S-6  the docs' component and interview-group counts match the disk

PROFILES="$PLUGIN_ROOT/skills/rice/assets/profiles"
RICE="$PLUGIN_ROOT/skills/rice/assets/rice"

# --- S-1  the presets the docs promise --------------------------------------------------------
for s in catppuccin-mocha catppuccin-frappe catppuccin-macchiato catppuccin-latte gruvbox nord \
         tokyo-night rose-pine dracula everforest kanagawa solarized-dark \
         high-contrast-dark high-contrast-light; do
    assert_file_exists "$PROFILES/$s.conf" "S-1: preset profile '$s' ships"
done

# The docs state a count; disagreeing with the directory is how "fourteen presets ship" became
# untrue while nothing failed.
n_profiles="$(find "$PROFILES" -name '*.conf' | wc -l)"
assert_eq "14" "$n_profiles" "S-1: the shipped preset count matches the documented fourteen"

# --- S-2  each profile satisfies the palette contract -----------------------------------------
REQUIRED=(scheme bg fg surface muted cursor accent accent2 red green yellow blue magenta cyan)
for p in "$PROFILES"/*.conf; do
    name="$(basename "$p" .conf)"
    missing=()
    for k in "${REQUIRED[@]}"; do
        grep -qE "^${k}=" "$p" || missing+=("$k")
    done
    for i in $(seq 0 15); do
        grep -qE "^color${i}=" "$p" || missing+=("color$i")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        pass "S-2: $name has every contract key"
    else
        fail "S-2: $name has every contract key" "missing: ${missing[*]}"
    fi
    # Hex is bare RRGGBB - no leading '#', which every template adds itself.
    bad="$(grep -E '^(bg|fg|surface|muted|cursor|accent|accent2|red|green|yellow|blue|magenta|cyan|color[0-9]+)=' "$p" \
           | grep -vE '=[0-9a-fA-F]{6}$' || true)"
    if [ -z "$bad" ]; then
        pass "S-2: $name uses bare RRGGBB hex"
    else
        fail "S-2: $name uses bare RRGGBB hex" "$bad"
    fi
done

# --- S-3/S-4/S-5  the `rice scheme` subcommand ------------------------------------------------
tmp="$(mktemp_test_dir rice-scheme)"
trap 'rm -rf "$tmp"' EXIT
export RICE_DIR="$tmp/rice"
mkdir -p "$RICE_DIR/profiles"
cp "$PROFILES"/high-contrast-dark.conf "$PROFILES"/nord.conf "$RICE_DIR/profiles/"
# render-templates.sh is invoked by the subcommand; stub it so this test grades the CLI, not the
# renderer (which test_render_templates.sh already covers).
printf '#!/usr/bin/env bash\nexit 0\n' > "$RICE_DIR/render-templates.sh"
chmod +x "$RICE_DIR/render-templates.sh"

# Start on high-contrast with a wallpaper set - the exact state the docs describe escaping.
cp "$PROFILES/high-contrast-dark.conf" "$RICE_DIR/palette.conf"
sed -i 's|^wallpaper=.*|wallpaper=/home/someone/Pictures/keep-me.png|' "$RICE_DIR/palette.conf"

out="$(bash "$RICE" scheme nord 2>&1)"; rc=$?
assert_eq "0" "$rc" "S-3: rice scheme exits zero on a known profile"
new_scheme="$(sed -n 's/^scheme=//p' "$RICE_DIR/palette.conf" | head -1)"
new_wp="$(sed -n 's/^wallpaper=//p' "$RICE_DIR/palette.conf" | head -1)"
new_accent="$(sed -n 's/^accent=//p' "$RICE_DIR/palette.conf" | head -1)"
assert_eq "nord" "$new_scheme" "S-3: the scheme is swapped"
assert_eq "88c0d0" "$new_accent" "S-3: the palette really is the new scheme's"
assert_eq "/home/someone/Pictures/keep-me.png" "$new_wp" "S-3: the wallpaper is KEPT, not replaced"
if printf '%s' "$out" | grep -q "wallpaper kept"; then
    pass "S-3: it says the wallpaper was kept"
else
    fail "S-3: it says the wallpaper was kept" "$out"
fi

# S-4  no argument: usage + the current scheme, nothing changed.
before="$(cat "$RICE_DIR/palette.conf")"
out="$(bash "$RICE" scheme 2>&1)"; rc=$?
assert_eq "1" "$rc" "S-4: no argument exits non-zero"
if printf '%s' "$out" | grep -q "current: nord"; then
    pass "S-4: it reports the current scheme"
else
    fail "S-4: it reports the current scheme" "$out"
fi
assert_eq "$before" "$(cat "$RICE_DIR/palette.conf")" "S-4: no argument changed nothing"

# S-5  unknown profile: refuse, change nothing.
out="$(bash "$RICE" scheme no-such-scheme 2>&1)"; rc=$?
assert_eq "1" "$rc" "S-5: an unknown profile exits non-zero"
if printf '%s' "$out" | grep -q "no profile"; then
    pass "S-5: it names the problem"
else
    fail "S-5: it names the problem" "$out"
fi
assert_eq "$before" "$(cat "$RICE_DIR/palette.conf")" "S-5: an unknown profile changed nothing"

# --- S-6  the docs' component counts match the disk ------------------------------------------
# "22 total" in the reference index while 24 folders existed is how a reader learns the docs are
# approximate. Pin both numbers to what is actually there: the folder count, and the number of
# interview groups the protocol table walks.
n_components="$(find "$PLUGIN_ROOT/skills/rice/references/components" -mindepth 1 -maxdepth 1 -type d | wc -l)"
proto="$PLUGIN_ROOT/skills/rice/references/_interview-protocol.md"
n_groups="$(grep -cE '^\| *[0-9]+ \|' "$proto")"

idx="$PLUGIN_ROOT/skills/rice/references/index.md"
assert_file_contains "$idx" "$n_components total" "S-6: the index's component count matches the disk ($n_components)"
assert_grep "walks \*\*${n_groups} groups\*\*" "$idx" "S-6: the index's interview-group count matches the protocol table ($n_groups)"

# Every component folder has a README, so no folder is a mystery.
no_readme=()
while IFS= read -r d; do
    [ -f "$d/README.md" ] || no_readme+=("$(basename "$d")")
done < <(find "$PLUGIN_ROOT/skills/rice/references/components" -mindepth 1 -maxdepth 1 -type d | sort)
if [ "${#no_readme[@]}" -eq 0 ]; then
    pass "S-6: every component folder has a README"
else
    fail "S-6: every component folder has a README" "missing: ${no_readme[*]}"
fi

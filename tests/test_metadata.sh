#!/usr/bin/env bash
# Plugin metadata and frontmatter integrity:
#   - plugin.json / marketplace.json parse and agree on the version
#   - skills/*/SKILL.md and agents/*.md have the required frontmatter keys
#   - rice/SKILL.md's version matches plugin.json's

if ! command -v jq >/dev/null 2>&1; then
    skip "metadata: jq missing" "jq required"
    return 0
fi

# --- plugin.json + marketplace.json ---------------------------------------------------------
pj="$PLUGIN_ROOT/.claude-plugin/plugin.json"
mj="$PLUGIN_ROOT/.claude-plugin/marketplace.json"
assert_file_exists "$pj" ".claude-plugin/plugin.json present"
assert_file_exists "$mj" ".claude-plugin/marketplace.json present"

assert_ok "plugin.json parses as JSON" jq -e . "$pj"
assert_ok "marketplace.json parses as JSON" jq -e . "$mj"

pj_version="$(jq -r .version "$pj")"
mj_version="$(jq -r .metadata.version "$mj")"
mj_plugin_name="$(jq -r '.plugins[0].name' "$mj")"
pj_name="$(jq -r .name "$pj")"

assert_eq "$pj_version" "$mj_version" "plugin.json and marketplace.json versions match"
assert_eq "$pj_name"    "$mj_plugin_name" "plugin.json and marketplace.json names match"

# Required top-level keys.
for k in name version description author license keywords; do
    if jq -e ".$k" "$pj" >/dev/null 2>&1; then
        pass "plugin.json has .$k"
    else
        fail "plugin.json has .$k" "missing key"
    fi
done

# Version is semver-shaped (X.Y.Z).
if [[ "$pj_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    pass "plugin.json version is semver (X.Y.Z)"
else
    fail "plugin.json version is semver (X.Y.Z)" "got: $pj_version"
fi

# --- rice/SKILL.md frontmatter version must match plugin.json -------------------------------
rice_skill="$PLUGIN_ROOT/skills/rice/SKILL.md"
# Extract just the YAML frontmatter (between the two leading ---).
rice_fm="$(awk '/^---$/{c++; next} c==1' "$rice_skill")"
rice_skill_version="$(printf '%s\n' "$rice_fm" | sed -n 's/^version:[[:space:]]*//p' | tr -d '"' )"
assert_eq "$pj_version" "$rice_skill_version" "rice/SKILL.md frontmatter version matches plugin.json"

# --- Skill frontmatter ---------------------------------------------------------------------
# Every skills/*/SKILL.md needs name + description + version. allowed-tools is optional but
# common; we don't enforce its presence.
mapfile -t skill_files < <(find "$PLUGIN_ROOT/skills" -maxdepth 2 -name 'SKILL.md' | sort)
if [ "${#skill_files[@]}" -lt 3 ]; then
    fail "skills found" "expected at least 3 SKILL.md files, found ${#skill_files[@]}"
else
    pass "${#skill_files[@]} SKILL.md files discovered"
fi

for sf in "${skill_files[@]}"; do
    rel="${sf#$PLUGIN_ROOT/}"
    fm="$(awk '/^---$/{c++; next} c==1' "$sf")"
    for required in name description; do
        if printf '%s\n' "$fm" | grep -qE "^${required}:"; then
            pass "$rel has frontmatter: $required"
        else
            fail "$rel has frontmatter: $required" "missing key"
        fi
    done
done

# --- Agent frontmatter --------------------------------------------------------------------
# name + description + model + tools required.
mapfile -t agent_files < <(find "$PLUGIN_ROOT/agents" -maxdepth 1 -name '*.md' | sort)
if [ "${#agent_files[@]}" -lt 1 ]; then
    fail "agents found" "no agents/*.md files found"
else
    pass "${#agent_files[@]} agent files discovered"
fi

for af in "${agent_files[@]}"; do
    rel="${af#$PLUGIN_ROOT/}"
    fm="$(awk '/^---$/{c++; next} c==1' "$af")"
    for required in name description model tools; do
        if printf '%s\n' "$fm" | grep -qE "^${required}:"; then
            pass "$rel has frontmatter: $required"
        else
            fail "$rel has frontmatter: $required" "missing key"
        fi
    done
done

# --- Commands frontmatter ------------------------------------------------------------------
mapfile -t cmd_files < <(find "$PLUGIN_ROOT/commands" -maxdepth 1 -name '*.md' 2>/dev/null | sort)
for cf in "${cmd_files[@]}"; do
    rel="${cf#$PLUGIN_ROOT/}"
    fm="$(awk '/^---$/{c++; next} c==1' "$cf")"
    if printf '%s\n' "$fm" | grep -qE '^description:'; then
        pass "$rel has frontmatter: description"
    else
        fail "$rel has frontmatter: description" "missing key"
    fi
done

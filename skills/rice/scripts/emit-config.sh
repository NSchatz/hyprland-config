#!/usr/bin/env bash
# Emit a baseline Hyprland configuration IN THE LANGUAGE THE COMPOSITOR READS.
#
# Since Hyprland 0.55 the documented config language is lua, and a `hyprland.lua`
# is loaded INSTEAD of `hyprland.conf`. This script is the emitter pair: one
# hyprlang writer (what the plugin always had) and one lua writer, picked by
# `config-language.sh` from the detected version rather than assumed.
#
# Usage: emit-config.sh <staging-dir>
#   <staging-dir>  Created if absent. The main config is written into it.
#
# Env:
#   HYPR_VERSION       skip detection and resolve the language from this version
#   HYPR_CONFIG_LANG   explicit language choice (lua|hyprlang)
#   BARE_TERMINAL      $terminal value (default: kitty)
#   BARE_MENU          $menu value     (default: wofi --show drun)
#
# Output:
#   HYPR_VERSION=<x.y.z|unknown>
#   CONFIG_LANGUAGE=<lua|hyprlang>
#   CONFIG_LANGUAGE_SOURCE=<detected|explicit>
#   CONFIG_LANGUAGE_RANGE=<versions that language is valid for>
#   EMITTED=<path of the file written>
#   DONE=ok
#
# Exit: 0 emitted, 2 bad usage, 3 the version could not be detected and no
#       explicit language choice was supplied (nothing is written).
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=config-language.sh
source "$here/config-language.sh"

staging="${1:-}"
if [ -z "$staging" ]; then
    echo "ERROR: usage: emit-config.sh <staging-dir>" >&2
    exit 2
fi

terminal="${BARE_TERMINAL:-kitty}"
menu="${BARE_MENU:-wofi --show drun}"

# --- Pick the language (refuses rather than assuming; see config-language.sh) ---
lang_out="$(config_lang_resolve)"
lang_rc=$?
printf '%s\n' "$lang_out"
if [ "$lang_rc" -ne 0 ]; then
    exit "$lang_rc"
fi
language="$(printf '%s\n' "$lang_out" | sed -n 's/^CONFIG_LANGUAGE=//p' | head -n1)"

mkdir -p "$staging" || { echo "ERROR: cannot create staging dir '$staging'" >&2; exit 2; }
out="$staging/$(config_lang_file "$language")"

emit_hyprlang() {
    config_lang_provenance hyprlang
    cat <<HEADER
# A minimal, working baseline. Rebuild with /hyprland-config:rice
# (full interview) or extend piecemeal with /hyprland-config:edit-config.

\$terminal = ${terminal}
\$menu     = ${menu}
HEADER
    cat <<'BARE'
$mainMod  = SUPER

# Monitors - auto-detect everything (adjust with `hyprctl monitors`).
monitor = , preferred, auto, auto

# Minimal look - small gaps, a visible border, dwindle tiling.
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    layout = dwindle
}

input {
    kb_layout = us
    follow_mouse = 1
}

# Essential keybinds - enough to open a terminal, launch apps, and exit.
bind = $mainMod, Return, exec, $terminal
bind = $mainMod, Q, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, D, exec, $menu
bind = $mainMod, Space, togglefloating,

# Move focus
bind = $mainMod, left,  movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up,    movefocus, u
bind = $mainMod, down,  movefocus, d

# Workspaces 1-5
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5

# Mouse move/resize
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow
BARE
}

emit_lua() {
    config_lang_provenance lua
    cat <<HEADER
-- A minimal, working baseline. Rebuild with /hyprland-config:rice
-- (full interview) or extend piecemeal with /hyprland-config:edit-config.
-- Config surface: hl.config / hl.monitor / hl.bind + hl.dsp.<dispatcher>().
-- See <https://wiki.hypr.land/Configuring/Start/> for the full lua API.

local terminal = "${terminal}"
local menu     = "${menu}"
HEADER
    cat <<'BARE'
local mainMod  = "SUPER"

-- Minimal look - small gaps, a visible border, dwindle tiling.
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        layout = "dwindle",
    },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
    },
})

-- Monitors - auto-detect everything (adjust with `hyprctl monitors`).
-- An empty output matches every monitor, like `monitor = , ...` in hyprlang.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Essential keybinds - enough to open a terminal, launch apps, and exit.
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.killactive())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + Space", hl.dsp.togglefloating())

-- Move focus
hl.bind(mainMod .. " + left",  hl.dsp.movefocus("l"))
hl.bind(mainMod .. " + right", hl.dsp.movefocus("r"))
hl.bind(mainMod .. " + up",    hl.dsp.movefocus("u"))
hl.bind(mainMod .. " + down",  hl.dsp.movefocus("d"))

-- Workspaces 1-5
for i = 1, 5 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.workspace(i))
    hl.bind(mainMod .. " SHIFT + " .. i, hl.dsp.movetoworkspace(i))
end

-- Mouse move/resize
hl.bind(mainMod .. " + mouse:272", hl.dsp.movewindow(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.resizewindow(), { mouse = true })
BARE
}

case "$language" in
    hyprlang) emit_hyprlang > "$out" ;;
    lua)      emit_lua      > "$out" ;;
    *)        echo "ERROR: unsupported config language: $language" >&2; exit 2 ;;
esac

echo "EMITTED=${out}"
echo "DONE=ok"

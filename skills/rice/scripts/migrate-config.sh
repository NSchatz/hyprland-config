#!/usr/bin/env bash
# Offer to convert a hyprlang `.conf` configuration - the kind earlier releases of
# this plugin wrote - into the lua config Hyprland reads from 0.55 on, keeping the
# `.conf` as a backup rather than deleting it. Hyprland 0.57 removed hyprlang: there
# a `.conf` is loaded by nothing, and this conversion is the way forward.
#
# Usage:
#   migrate-config.sh              THE OFFER: report exactly what a conversion
#                                  would do and change nothing. Always safe.
#   migrate-config.sh --convert    accept the offer and perform the conversion.
#
# Env:
#   HYPR_DIR          the config dir to convert  (explicit override; wins over
#                     XDG_CONFIG_HOME). With no HYPR_DIR the dir is $XDG_CONFIG_HOME/hypr
#                     when XDG_CONFIG_HOME is an absolute path and $HOME/.config/hypr when
#                     it is unset, empty or relative - one decision, made in
#                     scripts/xdg-config.sh and shared with every script here.
#   HYPR_BACKUP_DIR   where the `.conf` backups are written (default: $HYPR_DIR)
#
# It REFUSES, changing nothing, when:
#   - the directory already holds a `hyprland.lua` (or a `.lua` counterpart of any
#     sourced file): it will not overwrite a lua config it did not write;
#   - a `.conf` offered for conversion DOES NOT PARSE as hyprlang. The offending
#     lines are named (`UNPARSEABLE=`) and nothing is written;
#   - a `source =` line cannot be resolved to a concrete `.conf` inside the config
#     dir (a glob, a missing file, a file outside the dir). Then the converter
#     cannot even see the whole configuration, let alone report what a conversion
#     would cost, so it declines the lot (`UNRESOLVED_SOURCE=`);
#   - the backup step does not produce a readable, byte-identical copy of every
#     `.conf` it is about to convert. Then it aborts BEFORE writing any lua.
#
# A construct that PARSES but has no lua form the converter can write is NOT a
# refusal. Each such line is CARRIED ACROSS into the lua as a `-- NOT APPLIED`
# comment at its original position, reported line by line (`WOULD_NOT_APPLY=` in
# the offer, `NOT_APPLIED=` in the run), summarised in the header of every file that
# has one, and left intact in the `.conf`, which is kept. Nothing is dropped
# silently; the run says `MIGRATE=ok-with-unmapped`. Today that is: a dispatcher
# with no lua counterpart, an `exec` with a `[rules]` prefix, a bind flag or
# monitor form the converter does not know, the reload-time `exec` keyword, and
# a key Hyprland removed before lua existed (`dwindle:pseudotile`).
#
# A line that DID convert but deserves a second look is marked `-- REVIEW` and
# reported (`WOULD_REVIEW=` / `REVIEW=`): a gap list hyprlang read differently from
# how it was written, an `on-created-empty` rule (deprecated in 0.57), a shell
# command that calls `hyprctl keyword` or a legacy `hyprctl dispatch`.
#
# What it writes is the lua API as Hyprland documents it:
#   comments and blank lines, in place (a trailing `# note` becomes `-- note`),
#   `$var = value` -> expanded where it is used, as hyprlang does - EXCEPT a sourced
#     file that defines nothing but `$variables` (the palette the theme engine
#     regenerates): that becomes a module, `return { accent = "rgb(...)", ... }`,
#     and each file that uses a value reads it with `local c = require("colors")`,
#   `source = <a .conf under the config dir>` -> `require("<stem>")`, converted at
#     the source line so what it defines is visible to the lines after it,
#   `section { key = value }` (nestable) -> `hl.config({ section = { ... } })`, with
#     values typed by the option: `col.active_border = rgb(a) rgb(b) 45deg` is
#     `col = { active_border = { colors = {...}, angle = 45 } }`, a css gap is an
#     integer or a `{ top, right, bottom, left }` table, `tap-to-click` is
#     `tap_to_click`, `kb_layout = no` stays the string "no",
#   `windowrule { match:class = ... }` -> `hl.window_rule({ match = { class = ... } })`,
#   `layerrule { match:namespace = ... }` -> `hl.layer_rule({ match = { ... } })`,
#     and their 0.53 one-line form (`windowrule = float on, match:class kitty`),
#   `device { name = ... }` -> `hl.device({...})`, `monitorv2 { }` -> `hl.monitor({...})`,
#   `monitor = out, mode, pos, scale[, key, value]` -> `hl.monitor({...})`,
#   `workspace = sel, rule:value, ...` -> `hl.workspace_rule({...})`,
#   `bezier` -> `hl.curve(...)`, `animation` -> `hl.animation({...})`,
#   `gesture` -> `hl.gesture({...})`, `permission` -> `hl.permission({...})`,
#   `bind[flags] = MODS, KEY, DISPATCHER[, ARGS]` -> `hl.bind("MOD + MOD + KEY", ...)`
#     with the LUA dispatcher (`killactive` is `hl.dsp.window.close()`; the legacy
#     names are nil in lua - see scripts/ricelib/hypr/luadispatch.py),
#   `submap = name` ... `submap = reset` -> `hl.define_submap("name", function() ... end)`,
#   `exec-once = cmd` -> `hl.exec_cmd("cmd")` INSIDE `hl.on("hyprland.start", ...)`, and
#     `exec-shutdown` inside `hl.on("hyprland.shutdown", ...)`. Never at the top level:
#     top-level code runs on every evaluation, including `Hyprland --verify-config`,
#   `env = NAME,value` -> `hl.env("NAME", "value")`; `envd` adds `, true`.
#
# Output:
#   MIGRATE_OFFER=<what would happen>   (offer mode)
#   WOULD_WRITE= / WOULD_KEEP= / WOULD_BACK_UP= / WOULD_NOT_APPLY= / WOULD_REVIEW=
#   BACKUP=<dir> / BACKED_UP=<path> / WROTE=<path> / KEPT=<path> / NOT_APPLIED= / REVIEW=
#   MIGRATE=ok | ok-with-unmapped | offered | nothing-to-convert
#         | refused-existing-lua | refused-unparseable | refused-unresolvable-source
#         | refused-no-config-dir | aborted-backup-failed
#
# Exit: 0 converted / offered / nothing to convert,
#       2 bad usage or no config directory could be determined,
#       3 refused (unparseable, or an unresolvable `source =`),
#       4 refused (a lua config is already there), 5 aborted (backup failed).
#
# THE IMPLEMENTATION IS PYTHON (scripts/ricelib/hypr/migrateconfig.py). This file locates
# the package and hands off; the name is the interface every caller, doc and test uses.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
libdir=""
for c in "$here" "$here/../../../scripts" "${CLAUDE_PLUGIN_ROOT:-}/scripts" "${RICE_DIR:-}"; do
    if [ -n "$c" ] && [ -f "$c/ricelib/__init__.py" ]; then libdir="$(cd "$c" && pwd)"; break; fi
done
if [ -z "$libdir" ]; then
    echo "ERROR: the ricelib package was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in \$RICE_DIR." >&2
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required and is not installed (sudo pacman -S --needed python)." >&2
    exit 2
fi
PYTHONPATH="$libdir${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m ricelib.hypr.migrateconfig "$@"

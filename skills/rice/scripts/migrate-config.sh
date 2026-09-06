#!/usr/bin/env bash
# Offer to convert a hyprlang `.conf` configuration - the kind earlier releases of
# this plugin wrote - into the lua config Hyprland reads from 0.55 on, keeping the
# `.conf` as a backup rather than deleting it.
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
# A construct that PARSES but has no documented lua mapping is NOT a refusal.
# Refusing there means the configs this plugin itself generates - which use
# `bezier`, `animation` and `gesture`, none of which has a documented lua form -
# get no conversion at all, on exactly the 0.56 machines where the compositor has
# stopped reading their `.conf`. Instead each such line is CARRIED ACROSS into the
# lua as a `-- NOT APPLIED` comment at its original position, reported line by
# line (`WOULD_NOT_APPLY=` in the offer, `NOT_APPLIED=` in the run), summarised in
# the header of every file that has one, and left intact in the `.conf`, which is
# kept. Nothing is dropped silently; the run says `MIGRATE=ok-with-unmapped`.
#
# Constructs it converts:
#   comments, blank lines, `$var = value` (expanded textually, as hyprlang does),
#   `source = <a .conf under the config dir>` -> `require("<stem>")`,
#   `section { key = value }` (nestable) -> `hl.config({ section = { ... } })`,
#     a key that is not a lua identifier (`col.active_border`, `tap-to-click`)
#     becomes a bracket key: `["col.active_border"] = ...`,
#   `windowrule { match:class = ... }` -> `hl.window_rule({ match = { class = ... } })`,
#   `layerrule { match:namespace = ... }` -> `hl.layer_rule({ match = { ... } })`,
#   `monitor = out, mode, pos, scale` -> `hl.monitor({...})`,
#   `bind[flags] = MODS, KEY, DISPATCHER[, ARGS]` -> `hl.bind(..., hl.dsp.*)`,
#   `exec-once = cmd` -> `hl.exec_cmd("cmd")`,
#   `env`/`envd = NAME,value` -> `hl.env("NAME", "value")`.
#
# Output:
#   MIGRATE_OFFER=<what would happen>   (offer mode)
#   WOULD_WRITE= / WOULD_KEEP= / WOULD_BACK_UP= / WOULD_NOT_APPLY=
#   BACKUP=<dir> / BACKED_UP=<path> / WROTE=<path> / KEPT=<path> / NOT_APPLIED=
#   MIGRATE=ok | ok-with-unmapped | offered | nothing-to-convert
#         | refused-existing-lua | refused-unparseable | refused-unresolvable-source
#         | refused-no-config-dir | aborted-backup-failed
#
# Exit: 0 converted / offered / nothing to convert,
#       2 bad usage or no config directory could be determined,
#       3 refused (unparseable, or an unresolvable `source =`),
#       4 refused (a lua config is already there), 5 aborted (backup failed).
set -uo pipefail
# Config values routinely contain `*` and `?` (window-rule regexes, exec commands).
# Nothing here needs pathname expansion, and letting it happen would rewrite a
# user's config line into whatever happens to be on disk. Turn it off.
set -f

mode="offer"
case "${1:-}" in
    "")          ;;
    --convert)   mode="convert" ;;
    -h|--help)   sed -n '2,65p' "$0"; exit 0 ;;
    *)           echo "ERROR: usage: migrate-config.sh [--convert]" >&2; exit 2 ;;
esac

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=config-language.sh
source "$here/config-language.sh"
_xdg_lib=""
for _c in "$here/xdg-config.sh" \
          "$here/../../../scripts/xdg-config.sh" \
          "${CLAUDE_PLUGIN_ROOT:-}/scripts/xdg-config.sh"; do
    if [ -n "$_c" ] && [ -f "$_c" ]; then _xdg_lib="$_c"; break; fi
done
if [ -z "$_xdg_lib" ]; then
    echo "ERROR: the config-path library (scripts/xdg-config.sh) was not found next to $0, in \$CLAUDE_PLUGIN_ROOT/scripts, or in the plugin. Refusing to guess where your config lives." >&2
    exit 2
fi
# shellcheck source=../../../scripts/xdg-config.sh
. "$_xdg_lib"

if ! xdg_config_target hypr "${HYPR_DIR:-}"; then
    echo "MIGRATE=refused-no-config-dir"
    exit 2
fi
target="$XDG_CONFIG_TARGET"
backup_dir="${HYPR_BACKUP_DIR:-$target}"
main="$target/hyprland.conf"
# The dir a `source = ~/.config/hypr/...` line names, which is NOT the same thing as the
# dir being converted. hyprlang expands a leading `~` to $HOME and nothing else - it has
# never read XDG_CONFIG_HOME - so this stays literally $HOME/.config/hypr even when the
# conversion target has moved. Rebasing it onto the target is convert_source's job, below.
home_config_dir="${HOME:-}/.config/hypr"   # XDG-OK: what hyprlang's `~` means, not our target

echo "TARGET=${target}"

if [ ! -f "$main" ]; then
    echo "There is no ${main} to convert."
    echo "MIGRATE=nothing-to-convert"
    exit 0
fi

# --- Refusal 1: never overwrite a lua config we did not write -------------------------------
if config_lang_present "$target/hyprland.lua"; then
    echo "ERROR: '$target/hyprland.lua' already exists; refusing to replace it." >&2
    echo "       That file is what Hyprland actually loads. Move it aside first if you" >&2
    echo "       really want this conversion to produce a new one." >&2
    echo "DECLINED_TO_REPLACE=${target}/hyprland.lua"
    echo "MIGRATE=refused-existing-lua"
    exit 4
fi

# ---------------------------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------------------------
declare -A VARS=()
declare -a PARSE_ERRORS=()
declare -a SOURCE_ERRORS=()
declare -a UNMAPPED=()
declare -a QUEUE=()
declare -a SEEN=()
file_unmapped=0

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# hyprlang strips `#` comments, including trailing ones. Mirror that: a `#` at the
# start of the line, or preceded by whitespace, begins a comment.
strip_comment() {
    local s="$1" t
    t="$(trim "$s")"
    case "$t" in '#'*) printf ''; return 0 ;; esac
    printf '%s' "${s%%[[:space:]]#*}"
}

expand_vars() {
    local s="$1" name
    # Longest names first so `$mainMod` is not eaten by a `$main`.
    for name in $(printf '%s\n' "${!VARS[@]}" | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-); do
        s="${s//\$$name/${VARS[$name]}}"
    done
    printf '%s' "$s"
}

lua_string() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '"%s"' "$s"
}

lua_value() {
    local v
    v="$(trim "$1")"
    case "$v" in
        "")                       lua_string "" ; return ;;
        true|false)               printf '%s' "$v"; return ;;
        yes)                      printf 'true'; return ;;
        no)                       printf 'false'; return ;;
    esac
    case "$v" in
        -[0-9]*|[0-9]*)
            if [[ "$v" =~ ^-?[0-9]+$ ]] || [[ "$v" =~ ^-?[0-9]*\.[0-9]+$ ]]; then
                printf '%s' "$v"; return
            fi ;;
    esac
    lua_string "$v"
}

# `lua_key <hyprlang key>` - the same key as a lua table key. hyprlang option names
# are not all lua identifiers (`col.active_border`, `tap-to-click`), and lua's own
# bracket-key syntax is how a table holds one. No hyprlang name is invented here;
# the key is carried across verbatim.
lua_key() {
    local k="$1"
    case "$k" in
        and|break|do|else|elseif|end|false|for|function|goto|if|in|local|nil|not|or|repeat|return|then|true|until|while)
            printf '[%s]' "$(lua_string "$k")"; return ;;
    esac
    if [[ "$k" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        printf '%s' "$k"
    else
        printf '[%s]' "$(lua_string "$k")"
    fi
}

indent() { printf '%*s' $(( 4 * $1 )) ''; }

lua_stem() {
    # `<dir>/env.conf` under $target -> `env`; `<dir>/sub/x.conf` -> `sub/x`
    local p="${1#"$target"/}"
    printf '%s' "${p%.conf}"
}

# A line that is not valid hyprlang. AC-9's refusal: nothing is written.
note_parse_error()  { PARSE_ERRORS+=("$1"); }
# A `source =` the converter cannot resolve. It cannot see the whole config, so it
# declines rather than convert a set it has not read.
note_source_error() { SOURCE_ERRORS+=("$1"); }

# `note_unmapped <in> <lineno> <why> <text> <out> <indent-level>` - a line that
# parses but has no documented lua mapping. Carried across as a comment at its
# original position, and reported. Never dropped, never silent.
note_unmapped() {
    local in="$1" lineno="$2" why="$3" text="$4" out="$5" lvl="$6"
    UNMAPPED+=("${in}:${lineno}: ${why}: ${text}")
    file_unmapped=$((file_unmapped + 1))
    { indent "$lvl"; printf -- '-- NOT APPLIED (%s): %s\n' "$why" "$text"; } >> "$out"
}

# hyprlang keywords that may appear more than once in one scope. A lua table cannot
# hold the same key twice, and none of these has a documented lua table form, so
# they are carried across rather than silently collapsed to the last one.
is_repeatable_keyword() {
    case "$1" in
        bezier|animation|gesture|windowrule|windowrulev2|layerrule|layerrulev2) return 0 ;;
        workspace|blurls|permission|submap|plugin|source|monitor|monitorv2) return 0 ;;
        env|envd|exec|exec-once|exec-shutdown|unbind) return 0 ;;
        bind|bind[a-z]*) return 0 ;;
    esac
    return 1
}

# convert_file <input.conf> <body.lua>   (the provenance header is composed later)
convert_file() {
    local in="$1" out="$2" lineno=0 depth=0
    local raw line body key val name rest t
    local rule_open="" rule_skip=0 mk
    declare -a rule_match=() rule_props=()
    file_unmapped=0
    : > "$out"

    while IFS= read -r raw || [ -n "$raw" ]; do
        lineno=$((lineno + 1))
        body="$(strip_comment "$raw")"
        line="$(trim "$body")"

        if [ -z "$line" ]; then
            # Keep whole-line comments; a trailing comment is dropped (the .conf
            # backup still has it). Inside a buffered rule block there is nowhere
            # to put one, so it waits for the rule to be flushed.
            t="$(trim "$raw")"
            if [ -z "$rule_open" ]; then
                case "$t" in
                    '#'*) printf -- '--%s\n' "${t#\#}" >> "$out" ;;
                    '')   printf '\n' >> "$out" ;;
                esac
            fi
            continue
        fi

        # --- inside a windowrule / layerrule block (buffered until its `}`) ------
        if [ -n "$rule_open" ]; then
            if [ "$rule_skip" -gt 0 ]; then
                case "$line" in
                    *'{') rule_skip=$((rule_skip + 1)) ;;
                    '}')  rule_skip=$((rule_skip - 1)) ;;
                esac
                continue
            fi
            if [ "$line" = "}" ]; then
                flush_rule "$rule_open" "$out"
                rule_open=""
                rule_match=(); rule_props=()
                continue
            fi
            if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_:.-]*)[[:space:]]*\{$ ]]; then
                note_unmapped "$in" "$lineno" "a nested block inside a ${rule_open} has no documented lua mapping" "$line" "$out" 0
                rule_skip=1
                continue
            fi
            if [[ "$line" != *"="* ]]; then
                note_parse_error "${in}:${lineno}: not a hyprlang assignment or section: ${line}"
                continue
            fi
            key="$(trim "${line%%=*}")"
            val="$(expand_vars "$(trim "${line#*=}")")"
            case "$key" in
                match:*)
                    mk="${key#match:}"
                    rule_match+=("$(lua_key "$mk") = $(lua_value "$val"),") ;;
                *)
                    rule_props+=("$(lua_key "$key") = $(lua_value "$val"),") ;;
            esac
            continue
        fi

        # Block close
        if [ "$line" = "}" ]; then
            if [ "$depth" -eq 0 ]; then
                note_parse_error "${in}:${lineno}: stray '}' with no open section"
                continue
            fi
            depth=$((depth - 1))
            if [ "$depth" -eq 0 ]; then
                { indent 1; printf '},\n'; printf '})\n'; } >> "$out"
            else
                { indent $((depth + 1)); printf '},\n'; } >> "$out"
            fi
            continue
        fi

        # Block open:  name {
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_:.-]*)[[:space:]]*\{$ ]]; then
            name="${BASH_REMATCH[1]}"
            if [ "$depth" -eq 0 ]; then
                case "$name" in
                    windowrule|windowrulev2)
                        rule_open="window_rule"; rule_match=(); rule_props=(); continue ;;
                    layerrule|layerrulev2)
                        rule_open="layer_rule";  rule_match=(); rule_props=(); continue ;;
                esac
                { printf 'hl.config({\n'; indent 1; printf '%s = {\n' "$(lua_key "$name")"; } >> "$out"
            else
                { indent $((depth + 1)); printf '%s = {\n' "$(lua_key "$name")"; } >> "$out"
            fi
            depth=$((depth + 1))
            continue
        fi

        # key = value
        if [[ "$line" != *"="* ]]; then
            note_parse_error "${in}:${lineno}: not a hyprlang assignment or section: ${line}"
            continue
        fi
        key="$(trim "${line%%=*}")"
        val="$(trim "${line#*=}")"

        # Variable definition
        if [ "${key:0:1}" = '$' ]; then
            name="${key:1}"
            if [[ ! "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                note_parse_error "${in}:${lineno}: variable name '${key}' is not usable: ${line}"
                continue
            fi
            VARS["$name"]="$(expand_vars "$val")"
            printf -- '-- %s = %s (expanded inline below, as hyprlang does)\n' "$key" "${VARS[$name]}" >> "$out"
            continue
        fi

        val="$(expand_vars "$val")"

        # Inside a section: a plain table entry.
        if [ "$depth" -gt 0 ]; then
            if is_repeatable_keyword "$key"; then
                note_unmapped "$in" "$lineno" \
                    "'${key}' is a repeatable hyprlang keyword with no documented lua mapping" \
                    "$line" "$out" $((depth + 1))
                continue
            fi
            { indent $((depth + 1)); printf '%s = %s,\n' "$(lua_key "$key")" "$(lua_value "$val")"; } >> "$out"
            continue
        fi

        # Top-level keywords.
        case "$key" in
            source)
                convert_source "$in" "$lineno" "$val" "$out"
                ;;
            monitor)
                convert_monitor "$in" "$lineno" "$val" "$out" "$line"
                ;;
            exec-once)
                { printf 'hl.exec_cmd(%s)\n' "$(lua_string "$val")"; } >> "$out"
                ;;
            env|envd)
                # On 0.55+ every hl.env() is implicitly the envd form.
                name="$(trim "${val%%,*}")"
                rest="$(trim "${val#*,}")"
                if [ "$name" = "$val" ]; then
                    note_parse_error "${in}:${lineno}: ${key} needs NAME,value: ${line}"
                else
                    printf 'hl.env(%s, %s)\n' "$(lua_string "$name")" "$(lua_string "$rest")" >> "$out"
                fi
                ;;
            bind*)
                convert_bind "$in" "$lineno" "$key" "$val" "$out" "$line"
                ;;
            *)
                note_unmapped "$in" "$lineno" \
                    "'${key}' has no documented lua mapping in this converter" "$line" "$out" 0
                ;;
        esac
    done < "$in"

    if [ -n "$rule_open" ]; then
        note_parse_error "${in}: a ${rule_open} block was opened and never closed"
    fi
    if [ "$depth" -ne 0 ]; then
        note_parse_error "${in}: ${depth} section(s) opened and never closed"
    fi
}

# `flush_rule <window_rule|layer_rule> <out>` - emit the buffered block. The shape
# (`name`, a `match = { ... }` sub-table, then the properties) is the one the
# reference layer documents at references/components/window-rules/template.md and
# references/components/launcher/gotchas.md.
flush_rule() {
    local kind="$1" out="$2" e
    {
        printf 'hl.%s({\n' "$kind"
        if [ "${#rule_match[@]}" -gt 0 ]; then
            printf '    match = {\n'
            for e in "${rule_match[@]}"; do printf '        %s\n' "$e"; done
            printf '    },\n'
        fi
        for e in ${rule_props[@]+"${rule_props[@]}"}; do printf '    %s\n' "$e"; done
        printf '})\n'
    } >> "$out"
}

convert_source() {
    local in="$1" lineno="$2" val="$3" out="$4" p base
    case "$val" in
        *'*'*|*'?'*)
            note_source_error "${in}:${lineno}: 'source' with a glob cannot be resolved to a fixed set of files: source = ${val}"
            return ;;
    esac
    p="$val"
    case "$p" in
        '~/'*) p="${HOME:-}/${p#\~/}" ;;
        /*)    ;;
        *)     p="$(dirname "$in")/$p" ;;
    esac
    # Target override. Every writing script in this repo resolves its target through
    # scripts/xdg-config.sh (HYPR_DIR, else an absolute XDG_CONFIG_HOME, else
    # $HOME/.config); a `source = ~/.config/hypr/...` line - the form this plugin's own
    # generator writes - names $HOME/.config/hypr, because that is all hyprlang's `~`
    # expansion can mean. Rebase it onto the dir actually being converted, or the two
    # disagree and a perfectly good config looks unresolvable whenever the target has
    # moved (HYPR_DIR set, or XDG_CONFIG_HOME pointing somewhere else).
    if [ -n "$home_config_dir" ] && [ "$target" != "$home_config_dir" ]; then
        case "$p" in
            "$home_config_dir"/*) p="${target}/${p#"$home_config_dir"/}" ;;
        esac
    fi
    case "$p" in
        *.conf) ;;
        *) note_source_error "${in}:${lineno}: 'source' of a non-.conf file: source = ${val}"; return ;;
    esac
    if [ ! -f "$p" ]; then
        note_source_error "${in}:${lineno}: sourced file does not exist: ${p}"
        return
    fi
    case "$p" in
        "$target"/*) ;;
        *) note_source_error "${in}:${lineno}: sourced file lives outside ${target}: ${p}"; return ;;
    esac
    base="$(lua_stem "$p")"
    printf 'require(%s)\n' "$(lua_string "$base")" >> "$out"
    QUEUE+=("$p")
}

convert_monitor() {
    local in="$1" lineno="$2" val="$3" out="$4" line="$5"
    local IFS=','
    # shellcheck disable=SC2206
    local parts=($val)
    unset IFS
    if [ "${#parts[@]}" -ne 4 ]; then
        note_unmapped "$in" "$lineno" \
            "only the 4-field 'monitor = output, mode, position, scale' form has a documented lua mapping" \
            "$line" "$out" 0
        return
    fi
    printf 'hl.monitor({ output = %s, mode = %s, position = %s, scale = %s })\n' \
        "$(lua_string "$(trim "${parts[0]}")")" \
        "$(lua_value "${parts[1]}")" \
        "$(lua_value "${parts[2]}")" \
        "$(lua_value "${parts[3]}")" >> "$out"
}

# `bind` flag letter -> lua option key (keybinds/gotchas.md's table).
bind_option_for_flag() {
    case "$1" in
        e) printf 'repeating' ;;
        l) printf 'locked' ;;
        r) printf 'release' ;;
        m) printf 'mouse' ;;
        n) printf 'non_consuming' ;;
        t) printf 'transparent' ;;
        i) printf 'ignore_mods' ;;
        *) return 1 ;;
    esac
}

convert_bind() {
    local in="$1" lineno="$2" key="$3" val="$4" out="$5" line="$6"
    local flags="${key#bind}" has_description=0 opts="" i ch opt
    for (( i=0; i<${#flags}; i++ )); do
        ch="${flags:i:1}"
        if [ "$ch" = "d" ]; then has_description=1; continue; fi
        if ! opt="$(bind_option_for_flag "$ch")"; then
            note_unmapped "$in" "$lineno" \
                "bind flag '${ch}' in '${key}' has no documented lua option" "$line" "$out" 0
            return
        fi
        opts="${opts}${opts:+, }${opt} = true"
    done

    local IFS=','
    # shellcheck disable=SC2206
    local parts=($val)
    unset IFS
    local mods keyname description="" dispatcher args=""
    mods="$(trim "${parts[0]:-}")"
    keyname="$(trim "${parts[1]:-}")"
    local next=2
    if [ "$has_description" -eq 1 ]; then
        description="$(trim "${parts[2]:-}")"
        next=3
    fi
    dispatcher="$(trim "${parts[$next]:-}")"
    if [ -z "$keyname" ] || [ -z "$dispatcher" ]; then
        note_parse_error "${in}:${lineno}: bind needs MODS, KEY, DISPATCHER: ${key} = ${val}"
        return
    fi
    if [[ ! "$dispatcher" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        note_unmapped "$in" "$lineno" \
            "dispatcher '${dispatcher}' is not a lua identifier, so it has no hl.dsp.* form" "$line" "$out" 0
        return
    fi

    # `exec` takes the whole rest of the line as one command; every other
    # dispatcher takes comma-separated args.
    local arglist=""
    if [ "$dispatcher" = "exec" ]; then
        dispatcher="exec_cmd"
        local prefix=""
        local n
        for (( n=0; n<=next; n++ )); do prefix="${prefix}${parts[n]},"; done
        args="$(trim "${val:${#prefix}}")"
        arglist="$(lua_string "$args")"
    else
        local n a
        local -a collected=()
        for (( n=next+1; n<${#parts[@]}; n++ )); do collected+=("${parts[n]}"); done
        # hyprlang tolerates a trailing empty field (`killactive,`); drop them.
        while [ "${#collected[@]}" -gt 0 ] && [ -z "$(trim "${collected[-1]}")" ]; do
            unset 'collected[-1]'
        done
        for a in ${collected[@]+"${collected[@]}"}; do
            arglist="${arglist}${arglist:+, }$(lua_value "$a")"
        done
    fi

    local chord
    if [ -n "$mods" ]; then chord="${mods} + ${keyname}"; else chord="${keyname}"; fi
    if [ -n "$description" ]; then
        opts="${opts}${opts:+, }description = $(lua_string "$description")"
    fi
    if [ -n "$opts" ]; then
        printf 'hl.bind(%s, hl.dsp.%s(%s), { %s })\n' "$(lua_string "$chord")" "$dispatcher" "$arglist" "$opts" >> "$out"
    else
        printf 'hl.bind(%s, hl.dsp.%s(%s))\n' "$(lua_string "$chord")" "$dispatcher" "$arglist" >> "$out"
    fi
}

# `compose_file <original.conf> <body.lua> <final.lua> <unmapped-count>` - the
# provenance header AC-3 asks for, then the carry-over summary when there is one,
# then the converted body.
compose_file() {
    local in="$1" body="$2" final="$3" count="$4"
    {
        config_lang_provenance lua
        printf -- '-- Converted from %s by the hyprland-config plugin.\n' "${in#"$target"/}"
        printf -- '-- The original .conf is kept as a backup; see the BACKUP= line of the run.\n'
        if [ "$count" -gt 0 ]; then
            printf -- '--\n'
            printf -- '-- NOT APPLIED: %d line(s) below have no documented lua mapping and were\n' "$count"
            printf -- '-- carried across as comments marked `NOT APPLIED`. They DO NOT take effect:\n'
            printf -- '-- Hyprland loads hyprland.lua INSTEAD of hyprland.conf. The original .conf is\n'
            printf -- '-- kept (see the KEPT= line of the run) so you can port them by hand.\n'
        fi
        printf -- '\n'
        cat "$body"
    } > "$final"
}

# --- Walk the whole .conf set, into a scratch dir; the target is not touched ------------------
scratch="$(mktemp -d "${TMPDIR:-/tmp}/hypr-migrate.XXXXXX")" || {
    echo "ERROR: could not create a scratch directory" >&2
    echo "MIGRATE=refused-unparseable"
    exit 3
}
cleanup() { rm -rf "$scratch"; }
trap cleanup EXIT

declare -a CONVERTED_FROM=()
declare -a CONVERTED_TO=()

QUEUE=("$main")
while [ "${#QUEUE[@]}" -gt 0 ]; do
    src="${QUEUE[0]}"
    QUEUE=("${QUEUE[@]:1}")
    already=0
    for s in ${SEEN[@]+"${SEEN[@]}"}; do [ "$s" = "$src" ] && already=1; done
    [ "$already" -eq 1 ] && continue
    SEEN+=("$src")

    stem="$(lua_stem "$src")"
    lua_target="${target}/${stem}.lua"
    if config_lang_present "$lua_target"; then
        echo "ERROR: '$lua_target' already exists; refusing to replace it." >&2
        echo "DECLINED_TO_REPLACE=${lua_target}"
        echo "MIGRATE=refused-existing-lua"
        exit 4
    fi
    mkdir -p "$(dirname "$scratch/$stem.lua")"
    convert_file "$src" "$scratch/$stem.body"
    compose_file "$src" "$scratch/$stem.body" "$scratch/$stem.lua" "$file_unmapped"
    CONVERTED_FROM+=("$src")
    CONVERTED_TO+=("$lua_target")
done

# --- Refusal 2: the config does not parse as hyprlang (AC-9) ----------------------------------
if [ "${#PARSE_ERRORS[@]}" -gt 0 ]; then
    echo "ERROR: this configuration does not parse as hyprlang, so nothing was changed." >&2
    echo "       Fix the lines below and re-run; the converter will not guess at them." >&2
    for e in "${PARSE_ERRORS[@]}"; do
        echo "UNPARSEABLE=${e}"
    done
    echo "UNPARSEABLE_COUNT=${#PARSE_ERRORS[@]}"
    echo "MIGRATE=refused-unparseable"
    exit 3
fi

# --- Refusal 3: a `source =` the converter cannot resolve -------------------------------------
if [ "${#SOURCE_ERRORS[@]}" -gt 0 ]; then
    echo "ERROR: a 'source =' line could not be resolved, so nothing was changed." >&2
    echo "       The converter cannot read the whole configuration, and it will not" >&2
    echo "       convert a set it has not seen: whole files would stop loading." >&2
    for e in "${SOURCE_ERRORS[@]}"; do
        echo "UNRESOLVED_SOURCE=${e}"
    done
    echo "UNRESOLVED_SOURCE_COUNT=${#SOURCE_ERRORS[@]}"
    echo "MIGRATE=refused-unresolvable-source"
    exit 3
fi

ts="$(date +%Y%m%d-%H%M%S)"

# --- Offer mode: say exactly what would happen, change nothing --------------------------------
if [ "$mode" = "offer" ]; then
    echo "MIGRATE_OFFER=convert ${#CONVERTED_FROM[@]} hyprlang .conf file(s) in ${target} to lua"
    echo "OFFER_REASON=$(config_lang_range hyprlang)"
    for i in "${!CONVERTED_FROM[@]}"; do
        echo "WOULD_WRITE=${CONVERTED_TO[$i]}"
        echo "WOULD_KEEP=${CONVERTED_FROM[$i]}"
        echo "WOULD_BACK_UP=${backup_dir}/$(basename "${CONVERTED_FROM[$i]}").pre-lua.${ts}"
    done
    if [ "${#UNMAPPED[@]}" -gt 0 ]; then
        echo "WARNING: ${#UNMAPPED[@]} line(s) have no documented lua mapping. They would be" >&2
        echo "         carried across as '-- NOT APPLIED' comments and would STOP APPLYING," >&2
        echo "         because Hyprland loads hyprland.lua instead of hyprland.conf. The .conf" >&2
        echo "         is kept either way, so you can port them by hand afterwards." >&2
        for e in "${UNMAPPED[@]}"; do
            echo "WOULD_NOT_APPLY=${e}"
        done
        echo "WOULD_NOT_APPLY_COUNT=${#UNMAPPED[@]}"
    fi
    echo "ACCEPT_WITH=migrate-config.sh --convert"
    echo "MIGRATE=offered"
    exit 0
fi

# --- Backup FIRST, and prove it is readable, before a byte of lua is written ------------------
if ! mkdir -p "$backup_dir" 2>/dev/null; then
    echo "ERROR: could not create the backup directory '${backup_dir}'." >&2
    echo "       Aborted because the backup failed; no lua was written and nothing changed." >&2
    echo "BACKUP_FAILED=${backup_dir}"
    echo "MIGRATE=aborted-backup-failed"
    exit 5
fi

declare -a MADE_BACKUPS=()
backup_failed=""
for f in "${CONVERTED_FROM[@]}"; do
    b="${backup_dir}/$(basename "$f").pre-lua.${ts}"
    if ! cp -p "$f" "$b" 2>/dev/null; then backup_failed="$b"; break; fi
    if [ ! -r "$b" ] || ! cmp -s "$f" "$b"; then backup_failed="$b"; break; fi
    MADE_BACKUPS+=("$b")
done

if [ -n "$backup_failed" ]; then
    for b in ${MADE_BACKUPS[@]+"${MADE_BACKUPS[@]}"}; do rm -f "$b"; done
    echo "ERROR: the backup step did not produce a readable copy of the original .conf." >&2
    echo "       Aborted because the backup failed; no lua was written and nothing changed." >&2
    echo "BACKUP_FAILED=${backup_failed}"
    echo "MIGRATE=aborted-backup-failed"
    exit 5
fi

echo "BACKUP=${backup_dir}"
for b in "${MADE_BACKUPS[@]}"; do echo "BACKED_UP=${b}"; done

# --- Commit the lua ---------------------------------------------------------------------------
for i in "${!CONVERTED_FROM[@]}"; do
    stem="$(lua_stem "${CONVERTED_FROM[$i]}")"
    mkdir -p "$(dirname "${CONVERTED_TO[$i]}")"
    cp -f "$scratch/$stem.lua" "${CONVERTED_TO[$i]}"
    echo "WROTE=${CONVERTED_TO[$i]}"
    echo "KEPT=${CONVERTED_FROM[$i]}"
done

echo "CONFIG_LANGUAGE=lua"
echo "CONFIG_LANGUAGE_RANGE=$(config_lang_range lua)"

if [ "${#UNMAPPED[@]}" -gt 0 ]; then
    echo "WARNING: ${#UNMAPPED[@]} line(s) had no documented lua mapping. They are in the" >&2
    echo "         converted files as '-- NOT APPLIED' comments and DO NOT take effect." >&2
    echo "         Every original .conf was kept, so port them by hand from there." >&2
    for e in "${UNMAPPED[@]}"; do
        echo "NOT_APPLIED=${e}"
    done
    echo "NOT_APPLIED_COUNT=${#UNMAPPED[@]}"
    echo "MIGRATE=ok-with-unmapped"
    exit 0
fi

echo "MIGRATE=ok"

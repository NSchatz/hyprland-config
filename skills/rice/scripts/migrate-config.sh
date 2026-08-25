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
#   HYPR_DIR          the config dir to convert  (default: ~/.config/hypr)
#   HYPR_BACKUP_DIR   where the `.conf` backups are written (default: $HYPR_DIR)
#
# It REFUSES, changing nothing, when:
#   - the directory already holds a `hyprland.lua` (or a `.lua` counterpart of any
#     sourced file): it will not overwrite a lua config it did not write;
#   - a `.conf` offered for conversion does not parse as hyprlang, or uses a
#     construct this converter has no documented lua mapping for. A partial
#     conversion is the WORST outcome available here: the moment a `hyprland.lua`
#     exists the compositor stops reading the `.conf`, so anything left behind
#     silently stops applying. So it is all or nothing, and the leftovers are
#     named by file and line;
#   - the backup step does not produce a readable, byte-identical copy of every
#     `.conf` it is about to convert. Then it aborts BEFORE writing any lua.
#
# Constructs it converts (everything else is refused by name):
#   comments, blank lines, `$var = value` (expanded textually, as hyprlang does),
#   `source = <a .conf under the config dir>` -> `require("<stem>")`,
#   `section { key = value }` (nestable) -> `hl.config({ section = { ... } })`,
#   `monitor = out, mode, pos, scale` -> `hl.monitor({...})`,
#   `bind[flags] = MODS, KEY, DISPATCHER[, ARGS]` -> `hl.bind(..., hl.dsp.*)`,
#   `exec-once = cmd` -> `hl.exec_cmd("cmd")`,
#   `env`/`envd = NAME,value` -> `hl.env("NAME", "value")`.
#
# Output:
#   MIGRATE_OFFER=<what would happen>   (offer mode)
#   WOULD_WRITE= / WOULD_KEEP= / WOULD_BACK_UP=
#   BACKUP=<dir> / BACKED_UP=<path> / WROTE=<path> / KEPT=<path>
#   MIGRATE=ok | nothing-to-convert | refused-existing-lua | refused-unparseable
#         | aborted-backup-failed
#
# Exit: 0 converted / offered / nothing to convert,
#       2 bad usage, 3 refused (unparseable or unmappable),
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
    -h|--help)   sed -n '2,40p' "$0"; exit 0 ;;
    *)           echo "ERROR: usage: migrate-config.sh [--convert]" >&2; exit 2 ;;
esac

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=config-language.sh
source "$here/config-language.sh"

target="${HYPR_DIR:-$HOME/.config/hypr}"
backup_dir="${HYPR_BACKUP_DIR:-$target}"
main="$target/hyprland.conf"

echo "TARGET=${target}"

if [ ! -f "$main" ]; then
    echo "There is no ${main} to convert."
    echo "MIGRATE=nothing-to-convert"
    exit 0
fi

# --- Refusal 1: never overwrite a lua config we did not write -------------------------------
if [ -e "$target/hyprland.lua" ]; then
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
declare -a ERRORS=()
declare -a QUEUE=()
declare -a SEEN=()

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

indent() { printf '%*s' $(( 4 * $1 )) ''; }

lua_stem() {
    # `<dir>/env.conf` under $target -> `env`; `<dir>/sub/x.conf` -> `sub/x`
    local p="${1#"$target"/}"
    printf '%s' "${p%.conf}"
}

note_error() { ERRORS+=("$1"); }

# convert_file <input.conf> <output.lua>
convert_file() {
    local in="$1" out="$2" lineno=0 depth=0
    local raw line body key val name rest
    : > "$out"
    {
        config_lang_provenance lua
        printf -- '-- Converted from %s by the hyprland-config plugin.\n' "${in#"$target"/}"
        printf -- '-- The original .conf is kept as a backup; see the BACKUP= line of the run.\n'
        printf -- '\n'
    } >> "$out"

    while IFS= read -r raw || [ -n "$raw" ]; do
        lineno=$((lineno + 1))
        body="$(strip_comment "$raw")"
        line="$(trim "$body")"

        if [ -z "$line" ]; then
            # Keep whole-line comments; a trailing comment is dropped (the .conf
            # backup still has it).
            local t; t="$(trim "$raw")"
            case "$t" in
                '#'*) printf -- '--%s\n' "${t#\#}" >> "$out" ;;
                '')   printf '\n' >> "$out" ;;
            esac
            continue
        fi

        # Block close
        if [ "$line" = "}" ]; then
            if [ "$depth" -eq 0 ]; then
                note_error "${in}:${lineno}: stray '}' with no open section"
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
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_:-]*)[[:space:]]*\{$ ]]; then
            name="${BASH_REMATCH[1]}"
            if [[ ! "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                note_error "${in}:${lineno}: section name '${name}' has no lua table-key form: ${line}"
                continue
            fi
            if [ "$depth" -eq 0 ]; then
                { printf 'hl.config({\n'; indent 1; printf '%s = {\n' "$name"; } >> "$out"
            else
                { indent $((depth + 1)); printf '%s = {\n' "$name"; } >> "$out"
            fi
            depth=$((depth + 1))
            continue
        fi

        # key = value
        if [[ "$line" != *"="* ]]; then
            note_error "${in}:${lineno}: not a hyprlang assignment or section: ${line}"
            continue
        fi
        key="$(trim "${line%%=*}")"
        val="$(trim "${line#*=}")"

        # Variable definition
        if [ "${key:0:1}" = '$' ]; then
            name="${key:1}"
            if [[ ! "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                note_error "${in}:${lineno}: variable name '${key}' is not usable: ${line}"
                continue
            fi
            VARS["$name"]="$(expand_vars "$val")"
            printf -- '-- %s = %s (expanded inline below, as hyprlang does)\n' "$key" "${VARS[$name]}" >> "$out"
            continue
        fi

        val="$(expand_vars "$val")"

        # Inside a section: a plain table entry.
        if [ "$depth" -gt 0 ]; then
            if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                note_error "${in}:${lineno}: '${key}' is a dotted/namespaced hyprlang key with no documented lua mapping: ${line}"
                continue
            fi
            { indent $((depth + 1)); printf '%s = %s,\n' "$key" "$(lua_value "$val")"; } >> "$out"
            continue
        fi

        # Top-level keywords.
        case "$key" in
            source)
                convert_source "$in" "$lineno" "$val" "$out"
                ;;
            monitor)
                convert_monitor "$in" "$lineno" "$val" "$out"
                ;;
            exec-once)
                { printf 'hl.exec_cmd(%s)\n' "$(lua_string "$val")"; } >> "$out"
                ;;
            env|envd)
                # On 0.55+ every hl.env() is implicitly the envd form.
                name="$(trim "${val%%,*}")"
                rest="$(trim "${val#*,}")"
                if [ "$name" = "$val" ]; then
                    note_error "${in}:${lineno}: ${key} needs NAME,value: ${line}"
                else
                    printf 'hl.env(%s, %s)\n' "$(lua_string "$name")" "$(lua_string "$rest")" >> "$out"
                fi
                ;;
            bind*)
                convert_bind "$in" "$lineno" "$key" "$val" "$out"
                ;;
            *)
                note_error "${in}:${lineno}: '${key}' has no documented lua mapping in this converter: ${line}"
                ;;
        esac
    done < "$in"

    if [ "$depth" -ne 0 ]; then
        note_error "${in}: ${depth} section(s) opened and never closed"
    fi
}

convert_source() {
    local in="$1" lineno="$2" val="$3" out="$4" p base
    case "$val" in
        *'*'*|*'?'*)
            note_error "${in}:${lineno}: 'source' with a glob has no deterministic lua form: source = ${val}"
            return ;;
    esac
    p="$val"
    case "$p" in
        '~/'*) p="$HOME/${p#\~/}" ;;
        /*)    ;;
        *)     p="$(dirname "$in")/$p" ;;
    esac
    case "$p" in
        *.conf) ;;
        *) note_error "${in}:${lineno}: 'source' of a non-.conf file: source = ${val}"; return ;;
    esac
    if [ ! -f "$p" ]; then
        note_error "${in}:${lineno}: sourced file does not exist: ${p}"
        return
    fi
    case "$p" in
        "$target"/*) ;;
        *) note_error "${in}:${lineno}: sourced file lives outside ${target}: ${p}"; return ;;
    esac
    base="$(lua_stem "$p")"
    printf 'require(%s)\n' "$(lua_string "$base")" >> "$out"
    QUEUE+=("$p")
}

convert_monitor() {
    local in="$1" lineno="$2" val="$3" out="$4"
    local IFS=','
    # shellcheck disable=SC2206
    local parts=($val)
    unset IFS
    if [ "${#parts[@]}" -ne 4 ]; then
        note_error "${in}:${lineno}: only the 4-field 'monitor = output, mode, position, scale' form has a documented lua mapping: monitor = ${val}"
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
    local in="$1" lineno="$2" key="$3" val="$4" out="$5"
    local flags="${key#bind}" has_description=0 opts="" i ch opt
    for (( i=0; i<${#flags}; i++ )); do
        ch="${flags:i:1}"
        if [ "$ch" = "d" ]; then has_description=1; continue; fi
        if ! opt="$(bind_option_for_flag "$ch")"; then
            note_error "${in}:${lineno}: bind flag '${ch}' in '${key}' has no documented lua option: ${key} = ${val}"
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
        note_error "${in}:${lineno}: bind needs MODS, KEY, DISPATCHER: ${key} = ${val}"
        return
    fi
    if [[ ! "$dispatcher" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        note_error "${in}:${lineno}: dispatcher '${dispatcher}' is not a lua identifier: ${key} = ${val}"
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
    if [ -e "$lua_target" ]; then
        echo "ERROR: '$lua_target' already exists; refusing to replace it." >&2
        echo "DECLINED_TO_REPLACE=${lua_target}"
        echo "MIGRATE=refused-existing-lua"
        exit 4
    fi
    mkdir -p "$(dirname "$scratch/$stem.lua")"
    convert_file "$src" "$scratch/$stem.lua"
    CONVERTED_FROM+=("$src")
    CONVERTED_TO+=("$lua_target")
done

if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "ERROR: this configuration cannot be converted faithfully, so nothing was changed." >&2
    echo "       Hyprland loads hyprland.lua INSTEAD of hyprland.conf, so a partial" >&2
    echo "       conversion would silently drop the lines below. Move them by hand, or" >&2
    echo "       keep using the .conf while it is still supported." >&2
    for e in "${ERRORS[@]}"; do
        echo "UNCONVERTIBLE=${e}"
    done
    echo "UNCONVERTIBLE_COUNT=${#ERRORS[@]}"
    echo "MIGRATE=refused-unparseable"
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
echo "MIGRATE=ok"

#!/usr/bin/env bash
# The keybind-bound desktop helpers talk to the RUNNING compositor in the form its config
# language takes.
#
# Under hyprlang a runtime toggle is `hyprctl keyword a:b v` and logout is
# `hyprctl dispatch exit`. Under a lua config - always, on Hyprland 0.57 - `keyword` does not
# exist and `dispatch` wants a lua dispatcher. The helpers only knew the hyprlang forms, so on
# 0.57 game mode, the blur toggle and the power menu's Logout all did nothing, silently. They
# also read option state from the `int` key of `getoption -j`; a lua session reports `bool`,
# so a toggle that did work could switch off and never back on.
#
# Driven with a stub `hyprctl` that records every call and answers `version` / `getoption` as
# told. No real compositor is contacted.

tmp="$(mktemp_test_dir desktop-helpers)"
stub="$tmp/bin"
mkdir -p "$stub"
log="$tmp/hyprctl.log"

# STUB_VERSION  what `hyprctl version` reports
# STUB_STYLE    how `getoption -j` answers: `int` (hyprlang) or `bool` (a lua session)
# STUB_ON       the option's state, 1 or 0
cat > "$stub/hyprctl" <<'STUB'
#!/usr/bin/env bash
log="$(dirname "$0")/../hyprctl.log"
case "${1:-}" in
    version)   echo "Hyprland ${STUB_VERSION:-0.54.3} built from branch"; exit 0 ;;
    getoption)
        printf 'getoption %s\n' "${2:-}" >> "$log"
        if [ "${STUB_STYLE:-int}" = "bool" ]; then
            [ "${STUB_ON:-1}" = "1" ] && v=true || v=false
            printf '{"option": "%s", "bool": %s, "set": true }\n' "${2:-}" "$v"
        else
            printf '{"option": "%s", "int": %s, "set": true }\n' "${2:-}" "${STUB_ON:-1}"
        fi
        exit 0 ;;
esac
printf '%s\n' "$*" >> "$log"
exit 0
STUB
# A launcher that always picks Logout, and a notifier that says nothing.
printf '#!/usr/bin/env bash\ncat >/dev/null\necho Logout\n' > "$stub/rofi"
printf '#!/usr/bin/env bash\nexit 0\n' > "$stub/notify-send"
chmod +x "$stub/hyprctl" "$stub/rofi" "$stub/notify-send"

cfg="$tmp/hypr"
mkdir -p "$cfg"

# `helper <env...> -- <action>` - run one helper against the stubs; the calls land in $log.
helper() {
    local envs=()
    while [ "$1" != "--" ]; do envs+=("$1"); shift; done
    shift
    : > "$log"
    env PATH="$stub:/usr/bin:/bin" HOME="$tmp" HYPR_DIR="$cfg" PYTHONPATH="$PLUGIN_ROOT/scripts" \
        "${envs[@]}" python3 -m ricelib.desktop.helpers "$@" >/dev/null 2>&1
}
calls() { grep -v '^getoption ' "$log"; }

# --------------------------------------------------------------------------------------------
# Hyprland 0.57: lua is the only language
# --------------------------------------------------------------------------------------------
helper STUB_VERSION=0.57.2 STUB_STYLE=bool STUB_ON=1 -- gamemode
assert_eq 'eval hl.config({ animations = { enabled = 0 }, decoration = { shadow = { enabled = 0 }, blur = { enabled = 0 }, rounding = 0 }, general = { gaps_in = 0, gaps_out = 0, border_size = 1 } })' \
    "$(calls)" "0.57 game mode: effects go off through hyprctl eval, as one hl.config call"
if grep -q 'keyword' "$log"; then
    fail "0.57 game mode: hyprctl keyword (which does not exist there) is not called" "$(cat "$log")"
else
    pass "0.57 game mode: hyprctl keyword (which does not exist there) is not called"
fi
assert_eq "getoption animations.enabled" "$(grep '^getoption ' "$log")" \
    "0.57 game mode: the state is read by the dotted option name"

# The state comes back as "bool": false. Reading only "int" made this branch unreachable.
helper STUB_VERSION=0.57.2 STUB_STYLE=bool STUB_ON=0 -- gamemode
assert_eq "reload" "$(calls)" "0.57 game mode: when already on, it restores by reloading"

helper STUB_VERSION=0.57.2 STUB_STYLE=bool STUB_ON=1 -- blur-toggle
assert_eq "eval hl.config({ decoration = { blur = { enabled = 0 } } })" "$(calls)" \
    "0.57 blur toggle: on -> off through hyprctl eval"
helper STUB_VERSION=0.57.2 STUB_STYLE=bool STUB_ON=0 -- blur-toggle
assert_eq "eval hl.config({ decoration = { blur = { enabled = 1 } } })" "$(calls)" \
    "0.57 blur toggle: off -> on (the state is read from the bool a lua session reports)"

helper STUB_VERSION=0.57.2 -- powermenu
assert_eq "dispatch hl.dsp.exit()" "$(calls)" "0.57 power menu: Logout is the lua dispatcher"

# --------------------------------------------------------------------------------------------
# A hyprlang session keeps the hyprlang forms
# --------------------------------------------------------------------------------------------
helper STUB_VERSION=0.54.3 STUB_STYLE=int STUB_ON=1 -- gamemode
assert_eq "--batch keyword animations:enabled 0;keyword decoration:shadow:enabled 0;keyword decoration:blur:enabled 0;keyword general:gaps_in 0;keyword general:gaps_out 0;keyword general:border_size 1;keyword decoration:rounding 0" \
    "$(calls)" "0.54 game mode: one hyprctl --batch of keyword lines, as before"
assert_eq "getoption animations:enabled" "$(grep '^getoption ' "$log")" \
    "0.54 game mode: the state is read by the colon option name"
helper STUB_VERSION=0.54.3 STUB_STYLE=int STUB_ON=1 -- blur-toggle
assert_eq "keyword decoration:blur:enabled 0" "$(calls)" "0.54 blur toggle: hyprctl keyword"
helper STUB_VERSION=0.54.3 STUB_STYLE=int STUB_ON=0 -- blur-toggle
assert_eq "keyword decoration:blur:enabled 1" "$(calls)" "0.54 blur toggle: and back on"
helper STUB_VERSION=0.54.3 -- powermenu
assert_eq "dispatch exit" "$(calls)" "0.54 power menu: Logout is hyprctl dispatch exit"

# --------------------------------------------------------------------------------------------
# 0.55 and 0.56 read whichever config is there: a hyprland.lua decides
# --------------------------------------------------------------------------------------------
helper STUB_VERSION=0.56.2 STUB_STYLE=int STUB_ON=1 -- blur-toggle
assert_eq "keyword decoration:blur:enabled 0" "$(calls)" \
    "0.56 with no hyprland.lua: still a hyprlang session"
printf -- '-- lua\n' > "$cfg/hyprland.lua"
helper STUB_VERSION=0.56.2 STUB_STYLE=bool STUB_ON=1 -- blur-toggle
assert_eq "eval hl.config({ decoration = { blur = { enabled = 0 } } })" "$(calls)" \
    "0.56 with a hyprland.lua: a lua session"
helper STUB_VERSION=0.56.2 -- powermenu
assert_eq "dispatch hl.dsp.exit()" "$(calls)" "0.56 with a hyprland.lua: Logout is the lua dispatcher"
rm -f "$cfg/hyprland.lua"

# The table game mode sends has to be one Hyprland accepts. hl.config validates the same way
# from a config file as from `hyprctl eval`, so the compositor's offline check can say.
if hyprland_reads_lua; then
    helper STUB_VERSION=0.57.2 STUB_STYLE=bool STUB_ON=1 -- gamemode
    mkdir -p "$tmp/check"
    calls | sed 's/^eval //' > "$tmp/check/hyprland.lua"
    if verify_config_isolated "$tmp/check/hyprland.lua" | grep -qx 'config ok'; then
        pass "hyprland: accepts the hl.config table game mode sends"
    else
        fail "hyprland: accepts the hl.config table game mode sends" "$(cat "$tmp/check/hyprland.lua")"
    fi
else
    skip "hyprland: accepts the hl.config table game mode sends" "no Hyprland 0.55 or newer on this host"
fi

rm -rf "$tmp"

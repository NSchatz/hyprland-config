#!/usr/bin/env bash
# Inside-container script. Starts sway headless, then for each rice preset palette:
#   1. Copies the preset into ~/.config/hypr-rice/palette.conf
#   2. Re-renders every wired colors file via render-templates.sh
#   3. Restarts waybar / mako so they pick up the new colors
#   4. Opens kitty windows with the rendered theme
#   5. grim-screenshots each surface into /screenshots/<preset>/
# Writes /screenshots/manifest.json with one entry per (preset, surface) so the orchestrator
# can assert what landed.
#
# Note: sway is the host compositor here because it boots headlessly on a runner with no
# /dev/dri. The rice flow's actual surfaces (waybar, wofi, mako, kitty) render identically in
# sway and Hyprland because they're all wlr-layer-shell / Wayland clients.
set -uo pipefail

PLUGIN_ROOT="/plugin"
OUT="/screenshots"
mkdir -p "$OUT" "$XDG_RUNTIME_DIR" "${XDG_CACHE_HOME:-$HOME/.cache}/hyprland/crashReports"
chmod 700 "$XDG_RUNTIME_DIR"

# ----- 0. Bring up a session D-Bus -----------------------------------------------------------
# waybar + mako require a session bus. Without /etc/machine-id (which we don't get from the
# Arch base image), dbus-daemon refuses to start. Synthesize one + launch a session bus and
# export DBUS_SESSION_BUS_ADDRESS so every child (waybar, mako, gdbus notify call) picks it up.
if [ ! -s /etc/machine-id ]; then
    dbus-uuidgen --ensure=/etc/machine-id
fi
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    eval "$(dbus-launch --sh-syntax)"
    echo "DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS"
fi

# ----- 1. Write a minimal sway config so it boots cleanly headless ---------------------------
mkdir -p "$HOME/.config/sway"
cat > "$HOME/.config/sway/config" <<'EOF'
# Minimal sway config for visual tests. Headless backend creates a 1600x900 virtual output;
# we set it explicitly so screenshots are a known size.
output HEADLESS-1 resolution 1600x900 position 0,0
input * xkb_layout "us"
# 2px solid border around floating windows (closest sway can get to Hyprland's
# general:border_size = 2 + col.active_border = $accent). Per-preset accent color is
# applied via `swaymsg client.focused …` once the palette is loaded.
default_border pixel 2
gaps inner 8
gaps outer 12
font pango:Inter 11

# Place kitty (the rice preview window) at a known spot so the per-window crop is stable. We
# avoid swaymsg-after-launch because focus/timing is racy; for_window rules apply when the
# window is mapped.
for_window [app_id="kitty"] floating enable, resize set 900 340, move position 60 140
# wofi already paints its own 2px @accent border in style.css — suppress the sway one so
# we don't double up.
for_window [app_id="wofi"]  floating enable, move position 500 170, border none
EOF

# ----- 2. Start sway headlessly --------------------------------------------------------------
echo "VISUAL_PHASE=starting-sway"
SWAY_LOG="/tmp/sway.log"
sway -V 2>&1 | head -n1 || true
WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 sway > "$SWAY_LOG" 2>&1 &
SWAY_PID=$!

# Sway picks a socket path under XDG_RUNTIME_DIR/sway-ipc.* — wait for it to appear.
deadline=$(( $(date +%s) + 30 ))
ready=0
while [ "$(date +%s)" -lt "$deadline" ]; do
    sock="$(find "$XDG_RUNTIME_DIR" -maxdepth 2 -name 'sway-ipc.*.sock' 2>/dev/null | head -n1)"
    if [ -n "$sock" ]; then
        export SWAYSOCK="$sock"
        if swaymsg -t get_version >/dev/null 2>&1; then
            ready=1; break
        fi
    fi
    sleep 0.3
done

if [ "$ready" -ne 1 ]; then
    echo "VISUAL_PHASE=sway-failed-to-start"
    echo "----- diagnostic: process state -----"
    ps -ef | grep -E 'sway|wayland' | grep -v grep || true
    echo "----- diagnostic: XDG_RUNTIME_DIR contents -----"
    ls -la "$XDG_RUNTIME_DIR" 2>&1 || true
    echo "----- diagnostic: SWAYSOCK env -----"
    echo "SWAYSOCK=${SWAYSOCK:-<unset>}"
    echo "----- diagnostic: swaymsg version probe -----"
    swaymsg -t get_version 2>&1 || true
    echo "----- sway stdout/stderr (full) -----"
    cat "$SWAY_LOG" || true
    echo "VISUAL=failed (sway did not become ready in 30s)"
    exit 2
fi
echo "VISUAL_PHASE=sway-ready (socket: $SWAYSOCK)"

# WAYLAND_DISPLAY is the socket name (relative to XDG_RUNTIME_DIR). Sway's default is wayland-1.
export WAYLAND_DISPLAY="wayland-1"
[ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] || {
    WAYLAND_DISPLAY="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' -not -name '*.lock' \
        | head -n1 | xargs -n1 basename 2>/dev/null)"
    export WAYLAND_DISPLAY
}
echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"

# ----- 3. Scaffold the rice engine -----------------------------------------------------------
echo "VISUAL_PHASE=rice-init"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
bash "$PLUGIN_ROOT/skills/rice/scripts/rice-init.sh" >/dev/null
RICE_DIR="$HOME/.config/hypr-rice"

# ----- 4. Discover committed regression fixtures ---------------------------------------------
# The plugin's component-writer agent produces real configs into tests/agent-eval/generated/
# when the user runs /regression-eval locally. The visual test consumes whatever's committed
# there — that's how this loop tests REAL plugin output instead of test stubs. If nothing has
# been committed, there's nothing to screenshot; bail out clean.
GEN_DIR="$PLUGIN_ROOT/tests/agent-eval/generated"

if [ ! -d "$GEN_DIR" ] || [ -z "$(ls -A "$GEN_DIR" 2>/dev/null)" ]; then
    echo "VISUAL_PHASE=no-fixtures"
    echo "  tests/agent-eval/generated/ is empty — no committed agent output to screenshot."
    echo "  To populate it: run '/regression-eval' locally, then commit tests/agent-eval/generated/."
    printf '{\n  "presets": [],\n  "shots": [],\n  "skipped_reason": "no-committed-fixtures"\n}\n' > "$OUT/manifest.json"
    echo "VISUAL=ok (skipped — no fixtures)"
    exit 0
fi

# Build the preset → [fixture-name, ...] map from fixture metadata. Each fixture targets one
# preset; the visual test groups all fixtures sharing a preset into a single composed scene.
declare -A PRESET_FIXTURES
for fix_json in "$PLUGIN_ROOT"/tests/agent-eval/fixtures/*.json; do
    [ -f "$fix_json" ] || continue
    name="$(jq -r .name "$fix_json")"
    preset="$(jq -r .preset "$fix_json")"
    [ -z "$name" ] || [ -z "$preset" ] && continue
    # Only count fixtures whose generated/ dir was actually committed.
    [ -d "$GEN_DIR/$name" ] || continue
    PRESET_FIXTURES["$preset"]+="$name "
done

if [ "${#PRESET_FIXTURES[@]}" -eq 0 ]; then
    echo "VISUAL_PHASE=no-matched-fixtures"
    echo "  Found fixture JSONs but no matching tests/agent-eval/generated/<name>/ dirs."
    echo "  Run '/regression-eval' to produce them, then commit."
    printf '{\n  "presets": [],\n  "shots": [],\n  "skipped_reason": "fixtures-defined-but-no-generated-dirs"\n}\n' > "$OUT/manifest.json"
    echo "VISUAL=ok (skipped — fixtures unpopulated)"
    exit 0
fi

PRESETS=( "${!PRESET_FIXTURES[@]}" )
echo "VISUAL_PHASE=fixtures-loaded"
for p in "${PRESETS[@]}"; do
    echo "  preset=$p  fixtures=${PRESET_FIXTURES[$p]}"
done

# Install the generated config dirs for every fixture in a preset's bundle into ~/.config/.
# Each fixture's tree mirrors what would go under ~/.config (e.g. waybar/, wofi/, mako/, kitty/),
# so a flat cp -r merges the surfaces cleanly.
install_preset_fixtures() {
    local preset="$1"
    for fix in ${PRESET_FIXTURES[$preset]}; do
        cp -r "$GEN_DIR/$fix/." "$HOME/.config/" 2>/dev/null || true
    done
}

# Track what got captured for the orchestrator. Start a manifest array.
manifest_entries=()

start_app_bg() { setsid "$@" >/dev/null 2>&1 < /dev/null & disown; }
# Like start_app_bg but redirects the app's stderr to a per-app log so we can debug rendering
# failures (waybar in particular fails silently on a CSS parse error).
start_app_logged() {
    local logf="$1"; shift
    setsid "$@" >"$logf" 2>&1 < /dev/null & disown
}

# Kill any stale clients before each preset. Wofi/waybar/mako will be relaunched per preset to
# pick up the freshly-rendered colors.
kill_clients() {
    pkill -x waybar 2>/dev/null || true
    pkill -x mako   2>/dev/null || true
    pkill -x kitty  2>/dev/null || true
    pkill -x wofi   2>/dev/null || true
    sleep 0.3
}

# Send a notification through mako (used to make the notification surface non-empty).
send_notification() {
    # Use a dbus-send for a transient notification — mako listens on the freedesktop bus that
    # sway brings up. If dbus isn't available we just skip the notif screenshot.
    if command -v gdbus >/dev/null 2>&1; then
        gdbus call --session --dest org.freedesktop.Notifications \
            --object-path /org/freedesktop/Notifications \
            --method org.freedesktop.Notifications.Notify \
            "rice" 0 "" "Theme applied" "$1" '[]' '{}' 5000 >/dev/null 2>&1 || true
    fi
}

# Place a sway window where we want it for a clean screenshot.
move_focused_window() {
    # $1=x,y  $2=widthxheight
    local pos="$1" size="$2"
    swaymsg "floating enable, move position $pos, resize set $size" >/dev/null 2>&1 || true
}

for preset in "${PRESETS[@]}"; do
    src="$PLUGIN_ROOT/skills/rice/assets/profiles/${preset}.conf"
    if [ ! -f "$src" ]; then
        echo "SKIP preset (not shipped): $preset"; continue
    fi

    echo "VISUAL_PHASE=preset:$preset"
    cp "$src" "$RICE_DIR/palette.conf"
    # Re-render with --no-reload (we're going to restart the apps ourselves).
    if ! bash "$RICE_DIR/render-templates.sh" --no-reload >/tmp/render.log 2>&1; then
        echo "RENDER_FAILED $preset"
        cat /tmp/render.log
        continue
    fi

    # Install the agent-produced configs for every fixture targeting this preset. This is the
    # whole point of the visual test now: it screenshots REAL plugin output (the
    # component-writer's generated configs that the user committed), not test stubs.
    install_preset_fixtures "$preset"

    # Pull palette bg for the wallpaper backdrop.
    pal_val() { awk -F= -v k="$1" '$1==k{print $2; exit}' "$RICE_DIR/palette.conf" | tr -d '\r'; }
    bg_hex="$(pal_val bg)"
    accent_hex="$(pal_val accent)"
    accent2_hex="$(pal_val accent2)"
    muted_hex="$(pal_val muted)"
    fg_hex="$(pal_val fg)"

    # Theme sway's per-state window border using the loaded palette. This is what gives the
    # kitty terminal (the only non-layer-shell, non-wofi window in scene) a visible accent
    # frame — the closest sway can render to Hyprland's `general:col.active_border = $accent`.
    if [ -n "$accent_hex" ]; then
        swaymsg "client.focused          #${accent_hex} #${accent_hex} #${fg_hex:-c0caf5} #${accent2_hex:-$accent_hex} #${accent_hex}" >/dev/null 2>&1 || true
        swaymsg "client.focused_inactive #${muted_hex:-565f89}  #${muted_hex:-565f89}  #${fg_hex:-c0caf5} #${muted_hex:-565f89}        #${muted_hex:-565f89}" >/dev/null 2>&1 || true
        swaymsg "client.unfocused        #${muted_hex:-565f89}  #${muted_hex:-565f89}  #${fg_hex:-c0caf5} #${muted_hex:-565f89}        #${muted_hex:-565f89}" >/dev/null 2>&1 || true
    fi

    # Clear screen.
    kill_clients
    swaymsg 'exec true' >/dev/null 2>&1 || true

    # Set the wallpaper. Prefer a per-preset image at tests/visual/wallpapers/<preset>.{jpg,png}
    # if one is bundled — that's the realistic backdrop (kitty's translucency is visible, the bar
    # sits over a real backdrop, wofi overlays it). Fall back to a solid palette-bg color for
    # presets that don't ship a wallpaper.
    if command -v swaybg >/dev/null 2>&1; then
        pkill -x swaybg 2>/dev/null || true
        wp=""
        for ext in jpg png jpeg; do
            cand="$PLUGIN_ROOT/tests/visual/wallpapers/${preset}.${ext}"
            [ -f "$cand" ] && { wp="$cand"; break; }
        done
        if [ -n "$wp" ]; then
            start_app_bg swaybg -i "$wp" -m fill
        elif [ -n "$bg_hex" ]; then
            # swaybg's --color expects #RRGGBB.
            start_app_bg swaybg --color "#${bg_hex}"
        fi
        sleep 0.2
    fi

    # Launch the components. Capture waybar/mako stderr so a silent CSS or JSON parse error
    # surfaces as a real log entry instead of an empty screenshot.
    start_app_logged "/tmp/waybar.log" waybar
    start_app_logged "/tmp/mako.log"   mako
    sleep 2.0  # both need a beat to draw; waybar in particular has a noticeable warm-up

    # Echo any error/warning lines waybar produced (so the orchestrator log has them).
    if [ -s /tmp/waybar.log ]; then
        echo "----- waybar log ($preset) -----"
        head -n 20 /tmp/waybar.log
    fi

    out_dir="$OUT/$preset"; mkdir -p "$out_dir"

    # Launch kitty with a small color demo script. Goes up first so the desktop composite
    # captures wallpaper + bar + terminal + notification together.
    # Override hide_window_decorations to `no` for the screenshot run only — the fixture's
    # production setting is `yes` (intended for real Hyprland users, where the COMPOSITOR
    # draws the accent border). Under sway-with-xdg-decoration, `yes` makes kitty request
    # CSD-no-decoration, which means sway never draws a border either. `no` lets sway draw
    # SSD per our `default_border pixel 2` + `client.focused #accent …` setup, so the
    # screenshot reproduces what Hyprland would render around the terminal.
    start_app_bg kitty -o hide_window_decorations=no --hold bash -c '
        printf "\033[1;38;2;255;255;255mhyprland-config rice preview\033[0m\n\n"
        printf "scheme: \033[1m%s\033[0m\n\n" "$(awk -F= "\$1==\"scheme\"{print \$2}" ~/.config/hypr-rice/palette.conf)"
        for i in 0 1 2 3 4 5 6 7; do
            printf "\033[3${i}m  ████  "
        done
        printf "\n"
        for i in 0 1 2 3 4 5 6 7; do
            printf "\033[9${i}m  ████  "
        done
        printf "\033[0m\n\n"
        printf "  $ ls -la ~/.config/hypr/\n"
        printf "  \033[34mdrwxr-xr-x\033[0m   binds.conf  monitors.conf  looknfeel.conf\n"
        printf "  $ \033[32mhyprctl reload\033[0m\n"
        printf "  ok\n\n"
    '
    # Sway's for_window rule sizes kitty to 900x340 / position 60,140. The 340 height matches
    # how much output the demo script actually prints, so the terminal crop has no dead space.
    sleep 1.5

    # Now send the notification so the desktop shot has all three surfaces lit.
    send_notification "$preset rice screenshot run"
    sleep 0.6

    # Per-surface crops. Tight enough that each frame is mostly the thing it's showing.
    # Terminal: matches the for_window resize (900x340 at 60,140).
    grim -g "60,140 900x340" "$out_dir/terminal.png" 2>/dev/null && manifest_entries+=("$preset/terminal.png")
    # Waybar: full width, tall enough to fence in the pill and a strip of wallpaper underneath.
    grim -g "0,0 1600x70" "$out_dir/waybar.png" 2>/dev/null && manifest_entries+=("$preset/waybar.png")
    # Notification: anchored top-right with margin=20 + width=380; this crop pulls just the toast.
    grim -g "1190,10 400x180" "$out_dir/notification.png" 2>/dev/null && manifest_entries+=("$preset/notification.png")
    # Full-desktop composite (wallpaper + waybar + terminal + notification together).
    grim "$out_dir/desktop.png" 2>/dev/null && manifest_entries+=("$preset/desktop.png")

    # Wofi gets a dedicated shot on a clean backdrop — kill kitty + dismiss the notification so
    # nothing bleeds through wofi's translucent background.
    pkill -x kitty 2>/dev/null || true
    makoctl dismiss --all 2>/dev/null || true
    sleep 0.3

    setsid wofi --show drun >/dev/null 2>&1 < /dev/null &
    wofi_pid=$!
    sleep 0.8
    grim -g "500,170 600x400" "$out_dir/wofi.png" 2>/dev/null && manifest_entries+=("$preset/wofi.png")
    kill "$wofi_pid" 2>/dev/null || true
    pkill -x wofi 2>/dev/null || true
    sleep 0.2
done

# ----- 7. Write manifest ---------------------------------------------------------------------
{
    printf '{\n  "presets": ['
    first=1
    for p in "${PRESETS[@]}"; do
        if [ "$first" -eq 1 ]; then first=0; else printf ','; fi
        printf '"%s"' "$p"
    done
    printf '],\n  "shots": ['
    first=1
    for e in "${manifest_entries[@]}"; do
        if [ "$first" -eq 1 ]; then first=0; else printf ','; fi
        printf '"%s"' "$e"
    done
    printf ']\n}\n'
} > "$OUT/manifest.json"

shot_count="${#manifest_entries[@]}"
echo ""
echo "VISUAL_PHASE=done"
echo "VISUAL_SHOTS=$shot_count"
echo "VISUAL=ok"

# Clean shutdown.
kill_clients
swaymsg exit >/dev/null 2>&1 || true
sleep 0.3
kill "$SWAY_PID" 2>/dev/null || true
wait "$SWAY_PID" 2>/dev/null || true
exit 0

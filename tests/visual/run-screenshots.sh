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

# ----- 1. Write a minimal sway config so it boots cleanly headless ---------------------------
mkdir -p "$HOME/.config/sway"
cat > "$HOME/.config/sway/config" <<'EOF'
# Minimal sway config for visual tests. Headless backend creates a 1600x900 virtual output;
# we set it explicitly so screenshots are a known size.
output HEADLESS-1 resolution 1600x900 position 0,0
input * xkb_layout "us"
default_border none
gaps inner 8
gaps outer 12
font pango:Inter 11
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

# ----- 4. Write minimal waybar + mako configs that read the engine's colors ------------------
# Bar is a centered floating-pill style: shows clock, workspaces stand-in, a status indicator.
# Style imports the colors file so the per-preset re-render is visible.
mkdir -p "$HOME/.config/waybar"
cat > "$HOME/.config/waybar/config.jsonc" <<'EOF'
{
  "layer": "top",
  "position": "top",
  "height": 38,
  "spacing": 8,
  "margin-top": 8,
  "margin-left": 14,
  "margin-right": 14,
  "modules-left": ["sway/workspaces", "sway/mode"],
  "modules-center": ["clock"],
  "modules-right": ["cpu", "memory", "tray"],
  "sway/workspaces": { "format": "{name}" },
  "clock": { "format": "{:%H:%M  %a %d %b}" },
  "cpu":   { "format": "  {usage}%" },
  "memory":{ "format": "  {used:.1f}G" }
}
EOF

cat > "$HOME/.config/waybar/style.css" <<'EOF'
@import "colors.css";

* {
    font-family: "JetBrainsMono Nerd Font", "Inter", sans-serif;
    font-size: 12pt;
    border: none;
    border-radius: 0;
}

window#waybar {
    background: transparent;
}

.modules-left, .modules-center, .modules-right {
    background-color: alpha(@bg, 0.85);
    color: @fg;
    border-radius: 14px;
    padding: 4px 14px;
    margin: 2px;
    border: 1px solid alpha(@surface, 0.6);
}

#workspaces button {
    background: transparent;
    color: @muted;
    padding: 0 6px;
}
#workspaces button.focused {
    color: @accent;
    background: alpha(@accent, 0.18);
    border-radius: 8px;
}

#clock { color: @accent; padding: 0 8px; }
#cpu { color: @green; padding: 0 8px; }
#memory { color: @yellow; padding: 0 8px; }
EOF

# Tiny mako config that themes off the engine's colors.css (we render a colors.ini next to it
# for mako since mako can't read CSS). For the screenshot we just want one notification visible.
mkdir -p "$HOME/.config/mako"
cat > "$HOME/.config/mako/config" <<'EOF'
font=Inter 11
default-timeout=0
anchor=top-right
margin=20
padding=14
border-size=2
border-radius=12
width=380
height=120
icons=0
EOF

# Wofi: simple drun layout
mkdir -p "$HOME/.config/wofi"
cat > "$HOME/.config/wofi/config" <<'EOF'
show=drun
width=600
height=400
location=center
allow_images=true
prompt=Search
EOF

cat > "$HOME/.config/wofi/style.css" <<'EOF'
@import "colors.css";

* {
    font-family: "Inter", sans-serif;
    font-size: 12pt;
}

window {
    background-color: alpha(@bg, 0.92);
    border: 2px solid @accent;
    border-radius: 16px;
}

#input {
    background-color: alpha(@surface, 0.6);
    color: @fg;
    padding: 10px 14px;
    margin: 12px;
    border-radius: 10px;
    border: 1px solid alpha(@muted, 0.4);
}

#inner-box, #outer-box, #scroll { background: transparent; }
#text { color: @fg; padding: 6px 10px; }
#entry { padding: 4px 8px; border-radius: 8px; }
#entry:selected {
    background-color: @accent;
    color: @bg;
}
EOF

# Kitty config — uses the colors.conf the engine renders.
mkdir -p "$HOME/.config/kitty"
cat > "$HOME/.config/kitty/kitty.conf" <<'EOF'
font_family JetBrainsMono Nerd Font
font_size 12.0
background_opacity 0.92
padding 14
include colors.conf
EOF

# ----- 5. Make sure the engine's manifest knows about wofi (its template) --------------------
# rice-init.sh already wires waybar/wofi/kitty/hyprland/rofi/gtk4 — the defaults are perfect.

# ----- 6. Iterate presets, render, screenshot ------------------------------------------------
PRESETS=(catppuccin-mocha gruvbox nord tokyo-night)

# Track what got captured for the orchestrator. Start a manifest array.
manifest_entries=()

start_app_bg() { setsid "$@" >/dev/null 2>&1 < /dev/null & disown; }

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

    # Clear screen.
    kill_clients
    swaymsg 'exec true' >/dev/null 2>&1 || true

    # Set a solid wallpaper using the palette bg so the screenshot has a real backdrop.
    bg_hex="$(awk -F= '$1=="bg"{print $2}' "$RICE_DIR/palette.conf" | head -n1 | tr -d '\r')"
    if [ -n "$bg_hex" ] && command -v swaybg >/dev/null 2>&1; then
        pkill -x swaybg 2>/dev/null || true
        # swaybg's --color expects #RRGGBB.
        start_app_bg swaybg --color "#${bg_hex}"
        sleep 0.2
    fi

    # Launch the components.
    start_app_bg waybar
    start_app_bg mako
    sleep 1.0  # waybar + mako both need a beat to lay out
    send_notification "$preset rice screenshot run"
    sleep 0.4

    out_dir="$OUT/$preset"; mkdir -p "$out_dir"

    # Full-desktop screenshot (waybar + wallpaper + notification together).
    grim "$out_dir/desktop.png" 2>/dev/null && manifest_entries+=("$preset/desktop.png")
    # Waybar-only via crop region. The bar is at the top of HEADLESS-1.
    grim -g "0,0 1600x80" "$out_dir/waybar.png" 2>/dev/null && manifest_entries+=("$preset/waybar.png")
    # Notification-only crop (mako anchored top-right).
    grim -g "1180,80 400,160" "$out_dir/notification.png" 2>/dev/null && manifest_entries+=("$preset/notification.png")

    # Terminal: launch kitty, run a small color demo script in it, screenshot.
    start_app_bg kitty --hold bash -c '
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
    sleep 1.2
    # Resize kitty into a known box so the crop is stable.
    move_focused_window "60 140" "900 600"
    sleep 0.6
    grim -g "60,140 900x600" "$out_dir/terminal.png" 2>/dev/null && manifest_entries+=("$preset/terminal.png")

    # Wofi: launch, screenshot, dismiss. wofi prints its picks to stdout — `&` it and read pid.
    setsid wofi --show drun >/dev/null 2>&1 < /dev/null &
    wofi_pid=$!
    sleep 0.8
    grim -g "500,170 600x500" "$out_dir/wofi.png" 2>/dev/null && manifest_entries+=("$preset/wofi.png")
    kill "$wofi_pid" 2>/dev/null || true
    pkill -x wofi 2>/dev/null || true
    sleep 0.2

    # One more full-desktop screenshot AFTER closing wofi so we have a "clean" composite too.
    grim "$out_dir/desktop-clean.png" 2>/dev/null && manifest_entries+=("$preset/desktop-clean.png")
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
